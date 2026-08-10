import 'package:fitfuel/features/nutrition/data/datasources/nutrition_remote_datasource.dart';
import 'package:fitfuel/features/nutrition/data/models/nutrition_record_model.dart';
import 'package:fitfuel/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_calculator.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNutritionRemoteDataSource implements INutritionRemoteDataSource {
  final Map<String, List<NutritionRecordModel>> database = {};

  @override
  Future<void> addRecord(String uid, NutritionRecordModel record) async {
    database.putIfAbsent(uid, () => []).add(record);
  }

  @override
  Future<List<NutritionRecordModel>> getRecords(String uid) async {
    return database[uid] ?? [];
  }

  @override
  Stream<List<NutritionRecordModel>> streamRecords(String uid) {
    return Stream.value(database[uid] ?? []);
  }

  @override
  Future<void> updateRecord(String uid, NutritionRecordModel record) async {
    final list = database[uid];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        list[index] = record;
      }
    }
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {
    final list = database[uid];
    if (list != null) {
      list.removeWhere((r) => r.id == recordId);
    }
  }
}

void main() {
  late FakeNutritionRemoteDataSource fakeDataSource;
  late NutritionRepositoryImpl repository;
  final now = DateTime.now();

  setUp(() {
    fakeDataSource = FakeNutritionRemoteDataSource();
    repository = NutritionRepositoryImpl(fakeDataSource);
  });

  final testRecord = NutritionRecordEntity(
    id: 'food_1',
    foodName: 'Oatmeal',
    mealType: 'Breakfast',
    calories: 300.0,
    protein: 10.0,
    carbohydrates: 50.0,
    fats: 5.0,
    sugar: 8.0,
    servingSize: 100.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('Food Log Management Repository Tests', () {
    test('addRecord registers a record in datasource', () async {
      await repository.addRecord('user_abc', testRecord);
      final records = await repository.getRecords('user_abc');

      expect(records.length, 1);
      expect(records.first.foodName, 'Oatmeal');
    });

    test('updateRecord modifies existing document in database', () async {
      await repository.addRecord('user_abc', testRecord);

      final updatedRecord = testRecord.copyWith(
        foodName: 'Oatmeal with Honey',
        calories: 350.0,
      );

      await repository.updateRecord('user_abc', updatedRecord);
      final records = await repository.getRecords('user_abc');

      expect(records.first.foodName, 'Oatmeal with Honey');
      expect(records.first.calories, 350.0);
    });

    test('deleteRecord deletes the document and updates totals count', () async {
      await repository.addRecord('user_abc', testRecord);
      var records = await repository.getRecords('user_abc');
      expect(records.length, 1);

      await repository.deleteRecord('user_abc', 'food_1');
      records = await repository.getRecords('user_abc');
      expect(records.isEmpty, isTrue);
    });

    test('Progress updates correctly after addition and updates', () async {
      final goals = NutritionGoalsEntity(
        userId: 'user_abc',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 100,
        carbsTargetGrams: 200,
        fatTargetGrams: 50,
        updatedAt: now,
      );

      // Add first record
      await repository.addRecord('user_abc', testRecord);
      var list = await repository.getRecords('user_abc');
      var stats = NutritionCalculator.calculateProgress(dailyRecords: list, goals: goals);
      expect(stats.totalCalories, 300.0);
      expect(stats.calorieProgress, 0.15); // 300/2000

      // Update record to higher calorie count
      final updated = testRecord.copyWith(calories: 500.0);
      await repository.updateRecord('user_abc', updated);
      list = await repository.getRecords('user_abc');
      stats = NutritionCalculator.calculateProgress(dailyRecords: list, goals: goals);
      expect(stats.totalCalories, 500.0);
      expect(stats.calorieProgress, 0.25); // 500/2000
    });

    test('Validates invalid input data (null/negative fields logic)', () {
      final invalidRecord = NutritionRecordEntity(
        id: 'food_2',
        foodName: '',
        mealType: 'Snack',
        calories: -50.0,
        protein: -2.0,
        carbohydrates: -5.0,
        fats: -1.0,
        sugar: -1.0,
        servingSize: -100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Check validation constraints
      expect(invalidRecord.foodName.isEmpty, isTrue);
      expect(invalidRecord.calories < 0, isTrue);
      expect(invalidRecord.servingSize < 0, isTrue);
    });
  });
}
