import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';

enum ScanConfidenceLevel {
  high,
  medium,
  low,
}

/// Represents an individual food item detected in a scanned meal photo,
/// its portion estimate, matched database entity (if present),
/// AI-estimated fallback nutrition (if unmatched), and scaled nutrition.
class DetectedFoodCandidate {
  final String id;
  final String detectedName;
  final double confidence; // 0.0 - 1.0
  final double estimatedAmount;
  final double? originalEstimatedAmount;
  final String estimatedUnit;
  final FoodEntity? matchedFood;
  final double matchConfidence;
  final String? visualNotes;
  final EstimatedNutrition? aiEstimatedNutrition;
  final FoodScanRecognitionSource? recognitionSource;
  final bool isUserConfirmed;
  final NutritionProfileTier? nutritionTier;
  final String? nutritionExplanation;
  final String? recipeAssumptions;
  final String? nutritionAttribution;

  const DetectedFoodCandidate({
    required this.id,
    required this.detectedName,
    required this.confidence,
    required this.estimatedAmount,
    this.originalEstimatedAmount,
    this.estimatedUnit = 'g',
    this.matchedFood,
    this.matchConfidence = 0.0,
    this.visualNotes,
    this.aiEstimatedNutrition,
    this.recognitionSource,
    this.isUserConfirmed = false,
    this.nutritionTier,
    this.nutritionExplanation,
    this.recipeAssumptions,
    this.nutritionAttribution,
  });

  /// True when the user explicitly confirmed this food via local suggestion or manual search/change.
  bool get isConfirmedByUser =>
      isUserConfirmed || (recognitionSource?.isUserConfirmed ?? false);

  ScanConfidenceLevel get confidenceLevel {
    if (confidence >= 0.80) return ScanConfidenceLevel.high;
    if (confidence >= 0.60) return ScanConfidenceLevel.medium;
    return ScanConfidenceLevel.low;
  }

  /// Whether recognition confidence is weak for an unconfirmed prediction.
  /// Once confirmed by the user or presented as a gated Tier-2 primary single result,
  /// raw similarity/confidence never triggers low-confidence warnings.
  bool get isLowConfidence =>
      !isConfirmedByUser &&
      recognitionSource != FoodScanRecognitionSource.openVocabularyPrimary &&
      recognitionSource !=
          FoodScanRecognitionSource.openVocabularyPrimarySuggested &&
      confidence < 0.60;

  /// Whether a trusted FitFuel catalog match was found.
  bool get isMatched => matchedFood != null;

  /// Whether nutrition is derived from a trusted database match.
  bool get isDatabaseMatch => matchedFood != null;

  /// Whether nutrition is derived from an AI estimate fallback.
  bool get isAiEstimated => matchedFood == null && aiEstimatedNutrition != null;

  /// Human-readable food display name.
  String get displayName => matchedFood?.name ?? detectedName;

  /// True when this food candidate represents user-entered manual nutrition.
  bool get isUserEnteredNutrition =>
      nutritionAttribution == 'User-entered nutrition' ||
      (matchedFood != null &&
          (matchedFood!.id.startsWith('manual_') ||
              (matchedFood!.isCustom && nutritionTier == null))) ||
      (recognitionSource == FoodScanRecognitionSource.manual &&
          (matchedFood == null || matchedFood!.id.startsWith('manual_')));

  /// Human-readable source indicator label for UI.
  String get nutritionSourceLabel {
    if (isUserEnteredNutrition) {
      return 'User-entered nutrition';
    }
    if (nutritionTier != null) {
      switch (nutritionTier!) {
        case NutritionProfileTier.verifiedExact:
          return 'Curated FitFuel Food Database';
        case NutritionProfileTier.closelyRelatedGeneric:
          final isUsda = nutritionAttribution != null &&
              (nutritionAttribution!.contains('USDA') ||
                  nutritionAttribution!.contains('Department of Agriculture'));
          return isUsda ? 'USDA Generic Baseline' : 'Generic Nutrition Baseline';
        case NutritionProfileTier.recipeEstimate:
          return 'Recipe Estimate';
        case NutritionProfileTier.unavailable:
          return 'Nutrition Unavailable';
      }
    }
    if (isDatabaseMatch) return 'Curated FitFuel Food Database';
    if (isAiEstimated) return 'AI Estimate • Needs confirmation';
    return 'Needs confirmation';
  }

  /// True if all 4 macronutrients are determined (non-null).
  bool get hasNutrition =>
      calories != null && protein != null && carbs != null && fats != null;

