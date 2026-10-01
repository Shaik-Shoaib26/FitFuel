import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/weight_record_entity.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../datasources/progress_remote_datasource.dart';
import '../models/weight_record_model.dart';
import '../../../../core/utils/id_utils.dart';

class ProgressRepositoryImpl implements IProgressRepository {
  final IProgressRemoteDataSource _remoteDataSource;

  ProgressRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> addWeight(String uid, double weight, DateTime recordedAt) async {
    try {
      final recordId = IdUtils.generateId();
      final model = WeightRecordModel(id: recordId, weight: weight, recordedAt: recordedAt);
      await _remoteDataSource.addWeight(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<WeightRecordEntity>> getWeightHistory(String uid) async {
    try {
      final models = await _remoteDataSource.getWeightHistory(uid);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<WeightRecordEntity>> streamWeightHistory(String uid) {
    return _remoteDataSource
        .streamWeightHistory(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
