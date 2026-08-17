import '../entities/reminder_entity.dart';

abstract class INotificationService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> scheduleReminder(ReminderEntity reminder);
  Future<void> cancelReminder(String id);
  Future<void> cancelAllReminders();
  Future<void> showImmediateNotification(String title, String body);
}
