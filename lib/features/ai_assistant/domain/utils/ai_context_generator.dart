import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/domain/utils/nutrition_insights_engine.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../../../weekly_report/domain/utils/weekly_report_calculator.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../reminders/domain/entities/reminder_entity.dart';
import '../../../grocery/domain/entities/grocery_item_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../../analytics/domain/utils/health_analytics_calculator.dart';
import '../../../analytics/domain/utils/analytics_insight_engine.dart';
import '../../../insights/domain/utils/insight_engine.dart';

class AiContextGenerator {
  /// Compiles user health profile, nutrition goals, today's logs, history averages, wellness scores, and meal plans into a structured context string
  static String generateContext({
    required List<NutritionRecordEntity> todayRecords,
    required List<NutritionRecordEntity> historyRecords,
    required NutritionGoalsEntity? goals,
    HealthRecordEntity? todayHealth,
    List<HealthRecordEntity> historyHealth = const [],
    UserProfileEntity? profile,
    List<WeightRecordEntity> weightHistory = const [],
    List<FoodEntity> availableFoods = const [],
    MealPlanEntity? mealPlan,
    DailyRoutineEntity? dailyRoutine,
    List<GroceryItemEntity> groceryItems = const [],
    List<PantryItemEntity> pantryItems = const [],
  }) {
    final double goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double goalPro = goals?.proteinTargetGrams ?? 150.0;
    final double goalCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double goalFats = goals?.fatTargetGrams ?? 65.0;

    // 1. Today's metrics
    final progress = NutritionCalculator.calculateProgress(
      dailyRecords: todayRecords,
      goals: goals,
    );

    // Remaining targets
    final double remainingCals = (goalCals - progress.totalCalories).clamp(0.0, double.infinity);
    final double remainingPro = (goalPro - progress.totalProtein).clamp(0.0, double.infinity);
    final double remainingCarbs = (goalCarbs - progress.totalCarbs).clamp(0.0, double.infinity);
    final double remainingFats = (goalFats - progress.totalFats).clamp(0.0, double.infinity);

    // 2. Recent History Metrics
    final intelligence = NutritionInsightsEngine.analyzeHistory(
      records: historyRecords,
      goals: goals,
      daysCount: 7,
    );



    final buffer = StringBuffer();
    buffer.writeln('=== USER NUTRITION CONTEXT ===');

    if (profile != null) {
      buffer.writeln('USER HEALTH PROFILE:');
      if (profile.age != null) buffer.writeln('- Age: ${profile.age}');
      if (profile.gender != null) buffer.writeln('- Gender: ${profile.gender}');
      if (profile.height != null) buffer.writeln('- Height: ${profile.height?.toStringAsFixed(1)} cm');
      if (profile.weight != null) buffer.writeln('- Weight: ${profile.weight?.toStringAsFixed(1)} kg');
      if (profile.activityLevel != null) buffer.writeln('- Activity Level: ${profile.activityLevel}');
      if (profile.fitnessGoal != null) buffer.writeln('- Fitness Goal: ${profile.fitnessGoal}');
      if (profile.dietaryPreference != null) buffer.writeln('- Dietary Preference: ${profile.dietaryPreference}');
      buffer.writeln('');
    }

    buffer.writeln('USER GOALS:');
    buffer.writeln('- Calories Target: ${goalCals.toStringAsFixed(0)} kcal');
    buffer.writeln('- Protein Target: ${goalPro.toStringAsFixed(0)} g');
    buffer.writeln('- Carbohydrate Target: ${goalCarbs.toStringAsFixed(0)} g');
    buffer.writeln('- Fat Target: ${goalFats.toStringAsFixed(0)} g');
    buffer.writeln('');

    buffer.writeln('TODAY CONSUMED & REMAINING:');
    buffer.writeln('- Calories: ${progress.totalCalories.toStringAsFixed(0)} kcal consumed / ${remainingCals.toStringAsFixed(0)} kcal remaining');
    buffer.writeln('- Protein: ${progress.totalProtein.toStringAsFixed(1)} g consumed / ${remainingPro.toStringAsFixed(1)} g remaining');
    buffer.writeln('- Carbohydrates: ${progress.totalCarbs.toStringAsFixed(1)} g consumed / ${remainingCarbs.toStringAsFixed(1)} g remaining');
    buffer.writeln('- Fat: ${progress.totalFats.toStringAsFixed(1)} g consumed / ${remainingFats.toStringAsFixed(1)} g remaining');
    buffer.writeln('');

    if (todayHealth != null) {
      int exMins = 0;
      double exCals = 0.0;
      for (final ex in todayHealth.exercises) {
        exMins += ex.duration;
        exCals += ex.caloriesBurned;
      }
      int habitsCompleted = 0;
      todayHealth.habits.forEach((_, v) {
        if (v) habitsCompleted++;
      });
      final double score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: todayRecords.isNotEmpty,
        healthRecord: todayHealth,
      );

      buffer.writeln('TODAY HYDRATION, WORKOUT & HABITS:');
      buffer.writeln('- Water Intake: ${todayHealth.waterIntakeMl.toStringAsFixed(0)} ml / ${todayHealth.waterTargetMl.toStringAsFixed(0)} ml');
      buffer.writeln('- Workout Duration: $exMins minutes');
      buffer.writeln('- Workout Calories Burned: ${exCals.toStringAsFixed(0)} kcal');
      buffer.writeln('- Habits Completed: $habitsCompleted / ${todayHealth.habits.length}');
      buffer.writeln('- Wellness Score: ${score.toStringAsFixed(0)} / 100');
      buffer.writeln('');
    }

