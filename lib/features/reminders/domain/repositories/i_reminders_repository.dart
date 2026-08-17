import '../entities/reminder_settings_entity.dart';

abstract class IRemindersRepository {
  Future<ReminderSettingsEntity?> getSettings(String uid);
  Future<void> saveSettings(String uid, ReminderSettingsEntity settings);
  Stream<ReminderSettingsEntity?> streamSettings(String uid);
}
