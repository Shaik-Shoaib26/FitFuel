import 'package:flutter/foundation.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/food_matcher.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';

class FoodScanRepositoryImpl implements IFreeFirstFoodScanRepository {
  final IFoodScanRemoteDataSource _remoteDataSource;
  final FoodScanRecognitionRouter? _router;

  FoodScanRepositoryImpl({
    required IFoodScanRemoteDataSource remoteDataSource,
    FoodScanRecognitionRouter? router,
  })  : _remoteDataSource = remoteDataSource,
        _router = router;

  @override
  bool get hasFreeFirstRouter => _router != null;

  @override
  FoodScanRecognitionRouter? get router => _router;

  @override
  Future<FoodScanRouteDecision> evaluateFreeFirstScan({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  }) async {
    final reqId = requestId ?? 'scan_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      return await _router.routeFreeFirst(
        imagePath: imagePath,
        imageBytes: imageBytes,
        foodCatalog: foodCatalog,
        requestId: reqId,
        isOffline: isOffline,
        isMixedMealSuspected: isMixedMealSuspected,
      );
    }
    return LocalModelUnavailable(
      requestId: reqId,
      imagePath: imagePath,
      isOffline: isOffline,
    );
  }

  @override
  Future<FoodScanResult> analyzeWithAi({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
    LocalFoodPrediction? priorLocalPrediction,
    int localInferenceDurationMs = 0,
    bool isOffline = false,
    bool userRequestedAi = true,
  }) async {
    if (!userRequestedAi) {
      throw StateError('Automatic Gemini call blocked');
    }
    final reqId = requestId ?? 'ai_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      return await _router.analyzeWithCloud(
        imagePath: imagePath,
        imageBytes: imageBytes,
        foodCatalog: foodCatalog,
        requestId: reqId,
        priorLocalPrediction: priorLocalPrediction,
        localInferenceDurationMs: localInferenceDurationMs,
        isOffline: isOffline,
        userRequestedAi: userRequestedAi,
        scanSessionId: reqId,
      );
    }
    if (isOffline) {
      throw FoodScanFailure.fromType(FoodScanFailureType.offline);
    }
    return await _scanViaRemoteDataSource(
      imagePath: imagePath,
      imageBytes: imageBytes,
      foodCatalog: foodCatalog,
      reqId: reqId,
    );
  }

  @override
  FoodScanResult confirmLocalSuggestion({
    required LocalFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    String? requestId,
    int? localInferenceDurationMs,
    List<LocalFoodCandidate> allSuggestions = const [],
    String? top1FoodId,
  }) {
    final reqId =
        requestId ?? 'confirm_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      return _router.confirmSuggestion(
        candidate: candidate,
        foodCatalog: foodCatalog,
        imagePath: imagePath,
        requestId: reqId,
        localInferenceDurationMs: localInferenceDurationMs,
        allSuggestions: allSuggestions,
        top1FoodId: top1FoodId,
        scanSessionId: reqId,
      );
    }

    final effectiveCatalog = foodCatalog.isNotEmpty
        ? foodCatalog
        : PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    final matched = effectiveCatalog.firstWhere(
      (f) => f.id == candidate.foodId,
      orElse: () => throw const FoodScanFailure(
        type: FoodScanFailureType.invalidRequest,
        title: FoodScanErrorCopy.unknownTitle,
        message: 'Selected food was not found in the FitFuel catalog.',
      ),
    );

    return FoodScanResult(
      id: reqId,
      imagePath: imagePath,
      foods: [
        DetectedFoodCandidate(
          id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}',
          detectedName: matched.name,
          confidence: candidate.confidence,
          estimatedAmount: matched.servingSize,
          originalEstimatedAmount: matched.servingSize,
          estimatedUnit: matched.servingUnit,
          matchedFood: matched,
          matchConfidence: 1.0,
          visualNotes: 'Confirmed from local suggestions',
          aiEstimatedNutrition: null,
          recognitionSource: FoodScanRecognitionSource.localSuggestionConfirmed,
          isUserConfirmed: true,
        ),
      ],
      overallConfidence: candidate.confidence,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.localSuggestionConfirmed,
      localConfidence: candidate.confidence,
      localInferenceDurationMs: localInferenceDurationMs,
      localCandidates:
          allSuggestions.isNotEmpty ? allSuggestions : [candidate],
    );
  }

  @override
  FoodScanResult confirmOpenVocabCandidate({
    required OpenVocabularyFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    String? requestId,
    int? localInferenceDurationMs,
    List<OpenVocabularyFoodCandidate> allCandidates = const [],
    String? top1CanonicalId,
  }) {
    final reqId =
        requestId ?? 'openvocab_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      return _router.confirmOpenVocabCandidate(
        candidate: candidate,
        foodCatalog: foodCatalog,
        imagePath: imagePath,
        requestId: reqId,
        localInferenceDurationMs: localInferenceDurationMs,
        allCandidates: allCandidates,
        top1CanonicalId: top1CanonicalId,
        scanSessionId: reqId,
      );
    }

    final matched = TrustedOpenVocabNutritionMapper.resolveTrustedCatalogFood(
      candidate,
      foodCatalog: foodCatalog,
    );

    return FoodScanResult(
      id: reqId,
      imagePath: imagePath,
      foods: [
        DetectedFoodCandidate(
          id: 'openvocab_${DateTime.now().millisecondsSinceEpoch}',
          detectedName: matched?.name ?? candidate.canonicalName,
          confidence: 1.0,
          estimatedAmount: matched?.servingSize ?? 100.0,
          originalEstimatedAmount: matched?.servingSize ?? 100.0,
          estimatedUnit: matched?.servingUnit ?? 'g',
          matchedFood: matched,
          matchConfidence: matched != null ? 1.0 : 0.0,
          visualNotes: matched != null
              ? 'Confirmed from on-device food recognition'
              : 'Confirmed by you • Select a FitFuel nutrition profile before logging',
          aiEstimatedNutrition: null,
          recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
          isUserConfirmed: true,
        ),
      ],
      overallConfidence: 1.0,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
      localConfidence: candidate.similarity,
      localInferenceDurationMs: localInferenceDurationMs,
      openVocabCandidates:
          allCandidates.isNotEmpty ? allCandidates : [candidate],
    );
  }

  @override
  Future<void> disposeLocalSessions() async {
    await _router?.disposeTier2Session();
  }

  @override
  FoodScanResult recordManualFoodSelection({
    required FoodEntity food,
    double? amount,
    required String imagePath,
    String? requestId,
  }) {
    final reqId =
        requestId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      return _router.recordManualSelection(
        food: food,
        amount: amount,
        imagePath: imagePath,
        requestId: reqId,
        scanSessionId: reqId,
      );
    }

    final servingAmount = amount ?? food.servingSize;
    return FoodScanResult(
      id: reqId,
      imagePath: imagePath,
      foods: [
        DetectedFoodCandidate(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          detectedName: food.name,
          confidence: 1.0,
          estimatedAmount: servingAmount,
          originalEstimatedAmount: food.servingSize,
          estimatedUnit: food.servingUnit,
          matchedFood: food,
          matchConfidence: 1.0,
          visualNotes: 'Selected manually from FitFuel catalog',
          aiEstimatedNutrition: null,
          recognitionSource: FoodScanRecognitionSource.manual,
          isUserConfirmed: true,
        ),
      ],
      overallConfidence: 1.0,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.manual,
    );
  }

  @override
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
  }) async {
    final reqId = requestId ?? 'scan_${DateTime.now().millisecondsSinceEpoch}';
    if (_router != null) {
      // Phase 35.10.1 Lock: When a router is configured, legacy scanFoodImage
      // internally calls free-first routing by default and NEVER auto-starts Gemini.
      final decision = await evaluateFreeFirstScan(
        imagePath: imagePath,
        imageBytes: imageBytes,
        foodCatalog: foodCatalog,
        requestId: reqId,
      );
      return switch (decision) {
        LocalAutoAccepted(:final result) => result,
        Tier2OpenVocabSuggestionsAvailable(
          :final candidates,
          :final openVocabResult
        ) =>
          FoodScanResult(
            id: reqId,
            imagePath: imagePath,
            foods: const [],
            overallConfidence: openVocabResult.topSimilarity,
            scannedAt: DateTime.now(),
            recognitionSource:
                FoodScanRecognitionSource.openVocabularyConfirmed,
            localConfidence: openVocabResult.topSimilarity,
            localInferenceDurationMs: decision.localInferenceDurationMs,
            openVocabCandidates: candidates,
          ),
        LocalSuggestionsAvailable(:final suggestions, :final prediction) =>
          FoodScanResult(
            id: reqId,
            imagePath: imagePath,
            foods: const [],
            overallConfidence: prediction?.confidence ?? 0.0,
            scannedAt: DateTime.now(),
            recognitionSource:
                FoodScanRecognitionSource.localSuggestionConfirmed,
            localConfidence: prediction?.confidence,
            localInferenceDurationMs: decision.localInferenceDurationMs,
            localCandidates: suggestions,
          ),
        MixedMealNeedsDecision(:final suggestions, :final prediction) =>
          FoodScanResult(
            id: reqId,
            imagePath: imagePath,
            foods: const [],
            overallConfidence: prediction?.confidence ?? 0.0,
            scannedAt: DateTime.now(),
            recognitionSource: FoodScanRecognitionSource.manual,
            localConfidence: prediction?.confidence,
            localInferenceDurationMs: decision.localInferenceDurationMs,
            localCandidates: suggestions,
          ),
        LocalModelUnavailable(:final prediction) ||
        CloudRequired(:final prediction) =>
          FoodScanResult(
            id: reqId,
            imagePath: imagePath,
            foods: const [],
            overallConfidence: prediction?.confidence ?? 0.0,
            scannedAt: DateTime.now(),
            recognitionSource: FoodScanRecognitionSource.manual,
            localConfidence: prediction?.confidence,
            localInferenceDurationMs: decision.localInferenceDurationMs,
          ),
      };
    }
    return await _scanViaRemoteDataSource(
      imagePath: imagePath,
      imageBytes: imageBytes,
      foodCatalog: foodCatalog,
      reqId: reqId,
    );
  }

  Future<FoodScanResult> _scanViaRemoteDataSource({
    required String imagePath,
    required Uint8List imageBytes,
    required List<FoodEntity> foodCatalog,
    required String reqId,
  }) async {
    try {
      final rawFoods = await _remoteDataSource.analyzeMealImage(
        imageBytes,
        requestId: reqId,
      );

      final List<DetectedFoodCandidate> candidates = [];

      for (var i = 0; i < rawFoods.length; i++) {
        final raw = rawFoods[i];

        // 1. Database-first matching: check if trusted FitFuel food match exists
        final matchResult = FoodMatcher.match(raw.name, foodCatalog);

        EstimatedNutrition? resolvedNutrition;

        if (matchResult.isMatched) {
          // Trusted database match exists: use database nutrition, ignore AI macros, 0 extra requests
          resolvedNutrition = null;
        } else if (raw.estimatedNutrition != null) {
          // Unmatched food with already complete AI macros (all 4 fields present): 0 extra requests
          resolvedNutrition = raw.estimatedNutrition;
        } else {
          // Unmatched food with incomplete AI macros: attempt ONE small text-only repair request
          try {
            resolvedNutrition = await _remoteDataSource.repairNutrition(
              foodName: raw.name,
              estimatedGrams: raw.estimatedGrams,
            );
          } catch (_) {
            resolvedNutrition = null;
          }
        }

        candidates.add(
          DetectedFoodCandidate(
            id: 'detected_${i}_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: raw.name,
            confidence: raw.confidence,
            estimatedAmount: raw.estimatedGrams,
            originalEstimatedAmount: raw.estimatedGrams,
            estimatedUnit: raw.unit,
            matchedFood: matchResult.isMatched ? matchResult.food : null,
            matchConfidence:
                matchResult.isMatched ? matchResult.matchScore : 0.0,
            visualNotes: raw.visualNotes,
            aiEstimatedNutrition: resolvedNutrition,
          ),
        );
      }

      final overallConfidence = candidates.isEmpty
          ? 0.0
          : candidates.fold(0.0, (sum, f) => sum + f.confidence) /
              candidates.length;

      return FoodScanResult(
        id: reqId,
        imagePath: imagePath,
        foods: candidates,
        overallConfidence: overallConfidence,
        scannedAt: DateTime.now(),
      );
    } on FoodScanException catch (e) {
      throw FoodScanFailure.fromType(
        e.type,
        messageOverride: e.message,
        retryAfterSeconds: e.retryAfterSeconds,
        statusCode: e.statusCode,
      );
    } on ModelUnavailableException catch (e) {
      throw FoodScanFailure.fromType(
        FoodScanFailureType.modelUnavailable,
        messageOverride: e.message,
        statusCode: e.statusCode,
      );
    } on NetworkException catch (e) {
      throw FoodScanFailure.fromType(
        FoodScanFailureType.offline,
        messageOverride: e.message,
      );
    } on ServerException catch (e) {
      final statusCode = e.statusCode;
      if (statusCode == 404) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.modelUnavailable,
          statusCode: 404,
        );
      }
      if (statusCode == 429) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.rateLimited,
          statusCode: 429,
        );
      }
      if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.serviceUnavailable,
          statusCode: statusCode,
        );
      }
      if (statusCode == 408 || statusCode == 504) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.timeout,
          statusCode: statusCode,
        );
      }
      if (statusCode == 401) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.unauthorized,
          statusCode: 401,
        );
      }
      if (statusCode == 403) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.forbidden,
          statusCode: 403,
        );
      }
      if (statusCode == 400) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.invalidRequest,
          statusCode: 400,
        );
      }
      throw FoodScanFailure.fromType(
        FoodScanFailureType.unknownServiceFailure,
        statusCode: statusCode,
      );
    } catch (e) {
      if (e is FoodScanFailure) rethrow;
      if (e is Failure) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.unknownServiceFailure,
          messageOverride: e.message,
        );
      }
      if (kDebugMode) {
        debugPrint('[FoodScan] Unexpected error in repository: $e');
      }
      // Never expose technical exception text or raw details to presentation layer
      throw FoodScanFailure.fromType(
        FoodScanFailureType.unknownServiceFailure,
        messageOverride: FoodScanErrorCopy.unknownMessage,
      );
    }
  }
}
