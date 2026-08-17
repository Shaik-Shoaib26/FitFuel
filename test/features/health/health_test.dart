import 'package:fitfuel/features/health/data/models/exercise_model.dart';
import 'package:fitfuel/features/health/data/models/health_record_model.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/domain/utils/wellness_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exercise Tracking Model/Entity Tests', () {
    test('ExerciseEntity copyWith and creation works correctly', () {
      const exercise = ExerciseEntity(
        activity: 'Running',
        duration: 30,
        caloriesBurned: 300.0,
      );

      final updated = exercise.copyWith(duration: 45);
      expect(updated.duration, 45);
      expect(updated.activity, 'Running');
    });

    test('ExerciseModel translates to/from JSON successfully', () {
      final model = ExerciseModel.fromJson(const {
        'activity': 'Cycling',
        'duration': 20,
        'caloriesBurned': 150.0,
      });

      expect(model.activity, 'Cycling');
      expect(model.duration, 20);
      expect(model.caloriesBurned, 150.0);

      final json = model.toJson();
      expect(json['activity'], 'Cycling');
      expect(json['duration'], 20);
      expect(json['caloriesBurned'], 150.0);
    });
  });

  group('Health Record Entity/Model Tests', () {
    test('HealthRecordEntity empty constructor defaults work correctly', () {
      final record = HealthRecordEntity.empty('2026-08-10');
      expect(record.id, '2026-08-10');
      expect(record.date, '2026-08-10');
      expect(record.waterIntakeMl, 0.0);
      expect(record.waterTargetMl, 2500.0);
      expect(record.exercises.isEmpty, isTrue);
      expect(record.habits['Sleep 7-8h'], isFalse);
    });

    test('HealthRecordModel fromEntity / toEntity works cleanly', () {
      final entity = HealthRecordEntity(
        id: '2026-08-10',
        date: '2026-08-10',
        waterIntakeMl: 1000.0,
        waterTargetMl: 2000.0,
        exercises: const [
          ExerciseEntity(activity: 'Walking', duration: 15, caloriesBurned: 50.0)
        ],
        habits: const {'Sleep 7-8h': true},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final model = HealthRecordModel.fromEntity(entity);
      expect(model.waterIntakeMl, 1000.0);
      expect(model.exercises.first.activity, 'Walking');

      final back = model.toEntity();
      expect(back.waterTargetMl, 2000.0);
      expect(back.exercises.first.activity, 'Walking');
    });
  });

  group('WellnessCalculator Scoring Tests', () {
    test('Score is 0 when no foods logged and health record is null', () {
      final score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: false,
        healthRecord: null,
      );
      expect(score, 0.0);
    });

    test('Score is 25 when food is logged but health record is null', () {
      final score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: true,
        healthRecord: null,
      );
      expect(score, 25.0);
    });

    test('Calculates full hydration points correctly (25 points)', () {
      final record = HealthRecordEntity.empty('2026-08-10').copyWith(
        waterIntakeMl: 2500.0,
        waterTargetMl: 2500.0,
      );

      final score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: false,
        healthRecord: record,
      );
      // hydration is 100% -> 25 points, others 0
      expect(score, 25.0);
    });

    test('Calculates partial exercise points correctly (30 mins target)', () {
      // 15 mins exercised / 30 mins target = 50% progress = 12.5 points
      final record = HealthRecordEntity.empty('2026-08-10').copyWith(
        exercises: const [
          ExerciseEntity(activity: 'Stretching', duration: 15, caloriesBurned: 100.0)
        ],
      );

      final score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: false,
        healthRecord: record,
      );
      expect(score, 12.5);
    });

    test('Calculates habit completion points correctly (25 points for 100% completed)', () {
      final record = HealthRecordEntity.empty('2026-08-10').copyWith(
        habits: const {
          'Sleep': true,
          'Steps': true,
        },
      );

      final score = WellnessCalculator.calculateScore(
        hasLoggedFoodToday: false,
        healthRecord: record,
      );
      // habits 2/2 -> 100% -> 25 points
      expect(score, 25.0);
    });

    test('Filters health records correctly by specific date string', () {
      final record1 = HealthRecordEntity.empty('2026-08-09');
      final record2 = HealthRecordEntity.empty('2026-08-10');

      final list = [record1, record2];
      final result = WellnessCalculator.filterByDate(list, '2026-08-10');

      expect(result, isNotNull);
      expect(result!.date, '2026-08-10');
    });
  });
}
