import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../entities/weekly_report_entity.dart';

class WeeklyReportCalculator {
  static const double calorieTolerance = 0.05;

  static WeeklyReportEntity calculateReport({
    required List<NutritionRecordEntity> nutritionHistory,
    required List<HealthRecordEntity> healthHistory,
    required List<WeightRecordEntity> weightHistory,
    required NutritionGoalsEntity? goals,
    required UserProfileEntity? profile,
    required String period, // 'completed' | 'previous' | 'preview'
    DateTime? referenceDate,
  }) {
    final today = referenceDate ?? DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final DateTime start;
    if (period == 'completed') {
      start = todayMidnight.subtract(const Duration(days: 7));
    } else if (period == 'previous') {
      start = todayMidnight.subtract(const Duration(days: 14));
    } else { // 'preview' (current week)
      start = todayMidnight.subtract(const Duration(days: 6));
    }

    final List<String> dateStrings = [];
    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      dateStrings.add(date.toString().split(' ').first);
    }

    // Targets configuration
    final double targetCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double targetPro = goals?.proteinTargetGrams ?? 150.0;
    const double targetWater = 2500.0;

    // 1. Nutrition Aggregations
    int daysLoggedNutrition = 0;
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFats = 0.0;
    int caloriesConsistentDays = 0;
    int proteinDaysMet = 0;

    final minCal = targetCals * (1.0 - calorieTolerance);
    final maxCal = targetCals * (1.0 + calorieTolerance);

    for (final dateStr in dateStrings) {
      final dayRecords = nutritionHistory.where((r) {
        final rDateStr = r.consumedAt.toString().split(' ').first;
        return rDateStr == dateStr;
      }).toList();

      if (dayRecords.isNotEmpty) {
        daysLoggedNutrition++;
        double dayCals = 0.0;
        double dayPro = 0.0;
        double dayCarbs = 0.0;
        double dayFats = 0.0;

        for (final r in dayRecords) {
          dayCals += r.calories;
          dayPro += r.protein;
          dayCarbs += r.carbohydrates;
          dayFats += r.fats;
        }

        totalCalories += dayCals;
        totalProtein += dayPro;
        totalCarbs += dayCarbs;
        totalFats += dayFats;

        if (dayCals >= minCal && dayCals <= maxCal) {
          caloriesConsistentDays++;
        }
        if (dayPro >= targetPro) {
          proteinDaysMet++;
        }
      }
    }

    final double avgCalories = daysLoggedNutrition > 0 ? totalCalories / daysLoggedNutrition : 0.0;
    final double avgProtein = daysLoggedNutrition > 0 ? totalProtein / daysLoggedNutrition : 0.0;
    final double avgCarbs = daysLoggedNutrition > 0 ? totalCarbs / daysLoggedNutrition : 0.0;
    final double avgFats = daysLoggedNutrition > 0 ? totalFats / daysLoggedNutrition : 0.0;

