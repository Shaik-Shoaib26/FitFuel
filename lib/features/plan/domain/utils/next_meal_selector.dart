import 'package:flutter/foundation.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../meal_planner/domain/entities/planned_meal_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../reminders/domain/entities/reminder_settings_entity.dart';

/// Status of a meal slot in today's plan.
enum MealStatus {
  completed,
  current,
  upcoming,
  missed,
}

/// Result of evaluating the next upcoming meal.
@immutable
class NextMealSelection {
  final PlannedMealEntity? meal;
  final String mealSlot;
  final String displaySlot;
  final String scheduledTime;
  final double calories;
  final bool isNextDay;
  final bool isAllCompleted;
  final int completedCount;
  final int totalCount;
  final Map<PlannedMealEntity, MealStatus> mealStatuses;

  const NextMealSelection({
    this.meal,
    required this.mealSlot,
    required this.displaySlot,
    required this.scheduledTime,
    required this.calories,
    this.isNextDay = false,
    this.isAllCompleted = false,
    required this.completedCount,
    required this.totalCount,
    this.mealStatuses = const {},
  });

  MealStatus statusFor(PlannedMealEntity m) =>
      mealStatuses[m] ?? MealStatus.upcoming;
}

/// Pure deterministic utility for selecting the next upcoming meal
/// and computing meal completion statuses.
class NextMealSelector {
  static const List<String> canonicalSlotOrder = [
    'breakfast',
    'morning snack',
    'lunch',
    'afternoon snack',
    'evening snack',
    'snack',
    'dinner',
  ];

  static const Map<String, String> defaultSlotTimes = {
    'breakfast': '08:00',
    'morning snack': '10:30',
    'lunch': '13:00',
    'afternoon snack': '16:00',
    'evening snack': '17:30',
    'snack': '16:00',
    'dinner': '20:00',
  };

  /// Normalizes meal type string for comparison.
  static String normalizeSlotName(String slot) {
    return slot.toLowerCase().replaceAll('_', ' ').trim();
  }

