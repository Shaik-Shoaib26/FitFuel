import '../../../../core/sync/sync_status.dart';
import '../../../food_scan/domain/entities/nutrition_profile_tier.dart';

class NutritionRecordEntity {
  final String id;
  final String foodName;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double sugar;
  final double? fiber;
  final double? sodium;
  final double servingSize;
  final String? foodId;
  final double? baseServingSize;
  final double? baseCalories;
  final double? baseProtein;
  final double? baseCarbohydrates;
  final double? baseFats;
  final double? baseFiber;
  final double? baseSugar;
  final double? baseSodium;
  final NutritionProfileTier? nutritionTier;
  final String? nutritionAttribution;
  final String? recipeAssumptions;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const NutritionRecordEntity({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.sugar,
    this.fiber,
    this.sodium,
    required this.servingSize,
    this.foodId,
    this.baseServingSize,
    this.baseCalories,
    this.baseProtein,
    this.baseCarbohydrates,
    this.baseFats,
    this.baseFiber,
    this.baseSugar,
    this.baseSodium,
    this.nutritionTier,
    this.nutritionAttribution,
    this.recipeAssumptions,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
  });

  /// True when this food candidate represents user-entered manual nutrition.
  bool get isUserEnteredNutrition =>
      nutritionAttribution == 'User-entered nutrition' ||
      (foodId != null && (foodId!.startsWith('manual_') || foodId == 'custom'));

  /// True if dietary fiber is explicitly recorded (including known measured 0.0).
  bool get hasFiber => fiber != null;

  /// True if sodium is explicitly recorded (including known measured 0.0).
  bool get hasSodium => sodium != null;

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
    return nutritionAttribution ?? 'Curated FitFuel Food Database';
  }

  NutritionRecordEntity copyWith({
    String? id,
    String? foodName,
    String? mealType,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    double? sugar,
    double? fiber,
    double? sodium,
    double? servingSize,
    String? foodId,
    double? baseServingSize,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbohydrates,
    double? baseFats,
    double? baseFiber,
    double? baseSugar,
    double? baseSodium,
    NutritionProfileTier? nutritionTier,
    String? nutritionAttribution,
    String? recipeAssumptions,
    DateTime? consumedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return NutritionRecordEntity(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fats: fats ?? this.fats,
      sugar: sugar ?? this.sugar,
      fiber: fiber ?? this.fiber,
      sodium: sodium ?? this.sodium,
      servingSize: servingSize ?? this.servingSize,
      foodId: foodId ?? this.foodId,
      baseServingSize: baseServingSize ?? this.baseServingSize,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbohydrates: baseCarbohydrates ?? this.baseCarbohydrates,
      baseFats: baseFats ?? this.baseFats,
      baseFiber: baseFiber ?? this.baseFiber,
      baseSugar: baseSugar ?? this.baseSugar,
      baseSodium: baseSodium ?? this.baseSodium,
      nutritionTier: nutritionTier ?? this.nutritionTier,
      nutritionAttribution: nutritionAttribution ?? this.nutritionAttribution,
      recipeAssumptions: recipeAssumptions ?? this.recipeAssumptions,
      consumedAt: consumedAt ?? this.consumedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionRecordEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          foodName == other.foodName &&
          mealType == other.mealType &&
          calories == other.calories &&
          protein == other.protein &&
          carbohydrates == other.carbohydrates &&
          fats == other.fats &&
          sugar == other.sugar &&
          fiber == other.fiber &&
          sodium == other.sodium &&
          servingSize == other.servingSize &&
          foodId == other.foodId &&
          nutritionTier == other.nutritionTier &&
          consumedAt == other.consumedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      foodName.hashCode ^
      mealType.hashCode ^
      calories.hashCode ^
      protein.hashCode ^
      carbohydrates.hashCode ^
      fats.hashCode ^
      sugar.hashCode ^
      fiber.hashCode ^
      sodium.hashCode ^
      servingSize.hashCode ^
      foodId.hashCode ^
      nutritionTier.hashCode ^
      consumedAt.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
