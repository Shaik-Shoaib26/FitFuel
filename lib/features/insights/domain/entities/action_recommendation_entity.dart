import 'health_insight_entity.dart';

class ActionRecommendationEntity {
  final String id;
  final String title;
  final String description;
  final InsightActionType actionType;
  final String route;
  final InsightPriority priority;
  final bool isCompleted;

  const ActionRecommendationEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.actionType,
    required this.route,
    required this.priority,
    this.isCompleted = false,
  });

  ActionRecommendationEntity copyWith({
    String? id,
    String? title,
    String? description,
    InsightActionType? actionType,
    String? route,
    InsightPriority? priority,
    bool? isCompleted,
  }) {
    return ActionRecommendationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      actionType: actionType ?? this.actionType,
      route: route ?? this.route,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
