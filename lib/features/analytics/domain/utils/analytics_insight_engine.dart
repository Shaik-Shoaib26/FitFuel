import '../../domain/entities/analytics_data_point_entity.dart';
import '../../domain/entities/analytics_summary_entity.dart';

class AnalyticsInsight {
  final String title;
  final String description;
  final String type; // 'hydration', 'nutrition', 'exercise', 'wellness', 'weight', 'correlation'

  const AnalyticsInsight({
    required this.title,
    required this.description,
    required this.type,
  });
}

class FocusArea {
  final String category;
  final double percentage;
  final String reason;
  final String recommendedAction;

  const FocusArea({
    required this.category,
    required this.percentage,
    required this.reason,
    required this.recommendedAction,
  });
}

class BestDayInfo {
  final DateTime date;
  final double score;
  final List<String> whatWentWell;

  const BestDayInfo({
    required this.date,
    required this.score,
    required this.whatWentWell,
  });
}

class AnalyticsInsightEngine {
  static List<AnalyticsInsight> generateInsights({
    required List<AnalyticsDataPointEntity> dataPoints,
    required AnalyticsSummaryEntity summary,
    required AnalyticsSummaryEntity? previousSummary,
  }) {
    final List<AnalyticsInsight> insights = [];

    // 1. Hydration Insight
    final loggedHydrationDays = dataPoints.where((dp) => dp.waterLogged).toList();
    if (loggedHydrationDays.isNotEmpty) {
      final metDays = loggedHydrationDays.where((dp) => dp.water >= dp.waterTarget).length;
      insights.add(AnalyticsInsight(
        title: 'Hydration Consistency',
        description: 'You reached your water target on $metDays of the last ${loggedHydrationDays.length} logged days.',
        type: 'hydration',
      ));
    }

    // 2. Nutrition Insight
    final loggedNutritionDays = dataPoints.where((dp) => dp.nutritionLogged).toList();
    if (loggedNutritionDays.isNotEmpty) {
      final metProtein = loggedNutritionDays.where((dp) => dp.protein >= dp.proteinTarget).length;
      insights.add(AnalyticsInsight(
        title: 'Protein Intake',
        description: 'Your protein target was met on $metProtein of the last ${loggedNutritionDays.length} logged days.',
        type: 'nutrition',
      ));
    }

    // 3. Exercise Insight
    final activeExerciseDays = dataPoints.where((dp) => dp.workoutMinutes > 0).length;
    if (activeExerciseDays > 0) {
      insights.add(AnalyticsInsight(
        title: 'Exercise Level',
        description: 'You completed $activeExerciseDays active days this period, keeping up your physical momentum.',
        type: 'exercise',
      ));
    }

    // 4. Wellness Insight
    if (previousSummary != null && summary.averageWellness > 0 && previousSummary.averageWellness > 0) {
      final diff = summary.averageWellness - previousSummary.averageWellness;
      if (diff > 0) {
        insights.add(AnalyticsInsight(
          title: 'Wellness Progress',
          description: 'Your wellness score improved by ${diff.toStringAsFixed(1)} points compared with the previous period.',
          type: 'wellness',
        ));
      }
    }

    // 5. Weight Insight
    if (summary.weightChange != null && summary.weightChange != 0.0) {
      final changeAbs = summary.weightChange!.abs();
      final direction = summary.weightChange! < 0 ? 'decreased' : 'increased';
      insights.add(AnalyticsInsight(
        title: 'Weight Tracking',
        description: 'Your weight $direction by ${changeAbs.toStringAsFixed(1)} kg over the selected period.',
        type: 'weight',
      ));
    }

    // 6. Smart Correlations (Associations only, no causal claims)
    if (loggedHydrationDays.isNotEmpty) {
      final hydrationMetDays = dataPoints.where((dp) => dp.waterLogged && dp.water >= dp.waterTarget).toList();
      final hydrationUnmetDays = dataPoints.where((dp) => dp.waterLogged && dp.water < dp.waterTarget).toList();

      if (hydrationMetDays.isNotEmpty && hydrationUnmetDays.isNotEmpty) {
        final avgWellnessMet = hydrationMetDays.map((dp) => dp.wellnessScore).reduce((a, b) => a + b) / hydrationMetDays.length;
        final avgWellnessUnmet = hydrationUnmetDays.map((dp) => dp.wellnessScore).reduce((a, b) => a + b) / hydrationUnmetDays.length;

        if (avgWellnessMet > avgWellnessUnmet + 3.0) {
          insights.add(const AnalyticsInsight(
            title: 'Hydration & Wellness Connection',
            description: 'Your higher-hydration days are associated with stronger wellness scores.',
            type: 'correlation',
          ));
        }
      }
    }

    final activeDays = dataPoints.where((dp) => dp.workoutMinutes > 0).toList();
    final inactiveDays = dataPoints.where((dp) => dp.workoutMinutes == 0).toList();
    if (activeDays.isNotEmpty && inactiveDays.isNotEmpty) {
      final avgWellnessActive = activeDays.map((dp) => dp.wellnessScore).reduce((a, b) => a + b) / activeDays.length;
      final avgWellnessInactive = inactiveDays.map((dp) => dp.wellnessScore).reduce((a, b) => a + b) / inactiveDays.length;

      if (avgWellnessActive > avgWellnessInactive + 3.0) {
        insights.add(const AnalyticsInsight(
          title: 'Activity & Wellness Connection',
          description: 'Your more active days coincide with higher wellness scores.',
          type: 'correlation',
        ));
      }
    }

    if (summary.proteinAdherencePercentage >= 75.0) {
      insights.add(const AnalyticsInsight(
        title: 'Protein Consistency',
        description: 'Your protein intake has been consistently aligned with your target.',
        type: 'correlation',
      ));
    }

    return insights;
  }

