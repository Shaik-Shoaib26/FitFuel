import '../../domain/entities/health_analytics_entity.dart';
import '../../domain/repositories/i_analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';
import '../../domain/utils/health_analytics_calculator.dart';

class AnalyticsRepositoryImpl implements IAnalyticsRepository {
  final IAnalyticsRemoteDataSource _dataSource;

  AnalyticsRepositoryImpl(this._dataSource);

  @override
  Future<HealthAnalyticsEntity> getAnalytics({
    required String uid,
    required String range,
    required DateTime today,
  }) async {
    final nutritionModels = await _dataSource.getNutritionRecords(uid);
    final healthModels = await _dataSource.getHealthRecords(uid);
    final weightModels = await _dataSource.getWeightHistory(uid);
    final profileModel = await _dataSource.getUserProfile(uid);
    final goalsModel = await _dataSource.getNutritionGoals(uid);

    final nutritionEntities = nutritionModels.map((m) => m.toEntity()).toList();
    final healthEntities = healthModels.map((m) => m.toEntity()).toList();
    final weightEntities = weightModels.map((m) => m.toEntity()).toList();
    final profileEntity = profileModel?.toEntity();
    final goalsEntity = goalsModel?.toEntity();

    return HealthAnalyticsCalculator.calculate(
      range: range,
      today: today,
      nutritionRecords: nutritionEntities,
      healthRecords: healthEntities,
      weightHistory: weightEntities,
      profile: profileEntity,
      goals: goalsEntity,
    );
  }
}
