import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/health_record_entity.dart';
import '../../domain/repositories/i_health_repository.dart';
import '../datasources/health_remote_datasource.dart';
import '../models/health_record_model.dart';

class HealthRepositoryImpl implements IHealthRepository {
  final IHealthRemoteDataSource _remoteDataSource;

  HealthRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> saveRecord(String uid, HealthRecordEntity record) async {
    try {
      final model = HealthRecordModel.fromEntity(record);
      await _remoteDataSource.saveRecord(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<HealthRecordEntity?> getRecord(String uid, String date) async {
    try {
      final model = await _remoteDataSource.getRecord(uid, date);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<HealthRecordEntity?> streamRecord(String uid, String date) {
    return _remoteDataSource
        .streamRecord(uid, date)
        .map((model) => model?.toEntity());
  }

  @override
  Stream<List<HealthRecordEntity>> streamAllRecords(String uid) {
    return _remoteDataSource
        .streamAllRecords(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
