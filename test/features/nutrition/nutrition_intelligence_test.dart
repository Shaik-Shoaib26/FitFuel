import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_insights_engine.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_intelligence',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final day1Record = NutritionRecordEntity(
    id: 'd1_rec',
    foodName: 'Standard Meal',
    mealType: 'Lunch',
    calories: 1200.0,
    protein: 60.0,
    carbohydrates: 110.0,
    fats: 25.0,
    sugar: 5.0,
    servingSize: 300.0,
    consumedAt: now.subtract(const Duration(days: 1)),
    createdAt: now,
    updatedAt: now,
  );

  final day2Record = NutritionRecordEntity(
    id: 'd2_rec',
    foodName: 'Standard Meal 2',
    mealType: 'Dinner',
    calories: 800.0,
    protein: 40.0,
    carbohydrates: 90.0,
    fats: 25.0,
    sugar: 5.0,
    servingSize: 300.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('Nutrition Insights Engine Tests', () {
    test('Calculates average calories and macros correctly', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [day1Record, day2Record],
        goals: testGoal,
        daysCount: 7,
      );

      // Logged on 2 days. Total: Calories 2000, Protein 100, Carbs 200, Fats 50
      // Averages: Calories 1000, Protein 50, Carbs 100, Fats 25
      expect(result.avgCalories, 1000.0);
      expect(result.avgProtein, 50.0);
      expect(result.avgCarbs, 100.0);
      expect(result.avgFats, 25.0);

      // Goal achievements (Calories average 1000 vs Goal 2000 => 50%)
      expect(result.goalAchievementPercent, 50.0);
    });

    test('Calculates consistency score and logged days count correctly', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [day1Record, day2Record],
        goals: testGoal,
        daysCount: 7,
      );

      expect(result.loggedDaysCount, 2);
      expect(result.consistencyScore, closeTo(28.57, 0.1));
    });

    test('Identifies below-target calorie and protein deficiency insights', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [day1Record, day2Record],
        goals: testGoal,
        daysCount: 7,
      );

      // Average Calories (1000) is < 2000 * 0.9 => Consistently below calorie target
      // Average Protein (50) is < 100 * 0.9 => Protein frequently below target
      final hasBelowCalInsight = result.insights.any((i) => i.title == 'Consistently below calorie target');
      final hasBelowProInsight = result.insights.any((i) => i.title == 'Protein frequently below target');

      expect(hasBelowCalInsight, isTrue);
      expect(hasBelowProInsight, isTrue);
    });

    test('Identifies above-target calorie and fat excess insights', () {
      final hugeRecord = NutritionRecordEntity(
        id: 'huge',
        foodName: 'Huge Meal',
        mealType: 'Lunch',
        calories: 2500.0,
        protein: 40.0,
        carbohydrates: 200.0,
        fats: 60.0, // Goal: 50. Average of 2 days: 60g => Fat frequently above target
        sugar: 10.0,
        servingSize: 500.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );



      // Avg Calories: (1200 + 2500)/2 = 1850 (under 2000 target). Let's modify goal to 1500 target.
      final lowerGoal = testGoal.copyWith(dailyCalorieTarget: 1500, fatTargetGrams: 40);
      final lowResult = NutritionInsightsEngine.analyzeHistory(
        records: [day1Record, hugeRecord],
        goals: lowerGoal,
        daysCount: 7,
      );

      // Avg cals: 1850 vs Goal 1500 (1850 > 1650) => Exceeded!
      final hasAboveCalInsight = lowResult.insights.any((i) => i.title == 'Consistently above calorie target');
      final hasAboveFatInsight = lowResult.insights.any((i) => i.title == 'Fat frequently above target');

      expect(hasAboveCalInsight, isTrue);
      expect(hasAboveFatInsight, isTrue);
    });

    test('Evaluates trends correctly (improving, declining, stable)', () {
      // Create daily aggregate log history of 7 days to trigger trend analysis
      // Let's create logs where calorie intake is moving towards goal (improving)
      // Goal Calories = 2000
      // Previous 4 days: 1000, 1100, 1000, 1100 (Avg = 1050 kcal)
      // Last 3 days: 1800, 1900, 1850 (Avg = 1850 kcal - closer to target 2000)
      final List<NutritionRecordEntity> logs = [];
      for (int i = 0; i < 4; i++) {
        logs.add(NutritionRecordEntity(
          id: 'prev_$i',
          foodName: 'Small Salad',
          mealType: 'Lunch',
          calories: 1050.0,
          protein: 50.0,
          carbohydrates: 100.0,
          fats: 25.0,
          sugar: 0.0,
          servingSize: 200.0,
          consumedAt: now.subtract(Duration(days: 6 - i)),
          createdAt: now,
          updatedAt: now,
        ));
      }
      for (int i = 0; i < 3; i++) {
        logs.add(NutritionRecordEntity(
          id: 'last_$i',
          foodName: 'Salmon Rice',
          mealType: 'Dinner',
          calories: 1850.0,
          protein: 85.0,
          carbohydrates: 150.0,
          fats: 45.0,
          sugar: 0.0,
          servingSize: 400.0,
          consumedAt: now.subtract(Duration(days: 2 - i)),
          createdAt: now,
          updatedAt: now,
        ));
      }

      final result = NutritionInsightsEngine.analyzeHistory(
        records: logs,
        goals: testGoal,
        daysCount: 7,
      );

      final calTrend = result.trends.firstWhere((t) => t.metricName == 'Calories');
      expect(calTrend.direction, TrendDirection.improving);
    });

    test('Handles insufficient data (< 2 days of logs) gracefully', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [day2Record],
        goals: testGoal,
        daysCount: 7,
      );

      expect(result.insights.first.title, 'Insufficient Data');
    });

    test('Handles empty records list gracefully', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [],
        goals: testGoal,
        daysCount: 7,
      );

      expect(result.avgCalories, 0.0);
      expect(result.insights.first.title, 'Insufficient Data');
    });

    test('Handles missing goals gracefully', () {
      final result = NutritionInsightsEngine.analyzeHistory(
        records: [day1Record, day2Record],
        goals: null,
        daysCount: 7,
      );

      expect(result.insights.first.title, 'Configure Daily Targets');
    });
  });
}
