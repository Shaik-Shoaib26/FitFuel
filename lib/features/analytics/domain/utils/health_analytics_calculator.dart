import '../../domain/entities/analytics_data_point_entity.dart';
import '../../domain/entities/analytics_summary_entity.dart';
import '../../domain/entities/health_analytics_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import 'analytics_trend_engine.dart';

class HealthAnalyticsCalculator {
  static HealthAnalyticsEntity calculate({
    required String range,
    required DateTime today,
    required List<NutritionRecordEntity> nutritionRecords,
    required List<HealthRecordEntity> healthRecords,
    required List<WeightRecordEntity> weightHistory,
    required UserProfileEntity? profile,
    required NutritionGoalsEntity? goals,
  }) {
    final int numDays = _getRangeDays(range);
    final start = today.subtract(Duration(days: numDays - 1));
    final end = today;

    // 1. Gather all calendar days in range
    final List<DateTime> dates = _getDatesInRange(start, end);

    // 2. Map existing entries by calendar date string (yyyy-MM-dd)
    final Map<String, List<NutritionRecordEntity>> nutritionMap = {};
    for (final r in nutritionRecords) {
      final dateStr = r.consumedAt.toLocal().toString().split(' ').first;
      nutritionMap.putIfAbsent(dateStr, () => []).add(r);
    }

    final Map<String, HealthRecordEntity> healthMap = {};
    for (final r in healthRecords) {
      healthMap[r.date] = r;
    }

    final Map<String, List<WeightRecordEntity>> weightMap = {};
    for (final r in weightHistory) {
      final dateStr = r.recordedAt.toLocal().toString().split(' ').first;
      weightMap.putIfAbsent(dateStr, () => []).add(r);
    }

    // 3. Build data points for current range
    final List<AnalyticsDataPointEntity> dataPoints = _buildDataPoints(
      dates: dates,
      nutritionMap: nutritionMap,
      healthMap: healthMap,
      weightMap: weightMap,
      goals: goals,
      profile: profile,
    );

    // 4. Calculate current summary
    final summary = _calculateSummary(
      dataPoints: dataPoints,
      weightHistory: weightHistory,
      nutritionRecords: nutritionRecords,
      healthRecords: healthRecords,
      profile: profile,
      start: start,
      end: end,
    );

    // 5. Calculate previous summary (period comparison)
    final prevEnd = start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: numDays - 1));
    final prevDates = _getDatesInRange(prevStart, prevEnd);

    final prevDataPoints = _buildDataPoints(
      dates: prevDates,
      nutritionMap: nutritionMap,
      healthMap: healthMap,
      weightMap: weightMap,
      goals: goals,
      profile: profile,
    );

    final previousSummary = _calculateSummary(
      dataPoints: prevDataPoints,
      weightHistory: weightHistory,
      nutritionRecords: nutritionRecords,
      healthRecords: healthRecords,
      profile: profile,
      start: prevStart,
      end: prevEnd,
    );

    return HealthAnalyticsEntity(
      range: range,
      dataPoints: dataPoints,
      summary: summary,
      previousSummary: previousSummary,
    );
  }

  static int _getRangeDays(String range) {
    switch (range) {
      case '7D':
        return 7;
      case '90D':
        return 90;
      case '1Y':
        return 365;
      case '30D':
      default:
        return 30;
    }
  }

  static List<DateTime> _getDatesInRange(DateTime start, DateTime end) {
    final List<DateTime> dates = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final targetEnd = DateTime(end.year, end.month, end.day);
    while (current.isBefore(targetEnd) || current.isAtSameMomentAs(targetEnd)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  static List<AnalyticsDataPointEntity> _buildDataPoints({
    required List<DateTime> dates,
    required Map<String, List<NutritionRecordEntity>> nutritionMap,
    required Map<String, HealthRecordEntity> healthMap,
    required Map<String, List<WeightRecordEntity>> weightMap,
    required NutritionGoalsEntity? goals,
    required UserProfileEntity? profile,
  }) {
    final List<AnalyticsDataPointEntity> points = [];

    // Fallbacks
    final calorieTarget = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final proteinTarget = goals?.proteinTargetGrams ?? 130.0;
    final carbsTarget = goals?.carbsTargetGrams ?? 220.0;
    final fatTarget = goals?.fatTargetGrams ?? 65.0;
    const defaultWaterTarget = 2500.0;

    for (final date in dates) {
      final dateStr = date.toString().split(' ').first;

      // Nutrition
      double calories = 0.0;
      double protein = 0.0;
      double carbs = 0.0;
      double fat = 0.0;
      bool nutritionLogged = false;

      if (nutritionMap.containsKey(dateStr)) {
        nutritionLogged = true;
        for (final r in nutritionMap[dateStr]!) {
          calories += r.calories;
          protein += r.protein;
          carbs += r.carbohydrates;
          fat += r.fats;
        }
      }

      // Health / Reminders
      double water = 0.0;
      double waterTarget = defaultWaterTarget;
      double workoutMinutes = 0.0;
      double workoutCalories = 0.0;
      double habitCompletionRate = 0.0;
      bool waterLogged = false;
      bool exerciseLogged = false;
      bool habitsLogged = false;
      HealthRecordEntity? healthRecord = healthMap[dateStr];

      if (healthRecord != null) {
        water = healthRecord.waterIntakeMl;
        waterTarget = healthRecord.waterTargetMl;
        waterLogged = healthRecord.waterIntakeMl > 0;

        for (final ex in healthRecord.exercises) {
          workoutMinutes += ex.duration;
          workoutCalories += ex.caloriesBurned;
        }
        exerciseLogged = healthRecord.exercises.isNotEmpty;

        if (healthRecord.habits.isNotEmpty) {
          habitsLogged = true;
          int completed = 0;
          healthRecord.habits.forEach((_, val) {
            if (val) completed++;
          });
          habitCompletionRate = completed / healthRecord.habits.length;
        }
      }

      // Wellness Score
      final wellnessScore = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: nutritionLogged,
        healthRecord: healthRecord,
      );

      // Weight
      double? weight;
      if (weightMap.containsKey(dateStr)) {
        final list = weightMap[dateStr]!;
        if (list.isNotEmpty) {
          list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
          weight = list.last.weight;
        }
      }

      points.add(AnalyticsDataPointEntity(
        date: date,
        calories: calories,
        calorieTarget: calorieTarget,
        protein: protein,
        proteinTarget: proteinTarget,
        carbs: carbs,
        carbsTarget: carbsTarget,
        fat: fat,
        fatTarget: fatTarget,
        water: water,
        waterTarget: waterTarget,
        workoutMinutes: workoutMinutes,
        workoutCalories: workoutCalories,
        habitCompletionRate: habitCompletionRate,
        wellnessScore: wellnessScore,
        weight: weight,
        nutritionLogged: nutritionLogged,
        waterLogged: waterLogged,
        exerciseLogged: exerciseLogged,
        habitsLogged: habitsLogged,
      ));
    }

    return points;
  }

  static AnalyticsSummaryEntity _calculateSummary({
    required List<AnalyticsDataPointEntity> dataPoints,
    required List<WeightRecordEntity> weightHistory,
    required List<NutritionRecordEntity> nutritionRecords,
    required List<HealthRecordEntity> healthRecords,
    required UserProfileEntity? profile,
    required DateTime start,
    required DateTime end,
  }) {
    int nutritionLoggedDays = 0;
    int hydrationLoggedDays = 0;
    int exerciseActiveDays = 0;
    int habitsLoggedDays = 0;
    int wellnessLoggedDays = 0;

    double sumCalories = 0.0;
    double sumProtein = 0.0;
    double sumCarbs = 0.0;
    double sumFat = 0.0;
    double sumWater = 0.0;
    double sumWorkoutMinutes = 0.0;
    double sumHabitCompletion = 0.0;
    double sumWellness = 0.0;

    int calorieMetDays = 0;
    int proteinMetDays = 0;
    int hydrationMetDays = 0;

    double maxWellness = 0.0;
    double minWellness = 100.0;

    for (final dp in dataPoints) {
      if (dp.nutritionLogged) {
        nutritionLoggedDays++;
        sumCalories += dp.calories;
        sumProtein += dp.protein;
        sumCarbs += dp.carbs;
        sumFat += dp.fat;

        // ±5% tolerance
        final calDiffPercent = (dp.calories - dp.calorieTarget).abs() / dp.calorieTarget;
        if (calDiffPercent <= 0.05) calorieMetDays++;

        // Protein >= target
        if (dp.protein >= dp.proteinTarget) proteinMetDays++;
      }

      if (dp.waterLogged) {
        hydrationLoggedDays++;
        sumWater += dp.water;
        if (dp.water >= dp.waterTarget) hydrationMetDays++;
      }

      if (dp.exerciseLogged) {
        exerciseActiveDays++;
      }
      sumWorkoutMinutes += dp.workoutMinutes;

      if (dp.habitsLogged) {
        habitsLoggedDays++;
        sumHabitCompletion += dp.habitCompletionRate;
      }

      // Wellness is always calculable
      wellnessLoggedDays++;
      sumWellness += dp.wellnessScore;
      if (dp.wellnessScore > maxWellness) maxWellness = dp.wellnessScore;
      if (dp.wellnessScore < minWellness) minWellness = dp.wellnessScore;
    }

    if (minWellness > 100.0) minWellness = 0.0;

    // Averages (over logged days, except wellness/workout duration which spans overall period days)
    final avgCalories = nutritionLoggedDays > 0 ? sumCalories / nutritionLoggedDays : 0.0;
    final avgProtein = nutritionLoggedDays > 0 ? sumProtein / nutritionLoggedDays : 0.0;
    final avgCarbs = nutritionLoggedDays > 0 ? sumCarbs / nutritionLoggedDays : 0.0;
    final avgFat = nutritionLoggedDays > 0 ? sumFat / nutritionLoggedDays : 0.0;
    final avgWater = hydrationLoggedDays > 0 ? sumWater / hydrationLoggedDays : 0.0;
    final avgWorkoutMinutes = sumWorkoutMinutes / dataPoints.length;
    final avgWellness = wellnessLoggedDays > 0 ? sumWellness / wellnessLoggedDays : 0.0;
    final avgHabitCompletion = habitsLoggedDays > 0 ? sumHabitCompletion / habitsLoggedDays : 0.0;

    // Adherences
    final calorieAdherence = nutritionLoggedDays > 0 ? (calorieMetDays / nutritionLoggedDays) * 100 : 0.0;
    final proteinAdherence = nutritionLoggedDays > 0 ? (proteinMetDays / nutritionLoggedDays) * 100 : 0.0;
    final hydrationAdherence = hydrationLoggedDays > 0 ? (hydrationMetDays / hydrationLoggedDays) * 100 : 0.0;
    final exerciseConsistency = (exerciseActiveDays / dataPoints.length) * 100;
    final habitConsistency = avgHabitCompletion * 100;
    final overallConsistency = (calorieAdherence + proteinAdherence + hydrationAdherence + exerciseConsistency + habitConsistency) / 5;

    // Weight starting/current
    double? startingWeight;
    double? currentWeight;
    double? weightChange;
    double? weightChangePercent;

    final sortedWeightHistory = List<WeightRecordEntity>.from(weightHistory)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (sortedWeightHistory.isNotEmpty) {
      // Find starting weight: first in range, or closest before
      final startLimit = start;
      try {
        startingWeight = sortedWeightHistory.firstWhere((w) => w.recordedAt.isAfter(startLimit) || w.recordedAt.isAtSameMomentAs(startLimit)).weight;
      } catch (_) {
        // Fallback to the latest record before start limit
        final before = sortedWeightHistory.where((w) => w.recordedAt.isBefore(startLimit)).toList();
        if (before.isNotEmpty) {
          startingWeight = before.last.weight;
        } else {
          startingWeight = sortedWeightHistory.first.weight;
        }
      }

      // Find current weight: last in range, or closest before end
      final endLimit = end;
      try {
        currentWeight = sortedWeightHistory.lastWhere((w) => w.recordedAt.isBefore(endLimit) || w.recordedAt.isAtSameMomentAs(endLimit)).weight;
      } catch (_) {
        currentWeight = sortedWeightHistory.last.weight;
      }

      weightChange = currentWeight - startingWeight;
      weightChangePercent = startingWeight > 0 ? (weightChange / startingWeight) * 100 : 0.0;
    }

    // Streak Calculations
    final Set<String> loggedDates = {};
    for (final r in nutritionRecords) {
      loggedDates.add(r.consumedAt.toLocal().toString().split(' ').first);
    }
    for (final r in healthRecords) {
      loggedDates.add(r.date);
    }
    for (final r in weightHistory) {
      loggedDates.add(r.recordedAt.toLocal().toString().split(' ').first);
    }

    final sortedDates = loggedDates.toList()..sort();
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    if (sortedDates.isNotEmpty) {
      DateTime? prevDate;
      for (final dateStr in sortedDates) {
        final parsed = DateTime.parse(dateStr);
        if (prevDate == null) {
          tempStreak = 1;
        } else {
          final diff = parsed.difference(prevDate).inDays;
          if (diff == 1) {
            tempStreak++;
          } else if (diff > 1) {
            if (tempStreak > longestStreak) longestStreak = tempStreak;
            tempStreak = 1;
          }
        }
        prevDate = parsed;
      }
      if (tempStreak > longestStreak) longestStreak = tempStreak;

      // Current Streak
      final todayStr = end.toString().split(' ').first;
      final yesterdayStr = end.subtract(const Duration(days: 1)).toString().split(' ').first;

      if (loggedDates.contains(todayStr) || loggedDates.contains(yesterdayStr)) {
        DateTime checkDate = loggedDates.contains(todayStr) ? end : end.subtract(const Duration(days: 1));
        while (loggedDates.contains(checkDate.toString().split(' ').first)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }
    }

    // Active logging days inside the period
    int activeLogDays = 0;
    for (final dp in dataPoints) {
      if (dp.nutritionLogged || dp.waterLogged || dp.exerciseLogged || dp.habitsLogged || dp.weight != null) {
        activeLogDays++;
      }
    }

    // Trends Engine mappings
    final nutritionTrend = AnalyticsTrendEngine.calculateTrend(
      values: dataPoints.map((dp) {
        if (!dp.nutritionLogged) return 0.0;
        final calDiffPercent = (dp.calories - dp.calorieTarget).abs() / dp.calorieTarget;
        return calDiffPercent <= 0.05 ? 1.0 : 0.0;
      }).toList(),
      threshold: 0.05,
    );

    final hydrationTrend = AnalyticsTrendEngine.calculateTrend(
      values: dataPoints.map((dp) => dp.water).toList(),
      threshold: 100.0,
    );

    final exerciseTrend = AnalyticsTrendEngine.calculateTrend(
      values: dataPoints.map((dp) => dp.workoutMinutes).toList(),
      threshold: 5.0,
    );

    final habitsTrend = AnalyticsTrendEngine.calculateTrend(
      values: dataPoints.map((dp) => dp.habitCompletionRate).toList(),
      threshold: 0.05,
    );

    final wellnessTrend = AnalyticsTrendEngine.calculateTrend(
      values: dataPoints.map((dp) => dp.wellnessScore).toList(),
      threshold: 3.0,
    );

    final weightTrend = AnalyticsTrendEngine.calculateWeightTrend(
      startingWeight: startingWeight,
      currentWeight: currentWeight,
      goal: profile?.fitnessGoal ?? 'Maintain',
    );

    return AnalyticsSummaryEntity(
      averageCalories: avgCalories,
      averageProtein: avgProtein,
      averageCarbs: avgCarbs,
      averageFat: avgFat,
      averageWater: avgWater,
      averageWorkoutMinutes: avgWorkoutMinutes,
      averageWellness: avgWellness,
      averageHabitCompletion: avgHabitCompletion,
      calorieAdherencePercentage: calorieAdherence,
      proteinAdherencePercentage: proteinAdherence,
      hydrationAdherencePercentage: hydrationAdherence,
      exerciseConsistencyPercentage: exerciseConsistency,
      habitConsistencyPercentage: habitConsistency,
      overallConsistencyPercentage: overallConsistency,
      startingWeight: startingWeight,
      currentWeight: currentWeight,
      weightChange: weightChange,
      weightChangePercentage: weightChangePercent,
      bestWellnessScore: maxWellness,
      lowestWellnessScore: minWellness,
      activeLoggingDays: activeLogDays,
      currentLoggingStreak: currentStreak,
      longestLoggingStreak: longestStreak,
      trends: {
        'nutrition': nutritionTrend,
        'hydration': hydrationTrend,
        'exercise': exerciseTrend,
        'habits': habitsTrend,
        'wellness': wellnessTrend,
        'weight': weightTrend,
      },
    );
  }
}
