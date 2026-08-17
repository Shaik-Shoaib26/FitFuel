import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../entities/progress_summary_entity.dart';
import '../entities/weight_record_entity.dart';

class ProgressCalculator {
  static const double calorieTolerance = 0.05; // 5% tolerance

  static ProgressSummaryEntity calculateSummary({
    required List<NutritionRecordEntity> nutritionHistory,
    required List<HealthRecordEntity> healthHistory,
    required List<WeightRecordEntity> weightHistory,
    required NutritionGoalsEntity? goals,
    required UserProfileEntity? profile,
    required int daysCount,
  }) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final startDate = todayMidnight.subtract(Duration(days: daysCount - 1));

    // Compile list of date strings in filter range
    final List<String> dateStrings = [];
    for (int i = 0; i < daysCount; i++) {
      final date = startDate.add(Duration(days: i));
      dateStrings.add(date.toString().split(' ').first);
    }

    // Targets configuration
    final double targetCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double targetPro = goals?.proteinTargetGrams ?? 150.0;
    final double targetCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double targetFats = goals?.fatTargetGrams ?? 65.0;
    const double targetWater = 2500.0; // Default hydration target

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

    final double calorieConsistencyPercent = daysLoggedNutrition > 0
        ? (caloriesConsistentDays / daysLoggedNutrition * 100.0)
        : 0.0;

    final double proteinConsistencyPercent = daysLoggedNutrition > 0
        ? (proteinDaysMet / daysLoggedNutrition * 100.0)
        : 0.0;

    // 2. Hydration & Health Aggregations
    int hydrationDaysMet = 0;
    double totalWater = 0.0;
    int hydrationDaysLogged = 0;

    for (final dateStr in dateStrings) {
      final hr = healthHistory.where((r) => r.date == dateStr).firstOrNull;
      if (hr != null) {
        hydrationDaysLogged++;
        totalWater += hr.waterIntakeMl;
        if (hr.waterIntakeMl >= hr.waterTargetMl) {
          hydrationDaysMet++;
        }
      }
    }

    final double avgWater = hydrationDaysLogged > 0 ? totalWater / hydrationDaysLogged : 0.0;
    final double waterConsistencyPercent = hydrationDaysLogged > 0
        ? (hydrationDaysMet / hydrationDaysLogged * 100.0)
        : 0.0;

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

    final double exerciseConsistencyPercent = (exerciseActiveDays / daysCount * 100.0);

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

    final double habitsAvgCompletionRate = habitsLoggedDays > 0
        ? (habitsTotalCompletionRate / habitsLoggedDays * 100.0)
        : 0.0;

    final double habitsConsistencyPercent = habitsLoggedDays > 0
        ? (habitsSuccessfulDays / habitsLoggedDays * 100.0)
        : 0.0;

    String habitsMostConsistent = 'N/A';
    double bestRate = -1.0;
    habitTrueCounts.forEach((key, count) {
      final total = habitTotalCounts[key] ?? 1;
      final rate = count / total;
      if (rate > bestRate) {
        bestRate = rate;
        habitsMostConsistent = key;
      }
    });

