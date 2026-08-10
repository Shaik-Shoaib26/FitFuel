import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/repositories/i_nutrition_repository.dart';
import '../providers/nutrition_providers.dart';

abstract class NutritionState {
  const NutritionState();
}

class NutritionInitialState extends NutritionState {
  const NutritionInitialState();
}

class NutritionLoadingState extends NutritionState {
  const NutritionLoadingState();
}

class NutritionSuccessState extends NutritionState {
  final String? successMessage;
  const NutritionSuccessState({this.successMessage});
}

class NutritionErrorState extends NutritionState {
  final String message;
  const NutritionErrorState(this.message);
}

class NutritionController extends StateNotifier<NutritionState> {
  final INutritionRepository _repository;

  NutritionController(this._repository) : super(const NutritionInitialState());

  Future<bool> addRecord(String uid, NutritionRecordEntity record) async {
    state = const NutritionLoadingState();
    try {
      LoggerService.info('NutritionController: Adding record for UID: $uid');
      await _repository.addRecord(uid, record);
      state = const NutritionSuccessState(successMessage: 'Nutrition record added successfully.');
      return true;
    } on Failure catch (e) {
      LoggerService.error('NutritionController error adding record: ${e.message}');
      state = NutritionErrorState(e.message);
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('NutritionController unexpected error adding record', e, stackTrace);
      state = const NutritionErrorState('Unexpected error occurred while adding record.');
      return false;
    }
  }

  Future<bool> updateRecord(String uid, NutritionRecordEntity record) async {
    state = const NutritionLoadingState();
    try {
      LoggerService.info('NutritionController: Updating record ${record.id} for UID: $uid');
      await _repository.updateRecord(uid, record);
      state = const NutritionSuccessState(successMessage: 'Nutrition record updated successfully.');
      return true;
    } on Failure catch (e) {
      LoggerService.error('NutritionController error updating record: ${e.message}');
      state = NutritionErrorState(e.message);
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('NutritionController unexpected error updating record', e, stackTrace);
      state = const NutritionErrorState('Unexpected error occurred while updating record.');
      return false;
    }
  }

  Future<bool> deleteRecord(String uid, String recordId) async {
    state = const NutritionLoadingState();
    try {
      LoggerService.info('NutritionController: Deleting record $recordId for UID: $uid');
      await _repository.deleteRecord(uid, recordId);
      state = const NutritionSuccessState(successMessage: 'Nutrition record deleted successfully.');
      return true;
    } on Failure catch (e) {
      LoggerService.error('NutritionController error deleting record: ${e.message}');
      state = NutritionErrorState(e.message);
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('NutritionController unexpected error deleting record', e, stackTrace);
      state = const NutritionErrorState('Unexpected error occurred while deleting record.');
      return false;
    }
  }

  void resetState() {
    state = const NutritionInitialState();
  }
}

final nutritionControllerProvider =
    StateNotifierProvider<NutritionController, NutritionState>((ref) {
  final repository = ref.watch(nutritionRepositoryProvider);
  return NutritionController(repository);
});
