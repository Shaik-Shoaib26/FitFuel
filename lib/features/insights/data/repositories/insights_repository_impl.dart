import '../../domain/repositories/i_insights_repository.dart';
import '../../domain/entities/health_insight_entity.dart';
import '../../domain/entities/daily_focus_entity.dart';
import '../../domain/utils/insight_engine.dart';
import '../datasources/insights_remote_datasource.dart';

class InsightsRepositoryImpl implements IInsightsRepository {
  final IInsightsRemoteDataSource _remoteDataSource;

  InsightsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<HealthInsightEntity>> getInsights({
    required String uid,
    required DateTime today,
  }) async {
    final nutritionRecords = await _remoteDataSource.getNutritionRecords(uid);
    final healthRecords = await _remoteDataSource.getHealthRecords(uid);
    final weightHistory = await _remoteDataSource.getWeightHistory(uid);
    final profile = await _remoteDataSource.getUserProfile(uid);
    final goals = await _remoteDataSource.getNutritionGoals(uid);
    final groceryLists = await _remoteDataSource.getGroceryLists(uid);
    final pantryItems = await _remoteDataSource.getPantryItems(uid);

    return InsightEngine.generateInsights(
      today: today,
      profile: profile?.toEntity(),
      goals: goals?.toEntity(),
      nutritionHistory: nutritionRecords.map((m) => m.toEntity()).toList(),
      healthHistory: healthRecords.map((m) => m.toEntity()).toList(),
      weightHistory: weightHistory.map((m) => m.toEntity()).toList(),
      groceryLists: groceryLists.map((m) => m.toEntity()).toList(),
      pantryItems: pantryItems.map((m) => m.toEntity()).toList(),
    );
  }

  @override
  Future<DailyFocusEntity> getDailyFocus({
    required String uid,
    required DateTime today,
  }) async {
    final insights = await getInsights(uid: uid, today: today);
    return InsightEngine.selectDailyFocus(insights);
  }
}
