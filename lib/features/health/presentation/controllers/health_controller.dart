import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/health_record_entity.dart';
import '../providers/health_providers.dart';

class HealthController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  HealthController(this._ref) : super(const AsyncValue.data(null));

  Future<void> _updateRecord(HealthRecordEntity updated) async {
    final uid = _ref.read(authStateStreamProvider).value?.uid;
    if (uid == null) return;

    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(healthRepositoryProvider);
      await repository.saveRecord(uid, updated);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  HealthRecordEntity _getOrCreateTodayRecord() {
    final todayStr = DateTime.now().toString().split(' ').first;
    final existing = _ref.read(todayHealthRecordProvider);
    return existing ?? HealthRecordEntity.empty(todayStr);
  }

  Future<void> incrementWater(double ml) async {
    final current = _getOrCreateTodayRecord();
    final updated = current.copyWith(
      waterIntakeMl: current.waterIntakeMl + ml,
      updatedAt: DateTime.now(),
    );
    await _updateRecord(updated);
  }

  Future<void> setWaterTarget(double targetMl) async {
    final current = _getOrCreateTodayRecord();
    final updated = current.copyWith(
      waterTargetMl: targetMl,
      updatedAt: DateTime.now(),
    );
    await _updateRecord(updated);
  }

  Future<void> addExercise(ExerciseEntity exercise) async {
    final current = _getOrCreateTodayRecord();
    final updatedList = List<ExerciseEntity>.from(current.exercises)..add(exercise);
    final updated = current.copyWith(
      exercises: updatedList,
      updatedAt: DateTime.now(),
    );
    await _updateRecord(updated);
  }

  Future<void> toggleHabit(String habitName, bool completed) async {
    final current = _getOrCreateTodayRecord();
    final updatedHabits = Map<String, bool>.from(current.habits)..[habitName] = completed;
    final updated = current.copyWith(
      habits: updatedHabits,
      updatedAt: DateTime.now(),
    );
    await _updateRecord(updated);
  }
}

final healthControllerProvider = StateNotifierProvider<HealthController, AsyncValue<void>>((ref) {
  return HealthController(ref);
});
