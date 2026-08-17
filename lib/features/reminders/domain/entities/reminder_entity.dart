enum ReminderType {
  hydration,
  breakfast,
  lunch,
  dinner,
  snack,
  exercise,
  habit,
  weight,
  nutritionLogging,
  weeklyReview,
  aiCoaching,
  custom,
}

enum ReminderPriority {
  low,
  medium,
  high,
  critical,
}

class ReminderEntity {
  final String id;
  final String title;
  final String description;
  final ReminderType type;
  final String scheduledTime; // "HH:mm"
  final bool enabled;
  final bool completed;
  final String repeatPattern; // "daily" | "weekly"
  final ReminderPriority priority;
  final String actionRoute;

  const ReminderEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.scheduledTime,
    this.enabled = true,
    this.completed = false,
    this.repeatPattern = 'daily',
    this.priority = ReminderPriority.medium,
    required this.actionRoute,
  });

  ReminderEntity copyWith({
    String? id,
    String? title,
    String? description,
    ReminderType? type,
    String? scheduledTime,
    bool? enabled,
    bool? completed,
    String? repeatPattern,
    ReminderPriority? priority,
    String? actionRoute,
  }) {
    return ReminderEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      enabled: enabled ?? this.enabled,
      completed: completed ?? this.completed,
      repeatPattern: repeatPattern ?? this.repeatPattern,
      priority: priority ?? this.priority,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }
}
