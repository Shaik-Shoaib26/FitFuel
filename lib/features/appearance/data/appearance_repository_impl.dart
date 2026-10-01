import '../../../core/storage/shared_prefs_service.dart';
import '../domain/appearance_repository.dart';

/// Device preference; contains no account or health data.
class AppearanceRepositoryImpl implements AppearanceRepository {
  final Future<SharedPrefsService> Function() openStorage;
  static const storageKey = 'fitfuel.appearance';

  AppearanceRepositoryImpl({this.openStorage = SharedPrefsService.init});

  @override
  Future<AppearanceMode> load() async {
    final value = (await openStorage()).getString(storageKey);
    return AppearanceMode.values
            .where((mode) => mode.name == value)
            .firstOrNull ??
        AppearanceMode.light;
  }

  @override
  Future<void> save(AppearanceMode mode) async {
    if (!await (await openStorage()).setString(storageKey, mode.name)) {
      throw StateError('Could not save appearance');
    }
  }
}
