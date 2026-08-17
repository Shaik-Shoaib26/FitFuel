import '../entities/health_insight_entity.dart';
import '../entities/daily_focus_entity.dart';
import 'priority_calculator.dart';
import 'action_recommendation_engine.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../grocery/domain/entities/grocery_list_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';

class InsightEngine {
  static List<HealthInsightEntity> generateInsights({
    required DateTime today,
    UserProfileEntity? profile,
    NutritionGoalsEntity? goals,
    required List<NutritionRecordEntity> nutritionHistory,
    required List<HealthRecordEntity> healthHistory,
    required List<WeightRecordEntity> weightHistory,
    List<GroceryListEntity>? groceryLists,
    List<PantryItemEntity>? pantryItems,
  }) {
    final List<HealthInsightEntity> insights = [];
    final todayStr = today.toString().split(' ').first;

    // Filter today's records
    final todayNutrition = nutritionHistory.where((r) {
      final rDateStr = r.consumedAt.toString().split(' ').first;
      return rDateStr == todayStr;
    }).toList();

    final todayHealthList = healthHistory.where((h) => h.date == todayStr).toList();
    final HealthRecordEntity? todayHealth = todayHealthList.isNotEmpty ? todayHealthList.first : null;

    final targetCalories = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final targetProtein = goals?.proteinTargetGrams ?? 100.0;

    // 1. NUTRITION
    final progress = NutritionCalculator.calculateProgress(
      dailyRecords: todayNutrition,
      goals: goals,
    );
    final currentCalories = progress.totalCalories;
    final currentProtein = progress.totalProtein;

    if (currentProtein < targetProtein) {
      final deficit = targetProtein - currentProtein;
      if (deficit > 5.0) {
        insights.add(HealthInsightEntity(
          id: 'insight_protein_deficit',
          category: InsightCategory.nutrition,
          title: 'Protein is below target',
          description: "You're currently ${deficit.toStringAsFixed(0)}g below your protein goal.",
          priority: PriorityCalculator.calculateProteinPriority(currentProtein, targetProtein),
          metricValue: currentProtein,
          targetValue: targetProtein,
          unit: 'g',
          recommendation: 'Aim to add a high-protein food to your next meal.',
          actionType: InsightActionType.findProteinFoods,
          createdAt: today,
        ));
      }
    } else if (targetProtein > 0) {
      insights.add(HealthInsightEntity(
        id: 'insight_protein_positive',
        category: InsightCategory.positive,
        title: 'Great protein consistency today.',
        description: 'You have successfully reached your protein goal of ${targetProtein.toStringAsFixed(0)}g today.',
        priority: InsightPriority.positive,
        metricValue: currentProtein,
        targetValue: targetProtein,
        unit: 'g',
        recommendation: 'Keep choosing high quality protein sources.',
        actionType: InsightActionType.none,
        createdAt: today,
      ));
    }

    if (targetCalories > 0) {
      final ratio = currentCalories / targetCalories;
      if (ratio > 1.15) {
        final surplus = currentCalories - targetCalories;
        insights.add(HealthInsightEntity(
          id: 'insight_calorie_surplus',
          category: InsightCategory.nutrition,
          title: 'Calories above target',
          description: "You're currently ${surplus.toStringAsFixed(0)} kcal above your target.",
          priority: PriorityCalculator.calculateCaloriePriority(currentCalories, targetCalories),
          metricValue: currentCalories,
          targetValue: targetCalories,
          unit: 'kcal',
          recommendation: 'Focus on high-volume, low-calorie foods and moderate portion sizes for the rest of today.',
          actionType: InsightActionType.viewMealPlan,
          createdAt: today,
        ));
      } else if (ratio < 0.8 && currentCalories > 0) {
        final deficit = targetCalories - currentCalories;
        insights.add(HealthInsightEntity(
          id: 'insight_calorie_deficit',
          category: InsightCategory.nutrition,
          title: 'Calories below target',
          description: "You're currently ${deficit.toStringAsFixed(0)} kcal below your target.",
          priority: PriorityCalculator.calculateCaloriePriority(currentCalories, targetCalories),
          metricValue: currentCalories,
          targetValue: targetCalories,
          unit: 'kcal',
          recommendation: 'Consider adding a healthy snack to meet your minimum energy requirements.',
          actionType: InsightActionType.viewMealPlan,
          createdAt: today,
        ));
      }
    }

    // 2. HYDRATION
    final currentWater = todayHealth?.waterIntakeMl ?? 0.0;
    final targetWater = todayHealth?.waterTargetMl ?? 2000.0;
    if (currentWater < targetWater) {
      final deficit = targetWater - currentWater;
      insights.add(HealthInsightEntity(
        id: 'insight_hydration_deficit',
        category: InsightCategory.hydration,
        title: 'Hydration needs attention',
        description: "You're ${deficit.toStringAsFixed(0)} ml below today's target.",
        priority: PriorityCalculator.calculateHydrationPriority(currentWater, targetWater),
        metricValue: currentWater,
        targetValue: targetWater,
        unit: 'ml',
        recommendation: 'Drink a glass of water now to stay hydrated.',
        actionType: InsightActionType.logWater,
        createdAt: today,
      ));
    } else if (targetWater > 0) {
      insights.add(HealthInsightEntity(
        id: 'insight_hydration_positive',
        category: InsightCategory.positive,
        title: 'Hydration target reached',
        description: 'You have met today\'s water target.',
        priority: InsightPriority.positive,
        metricValue: currentWater,
        targetValue: targetWater,
        unit: 'ml',
        recommendation: 'Excellent job staying hydrated today!',
        actionType: InsightActionType.none,
        createdAt: today,
      ));
    }

    // 3. EXERCISE
    int activeDays = 0;
    final last7Days = List.generate(7, (i) => today.subtract(Duration(days: i)));
    for (final date in last7Days) {
      final dStr = date.toString().split(' ').first;
      final match = healthHistory.where((h) => h.date == dStr);
      if (match.isNotEmpty && match.first.exercises.isNotEmpty) {
        activeDays++;
      }
    }
    const targetExerciseDays = 3;
    if (activeDays < targetExerciseDays) {
      insights.add(HealthInsightEntity(
        id: 'insight_exercise_deficit',
        category: InsightCategory.exercise,
        title: 'Weekly active days target',
        description: 'You have completed $activeDays of your $targetExerciseDays weekly workout sessions.',
        priority: PriorityCalculator.calculateExercisePriority(activeDays, targetExerciseDays),
        metricValue: activeDays.toDouble(),
        targetValue: targetExerciseDays.toDouble(),
        unit: 'days',
        recommendation: 'Try scheduled routine workouts to meet your goals.',
        actionType: InsightActionType.openDailyRoutine,
        createdAt: today,
      ));
    } else {
      insights.add(HealthInsightEntity(
        id: 'insight_exercise_positive',
        category: InsightCategory.positive,
        title: 'Weekly workout target completed.',
        description: 'Great job hitting your weekly active days target!',
        priority: InsightPriority.positive,
        metricValue: activeDays.toDouble(),
        targetValue: targetExerciseDays.toDouble(),
        unit: 'days',
        recommendation: 'Maintain your current workout consistency.',
        actionType: InsightActionType.none,
        createdAt: today,
      ));
    }

    // 4. HABITS
    if (todayHealth != null && todayHealth.habits.isNotEmpty) {
      int completed = 0;
      todayHealth.habits.forEach((_, v) {
        if (v) completed++;
      });
      final rate = completed / todayHealth.habits.length;
      if (rate < 0.8) {
        insights.add(HealthInsightEntity(
          id: 'insight_habits_deficit',
          category: InsightCategory.habits,
          title: 'Habit consistency needs attention',
          description: 'Your habit completion rate is currently ${(rate * 100).toStringAsFixed(0)}%.',
          priority: PriorityCalculator.calculateHabitPriority(rate),
          metricValue: rate * 100,
          targetValue: 100,
          unit: '%',
          recommendation: 'Try reviewing and checking off your pending checklist items.',
          actionType: InsightActionType.openDailyRoutine,
          createdAt: today,
        ));
      } else {
        insights.add(HealthInsightEntity(
          id: 'insight_habits_positive',
          category: InsightCategory.positive,
          title: 'Excellent habit completion today!',
          description: 'Your habit completion is above 90% today.',
          priority: InsightPriority.positive,
          metricValue: rate * 100,
          targetValue: 100,
          unit: '%',
          recommendation: 'Outstanding work on maintaining your daily routines!',
          actionType: InsightActionType.none,
          createdAt: today,
        ));
      }
    }

    // 5. WELLNESS
    double wellnessAvgThisWeek = 0.0;
    int wellnessDays = 0;
    for (final date in last7Days) {
      final dStr = date.toString().split(' ').first;
      final match = healthHistory.where((h) => h.date == dStr);
      if (match.isNotEmpty) {
        final dayNutrition = nutritionHistory.where((r) {
          final rDateStr = r.consumedAt.toString().split(' ').first;
          return rDateStr == dStr;
        });
        final score = WellnessCalculator.calculateScore(
          hasLoggedFoodToday: dayNutrition.isNotEmpty,
          healthRecord: match.first,
        );
        if (score > 0) {
          wellnessAvgThisWeek += score;
          wellnessDays++;
        }
      }
    }
    if (wellnessDays > 0) {
      wellnessAvgThisWeek /= wellnessDays;
    }
    if (wellnessAvgThisWeek > 0) {
      insights.add(HealthInsightEntity(
        id: 'insight_wellness_stable',
        category: InsightCategory.wellness,
        title: 'Wellness is stable',
        description: 'Your average wellness score is ${wellnessAvgThisWeek.toStringAsFixed(0)}/100.',
        priority: InsightPriority.low,
        metricValue: wellnessAvgThisWeek,
        targetValue: 100,
        unit: '/100',
        recommendation: 'Try prioritizing sleep and regular hydration to boost wellness.',
        actionType: InsightActionType.openAnalytics,
        createdAt: today,
      ));
    }

    // 6. WEIGHT
    if (weightHistory.isNotEmpty) {
      final currentWeight = weightHistory.first.weight;
      final startingWeight = weightHistory.last.weight;
      final change = currentWeight - startingWeight;
      final goal = profile?.fitnessGoal ?? 'Maintain Weight';

      final priority = PriorityCalculator.calculateWeightPriority(change, goal);
      final isGoalAligned = (goal.toLowerCase().contains('lose') && change < 0) ||
          (goal.toLowerCase().contains('gain') && change > 0);

      insights.add(HealthInsightEntity(
        id: 'insight_weight_tracker',
        category: isGoalAligned ? InsightCategory.positive : InsightCategory.weight,
        title: isGoalAligned ? 'Weight progress aligned' : 'Weight change trend',
        description: 'Your weight has changed by ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg.',
        priority: priority,
        metricValue: currentWeight,
        targetValue: startingWeight,
        unit: 'kg',
        recommendation: isGoalAligned
            ? 'This is aligned with your fitness goal. Keep up the great work!'
            : 'Focus on calorie balance and consistency. Daily weight fluctuations are normal.',
        actionType: InsightActionType.viewProgress,
        createdAt: today,
      ));
    }

    // 7. GROCERY
    if (groceryLists != null && groceryLists.isNotEmpty) {
      final activeList = groceryLists.first;
      final pendingCount = activeList.items.where((i) => !i.isPurchased).length;
      if (pendingCount > 0) {
        insights.add(HealthInsightEntity(
          id: 'insight_grocery_pending',
          category: InsightCategory.progress,
          title: 'Grocery items pending',
          description: 'You have $pendingCount pending items on your shopping list.',
          priority: InsightPriority.medium,
          metricValue: pendingCount.toDouble(),
          recommendation: 'Review your grocery planner to prepare your ingredients.',
          actionType: InsightActionType.openGrocery,
          createdAt: today,
        ));
      }
    }

    return insights;
  }

