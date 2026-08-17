import '../entities/reminder_entity.dart';
import '../entities/reminder_settings_entity.dart';
import '../entities/daily_routine_entity.dart';
import 'reminder_calculator.dart';
import 'reminder_priority_engine.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../grocery/domain/entities/grocery_list_entity.dart';
import '../../../grocery/domain/entities/grocery_preferences_entity.dart';

class DailyRoutineCalculator {
  static DailyRoutineEntity calculateRoutine({
    required String date,
    required ReminderSettingsEntity settings,
    required HealthRecordEntity? todayHealth,
    required List<NutritionRecordEntity> todayNutrition,
    required List<WeightRecordEntity> weightHistory,
    required List<NutritionRecordEntity> nutritionHistory,
    required List<HealthRecordEntity> healthHistory,
    required String? activityLevel,
    DateTime? referenceDate,
    MealPlanEntity? todayMealPlan,
    GroceryListEntity? todayGroceryList,
    GroceryPreferencesEntity? groceryPreferences,
  }) {
    final now = referenceDate ?? DateTime.now();
    final items = <ReminderEntity>[];

    // (Breakfast, Hydration, Lunch, Snack, Dinner, Exercise, Habits, Weight, Nutrition logging, Weekly Review, AI coaching...)


    // 1. Breakfast
    if (settings.mealEnabled) {
      final isLogged = ReminderCalculator.isMealLogged(todayNutrition, 'Breakfast');
      String desc = isLogged ? 'Breakfast already logged.' : 'Breakfast time — remember to log your meal.';
      if (!isLogged && todayMealPlan != null) {
        final breakfastMeal = todayMealPlan.breakfast;
        if (breakfastMeal != null && breakfastMeal.foods.isNotEmpty) {
          final foodsText = breakfastMeal.foods.map((f) => '${f.servingQuantity.toStringAsFixed(0)} ${f.unit} of ${f.food.name}').join(' + ');
          desc = 'Your planned breakfast is ready: $foodsText.';
        }
      }

      items.add(ReminderEntity(
        id: 'breakfast',
        title: 'Breakfast 🍳',
        description: desc,
        type: ReminderType.breakfast,
        scheduledTime: settings.breakfastTime,
        enabled: true,
        completed: isLogged,
        priority: ReminderPriorityEngine.getPriority(ReminderType.breakfast),
        actionRoute: '/meal-planner',
      ));
    }

    // 2. Hydration Reminders
    if (settings.hydrationEnabled) {
      final waterTimes = ['09:00', '11:00', '13:00', '15:00', '17:00', '19:00'];
      final target = todayHealth?.waterTargetMl ?? 2000.0;
      final current = todayHealth?.waterIntakeMl ?? 0.0;
      final remaining = (target - current).clamp(0.0, double.infinity);
      final isComplete = current >= target;

      for (int i = 0; i < waterTimes.length; i++) {
        final share = target * (i + 1) / waterTimes.length;
        final completed = current >= share || isComplete;
        items.add(ReminderEntity(
          id: 'hydration_$i',
          title: 'Drink Water 💧',
          description: completed
              ? 'Stay hydrated!'
              : "You're ${remaining.toStringAsFixed(0)} ml away from today's water goal. A glass of water now can help you stay on track.",
          type: ReminderType.hydration,
          scheduledTime: waterTimes[i],
          enabled: true,
          completed: completed,
          priority: ReminderPriorityEngine.getPriority(ReminderType.hydration, isCriticalHydration: !completed && remaining > 1000),
          actionRoute: '/dashboard',
        ));
      }
    }

    // 3. Lunch
    if (settings.mealEnabled) {
      final isLogged = ReminderCalculator.isMealLogged(todayNutrition, 'Lunch');
      String desc = isLogged ? 'Lunch already logged.' : 'Time for lunch. Need a healthy suggestion?';
      if (!isLogged && todayMealPlan != null) {
        final lunchMeal = todayMealPlan.lunch;
        if (lunchMeal != null && lunchMeal.foods.isNotEmpty) {
          final foodsText = lunchMeal.foods.map((f) => '${f.servingQuantity.toStringAsFixed(0)} ${f.unit} of ${f.food.name}').join(' + ');
          desc = 'Your planned lunch is: $foodsText.';
        }
      }

      items.add(ReminderEntity(
        id: 'lunch',
        title: 'Lunch 🍽️',
        description: desc,
        type: ReminderType.lunch,
        scheduledTime: settings.lunchTime,
        enabled: true,
        completed: isLogged,
        priority: ReminderPriorityEngine.getPriority(ReminderType.lunch),
        actionRoute: '/meal-planner',
      ));
    }

    // 4. Snack
    if (settings.mealEnabled) {
      final isLogged = ReminderCalculator.isMealLogged(todayNutrition, 'Snack');
      String desc = isLogged ? 'Snack already logged.' : 'Time for a quick snack.';
      if (!isLogged && todayMealPlan != null) {
        final snackMeal = todayMealPlan.morningSnack ?? todayMealPlan.eveningSnack;
        if (snackMeal != null && snackMeal.foods.isNotEmpty) {
          final foodsText = snackMeal.foods.map((f) => '${f.servingQuantity.toStringAsFixed(0)} ${f.unit} of ${f.food.name}').join(' + ');
          desc = 'Your planned snack is: $foodsText.';
        }
      }

      items.add(ReminderEntity(
        id: 'snack',
        title: 'Snack 🍎',
        description: desc,
        type: ReminderType.snack,
        scheduledTime: settings.snackTime,
        enabled: true,
        completed: isLogged,
        priority: ReminderPriorityEngine.getPriority(ReminderType.snack),
        actionRoute: '/meal-planner',
      ));
    }

    // 5. Dinner
    if (settings.mealEnabled) {
      final isLogged = ReminderCalculator.isMealLogged(todayNutrition, 'Dinner');
      String desc = isLogged ? 'Dinner already logged.' : 'Time for dinner. Don\'t forget to log your meal.';
      if (!isLogged && todayMealPlan != null) {
        final dinnerMeal = todayMealPlan.dinner;
        if (dinnerMeal != null && dinnerMeal.foods.isNotEmpty) {
          final foodsText = dinnerMeal.foods.map((f) => '${f.servingQuantity.toStringAsFixed(0)} ${f.unit} of ${f.food.name}').join(' + ');
          desc = 'Your planned dinner is: $foodsText.';
        }
      }

      items.add(ReminderEntity(
        id: 'dinner',
        title: 'Dinner 🍲',
        description: desc,
        type: ReminderType.dinner,
        scheduledTime: settings.dinnerTime,
        enabled: true,
        completed: isLogged,
        priority: ReminderPriorityEngine.getPriority(ReminderType.dinner),
        actionRoute: '/meal-planner',
      ));
    }

    // 6. Exercise
    if (settings.exerciseEnabled) {
      final isComplete = ReminderCalculator.isExerciseComplete(todayHealth);
      final workoutType = activityLevel?.toLowerCase() == 'sedentary'
          ? 'Gentle movement session'
          : activityLevel?.toLowerCase() == 'lightly active'
              ? 'Moderate workout'
              : 'Workout training';
      items.add(ReminderEntity(
        id: 'exercise',
        title: 'Exercise 🏃',
        description: isComplete ? 'Workout completed!' : 'Your workout is still waiting 💪 A 30-minute $workoutType can keep you on track.',
        type: ReminderType.exercise,
        scheduledTime: settings.exerciseTime,
        enabled: true,
        completed: isComplete,
        priority: ReminderPriorityEngine.getPriority(ReminderType.exercise),
        actionRoute: '/dashboard',
      ));
    }

    // 7. Habits
    if (settings.habitEnabled) {
      final isComplete = ReminderCalculator.isHabitsComplete(todayHealth);
      final pendingCount = ReminderCalculator.incompleteHabitsCount(todayHealth);
      items.add(ReminderEntity(
        id: 'habit',
        title: 'Habits ✅',
        description: isComplete ? 'All habits completed!' : 'You still have $pendingCount habits to complete today.',
        type: ReminderType.habit,
        scheduledTime: '10:00',
        enabled: true,
        completed: isComplete,
        priority: ReminderPriorityEngine.getPriority(ReminderType.habit),
        actionRoute: '/dashboard',
      ));
    }

    // 8. Weight
    if (settings.weightEnabled) {
      final isLogged = ReminderCalculator.isWeightLoggedRecently(weightHistory, referenceDate: now);
      items.add(ReminderEntity(
        id: 'weight',
        title: 'Weight Weigh-In ⚖️',
        description: isLogged ? 'Weight logged recently.' : 'Time for your weekly weigh-in ⚖️',
        type: ReminderType.weight,
        scheduledTime: settings.weightTime,
        enabled: true,
        completed: isLogged,
        repeatPattern: 'weekly',
        priority: ReminderPriorityEngine.getPriority(ReminderType.weight),
        actionRoute: '/progress',
      ));
    }

    // 9. Nutrition Logging
    if (settings.nutritionLoggingEnabled) {
      final isLoggedSome = todayNutrition.isNotEmpty;
      final isLoggedAll = todayNutrition.length >= 3;
      items.add(ReminderEntity(
        id: 'nutrition_logging',
        title: 'Nutrition Logging 📝',
        description: isLoggedAll
            ? 'Nutrition log complete!'
            : isLoggedSome
                ? 'You\'ve started today\'s nutrition log. Keep tracking your meals.'
                : 'Start your nutrition log for today 🍎',
        type: ReminderType.nutritionLogging,
        scheduledTime: '21:30',
        enabled: true,
        completed: isLoggedAll,
        priority: ReminderPriorityEngine.getPriority(ReminderType.nutritionLogging),
        actionRoute: '/food-search',
      ));
    }

    // 10. Weekly Review
    if (settings.weeklyReviewEnabled) {
      final isAvailable = ReminderCalculator.isWeeklyReviewAvailable(
        nutritionHistory,
        healthHistory,
        weightHistory,
        referenceDate: now,
      );
      items.add(ReminderEntity(
        id: 'weekly_review',
        title: 'Weekly Report 📊',
        description: isAvailable ? 'Your weekly FitFuel report is ready 📊' : 'Log more activities to generate weekly insights.',
        type: ReminderType.weeklyReview,
        scheduledTime: settings.weeklyReviewTime,
        enabled: true,
        completed: !isAvailable,
        repeatPattern: 'weekly',
        priority: ReminderPriorityEngine.getPriority(ReminderType.weeklyReview),
        actionRoute: '/weekly-report',
      ));
    }

    // 11. AI Coaching
    if (settings.aiCoachEnabled) {
      items.add(ReminderEntity(
        id: 'ai_coaching',
        title: 'Ask FitFuel AI 💬',
        description: 'Want a quick health check-in? Ask FitFuel AI about your progress.',
        type: ReminderType.aiCoaching,
        scheduledTime: settings.aiCoachTime,
        enabled: true,
        completed: false,
        priority: ReminderPriorityEngine.getPriority(ReminderType.aiCoaching),
        actionRoute: '/ai-assistant',
      ));
    }

    // 12. Grocery Shopping
    final showGroceryReminder = (groceryPreferences?.autoGenerateWeeklyList ?? true) &&
        todayGroceryList != null &&
        todayGroceryList.remainingItems > 0;
    if (showGroceryReminder) {
      items.add(const ReminderEntity(
        id: 'grocery_shopping',
        title: 'Grocery Shopping 🛒',
        description: '🛒 Grocery shopping pending — log remaining items.',
        type: ReminderType.custom,
        scheduledTime: '18:00',
        enabled: true,
        completed: false,
        priority: ReminderPriority.medium,
        actionRoute: '/grocery',
      ));
    }

    final enabledItems = items.where((i) => i.enabled).toList();
    final completedItems = enabledItems.where((i) => i.completed).toList();
    final pendingItems = enabledItems.where((i) => !i.completed).toList();
    final totalCount = enabledItems.length;
    final completedCount = completedItems.length;
    final completionPct = totalCount > 0 ? (completedCount / totalCount * 100.0) : 100.0;

    final nowHour = now.hour;
    final nowMin = now.minute;
    ReminderEntity? nextRem;
    
    final sortedPending = List<ReminderEntity>.from(pendingItems)
      ..sort((a, b) => _compareTimeStrings(a.scheduledTime, b.scheduledTime));

    for (final item in sortedPending) {
      final parts = item.scheduledTime.split(':');
      final itemHour = int.tryParse(parts[0]) ?? 0;
      final itemMin = int.tryParse(parts[1]) ?? 0;
      if (itemHour > nowHour || (itemHour == nowHour && itemMin > nowMin)) {
        nextRem = item;
        break;
      }
    }
    nextRem ??= sortedPending.firstOrNull;

    return DailyRoutineEntity(
      date: date,
      routineItems: enabledItems,
      completedItems: completedItems,
      pendingItems: pendingItems,
      completionPercentage: double.parse(completionPct.toStringAsFixed(1)),
      nextReminder: nextRem,
      totalReminders: totalCount,
      completedReminders: completedCount,
    );
  }

