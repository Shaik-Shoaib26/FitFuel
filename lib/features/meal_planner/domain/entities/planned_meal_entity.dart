import 'package:fitfuel/features/food/domain/entities/food_entity.dart';

class PlannedFoodEntity {
  final FoodEntity food;
  final double servingQuantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  const PlannedFoodEntity({
    required this.food,
    required this.servingQuantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  PlannedFoodEntity copyWith({
    FoodEntity? food,
    double? servingQuantity,
    String? unit,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    double? fiber,
  }) {
    return PlannedFoodEntity(
      food: food ?? this.food,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedFoodEntity &&
          runtimeType == other.runtimeType &&
          food == other.food &&
          servingQuantity == other.servingQuantity &&
          unit == other.unit &&
          calories == other.calories &&
          protein == other.protein &&
          carbohydrates == other.carbohydrates &&
          fat == other.fat &&
          fiber == other.fiber;

  @override
  int get hashCode =>
      food.hashCode ^
      servingQuantity.hashCode ^
      unit.hashCode ^
      calories.hashCode ^
      protein.hashCode ^
      carbohydrates.hashCode ^
      fat.hashCode ^
      fiber.hashCode;
}

class PlannedMealEntity {
  final String mealType; // "Breakfast", "Morning Snack", "Lunch", "Evening Snack", "Dinner"
  final List<PlannedFoodEntity> foods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const PlannedMealEntity({
    required this.mealType,
    this.foods = const [],
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  PlannedMealEntity copyWith({
    String? mealType,
    List<PlannedFoodEntity>? foods,
    double? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
  }) {
    return PlannedMealEntity(
      mealType: mealType ?? this.mealType,
      foods: foods ?? this.foods,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMealEntity &&
          runtimeType == other.runtimeType &&
          mealType == other.mealType &&
          foods == other.foods &&
          totalCalories == other.totalCalories &&
          totalProtein == other.totalProtein &&
          totalCarbs == other.totalCarbs &&
          totalFat == other.totalFat;

  @override
  int get hashCode =>
      mealType.hashCode ^
      foods.hashCode ^
      totalCalories.hashCode ^
      totalProtein.hashCode ^
      totalCarbs.hashCode ^
      totalFat.hashCode;
}
