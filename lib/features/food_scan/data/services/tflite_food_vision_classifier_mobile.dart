import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';

/// Mobile implementation of [FoodVisionClassifier] using TensorFlow Lite / LiteRT C bindings.
/// Runs on Android & iOS. Gracefully degrades to unavailable if the model asset is pending.
class TfliteFoodVisionClassifier implements FoodVisionClassifier {
  final String modelPath;
  final String labelsPath;
  final int numThreads;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  bool _isAvailable = false;
  bool _initFailed = false;

  TfliteFoodVisionClassifier({
    this.modelPath = 'assets/ml/fitfuel_food_classifier.tflite',
    this.labelsPath = 'assets/ml/fitfuel_food_labels.txt',
    this.numThreads = 2,
  });

  @override
  bool get isAvailable => !_initFailed;

  /// Asynchronously loads model and label assets into memory.
  Future<bool> initialize() async {
    if (_isAvailable && _interpreter != null) return true;

    try {
      // 1. Load label manifest
      try {
        final labelsData = await rootBundle.loadString(labelsPath);
        _labels = const LineSplitter()
            .convert(labelsData)
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
      } catch (e) {
        LoggerService.info('FitFuel labels asset not found at $labelsPath: $e');
        _isAvailable = false;
        _initFailed = true;
        return false;
      }

      // 2. Attempt model loading via rootBundle buffer first (avoids Android assets/ prefix duplication)
      try {
        final options = InterpreterOptions()..threads = numThreads;
        try {
          final rawAsset = await rootBundle.load(modelPath);
          final modelBytes = rawAsset.buffer.asUint8List(
            rawAsset.offsetInBytes,
            rawAsset.lengthInBytes,
          );
          _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
        } catch (_) {
          _interpreter =
              await Interpreter.fromAsset(modelPath, options: options);
        }

        // Validate output tensor dimension matches labels count
        final outputShape = _interpreter!.getOutputTensor(0).shape;
        final outputClasses = outputShape.last;

        if (_labels.isNotEmpty && outputClasses != _labels.length) {
          LoggerService.warning(
            'Model output classes ($outputClasses) != label count (${_labels.length}). '
            'Marking local model unavailable.',
          );
          _interpreter?.close();
          _interpreter = null;
          _isAvailable = false;
          _initFailed = true;
          return false;
        }

        _isAvailable = true;
        _initFailed = false;
        LoggerService.info(
          'TFLite Food Classifier initialized successfully '
          '(${_labels.length} classes, threads=$numThreads)',
        );
        return true;
      } catch (e) {
        LoggerService.info(
          'On-device classifier model asset is pending or unavailable ($modelPath). '
          'Error: $e',
        );
        _isAvailable = false;
        _initFailed = true;
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.warning('Failed to initialize on-device classifier: $e');
      LoggerService.warning('$stackTrace');
      _isAvailable = false;
      _initFailed = true;
      return false;
    }
  }

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized || _interpreter == null) {
        return LocalFoodPrediction.unavailable(
          reason: 'Local model asset ($modelPath) is not available.',
        );
      }
    }

    final stopwatch = Stopwatch()..start();

    try {
      final inputDetails = _interpreter!.getInputTensor(0);
      final inputShape = inputDetails.shape; // e.g. [1, 224, 224, 3]
      final height = inputShape.length > 1 ? inputShape[1] : 224;
      final width = inputShape.length > 2 ? inputShape[2] : 224;

      // Preprocess image bytes to normalized tensor buffer (or graceful fallback on empty/test bytes)
      final inputBuffer = await _preprocessImage(imageBytes, height, width);

      final outputBuffer = List.generate(
        1,
        (_) => List.filled(_labels.isNotEmpty ? _labels.length : 50, 0.0),
      );

      _interpreter!.run(inputBuffer, outputBuffer);
      stopwatch.stop();

      final probabilities = outputBuffer[0];
      final List<MapEntry<int, double>> indexed = [];
      for (var i = 0; i < probabilities.length; i++) {
        indexed.add(MapEntry(i, probabilities[i]));
      }
      indexed.sort((a, b) => b.value.compareTo(a.value));

      final topEntries = indexed.take(5).toList();
      final candidates = topEntries.map((e) {
        final id = e.key < _labels.length ? _labels[e.key] : 'class_${e.key}';
        final name = _formatFoodName(id);
        return LocalFoodCandidate(
          foodId: id,
          foodName: name,
          confidence: e.value,
        );
      }).toList();

      final top = candidates.isNotEmpty ? candidates.first : null;
      final top3Debug = candidates
          .take(3)
          .map((c) => '${c.foodId}:${c.confidence.toStringAsFixed(3)}')
          .join(',');
      LoggerService.info(
        '[FoodScanLocalModel] model=fitfuel_food_v5 top1=${top?.foodId ?? 'none'} '
        'confidence=${(top?.confidence ?? 0.0).toStringAsFixed(3)} '
        'top3=$top3Debug durationMs=${stopwatch.elapsedMilliseconds}',
      );

      return LocalFoodPrediction(
        foodId: top?.foodId ?? '',
        foodName: top?.label ?? '',
        confidence: top?.confidence ?? 0.0,
        topCandidates: candidates,
        inferenceDurationMs: stopwatch.elapsedMilliseconds,
        isModelAvailable: true,
      );
    } catch (e, stackTrace) {
      LoggerService.error('Error during on-device food classification', e, stackTrace);
      return LocalFoodPrediction.unavailable(
        reason: 'Error during on-device inference: $e',
      );
    }
  }

  static String _formatFoodName(String foodId) {
    var raw = foodId.replaceAll('predefined_', '').replaceAll('_', ' ');
    return raw.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(
    Uint8List imageBytes,
    int height,
    int width,
  ) async {
    try {
      if (imageBytes.isEmpty) {
        return List.generate(
          1,
          (_) => List.generate(
            height,
            (_) => List.generate(width, (_) => List.filled(3, 0.0)),
          ),
        );
      }

      // Decode image without forcing both targetWidth and targetHeight simultaneously,
      // because dart:ui preserves aspect ratio (e.g. 4:3 or 16:9 camera photos decode
      // to non-square dimensions such as 168x224). We then bilinearly resize from
      // (srcW, srcH) to (width, height) to match tf.image.resize([224, 224]).
      final codec = imageBytes.length > 250000
          ? await ui.instantiateImageCodec(imageBytes, targetWidth: width * 2)
          : await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final srcW = image.width;
      final srcH = image.height;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null || srcW <= 0 || srcH <= 0) {
        throw Exception('Failed to extract RGBA bytes from decoded frame');
      }

      final rawBytes = byteData.buffer.asUint8List();
      final scaleY = srcH / height;
      final scaleX = srcW / width;

      return List.generate(
        1,
        (_) => List.generate(
          height,
          (y) {
            final srcYf =
                ((y + 0.5) * scaleY - 0.5).clamp(0.0, (srcH - 1).toDouble());
            final y0 = srcYf.floor();
            final y1 = (y0 + 1 < srcH) ? y0 + 1 : y0;
            final wy = srcYf - y0;

            return List.generate(
              width,
              (x) {
                final srcXf = ((x + 0.5) * scaleX - 0.5)
                    .clamp(0.0, (srcW - 1).toDouble());
                final x0 = srcXf.floor();
                final x1 = (x0 + 1 < srcW) ? x0 + 1 : x0;
                final wx = srcXf - x0;

                final o00 = (y0 * srcW + x0) * 4;
                final o01 = (y0 * srcW + x1) * 4;
                final o10 = (y1 * srcW + x0) * 4;
                final o11 = (y1 * srcW + x1) * 4;

                final r = (1 - wy) *
                        ((1 - wx) * rawBytes[o00] + wx * rawBytes[o01]) +
                    wy * ((1 - wx) * rawBytes[o10] + wx * rawBytes[o11]);
                final g = (1 - wy) *
                        ((1 - wx) * rawBytes[o00 + 1] +
                            wx * rawBytes[o01 + 1]) +
                    wy *
                        ((1 - wx) * rawBytes[o10 + 1] +
                            wx * rawBytes[o11 + 1]);
                final b = (1 - wy) *
                        ((1 - wx) * rawBytes[o00 + 2] +
                            wx * rawBytes[o01 + 2]) +
                    wy *
                        ((1 - wx) * rawBytes[o10 + 2] +
                            wx * rawBytes[o11 + 2]);

                return [r, g, b];
              },
            );
          },
        ),
      );
    } catch (e) {
      LoggerService.info('Preprocess fallback to zero tensor: $e');
      return List.generate(
        1,
        (_) => List.generate(
          height,
          (_) => List.generate(width, (_) => List.filled(3, 0.0)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isAvailable = false;
  }
}
