import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_nutrition_calculator.dart';

void main() {
  group('Food Nutrition Calculator Tests', () {
    const baseFood = FoodEntity(
      id: '1',
      name: 'Test Food',
      category: 'Custom',
      servingSize: 100,
      servingUnit: 'g',
      calories: 150,
      protein: 10,
      carbohydrates: 20,
      fats: 5,
      fiber: 4,
      sugar: 8,
      sodium: 120,
    );

    test('100g calculation', () {
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: 100);
      expect(scaled.calories, 150);
      expect(scaled.protein, 10);
      expect(scaled.carbohydrates, 20);
      expect(scaled.fats, 5);
      expect(scaled.fiber, 4);
      expect(scaled.sugar, 8);
      expect(scaled.sodium, 120);
    });

    test('200g calculation', () {
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: 200);
      expect(scaled.calories, 300);
      expect(scaled.protein, 20);
      expect(scaled.carbohydrates, 40);
      expect(scaled.fats, 10);
      expect(scaled.fiber, 8);
      expect(scaled.sugar, 16);
      expect(scaled.sodium, 240);
    });

    test('Fractional serving', () {
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: 50);
      expect(scaled.calories, 75);
      expect(scaled.protein, 5);
      expect(scaled.carbohydrates, 10);
      expect(scaled.fats, 2.5);
      expect(scaled.fiber, 2);
      expect(scaled.sugar, 4);
      expect(scaled.sodium, 60);
    });

    test('Zero serving validation', () {
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: 0);
      expect(scaled.servingSize, 0);
      expect(scaled.calories, 0);
      expect(scaled.protein, 0);
      expect(scaled.carbohydrates, 0);
      expect(scaled.fats, 0);
      expect(scaled.fiber, 0);
      expect(scaled.sugar, 0);
      expect(scaled.sodium, 0);
    });

    test('Negative serving validation', () {
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: -50);
      expect(scaled.servingSize, 0);
      expect(scaled.calories, 0);
    });
  });
}
