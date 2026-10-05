import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';

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
  });

  ScanConfidenceLevel get confidenceLevel {
    if (confidence >= 0.80) return ScanConfidenceLevel.high;
    if (confidence >= 0.60) return ScanConfidenceLevel.medium;
    return ScanConfidenceLevel.low;
  }

  /// Whether the AI recognition confidence is weak.
  bool get isLowConfidence => confidence < 0.60;

  /// Whether a trusted FitFuel catalog match was found.
  bool get isMatched => matchedFood != null;

  /// Whether nutrition is derived from a trusted database match.
  bool get isDatabaseMatch => matchedFood != null;

  /// Whether nutrition is derived from an AI estimate fallback.
  bool get isAiEstimated => matchedFood == null && aiEstimatedNutrition != null;

  /// Human-readable food display name.
  String get displayName => matchedFood?.name ?? detectedName;

  /// Human-readable source indicator label for UI.
  String get nutritionSourceLabel {
    if (isDatabaseMatch) return 'Database Match';
    if (isAiEstimated) return 'AI Estimate • Needs confirmation';
    return 'Nutrition Unavailable • Needs confirmation';
  }

  /// True if all 4 macronutrients are determined (non-null).
  bool get hasNutrition =>
      calories != null && protein != null && carbs != null && fats != null;

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
    );
  }
}
