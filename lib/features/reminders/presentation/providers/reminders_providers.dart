import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/reminders_remote_datasource.dart';
import '../../data/repositories/reminders_repository_impl.dart';
import '../../data/repositories/notification_service_impl.dart';
import '../../domain/entities/reminder_settings_entity.dart';
import '../../domain/entities/daily_routine_entity.dart';
import '../../domain/repositories/i_reminders_repository.dart';
import '../../domain/services/i_notification_service.dart';
import '../../domain/utils/daily_routine_calculator.dart';
import '../controllers/reminders_settings_controller.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';

final notificationServiceProvider = Provider<INotificationService>((ref) {
  final service = NotificationServiceImpl();
  service.initialize();
  return service;
});

final remindersRemoteDataSourceProvider = Provider<IRemindersRemoteDataSource>((ref) {
  return RemindersRemoteDataSourceImpl();
});

final remindersRepositoryProvider = Provider<IRemindersRepository>((ref) {
  final dataSource = ref.watch(remindersRemoteDataSourceProvider);
  return RemindersRepositoryImpl(dataSource);
});

final remindersSettingsStreamProvider = StreamProvider<ReminderSettingsEntity?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(remindersRepositoryProvider);
  return repository.streamSettings(authUser.uid);
});

final remindersSettingsControllerProvider =
    StateNotifierProvider<RemindersSettingsController, AsyncValue<void>>((ref) {
  final repository = ref.watch(remindersRepositoryProvider);
  return RemindersSettingsController(repository, ref);
});

final dailyRoutineProvider = Provider<DailyRoutineEntity>((ref) {
  final settingsAsync = ref.watch(remindersSettingsStreamProvider);
  final todayHealth = ref.watch(todayHealthRecordProvider);
  final nutritionRecords =
      ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
  final weightHistory =
      ref.watch(weightHistoryStreamProvider).valueOrNull ?? const [];
  final healthHistory =
      ref.watch(healthStreamProvider).valueOrNull ?? const [];
  final profile = ref.watch(currentProfileStreamProvider).valueOrNull;
  final mealPlan = ref.watch(mealPlannerControllerProvider).valueOrNull;
  final groceryList = ref.watch(currentGroceryListProvider).valueOrNull;
  final groceryPreferences =
      ref.watch(groceryPreferencesProvider).valueOrNull;

  final todayStr = DateTime.now().toString().split(' ').first;
  final todayNutrition = nutritionRecords
      .where((r) => r.consumedAt.toString().split(' ').first == todayStr)
      .toList();
  final settings = settingsAsync.valueOrNull ?? const ReminderSettingsEntity();

  return DailyRoutineCalculator.calculateRoutine(
    date: todayStr,
    settings: settings,
    todayHealth: todayHealth,
    todayNutrition: todayNutrition,
    weightHistory: weightHistory,
    nutritionHistory: nutritionRecords,
    healthHistory: healthHistory,
    activityLevel: profile?.activityLevel,
    todayMealPlan: mealPlan,
    todayGroceryList: groceryList,
    groceryPreferences: groceryPreferences,
  );
});