    buffer.writeln('RECENT HISTORY (LAST 7 DAYS):');
    buffer.writeln('- Active Logged Days: ${intelligence.loggedDaysCount} / 7 days');
    buffer.writeln('- Weekly Logging Consistency: ${intelligence.consistencyScore.toStringAsFixed(0)}%');
    buffer.writeln('- Average Calories Logged: ${intelligence.avgCalories.toStringAsFixed(0)} kcal');
    for (final trend in intelligence.trends) {
      final direction = trend.direction.toString().split('.').last.toUpperCase();
      buffer.writeln('- ${trend.metricName} Intake Trend: $direction (${trend.changePercentage.toStringAsFixed(0)}% shift)');
    }
    buffer.writeln('');

    // Calculate long term progress summary
    final progressSummary = ProgressCalculator.calculateSummary(
      nutritionHistory: historyRecords,
      healthHistory: historyHealth,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      daysCount: 7,
    );

    buffer.writeln('=== USER LONG-TERM PROGRESS & ACHIEVEMENT (7 DAYS) ===');
    buffer.writeln('- Calorie Consistency: ${progressSummary.calorieConsistencyPercent.toStringAsFixed(1)}% of days close to target');
    buffer.writeln('- Protein Target Consistency: ${progressSummary.proteinConsistencyPercent.toStringAsFixed(1)}% of days met');
    buffer.writeln('- Hydration Consistency: ${progressSummary.waterConsistencyPercent.toStringAsFixed(1)}% of days met');
    buffer.writeln('- Exercise Consistency: ${progressSummary.exerciseConsistencyPercent.toStringAsFixed(1)}% of days active');
    buffer.writeln('- Exercise Total Workouts: ${progressSummary.exerciseActiveDays} days / Total Duration: ${progressSummary.exerciseTotalMinutes} mins / Burned: ${progressSummary.exerciseTotalCaloriesBurned.toStringAsFixed(0)} kcal');
    buffer.writeln('- Habit Completion Average Rate: ${progressSummary.habitsAvgCompletionRate.toStringAsFixed(1)}%');
    buffer.writeln('- Wellness Trend: ${progressSummary.wellnessTrend} (Average Wellness Score: ${progressSummary.wellnessAvgScore.toStringAsFixed(1)})');
    if (weightHistory.isNotEmpty) {
      buffer.writeln('- Weight Tracker: Start: ${progressSummary.startingWeight.toStringAsFixed(1)} kg, Current: ${progressSummary.currentWeight.toStringAsFixed(1)} kg, Change: ${progressSummary.weightChange.toStringAsFixed(1)} kg (${progressSummary.weightChangePercent.toStringAsFixed(1)}%)');
    } else {
      buffer.writeln('- Weight Tracker: No weight history yet');
    }
    buffer.writeln('- Nutrition Streak: ${progressSummary.currentStreak} days current, Max: ${progressSummary.longestStreak} days');
    final unlocked = progressSummary.milestones.where((m) => m.isUnlocked).map((m) => m.title).join(', ');
    buffer.writeln('- Unlocked Milestones: ${unlocked.isNotEmpty ? unlocked : 'None yet'}');
    buffer.writeln('');

