import '../entities/health_analytics_entity.dart';

abstract class IAnalyticsRepository {
  Future<HealthAnalyticsEntity> getAnalytics({
    required String uid,
    required String range,
    required DateTime today,
  });
}
