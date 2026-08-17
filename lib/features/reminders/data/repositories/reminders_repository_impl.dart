import '../../domain/entities/reminder_settings_entity.dart';
import '../../domain/repositories/i_reminders_repository.dart';
import '../datasources/reminders_remote_datasource.dart';
import '../models/reminder_settings_model.dart';

class RemindersRepositoryImpl implements IRemindersRepository {
  final IRemindersRemoteDataSource _remoteDataSource;

  RemindersRepositoryImpl(this._remoteDataSource);

  @override
  Future<ReminderSettingsEntity?> getSettings(String uid) async {
    return await _remoteDataSource.getSettings(uid);
  }

  @override
  Future<void> saveSettings(String uid, ReminderSettingsEntity settings) async {
    final model = ReminderSettingsModel.fromEntity(settings);
    await _remoteDataSource.saveSettings(uid, model);
  }

  @override
  Stream<ReminderSettingsEntity?> streamSettings(String uid) {
    return _remoteDataSource.streamSettings(uid);
  }
}