    // Phase 21 Weekly Report Summary details
    final weeklyReport = WeeklyReportCalculator.calculateReport(
      nutritionHistory: historyRecords,
      healthHistory: historyHealth,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      period: 'completed',
    );

    final comparisonReport = WeeklyReportCalculator.calculateReport(
      nutritionHistory: historyRecords,
      healthHistory: historyHealth,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      period: 'previous',
    );

    final double scoreDiff = weeklyReport.healthScore - comparisonReport.healthScore;
    final String scoreChangeText = comparisonReport.healthScore == 0.0
        ? 'Not enough previous data'
        : (scoreDiff > 0 ? '+${scoreDiff.toStringAsFixed(1)} points' : '${scoreDiff.toStringAsFixed(1)} points');

    buffer.writeln('=== FITFUEL WEEKLY HEALTH REPORT ===');
    buffer.writeln('Period: Completed Week');
    buffer.writeln('Weekly Health Score: ${weeklyReport.healthScore.toStringAsFixed(0)}/100');
    buffer.writeln('Previous Week Score: ${comparisonReport.healthScore.toStringAsFixed(0)}/100');
    buffer.writeln('Score Change: $scoreChangeText');
    buffer.writeln('Strongest Area: ${weeklyReport.strongestArea} (${weeklyReport.strongestAreaDescription})');
    buffer.writeln('Weakest Area: ${weeklyReport.weakestArea} (${weeklyReport.weakestAreaDescription})');
    buffer.writeln('');
    buffer.writeln('Nutrition:');
    buffer.writeln('- calorie consistency: ${weeklyReport.calorieConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('- protein consistency: ${weeklyReport.proteinConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('- nutrition logging days: ${weeklyReport.nutritionDaysLogged}');
    buffer.writeln('');
    buffer.writeln('Hydration:');
    buffer.writeln('- target days: ${weeklyReport.waterDaysMet}');
    buffer.writeln('- total water: ${weeklyReport.avgWater.toStringAsFixed(0)} ml');
    buffer.writeln('- hydration consistency: ${weeklyReport.hydrationConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('');
    buffer.writeln('Exercise:');
    buffer.writeln('- active days: ${weeklyReport.exerciseActiveDays}');
    buffer.writeln('- workout minutes: ${weeklyReport.exerciseTotalMinutes}');
    buffer.writeln('- calories burned: ${weeklyReport.exerciseCaloriesBurned.toStringAsFixed(0)}');
    buffer.writeln('');
    buffer.writeln('Habits:');
    buffer.writeln('- average completion: ${weeklyReport.habitsAvgCompletionPercent.toStringAsFixed(0)}%');
    buffer.writeln('- most consistent habit: ${weeklyReport.habitsBestName}');
    buffer.writeln('- least consistent habit: ${weeklyReport.habitsAttentionName}');
    buffer.writeln('');
    buffer.writeln('Wellness:');
    buffer.writeln('- average score: ${weeklyReport.wellnessAvgScore.toStringAsFixed(0)}');
    buffer.writeln('- trend: ${weeklyReport.wellnessTrend}');
    buffer.writeln('');
    buffer.writeln('Weight:');
    buffer.writeln('- starting weight: ${weeklyReport.startingWeight.toStringAsFixed(1)} kg');
    buffer.writeln('- current weight: ${weeklyReport.currentWeight.toStringAsFixed(1)} kg');
    buffer.writeln('- change: ${weeklyReport.weightChange.toStringAsFixed(1)} kg');
    buffer.writeln('- percentage change: ${weeklyReport.weightChangePercent.toStringAsFixed(1)}%');
    buffer.writeln('');
    buffer.writeln('Achievements: ${weeklyReport.unlockedMilestones.join(", ")}');
    buffer.writeln('Current Streak: ${weeklyReport.nutritionStreak} days');
    buffer.writeln('Next Week Action Plan: ${weeklyReport.actionPlan.join("; ")}');
    buffer.writeln('=== END WEEKLY HEALTH REPORT ===');
    buffer.writeln('');

    buffer.writeln('=== FITFUEL ADAPTIVE MEAL PLAN CONTEXT ===');
    buffer.writeln('- Fitness Goal: ${profile?.fitnessGoal ?? "None"}');
    buffer.writeln('- Activity Level: ${profile?.activityLevel ?? "None"}');
    buffer.writeln('- Dietary Preference: ${profile?.dietaryPreference ?? "None"}');
    buffer.writeln('- Consumed Calories: ${progress.totalCalories.toStringAsFixed(0)} kcal');
    buffer.writeln('- Remaining Calories: ${remainingCals.toStringAsFixed(0)} kcal');
    buffer.writeln('- Consumed Protein: ${progress.totalProtein.toStringAsFixed(1)} g');
    buffer.writeln('- Remaining Protein: ${remainingPro.toStringAsFixed(1)} g');
    
    final kcalDeficit = (goalCals - progress.totalCalories).clamp(0.0, double.infinity);
    final proDeficit = (goalPro - progress.totalProtein).clamp(0.0, double.infinity);
    buffer.writeln('- Calories Deficit: ${kcalDeficit.toStringAsFixed(0)} kcal');
    buffer.writeln('- Protein Deficit: ${proDeficit.toStringAsFixed(1)} g');

    if (mealPlan != null) {
      buffer.writeln('Today\'s Active Meal Plan:');
      for (final meal in mealPlan.meals) {
        buffer.writeln('  * Meal: ${meal.mealType} | Planned Calories: ${meal.totalCalories.toStringAsFixed(0)} kcal | Planned Protein: ${meal.totalProtein.toStringAsFixed(1)}g');
        for (final pf in meal.foods) {
          buffer.writeln('    - ${pf.servingQuantity.toStringAsFixed(0)} ${pf.unit} of ${pf.food.name} (${pf.calories.toStringAsFixed(0)} kcal)');
        }
      }
    } else {
      buffer.writeln('No active generated meal plan.');
    }
    buffer.writeln('=== END MEAL PLAN CONTEXT ===');
    buffer.writeln('');

    buffer.writeln('=== FITFUEL PERSONALIZED COACH CONTEXT ===');
    buffer.writeln('');
    buffer.writeln('PROFILE');
    if (profile != null) {
      buffer.writeln('- Age: ${profile.age ?? "Missing data"}');
      buffer.writeln('- Gender: ${profile.gender ?? "Missing data"}');
      buffer.writeln('- Height: ${profile.height != null ? "${profile.height!.toStringAsFixed(1)} cm" : "Missing data"}');
      buffer.writeln('- Weight: ${profile.weight != null ? "${profile.weight!.toStringAsFixed(1)} kg" : "Missing data"}');
      buffer.writeln('- Activity level: ${profile.activityLevel ?? "Missing data"}');
      buffer.writeln('- Fitness goal: ${profile.fitnessGoal ?? "Missing data"}');
      buffer.writeln('- Dietary preference: ${profile.dietaryPreference ?? "Missing data"}');
    } else {
      buffer.writeln('- Age: Missing data');
      buffer.writeln('- Gender: Missing data');
      buffer.writeln('- Height: Missing data');
      buffer.writeln('- Weight: Missing data');
      buffer.writeln('- Activity level: Missing data');
      buffer.writeln('- Fitness goal: Missing data');
      buffer.writeln('- Dietary preference: Missing data');
    }
    buffer.writeln('');

    buffer.writeln('TODAY');
    buffer.writeln('- Calories consumed: ${progress.totalCalories.toStringAsFixed(0)} kcal');
    buffer.writeln('- Calories remaining: ${remainingCals.toStringAsFixed(0)} kcal');
    buffer.writeln('- Protein: ${progress.totalProtein.toStringAsFixed(1)} g');
    buffer.writeln('- Carbs: ${progress.totalCarbs.toStringAsFixed(1)} g');
    buffer.writeln('- Fat: ${progress.totalFats.toStringAsFixed(1)} g');
    if (todayHealth != null) {
      int exMins = 0;
      double exCals = 0.0;
      for (final ex in todayHealth.exercises) {
        exMins += ex.duration;
        exCals += ex.caloriesBurned;
      }
      int habitsCompleted = 0;
      todayHealth.habits.forEach((_, v) {
        if (v) habitsCompleted++;
      });
      final double score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: todayRecords.isNotEmpty,
        healthRecord: todayHealth,
      );
      buffer.writeln('- Water: ${todayHealth.waterIntakeMl.toStringAsFixed(0)} ml');
      buffer.writeln('- Water target: ${todayHealth.waterTargetMl.toStringAsFixed(0)} ml');
      buffer.writeln('- Exercise duration: $exMins minutes');
      buffer.writeln('- Exercise calories: ${exCals.toStringAsFixed(0)} kcal');
      buffer.writeln('- Habit completion: $habitsCompleted / ${todayHealth.habits.length}');
      buffer.writeln('- Wellness score: ${score.toStringAsFixed(0)} / 100');
    } else {
      buffer.writeln('- Water: Missing data');
      buffer.writeln('- Water target: Missing data');
      buffer.writeln('- Exercise duration: Missing data');
      buffer.writeln('- Exercise calories: Missing data');
      buffer.writeln('- Habit completion: Missing data');
      buffer.writeln('- Wellness score: Missing data');
    }
    buffer.writeln('');

    buffer.writeln('GOALS');
    buffer.writeln('- Daily calorie target: ${goalCals.toStringAsFixed(0)} kcal');
    buffer.writeln('- Protein target: ${goalPro.toStringAsFixed(0)} g');
    buffer.writeln('- Carb target: ${goalCarbs.toStringAsFixed(0)} g');
    buffer.writeln('- Fat target: ${goalFats.toStringAsFixed(0)} g');
    if (todayHealth != null) {
      buffer.writeln('- Water target: ${todayHealth.waterTargetMl.toStringAsFixed(0)} ml');
    } else {
      buffer.writeln('- Water target: Missing data');
    }
    buffer.writeln('');

    buffer.writeln('7-DAY PERFORMANCE');
    buffer.writeln('- Nutrition consistency: ${progressSummary.calorieConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Hydration consistency: ${progressSummary.waterConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Exercise active days: ${progressSummary.exerciseActiveDays}');
    buffer.writeln('- Exercise minutes: ${progressSummary.exerciseTotalMinutes}');
    buffer.writeln('- Habit completion: ${progressSummary.habitsAvgCompletionRate.toStringAsFixed(1)}%');
    buffer.writeln('- Average wellness: ${progressSummary.wellnessAvgScore.toStringAsFixed(1)}');
    if (weightHistory.isNotEmpty) {
      buffer.writeln('- Weight change: ${progressSummary.weightChange.toStringAsFixed(1)} kg');
    } else {
      buffer.writeln('- Weight change: Missing data');
    }
    buffer.writeln('- Current streak: ${progressSummary.currentStreak} days');
    buffer.writeln('');

    buffer.writeln('WEEKLY REPORT');
    buffer.writeln('- Weekly score: ${weeklyReport.healthScore.toStringAsFixed(0)}');
    buffer.writeln('- Previous score: ${comparisonReport.healthScore.toStringAsFixed(0)}');
    buffer.writeln('- Score change: $scoreChangeText');
    buffer.writeln('- Strongest area: ${weeklyReport.strongestArea.isNotEmpty ? weeklyReport.strongestArea : 'Missing data'}');
    buffer.writeln('- Weakest area: ${weeklyReport.weakestArea.isNotEmpty ? weeklyReport.weakestArea : 'Missing data'}');
    final achievementsStr = weeklyReport.unlockedMilestones.join(', ');
    buffer.writeln('- Achievements: ${achievementsStr.isNotEmpty ? achievementsStr : 'None yet'}');
    buffer.writeln('- Next-week action plan: ${weeklyReport.actionPlan.isNotEmpty ? weeklyReport.actionPlan.join('; ') : 'Missing data'}');
    buffer.writeln('');

    buffer.writeln('LONG-TERM PROGRESS');
    if (weightHistory.isNotEmpty) {
      buffer.writeln('- Starting weight: ${progressSummary.startingWeight.toStringAsFixed(1)} kg');
      buffer.writeln('- Current weight: ${progressSummary.currentWeight.toStringAsFixed(1)} kg');
      buffer.writeln('- Weight change: ${progressSummary.weightChange.toStringAsFixed(1)} kg');
      buffer.writeln('- Percentage change: ${progressSummary.weightChangePercent.toStringAsFixed(1)}%');
    } else {
      buffer.writeln('- Starting weight: Missing data');
      buffer.writeln('- Current weight: Missing data');
      buffer.writeln('- Weight change: Missing data');
      buffer.writeln('- Percentage change: Missing data');
    }
    buffer.writeln('- Longest nutrition streak: ${progressSummary.longestStreak} days');
    final unlockedAchievements = progressSummary.milestones.where((m) => m.isUnlocked).map((m) => m.title).join(', ');
    buffer.writeln('- Achievements unlocked: ${unlockedAchievements.isNotEmpty ? unlockedAchievements : 'None yet'}');
    buffer.writeln('');

    if (availableFoods.isNotEmpty) {
      buffer.writeln('AVAILABLE FOODS DATABASE:');
      for (final food in availableFoods) {
        buffer.writeln('- Food: ${food.name} | Category: ${food.category} | Serving: ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} | Calories: ${food.calories.toStringAsFixed(0)} kcal | Protein: ${food.protein.toStringAsFixed(1)}g | Carbs: ${food.carbohydrates.toStringAsFixed(1)}g | Fats: ${food.fats.toStringAsFixed(1)}g | Fiber: ${food.fiber.toStringAsFixed(1)}g | Sugar: ${food.sugar.toStringAsFixed(1)}g | Sodium: ${food.sodium.toStringAsFixed(0)}mg | id: ${food.id} | isFavorite: ${food.isFavorite} | isIndian: ${food.isIndian} | isVegetarian: ${food.isVegetarian} | isVegan: ${food.isVegan} | dietaryTags: ${food.dietaryTags.join(',')} | mealTypes: ${food.mealTypes.join(',')}');
      }
      buffer.writeln('');
    }

    if (dailyRoutine != null) {
      buffer.writeln('=== FITFUEL DAILY ROUTINE CONTEXT ===');
      buffer.writeln('- Routine Completion: ${dailyRoutine.completionPercentage.toStringAsFixed(1)}%');
      buffer.writeln('- Completed Tasks: ${dailyRoutine.completedItems.map((i) => i.title).join(', ')}');
      buffer.writeln('- Pending Tasks: ${dailyRoutine.pendingItems.map((i) => i.title).join(', ')}');
      if (dailyRoutine.nextReminder != null) {
        buffer.writeln('- Next Reminder: ${dailyRoutine.nextReminder!.title} at ${dailyRoutine.nextReminder!.scheduledTime}');
      } else {
        buffer.writeln('- Next Reminder: None');
      }
      
      final waterPending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.hydration);
      buffer.writeln('- Hydration Status: ${waterPending ? "Behind Goal" : "On Track"}');
      
      final mealPending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.breakfast || i.type == ReminderType.lunch || i.type == ReminderType.dinner);
      buffer.writeln('- Meal Status: ${mealPending ? "Unlogged meals pending" : "All meals logged"}');
      
      final exercisePending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.exercise);
      buffer.writeln('- Exercise Status: ${exercisePending ? "Workout pending" : "Workout completed"}');
      
