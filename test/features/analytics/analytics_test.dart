import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/analytics/domain/utils/health_analytics_calculator.dart';
import 'package:fitfuel/features/analytics/domain/utils/analytics_trend_engine.dart';
import 'package:fitfuel/features/analytics/domain/utils/analytics_insight_engine.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';

void main() {
  group('Smart Health Analytics Center Tests', () {
    final today = DateTime(2026, 8, 16);

    final profile = UserProfileEntity(
      uid: 'user_123',
      displayName: 'John Doe',
      email: 'john@example.com',
      age: 28,
      gender: 'Male',
      height: 175.0,
      weight: 80.0,
      activityLevel: 'Moderately Active',
      fitnessGoal: 'Lose Weight',
      dietaryPreference: 'Any',
      createdAt: today,
      updatedAt: today,
    );

    final goals = NutritionGoalsEntity(
      userId: 'user_123',
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 150.0,
      carbsTargetGrams: 200.0,
      fatTargetGrams: 65.0,
      updatedAt: today,
    );

    final List<NutritionRecordEntity> nutritionRecords = [
      NutritionRecordEntity(
        id: 'nut_1',
        foodName: 'Oats',
        mealType: 'Breakfast',
        calories: 300,
        protein: 10,
        carbohydrates: 50,
        fats: 5,
        sugar: 1,
        servingSize: 100,
        consumedAt: today,
        createdAt: today,
        updatedAt: today,
      ),
      NutritionRecordEntity(
        id: 'nut_2',
        foodName: 'Chicken Salad',
        mealType: 'Lunch',
        calories: 1600,
        protein: 140,
        carbohydrates: 20,
        fats: 40,
        sugar: 5,
        servingSize: 400,
        consumedAt: today,
        createdAt: today,
        updatedAt: today,
      ),
      NutritionRecordEntity(
        id: 'nut_3',
        foodName: 'Eggs',
        mealType: 'Breakfast',
        calories: 2000,
        protein: 160,
        carbohydrates: 195,
        fats: 62,
        sugar: 4,
        servingSize: 150,
        consumedAt: today.subtract(const Duration(days: 1)),
        createdAt: today,
        updatedAt: today,
      ),
    ];

    final List<HealthRecordEntity> healthRecords = [
      HealthRecordEntity(
        id: '2026-08-16',
        date: '2026-08-16',
        waterIntakeMl: 3000,
        waterTargetMl: 2500,
        exercises: const [
          ExerciseEntity(activity: 'Running', duration: 40, caloriesBurned: 400),
          ExerciseEntity(activity: 'Pushups', duration: 20, caloriesBurned: 150),
        ],
        habits: const {
          'Sleep 7-8h': true,
          '10k Steps': true,
          'Stretching': false,
        },
        createdAt: today,
        updatedAt: today,
      ),
      HealthRecordEntity(
        id: '2026-08-15',
        date: '2026-08-15',
        waterIntakeMl: 2000,
        waterTargetMl: 2500,
        exercises: const [],
        habits: const {
          'Sleep 7-8h': true,
          '10k Steps': false,
          'Stretching': false,
        },
        createdAt: today,
        updatedAt: today,
      ),
    ];

    final List<WeightRecordEntity> weightHistory = [
      WeightRecordEntity(id: 'w_1', weight: 82.0, recordedAt: today.subtract(const Duration(days: 10))),
      WeightRecordEntity(id: 'w_2', weight: 81.0, recordedAt: today.subtract(const Duration(days: 5))),
      WeightRecordEntity(id: 'w_3', weight: 80.0, recordedAt: today.subtract(const Duration(minutes: 10))),
      WeightRecordEntity(id: 'w_4', weight: 80.2, recordedAt: today),
    ];

    test('1. Daily aggregation combining metrics correctly', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );

      expect(analytics.dataPoints.length, 7);
      final todayPoint = analytics.dataPoints.firstWhere((dp) => dp.date.day == 16);
      expect(todayPoint.calories, 1900.0);
      expect(todayPoint.protein, 150.0);
      expect(todayPoint.water, 3000.0);
      expect(todayPoint.workoutMinutes, 60.0);
      expect(todayPoint.workoutCalories, 550.0);
      expect(todayPoint.habitCompletionRate, closeTo(2 / 3, 0.01));
    });

    test('2. Multiple nutrition entries same day combined', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );

      final todayPoint = analytics.dataPoints.firstWhere((dp) => dp.date.day == 16);
      expect(todayPoint.calories, 1900.0);
    });

    test('3. Multiple water entries same day combined', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final todayPoint = analytics.dataPoints.firstWhere((dp) => dp.date.day == 16);
      expect(todayPoint.water, 3000.0);
    });

    test('4. Multiple workouts same day combined', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final todayPoint = analytics.dataPoints.firstWhere((dp) => dp.date.day == 16);
      expect(todayPoint.workoutMinutes, 60.0);
    });

    test('5. Missing data creates safe fallback defaults', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: const [],
        healthRecords: const [],
        weightHistory: const [],
        profile: profile,
        goals: goals,
      );
      expect(analytics.dataPoints.isNotEmpty, true);
      expect(analytics.dataPoints.every((dp) => dp.calories == 0.0), true);
      expect(analytics.dataPoints.every((dp) => dp.weight == null), true);
    });

    test('6. 7-day range constraints', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.dataPoints.length, 7);
      expect(analytics.dataPoints.first.date, today.subtract(const Duration(days: 6)));
      expect(analytics.dataPoints.last.date, today);
    });

    test('7. 30-day range constraints', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '30D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.dataPoints.length, 30);
    });

    test('8. 90-day range constraints', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '90D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.dataPoints.length, 90);
    });

    test('9. 1-year range constraints', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '1Y',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.dataPoints.length, 365);
    });

    test('10. Calorie target adherence calculation with tolerance', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.calorieAdherencePercentage, 100.0);
    });

    test('11. Protein target adherence calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.proteinAdherencePercentage, 100.0);
    });

    test('12. Hydration adherence calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.hydrationAdherencePercentage, 50.0);
    });

    test('13. Exercise consistency calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.exerciseConsistencyPercentage, closeTo(14.28, 0.05));
    });

    test('14. Habit consistency calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.habitConsistencyPercentage, 50.0);
    });

    test('15. Wellness score trend logic', () {
      final wellnessValues = [50.0, 60.0];
      final trend = AnalyticsTrendEngine.calculateTrend(
        values: wellnessValues,
        threshold: 3.0,
      );
      expect(trend, 'Improving');
    });

    test('16. Weight change metrics calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '30D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.startingWeight, 82.0);
      expect(analytics.summary.currentWeight, 80.2);
      expect(analytics.summary.weightChange, closeTo(-1.8, 0.05));
    });

    test('17. Goal-aware weight interpretation', () {
      final loseTrend = AnalyticsTrendEngine.calculateWeightTrend(
        startingWeight: 82.0,
        currentWeight: 80.0,
        goal: 'Lose Weight',
      );
      expect(loseTrend, 'Improving');

      final gainTrend = AnalyticsTrendEngine.calculateWeightTrend(
        startingWeight: 82.0,
        currentWeight: 80.0,
        goal: 'Gain Muscle',
      );
      expect(gainTrend, 'Declining');
    });

    test('18. Best day calculation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final best = AnalyticsInsightEngine.calculateBestDay(analytics.dataPoints);
      expect(best, isNotNull);
      expect(best!.date.day, 16);
    });

    test('19. Weakest category detection', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final focus = AnalyticsInsightEngine.detectFocusArea(analytics.summary, analytics.dataPoints);
      expect(focus.category, 'Exercise');
    });

    test('20. Strongest category detection', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final strongest = AnalyticsInsightEngine.detectStrongestCategory(analytics.summary);
      expect(strongest, 'Nutrition');
    });

    test('21. Period comparison logic', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      expect(analytics.previousSummary, isNotNull);
      expect(analytics.summary.averageWellness >= 0, true);
    });

    test('22. Smart insights text validation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final insights = AnalyticsInsightEngine.generateInsights(
        dataPoints: analytics.dataPoints,
        summary: analytics.summary,
        previousSummary: analytics.previousSummary,
      );
      expect(insights.isNotEmpty, true);
      expect(insights.any((i) => i.title == 'Hydration Consistency'), true);
    });

    test('23. Correlation insights generation', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: nutritionRecords,
        healthRecords: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
        goals: goals,
      );
      final insights = AnalyticsInsightEngine.generateInsights(
        dataPoints: analytics.dataPoints,
        summary: analytics.summary,
        previousSummary: analytics.previousSummary,
      );
      expect(insights.any((i) => i.title == 'Protein Consistency'), true);
    });

    test('24. Empty state detection and safe building', () {
      final analytics = HealthAnalyticsCalculator.calculate(
        range: '7D',
        today: today,
        nutritionRecords: const [],
        healthRecords: const [],
        weightHistory: const [],
        profile: profile,
        goals: goals,
      );
      expect(analytics.summary.activeLoggingDays, 0);
    });

    test('25. AI context generation contains analytics block', () {
      final contextText = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: nutritionRecords,
        goals: goals,
        todayHealth: healthRecords.first,
        historyHealth: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
      );
      expect(contextText.contains('=== FITFUEL ANALYTICS CONTEXT ==='), true);
      expect(contextText.contains('Nutrition Adherence:'), true);
      expect(contextText.contains('Hydration Adherence:'), true);
    });

    test('26. AI intent routing prioritizes analytics questions', () async {
      final contextText = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: nutritionRecords,
        goals: goals,
        todayHealth: healthRecords.first,
        historyHealth: healthRecords,
        weightHistory: weightHistory,
        profile: profile,
      );

      final response = await AiNutritionMockDatasource().generateResponse(
        userPrompt: 'How is my nutrition?',
        systemContext: contextText,
      );
      expect(response.text.contains('nutrition target adherence'), true);
    });

    test('27. Generic greeting routing works correctly', () async {
      final response = await AiNutritionMockDatasource().generateResponse(
        userPrompt: 'Hi',
        systemContext: '',
      );
      expect(response.text.contains("I'm FitFuel AI"), true);
    });

    test('28. Food recommendation regression check', () async {
      final response = await AiNutritionMockDatasource().generateResponse(
        userPrompt: 'What should I eat?',
        systemContext: '',
      );
      expect(response.text.contains('nutrition target adherence'), false);
    });
  });
}
