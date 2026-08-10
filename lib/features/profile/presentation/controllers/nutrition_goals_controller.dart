import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../providers/profile_providers.dart';

abstract class NutritionGoalsState {
  const NutritionGoalsState();
}

class NutritionGoalsInitialState extends NutritionGoalsState {
  const NutritionGoalsInitialState();
}

class NutritionGoalsLoadingState extends NutritionGoalsState {
  const NutritionGoalsLoadingState();
}

class NutritionGoalsSuccessState extends NutritionGoalsState {
  final String message;
  const NutritionGoalsSuccessState(this.message);
}

class NutritionGoalsErrorState extends NutritionGoalsState {
  final String message;
  const NutritionGoalsErrorState(this.message);
}

class NutritionGoalsController extends StateNotifier<NutritionGoalsState> {
  final IProfileRepository _repository;

  NutritionGoalsController(this._repository) : super(const NutritionGoalsInitialState());

  Future<bool> saveGoals(String uid, NutritionGoalsEntity goals) async {
    state = const NutritionGoalsLoadingState();
    try {
      LoggerService.info('NutritionGoalsController: Saving goals for UID: $uid');
      await _repository.saveGoals(uid, goals);
      state = const NutritionGoalsSuccessState('Nutrition goals saved successfully.');
      return true;
    } on Failure catch (e) {
      LoggerService.error('NutritionGoalsController error saving goals: ${e.message}');
      state = NutritionGoalsErrorState(e.message);
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('NutritionGoalsController unexpected error saving goals', e, stackTrace);
      state = const NutritionGoalsErrorState('Unexpected error occurred while saving goals.');
      return false;
    }
  }

  void resetState() {
    state = const NutritionGoalsInitialState();
  }
}

final nutritionGoalsControllerProvider =
    StateNotifierProvider<NutritionGoalsController, NutritionGoalsState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return NutritionGoalsController(repository);
});
