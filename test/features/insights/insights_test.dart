import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/insights/domain/entities/health_insight_entity.dart';
import 'package:fitfuel/features/insights/domain/utils/priority_calculator.dart';
import 'package:fitfuel/features/insights/domain/utils/insight_engine.dart';
import 'package:fitfuel/features/insights/domain/utils/action_recommendation_engine.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';

void main() {
  group('PriorityCalculator Tests', () {
    test('calculateProteinPriority under 40% returns high', () {
      expect(PriorityCalculator.calculateProteinPriority(30, 100), InsightPriority.high);
    });

    test('calculateProteinPriority under 70% returns medium', () {
      expect(PriorityCalculator.calculateProteinPriority(60, 100), InsightPriority.medium);
    });

    test('calculateProteinPriority under 90% returns low', () {
      expect(PriorityCalculator.calculateProteinPriority(85, 100), InsightPriority.low);
    });

    test('calculateProteinPriority over 90% returns positive', () {
      expect(PriorityCalculator.calculateProteinPriority(95, 100), InsightPriority.positive);
    });

    test('calculateCaloriePriority over 120% returns high', () {
      expect(PriorityCalculator.calculateCaloriePriority(2500, 2000), InsightPriority.high);
    });

    test('calculateCaloriePriority under 80% returns medium', () {
      expect(PriorityCalculator.calculateCaloriePriority(1500, 2000), InsightPriority.medium);
    });

    test('calculateCaloriePriority inside tolerance returns positive', () {
      expect(PriorityCalculator.calculateCaloriePriority(2010, 2000), InsightPriority.positive);
    });

    test('calculateHydrationPriority deficit > 1000ml returns high', () {
      expect(PriorityCalculator.calculateHydrationPriority(1000, 2500), InsightPriority.high);
    });

    test('calculateHydrationPriority deficit > 500ml returns medium', () {
      expect(PriorityCalculator.calculateHydrationPriority(1800, 2500), InsightPriority.medium);
    });

    test('calculateHydrationPriority no deficit returns positive', () {
      expect(PriorityCalculator.calculateHydrationPriority(2500, 2500), InsightPriority.positive);
    });

    test('calculateExercisePriority active days target met returns positive', () {
      expect(PriorityCalculator.calculateExercisePriority(3, 3), InsightPriority.positive);
    });

    test('calculateExercisePriority zero active days returns high', () {
      expect(PriorityCalculator.calculateExercisePriority(0, 3), InsightPriority.high);
    });

    test('calculateHabitPriority low rate returns high', () {
      expect(PriorityCalculator.calculateHabitPriority(0.4), InsightPriority.high);
    });

    test('calculateHabitPriority high rate returns positive', () {
      expect(PriorityCalculator.calculateHabitPriority(0.95), InsightPriority.positive);
    });
  });

  group('ActionRecommendationEngine Tests', () {
    test('maps logWater to /health', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.logWater, InsightPriority.high);
      expect(rec.route, '/health');
      expect(rec.actionType, InsightActionType.logWater);
    });

    test('maps findProteinFoods to /food-search', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.findProteinFoods, InsightPriority.high);
      expect(rec.route, '/food-search');
    });

    test('maps viewMealPlan to /meal-planner', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.viewMealPlan, InsightPriority.medium);
      expect(rec.route, '/meal-planner');
    });

    test('maps openGrocery to /grocery', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.openGrocery, InsightPriority.medium);
      expect(rec.route, '/grocery');
    });

    test('maps viewProgress to /progress', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.viewProgress, InsightPriority.low);
      expect(rec.route, '/progress');
    });

    test('maps openWeeklyReport to /weekly-report', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.openWeeklyReport, InsightPriority.low);
      expect(rec.route, '/weekly-report');
    });

    test('maps openDailyRoutine to /daily-routine', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.openDailyRoutine, InsightPriority.medium);
      expect(rec.route, '/daily-routine');
    });

    test('maps openAnalytics to /analytics', () {
      final rec = ActionRecommendationEngine.generate(InsightActionType.openAnalytics, InsightPriority.low);
      expect(rec.route, '/analytics');
    });
  });

  group('InsightEngine Tests', () {
    final today = DateTime(2026, 8, 16);
    final profile = UserProfileEntity(
      uid: 'user_123',
      email: 'test@example.com',
      fitnessGoal: 'Lose Weight',
      createdAt: today,
      updatedAt: today,
    );

    final goals = NutritionGoalsEntity(
      userId: 'user_123',
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 100.0,
      carbsTargetGrams: 200.0,
      fatTargetGrams: 65.0,
      updatedAt: today,
    );

    test('generateInsights detects protein deficit', () {
      final records = [
        NutritionRecordEntity(
          id: '1',
          foodName: 'Apple',
          mealType: 'Snack',
          calories: 100.0,
          protein: 2.0,
          carbohydrates: 25.0,
          fats: 0.0,
          sugar: 10.0,
          servingSize: 100.0,
          consumedAt: today,
          createdAt: today,
          updatedAt: today,
        ),
      ];

      final insights = InsightEngine.generateInsights(
        today: today,
        profile: profile,
        goals: goals,
        nutritionHistory: records,
        healthHistory: [],
        weightHistory: [],
      );

      final hasProteinDeficit = insights.any((i) => i.id == 'insight_protein_deficit');
      expect(hasProteinDeficit, isTrue);
    });

    test('generateInsights detects hydration deficit', () {
      final healthHistory = [
        HealthRecordEntity(
          id: 'h1',
          date: '2026-08-16',
          waterIntakeMl: 500,
          waterTargetMl: 2500,
          exercises: const [],
          habits: const {},
          createdAt: today,
          updatedAt: today,
        ),
      ];

      final insights = InsightEngine.generateInsights(
        today: today,
        profile: profile,
        goals: goals,
        nutritionHistory: const [],
        healthHistory: healthHistory,
        weightHistory: [],
      );

      final hasHydrationDeficit = insights.any((i) => i.id == 'insight_hydration_deficit');
      expect(hasHydrationDeficit, isTrue);
    });

    test('selectDailyFocus prioritizes hydration over protein', () {
      final insights = [
        HealthInsightEntity(
          id: 'insight_protein_deficit',
          category: InsightCategory.nutrition,
          title: 'Protein is below target',
          description: 'deficit',
          priority: InsightPriority.high,
          metricValue: 20,
          targetValue: 100,
          recommendation: 'eat protein',
          actionType: InsightActionType.findProteinFoods,
          createdAt: today,
        ),
        HealthInsightEntity(
          id: 'insight_hydration_deficit',
          category: InsightCategory.hydration,
          title: 'Hydration needs attention',
          description: 'deficit',
          priority: InsightPriority.high,
          metricValue: 500,
          targetValue: 2000,
          recommendation: 'drink water',
          actionType: InsightActionType.logWater,
          createdAt: today,
        ),
      ];

      final focus = InsightEngine.selectDailyFocus(insights);
      expect(focus.category, InsightCategory.hydration);
      expect(focus.title, 'Improve hydration');
    });

    test('selectDailyFocus falls back to positive when no deficits exist', () {
      final focus = InsightEngine.selectDailyFocus([]);
      expect(focus.category, InsightCategory.positive);
      expect(focus.title, 'Keep your momentum');
    });
  });
}
