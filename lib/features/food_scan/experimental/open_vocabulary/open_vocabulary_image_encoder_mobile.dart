import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'open_vocabulary_image_encoder_interface.dart';
import 'open_vocabulary_similarity_engine.dart';

/// Native Android/iOS implementation of [IOpenVocabularyImageEncoder] using LiteRT / TensorFlow Lite.
///
/// Lazy-loads the model only when first requested (never at app startup),
/// and records separate timings for:
/// - Cold model initialization ([coldLoadTimeMs])
/// - Image decode ([OpenVocabularyEncodedImage.imageDecodeMs])
/// - Resize + RGB tensor preprocessing ([OpenVocabularyEncodedImage.preprocessMs])
/// - TFLite inference ([OpenVocabularyEncodedImage.inferenceMs])
class TfliteOpenVocabularyImageEncoder implements IOpenVocabularyImageEncoder {
  final String modelAssetPath;
  @override
  final String modelName;
  @override
  final int embeddingDimension;
  final int numThreads;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  double _coldLoadTimeMs = 0.0;

  TfliteOpenVocabularyImageEncoder({
    this.modelAssetPath =
        'assets/ml/fitfuel_openvocab_mnv3_384_float16.tflite',
    this.modelName = 'fitfuel_openvocab_mnv3_minilm_384',
    this.embeddingDimension = 384,
    this.numThreads = 2,
  });

  @override
  String get runtimeName =>
      'LiteRT / TensorFlow Lite CPU ($numThreads threads)';

  @override
  bool get isInitialized => _isInitialized && _interpreter != null;

  @override
  double get coldLoadTimeMs => _coldLoadTimeMs;

  /// Lazily initializes the TFLite interpreter when the benchmark or experimental view is opened.
  Future<bool> initialize() async {
    if (_isInitialized && _interpreter != null) return true;

    final sw = Stopwatch()..start();
    try {
      final options = InterpreterOptions()..threads = numThreads;
      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );
      sw.stop();
      _coldLoadTimeMs = sw.elapsedMicroseconds / 1000.0;
      _isInitialized = true;
      LoggerService.info(
        'OpenVocabulary TFLite encoder initialized ($modelName) in ${_coldLoadTimeMs.toStringAsFixed(2)} ms',
      );
      return true;
    } catch (e) {
      sw.stop();
      _coldLoadTimeMs = sw.elapsedMicroseconds / 1000.0;
      _isInitialized = false;
      LoggerService.info(
        'OpenVocabulary TFLite model asset not bundled at $modelAssetPath: $e',
      );
      return false;
    }
  }

  @override
  Future<OpenVocabularyEncodedImage> encodeImage(Uint8List imageBytes) async {
    bool wasCold = false;
    if (!isInitialized) {
      wasCold = true;
      final ok = await initialize();
      if (!ok || _interpreter == null) {
        return OpenVocabularyEncodedImage.unavailable(
          modelName: modelName,
          runtimeName: runtimeName,
          reason:
              'Experimental open-vocabulary model asset ($modelAssetPath) is not available.',
        );
      }
    }

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape; // [1, 224, 224, 3]
      final height = inputShape.length > 1 ? inputShape[1] : 224;
      final width = inputShape.length > 2 ? inputShape[2] : 224;

      final outputTensor = _interpreter!.getOutputTensor(0);
      final outDim = outputTensor.shape.isNotEmpty
          ? outputTensor.shape.last
          : embeddingDimension;

      // Step 1 & 2: Decode + Deterministic Resize/Normalization
      final preprocResult = await _decodeAndPreprocess(
        imageBytes,
        height,
        width,
      );

      // Step 3: TFLite Inference
      final inferSw = Stopwatch()..start();
      final outputBuffer = List.generate(
        1,
        (_) => List<double>.filled(outDim, 0.0),
      );
      _interpreter!.run(preprocResult.tensor, outputBuffer);
      inferSw.stop();
      final inferenceMs = inferSw.elapsedMicroseconds / 1000.0;

      final normalizedEmbedding =
          OpenVocabularySimilarityEngine.normalizeEmbedding(outputBuffer[0]);

      return OpenVocabularyEncodedImage(
        embedding: normalizedEmbedding,
        imageDecodeMs: preprocResult.decodeMs,
        preprocessMs: preprocResult.preprocessMs,
        inferenceMs: inferenceMs,
        coldLoadMs: wasCold ? _coldLoadTimeMs : 0.0,
        wasColdStart: wasCold,
        modelName: modelName,
        runtimeName: runtimeName,
        isSuccess: normalizedEmbedding.isNotEmpty,
      );
    } catch (e) {
      return OpenVocabularyEncodedImage.unavailable(
        modelName: modelName,
        runtimeName: runtimeName,
        reason: 'Open-vocabulary encoding error: $e',
      );
    }
  }

  Future<_PreprocessedImageResult> _decodeAndPreprocess(
    Uint8List bytes,
    int targetHeight,
    int targetWidth,
  ) async {
    final decodeSw = Stopwatch()..start();
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      decodeSw.stop();
      final decodeMs = decodeSw.elapsedMicroseconds / 1000.0;

      final preprocSw = Stopwatch()..start();
      if (byteData == null) {
        final fallback = _emptyTensor(targetHeight, targetWidth);
        preprocSw.stop();
        return _PreprocessedImageResult(
          tensor: fallback,
          decodeMs: decodeMs,
          preprocessMs: preprocSw.elapsedMicroseconds / 1000.0,
        );
      }

      final rgba = byteData.buffer.asUint8List();
      final tensor = List.generate(
        1,
        (_) => List.generate(
          targetHeight,
          (y) => List.generate(targetWidth, (x) {
            final idx = (y * targetWidth + x) * 4;
            if (idx + 2 < rgba.length) {
              return <double>[
                rgba[idx].toDouble(),
                rgba[idx + 1].toDouble(),
                rgba[idx + 2].toDouble(),
              ];
            }
            return <double>[0.0, 0.0, 0.0];
          }, growable: false),
          growable: false,
        ),
        growable: false,
      );
      preprocSw.stop();

      return _PreprocessedImageResult(
        tensor: tensor,
        decodeMs: decodeMs,
        preprocessMs: preprocSw.elapsedMicroseconds / 1000.0,
      );
    } catch (_) {
      decodeSw.stop();
      final decodeMs = decodeSw.elapsedMicroseconds / 1000.0;
      final preprocSw = Stopwatch()..start();
      final fallback = _emptyTensor(targetHeight, targetWidth);
      preprocSw.stop();
      return _PreprocessedImageResult(
        tensor: fallback,
        decodeMs: decodeMs,
        preprocessMs: preprocSw.elapsedMicroseconds / 1000.0,
      );
    }
  }

  List<List<List<List<double>>>> _emptyTensor(int height, int width) {
    return List.generate(
      1,
      (_) => List.generate(
        height,
        (_) => List.generate(width, (_) => <double>[0.0, 0.0, 0.0]),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

class _PreprocessedImageResult {
  final List<List<List<List<double>>>> tensor;
  final double decodeMs;
  final double preprocessMs;

  const _PreprocessedImageResult({
    required this.tensor,
    required this.decodeMs,
    required this.preprocessMs,
  });
}
