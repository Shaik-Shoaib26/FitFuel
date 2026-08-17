import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';

class DailyHealthSummary {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double waterIntakeMl;
  final double waterTargetMl;
  final int exerciseDurationMinutes;
  final double exerciseCaloriesBurned;
  final int completedHabitsCount;
  final int totalHabitsCount;
  final double wellnessScore;

  const DailyHealthSummary({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.waterIntakeMl,
    required this.waterTargetMl,
    required this.exerciseDurationMinutes,
    required this.exerciseCaloriesBurned,
    required this.completedHabitsCount,
    required this.totalHabitsCount,
    required this.wellnessScore,
  });
}

class WellnessTrendPoint {
  final String date;
  final double wellnessScore;
  final double hydrationMl;
  final int exerciseMinutes;
  final bool hasLoggedFood;
  final double habitCompletionRate;

  const WellnessTrendPoint({
    required this.date,
    required this.wellnessScore,
    required this.hydrationMl,
    required this.exerciseMinutes,
    required this.hasLoggedFood,
    required this.habitCompletionRate,
  });
}

class HealthInsight {
  final String type; // Hydration, Exercise, Nutrition, Habit, Wellness
  final String title;
  final String message;
  final String priority; // High, Medium, Low

  const HealthInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
  });
}

class HealthInsightsEngine {
  /// Compiles today's summary statistics
  static DailyHealthSummary generateTodaySummary({
    required List<NutritionRecordEntity> todayNutrition,
    required HealthRecordEntity? todayHealth,
    required NutritionGoalsEntity? goals,
  }) {
    final progress = NutritionCalculator.calculateProgress(
      dailyRecords: todayNutrition,
      goals: goals,
    );

    int totalExerciseMinutes = 0;
    double totalExerciseCals = 0.0;
    if (todayHealth != null) {
      for (final ex in todayHealth.exercises) {
        totalExerciseMinutes += ex.duration;
        totalExerciseCals += ex.caloriesBurned;
      }
    }

    int completedHabits = 0;
    int totalHabits = todayHealth?.habits.length ?? 0;
    if (todayHealth != null) {
      todayHealth.habits.forEach((_, val) {
        if (val) completedHabits++;
      });
    }

    final double score = WellnessCalculator.calculateScore(
      hasLoggedFoodToday: todayNutrition.isNotEmpty,
      healthRecord: todayHealth,
    );

    return DailyHealthSummary(
      calories: progress.totalCalories,
      protein: progress.totalProtein,
      carbs: progress.totalCarbs,
      fats: progress.totalFats,
      waterIntakeMl: todayHealth?.waterIntakeMl ?? 0.0,
      waterTargetMl: todayHealth?.waterTargetMl ?? 2500.0,
      exerciseDurationMinutes: totalExerciseMinutes,
      exerciseCaloriesBurned: totalExerciseCals,
      completedHabitsCount: completedHabits,
      totalHabitsCount: totalHabits,
      wellnessScore: score,
    );
  }

  /// Aggregates last 7 days of data points
  static List<WellnessTrendPoint> generate7DayTrend({
    required List<NutritionRecordEntity> nutritionHistory,
    required List<HealthRecordEntity> healthHistory,
  }) {
    final List<WellnessTrendPoint> trends = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dateStr = targetDate.toString().split(' ').first; // yyyy-MM-dd

      // Filter nutrition records for this day
      final dayNutrition = nutritionHistory.where((r) {
        final rDateStr = r.consumedAt.toString().split(' ').first;
        return rDateStr == dateStr;
      }).toList();

      final dayHealth = WellnessCalculator.filterByDate(healthHistory, dateStr);

      final double score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: dayNutrition.isNotEmpty,
        healthRecord: dayHealth,
      );

      int exMins = 0;
      if (dayHealth != null) {
        for (final ex in dayHealth.exercises) {
          exMins += ex.duration;
        }
      }

      double habitRate = 0.0;
      if (dayHealth != null && dayHealth.habits.isNotEmpty) {
        int completed = 0;
        dayHealth.habits.forEach((_, v) {
          if (v) completed++;
        });
        habitRate = completed / dayHealth.habits.length;
      }

