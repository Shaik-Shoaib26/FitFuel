import 'analytics_data_point_entity.dart';
import 'analytics_summary_entity.dart';

class HealthAnalyticsEntity {
  final String range;
  final List<AnalyticsDataPointEntity> dataPoints;
  final AnalyticsSummaryEntity summary;
  final AnalyticsSummaryEntity? previousSummary;

  const HealthAnalyticsEntity({
    required this.range,
    required this.dataPoints,
    required this.summary,
    this.previousSummary,
  });
}
