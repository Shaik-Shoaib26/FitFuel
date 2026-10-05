import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';

/// Aggregated result of an AI meal scan containing all detected food candidates,
/// total scaled calories & macros, and analysis metadata.
class FoodScanResult {
  final String id;
  final String? imagePath;
  final List<DetectedFoodCandidate> foods;
  final double overallConfidence;
  final DateTime scannedAt;

  const FoodScanResult({
    required this.id,
    this.imagePath,
    required this.foods,
    required this.overallConfidence,
    required this.scannedAt,
  });

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

  /// True if the detection overall or individual items have weak confidence.
  bool get isLowConfidence =>
      overallConfidence < 0.60 || foods.any((f) => f.isLowConfidence);

  /// Combined total calories across all detected food components
  double get totalCalories =>
      foods.fold(0.0, (sum, food) => sum + food.scaledCalories);

  double get totalProtein =>
      foods.fold(0.0, (sum, food) => sum + food.scaledProtein);

  double get totalCarbs =>
      foods.fold(0.0, (sum, food) => sum + food.scaledCarbs);

  double get totalFats =>
      foods.fold(0.0, (sum, food) => sum + food.scaledFats);

  FoodScanResult copyWith({
    String? id,
    String? imagePath,
    List<DetectedFoodCandidate>? foods,
    double? overallConfidence,
    DateTime? scannedAt,
  }) {
    return FoodScanResult(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      foods: foods ?? this.foods,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}
