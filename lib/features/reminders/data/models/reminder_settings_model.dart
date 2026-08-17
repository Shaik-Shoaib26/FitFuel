import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/reminder_settings_entity.dart';

class ReminderSettingsModel extends ReminderSettingsEntity {
  const ReminderSettingsModel({
    super.hydrationEnabled,
    super.mealEnabled,
    super.breakfastTime,
    super.lunchTime,
    super.dinnerTime,
    super.snackTime,
    super.exerciseEnabled,
    super.exerciseTime,
    super.habitEnabled,
    super.weightEnabled,
    super.weightDay,
    super.weightTime,
    super.nutritionLoggingEnabled,
    super.weeklyReviewEnabled,
    super.weeklyReviewDay,
    super.weeklyReviewTime,
    super.aiCoachEnabled,
    super.aiCoachTime,
  });

  factory ReminderSettingsModel.fromEntity(ReminderSettingsEntity entity) {
    return ReminderSettingsModel(
      hydrationEnabled: entity.hydrationEnabled,
      mealEnabled: entity.mealEnabled,
      breakfastTime: entity.breakfastTime,
      lunchTime: entity.lunchTime,
      dinnerTime: entity.dinnerTime,
      snackTime: entity.snackTime,
      exerciseEnabled: entity.exerciseEnabled,
      exerciseTime: entity.exerciseTime,
      habitEnabled: entity.habitEnabled,
      weightEnabled: entity.weightEnabled,
      weightDay: entity.weightDay,
      weightTime: entity.weightTime,
      nutritionLoggingEnabled: entity.nutritionLoggingEnabled,
      weeklyReviewEnabled: entity.weeklyReviewEnabled,
      weeklyReviewDay: entity.weeklyReviewDay,
      weeklyReviewTime: entity.weeklyReviewTime,
      aiCoachEnabled: entity.aiCoachEnabled,
      aiCoachTime: entity.aiCoachTime,
    );
  }

  factory ReminderSettingsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReminderSettingsModel(
      hydrationEnabled: data['hydrationEnabled'] ?? true,
      mealEnabled: data['mealEnabled'] ?? true,
      breakfastTime: data['breakfastTime'] ?? '08:00',
      lunchTime: data['lunchTime'] ?? '13:00',
      dinnerTime: data['dinnerTime'] ?? '20:00',
      snackTime: data['snackTime'] ?? '16:00',
      exerciseEnabled: data['exerciseEnabled'] ?? true,
      exerciseTime: data['exerciseTime'] ?? '18:00',
      habitEnabled: data['habitEnabled'] ?? true,
      weightEnabled: data['weightEnabled'] ?? true,
      weightDay: data['weightDay'] ?? 'Sunday',
      weightTime: data['weightTime'] ?? '07:30',
      nutritionLoggingEnabled: data['nutritionLoggingEnabled'] ?? true,
      weeklyReviewEnabled: data['weeklyReviewEnabled'] ?? true,
      weeklyReviewDay: data['weeklyReviewDay'] ?? 'Sunday',
      weeklyReviewTime: data['weeklyReviewTime'] ?? '19:00',
      aiCoachEnabled: data['aiCoachEnabled'] ?? true,
      aiCoachTime: data['aiCoachTime'] ?? '21:00',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hydrationEnabled': hydrationEnabled,
      'mealEnabled': mealEnabled,
      'breakfastTime': breakfastTime,
      'lunchTime': lunchTime,
      'dinnerTime': dinnerTime,
      'snackTime': snackTime,
      'exerciseEnabled': exerciseEnabled,
      'exerciseTime': exerciseTime,
      'habitEnabled': habitEnabled,
      'weightEnabled': weightEnabled,
      'weightDay': weightDay,
      'weightTime': weightTime,
      'nutritionLoggingEnabled': nutritionLoggingEnabled,
      'weeklyReviewEnabled': weeklyReviewEnabled,
      'weeklyReviewDay': weeklyReviewDay,
      'weeklyReviewTime': weeklyReviewTime,
      'aiCoachEnabled': aiCoachEnabled,
      'aiCoachTime': aiCoachTime,
    };
  }
}