  static FocusArea detectFocusArea(AnalyticsSummaryEntity summary, List<AnalyticsDataPointEntity> dataPoints) {
    final Map<String, double> scores = {
      'Nutrition': summary.calorieAdherencePercentage,
      'Hydration': summary.hydrationAdherencePercentage,
      'Exercise': summary.exerciseConsistencyPercentage,
      'Habits': summary.habitConsistencyPercentage,
      'Wellness': summary.averageWellness,
    };

    String weakestCategory = 'Hydration';
    double lowestScore = 100.0;

    scores.forEach((key, val) {
      if (val < lowestScore) {
        lowestScore = val;
        weakestCategory = key;
      }
    });

    final loggedHydration = dataPoints.where((dp) => dp.waterLogged).length;
    final metHydration = dataPoints.where((dp) => dp.waterLogged && dp.water >= dp.waterTarget).length;
    final loggedNutrition = dataPoints.where((dp) => dp.nutritionLogged).length;
    final metCal = dataPoints.where((dp) => dp.nutritionLogged && (dp.calories - dp.calorieTarget).abs() / dp.calorieTarget <= 0.05).length;
    final activeEx = dataPoints.where((dp) => dp.workoutMinutes > 0).length;

    String reason = '';
    String recommendedAction = '';

    if (weakestCategory == 'Hydration') {
      reason = 'Your water target was reached on $metHydration of $loggedHydration logged days.';
      recommendedAction = 'Try logging water immediately after each meal.';
    } else if (weakestCategory == 'Nutrition') {
      reason = 'Your calorie targets were aligned on $metCal of $loggedNutrition logged days.';
      recommendedAction = 'Plan your meals the night before using the Adaptive Meal Planner.';
    } else if (weakestCategory == 'Exercise') {
      reason = 'You had only $activeEx active exercise days during this period.';
      recommendedAction = 'Schedule short 15-minute home workouts into your Daily Routine.';
    } else if (weakestCategory == 'Habits') {
      reason = 'Your daily checklist habit completion rate is at ${summary.habitConsistencyPercentage.toStringAsFixed(0)}%.';
      recommendedAction = 'Complete your habit checklist reminders first thing in the morning.';
    } else {
      reason = 'Your wellness scores average ${summary.averageWellness.toStringAsFixed(0)}/100.';
      recommendedAction = 'Improve your wellness by balancing diet, drinking water, and exercising daily.';
    }

    return FocusArea(
      category: weakestCategory,
      percentage: lowestScore,
      reason: reason,
      recommendedAction: recommendedAction,
    );
  }

  static String detectStrongestCategory(AnalyticsSummaryEntity summary) {
    final Map<String, double> scores = {
      'Nutrition': summary.calorieAdherencePercentage,
      'Hydration': summary.hydrationAdherencePercentage,
      'Exercise': summary.exerciseConsistencyPercentage,
      'Habits': summary.habitConsistencyPercentage,
      'Wellness': summary.averageWellness,
    };

    String strongestCategory = 'Wellness';
    double highestScore = 0.0;

    scores.forEach((key, val) {
      if (val > highestScore) {
        highestScore = val;
        strongestCategory = key;
      }
    });

    return strongestCategory;
  }

  static BestDayInfo? calculateBestDay(List<AnalyticsDataPointEntity> dataPoints) {
    if (dataPoints.isEmpty) return null;

    BestDayInfo? bestDay;
    double maxScore = -1.0;

    for (final dp in dataPoints) {
      double nutritionScore = 0.0;
      final List<String> items = [];

      if (dp.nutritionLogged) {
        final calDiffPercent = (dp.calories - dp.calorieTarget).abs() / dp.calorieTarget;
        if (calDiffPercent <= 0.05) {
          nutritionScore += 10.0;
        }
        if (dp.protein >= dp.proteinTarget) {
          nutritionScore += 10.0;
        }
        if (nutritionScore > 0) items.add('Nutrition');
      }

      double hydrationScore = 0.0;
      if (dp.waterLogged && dp.water >= dp.waterTarget) {
        hydrationScore = 20.0;
        items.add('Hydration');
      }

      double exerciseScore = 0.0;
      if (dp.workoutMinutes > 0) {
        exerciseScore = 20.0;
        items.add('Exercise');
      }

      double habitsScore = dp.habitCompletionRate * 20.0;
      if (dp.habitCompletionRate >= 0.8) {
        items.add('Habits');
      }

      double wellnessContribution = dp.wellnessScore * 0.2;
      if (dp.wellnessScore >= 75.0) {
        items.add('Wellness');
      }

      final double totalDayScore = nutritionScore + hydrationScore + exerciseScore + habitsScore + wellnessContribution;

      if (totalDayScore > maxScore) {
        maxScore = totalDayScore;
        bestDay = BestDayInfo(
          date: dp.date,
          score: totalDayScore,
          whatWentWell: items,
        );
      }
    }

    return bestDay;
  }
}
