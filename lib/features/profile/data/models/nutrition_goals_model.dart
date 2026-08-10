import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/nutrition_goals_entity.dart';

class NutritionGoalsModel {
  final String userId;
  final int dailyCalorieTarget;
  final double proteinTargetGrams;
  final double carbsTargetGrams;
  final double fatTargetGrams;
  final DateTime updatedAt;

  const NutritionGoalsModel({
    required this.userId,
    required this.dailyCalorieTarget,
    required this.proteinTargetGrams,
    required this.carbsTargetGrams,
    required this.fatTargetGrams,
    required this.updatedAt,
  });

  factory NutritionGoalsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final macroTargets = data['macroTargets'] as Map<String, dynamic>? ?? {};

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return NutritionGoalsModel(
      userId: data['userId'] as String? ?? doc.id,
      dailyCalorieTarget: (data['dailyCalorieTarget'] as num? ?? 2000).toInt(),
      proteinTargetGrams: parseDouble(macroTargets['proteinGrams'] ?? 150.0),
      carbsTargetGrams: parseDouble(macroTargets['carbsGrams'] ?? 200.0),
      fatTargetGrams: parseDouble(macroTargets['fatGrams'] ?? 65.0),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'dailyCalorieTarget': dailyCalorieTarget,
      'macroTargets': {
        'proteinGrams': proteinTargetGrams,
        'carbsGrams': carbsTargetGrams,
        'fatGrams': fatTargetGrams,
      },
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory NutritionGoalsModel.fromEntity(NutritionGoalsEntity entity) {
    return NutritionGoalsModel(
      userId: entity.userId,
      dailyCalorieTarget: entity.dailyCalorieTarget,
      proteinTargetGrams: entity.proteinTargetGrams,
      carbsTargetGrams: entity.carbsTargetGrams,
      fatTargetGrams: entity.fatTargetGrams,
      updatedAt: entity.updatedAt,
    );
  }

  NutritionGoalsEntity toEntity() {
    return NutritionGoalsEntity(
      userId: userId,
      dailyCalorieTarget: dailyCalorieTarget,
      proteinTargetGrams: proteinTargetGrams,
      carbsTargetGrams: carbsTargetGrams,
      fatTargetGrams: fatTargetGrams,
      updatedAt: updatedAt,
    );
  }
}
