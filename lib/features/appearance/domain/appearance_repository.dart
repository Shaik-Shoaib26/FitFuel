enum AppearanceMode { system, light, dark }

abstract class AppearanceRepository {
  Future<AppearanceMode> load();
  Future<void> save(AppearanceMode mode);
}
