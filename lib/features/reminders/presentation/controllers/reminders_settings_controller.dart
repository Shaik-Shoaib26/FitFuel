import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reminder_settings_entity.dart';
import '../../domain/repositories/i_reminders_repository.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class RemindersSettingsController extends StateNotifier<AsyncValue<void>> {
  final IRemindersRepository _repository;
  final Ref _ref;

  RemindersSettingsController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> updateSettings(ReminderSettingsEntity settings) async {
    final uid = _ref.read(authStateStreamProvider).value?.uid;
    if (uid == null) return;

    state = const AsyncValue.loading();
    try {
      await _repository.saveSettings(uid, settings);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
