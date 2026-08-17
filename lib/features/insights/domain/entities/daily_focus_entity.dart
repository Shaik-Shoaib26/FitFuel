import 'health_insight_entity.dart';
import 'action_recommendation_entity.dart';

class DailyFocusEntity {
  final String title;
  final String description;
  final InsightCategory category;
  final InsightPriority priority;
  final List<ActionRecommendationEntity> recommendedActions;

  const DailyFocusEntity({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.recommendedActions,
  });

  DailyFocusEntity copyWith({
    String? title,
    String? description,
    InsightCategory? category,
    InsightPriority? priority,
    List<ActionRecommendationEntity>? recommendedActions,
  }) {
    return DailyFocusEntity(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      recommendedActions: recommendedActions ?? this.recommendedActions,
    );
  }
}