  static DailyFocusEntity selectDailyFocus(List<HealthInsightEntity> insights) {
    // Deficits precedence logic:
    // 1. Hydration deficit (High/Critical priority)
    // 2. Protein deficit (High/Critical priority)
    // 3. Exercise deficit
    // 4. Habits deficit
    // 5. Fallback

    final hydrationDeficits = insights.where((i) => i.id == 'insight_hydration_deficit');
    if (hydrationDeficits.isNotEmpty) {
      final insight = hydrationDeficits.first;
      final deficit = (insight.targetValue ?? 2000) - (insight.metricValue ?? 0);
      final list = [
        ActionRecommendationEngine.generate(InsightActionType.logWater, InsightPriority.high),
      ];
      return DailyFocusEntity(
        title: 'Improve hydration',
        description: "You're ${deficit.toStringAsFixed(0)} ml below today's target.",
        category: InsightCategory.hydration,
        priority: InsightPriority.high,
        recommendedActions: list,
      );
    }

    final proteinDeficits = insights.where((i) => i.id == 'insight_protein_deficit');
    if (proteinDeficits.isNotEmpty) {
      final insight = proteinDeficits.first;
      final deficit = (insight.targetValue ?? 100) - (insight.metricValue ?? 0);
      final list = [
        ActionRecommendationEngine.generate(InsightActionType.findProteinFoods, InsightPriority.high),
      ];
      return DailyFocusEntity(
        title: 'Increase protein intake',
        description: "You're currently ${deficit.toStringAsFixed(0)}g below your protein goal.",
        category: InsightCategory.nutrition,
        priority: InsightPriority.high,
        recommendedActions: list,
      );
    }

    final exerciseDeficits = insights.where((i) => i.id == 'insight_exercise_deficit');
    if (exerciseDeficits.isNotEmpty) {
      final list = [
        ActionRecommendationEngine.generate(InsightActionType.openDailyRoutine, InsightPriority.medium),
      ];
      return DailyFocusEntity(
        title: 'Complete weekly exercise',
        description: exerciseDeficits.first.description,
        category: InsightCategory.exercise,
        priority: InsightPriority.medium,
        recommendedActions: list,
      );
    }

    final habitsDeficits = insights.where((i) => i.id == 'insight_habits_deficit');
    if (habitsDeficits.isNotEmpty) {
      final list = [
        ActionRecommendationEngine.generate(InsightActionType.openDailyRoutine, InsightPriority.medium),
      ];
      return DailyFocusEntity(
        title: 'Complete daily habits',
        description: habitsDeficits.first.description,
        category: InsightCategory.habits,
        priority: InsightPriority.medium,
        recommendedActions: list,
      );
    }

    // If nothing negative, or everything is met, fallback to positive focus:
    return DailyFocusEntity(
      title: 'Keep your momentum',
      description: 'Your nutrition, hydration, exercise, and habits are all tracking well today.',
      category: InsightCategory.positive,
      priority: InsightPriority.positive,
      recommendedActions: [
        ActionRecommendationEngine.generate(InsightActionType.none, InsightPriority.positive),
      ],
    );
  }
}
