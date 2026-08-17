import '../entities/reminder_entity.dart';

class ReminderPriorityEngine {
  static ReminderPriority getPriority(ReminderType type, {bool isCriticalHydration = false}) {
    switch (type) {
      case ReminderType.hydration:
        return isCriticalHydration ? ReminderPriority.critical : ReminderPriority.medium;
      case ReminderType.breakfast:
      case ReminderType.lunch:
      case ReminderType.dinner:
      case ReminderType.snack:
      case ReminderType.nutritionLogging:
        return ReminderPriority.high;
      case ReminderType.exercise:
      case ReminderType.habit:
        return ReminderPriority.medium;
      case ReminderType.weight:
      case ReminderType.weeklyReview:
      case ReminderType.aiCoaching:
      case ReminderType.custom:
        return ReminderPriority.low;
    }
  }

  static String generateCombinedReminder({
    required double remainingWaterMl,
    required bool hasPendingMeal,
    required String? pendingMealName,
    required int pendingHabitsCount,
    required bool exercisePending,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Your FitFuel check-in 💚');
    if (remainingWaterMl > 0) {
      buffer.writeln('• ${remainingWaterMl.toStringAsFixed(0)} ml water remaining');
    }
    if (hasPendingMeal && pendingMealName != null) {
      buffer.writeln('• $pendingMealName hasn\'t been logged');
    }
    if (exercisePending) {
      buffer.writeln('• Exercise hasn\'t been completed');
    }
    if (pendingHabitsCount > 0) {
      buffer.writeln('• $pendingHabitsCount habit${pendingHabitsCount > 1 ? 's' : ''} remaining');
    }
    return buffer.toString().trim();
  }
}
