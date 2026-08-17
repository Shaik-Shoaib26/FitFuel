import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health_insights/domain/utils/health_insights_engine.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_insights',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final breakfastLog = NutritionRecordEntity(
    id: 'n1',
    foodName: 'Oats',
    mealType: 'Breakfast',
    calories: 400.0,
    protein: 15.0,
    carbohydrates: 60.0,
    fats: 6.0,
    sugar: 2.0,
    servingSize: 150.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('Daily Summary Calculations', () {
    test('Computes today summary correctly with values present', () {
      final todayHealth = HealthRecordEntity(
        id: 'today',
        date: now.toString().split(' ').first,
        waterIntakeMl: 1500.0,
        waterTargetMl: 2500.0,
        exercises: const [
          ExerciseEntity(activity: 'Running', duration: 20, caloriesBurned: 200.0)
        ],
        habits: const {'Sleep': true, 'Stretch': false},
        createdAt: now,
        updatedAt: now,
      );

      final summary = HealthInsightsEngine.generateTodaySummary(
        todayNutrition: [breakfastLog],
        todayHealth: todayHealth,
        goals: testGoal,
      );

      expect(summary.calories, 400.0);
      expect(summary.waterIntakeMl, 1500.0);
      expect(summary.exerciseDurationMinutes, 20);
      expect(summary.exerciseCaloriesBurned, 200.0);
      expect(summary.completedHabitsCount, 1);
      expect(summary.totalHabitsCount, 2);
      expect(summary.wellnessScore > 0, isTrue);
    });

    test('Handles empty/missing today summary data safely without crashing', () {
      final summary = HealthInsightsEngine.generateTodaySummary(
        todayNutrition: [],
        todayHealth: null,
        goals: null,
      );

      expect(summary.calories, 0.0);
      expect(summary.waterIntakeMl, 0.0);
      expect(summary.exerciseDurationMinutes, 0);
      expect(summary.exerciseCaloriesBurned, 0.0);
      expect(summary.completedHabitsCount, 0);
      expect(summary.totalHabitsCount, 0);
      expect(summary.wellnessScore, 0.0);
    });
  });

  group('7-Day Aggregation and Trend Analysis', () {
    test('Generates 7-day trend analysis details', () {
      final todayStr = now.toString().split(' ').first;
      final todayHealth = HealthRecordEntity(
        id: todayStr,
        date: todayStr,
        waterIntakeMl: 2000.0,
        waterTargetMl: 2500.0,
        exercises: const [
          ExerciseEntity(activity: 'Swimming', duration: 30, caloriesBurned: 300.0)
        ],
        habits: const {'Sleep': true},
        createdAt: now,
        updatedAt: now,
      );

      final trend = HealthInsightsEngine.generate7DayTrend(
        nutritionHistory: [breakfastLog],
        healthHistory: [todayHealth],
      );

      expect(trend.length, 7);
      // Verify last element corresponds to today
      expect(trend.last.date, todayStr);
      expect(trend.last.hydrationMl, 2000.0);
      expect(trend.last.exerciseMinutes, 30);
      expect(trend.last.habitCompletionRate, 1.0);
    });
  });

  group('Insight and Suggestion Generation Rule Engines', () {
    test('Generates hydration insight when intake is consistently low', () {
      // 3 days with low hydration (< 1500ml)
      const trends = [
        WellnessTrendPoint(date: '1', wellnessScore: 50.0, hydrationMl: 1000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '2', wellnessScore: 50.0, hydrationMl: 1200.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '3', wellnessScore: 50.0, hydrationMl: 1000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '4', wellnessScore: 50.0, hydrationMl: 2000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '5', wellnessScore: 50.0, hydrationMl: 2000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '6', wellnessScore: 50.0, hydrationMl: 2000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
        WellnessTrendPoint(date: '7', wellnessScore: 50.0, hydrationMl: 2000.0, exerciseMinutes: 0, hasLoggedFood: false, habitCompletionRate: 0.0),
      ];

      final insights = HealthInsightsEngine.generateInsights(trends);
      final hasLowHydrationInsight = insights.any((i) => i.title == 'Hydration Under Target');
      expect(hasLowHydrationInsight, isTrue);
    });

    test('Generates exercise warning when active days are zero', () {
      final trends = List.generate(7, (index) =>
        WellnessTrendPoint(date: '$index', wellnessScore: 30.0, hydrationMl: 2000.0, exerciseMinutes: 0, hasLoggedFood: true, habitCompletionRate: 0.8)
      );

      final insights = HealthInsightsEngine.generateInsights(trends);
      final hasSedentaryInsight = insights.any((i) => i.title == 'Sedentary Week');
      expect(hasSedentaryInsight, isTrue);
    });

    test('Generates habit warning when completion rate is low', () {
      final trends = List.generate(7, (index) =>
        WellnessTrendPoint(date: '$index', wellnessScore: 30.0, hydrationMl: 2000.0, exerciseMinutes: 30, hasLoggedFood: true, habitCompletionRate: 0.2)
      );

      final insights = HealthInsightsEngine.generateInsights(trends);
      final hasHabitsInsight = insights.any((i) => i.title == 'Focus on Habits');
      expect(hasHabitsInsight, isTrue);
    });

    test('Generates action suggestions based on today stats', () {
      const summary = DailyHealthSummary(
        calories: 0.0,
        protein: 0.0,
        carbs: 0.0,
        fats: 0.0,
        waterIntakeMl: 1000.0,
        waterTargetMl: 2000.0,
        exerciseDurationMinutes: 10,
        exerciseCaloriesBurned: 100.0,
        completedHabitsCount: 1,
        totalHabitsCount: 3,
        wellnessScore: 40.0,
      );

      final suggestions = HealthInsightsEngine.generateActionSuggestions(summary);
      expect(suggestions.any((s) => s.contains('water')), isTrue);
      expect(suggestions.any((s) => s.contains('workout')), isTrue);
      expect(suggestions.any((s) => s.contains('meal')), isTrue);
      expect(suggestions.any((s) => s.contains('habits')), isTrue);
    });
  });
}
