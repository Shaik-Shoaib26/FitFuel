enum InsightCategory {
  nutrition,
  hydration,
  exercise,
  habits,
  wellness,
  weight,
  progress,
  positive
}

enum InsightPriority {
  critical,
  high,
  medium,
  low,
  positive
}

enum InsightActionType {
  logWater,
  viewMealPlan,
  findProteinFoods,
  openGrocery,
  viewProgress,
  openWeeklyReport,
  openDailyRoutine,
  openAnalytics,
  none
}

class HealthInsightEntity {
  final String id;
  final InsightCategory category;
  final String title;
  final String description;
  final InsightPriority priority;
  final double? metricValue;
  final double? targetValue;
  final String? unit;
  final String recommendation;
  final InsightActionType actionType;
  final DateTime createdAt;

  const HealthInsightEntity({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
    this.metricValue,
    this.targetValue,
    this.unit,
    required this.recommendation,
    required this.actionType,
    required this.createdAt,
  });

  HealthInsightEntity copyWith({
    String? id,
    InsightCategory? category,
    String? title,
    String? description,
    InsightPriority? priority,
    double? metricValue,
    double? targetValue,
    String? unit,
    String? recommendation,
    InsightActionType? actionType,
    DateTime? createdAt,
  }) {
    return HealthInsightEntity(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      metricValue: metricValue ?? this.metricValue,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      recommendation: recommendation ?? this.recommendation,
      actionType: actionType ?? this.actionType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
