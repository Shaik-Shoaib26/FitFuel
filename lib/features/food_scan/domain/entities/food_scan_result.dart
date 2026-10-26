import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';

/// Aggregated result of an AI meal scan containing all detected food candidates,
/// total scaled calories & macros, and analysis metadata.
class FoodScanResult {
  final String id;
  final String? imagePath;
  final List<DetectedFoodCandidate> foods;
  final double overallConfidence;
  final DateTime scannedAt;

  /// Phase 35.9 / 35.11B hybrid & two-tier local scan provenance:
  final FoodScanRecognitionSource recognitionSource;
  final double? localConfidence;
  final int? localInferenceDurationMs;
  final List<LocalFoodCandidate> localCandidates;
  final List<OpenVocabularyFoodCandidate> openVocabCandidates;

  const FoodScanResult({
    required this.id,
    this.imagePath,
    required this.foods,
    required this.overallConfidence,
    required this.scannedAt,
    this.recognitionSource = FoodScanRecognitionSource.gemini,
    this.localConfidence,
    this.localInferenceDurationMs,
    this.localCandidates = const [],
    this.openVocabCandidates = const [],
  });

  /// True if successfully recognized automatically via an on-device model without cloud calls (Tier 1 or Tier 2).
  bool get isRecognizedOnDevice =>
      recognitionSource == FoodScanRecognitionSource.localModel ||
      recognitionSource == FoodScanRecognitionSource.openVocabularyPrimary;

  /// True if completed via user confirmation of a local Top-K suggestion (0 cloud calls).
  bool get isLocalSuggestionConfirmed =>
      recognitionSource == FoodScanRecognitionSource.localSuggestionConfirmed;

  /// True if representing an unconfirmed Tier-2 primary local suggestion (0 cloud requests).
  bool get isOpenVocabularyPrimarySuggested =>
      recognitionSource ==
      FoodScanRecognitionSource.openVocabularyPrimarySuggested;

  /// Phase 35.11B.1: True if representing a Tier-2 single primary local result (0 cloud requests).
  bool get isOpenVocabularyPrimary =>
      recognitionSource == FoodScanRecognitionSource.openVocabularyPrimary ||
      recognitionSource ==
          FoodScanRecognitionSource.openVocabularyPrimarySuggested;

  /// True if completed via user confirmation of a Tier-2 open-vocabulary local suggestion (0 cloud requests).
  bool get isOpenVocabularyConfirmed =>
      recognitionSource == FoodScanRecognitionSource.openVocabularyConfirmed;

  /// True if the result originated from Tier-2 open-vocabulary recognition (primary or confirmed).
  bool get isOpenVocabulary =>
      isOpenVocabularyConfirmed || isOpenVocabularyPrimary;

  /// True if completed via manual FitFuel catalog search (0 cloud requests).
  bool get isManualSelection =>
      recognitionSource == FoodScanRecognitionSource.manual;

  /// True if scan completed without invoking Gemini cloud analysis.
  bool get isCompletedWithoutCloud =>
      recognitionSource == FoodScanRecognitionSource.localModel ||
      recognitionSource == FoodScanRecognitionSource.localSuggestionConfirmed ||
      recognitionSource == FoodScanRecognitionSource.openVocabularyPrimary ||
      recognitionSource ==
          FoodScanRecognitionSource.openVocabularyPrimarySuggested ||
      recognitionSource == FoodScanRecognitionSource.openVocabularyConfirmed ||
      recognitionSource == FoodScanRecognitionSource.manual;

  /// True when the scan result was confirmed or selected by the user.
  bool get isUserConfirmed =>
      recognitionSource.isUserConfirmed ||
      (foods.isNotEmpty && foods.every((f) => f.isConfirmedByUser));

  /// User-facing source badge label for the scan result screen.
  String get sourceBadgeLabel => recognitionSource.sourceBadgeLabel;

  /// Optional secondary source detail for user-confirmed open-vocab results.
  String? get secondarySourceDetail => recognitionSource.secondarySourceDetail;

  /// Canonical debug telemetry route string (`route=auto_local`, `route=local_suggestion`, `route=tier2_open_vocab_confirmed`, `route=manual`, `route=gemini`).
  String get debugRoute => 'route=${recognitionSource.debugRouteLabel}';

  bool get isEmpty => foods.isEmpty;

  bool get hasUnmatchedFoods => foods.any((f) => !f.isMatched);