  static int _compareTimeStrings(String a, String b) {
    final aParts = a.split(':');
    final bParts = b.split(':');
    final aHour = int.tryParse(aParts[0]) ?? 0;
    final aMin = int.tryParse(aParts[1]) ?? 0;
    final bHour = int.tryParse(bParts[0]) ?? 0;
    final bMin = int.tryParse(bParts[1]) ?? 0;

    if (aHour != bHour) return aHour.compareTo(bHour);
    return aMin.compareTo(bMin);
  }

  static String generateSummaryText(DailyRoutineEntity routine) {
    if (routine.completionPercentage >= 100.0) {
      return "Fantastic job! You've fully completed all routine check-ins today. Keep up this amazing momentum! 🌟";
    } else if (routine.completionPercentage >= 70.0) {
      return "You're doing exceptionally well today. Just a few more routine check-ins to reach 100%.";
    } else {
      final pendingWater = routine.pendingItems.any((i) => i.type == ReminderType.hydration);
      final pendingMeal = routine.pendingItems.any((i) => i.type == ReminderType.breakfast || i.type == ReminderType.lunch || i.type == ReminderType.dinner);
      
      if (pendingWater && pendingMeal) {
        return "You're making steady progress. Focus on drinking water and logging your next meal to stay on track.";
      } else if (pendingWater) {
        return 'You are doing well today. Your hydration is slightly behind your target.';
      } else {
        return 'You are making steady progress. Remember to check off your pending tasks.';
      }
    }
  }
}
