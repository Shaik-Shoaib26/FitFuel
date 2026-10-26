import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'package:fitfuel/features/food_scan/data/services/open_vocabulary_model_asset_provider_impl.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_model_asset_provider.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';

/// Production Tier-2 on-device open-vocabulary food recognizer backed by
/// ONNX Runtime Mobile (`SigLIP-B/16 INT8`) on Android via platform channel
/// `fitfuel/open_vocab_food_recognizer`.
///
/// Key lifecycle properties (Phase 35.11B Sections 27–30, 33–36):
/// - Lazy initialization: does NOT load the 96.56 MB ONNX model at app startup
///   or when Tier 1 (`fitfuel_food_v5`) auto-accepts a trusted class.
/// - Warm session reuse: once initialized inside `FoodScanScreen`, subsequent
///   scans reuse the active `OrtSession` (~631 ms P50 on SM-E346B).
/// - Clean disposal: `dispose()` closes the native `OrtSession` and releases
///   memory buffers when leaving `FoodScanScreen`.
/// - Graceful cross-platform fallback: on Web/Desktop/iOS or if assets are
///   missing, returns `OpenVocabularyRecognitionResult.unavailable` without crashing.
class SiglipOpenVocabularyFoodRecognizer
    implements OpenVocabularyFoodRecognizer, DynamicVocabularySyncCapable {
  static const MethodChannel _channel =
      MethodChannel('fitfuel/open_vocab_food_recognizer');

  final OpenVocabularyModelAssetProvider _assetProvider;
  final int maxSuggestions;

  bool _markedUnavailable = false;
  bool _isSessionLoaded = false;

  SiglipOpenVocabularyFoodRecognizer({
    OpenVocabularyModelAssetProvider? assetProvider,
    this.maxSuggestions = 3,
  }) : _assetProvider =
            assetProvider ?? PlatformOpenVocabularyModelAssetProvider();

  bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get isAvailable => _isSupportedPlatform && !_markedUnavailable;

  @override
  bool get isSessionLoaded => _isSessionLoaded;

  @override
  bool get requiresColdInit => !_isSessionLoaded;

  @override
  Future<void> initialize() async {
    if (!isAvailable) return;
    if (_isSessionLoaded) return;

    try {
      final assets = await _assetProvider.resolveAssets();
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        assets?.toMap(),
      );
      if (response != null && response['initialized'] == true) {
        _isSessionLoaded = true;
      } else {
        _markedUnavailable = true;
        _isSessionLoaded = false;
      }
    } on MissingPluginException {
      _markedUnavailable = true;
      _isSessionLoaded = false;
    } on PlatformException catch (e) {
      LoggerService.warning(
        '[FoodScanCascade] tier2_unavailable reason=${e.message ?? e.code}',
      );
      _markedUnavailable = true;
      _isSessionLoaded = false;
    } catch (e) {
      LoggerService.warning('[FoodScanCascade] tier2_unavailable reason=$e');
      _markedUnavailable = true;
      _isSessionLoaded = false;
    }
  }

  @override
  Future<OpenVocabularyRecognitionResult> recognize(
    Uint8List imageBytes,
  ) async {
    if (!isAvailable) {
      return OpenVocabularyRecognitionResult.unavailable(
        reason: _isSupportedPlatform
            ? 'SigLIP model assets or ONNX session unavailable.'
            : 'Open-vocabulary ONNX inference is not supported on this platform.',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'recognizeImageBytes',
        <String, dynamic>{
          'imageBytes': imageBytes,
        },
      );

      if (response == null) {
        _markedUnavailable = true;
        _isSessionLoaded = false;
        return OpenVocabularyRecognitionResult.unavailable(
          reason: 'Null response from native open-vocabulary recognizer.',
        );
      }

      if (response['isUnavailable'] == true) {
        _markedUnavailable = true;
        _isSessionLoaded = false;
        final err = (response['errorReason'] ??
                'SigLIP model assets missing or corrupt.')
            .toString();
        return OpenVocabularyRecognitionResult.unavailable(reason: err);
      }

      _isSessionLoaded = true;
      final parsed = OpenVocabularyRecognitionResult.fromNativeMap(response);
      final deduplicatedTop =
          TrustedOpenVocabNutritionMapper.deduplicateCandidates(
        parsed.topCandidates,
        maxSuggestions: maxSuggestions,
      );

      return parsed.copyWith(topCandidates: deduplicatedTop);
    } on MissingPluginException {
      _markedUnavailable = true;
      _isSessionLoaded = false;
      return OpenVocabularyRecognitionResult.unavailable(
        reason: 'Open-vocabulary platform channel is not registered.',
      );
    } on PlatformException catch (e) {
      _isSessionLoaded = false;
      return OpenVocabularyRecognitionResult.unavailable(
        reason: e.message ?? e.code,
      );
    } catch (e) {
      return OpenVocabularyRecognitionResult.unavailable(
        reason: e.toString(),
      );
    }
  }

  @override
  Future<void> dispose() async {
    final wasLoaded = _isSessionLoaded;
    _isSessionLoaded = false;
    if (!_isSupportedPlatform || !wasLoaded) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('dispose');
      if (kDebugMode) {
        debugPrint('[FoodScanCascade] tier2_session_disposed model=siglip_b16_int8');
      }
    } on MissingPluginException {
      // Ignore in unit tests or unsupported platforms
    } catch (_) {
      // Never throw on disposal
    }
  }

  @override
  Future<Map<String, dynamic>?> registerDynamicVocabularyPack(
    VocabularyPack pack, {
    bool requireAllVisionEligible = false,
  }) async {
    if (!isAvailable) return null;
    try {
      final entriesPayload = pack.entries.map((e) => {
            'canonicalFoodId': e.canonicalId,
            'canonicalName': e.preferredName,
            'category': e.category,
            'textEmbedding': e.textEmbedding,
            'inFitFuel238': e.inFitFuelCatalog,
          }).toList();

      final response = await _channel.invokeMapMethod<String, dynamic>(
        'registerDynamicVocabularyPack',
        <String, dynamic>{
          'packId': pack.packId,
          'version': pack.version,
          'targetModelId': pack.targetModelId,
          'requireAllVisionEligible': requireAllVisionEligible,
          'entries': entriesPayload,
        },
      );
      return response;
    } on MissingPluginException {
      return null;
    } catch (e) {
      LoggerService.warning(
        '[SiglipRecognizer] registerDynamicVocabularyPack error: $e',
      );
      return {'success': false, 'error': e.toString(), 'rolledBack': true};
    }
  }

  @override
  Future<bool> clearDynamicVocabulary() async {
    if (!isAvailable) return false;
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('clearDynamicVocabulary');
      return res?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRegisteredVocabularyInfo() async {
    if (!isAvailable) return null;
    try {
      return await _channel
          .invokeMapMethod<String, dynamic>('getRegisteredVocabularyInfo');
    } catch (_) {
      return null;
    }
  }
}

