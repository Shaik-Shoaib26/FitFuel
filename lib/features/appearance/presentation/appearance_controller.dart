import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appearance_repository_impl.dart';
import '../domain/appearance_repository.dart';

final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => AppearanceRepositoryImpl(),
);

final appearanceControllerProvider =
    AsyncNotifierProvider<AppearanceController, AppearanceMode>(
        AppearanceController.new);

class AppearanceController extends AsyncNotifier<AppearanceMode> {
  bool _saving = false;

  @override
  Future<AppearanceMode> build() =>
      ref.watch(appearanceRepositoryProvider).load();

  Future<bool> setMode(AppearanceMode mode) async {
    if (_saving || state.isLoading) return false;
    _saving = true;
    final previous = state;
    state = const AsyncLoading<AppearanceMode>().copyWithPrevious(previous);
    try {
      await ref.read(appearanceRepositoryProvider).save(mode);
      state = AsyncData(mode);
      return true;
    } catch (_) {
      state = previous;
      return false;
    } finally {
      _saving = false;
    }
  }
}
