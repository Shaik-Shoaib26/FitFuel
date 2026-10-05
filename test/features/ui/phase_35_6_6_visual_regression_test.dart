import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/progress_summary_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/utils/progress_calculator.dart';
import 'package:fitfuel/features/progress/presentation/widgets/progress_deep_exploration.dart';
import 'package:fitfuel/features/progress/presentation/widgets/progress_insight_card.dart';
import 'package:fitfuel/features/progress/presentation/widgets/progress_milestones_section.dart';
import 'package:fitfuel/features/progress/presentation/widgets/progress_range_selector.dart';
import 'package:fitfuel/features/progress/presentation/widgets/progress_summary_metric_card.dart';
import 'package:fitfuel/features/progress/presentation/widgets/weight_progress_card.dart';
import 'package:fitfuel/features/progress/presentation/widgets/wellness_score_card.dart';

void main() {
  final now = DateTime.now();

  group('Phase 35.6.6 — Option A Progress Dashboard Tests', () {
    test('formatFitnessGoal formats raw database enums into human-readable labels', () {
      expect(ProgressCalculator.formatFitnessGoal('gain_muscle'), 'Gain Muscle');
      expect(ProgressCalculator.formatFitnessGoal('lose_weight'), 'Lose Weight');
      expect(ProgressCalculator.formatFitnessGoal('maintain_weight'), 'Maintain Weight');
      expect(ProgressCalculator.formatFitnessGoal('improve_fitness'), 'Improve Fitness');
      expect(ProgressCalculator.formatFitnessGoal('maintain'), 'Maintain Weight');
      expect(ProgressCalculator.formatFitnessGoal(null), 'Maintain Weight');
      expect(ProgressCalculator.formatFitnessGoal(''), 'Maintain Weight');
      expect(ProgressCalculator.formatFitnessGoal('custom_bulk'), 'Custom Bulk');
    });

    testWidgets('ProgressRangeSelector renders 7, 30, 90 days and responds to tap', (tester) async {
      int selected = 7;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ProgressRangeSelector(
                  selectedDays: selected,
                  onRangeSelected: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('90 Days'), findsOneWidget);

      await tester.tap(find.text('30 Days'));
      await tester.pumpAndSettle();

      expect(selected, 30);
    });

    testWidgets('ProgressSummaryMetricsRow displays Nutrition Streak, Water, and Activity', (tester) async {
      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [
          NutritionRecordEntity(
            id: '1',
            foodName: 'Oatmeal',
            mealType: 'Breakfast',
            calories: 500,
            protein: 20,
            carbohydrates: 70,
            fats: 10,
            sugar: 0,
            servingSize: 100,
            consumedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        healthHistory: [
          HealthRecordEntity(
            id: '1',
            date: now.toString().split(' ').first,
            waterIntakeMl: 1800,
            waterTargetMl: 2500,
            exercises: const [],
            habits: const {},
            createdAt: now,
            updatedAt: now,
          ),
        ],
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSummaryMetricsRow(summary: summary),
          ),
        ),
      );

      expect(find.text('Nutrition Streak'), findsOneWidget);
      expect(find.text('${summary.currentStreak} days'), findsOneWidget);

      expect(find.text('Water Avg per day'), findsOneWidget);
      expect(find.text('1.8 L'), findsOneWidget);

      expect(find.text('Activity Avg per day'), findsOneWidget);
    });

    testWidgets('WellnessScoreCard renders circular score and 4 categories with info dialog', (tester) async {
      const summary = ProgressSummaryEntity(
        avgCalories: 2000,
        calorieTarget: 2000,
        calorieAdherencePercent: 85,
        nutritionDaysLogged: 5,
        nutritionDaysMissed: 2,
        calorieConsistencyPercent: 80,
        avgProtein: 120,
        proteinTarget: 150,
        proteinDaysMet: 4,
        proteinConsistencyPercent: 80,
        avgCarbs: 200,
        carbsTarget: 200,
        avgFats: 60,
        fatsTarget: 60,
        avgWater: 2200,
        waterTarget: 2500,
        waterDaysMet: 5,
        waterConsistencyPercent: 88,
        exerciseActiveDays: 4,
        exerciseTotalMinutes: 160,
        exerciseAvgDuration: 40,
        exerciseConsistencyPercent: 80,
        exerciseTotalCaloriesBurned: 600,
        habitsAvgCompletionRate: 90,
        habitsSuccessfulDays: 5,
        habitsConsistencyPercent: 85,
        habitsMostConsistent: 'Reading',
        habitsLeastConsistent: 'Sleep',
        wellnessAvgScore: 82,
        wellnessBestScore: 90,
        wellnessLowestScore: 70,
        wellnessTrend: 'Improving',
        currentWeight: 56.0,
        startingWeight: 58.5,
        weightChange: -2.5,
        weightChangePercent: -4.3,
        weightGoalDirection: 'Lose Weight',
        currentStreak: 5,
        longestStreak: 5,
        milestones: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WellnessScoreCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Overall Wellness Score'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('of 100'), findsOneWidget);

      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);

      // Tap info icon
      await tester.tap(find.byTooltip('Wellness score info'));
      await tester.pumpAndSettle();

      expect(find.text('Wellness Score'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    });

    testWidgets('WeightProgressCard renders empty state when entries < 2', (tester) async {
      const summary = ProgressSummaryEntity(
        avgCalories: 0,
        calorieTarget: 2000,
        calorieAdherencePercent: 0,
        nutritionDaysLogged: 0,
        nutritionDaysMissed: 7,
        calorieConsistencyPercent: 0,
        avgProtein: 0,
        proteinTarget: 150,
        proteinDaysMet: 0,
        proteinConsistencyPercent: 0,
        avgCarbs: 0,
        carbsTarget: 200,
        avgFats: 0,
        fatsTarget: 60,
        avgWater: 0,
        waterTarget: 2500,
        waterDaysMet: 0,
        waterConsistencyPercent: 0,
        exerciseActiveDays: 0,
        exerciseTotalMinutes: 0,
        exerciseAvgDuration: 0,
        exerciseConsistencyPercent: 0,
        exerciseTotalCaloriesBurned: 0,
        habitsAvgCompletionRate: 0,
        habitsSuccessfulDays: 0,
        habitsConsistencyPercent: 0,
        habitsMostConsistent: '',
        habitsLeastConsistent: '',
        wellnessAvgScore: 0,
        wellnessBestScore: 0,
        wellnessLowestScore: 0,
        wellnessTrend: 'Stable',
        currentWeight: 0,
        startingWeight: 0,
        weightChange: 0,
        weightChangePercent: 0,
        weightGoalDirection: 'Maintain Weight',
        currentStreak: 0,
        longestStreak: 0,
        milestones: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeightProgressCard(
              summary: summary,
              weightHistory: [],
              selectedDays: 7,
            ),
          ),
        ),
      );

      expect(find.text('Weight Progress'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Not enough weight data yet'), findsOneWidget);
      expect(find.text('Log Weight'), findsOneWidget);
    });

    testWidgets('WeightProgressCard renders stat pill and chart when entries >= 2', (tester) async {
      final history = [
        WeightRecordEntity(id: '1', weight: 58.5, recordedAt: now.subtract(const Duration(days: 6))),
        WeightRecordEntity(id: '2', weight: 57.8, recordedAt: now.subtract(const Duration(days: 4))),
        WeightRecordEntity(id: '3', weight: 56.0, recordedAt: now),
      ];

      const summary = ProgressSummaryEntity(
        avgCalories: 0,
        calorieTarget: 2000,
        calorieAdherencePercent: 0,
        nutritionDaysLogged: 0,
        nutritionDaysMissed: 7,
        calorieConsistencyPercent: 0,
        avgProtein: 0,
        proteinTarget: 150,
        proteinDaysMet: 0,
        proteinConsistencyPercent: 0,
        avgCarbs: 0,
        carbsTarget: 200,
        avgFats: 0,
        fatsTarget: 60,
        avgWater: 0,
        waterTarget: 2500,
        waterDaysMet: 0,
        waterConsistencyPercent: 0,
        exerciseActiveDays: 0,
        exerciseTotalMinutes: 0,
        exerciseAvgDuration: 0,
        exerciseConsistencyPercent: 0,
        exerciseTotalCaloriesBurned: 0,
        habitsAvgCompletionRate: 0,
        habitsSuccessfulDays: 0,
        habitsConsistencyPercent: 0,
        habitsMostConsistent: '',
        habitsLeastConsistent: '',
        wellnessAvgScore: 0,
        wellnessBestScore: 0,
        wellnessLowestScore: 0,
        wellnessTrend: 'Stable',
        currentWeight: 56.0,
        startingWeight: 58.5,
        weightChange: -2.5,
        weightChangePercent: -4.3,
        weightGoalDirection: 'Lose Weight',
        currentStreak: 0,
        longestStreak: 0,
        milestones: [],
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightProgressCard(
              summary: summary,
              weightHistory: history,
              selectedDays: 7,
            ),
          ),
        ),
      );

      expect(find.text('56.0 kg'), findsOneWidget);
      expect(find.text('-2.5 kg ↓'), findsOneWidget);
    });

    testWidgets('ProgressInsightCard renders Key Insights with concise advice', (tester) async {
      const summary = ProgressSummaryEntity(
        avgCalories: 0,
        calorieTarget: 2000,
        calorieAdherencePercent: 0,
        nutritionDaysLogged: 5,
        nutritionDaysMissed: 2,
        calorieConsistencyPercent: 0,
        avgProtein: 0,
        proteinTarget: 150,
        proteinDaysMet: 0,
        proteinConsistencyPercent: 0,
        avgCarbs: 0,
        carbsTarget: 200,
        avgFats: 0,
        fatsTarget: 60,
        avgWater: 0,
        waterTarget: 2500,
        waterDaysMet: 0,
        waterConsistencyPercent: 0,
        exerciseActiveDays: 0,
        exerciseTotalMinutes: 0,
        exerciseAvgDuration: 0,
        exerciseConsistencyPercent: 0,
        exerciseTotalCaloriesBurned: 0,
        habitsAvgCompletionRate: 0,
        habitsSuccessfulDays: 0,
        habitsConsistencyPercent: 0,
        habitsMostConsistent: '',
        habitsLeastConsistent: '',
        wellnessAvgScore: 82,
        wellnessBestScore: 82,
        wellnessLowestScore: 82,
        wellnessTrend: 'Stable',
        currentWeight: 56.0,
        startingWeight: 56.0,
        weightChange: 0,
        weightChangePercent: 0,
        weightGoalDirection: 'Maintain Weight',
        currentStreak: 5,
        longestStreak: 5,
        milestones: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressInsightCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Key Insights'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      expect(
        find.text("You've been consistent with your nutrition for 5 days! Keep it up."),
        findsOneWidget,
      );
    });

    testWidgets('ProgressMilestonesSection renders unlocked achievements and progress', (tester) async {
      final milestones = [
        const MilestoneEntity(
          id: '1',
          title: '7-Day Nutrition Streak',
          description: 'Log food for 7 consecutive days.',
          isUnlocked: true,
          progressText: '7/7 days',
          progressPercent: 1.0,
        ),
        const MilestoneEntity(
          id: '2',
          title: 'Hydration Target',
          description: 'Meet your daily water target.',
          isUnlocked: false,
          progressText: '3/7 days',
          progressPercent: 0.42,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressMilestonesSection(milestones: milestones),
          ),
        ),
      );

      expect(find.text('Milestones & Achievements'), findsOneWidget);
      expect(find.text('1/2 Unlocked'), findsOneWidget);
      expect(find.text('7-Day Nutrition Streak'), findsOneWidget);
      expect(find.text('Hydration Target'), findsOneWidget);
    });

    testWidgets('ProgressDeepExploration renders 3 navigation tiles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressDeepExploration(),
          ),
        ),
      );

      expect(find.text('Deep Exploration'), findsOneWidget);
      expect(find.text('Health Analytics'), findsOneWidget);
      expect(find.text('Weekly Health Report'), findsOneWidget);
      expect(find.text('Smart Health Insights'), findsOneWidget);
    });
  });
}
