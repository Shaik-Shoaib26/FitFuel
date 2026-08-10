import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/analytics_aggregator.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_analytics',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final recToday1 = NutritionRecordEntity(
    id: 'r1',
    foodName: 'Shake',
    mealType: 'Breakfast',
    calories: 500.0,
    protein: 30.0,
    carbohydrates: 60.0,
    fats: 10.0,
    sugar: 10.0,
    servingSize: 200.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final recToday2 = NutritionRecordEntity(
    id: 'r2',
    foodName: 'Pasta',
    mealType: 'Dinner',
    calories: 700.0,
    protein: 40.0,
    carbohydrates: 90.0,
    fats: 20.0,
    sugar: 4.0,
    servingSize: 400.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final yesterday = now.subtract(const Duration(days: 1));
  final recYesterday = NutritionRecordEntity(
    id: 'r3',
    foodName: 'Salad',
    mealType: 'Lunch',
    calories: 300.0,
    protein: 10.0,
    carbohydrates: 15.0,
    fats: 15.0,
    sugar: 2.0,
    servingSize: 250.0,
    consumedAt: yesterday,
    createdAt: yesterday,
    updatedAt: yesterday,
  );

  group('Analytics Aggregator Tests', () {
    test('Correctly aggregates calories and macros by calendar day', () {
      final records = [recToday1, recToday2, recYesterday];
      final dailyAggregates = AnalyticsAggregator.aggregateByDay(records, daysCount: 7);

      // Verify length of 7 days
      expect(dailyAggregates.length, 7);

      // Today is the last element (index 6)
      final todayAgg = dailyAggregates[6];
      expect(todayAgg.totalCalories, 1200.0);
      expect(todayAgg.totalProtein, 70.0);
      expect(todayAgg.totalCarbs, 150.0);
      expect(todayAgg.totalFats, 30.0);

      // Yesterday is index 5
      final yestAgg = dailyAggregates[5];
      expect(yestAgg.totalCalories, 300.0);
      expect(yestAgg.totalProtein, 10.0);
      expect(yestAgg.totalCarbs, 15.0);
      expect(yestAgg.totalFats, 15.0);

      // Other days (indices 0 to 4) are empty
      expect(dailyAggregates[0].totalCalories, 0.0);
    });

    test('30-day aggregation correctly limits date scope range', () {
      final records = [recToday1, recYesterday];
      final dailyAggregates = AnalyticsAggregator.aggregateByDay(records, daysCount: 30);

      expect(dailyAggregates.length, 30);
    });

    test('Calculates averages, achievements, difference, and generates insights correctly', () {
      final records = [recToday1, recToday2, recYesterday];
      final dailyAggregates = AnalyticsAggregator.aggregateByDay(records, daysCount: 7);
      final summary = AnalyticsAggregator.getHistorySummary(dailyAggregates, testGoal);

      // Only two active days: Today (1200 kcal), Yesterday (300 kcal)
      // Average Calories = (1200 + 300) / 2 = 750 kcal
      // Average Protein = (70 + 10) / 2 = 40g
      // Goal Calories = 2000 => 750 kcal is < 2000 * 0.9 => "You are consistently below your calorie goal."
      // Goal Protein = 100g => 40g is < 100 * 0.95 => "Protein intake is below your target."

      expect(summary.avgCalories, 750.0);
      expect(summary.avgProtein, 40.0);
      expect(summary.avgCarbs, 82.5);
      expect(summary.avgFats, 22.5);

      expect(summary.insights.contains('You are consistently below your calorie goal.'), isTrue);
      expect(summary.insights.contains('Protein intake is below your target.'), isTrue);
    });

    test('Handles null goals with default messages and fallback targets', () {
      final dailyAggregates = AnalyticsAggregator.aggregateByDay([recToday1], daysCount: 7);
      final summary = AnalyticsAggregator.getHistorySummary(dailyAggregates, null);

      expect(summary.insights.first, 'Configure your goals targets to unlock comparative insights.');
    });

    test('Handles completely empty days without crashes', () {
      final dailyAggregates = AnalyticsAggregator.aggregateByDay([], daysCount: 7);
      final summary = AnalyticsAggregator.getHistorySummary(dailyAggregates, testGoal);

      expect(summary.avgCalories, 0.0);
      expect(summary.insights.first, 'You are consistently below your calorie goal.');
    });
  });
}
