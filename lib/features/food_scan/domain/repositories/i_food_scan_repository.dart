import 'dart:typed_data';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';

abstract class IFoodScanRepository {
  /// Analyzes a food image via AI vision, detects foods with portions & confidence,
  /// matches them against the FitFuel database [foodCatalog], and returns a [FoodScanResult].
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
  });
}

/// Extended repository contract supporting Phase 35.10 / 35.11B Free-First food scanning:
/// Tier-1 (`fitfuel_food_v5`) + Tier-2 (`SigLIP-B/16 INT8`) open-vocabulary suggestions,
/// user confirmation, manual selection, and optional Gemini AI analysis.
abstract class IFreeFirstFoodScanRepository extends IFoodScanRepository {
  bool get hasFreeFirstRouter;

  FoodScanRecognitionRouter? get router;

  Future<FoodScanRouteDecision> evaluateFreeFirstScan({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  });

  Future<FoodScanResult> analyzeWithAi({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
    LocalFoodPrediction? priorLocalPrediction,
    int localInferenceDurationMs = 0,
    bool isOffline = false,
    bool userRequestedAi = true,
  });

  FoodScanResult confirmLocalSuggestion({
    required LocalFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    String? requestId,
    int? localInferenceDurationMs,
    List<LocalFoodCandidate> allSuggestions = const [],
    String? top1FoodId,
  });

  FoodScanResult confirmOpenVocabCandidate({
    required OpenVocabularyFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    String? requestId,
    int? localInferenceDurationMs,
    List<OpenVocabularyFoodCandidate> allCandidates = const [],
    String? top1CanonicalId,
  });

  FoodScanResult recordManualFoodSelection({
    required FoodEntity food,
    double? amount,
    required String imagePath,
    String? requestId,
  });

  Future<void> disposeLocalSessions() async {}
}
