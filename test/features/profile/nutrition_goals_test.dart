import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/profile/data/models/nutrition_goals_model.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testEntity = NutritionGoalsEntity(
    userId: 'test_uid_123',
    dailyCalorieTarget: 2200,
    proteinTargetGrams: 160.0,
    carbsTargetGrams: 220.0,
    fatTargetGrams: 70.0,
    updatedAt: now,
  );

  final testModel = NutritionGoalsModel(
    userId: 'test_uid_123',
    dailyCalorieTarget: 2200,
    proteinTargetGrams: 160.0,
    carbsTargetGrams: 220.0,
    fatTargetGrams: 70.0,
    updatedAt: now,
  );

  group('NutritionGoalsEntity Tests', () {
    test('Entity properties verify correctly', () {
      expect(testEntity.userId, 'test_uid_123');
      expect(testEntity.dailyCalorieTarget, 2200);
      expect(testEntity.proteinTargetGrams, 160.0);
      expect(testEntity.carbsTargetGrams, 220.0);
      expect(testEntity.fatTargetGrams, 70.0);
      expect(testEntity.updatedAt, now);
    });

    test('Entity equality and copyWith work correctly', () {
      final copy = testEntity.copyWith(dailyCalorieTarget: 2400);
      expect(copy.dailyCalorieTarget, 2400);
      expect(copy.userId, testEntity.userId);
      expect(copy.proteinTargetGrams, testEntity.proteinTargetGrams);

      final identicalCopy = testEntity.copyWith();
      expect(identicalCopy, testEntity);
    });
  });

  group('NutritionGoalsModel Conversion Tests', () {
    test('Model toEntity converts accurately to NutritionGoalsEntity', () {
      final entity = testModel.toEntity();
      expect(entity, testEntity);
    });

    test('Model fromEntity converts accurately from NutritionGoalsEntity', () {
      final model = NutritionGoalsModel.fromEntity(testEntity);
      expect(model.userId, testEntity.userId);
      expect(model.dailyCalorieTarget, testEntity.dailyCalorieTarget);
      expect(model.proteinTargetGrams, testEntity.proteinTargetGrams);
      expect(model.carbsTargetGrams, testEntity.carbsTargetGrams);
      expect(model.fatTargetGrams, testEntity.fatTargetGrams);
    });

    test('Model toFirestore produces valid Map parameters', () {
      final firestoreMap = testModel.toFirestore();
      expect(firestoreMap['userId'], 'test_uid_123');
      expect(firestoreMap['dailyCalorieTarget'], 2200);
      expect(firestoreMap['macroTargets']['proteinGrams'], 160.0);
      expect(firestoreMap['macroTargets']['carbsGrams'], 220.0);
      expect(firestoreMap['macroTargets']['fatGrams'], 70.0);
      expect(firestoreMap['updatedAt'], isA<Timestamp>());
    });
  });
}
