import '../entities/health_insight_entity.dart';
import '../entities/daily_focus_entity.dart';

abstract class IInsightsRepository {
  Future<List<HealthInsightEntity>> getInsights({
    required String uid,
    required DateTime today,
  });

  Future<DailyFocusEntity> getDailyFocus({
    required String uid,
    required DateTime today,
  });
}