    final double calorieAdherencePercent = daysLoggedNutrition > 0
        ? (avgCalories / targetCals * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final double proteinAdherencePercent = daysLoggedNutrition > 0
        ? (avgProtein / targetPro * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final double calorieConsistencyPercent = daysLoggedNutrition > 0
        ? (caloriesConsistentDays / daysLoggedNutrition * 100.0)
        : 0.0;

    final double proteinConsistencyPercent = daysLoggedNutrition > 0
        ? (proteinDaysMet / daysLoggedNutrition * 100.0)
        : 0.0;

    // Component Score: Nutrition
    final double nutritionScore = daysLoggedNutrition > 0
        ? (calorieConsistencyPercent * 0.6) + (proteinConsistencyPercent * 0.4)
        : 0.0;

    final String nutritionStatus;
    if (daysLoggedNutrition == 0) {
      nutritionStatus = 'Insufficient Data';
    } else if (calorieConsistencyPercent >= 80.0 && proteinConsistencyPercent >= 80.0) {
      nutritionStatus = 'Excellent';
    } else if (calorieConsistencyPercent >= 50.0) {
      nutritionStatus = 'On Track';
    } else {
      nutritionStatus = 'Needs Attention';
    }

    // 2. Hydration Aggregations
    int waterDaysMet = 0;
    double totalWater = 0.0;
    int hydrationDaysLogged = 0;

    for (final dateStr in dateStrings) {
      final hr = healthHistory.where((r) => r.date == dateStr).firstOrNull;
      if (hr != null) {
        hydrationDaysLogged++;
        totalWater += hr.waterIntakeMl;
        if (hr.waterIntakeMl >= hr.waterTargetMl) {
          waterDaysMet++;
        }
      }
    }

    final double avgWater = hydrationDaysLogged > 0 ? totalWater / 7.0 : 0.0; // Over 7 calendar days
    final double hydrationConsistencyPercent = hydrationDaysLogged > 0
        ? (waterDaysMet / 7.0 * 100.0)
        : 0.0;
    final double hydrationAdherencePercent = targetWater > 0
        ? (avgWater / targetWater * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final double hydrationScore = hydrationConsistencyPercent;

    final String hydrationStatus;
    if (hydrationDaysLogged == 0) {
      hydrationStatus = 'Insufficient Data';
    } else if (waterDaysMet >= 5) {
      hydrationStatus = 'Excellent';
    } else if (waterDaysMet >= 3) {
      hydrationStatus = 'On Track';
    } else {
      hydrationStatus = 'Needs Attention';
    }

    // 3. Exercise Aggregations
    int exerciseActiveDays = 0;
    int exerciseTotalMinutes = 0;
    double exerciseTotalCaloriesBurned = 0.0;

    for (final dateStr in dateStrings) {
      final hr = healthHistory.where((r) => r.date == dateStr).firstOrNull;
      if (hr != null && hr.exercises.isNotEmpty) {
        int dayMins = 0;
        double dayCals = 0.0;
        for (final ex in hr.exercises) {
          dayMins += ex.duration;
          dayCals += ex.caloriesBurned;
        }
        if (dayMins > 0) {
          exerciseActiveDays++;
          exerciseTotalMinutes += dayMins;
          exerciseTotalCaloriesBurned += dayCals;
        }
      }
    }

    final double exerciseAvgDuration = exerciseActiveDays > 0
        ? exerciseTotalMinutes / exerciseActiveDays
        : 0.0;

    final double exerciseConsistencyPercent = (exerciseActiveDays / 7.0 * 100.0);

    // Target 3 active days a week = 100% exercise score
    final double exerciseScore = (exerciseActiveDays / 3.0 * 100.0).clamp(0.0, 100.0);

    // 4. Habits Aggregations
    double habitsTotalCompletionRate = 0.0;
    int habitsSuccessfulDays = 0;
    int habitsLoggedDays = 0;
    final Map<String, int> habitTrueCounts = {};
    final Map<String, int> habitTotalCounts = {};

    for (final dateStr in dateStrings) {
      final hr = healthHistory.where((r) => r.date == dateStr).firstOrNull;
      if (hr != null && hr.habits.isNotEmpty) {
        habitsLoggedDays++;
        int dayCompleted = 0;
        hr.habits.forEach((key, val) {
          habitTotalCounts[key] = (habitTotalCounts[key] ?? 0) + 1;
          if (val) {
            dayCompleted++;
            habitTrueCounts[key] = (habitTrueCounts[key] ?? 0) + 1;
          }
        });
        final double dayRate = dayCompleted / hr.habits.length;
        habitsTotalCompletionRate += dayRate;
        if (dayRate >= 0.8) {
          habitsSuccessfulDays++;
        }
      }
    }

    final double habitsAvgCompletionPercent = habitsLoggedDays > 0
        ? (habitsTotalCompletionRate / habitsLoggedDays * 100.0)
        : 0.0;

    final double habitsConsistencyPercent = habitsLoggedDays > 0
        ? (habitsSuccessfulDays / 7.0 * 100.0)
        : 0.0;

    final double habitsScore = habitsAvgCompletionPercent;

    String habitsBestName = 'N/A';
    double bestRate = -1.0;
    habitTrueCounts.forEach((key, count) {
      final total = habitTotalCounts[key] ?? 1;
      final rate = count / total;
      if (rate > bestRate) {
        bestRate = rate;
        habitsBestName = key;
      }
    });

    String habitsAttentionName = 'N/A';
    double worstRate = 2.0;
    habitTotalCounts.forEach((key, total) {
      final count = habitTrueCounts[key] ?? 0;
      final rate = count / total;
      if (rate < worstRate) {
        worstRate = rate;
        habitsAttentionName = key;
      }
    });

    // 5. Wellness Score Aggregations
    double wellnessTotalScore = 0.0;
    double wellnessBestScore = 0.0;
    double wellnessLowestScore = 100.0;
    int wellnessLoggedDays = 0;
    final List<double> wellnessScoresList = [];

    for (final dateStr in dateStrings) {
      final hr = healthHistory.where((r) => r.date == dateStr).firstOrNull;
      final hasLoggedFood = nutritionHistory.any((r) => r.consumedAt.toString().split(' ').first == dateStr);
      
      final double dayScore = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: hasLoggedFood,
        healthRecord: hr,
      );

      if (hasLoggedFood || hr != null) {
        wellnessLoggedDays++;
        wellnessTotalScore += dayScore;
        wellnessScoresList.add(dayScore);

        if (dayScore > wellnessBestScore) {
          wellnessBestScore = dayScore;
        }
        if (dayScore < wellnessLowestScore) {
          wellnessLowestScore = dayScore;
        }
      } else {
        wellnessScoresList.add(0.0);
      }
    }

    final double wellnessAvgScore = wellnessLoggedDays > 0
        ? wellnessTotalScore / wellnessLoggedDays
        : 0.0;

    if (wellnessLoggedDays == 0) {
      wellnessLowestScore = 0.0;
    }

    final double wellnessScore = wellnessAvgScore;

    String wellnessTrend = 'Insufficient';
    if (wellnessLoggedDays >= 3) {
      const int half = 3;
      double firstHalfSum = 0.0;
      int firstHalfCount = 0;
      double secondHalfSum = 0.0;
      int secondHalfCount = 0;

      for (int i = 0; i < 7; i++) {
        final score = wellnessScoresList[i];
        if (score > 0.0) {
          if (i < half) {
            firstHalfSum += score;
            firstHalfCount++;
          } else {
            secondHalfSum += score;
            secondHalfCount++;
          }
        }
      }

      final double avgFirst = firstHalfCount > 0 ? firstHalfSum / firstHalfCount : 0.0;
      final double avgSecond = secondHalfCount > 0 ? secondHalfSum / secondHalfCount : 0.0;

      if (firstHalfCount == 0 || secondHalfCount == 0) {
        wellnessTrend = 'Stable';
      } else {
        final double diff = avgSecond - avgFirst;
        if (diff > 3.0) {
          wellnessTrend = 'Improving';
        } else if (diff < -3.0) {
          wellnessTrend = 'Declining';
        } else {
          wellnessTrend = 'Stable';
        }
      }
    }

    // 6. Weight Aggregations
    double startingWeight = profile?.weight ?? 0.0;
    double currentWeight = profile?.weight ?? 0.0;
    double weightChange = 0.0;
    double weightChangePercent = 0.0;

    // Filter weights inside selected period
    final periodWeights = weightHistory.where((w) {
      final wDateStr = w.recordedAt.toString().split(' ').first;
      return dateStrings.contains(wDateStr);
    }).toList();

    if (periodWeights.isNotEmpty) {
      final sortedWeights = List<WeightRecordEntity>.from(periodWeights)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      startingWeight = sortedWeights.first.weight;
      currentWeight = sortedWeights.last.weight;
      weightChange = currentWeight - startingWeight;
      weightChangePercent = startingWeight > 0 ? (weightChange / startingWeight * 100.0) : 0.0;
    } else if (weightHistory.isNotEmpty) {
      // Fallback to latest historical weight if no weights this week
      final sortedAll = List<WeightRecordEntity>.from(weightHistory)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      startingWeight = sortedAll.last.weight;
      currentWeight = sortedAll.last.weight;
    }

    final String weightGoalDirection = profile?.fitnessGoal ?? 'Maintain';

    // 7. Dynamic Weighted Health Score Calculation
    double scoreSum = 0.0;
    int scoreCount = 0;

    if (daysLoggedNutrition > 0) {
      scoreSum += nutritionScore;
      scoreCount++;
    }
    if (hydrationDaysLogged > 0) {
      scoreSum += hydrationScore;
      scoreCount++;
    }
    if (exerciseActiveDays > 0 || healthHistory.any((h) => h.exercises.isNotEmpty)) {
      scoreSum += exerciseScore;
      scoreCount++;
    }
    if (habitsLoggedDays > 0) {
      scoreSum += habitsScore;
      scoreCount++;
    }
    if (wellnessLoggedDays > 0 && healthHistory.isNotEmpty) {
      scoreSum += wellnessScore;
      scoreCount++;
    }

    // Default normalization
    final double healthScore = scoreCount > 0 ? scoreSum / scoreCount : 0.0;

    // 8. Streak Logic (Past 7 calendar days)
    int nutritionStreak = 0;
    if (nutritionHistory.isNotEmpty) {
      final todayStr = today.toString().split(' ').first;
      final yesterdayStr = today.subtract(const Duration(days: 1)).toString().split(' ').first;
      bool hasLoggedToday = nutritionHistory.any((r) => r.consumedAt.toString().split(' ').first == todayStr);
      bool hasLoggedYesterday = nutritionHistory.any((r) => r.consumedAt.toString().split(' ').first == yesterdayStr);

      if (hasLoggedToday || hasLoggedYesterday) {
        int consecutiveDays = 0;
        DateTime checkDate = hasLoggedToday ? today : today.subtract(const Duration(days: 1));
        while (true) {
          final checkStr = checkDate.toString().split(' ').first;
          final hasLogs = nutritionHistory.any((r) => r.consumedAt.toString().split(' ').first == checkStr);
          if (hasLogs) {
            consecutiveDays++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
        nutritionStreak = consecutiveDays;
      }
    }

    // 9. Strongest and Weakest Areas
    final List<MapEntry<String, double>> validScores = [];
    if (daysLoggedNutrition > 0) validScores.add(MapEntry('Nutrition', nutritionScore));
    if (hydrationDaysLogged > 0) validScores.add(MapEntry('Hydration', hydrationScore));
    if (exerciseActiveDays > 0) validScores.add(MapEntry('Exercise', exerciseScore));
    if (habitsLoggedDays > 0) validScores.add(MapEntry('Habits', habitsScore));
    if (wellnessLoggedDays > 0 && healthHistory.isNotEmpty) validScores.add(MapEntry('Wellness', wellnessScore));

    validScores.sort((a, b) => b.value.compareTo(a.value));

    final String strongestArea = validScores.isNotEmpty ? validScores.first.key : 'N/A';
    final String strongestAreaDescription = strongestArea == 'Nutrition'
        ? 'You stayed close to your calorie and protein targets on $caloriesConsistentDays of $daysLoggedNutrition logged days.'
        : strongestArea == 'Hydration'
            ? 'You hit your hydration targets on $waterDaysMet of 7 days.'
            : strongestArea == 'Exercise'
                ? 'You maintained active physical workouts on $exerciseActiveDays days.'
                : strongestArea == 'Habits'
                    ? 'You completed an average of ${habitsAvgCompletionPercent.toStringAsFixed(0)}% of your habit checklists.'
                    : strongestArea == 'Wellness'
                        ? 'Your wellness score averaged ${wellnessAvgScore.toStringAsFixed(0)}/100.'
                        : 'No category score available yet.';

    validScores.sort((a, b) => a.value.compareTo(b.value));
    final String weakestArea = validScores.isNotEmpty ? validScores.first.key : 'N/A';
    final String weakestAreaDescription;
    final String weakestAreaSuggestion;

    if (weakestArea == 'Nutrition') {
      weakestAreaDescription = 'Your calorie consistency was ${calorieConsistencyPercent.toStringAsFixed(0)}% this week.';
      weakestAreaSuggestion = 'Try planning your main meals in advance to avoid calorie overflow or missing protein targets.';
    } else if (weakestArea == 'Hydration') {
      weakestAreaDescription = 'You met your water intake targets on $waterDaysMet of 7 days.';
      weakestAreaSuggestion = 'Set structured hourly notifications on your phone or keep a water bottle at your desk.';
    } else if (weakestArea == 'Exercise') {
      weakestAreaDescription = 'You only recorded $exerciseActiveDays active days of physical training.';
      weakestAreaSuggestion = 'Aim for at least three short 15-minute walks or stretching sessions next week.';
    } else if (weakestArea == 'Habits') {
      weakestAreaDescription = 'Your average habit completion rate was ${habitsAvgCompletionPercent.toStringAsFixed(0)}%.';
      weakestAreaSuggestion = 'Focus on consistency for your lowest habit ($habitsAttentionName) by checking it off early.';
    } else if (weakestArea == 'Wellness') {
      weakestAreaDescription = 'Your wellness score averaged ${wellnessAvgScore.toStringAsFixed(0)}/100.';
      weakestAreaSuggestion = 'Prioritizing hydration and regular sleep will help elevate your overall wellness rating.';
    } else {
      weakestAreaDescription = 'No category score available yet.';
      weakestAreaSuggestion = 'Start logging nutrition, hydration, and workouts to receive feedback.';
    }

    // 10. Weekly Insights
    final List<String> insights = [];
    if (daysLoggedNutrition > 0) {
      insights.add('Your nutrition consistency was ${calorieConsistencyPercent.toStringAsFixed(0)}% across logged days.');
    }
    if (waterDaysMet >= 5) {
      insights.add('Great job! You achieved your hydration goals on $waterDaysMet days.');
    } else if (waterDaysMet > 0) {
      insights.add('You met your water goals on $waterDaysMet days this week.');
    }
    if (exerciseActiveDays >= 3) {
      insights.add('Excellent! You completed $exerciseTotalMinutes workout minutes on $exerciseActiveDays active days.');
    } else if (exerciseActiveDays > 0) {
      insights.add('You completed $exerciseTotalMinutes minutes of active workouts.');
    }
    if (habitsAvgCompletionPercent >= 80.0) {
      insights.add('Your habits checklist completion averaged a high ${habitsAvgCompletionPercent.toStringAsFixed(0)}%.');
    }
    if (nutritionStreak >= 3) {
      insights.add('You maintained a consistent $nutritionStreak-day nutrition logging streak.');
    }

    // 11. Next Week Action Plan
    final List<String> actionPlan = [];
    if (weakestArea == 'Nutrition') {
      actionPlan.add('Log meals consistently for 7 days');
      actionPlan.add('Stay within calorie limits');
      actionPlan.add('Meet protein target on 5 days');
    } else if (weakestArea == 'Hydration') {
      actionPlan.add('Reach hydration target at least 5 days');
      actionPlan.add('Keep water bottle near desk');
      actionPlan.add('Log water intake after every meal');
    } else if (weakestArea == 'Exercise') {
      actionPlan.add('Complete 3 workout sessions');
      actionPlan.add('Walk at least 15 minutes daily');
      actionPlan.add('Log exercise duration and intensity');
    } else if (weakestArea == 'Habits') {
      actionPlan.add('Improve habit completion above 80%');
      actionPlan.add('Focus on completing "$habitsAttentionName"');
      actionPlan.add('Tick off habits first thing in the morning');
    } else {
      actionPlan.add('Keep tracking calories consistently');
      actionPlan.add('Complete daily habit checklist');
      actionPlan.add('Stay hydrated throughout the day');
    }

    // 12. Milestones Unlocked this Week
    final List<String> unlockedMilestones = [];
    // Recalculate summary over the past 7 days to extract unlocked milestone names
    final tempSummary = ProgressCalculator.calculateSummary(
      nutritionHistory: nutritionHistory,
      healthHistory: healthHistory,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      daysCount: 7,
    );
    for (final ms in tempSummary.milestones) {
      if (ms.isUnlocked) {
        unlockedMilestones.add(ms.title);
      }
    }

    return WeeklyReportEntity(
      healthScore: double.parse(healthScore.toStringAsFixed(1)),
      nutritionScore: double.parse(nutritionScore.toStringAsFixed(1)),
      hydrationScore: double.parse(hydrationScore.toStringAsFixed(1)),
      exerciseScore: double.parse(exerciseScore.toStringAsFixed(1)),
      habitsScore: double.parse(habitsScore.toStringAsFixed(1)),
      wellnessScore: double.parse(wellnessScore.toStringAsFixed(1)),
      avgCalories: double.parse(avgCalories.toStringAsFixed(0)),
      calorieAdherencePercent: double.parse(calorieAdherencePercent.toStringAsFixed(1)),
      calorieConsistencyPercent: double.parse(calorieConsistencyPercent.toStringAsFixed(1)),
      avgProtein: double.parse(avgProtein.toStringAsFixed(1)),
      proteinAdherencePercent: double.parse(proteinAdherencePercent.toStringAsFixed(1)),
      proteinConsistencyPercent: double.parse(proteinConsistencyPercent.toStringAsFixed(1)),
      avgCarbs: double.parse(avgCarbs.toStringAsFixed(1)),
      avgFats: double.parse(avgFats.toStringAsFixed(1)),
      nutritionDaysLogged: daysLoggedNutrition,
      nutritionStreak: nutritionStreak,
      nutritionStatus: nutritionStatus,
      avgWater: double.parse(avgWater.toStringAsFixed(0)),
      waterTarget: targetWater,
      hydrationAdherencePercent: double.parse(hydrationAdherencePercent.toStringAsFixed(1)),
      waterDaysMet: waterDaysMet,
      hydrationConsistencyPercent: double.parse(hydrationConsistencyPercent.toStringAsFixed(1)),
      hydrationStatus: hydrationStatus,
      exerciseActiveDays: exerciseActiveDays,
      exerciseTotalMinutes: exerciseTotalMinutes,
      exerciseAvgDuration: double.parse(exerciseAvgDuration.toStringAsFixed(1)),
      exerciseCaloriesBurned: double.parse(exerciseTotalCaloriesBurned.toStringAsFixed(0)),
      exerciseConsistencyPercent: double.parse(exerciseConsistencyPercent.toStringAsFixed(1)),
      habitsAvgCompletionPercent: double.parse(habitsAvgCompletionPercent.toStringAsFixed(1)),
      habitsSuccessfulDays: habitsSuccessfulDays,
      habitsBestName: habitsBestName,
      habitsAttentionName: habitsAttentionName,
      habitsConsistencyPercent: double.parse(habitsConsistencyPercent.toStringAsFixed(1)),
      wellnessAvgScore: double.parse(wellnessAvgScore.toStringAsFixed(1)),
      wellnessBestScore: wellnessBestScore,
      wellnessLowestScore: wellnessLowestScore,
      wellnessTrend: wellnessTrend,
      startingWeight: startingWeight,
      currentWeight: currentWeight,
      weightChange: double.parse(weightChange.toStringAsFixed(1)),
      weightChangePercent: double.parse(weightChangePercent.toStringAsFixed(1)),
      weightGoalDirection: weightGoalDirection,
      strongestArea: strongestArea,
      strongestAreaDescription: strongestAreaDescription,
      weakestArea: weakestArea,
      weakestAreaDescription: weakestAreaDescription,
      weakestAreaSuggestion: weakestAreaSuggestion,
      insights: insights,
      actionPlan: actionPlan,
      unlockedMilestones: unlockedMilestones,
    );
  }
}