  /// Formats "HH:mm" 24h string into "h:mm AM/PM".
  static String formatTimeOfDay(String time24) {
    final trimmed = time24.trim();
    if (trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minFormatted = minute.toString().padLeft(2, '0');
    return '$hour12:$minFormatted $period';
  }

  /// Parses "HH:mm" or "h:mm AM/PM" relative to the given [date].
  static DateTime parseTimeToDateTime(DateTime date, String timeStr) {
    final trimmed = timeStr.trim();
    int hour = 8;
    int minute = 0;

    final is12Hour = trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM');
    if (is12Hour) {
      final isPm = trimmed.toUpperCase().contains('PM');
      final clean = trimmed
          .replaceAll(RegExp(r'[a-zA-Z]'), '')
          .trim();
      final parts = clean.split(':');
      if (parts.isNotEmpty) {
        hour = int.tryParse(parts[0]) ?? 8;
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      }
      if (parts.length > 1) {
        minute = int.tryParse(parts[1]) ?? 0;
      }
    } else {
      final parts = trimmed.split(':');
      if (parts.isNotEmpty) {
        hour = int.tryParse(parts[0]) ?? 8;
      }
      if (parts.length > 1) {
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Gets the scheduled 24h time string for a given meal slot.
  static String getScheduledTimeForSlot({
    required String mealType,
    ReminderSettingsEntity? reminderSettings,
    Map<String, String>? customMealTimes,
  }) {
    final norm = normalizeSlotName(mealType);

    // 1. Explicit custom meal times
    if (customMealTimes != null) {
      for (final entry in customMealTimes.entries) {
        if (normalizeSlotName(entry.key) == norm) {
          return entry.value;
        }
      }
    }

    // 2. Reminder settings
    if (reminderSettings != null) {
      if (norm == 'breakfast') return reminderSettings.breakfastTime;
      if (norm == 'lunch') return reminderSettings.lunchTime;
      if (norm == 'dinner') return reminderSettings.dinnerTime;
      if (norm == 'afternoon snack' || norm == 'snack') {
        return reminderSettings.snackTime;
      }
    }

    // 3. Default slot times
    if (defaultSlotTimes.containsKey(norm)) {
      return defaultSlotTimes[norm]!;
    }

    return '12:00';
  }

  /// Matches logged nutrition records against planned meals without over-completing.
  static Set<PlannedMealEntity> findCompletedMeals(
    List<PlannedMealEntity> meals,
    List<NutritionRecordEntity> loggedToday,
  ) {
    final completed = <PlannedMealEntity>{};
    final remainingRecords = List<NutritionRecordEntity>.from(loggedToday);

    // Pass 1: Exact slot matches
    for (final meal in meals) {
      final norm = normalizeSlotName(meal.mealType);
      final idx = remainingRecords.indexWhere(
        (r) => normalizeSlotName(r.mealType) == norm,
      );
      if (idx != -1) {
        completed.add(meal);
        remainingRecords.removeAt(idx);
      }
    }

    // Pass 2: Snack generic matches
    for (final meal in meals) {
      if (completed.contains(meal)) continue;
      final norm = normalizeSlotName(meal.mealType);
      if (norm.contains('snack')) {
        final idx = remainingRecords.indexWhere(
          (r) => normalizeSlotName(r.mealType).contains('snack'),
        );
        if (idx != -1) {
          completed.add(meal);
          remainingRecords.removeAt(idx);
        }
      }
    }

    return completed;
  }

  /// Sorts meals by custom scheduled time if present, or by canonical slot sequence.
  static List<PlannedMealEntity> sortMeals(
    List<PlannedMealEntity> meals, {
    required DateTime date,
    ReminderSettingsEntity? reminderSettings,
    Map<String, String>? customMealTimes,
  }) {
    final list = List<PlannedMealEntity>.from(meals);

    list.sort((a, b) {
      final timeA = getScheduledTimeForSlot(
        mealType: a.mealType,
        reminderSettings: reminderSettings,
        customMealTimes: customMealTimes,
      );
      final timeB = getScheduledTimeForSlot(
        mealType: b.mealType,
        reminderSettings: reminderSettings,
        customMealTimes: customMealTimes,
      );

      final dtA = parseTimeToDateTime(date, timeA);
      final dtB = parseTimeToDateTime(date, timeB);

      final cmpTime = dtA.compareTo(dtB);
      if (cmpTime != 0) return cmpTime;

      // Fallback canonical order
      final normA = normalizeSlotName(a.mealType);
      final normB = normalizeSlotName(b.mealType);
      final idxA = canonicalSlotOrder.indexOf(normA);
      final idxB = canonicalSlotOrder.indexOf(normB);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.mealType.compareTo(b.mealType);
    });

    return list;
  }

  /// Sorts meals strictly by canonical fallback order without requiring timestamps.
  /// Naturally skips slots that do not exist in the plan without inserting missing snacks.
  static List<PlannedMealEntity> sortByCanonicalOrder(List<PlannedMealEntity> meals) {
    final list = List<PlannedMealEntity>.from(meals);
    list.sort((a, b) {
      final normA = normalizeSlotName(a.mealType);
      final normB = normalizeSlotName(b.mealType);
      final idxA = canonicalSlotOrder.indexOf(normA);
      final idxB = canonicalSlotOrder.indexOf(normB);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.mealType.compareTo(b.mealType);
    });
    return list;
  }

  /// Pure deterministic calculation of the next upcoming meal.
  static NextMealSelection determineNextMeal({
    required MealPlanEntity? plan,
    required List<NutritionRecordEntity> loggedToday,
    required DateTime now,
    ReminderSettingsEntity? reminderSettings,
    Map<String, String>? customMealTimes,
    MealPlanEntity? nextDayPlan,
  }) {
    if (plan == null || plan.meals.isEmpty) {
      return const NextMealSelection(
        meal: null,
        mealSlot: '',
        displaySlot: '',
        scheduledTime: '',
        calories: 0,
        completedCount: 0,
        totalCount: 0,
        mealStatuses: {},
      );
    }

    final orderedMeals = sortMeals(
      plan.meals,
      date: now,
      reminderSettings: reminderSettings,
      customMealTimes: customMealTimes,
    );

    final completedMeals = findCompletedMeals(orderedMeals, loggedToday);
    final completedCount = completedMeals.length;
    final totalCount = orderedMeals.length;
    final isAllCompleted = completedCount == totalCount && totalCount > 0;

    // Build timeline statuses for each meal
    final mealStatuses = <PlannedMealEntity, MealStatus>{};

    // Find next uncompleted upcoming meal
    PlannedMealEntity? selectedNextMeal;
    bool isNextDay = false;

    if (isAllCompleted) {
      // All meals are completed today -> preview tomorrow's first meal
      final tomorrowMeals = nextDayPlan != null && nextDayPlan.meals.isNotEmpty
          ? sortMeals(
              nextDayPlan.meals,
              date: now.add(const Duration(days: 1)),
              reminderSettings: reminderSettings,
              customMealTimes: customMealTimes,
            )
          : orderedMeals;
      selectedNextMeal = tomorrowMeals.firstOrNull;
      isNextDay = true;

      for (final m in orderedMeals) {
        mealStatuses[m] = MealStatus.completed;
      }
    } else {
      // Find the first meal that is NOT completed and scheduled in the future or current
      // A meal whose scheduled time has passed and was not logged is missed.
      for (final m in orderedMeals) {
        if (completedMeals.contains(m)) {
          mealStatuses[m] = MealStatus.completed;
          continue;
        }

        final timeStr = getScheduledTimeForSlot(
          mealType: m.mealType,
          reminderSettings: reminderSettings,
          customMealTimes: customMealTimes,
        );
        final scheduledDt = parseTimeToDateTime(now, timeStr);

        // If meal is scheduled in future (or current window)
        if (now.isBefore(scheduledDt) || now.isAtSameMomentAs(scheduledDt)) {
          if (selectedNextMeal == null) {
            selectedNextMeal = m;
            mealStatuses[m] = MealStatus.current;
          } else {
            mealStatuses[m] = MealStatus.upcoming;
          }
        } else {
          // Time has passed and meal was not logged -> missed
          mealStatuses[m] = MealStatus.missed;
        }
      }

      // If all uncompleted meals have already passed (e.g. late night after dinner)
      if (selectedNextMeal == null) {
        final tomorrowMeals = nextDayPlan != null && nextDayPlan.meals.isNotEmpty
            ? sortMeals(
                nextDayPlan.meals,
                date: now.add(const Duration(days: 1)),
                reminderSettings: reminderSettings,
                customMealTimes: customMealTimes,
              )
            : orderedMeals;
        selectedNextMeal = tomorrowMeals.firstOrNull;
        isNextDay = true;
      }
    }

    final mealSlot = selectedNextMeal?.mealType ?? '';
    final rawTime = selectedNextMeal != null
        ? getScheduledTimeForSlot(
            mealType: selectedNextMeal.mealType,
            reminderSettings: reminderSettings,
            customMealTimes: customMealTimes,
          )
        : '';
    final formattedTime = formatTimeOfDay(rawTime);
    final displaySlot = mealSlot.isNotEmpty ? 'NEXT: ${mealSlot.toUpperCase()}' : '';
    final calories = selectedNextMeal?.totalCalories ?? 0.0;

    return NextMealSelection(
      meal: selectedNextMeal,
      mealSlot: mealSlot,
      displaySlot: displaySlot,
      scheduledTime: formattedTime,
      calories: calories,
      isNextDay: isNextDay,
      isAllCompleted: isAllCompleted,
      completedCount: completedCount,
      totalCount: totalCount,
      mealStatuses: mealStatuses,
    );
  }
}
