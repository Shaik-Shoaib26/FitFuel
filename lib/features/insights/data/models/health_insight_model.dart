import '../../domain/entities/health_insight_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthInsightModel extends HealthInsightEntity {
  const HealthInsightModel({
    required super.id,
    required super.category,
    required super.title,
    required super.description,
    required super.priority,
    super.metricValue,
    super.targetValue,
    super.unit,
    required super.recommendation,
    required super.actionType,
    required super.createdAt,
  });

  factory HealthInsightModel.fromEntity(HealthInsightEntity entity) {
    return HealthInsightModel(
      id: entity.id,
      category: entity.category,
      title: entity.title,
      description: entity.description,
      priority: entity.priority,
      metricValue: entity.metricValue,
      targetValue: entity.targetValue,
      unit: entity.unit,
      recommendation: entity.recommendation,
      actionType: entity.actionType,
      createdAt: entity.createdAt,
    );
  }

  factory HealthInsightModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthInsightModel(
      id: doc.id,
      category: InsightCategory.values.firstWhere(
        (e) => e.toString().split('.').last == data['category'],
        orElse: () => InsightCategory.nutrition,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      priority: InsightPriority.values.firstWhere(
        (e) => e.toString().split('.').last == data['priority'],
        orElse: () => InsightPriority.low,
      ),
      metricValue: (data['metricValue'] as num?)?.toDouble(),
      targetValue: (data['targetValue'] as num?)?.toDouble(),
      unit: data['unit'],
      recommendation: data['recommendation'] ?? '',
      actionType: InsightActionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['actionType'],
        orElse: () => InsightActionType.none,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category.toString().split('.').last,
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'metricValue': metricValue,
      'targetValue': targetValue,
      'unit': unit,
      'recommendation': recommendation,
      'actionType': actionType.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
