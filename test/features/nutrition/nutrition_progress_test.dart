import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_calculator.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  final testGoal = NutritionGoalsEntity(
    userId: 'test_user',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: today,
  );

  final breakfast = NutritionRecordEntity(
    id: 'b1',
    foodName: 'Oats & Banana',
    mealType: 'Breakfast',
    calories: 400.0,
    protein: 10.0,
    carbohydrates: 70.0,
    fats: 5.0,
    sugar: 12.0,
    servingSize: 150.0,
    consumedAt: today,
    createdAt: today,
    updatedAt: today,
  );

  final lunch = NutritionRecordEntity(
    id: 'l1',
    foodName: 'Rice & Salmon',
    mealType: 'Lunch',
    calories: 600.0,
    protein: 40.0,
    carbohydrates: 50.0,
    fats: 20.0,
    sugar: 0.0,
    servingSize: 300.0,
    consumedAt: today,
    createdAt: today,
    updatedAt: today,
  );

  final oldSnack = NutritionRecordEntity(
    id: 's1',
    foodName: 'Almonds',
    mealType: 'Snack',
    calories: 150.0,
    protein: 5.0,
    carbohydrates: 5.0,
    fats: 12.0,
    sugar: 1.0,
    servingSize: 30.0,
    consumedAt: yesterday,
    createdAt: yesterday,
    updatedAt: yesterday,
  );

  group('Nutrition Calculator Tests', () {
    test('Correctly filters records by day', () {
      final list = [breakfast, lunch, oldSnack];
      final filtered = NutritionCalculator.filterByDay(list, today);
      expect(filtered.length, 2);
      expect(filtered.contains(breakfast), isTrue);
      expect(filtered.contains(lunch), isTrue);
      expect(filtered.contains(oldSnack), isFalse);
    });

    test('Computes totals and goals progress correctly', () {
      final dailyRecords = [breakfast, lunch];
      final stats = NutritionCalculator.calculateProgress(
        dailyRecords: dailyRecords,
        goals: testGoal,
      );

      // Expected values:
      // Calories: 400 + 600 = 1000 (Goal: 2000 => 50% / 0.5)
      // Protein: 10 + 40 = 50 (Goal: 100 => 50% / 0.5)
      // Carbs: 70 + 50 = 120 (Goal: 200 => 60% / 0.6)
      // Fats: 5 + 20 = 25 (Goal: 50 => 50% / 0.5)

      expect(stats.totalCalories, 1000.0);
      expect(stats.totalProtein, 50.0);
      expect(stats.totalCarbs, 120.0);
      expect(stats.totalFats, 25.0);

      expect(stats.calorieProgress, 0.5);
      expect(stats.proteinProgress, 0.5);
      expect(stats.carbsProgress, 0.6);
      expect(stats.fatProgress, 0.5);
    });

    test('Handles empty records list gracefully', () {
      final stats = NutritionCalculator.calculateProgress(
        dailyRecords: [],
        goals: testGoal,
      );

      expect(stats.totalCalories, 0.0);
      expect(stats.totalProtein, 0.0);
      expect(stats.totalCarbs, 0.0);
      expect(stats.totalFats, 0.0);

      expect(stats.calorieProgress, 0.0);
      expect(stats.proteinProgress, 0.0);
      expect(stats.carbsProgress, 0.0);
      expect(stats.fatProgress, 0.0);
    });

    test('Handles missing/null goals with default target calculations', () {
      final dailyRecords = [breakfast];
      final stats = NutritionCalculator.calculateProgress(
        dailyRecords: dailyRecords,
        goals: null,
      );

      // Defaults to CalorieGoal: 2000, ProteinGoal: 150, CarbsGoal: 200, FatGoal: 65
      // Breakfast Calories: 400 => 400 / 2000 = 0.2
      // Breakfast Protein: 10 => 10 / 150 = 0.0667

      expect(stats.totalCalories, 400.0);
      expect(stats.calorieProgress, 0.2);
      expect(stats.proteinProgress, closeTo(0.0667, 0.001));
    });
  });
}