  /// True if trusted secondary nutrition fields (fiber, sugar, sodium) are available.
  bool get hasSecondaryNutrition =>
      fiber != null || sugar != null || sodium != null;

  /// True if nutrition requires user review/confirmation.
  bool get isNutritionUncertain => !hasNutrition || isAiEstimated || isLowConfidence;

  /// Nullable Calories (kcal). Returns null if nutrition is undetermined.
  double? get calories {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.calories);
    }
    if (aiEstimatedNutrition != null) {
      return _scaleAi(aiEstimatedNutrition!.calories);
    }
    return null;
  }

  /// Nullable Protein (g). Returns null if nutrition is undetermined.
  double? get protein {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.protein);
    }
    if (aiEstimatedNutrition != null) {
      return _scaleAi(aiEstimatedNutrition!.protein);
    }
    return null;
  }

  /// Nullable Carbs (g). Returns null if nutrition is undetermined.
  double? get carbs {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.carbohydrates);
    }
    if (aiEstimatedNutrition != null) {
      return _scaleAi(aiEstimatedNutrition!.carbs);
    }
    return null;
  }

  /// Nullable Fat (g). Returns null if nutrition is undetermined.
  /// Note: A true zero value (0.0 g) is preserved and distinct from null.
  double? get fats {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.fats);
    }
    if (aiEstimatedNutrition != null) {
      return _scaleAi(aiEstimatedNutrition!.fat);
    }
    return null;
  }

  /// Nullable Fiber (g) from trusted FitFuel database. Returns null if unknown/unavailable.
  double? get fiber {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.fiber);
    }
    return null;
  }

  /// Nullable Sugar (g) from trusted FitFuel database. Returns null if unknown/unavailable.
  double? get sugar {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.sugar);
    }
    return null;
  }

  /// Nullable Sodium (mg) from trusted FitFuel database. Returns null if unknown/unavailable.
  double? get sodium {
    if (matchedFood != null) {
      return _scaleDb(matchedFood!.sodium);
    }
    return null;
  }

  /// Scaled non-null values for diary logging and display math.
  double get scaledCalories => calories ?? 0.0;
  double get scaledProtein => protein ?? 0.0;
  double get scaledCarbs => carbs ?? 0.0;
  double get scaledFats => fats ?? 0.0;

  double _scaleDb(double perServingValue) {
    if (matchedFood == null) return 0.0;
    final baseServing = matchedFood!.servingSize;
    if (baseServing <= 0) return 0.0;
    final factor = estimatedAmount / baseServing;
    return perServingValue * factor;
  }

  double _scaleAi(double baseValue) {
    final base = (originalEstimatedAmount != null && originalEstimatedAmount! > 0)
        ? originalEstimatedAmount!
        : estimatedAmount;
    if (base <= 0) return baseValue;
    final factor = estimatedAmount / base;
    return baseValue * factor;
  }

  DetectedFoodCandidate copyWith({
    String? id,
    String? detectedName,
    double? confidence,
    double? estimatedAmount,
    double? originalEstimatedAmount,
    String? estimatedUnit,
    FoodEntity? matchedFood,
    double? matchConfidence,
    String? visualNotes,
    EstimatedNutrition? aiEstimatedNutrition,
    FoodScanRecognitionSource? recognitionSource,
    bool? isUserConfirmed,
    NutritionProfileTier? nutritionTier,
    String? nutritionExplanation,
    String? recipeAssumptions,
    String? nutritionAttribution,
  }) {
    return DetectedFoodCandidate(
      id: id ?? this.id,
      detectedName: detectedName ?? this.detectedName,
      confidence: confidence ?? this.confidence,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      originalEstimatedAmount: originalEstimatedAmount ?? this.originalEstimatedAmount,
      estimatedUnit: estimatedUnit ?? this.estimatedUnit,
      matchedFood: matchedFood ?? this.matchedFood,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      visualNotes: visualNotes ?? this.visualNotes,
      aiEstimatedNutrition: aiEstimatedNutrition ?? this.aiEstimatedNutrition,
      recognitionSource: recognitionSource ?? this.recognitionSource,
      isUserConfirmed: isUserConfirmed ?? this.isUserConfirmed,
      nutritionTier: nutritionTier ?? this.nutritionTier,
      nutritionExplanation: nutritionExplanation ?? this.nutritionExplanation,
      recipeAssumptions: recipeAssumptions ?? this.recipeAssumptions,
      nutritionAttribution: nutritionAttribution ?? this.nutritionAttribution,
    );
  }
}
