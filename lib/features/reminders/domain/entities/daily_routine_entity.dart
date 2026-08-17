import 'reminder_entity.dart';

class DailyRoutineEntity {
  final String date; // yyyy-MM-dd
  final List<ReminderEntity> routineItems;
  final List<ReminderEntity> completedItems;
  final List<ReminderEntity> pendingItems;
  final double completionPercentage;
  final ReminderEntity? nextReminder;
  final int totalReminders;
  final int completedReminders;

  const DailyRoutineEntity({
    required this.date,
    required this.routineItems,
    required this.completedItems,
    required this.pendingItems,
    required this.completionPercentage,
    this.nextReminder,
    required this.totalReminders,
    required this.completedReminders,
  });

  DailyRoutineEntity copyWith({
    String? date,
    List<ReminderEntity>? routineItems,
    List<ReminderEntity>? completedItems,
    List<ReminderEntity>? pendingItems,
    double? completionPercentage,
    ReminderEntity? nextReminder,
    int? totalReminders,
    int? completedReminders,
  }) {
    return DailyRoutineEntity(
      date: date ?? this.date,
      routineItems: routineItems ?? this.routineItems,
      completedItems: completedItems ?? this.completedItems,
      pendingItems: pendingItems ?? this.pendingItems,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      nextReminder: nextReminder ?? this.nextReminder,
      totalReminders: totalReminders ?? this.totalReminders,
      completedReminders: completedReminders ?? this.completedReminders,
    );
  }
}