      trends.add(
        WellnessTrendPoint(
          date: dateStr,
          wellnessScore: score,
          hydrationMl: dayHealth?.waterIntakeMl ?? 0.0,
          exerciseMinutes: exMins,
          hasLoggedFood: dayNutrition.isNotEmpty,
          habitCompletionRate: habitRate,
        ),
      );
    }

    return trends;
  }

  /// Generates rule-based personalized insights from trend history
  static List<HealthInsight> generateInsights(List<WellnessTrendPoint> trends) {
    final List<HealthInsight> insights = [];
    if (trends.isEmpty) return insights;

    // 1. Hydration Analysis
    int lowHydrationDays = 0;
    for (final p in trends) {
      if (p.hydrationMl < 1500) {
        lowHydrationDays++;
      }
    }
    if (lowHydrationDays >= 3) {
      insights.add(const HealthInsight(
        type: 'Hydration',
        title: 'Hydration Under Target',
        message: 'Your water intake was below 1500ml on multiple days this week. Set a goal to carry a reusable water bottle.',
        priority: 'High',
      ));
    } else if (trends.last.hydrationMl >= 2500) {
      insights.add(const HealthInsight(
        type: 'Hydration',
        title: 'Excellent Hydration!',
        message: 'Great job staying hydrated today. Consistent water intake boosts energy levels and recovery.',
        priority: 'Low',
      ));
    }

    // 2. Exercise Analysis
    int activeDays = 0;
    int totalMins = 0;
    for (final p in trends) {
      if (p.exerciseMinutes > 0) {
        activeDays++;
        totalMins += p.exerciseMinutes;
      }
    }
    if (activeDays == 0) {
      insights.add(const HealthInsight(
        type: 'Exercise',
        title: 'Sedentary Week',
        message: 'No exercise sessions were logged this week. Adding even a brief 10-minute walk daily can improve cardiovascular health.',
        priority: 'High',
      ));
    } else if (activeDays >= 4) {
      insights.add(HealthInsight(
        type: 'Exercise',
        title: 'Consistent Workout Routines!',
        message: 'You logged workouts on $activeDays days this week totaling $totalMins minutes. Your physical active consistency is superb.',
        priority: 'Medium',
      ));
    }

    // 3. Habit Analysis
    double avgHabitRate = 0.0;
    for (final p in trends) {
      avgHabitRate += p.habitCompletionRate;
    }
    avgHabitRate = avgHabitRate / trends.length;
    if (avgHabitRate < 0.5) {
      insights.add(const HealthInsight(
        type: 'Habit',
        title: 'Focus on Habits',
        message: 'Your weekly habit completion is under 50%. Focus on checking off at least one simple habit tomorrow.',
        priority: 'Medium',
      ));
    }

    // 4. Wellness trend direction
    if (trends.length >= 2) {
      final initialScore = trends.first.wellnessScore;
      final finalScore = trends.last.wellnessScore;
      if (finalScore > initialScore + 10) {
        insights.add(const HealthInsight(
          type: 'Wellness',
          title: 'Wellness Score is Improving!',
          message: 'Your daily wellness scores are trending upwards. Maintain this momentum in logging meals and completing habits.',
          priority: 'High',
        ));
      }
    }

    return insights;
  }

  /// Generates practical daily action suggestions
  static List<String> generateActionSuggestions(DailyHealthSummary today) {
    final List<String> suggestions = [];

    if (today.waterIntakeMl < today.waterTargetMl) {
      final double diff = today.waterTargetMl - today.waterIntakeMl;
      suggestions.add('Drink ${diff.toStringAsFixed(0)}ml of water to complete today\'s hydration target.');
    }

    if (today.exerciseDurationMinutes < 30) {
      final int diff = 30 - today.exerciseDurationMinutes;
      suggestions.add('Add a $diff-minute workout or stretching session to hit your daily exercise target.');
    }

    if (today.calories == 0) {
      suggestions.add('Log your first meal to track and manage nutrition targets.');
    }

    if (today.totalHabitsCount > 0 && today.completedHabitsCount < today.totalHabitsCount) {
      final int diff = today.totalHabitsCount - today.completedHabitsCount;
      suggestions.add('Complete $diff remaining habits on your checklist to improve wellness scores.');
    }

    if (suggestions.isEmpty) {
      suggestions.add('Perfect day! All daily targets are fully achieved.');
    }

    return suggestions;
  }
}