    String habitsLeastConsistent = 'N/A';
    double worstRate = 2.0;
    habitTotalCounts.forEach((key, total) {
      final count = habitTrueCounts[key] ?? 0;
      final rate = count / total;
      if (rate < worstRate) {
        worstRate = rate;
        habitsLeastConsistent = key;
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

      // Only count days where there is either food logged or health logged to prevent skewing trend analysis
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
        wellnessScoresList.add(0.0); // Track flat zero
      }
    }

    final double wellnessAvgScore = wellnessLoggedDays > 0
        ? wellnessTotalScore / wellnessLoggedDays
        : 0.0;

    if (wellnessLoggedDays == 0) {
      wellnessLowestScore = 0.0;
    }

    // Trend analysis
    String wellnessTrend = 'Insufficient';
    if (wellnessLoggedDays >= 3) {
      final int half = (daysCount / 2).floor();
      double firstHalfSum = 0.0;
      int firstHalfCount = 0;
      double secondHalfSum = 0.0;
      int secondHalfCount = 0;

      for (int i = 0; i < daysCount; i++) {
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
    double currentWeight = profile?.weight ?? 0.0;
    double startingWeight = profile?.weight ?? 0.0;
    double weightChange = 0.0;
    double weightChangePercent = 0.0;

    if (weightHistory.isNotEmpty) {
      final sortedHistory = List<WeightRecordEntity>.from(weightHistory)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      startingWeight = sortedHistory.first.weight;
      currentWeight = sortedHistory.last.weight;
      weightChange = currentWeight - startingWeight;
      weightChangePercent = startingWeight > 0 ? (weightChange / startingWeight * 100.0) : 0.0;
    }

    final String weightGoalDirection = profile?.fitnessGoal ?? 'Maintain';

    // 7. Streaks Calculations
    // Streak calculations must scan sequentially backwards from today
    int currentStreak = 0;
    final todayStr = today.toString().split(' ').first;
    final yesterdayStr = today.subtract(const Duration(days: 1)).toString().split(' ').first;

    // Check if food was logged today or yesterday to determine if streak is active
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
      currentStreak = consecutiveDays;
    }

    // Longest streak scanned across all nutrition history records sorted chronologically
    int longestStreak = currentStreak;
    if (nutritionHistory.isNotEmpty) {
      final Set<String> uniqueLogDates = nutritionHistory
          .map((r) => r.consumedAt.toString().split(' ').first)
          .toSet();

      final List<DateTime> sortedDates = uniqueLogDates
          .map((d) => DateTime.parse(d))
          .toList()
        ..sort((a, b) => a.compareTo(b));

      int tempMax = 0;
      int currentRun = 0;
      DateTime? prev;

      for (final date in sortedDates) {
        if (prev == null) {
          currentRun = 1;
        } else {
          final diff = date.difference(prev).inDays;
          if (diff == 1) {
            currentRun++;
          } else if (diff > 1) {
            if (currentRun > tempMax) tempMax = currentRun;
            currentRun = 1;
          }
        }
        prev = date;
      }
      if (currentRun > tempMax) tempMax = currentRun;
      longestStreak = tempMax > longestStreak ? tempMax : longestStreak;
    }

    // 8. Rule-Based Achievements/Milestones
    final List<MilestoneEntity> milestones = [];

    // Milestone 1: First Meal Logged
    final bool firstMealUnlocked = nutritionHistory.isNotEmpty;
    milestones.add(MilestoneEntity(
      id: 'first_meal',
      title: 'First Meal Logged',
      description: 'Log your first nutrition item to begin tracking.',
      isUnlocked: firstMealUnlocked,
      progressText: firstMealUnlocked ? '1/1 logged' : '0/1 logged',
      progressPercent: firstMealUnlocked ? 1.0 : 0.0,
    ));

    // Milestone 2: 7-Day Nutrition Streak
    final int streakProgress = currentStreak.clamp(0, 7);
    milestones.add(MilestoneEntity(
      id: 'nutrition_streak_7',
      title: '7-Day Nutrition Streak',
      description: 'Log food for 7 consecutive days.',
      isUnlocked: currentStreak >= 7,
      progressText: '$streakProgress/7 days',
      progressPercent: streakProgress / 7.0,
    ));

    // Milestone 3: Hydration Goal Reached
    final bool hydrationReached = healthHistory.any((h) => h.waterIntakeMl >= h.waterTargetMl);
    milestones.add(MilestoneEntity(
      id: 'hydration_reached',
      title: 'Hydration Target Reached',
      description: 'Meet your daily water target at least once.',
      isUnlocked: hydrationReached,
      progressText: hydrationReached ? '1/1 met' : '0/1 met',
      progressPercent: hydrationReached ? 1.0 : 0.0,
    ));

    // Milestone 4: 7 Hydration Days
    final int hydMetCount = healthHistory.where((h) => h.waterIntakeMl >= h.waterTargetMl).length;
    final int hydProgress = hydMetCount.clamp(0, 7);
    milestones.add(MilestoneEntity(
      id: 'hydration_days_7',
      title: 'Hydration consistency',
      description: 'Meet your hydration targets on 7 separate days.',
      isUnlocked: hydMetCount >= 7,
      progressText: '$hydProgress/7 days',
      progressPercent: hydProgress / 7.0,
    ));

    // Milestone 5: First Workout
    final bool firstWorkout = healthHistory.any((h) => h.exercises.isNotEmpty);
    milestones.add(MilestoneEntity(
      id: 'first_workout',
      title: 'First Workout Logged',
      description: 'Log your first exercise activity.',
      isUnlocked: firstWorkout,
      progressText: firstWorkout ? '1/1 logged' : '0/1 logged',
      progressPercent: firstWorkout ? 1.0 : 0.0,
    ));

    // Milestone 6: 7 Active Days
    int activeDaysTotalCount = 0;
    int workoutMinutesTotalCount = 0;
    for (final h in healthHistory) {
      if (h.exercises.isNotEmpty) {
        int dayMins = h.exercises.map((e) => e.duration).fold(0, (a, b) => a + b);
        if (dayMins > 0) {
          activeDaysTotalCount++;
          workoutMinutesTotalCount += dayMins;
        }
      }
    }
    final int activeProgress = activeDaysTotalCount.clamp(0, 7);
    milestones.add(MilestoneEntity(
      id: 'active_days_7',
      title: '7 Active Days',
      description: 'Log a workout on 7 separate days.',
      isUnlocked: activeDaysTotalCount >= 7,
      progressText: '$activeProgress/7 days',
      progressPercent: activeProgress / 7.0,
    ));

    // Milestone 7: 300 Workout Minutes
    final int minsProgress = workoutMinutesTotalCount.clamp(0, 300);
    milestones.add(MilestoneEntity(
      id: 'workout_minutes_300',
      title: '300 Workout Minutes',
      description: 'Work out for a total of 300 minutes.',
      isUnlocked: workoutMinutesTotalCount >= 300,
      progressText: '$minsProgress/300 mins',
      progressPercent: minsProgress / 300.0,
    ));

    // Milestone 8: 80% Habit Week
    final bool habitWeekUnlocked = healthHistory.any((h) {
      if (h.habits.isEmpty) return false;
      int done = h.habits.values.where((v) => v).length;
      return (done / h.habits.length) >= 0.8;
    });
    milestones.add(MilestoneEntity(
      id: 'habit_week_80',
      title: 'High Habit Performance',
      description: 'Complete 80% or more of habits in a single day.',
      isUnlocked: habitWeekUnlocked,
      progressText: habitWeekUnlocked ? '1/1 unlocked' : '0/1 unlocked',
      progressPercent: habitWeekUnlocked ? 1.0 : 0.0,
    ));

    // Milestone 9: Wellness Score 80+
    final bool wellness80Plus = wellnessAvgScore >= 80.0;
    milestones.add(MilestoneEntity(
      id: 'wellness_80_plus',
      title: 'Wellness Champion',
      description: 'Maintain an average Wellness Score of 80 or higher.',
      isUnlocked: wellness80Plus,
      progressText: '${wellnessAvgScore.toStringAsFixed(0)}/80 score',
      progressPercent: (wellnessAvgScore / 80.0).clamp(0.0, 1.0),
    ));

    // Milestone 10: First Weight Entry
    final bool weightEntryUnlocked = weightHistory.isNotEmpty;
    milestones.add(MilestoneEntity(
      id: 'weight_first_entry',
      title: 'Scale Step',
      description: 'Log your starting weight.',
      isUnlocked: weightEntryUnlocked,
      progressText: weightEntryUnlocked ? '1/1 logged' : '0/1 logged',
      progressPercent: weightEntryUnlocked ? 1.0 : 0.0,
    ));

    return ProgressSummaryEntity(
      avgCalories: double.parse(avgCalories.toStringAsFixed(0)),
      calorieTarget: targetCals,
      calorieAdherencePercent: double.parse(calorieAdherencePercent.toStringAsFixed(1)),
      nutritionDaysLogged: daysLoggedNutrition,
      nutritionDaysMissed: daysCount - daysLoggedNutrition,
      calorieConsistencyPercent: double.parse(calorieConsistencyPercent.toStringAsFixed(1)),
      avgProtein: double.parse(avgProtein.toStringAsFixed(1)),
      proteinTarget: targetPro,
      proteinDaysMet: proteinDaysMet,
      proteinConsistencyPercent: double.parse(proteinConsistencyPercent.toStringAsFixed(1)),
      avgCarbs: double.parse(avgCarbs.toStringAsFixed(1)),
      carbsTarget: targetCarbs,
      avgFats: double.parse(avgFats.toStringAsFixed(1)),
      fatsTarget: targetFats,
      avgWater: double.parse(avgWater.toStringAsFixed(0)),
      waterTarget: targetWater,
      waterDaysMet: hydrationDaysMet,
      waterConsistencyPercent: double.parse(waterConsistencyPercent.toStringAsFixed(1)),
      exerciseActiveDays: exerciseActiveDays,
      exerciseTotalMinutes: exerciseTotalMinutes,
      exerciseAvgDuration: double.parse(exerciseAvgDuration.toStringAsFixed(1)),
      exerciseConsistencyPercent: double.parse(exerciseConsistencyPercent.toStringAsFixed(1)),
      exerciseTotalCaloriesBurned: double.parse(exerciseTotalCaloriesBurned.toStringAsFixed(0)),
      habitsAvgCompletionRate: double.parse(habitsAvgCompletionRate.toStringAsFixed(1)),
      habitsSuccessfulDays: habitsSuccessfulDays,
      habitsConsistencyPercent: double.parse(habitsConsistencyPercent.toStringAsFixed(1)),
      habitsMostConsistent: habitsMostConsistent,
      habitsLeastConsistent: habitsLeastConsistent,
      wellnessAvgScore: double.parse(wellnessAvgScore.toStringAsFixed(1)),
      wellnessBestScore: wellnessBestScore,
      wellnessLowestScore: wellnessLowestScore,
      wellnessTrend: wellnessTrend,
      currentWeight: currentWeight,
      startingWeight: startingWeight,
      weightChange: double.parse(weightChange.toStringAsFixed(1)),
      weightChangePercent: double.parse(weightChangePercent.toStringAsFixed(1)),
      weightGoalDirection: weightGoalDirection,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      milestones: milestones,
    );
  }
}