  /// True if any food relies on AI estimate fallback rather than trusted DB.
  bool get hasAiEstimatedFoods => foods.any((f) => f.isAiEstimated);

  /// True if any food has uncertain or missing nutrition.
  bool get hasUncertainNutrition => foods.any((f) => f.isNutritionUncertain);

  /// True if any food is missing one or more required macronutrients (calories, protein, carbs, fat).
  bool get hasIncompleteNutrition => foods.any((f) => !f.hasNutrition);

  /// True if all food candidates have complete nutrition and can safely be logged.
  bool get canBeLogged => foods.isNotEmpty && foods.every((f) => f.hasNutrition);

  /// List of foods that lack complete nutrition and need confirmation.
  List<DetectedFoodCandidate> get unresolvedFoods =>
      foods.where((f) => !f.hasNutrition).toList();

  /// True if the detection overall or individual items have weak confidence and are not user-confirmed.
  bool get isLowConfidence =>
      !isUserConfirmed &&
      (overallConfidence < 0.60 || foods.any((f) => f.isLowConfidence));

  /// Combined total calories across all detected food components
  double get totalCalories =>
      foods.fold(0.0, (sum, food) => sum + food.scaledCalories);

  double get totalProtein =>
      foods.fold(0.0, (sum, food) => sum + food.scaledProtein);

  double get totalCarbs =>
      foods.fold(0.0, (sum, food) => sum + food.scaledCarbs);

  double get totalFats =>
      foods.fold(0.0, (sum, food) => sum + food.scaledFats);

  /// Total calories across all components, or null if any component lacks nutrition data.
  /// Prevents converting missing nutrition values into zero.
  double? get verifiedTotalCalories {
    if (foods.any((f) => f.calories == null)) return null;
    return foods.fold<double>(0.0, (sum, f) => sum + f.scaledCalories);
  }

  /// Total protein (g) across all components, or null if any component lacks nutrition data.
  double? get verifiedTotalProtein {
    if (foods.any((f) => f.protein == null)) return null;
    return foods.fold<double>(0.0, (sum, f) => sum + f.scaledProtein);
  }

  /// Total carbs (g) across all components, or null if any component lacks nutrition data.
  double? get verifiedTotalCarbs {
    if (foods.any((f) => f.carbs == null)) return null;
    return foods.fold<double>(0.0, (sum, f) => sum + f.scaledCarbs);
  }

  /// Total fats (g) across all components, or null if any component lacks nutrition data.
  double? get verifiedTotalFats {
    if (foods.any((f) => f.fats == null)) return null;
    return foods.fold<double>(0.0, (sum, f) => sum + f.scaledFats);
  }

  /// True if at least one food item has trusted secondary nutrition fields (fiber, sugar, or sodium).
  bool get hasMoreNutrition => foods.any((f) => f.hasSecondaryNutrition);

  /// Combined total fiber (g) across foods with trusted fiber data, or null if unavailable.
  double? get totalFiber {
    final values = foods.map((f) => f.fiber).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.fold<double>(0.0, (sum, v) => sum + v);
  }

  /// Combined total sugar (g) across foods with trusted sugar data, or null if unavailable.
  double? get totalSugar {
    final values = foods.map((f) => f.sugar).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.fold<double>(0.0, (sum, v) => sum + v);
  }

  /// Combined total sodium (mg) across foods with trusted sodium data, or null if unavailable.
  double? get totalSodium {
    final values = foods.map((f) => f.sodium).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.fold<double>(0.0, (sum, v) => sum + v);
  }

  FoodScanResult copyWith({
    String? id,
    String? imagePath,
    List<DetectedFoodCandidate>? foods,
    double? overallConfidence,
    DateTime? scannedAt,
    FoodScanRecognitionSource? recognitionSource,
    double? localConfidence,
    int? localInferenceDurationMs,
    List<LocalFoodCandidate>? localCandidates,
    List<OpenVocabularyFoodCandidate>? openVocabCandidates,
  }) {
    return FoodScanResult(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      foods: foods ?? this.foods,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      scannedAt: scannedAt ?? this.scannedAt,
      recognitionSource: recognitionSource ?? this.recognitionSource,
      localConfidence: localConfidence ?? this.localConfidence,
      localInferenceDurationMs:
          localInferenceDurationMs ?? this.localInferenceDurationMs,
      localCandidates: localCandidates ?? this.localCandidates,
      openVocabCandidates: openVocabCandidates ?? this.openVocabCandidates,
    );
  }
}
