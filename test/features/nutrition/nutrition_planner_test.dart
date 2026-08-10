import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/meal_planner_engine.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_planner',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final breakfastLog = NutritionRecordEntity(
    id: 'b1',
    foodName: 'Oats',
    mealType: 'Breakfast',
    calories: 389.0,
    protein: 16.9,
    carbohydrates: 66.3,
    fats: 6.9,
    sugar: 0.0,
    servingSize: 100.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('Meal Planner Engine Tests', () {
    test('Calculates targets distribution split correctly', () {
      final result = MealPlannerEngine.generateMealPlan(
        todayRecords: [],
        goals: testGoal,
      );

      // Daily goal = 2000
      // Breakfast (25%): 500 kcal
      // Lunch (35%): 700 kcal
      // Dinner (30%): 600 kcal
      // Snack (10%): 200 kcal

      expect(result.dailyCalorieGoal, 2000.0);
      expect(result.breakfastSuggestions.first.targetCalories, 500.0);
      expect(result.lunchSuggestions.first.targetCalories, 700.0);
      expect(result.dinnerSuggestions.first.targetCalories, 600.0);
      expect(result.snackSuggestions.first.targetCalories, 200.0);

      // Macros test for Breakfast
      expect(result.breakfastSuggestions.first.targetProtein, 25.0); // 100 * 0.25
      expect(result.breakfastSuggestions.first.targetCarbs, 50.0); // 200 * 0.25
      expect(result.breakfastSuggestions.first.targetFats, 12.5); // 50 * 0.25
    });

    test('Considers logged foods today and penalizes duplicate suggestions', () {
      final result = MealPlannerEngine.generateMealPlan(
        todayRecords: [breakfastLog],
        goals: testGoal,
      );

      // Verify Oats is not the top breakfast suggestion since it was already logged today
      expect(result.breakfastSuggestions.first.food.name != 'Oats', isTrue);
    });

    test('Remaining calories calculation is correct', () {
      final result = MealPlannerEngine.generateMealPlan(
        todayRecords: [breakfastLog],
        goals: testGoal,
      );

      expect(result.remainingCalories, 2000.0 - 389.0);
    });

    test('Handles empty goals with default values gracefully', () {
      final result = MealPlannerEngine.generateMealPlan(
        todayRecords: [],
        goals: null,
      );

      // Calorie fallback = 2000
      expect(result.dailyCalorieGoal, 2000.0);
      expect(result.breakfastSuggestions.isNotEmpty, isTrue);
    });

    test('Handles empty dataset scenarios safely without crashing', () {
      final result = MealPlannerEngine.generateMealPlan(
        todayRecords: [],
        goals: testGoal,
        customDataset: [],
      );

      expect(result.breakfastSuggestions.isEmpty, isTrue);
      expect(result.lunchSuggestions.isEmpty, isTrue);
      expect(result.plannedCalories, 0.0);
    });
  });
}
