import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/nutrition/data/models/nutrition_record_model.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testEntity = NutritionRecordEntity(
    id: 'rec_123',
    foodName: 'Grilled Chicken Breast',
    mealType: 'Lunch',
    calories: 165.0,
    protein: 31.0,
    carbohydrates: 0.0,
    fats: 3.6,
    sugar: 0.0,
    servingSize: 100.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final testModel = NutritionRecordModel(
    id: 'rec_123',
    foodName: 'Grilled Chicken Breast',
    mealType: 'Lunch',
    calories: 165.0,
    protein: 31.0,
    carbohydrates: 0.0,
    fats: 3.6,
    sugar: 0.0,
    servingSize: 100.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('NutritionRecordEntity Tests', () {
    test('Entity properties verify correctly', () {
      expect(testEntity.id, 'rec_123');
      expect(testEntity.foodName, 'Grilled Chicken Breast');
      expect(testEntity.mealType, 'Lunch');
      expect(testEntity.calories, 165.0);
      expect(testEntity.protein, 31.0);
      expect(testEntity.carbohydrates, 0.0);
      expect(testEntity.fats, 3.6);
      expect(testEntity.sugar, 0.0);
      expect(testEntity.servingSize, 100.0);
      expect(testEntity.consumedAt, now);
      expect(testEntity.createdAt, now);
      expect(testEntity.updatedAt, now);
    });

    test('Entity equality and copyWith work correctly', () {
      final copy = testEntity.copyWith(calories: 180.0);
      expect(copy.calories, 180.0);
      expect(copy.id, testEntity.id);
      expect(copy.foodName, testEntity.foodName);
      expect(copy.mealType, testEntity.mealType);

      final identicalCopy = testEntity.copyWith();
      expect(identicalCopy, testEntity);
    });
  });

  group('NutritionRecordModel Conversion Tests', () {
    test('Model toEntity converts accurately to NutritionRecordEntity', () {
      final entity = testModel.toEntity();
      expect(entity, testEntity);
    });

    test('Model fromEntity converts accurately from NutritionRecordEntity', () {
      final model = NutritionRecordModel.fromEntity(testEntity);
      expect(model.id, testEntity.id);
      expect(model.foodName, testEntity.foodName);
      expect(model.mealType, testEntity.mealType);
      expect(model.calories, testEntity.calories);
      expect(model.protein, testEntity.protein);
      expect(model.carbohydrates, testEntity.carbohydrates);
      expect(model.fats, testEntity.fats);
      expect(model.sugar, testEntity.sugar);
      expect(model.servingSize, testEntity.servingSize);
    });

    test('Model toFirestore produces valid Map parameters', () {
      final firestoreMap = testModel.toFirestore();
      expect(firestoreMap['foodName'], 'Grilled Chicken Breast');
      expect(firestoreMap['mealType'], 'Lunch');
      expect(firestoreMap['calories'], 165.0);
      expect(firestoreMap['protein'], 31.0);
      expect(firestoreMap['carbohydrates'], 0.0);
      expect(firestoreMap['fats'], 3.6);
      expect(firestoreMap['sugar'], 0.0);
      expect(firestoreMap['servingSize'], 100.0);
      expect(firestoreMap['consumedAt'], isA<Timestamp>());
    });
  });
}
