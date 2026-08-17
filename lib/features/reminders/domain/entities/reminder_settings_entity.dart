class ReminderSettingsEntity {
  final bool hydrationEnabled;
  final bool mealEnabled;
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;
  final String snackTime;
  final bool exerciseEnabled;
  final String exerciseTime;
  final bool habitEnabled;
  final bool weightEnabled;
  final String weightDay; // "Sunday", "Monday", etc.
  final String weightTime;
  final bool nutritionLoggingEnabled;
  final bool weeklyReviewEnabled;
  final String weeklyReviewDay; // "Sunday", etc.
  final String weeklyReviewTime;
  final bool aiCoachEnabled;
  final String aiCoachTime;

  const ReminderSettingsEntity({
    this.hydrationEnabled = true,
    this.mealEnabled = true,
    this.breakfastTime = '08:00',
    this.lunchTime = '13:00',
    this.dinnerTime = '20:00',
    this.snackTime = '16:00',
    this.exerciseEnabled = true,
    this.exerciseTime = '18:00',
    this.habitEnabled = true,
    this.weightEnabled = true,
    this.weightDay = 'Sunday',
    this.weightTime = '07:30',
    this.nutritionLoggingEnabled = true,
    this.weeklyReviewEnabled = true,
    this.weeklyReviewDay = 'Sunday',
    this.weeklyReviewTime = '19:00',
    this.aiCoachEnabled = true,
    this.aiCoachTime = '21:00',
  });

  ReminderSettingsEntity copyWith({
    bool? hydrationEnabled,
    bool? mealEnabled,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
    String? snackTime,
    bool? exerciseEnabled,
    String? exerciseTime,
    bool? habitEnabled,
    bool? weightEnabled,
    String? weightDay,
    String? weightTime,
    bool? nutritionLoggingEnabled,
    bool? weeklyReviewEnabled,
    String? weeklyReviewDay,
    String? weeklyReviewTime,
    bool? aiCoachEnabled,
    String? aiCoachTime,
  }) {
    return ReminderSettingsEntity(
      hydrationEnabled: hydrationEnabled ?? this.hydrationEnabled,
      mealEnabled: mealEnabled ?? this.mealEnabled,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      snackTime: snackTime ?? this.snackTime,
      exerciseEnabled: exerciseEnabled ?? this.exerciseEnabled,
      exerciseTime: exerciseTime ?? this.exerciseTime,
      habitEnabled: habitEnabled ?? this.habitEnabled,
      weightEnabled: weightEnabled ?? this.weightEnabled,
      weightDay: weightDay ?? this.weightDay,
      weightTime: weightTime ?? this.weightTime,
      nutritionLoggingEnabled: nutritionLoggingEnabled ?? this.nutritionLoggingEnabled,
      weeklyReviewEnabled: weeklyReviewEnabled ?? this.weeklyReviewEnabled,
      weeklyReviewDay: weeklyReviewDay ?? this.weeklyReviewDay,
      weeklyReviewTime: weeklyReviewTime ?? this.weeklyReviewTime,
      aiCoachEnabled: aiCoachEnabled ?? this.aiCoachEnabled,
      aiCoachTime: aiCoachTime ?? this.aiCoachTime,
    );
  }
}
