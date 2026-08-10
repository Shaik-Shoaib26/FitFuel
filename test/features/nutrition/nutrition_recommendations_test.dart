import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/recommendation_engine.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_recommend',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final breakfast = NutritionRecordEntity(
    id: 'b1',
    foodName: 'Oats & Milk',
    mealType: 'Breakfast',
    calories: 400.0,
    protein: 15.0,
    carbohydrates: 60.0,
    fats: 6.0,
    sugar: 8.0,
    servingSize: 150.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final heavyLunch = NutritionRecordEntity(
    id: 'l1',
    foodName: 'High Fat Cheese Meal',
    mealType: 'Lunch',
    calories: 1000.0,
    protein: 40.0,
    carbohydrates: 20.0,
    fats: 45.0,
    sugar: 2.0,
    servingSize: 400.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('Recommendation Engine Tests', () {
    test('Calculates remaining calories and macros correctly', () {
      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [breakfast],
        goals: testGoal,
      );

      // Remaining:
      // Calories: 2000 - 400 = 1600
      // Protein: 100 - 15 = 85
      // Carbs: 200 - 60 = 140
      // Fats: 50 - 6 = 44

      expect(result.remainingCalories, 1600.0);
      expect(result.remainingProtein, 85.0);
      expect(result.remainingCarbs, 140.0);
      expect(result.remainingFats, 44.0);

      expect(result.isCalorieExceeded, isFalse);
      expect(result.isProteinExceeded, isFalse);
      expect(result.isCarbsExceeded, isFalse);
      expect(result.isFatExceeded, isFalse);
    });

    test('Identifies exceeded goals accurately', () {
      final hugeSnack = NutritionRecordEntity(
        id: 's1',
        foodName: 'Huge Cheat Meal',
        mealType: 'Snack',
        calories: 1800.0,
        protein: 70.0,
        carbohydrates: 150.0,
        fats: 20.0,
        sugar: 15.0,
        servingSize: 500.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [breakfast, hugeSnack],
        goals: testGoal,
      );

      // Consumed Calories: 400 + 1800 = 2200 (Goal: 2000)
      // Consumed Carbs: 60 + 150 = 210 (Goal: 200)

      expect(result.isCalorieExceeded, isTrue);
      expect(result.isCarbsExceeded, isTrue);
      expect(result.remainingCalories, 0.0);
      expect(result.remainingCarbs, 0.0);
    });

    test('Generates correct insight for on-track goals', () {
      // Consumed: Calories 1700, Protein 90, Carbs 180, Fats 40 (Close to targets)
      final activeLunch = NutritionRecordEntity(
        id: 'l2',
        foodName: 'Fish & Rice',
        mealType: 'Lunch',
        calories: 1300.0,
        protein: 75.0,
        carbohydrates: 120.0,
        fats: 34.0,
        sugar: 0.0,
        servingSize: 450.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [activeLunch],
        goals: testGoal,
      );

      // Remaining: 300 kcal (15%), 25g protein (25%), 80g carbs (40%), 16g fats (32%)
      // Does not trigger low cals (>50% consumed), low protein (>60% consumed), low fat, or cals exceeded.
      expect(result.insightMessage, "You're on track with today's nutrition goals.");
    });

    test('Generates low calorie recommendation insight', () {
      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [], // 0 consumed
        goals: testGoal,
      );

      expect(result.insightMessage, 'Your calorie intake is below your daily target.');
    });

    test('Generates low protein recommendation insight', () {
      final highCarbRecord = NutritionRecordEntity(
        id: 'hc1',
        foodName: 'Rice with Jam',
        mealType: 'Lunch',
        calories: 1200.0,
        protein: 5.0,
        carbohydrates: 280.0,
        fats: 2.0,
        sugar: 50.0,
        servingSize: 400.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [highCarbRecord],
        goals: testGoal,
      );

      // Remaining calories: 800 kcal (40%) - not low calorie
      // Remaining protein: 95g (95% deficient)
      expect(result.insightMessage, 'Your protein intake is below your target.');
    });

    test('Generates high fat recommendation insight and filters out high fat suggestions', () {
      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [breakfast, heavyLunch],
        goals: testGoal,
      );

      // Consumed fats: 6 + 45 = 51 (Goal: 50) => Exceeded!
      expect(result.isFatExceeded, isTrue);
      expect(result.insightMessage, 'Consider choosing a lower-fat food for your next meal.');

      // Verify that Paneer (20.8g fat) is filtered out of suggestions
      final containsPaneer = result.suggestions.any((s) => s.food.name == 'Paneer');
      expect(containsPaneer, isFalse);
    });

    test('Handles empty records gracefully', () {
      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [],
        goals: testGoal,
      );

      expect(result.remainingCalories, 2000.0);
      expect(result.suggestions.isNotEmpty, isTrue);
    });

    test('Handles missing goals gracefully', () {
      final result = RecommendationEngine.getRecommendations(
        dailyRecords: [breakfast],
        goals: null,
      );

      expect(result.insightMessage, 'Set your goals to receive personalized smart nutrition feedback.');
      expect(result.remainingCalories, 1600.0); // Falls back to default target (2000)
    });
  });
}
