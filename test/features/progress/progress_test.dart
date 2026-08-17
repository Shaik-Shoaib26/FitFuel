import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/utils/progress_calculator.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';

void main() {
  final now = DateTime.now();

  group('ProgressCalculator Domain Tests', () {
    test('Calculates calorie and protein adherence correctly over ranges', () {
      final nutritionHistory = [
        // Day 1
        NutritionRecordEntity(
          id: '1',
          foodName: 'Oats',
          mealType: 'Breakfast',
          calories: 1950.0,
          protein: 100.0,
          carbohydrates: 200.0,
          fats: 50.0,
          sugar: 0.0,
          servingSize: 100.0,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final goals = NutritionGoalsEntity(
        userId: 'uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 100.0,
        carbsTargetGrams: 250.0,
        fatTargetGrams: 65.0,
        updatedAt: now,
      );

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: nutritionHistory,
        healthHistory: [],
        weightHistory: [],
        goals: goals,
        profile: null,
        daysCount: 7,
      );

      expect(summary.nutritionDaysLogged, 1);
      expect(summary.calorieAdherencePercent, 97.5); // 1950/2000 * 100
      expect(summary.calorieConsistencyPercent, 100.0); // 1950 is within 5% tolerance of 2000
      expect(summary.proteinDaysMet, 1);
      expect(summary.proteinConsistencyPercent, 100.0);
    });

    test('Handles missing nutrition data gracefully without failing with 0%', () {
      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: [],
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 30,
      );

      expect(summary.nutritionDaysLogged, 0);
      expect(summary.calorieAdherencePercent, 0.0);
      expect(summary.calorieConsistencyPercent, 0.0);
    });

    test('Computes hydration metrics and handles empty hydration history', () {
      final healthHistory = [
        HealthRecordEntity(
          id: '1',
          date: now.toString().split(' ').first,
          waterIntakeMl: 2600.0,
          waterTargetMl: 2500.0,
          exercises: [],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: healthHistory,
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      expect(summary.avgWater, 2600.0);
      expect(summary.waterDaysMet, 1);
      expect(summary.waterConsistencyPercent, 100.0);
    });

    test('Tracks exercise active days, workout minutes and calories correctly', () {
      final healthHistory = [
        HealthRecordEntity(
          id: '1',
          date: now.toString().split(' ').first,
          waterIntakeMl: 2000.0,
          waterTargetMl: 2500.0,
          exercises: const [
            ExerciseEntity(activity: 'Running', duration: 45, caloriesBurned: 400.0),
            ExerciseEntity(activity: 'Yoga', duration: 15, caloriesBurned: 100.0),
          ],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: healthHistory,
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      expect(summary.exerciseActiveDays, 1);
      expect(summary.exerciseTotalMinutes, 60);
      expect(summary.exerciseAvgDuration, 60.0);
      expect(summary.exerciseTotalCaloriesBurned, 500.0);
    });

    test('Calculates habit metrics and finds most/least consistent habits', () {
      final healthHistory = [
        HealthRecordEntity(
          id: '1',
          date: now.toString().split(' ').first,
          waterIntakeMl: 2000.0,
          waterTargetMl: 2500.0,
          exercises: [],
          habits: const {
            'Sleep 8h': true,
            'Walk 10k': false,
          },
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: healthHistory,
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      expect(summary.habitsAvgCompletionRate, 50.0);
      expect(summary.habitsMostConsistent, 'Sleep 8h');
      expect(summary.habitsLeastConsistent, 'Walk 10k');
    });

    test('Calculates wellness averages and detects improving/declining trends', () {
      final healthHistory = [
        HealthRecordEntity(
          id: '1',
          date: now.subtract(const Duration(days: 4)).toString().split(' ').first,
          waterIntakeMl: 1000.0,
          waterTargetMl: 2500.0,
          exercises: [],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
        HealthRecordEntity(
          id: '2',
          date: now.subtract(const Duration(days: 2)).toString().split(' ').first,
          waterIntakeMl: 2500.0,
          waterTargetMl: 2500.0,
          exercises: [],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
        HealthRecordEntity(
          id: '3',
          date: now.toString().split(' ').first,
          waterIntakeMl: 2500.0,
          waterTargetMl: 2500.0,
          exercises: [],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: healthHistory,
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      expect(summary.wellnessAvgScore > 0, isTrue);
      expect(summary.wellnessBestScore > 0, isTrue);
      expect(summary.wellnessLowestScore > 0, isTrue);
      // Average score of second half should be higher because of met water targets
      expect(summary.wellnessTrend, 'Improving');
    });

    test('Calculates weight changes, starting weights, and percentage shifts', () {
      final weightHistory = [
        WeightRecordEntity(id: '1', weight: 80.0, recordedAt: now.subtract(const Duration(days: 10))),
        WeightRecordEntity(id: '2', weight: 78.0, recordedAt: now),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: [],
        healthHistory: [],
        weightHistory: weightHistory,
        goals: null,
        profile: null,
        daysCount: 30,
      );

      expect(summary.startingWeight, 80.0);
      expect(summary.currentWeight, 78.0);
      expect(summary.weightChange, -2.0);
      expect(summary.weightChangePercent, -2.5);
    });

    test('Calculates streaks correctly and checks achievement unlock criteria', () {
      final nutritionHistory = [
        NutritionRecordEntity(
          id: '1',
          foodName: 'Oats',
          mealType: 'Breakfast',
          calories: 300.0,
          protein: 10.0,
          carbohydrates: 40.0,
          fats: 5.0,
          sugar: 0.0,
          servingSize: 100.0,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        NutritionRecordEntity(
          id: '2',
          foodName: 'Oats',
          mealType: 'Breakfast',
          calories: 300.0,
          protein: 10.0,
          carbohydrates: 40.0,
          fats: 5.0,
          sugar: 0.0,
          servingSize: 100.0,
          consumedAt: now.subtract(const Duration(days: 1)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = ProgressCalculator.calculateSummary(
        nutritionHistory: nutritionHistory,
        healthHistory: [],
        weightHistory: [],
        goals: null,
        profile: null,
        daysCount: 7,
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
      expect(summary.milestones.firstWhere((m) => m.id == 'first_meal').isUnlocked, isTrue);
    });
  });

  group('AI Context Generator & Progress Integration Tests', () {
    test('GenerateContext includes weight trends, streaks and consistency details in AI context', () {
      final profile = UserProfileEntity(
        uid: 'uid',
        email: 'test@test.com',
        age: 30,
        gender: 'male',
        height: 180.0,
        weight: 75.0,
        activityLevel: 'very_active',
        fitnessGoal: 'Gain Muscle',
        dietaryPreference: 'vegan',
        createdAt: now,
        updatedAt: now,
      );

      final weightHistory = [
        WeightRecordEntity(id: '1', weight: 73.0, recordedAt: now.subtract(const Duration(days: 10))),
        WeightRecordEntity(id: '2', weight: 75.0, recordedAt: now),
      ];

      final context = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
        profile: profile,
        weightHistory: weightHistory,
      );

      expect(context.contains('USER LONG-TERM PROGRESS & ACHIEVEMENT'), isTrue);
      expect(context.contains('Weight Tracker: Start: 73.0 kg, Current: 75.0 kg, Change: 2.0 kg (2.7%)'), isTrue);
      expect(context.contains('Gain Muscle'), isTrue);
    });
  });
}
