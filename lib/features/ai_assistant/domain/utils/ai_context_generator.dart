import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../grocery/domain/entities/grocery_item_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../../food/data/repositories/food_asset_repository.dart';
import '../../../reminders/domain/entities/reminder_entity.dart';

import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/domain/utils/nutrition_insights_engine.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../../../weekly_report/domain/utils/weekly_report_calculator.dart';
import '../../../smart_eat/domain/engines/nutrition_gap_engine.dart';
import '../../../smart_eat/domain/engines/recommendation_scoring_engine.dart';
import '../../../analytics/domain/utils/health_analytics_calculator.dart';
import '../../../analytics/domain/utils/analytics_insight_engine.dart';
import '../../../insights/domain/utils/insight_engine.dart';
import '../../../health/domain/utils/wellness_calculator.dart';

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
    List<String> chatExclusions = const [],
    String userPrompt = '',
  }) {
    final double goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double goalPro = goals?.proteinTargetGrams ?? 150.0;
    final double goalCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double goalFats = goals?.fatTargetGrams ?? 65.0;

    // Today's metrics
    final progress = NutritionCalculator.calculateProgress(
      dailyRecords: todayRecords,
      goals: goals,
    );

    // Remaining targets
    final double remainingCals = (goalCals - progress.totalCalories).clamp(0.0, double.infinity);
    final double remainingPro = (goalPro - progress.totalProtein).clamp(0.0, double.infinity);
    final double remainingCarbs = (goalCarbs - progress.totalCarbs).clamp(0.0, double.infinity);
    final double remainingFats = (goalFats - progress.totalFats).clamp(0.0, double.infinity);

    // Recent History Metrics
    final intelligence = NutritionInsightsEngine.analyzeHistory(
      records: historyRecords,
      goals: goals,
      daysCount: 7,
    );

    // Long term progress summary
    final progressSummary = ProgressCalculator.calculateSummary(
      nutritionHistory: historyRecords,
      healthHistory: historyHealth,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      daysCount: 7,
    );

    // Weekly Report details
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

    // Smart Eat Food Context
    final gap = NutritionGapEngine.calculate(
      profile: profile,
      goals: goals,
      todayRecords: todayRecords,
      todayHealth: todayHealth,
    );

    final hour = DateTime.now().hour;
    String mealType = 'Snack';
    if (hour >= 6 && hour < 11) {
      mealType = 'Breakfast';
    } else if (hour >= 11 && hour < 16) {
      mealType = 'Lunch';
    } else if (hour >= 16 && hour < 22) {
      mealType = 'Dinner';
    }

    final recommendations = RecommendationScoringEngine.score(
      foods: availableFoods,
      profile: profile,
      gap: gap,
      currentMealType: mealType,
      pantryItems: pantryItems,
      groceryLists: const [],
      recentLogs: historyRecords,
      favoriteFoods: const [],
      recentFoods: const [],
      chatExclusions: chatExclusions,
    );

    // Analytics Context
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
    final analyticsFocus = AnalyticsInsightEngine.detectFocusArea(analyticsSummary, analytics.dataPoints);
    final analyticsStrongest = AnalyticsInsightEngine.detectStrongestCategory(analyticsSummary);

    // Daily Focus
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

    final buffer = StringBuffer();

    // 1. FITFUEL SYSTEM ROLE
    buffer.writeln('=== FITFUEL SYSTEM ROLE ===');
    buffer.writeln('You are FitFuel AI, a helpful nutrition and wellness assistant. Provide practical, concise, and clear coaching based on the user\'s data.');
    buffer.writeln('');

    // 2. USER PROFILE
    buffer.writeln('=== USER PROFILE ===');
    if (profile != null) {
      if (profile.age != null) buffer.writeln('- Age: ${profile.age}');
      if (profile.gender != null) buffer.writeln('- Gender: ${profile.gender}');
      if (profile.height != null) buffer.writeln('- Height: ${profile.height?.toStringAsFixed(1)} cm');
      if (profile.weight != null) buffer.writeln('- Weight: ${profile.weight?.toStringAsFixed(1)} kg');
      if (profile.activityLevel != null) buffer.writeln('- Activity Level: ${profile.activityLevel}');
      if (profile.fitnessGoal != null) buffer.writeln('- Fitness Goal: ${profile.fitnessGoal}');
      if (profile.dietaryPreference != null) buffer.writeln('- Dietary Preference: ${profile.dietaryPreference}');
    } else {
      buffer.writeln('- Profile details not yet configured.');
    }
    buffer.writeln('');

    // 3. TODAY'S NUTRITION
    buffer.writeln('=== TODAY\'S NUTRITION ===');
    buffer.writeln('Goals:');
    buffer.writeln('- Calories Target: ${goalCals.toStringAsFixed(0)} kcal');
    buffer.writeln('- Protein Target: ${goalPro.toStringAsFixed(0)} g');
    buffer.writeln('- Carbohydrate Target: ${goalCarbs.toStringAsFixed(0)} g');
    buffer.writeln('- Fat Target: ${goalFats.toStringAsFixed(0)} g');
    buffer.writeln('Progress:');
    buffer.writeln('- Calories: ${progress.totalCalories.toStringAsFixed(0)} kcal consumed / ${remainingCals.toStringAsFixed(0)} kcal remaining');
    buffer.writeln('- Protein: ${progress.totalProtein.toStringAsFixed(1)} g consumed / ${remainingPro.toStringAsFixed(1)} g remaining');
    buffer.writeln('- Carbohydrates: ${progress.totalCarbs.toStringAsFixed(1)} g consumed / ${remainingCarbs.toStringAsFixed(1)} g remaining');
    buffer.writeln('- Fat: ${progress.totalFats.toStringAsFixed(1)} g consumed / ${remainingFats.toStringAsFixed(1)} g remaining');
    buffer.writeln('');

    // 4. HEALTH & HABITS
    buffer.writeln('=== HEALTH & HABITS ===');
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
      buffer.writeln('- Water Intake: ${todayHealth.waterIntakeMl.toStringAsFixed(0)} ml / ${todayHealth.waterTargetMl.toStringAsFixed(0)} ml');
      buffer.writeln('- Workout Duration: $exMins minutes');
      buffer.writeln('- Workout Calories Burned: ${exCals.toStringAsFixed(0)} kcal');
      buffer.writeln('- Habits Completed: $habitsCompleted / ${todayHealth.habits.length}');
      buffer.writeln('- Wellness Score: ${score.toStringAsFixed(0)} / 100');
    } else {
      buffer.writeln('- Hydration and activity details not logged today.');
    }
    buffer.writeln('');

    // 5. MEAL PLAN (FITFUEL ADAPTIVE MEAL PLAN CONTEXT)
    buffer.writeln(_buildMealPlanContext(
      mealPlan: mealPlan,
      profile: profile,
      totalCalories: progress.totalCalories,
      remainingCalories: remainingCals,
      totalProtein: progress.totalProtein,
      remainingProtein: remainingPro,
      calorieTarget: goalCals,
      proteinTarget: goalPro,
    ));
    buffer.writeln('');

    // 6. SMART EAT (FITFUEL SMART EAT FOOD CONTEXT)
    buffer.writeln(_buildSmartEatContext(
      mealType: mealType,
      remainingCalories: gap.remainingCalories,
      remainingProtein: gap.remainingProtein,
      chatExclusions: chatExclusions,
      availableFoods: availableFoods,
      recommendations: recommendations,
    ));
    buffer.writeln('');

    // 7. GROCERY & PANTRY (FITFUEL SMART GROCERY CONTEXT)
    buffer.writeln(_buildGroceryContext(
      groceryItems: groceryItems,
      pantryItems: pantryItems,
      profile: profile,
    ));
    buffer.writeln('');

    // 8. DAILY ROUTINE (FITFUEL DAILY ROUTINE CONTEXT)
    buffer.writeln(_buildRoutineContext(dailyRoutine));
    buffer.writeln('');

    // 9. PROGRESS (USER LONG-TERM PROGRESS & ACHIEVEMENT)
    buffer.writeln(_buildProgressContext(
      intelligence: intelligence,
      progressSummary: progressSummary,
      weightHistory: weightHistory,
    ));
    buffer.writeln('');

    // 10. WEEKLY REPORT (FITFUEL WEEKLY HEALTH REPORT)
    buffer.writeln(_buildWeeklyReportContext(
      weeklyReport: weeklyReport,
      comparisonReport: comparisonReport,
      scoreChangeText: scoreChangeText,
    ));
    buffer.writeln('');

    // 11. ANALYTICS (FITFUEL ANALYTICS CONTEXT)
    buffer.writeln(_buildAnalyticsContext(
      analyticsSummary: analyticsSummary,
      analyticsFocus: analyticsFocus,
      analyticsStrongest: analyticsStrongest,
    ));
    buffer.writeln('');

    // 12. SMART INSIGHTS (FITFUEL SMART INSIGHTS CONTEXT)
    buffer.writeln(_buildInsightsContext(dailyFocus));
    buffer.writeln('');

    // 13. AVAILABLE FOODS DATABASE
    buffer.writeln(_buildFoodDatabaseContext(availableFoods));
    buffer.writeln('');

    // 14. CURRENT CONVERSATION PREFERENCES
    buffer.writeln('=== CURRENT CONVERSATION PREFERENCES ===');
    buffer.writeln('- Excluded foods (temporary): ${chatExclusions.isEmpty ? "None" : chatExclusions.join(", ")}');
    buffer.writeln('');

    // 15. CURRENT USER QUESTION
    buffer.writeln('=== CURRENT USER QUESTION ===');
    buffer.writeln(userPrompt);
    buffer.writeln('');

    buffer.writeln('=== END CONTEXT ===');
    return buffer.toString();
  }

  static String _buildMealPlanContext({
    required MealPlanEntity? mealPlan,
    required UserProfileEntity? profile,
    required double totalCalories,
    required double remainingCalories,
    required double totalProtein,
    required double remainingProtein,
    required double calorieTarget,
    required double proteinTarget,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL ADAPTIVE MEAL PLAN CONTEXT ===');
    buffer.writeln('- Fitness Goal: ${profile?.fitnessGoal ?? "None"}');
    buffer.writeln('- Activity Level: ${profile?.activityLevel ?? "None"}');
    buffer.writeln('- Dietary Preference: ${profile?.dietaryPreference ?? "None"}');
    buffer.writeln('- Consumed Calories: ${totalCalories.toStringAsFixed(0)} kcal');
    buffer.writeln('- Remaining Calories: ${remainingCalories.toStringAsFixed(0)} kcal');
    buffer.writeln('- Consumed Protein: ${totalProtein.toStringAsFixed(1)} g');
    buffer.writeln('- Remaining Protein: ${remainingProtein.toStringAsFixed(1)} g');

    final kcalDeficit = (calorieTarget - totalCalories).clamp(0.0, double.infinity);
    final proDeficit = (proteinTarget - totalProtein).clamp(0.0, double.infinity);
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
    return buffer.toString();
  }

  static String _buildSmartEatContext({
    required String mealType,
    required double remainingCalories,
    required double remainingProtein,
    required List<String> chatExclusions,
    required List<FoodEntity> availableFoods,
    required List<dynamic> recommendations,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL SMART EAT FOOD CONTEXT ===');
    buffer.writeln('Current meal: $mealType');
    buffer.writeln('Remaining calories: ${remainingCalories.toStringAsFixed(0)}');
    buffer.writeln('Remaining protein: ${remainingProtein.toStringAsFixed(0)}');
    buffer.writeln('Exclusions: ${chatExclusions.isEmpty ? "None" : chatExclusions.join(", ")}');
    buffer.writeln('Recommended foods:');
    if (recommendations.isNotEmpty) {
      final repo = FoodAssetRepository.instance;
      for (int i = 0; i < recommendations.length && i < 4; i++) {
        final rec = recommendations[i];
        final food = availableFoods.firstWhere((f) => f.id == rec.foodId, orElse: () => FoodEntity(
          id: rec.foodId,
          name: rec.foodName,
          category: rec.category,
          servingSize: rec.servingSize,
          servingUnit: 'g',
          calories: rec.calories,
          protein: rec.protein,
          carbohydrates: rec.carbs,
          fats: rec.fat,
          fiber: rec.fiber,
          sugar: 0,
          sodium: 0,
        ));
        final recipeAvail = repo.getRecipe(rec.foodId) != null ? 'available' : 'not available';
        final dietType = food.dietTypeVal;
        buffer.writeln('${i + 1}. ${rec.foodName}');
        buffer.writeln('   foodId: ${rec.foodId}');
        buffer.writeln('   dietType: $dietType');
        buffer.writeln('   calories: ${rec.calories.toStringAsFixed(0)}');
        buffer.writeln('   protein: ${rec.protein.toStringAsFixed(1)}');
        buffer.writeln('   carbs: ${rec.carbs.toStringAsFixed(1)}');
        buffer.writeln('   fat: ${rec.fat.toStringAsFixed(1)}');
        buffer.writeln('   imageUrl: ${rec.imageUrl}');
        buffer.writeln('   recipe availability: $recipeAvail');
      }
    } else {
      buffer.writeln('  None');
    }
    return buffer.toString();
  }

  static String _buildGroceryContext({
    required List<GroceryItemEntity> groceryItems,
    required List<PantryItemEntity> pantryItems,
    required UserProfileEntity? profile,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL SMART GROCERY CONTEXT ===');
    buffer.writeln('- Grocery Items Remaining:');
    final remaining = groceryItems.where((i) => !i.isPurchased).toList();
    if (remaining.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in remaining.take(10)) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (${item.category})');
      }
    }

    buffer.writeln('- Grocery Items Purchased:');
    final purchased = groceryItems.where((i) => i.isPurchased).toList();
    if (purchased.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in purchased.take(10)) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (${item.category})');
      }
    }

    buffer.writeln('- Pantry Items:');
    if (pantryItems.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final item in pantryItems.take(10)) {
        buffer.writeln('  * ${item.foodName}: ${item.quantity.toStringAsFixed(1)} ${item.unit} (Expires: ${item.expiryDate.toString().split(' ').first}, Status: ${item.getExpiryStatus()})');
      }
    }

    buffer.writeln('- Dietary Preferences: ${profile?.dietaryPreference ?? 'None'}');
    buffer.writeln('- Food Exclusions: None');
    return buffer.toString();
  }

  static String _buildRoutineContext(DailyRoutineEntity? dailyRoutine) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL DAILY ROUTINE CONTEXT ===');
    if (dailyRoutine != null) {
      buffer.writeln('- Routine Completion: ${dailyRoutine.completionPercentage.toStringAsFixed(1)}%');
      buffer.writeln('- Completed Tasks: ${dailyRoutine.completedItems.map((i) => i.title).join(', ')}');
      buffer.writeln('- Pending Tasks: ${dailyRoutine.pendingItems.map((i) => i.title).join(', ')}');
      if (dailyRoutine.nextReminder != null) {
        buffer.writeln('- Next Reminder: ${dailyRoutine.nextReminder!.title} at ${dailyRoutine.nextReminder!.scheduledTime}');
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
    } else {
      buffer.writeln('- Daily routine details not configured.');
    }
    return buffer.toString();
  }

  static String _buildProgressContext({
    required dynamic intelligence,
    required dynamic progressSummary,
    required List<WeightRecordEntity> weightHistory,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== USER LONG-TERM PROGRESS & ACHIEVEMENT (7 DAYS) ===');
    buffer.writeln('- Active Logged Days: ${intelligence.loggedDaysCount} / 7 days');
    buffer.writeln('- Weekly Logging Consistency: ${intelligence.consistencyScore.toStringAsFixed(0)}%');
    buffer.writeln('- Average Calories Logged: ${intelligence.avgCalories.toStringAsFixed(0)} kcal');
    buffer.writeln('- Calorie Consistency: ${progressSummary.calorieConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Protein Target Consistency: ${progressSummary.proteinConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Hydration Consistency: ${progressSummary.waterConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Exercise Consistency: ${progressSummary.exerciseConsistencyPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Habit Completion Average Rate: ${progressSummary.habitsAvgCompletionRate.toStringAsFixed(1)}%');
    buffer.writeln('- Wellness Trend: ${progressSummary.wellnessTrend} (Average Wellness Score: ${progressSummary.wellnessAvgScore.toStringAsFixed(1)})');
    if (weightHistory.isNotEmpty) {
      buffer.writeln('- Weight Tracker: Start: ${progressSummary.startingWeight.toStringAsFixed(1)} kg, Current: ${progressSummary.currentWeight.toStringAsFixed(1)} kg, Change: ${progressSummary.weightChange.toStringAsFixed(1)} kg (${progressSummary.weightChangePercent.toStringAsFixed(1)}%)');
    } else {
      buffer.writeln('- Weight Tracker: No weight history yet');
    }
    buffer.writeln('- Nutrition Streak: ${progressSummary.currentStreak} days current, Max: ${progressSummary.longestStreak} days');
    final unlocked = (progressSummary.milestones as List).where((dynamic m) => m.isUnlocked == true).map((dynamic m) => m.title as String).join(', ');
    buffer.writeln('- Unlocked Milestones: ${unlocked.isNotEmpty ? unlocked : 'None yet'}');
    return buffer.toString();
  }

  static String _buildWeeklyReportContext({
    required dynamic weeklyReport,
    required dynamic comparisonReport,
    required String scoreChangeText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL WEEKLY HEALTH REPORT ===');
    buffer.writeln('Weekly Health Score: ${weeklyReport.healthScore.toStringAsFixed(0)}/100');
    buffer.writeln('Previous Week Score: ${comparisonReport.healthScore.toStringAsFixed(0)}/100');
    buffer.writeln('Score Change: $scoreChangeText');
    buffer.writeln('Strongest Area: ${weeklyReport.strongestArea} (${weeklyReport.strongestAreaDescription})');
    buffer.writeln('Weakest Area: ${weeklyReport.weakestArea} (${weeklyReport.weakestAreaDescription})');
    buffer.writeln('Nutrition:');
    buffer.writeln('- calorie consistency: ${weeklyReport.calorieConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('- protein consistency: ${weeklyReport.proteinConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('- nutrition logging days: ${weeklyReport.nutritionDaysLogged}');
    buffer.writeln('Hydration:');
    buffer.writeln('- target days: ${weeklyReport.waterDaysMet}');
    buffer.writeln('- total water: ${weeklyReport.avgWater.toStringAsFixed(0)} ml');
    buffer.writeln('- hydration consistency: ${weeklyReport.hydrationConsistencyPercent.toStringAsFixed(0)}%');
    buffer.writeln('Exercise:');
    buffer.writeln('- active days: ${weeklyReport.exerciseActiveDays}');
    buffer.writeln('- workout minutes: ${weeklyReport.exerciseTotalMinutes}');
    buffer.writeln('- calories burned: ${weeklyReport.exerciseCaloriesBurned.toStringAsFixed(0)}');
    buffer.writeln('Habits:');
    buffer.writeln('- average completion: ${weeklyReport.habitsAvgCompletionPercent.toStringAsFixed(0)}%');
    buffer.writeln('- most consistent habit: ${weeklyReport.habitsBestName}');
    buffer.writeln('- least consistent habit: ${weeklyReport.habitsAttentionName}');
    buffer.writeln('Wellness:');
    buffer.writeln('- average score: ${weeklyReport.wellnessAvgScore.toStringAsFixed(0)}');
    buffer.writeln('- trend: ${weeklyReport.wellnessTrend}');
    buffer.writeln('Weight:');
    buffer.writeln('- starting weight: ${weeklyReport.startingWeight.toStringAsFixed(1)} kg');
    buffer.writeln('- current weight: ${weeklyReport.currentWeight.toStringAsFixed(1)} kg');
    buffer.writeln('- change: ${weeklyReport.weightChange.toStringAsFixed(1)} kg');
    buffer.writeln('- percentage change: ${weeklyReport.weightChangePercent.toStringAsFixed(1)}%');
    buffer.writeln('Achievements: ${weeklyReport.unlockedMilestones.join(", ")}');
    buffer.writeln('Current Streak: ${weeklyReport.nutritionStreak} days');
    buffer.writeln('Next Week Action Plan: ${weeklyReport.actionPlan.join("; ")}');
    return buffer.toString();
  }

  static String _buildAnalyticsContext({
    required dynamic analyticsSummary,
    required dynamic analyticsFocus,
    required String analyticsStrongest,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL ANALYTICS CONTEXT ===');
    buffer.writeln('- Selected Range: 30D');
    buffer.writeln('- Overall Consistency: ${analyticsSummary.overallConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Nutrition Adherence: ${analyticsSummary.calorieAdherencePercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Hydration Adherence: ${analyticsSummary.hydrationAdherencePercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Exercise Consistency: ${analyticsSummary.exerciseConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Habit Consistency: ${analyticsSummary.habitConsistencyPercentage.toStringAsFixed(0)}%');
    buffer.writeln('- Wellness Trend: ${analyticsSummary.trends['wellness'] ?? 'Stable'}');
    buffer.writeln('- Weight Trend: ${analyticsSummary.trends['weight'] ?? 'Stable'}');
    buffer.writeln('- Weakest Area: ${analyticsFocus.category}');
    buffer.writeln('- Strongest Area: $analyticsStrongest');
    return buffer.toString();
  }

  static String _buildInsightsContext(dynamic dailyFocus) {
    final buffer = StringBuffer();
    buffer.writeln('=== FITFUEL SMART INSIGHTS CONTEXT ===');
    buffer.writeln('- Daily Focus: ${dailyFocus.title} - ${dailyFocus.description}');
    return buffer.toString();
  }

  static String _buildFoodDatabaseContext(List<FoodEntity> availableFoods) {
    final buffer = StringBuffer();
    if (availableFoods.isNotEmpty) {
      buffer.writeln('=== AVAILABLE FOODS DATABASE ===');
      for (final food in availableFoods.take(10)) {
        buffer.writeln('- Food: ${food.name} | Category: ${food.category} | Serving: ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} | Calories: ${food.calories.toStringAsFixed(0)} kcal | Protein: ${food.protein.toStringAsFixed(1)}g | Carbs: ${food.carbohydrates.toStringAsFixed(1)}g | Fats: ${food.fats.toStringAsFixed(1)}g | Fiber: ${food.fiber.toStringAsFixed(1)}g | Sugar: ${food.sugar.toStringAsFixed(1)}g | Sodium: ${food.sodium.toStringAsFixed(0)}mg | id: ${food.id} | isFavorite: ${food.isFavorite} | isIndian: ${food.isIndian} | isVegetarian: ${food.isVegetarian} | isVegan: ${food.isVegan} | dietaryTags: ${food.dietaryTags.join(',')} | mealTypes: ${food.mealTypes.join(',')}');
      }
    }
    return buffer.toString();
  }
}
