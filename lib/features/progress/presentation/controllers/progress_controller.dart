import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/progress_remote_datasource.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/weight_record_entity.dart';
import '../../domain/repositories/i_progress_repository.dart';


class ProgressState {
  final int selectedRange;
  final bool isSavingWeight;
  final String? saveError;
  final bool saveSuccess;

  const ProgressState({
    this.selectedRange = 7,
    this.isSavingWeight = false,
    this.saveError,
    this.saveSuccess = false,
  });

  ProgressState copyWith({
    int? selectedRange,
    bool? isSavingWeight,
    String? saveError,
    bool? saveSuccess,
  }) {
    return ProgressState(
      selectedRange: selectedRange ?? this.selectedRange,
      isSavingWeight: isSavingWeight ?? this.isSavingWeight,
      saveError: saveError,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

class ProgressController extends StateNotifier<ProgressState> {
  final IProgressRepository _repository;

  ProgressController(this._repository) : super(const ProgressState());

  void setRange(int range) {
    state = state.copyWith(selectedRange: range);
  }

  Future<bool> logWeight(String uid, double weight) async {
    state = state.copyWith(isSavingWeight: true, saveError: null, saveSuccess: false);
    try {
      await _repository.addWeight(uid, weight, DateTime.now());
      state = state.copyWith(isSavingWeight: false, saveSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSavingWeight: false, saveError: e.toString());
      return false;
    }
  }
}

final progressRemoteDataSourceProvider = Provider<IProgressRemoteDataSource>((ref) {
  return ProgressRemoteDataSourceImpl();
});

final progressRepositoryProvider = Provider<IProgressRepository>((ref) {
  final dataSource = ref.watch(progressRemoteDataSourceProvider);
  return ProgressRepositoryImpl(dataSource);
});

final progressControllerProvider =
    StateNotifierProvider<ProgressController, ProgressState>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  return ProgressController(repository);
});

final weightHistoryStreamProvider = StreamProvider<List<WeightRecordEntity>>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(const []);
  }
  final repository = ref.watch(progressRepositoryProvider);
  return repository.streamWeightHistory(authUser.uid);
});