/// Deterministic in-memory [OpenVocabularyFoodRecognizer] for unit and widget tests.
class FakeOpenVocabularyFoodRecognizer
    implements OpenVocabularyFoodRecognizer, DynamicVocabularySyncCapable {
  bool _available;
  bool _sessionLoaded;
  int initializeCallCount = 0;
  int recognizeCallCount = 0;
  int disposeCallCount = 0;
  OpenVocabularyRecognitionResult? nextResult;
  Duration simulatedLatency;

  FakeOpenVocabularyFoodRecognizer({
    bool isAvailable = true,
    bool isSessionLoaded = false,
    this.nextResult,
    this.simulatedLatency = Duration.zero,
  })  : _available = isAvailable,
        _sessionLoaded = isSessionLoaded;

  set available(bool value) => _available = value;

  @override
  bool get isAvailable => _available;

  @override
  bool get isSessionLoaded => _sessionLoaded;

  @override
  bool get requiresColdInit => !_sessionLoaded;

  void setAcceptedCandidates(
    List<OpenVocabularyFoodCandidate> candidates, {
    double topSimilarity = 0.0812,
    double negativeSimilarity = -0.0085,
    int modelLoadMs = 0,
    int preprocessMs = 15,
    int encoderMs = 609,
    int retrievalMs = 8,
  }) {
    final margin = topSimilarity - negativeSimilarity;
    nextResult = OpenVocabularyRecognitionResult(
      accepted: true,
      abstained: false,
      isNonFoodRejected: false,
      isUnavailable: false,
      topCandidates: candidates,
      modelId: 'siglip_b16_int8',
      topSimilarity: topSimilarity,
      negativeSimilarity: negativeSimilarity,
      negativeMargin: margin,
      topNegativePrompt: 'Wooden Desk / Office Table',
      decisionReason: 'accepted_open_vocab',
      modelLoadMs: modelLoadMs,
      preprocessMs: preprocessMs,
      encoderMs: encoderMs,
      retrievalMs: retrievalMs,
      totalMs: modelLoadMs + preprocessMs + encoderMs + retrievalMs,
      sessionReused: _sessionLoaded,
    );
  }

  void setNonFoodAbstained({
    double topSimilarity = 0.0410,
    double negativeSimilarity = 0.0320,
    String topNegativePrompt = 'Laptop Computer / Monitor',
    List<OpenVocabularyFoodCandidate> internalSuppressedCandidates = const [],
  }) {
    nextResult = OpenVocabularyRecognitionResult(
      accepted: false,
      abstained: true,
      isNonFoodRejected: true,
      isUnavailable: false,
      topCandidates: internalSuppressedCandidates,
      modelId: 'siglip_b16_int8',
      topSimilarity: topSimilarity,
      negativeSimilarity: negativeSimilarity,
      negativeMargin: topSimilarity - negativeSimilarity,
      topNegativePrompt: topNegativePrompt,
      decisionReason: 'rejected_non_food_margin',
      preprocessMs: 14,
      encoderMs: 605,
      retrievalMs: 7,
      totalMs: 626,
      sessionReused: _sessionLoaded,
    );
  }

  void setLowSimilarityAbstained({
    double topSimilarity = 0.0520,
    double negativeSimilarity = -0.0150,
    List<OpenVocabularyFoodCandidate> internalSuppressedCandidates = const [],
  }) {
    nextResult = OpenVocabularyRecognitionResult(
      accepted: false,
      abstained: true,
      isNonFoodRejected: false,
      isUnavailable: false,
      topCandidates: internalSuppressedCandidates,
      modelId: 'siglip_b16_int8',
      topSimilarity: topSimilarity,
      negativeSimilarity: negativeSimilarity,
      negativeMargin: topSimilarity - negativeSimilarity,
      topNegativePrompt: 'Empty Plate / Empty Bowl',
      decisionReason: 'rejected_low_food_similarity',
      preprocessMs: 14,
      encoderMs: 605,
      retrievalMs: 7,
      totalMs: 626,
      sessionReused: _sessionLoaded,
    );
  }

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (!_available) return;
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }
    _sessionLoaded = true;
  }

  @override
  Future<OpenVocabularyRecognitionResult> recognize(
    Uint8List imageBytes,
  ) async {
    recognizeCallCount++;
    if (!_available) {
      return OpenVocabularyRecognitionResult.unavailable(
        reason: 'FakeOpenVocabularyFoodRecognizer is marked unavailable.',
      );
    }
    final wasWarm = _sessionLoaded;
    if (!_sessionLoaded) {
      await initialize();
    } else if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    final configured = nextResult;
    if (configured == null) {
      return OpenVocabularyRecognitionResult.unavailable(
        reason: 'No fake result configured.',
      );
    }

    final deduplicated = TrustedOpenVocabNutritionMapper.deduplicateCandidates(
      configured.topCandidates,
    );

    return configured.copyWith(
      sessionReused: wasWarm,
      modelLoadMs: wasWarm ? 0 : (configured.modelLoadMs > 0 ? configured.modelLoadMs : 428),
      topCandidates: deduplicated,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _sessionLoaded = false;
  }

  final List<VocabularyPack> registeredPacks = [];
  int clearDynamicVocabularyCallCount = 0;
  bool simulateNativeFailureOnRegister = false;

  @override
  Future<Map<String, dynamic>?> registerDynamicVocabularyPack(
    VocabularyPack pack, {
    bool requireAllVisionEligible = false,
  }) async {
    if (simulateNativeFailureOnRegister) {
      return {
        'success': false,
        'error': 'Simulated native registration failure',
        'rolledBack': true,
      };
    }

    if (requireAllVisionEligible &&
        pack.targetModelId != null &&
        !pack.targetModelId!.toLowerCase().contains('siglip')) {
      return {
        'success': false,
        'error': 'Incompatible model ID ${pack.targetModelId}. Expected SigLIP model compatible with siglip_b16_int8.',
        'rolledBack': true,
      };
    }

    if (requireAllVisionEligible) {
      for (final e in pack.entries) {
        if (!e.hasImageSupport) {
          return {
            'success': false,
            'error': 'Entry "${e.canonicalId}" lacks 768-d embedding',
            'rolledBack': true,
          };
        }
        final emb = e.textEmbedding!;
        double normSq = 0.0;
        for (final v in emb) {
          normSq += v * v;
        }
        if (normSq < 1e-12) {
          return {
            'success': false,
            'error': 'Entry "${e.canonicalId}" has zero or near-zero norm ($normSq)',
            'rolledBack': true,
          };
        }
      }
    }

    registeredPacks.removeWhere((p) => p.packId == pack.packId);
    registeredPacks.add(pack);
    final visionAdded = pack.entries.where((e) => e.hasImageSupport).length;
    return {
      'success': true,
      'packId': pack.packId,
      'visionAddedCount': visionAdded,
      'totalConcepts': 2050 + visionAdded,
      'persisted': true,
    };
  }

  @override
  Future<bool> clearDynamicVocabulary() async {
    clearDynamicVocabularyCallCount++;
    registeredPacks.clear();
    return true;
  }

  @override
  Future<Map<String, dynamic>?> getRegisteredVocabularyInfo() async {
    final dynCount = registeredPacks.fold<int>(
      0,
      (sum, p) => sum + p.entries.where((e) => e.hasImageSupport).length,
    );
    return {
      'baseConcepts': 2050,
      'dynamicConcepts': dynCount,
      'totalConcepts': 2050 + dynCount,
      'dynamicPacksCount': registeredPacks.length,
    };
  }
}
