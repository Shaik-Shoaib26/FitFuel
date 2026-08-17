import 'package:fitfuel/features/food/data/models/food_model.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';

class PlannedFoodModel {
  final FoodModel food;
  final double servingQuantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  const PlannedFoodModel({
    required this.food,
    required this.servingQuantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  factory PlannedFoodModel.fromMap(Map<String, dynamic> data) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return PlannedFoodModel(
      food: FoodModel.fromMap(Map<String, dynamic>.from(data['food'] ?? {}), data['food']?['id'] ?? ''),
      servingQuantity: parseDouble(data['servingQuantity']),
      unit: data['unit'] as String? ?? 'g',
      calories: parseDouble(data['calories']),
      protein: parseDouble(data['protein']),
      carbohydrates: parseDouble(data['carbohydrates']),
      fat: parseDouble(data['fat']),
      fiber: parseDouble(data['fiber']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'food': food.toFirestore()..['id'] = food.id,
      'servingQuantity': servingQuantity,
      'unit': unit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
    };
  }

  factory PlannedFoodModel.fromEntity(PlannedFoodEntity entity) {
    return PlannedFoodModel(
      food: FoodModel.fromEntity(entity.food),
      servingQuantity: entity.servingQuantity,
      unit: entity.unit,
      calories: entity.calories,
      protein: entity.protein,
      carbohydrates: entity.carbohydrates,
      fat: entity.fat,
      fiber: entity.fiber,
    );
  }

  PlannedFoodEntity toEntity() {
    return PlannedFoodEntity(
      food: food.toEntity(),
      servingQuantity: servingQuantity,
      unit: unit,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
    );
  }
}

class PlannedMealModel {
  final String mealType;
  final List<PlannedFoodModel> foods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const PlannedMealModel({
    required this.mealType,
    required this.foods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  factory PlannedMealModel.fromMap(Map<String, dynamic> data) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final foodsList = (data['foods'] as List<dynamic>?) ?? [];
    
    return PlannedMealModel(
      mealType: data['mealType'] as String? ?? '',
      foods: foodsList.map((e) => PlannedFoodModel.fromMap(Map<String, dynamic>.from(e))).toList(),
      totalCalories: parseDouble(data['totalCalories']),
      totalProtein: parseDouble(data['totalProtein']),
      totalCarbs: parseDouble(data['totalCarbs']),
      totalFat: parseDouble(data['totalFat']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mealType': mealType,
      'foods': foods.map((e) => e.toMap()).toList(),
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
    };
  }

  factory PlannedMealModel.fromEntity(PlannedMealEntity entity) {
    return PlannedMealModel(
      mealType: entity.mealType,
      foods: entity.foods.map((e) => PlannedFoodModel.fromEntity(e)).toList(),
      totalCalories: entity.totalCalories,
      totalProtein: entity.totalProtein,
      totalCarbs: entity.totalCarbs,
      totalFat: entity.totalFat,
    );
  }

  PlannedMealEntity toEntity() {
    return PlannedMealEntity(
      mealType: mealType,
      foods: foods.map((e) => e.toEntity()).toList(),
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
    );
  }
}