      final habitsPending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.habit);
      buffer.writeln('- Habit Status: ${habitsPending ? "Habits incomplete" : "Habits complete"}');
      
      final weightPending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.weight);
      buffer.writeln('- Weight Reminder Status: ${weightPending ? "Weigh-in pending" : "Weigh-in completed"}');
      
      final reviewPending = dailyRoutine.pendingItems.any((i) => i.type == ReminderType.weeklyReview);
      buffer.writeln('- Weekly Review Status: ${reviewPending ? "Report pending" : "Report reviewed"}');
      buffer.writeln('');
    }

    // === FITFUEL SMART GROCERY CONTEXT ===
    buffer.writeln('=== FITFUEL SMART GROCERY CONTEXT ===');
    buffer.writeln('- Grocery Items Remaining:');
    final remaining = groceryItems.where((i) => !i.isPurchased).toList();
    if (remaining.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in remaining) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (${item.category})');
      }
    }

    buffer.writeln('- Grocery Items Purchased:');
    final purchased = groceryItems.where((i) => i.isPurchased).toList();
    if (purchased.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in purchased) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (${item.category})');
      }
    }

    buffer.writeln('- Pantry Items:');
    if (pantryItems.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in pantryItems) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (Expires: ${item.expiryDate.toString().split(' ').first}, Status: ${item.getExpiryStatus()})');
      }
    }

    buffer.writeln('- Dietary Preferences: ${profile?.dietaryPreference ?? 'None'}');
    buffer.writeln('- Food Exclusions: None');
    buffer.writeln('');

    // === FITFUEL ANALYTICS CONTEXT ===
    final analytics = HealthAnalyticsCalculator.calculate(
      range: '30D',
      today: DateTime.now(),
      nutritionRecords: historyRecords,
      healthRecords: historyHealth,
      weightHistory: weightHistory,
      profile: profile,
      goals: goals,
    );
    final analyticsSummary = analytics.summary;
    final analyticsInsights = AnalyticsInsightEngine.generateInsights(
      dataPoints: analytics.dataPoints,
      summary: analyticsSummary,
      previousSummary: analytics.previousSummary,
    );
    final analyticsFocus = AnalyticsInsightEngine.detectFocusArea(analyticsSummary, analytics.dataPoints);
    final analyticsStrongest = AnalyticsInsightEngine.detectStrongestCategory(analyticsSummary);
    final analyticsBest = AnalyticsInsightEngine.calculateBestDay(analytics.dataPoints);

    buffer.writeln('=== FITFUEL ANALYTICS CONTEXT ===');
    buffer.writeln('- Selected Range: 30D');
    buffer.writeln('- Overall Consistency: ${analyticsSummary.overallConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Nutrition Adherence: ${analyticsSummary.calorieAdherencePercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Hydration Adherence: ${analyticsSummary.hydrationAdherencePercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Exercise Consistency: ${analyticsSummary.exerciseConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Habit Consistency: ${analyticsSummary.habitConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Wellness Trend: ${analyticsSummary.trends['wellness'] ?? 'Stable'}');
    buffer.writeln('- Weight Trend: ${analyticsSummary.trends['weight'] ?? 'Stable'}');
    if (analyticsBest != null) {
      buffer.writeln('- Best Day: ${analyticsBest.date.toString().split(' ').first} (Score: ${analyticsBest.score.toStringAsFixed(0)}/100)');
    } else {
      buffer.writeln('- Best Day: None');
    }
    buffer.writeln('- Weakest Area: ${analyticsFocus.category}');
    buffer.writeln('- Strongest Area: $analyticsStrongest');
    if (analytics.previousSummary != null) {
      buffer.writeln('- Period Comparison: Wellness: ${analyticsSummary.averageWellness.toStringAsFixed(1)} vs ${analytics.previousSummary!.averageWellness.toStringAsFixed(1)}');
    }
    buffer.writeln('- Major Insights:');
    for (final insight in analyticsInsights) {
      buffer.writeln('  * ${insight.title}: ${insight.description}');
    }
    buffer.writeln('');

    // === FITFUEL SMART INSIGHTS CONTEXT ===
    final insightsList = InsightEngine.generateInsights(
      today: DateTime.now(),
      profile: profile,
      goals: goals,
      nutritionHistory: historyRecords,
      healthHistory: historyHealth,
      weightHistory: weightHistory,
      pantryItems: pantryItems,
    );
    final dailyFocus = InsightEngine.selectDailyFocus(insightsList);

    buffer.writeln('=== FITFUEL SMART INSIGHTS CONTEXT ===');
    buffer.writeln('- Daily Focus: ${dailyFocus.title} - ${dailyFocus.description}');
    buffer.writeln('- Active Insights:');
    if (insightsList.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final insight in insightsList) {
        buffer.writeln('  * [${insight.priority.toString().split('.').last.toUpperCase()}] ${insight.title}: ${insight.description} (Recommendation: ${insight.recommendation})');
      }
    }
    buffer.writeln('');

    buffer.writeln('=== END CONTEXT ===');

    return buffer.toString();
  }
}
