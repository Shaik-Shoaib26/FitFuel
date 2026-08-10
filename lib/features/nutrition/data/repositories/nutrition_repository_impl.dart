import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/repositories/i_nutrition_repository.dart';
import '../datasources/nutrition_remote_datasource.dart';
import '../models/nutrition_record_model.dart';

class NutritionRepositoryImpl implements INutritionRepository {
  final INutritionRemoteDataSource _remoteDataSource;

  NutritionRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> addRecord(String uid, NutritionRecordEntity record) async {
    try {
      final model = NutritionRecordModel.fromEntity(record);
      await _remoteDataSource.addRecord(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<NutritionRecordEntity>> getRecords(String uid) async {
    try {
      final models = await _remoteDataSource.getRecords(uid);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<NutritionRecordEntity>> streamRecords(String uid) {
    return _remoteDataSource
        .streamRecords(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<void> updateRecord(String uid, NutritionRecordEntity record) async {
    try {
      final model = NutritionRecordModel.fromEntity(record);
      await _remoteDataSource.updateRecord(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {
    try {
      await _remoteDataSource.deleteRecord(uid, recordId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
