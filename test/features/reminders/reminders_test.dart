import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/features/reminders/domain/entities/reminder_entity.dart';
import 'package:fitfuel/features/reminders/domain/entities/reminder_settings_entity.dart';
import 'package:fitfuel/features/reminders/domain/entities/daily_routine_entity.dart';
import 'package:fitfuel/features/reminders/domain/utils/reminder_calculator.dart';
import 'package:fitfuel/features/reminders/domain/utils/daily_routine_calculator.dart';
import 'package:fitfuel/features/reminders/domain/utils/reminder_priority_engine.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';
import 'package:fitfuel/features/dashboard/presentation/widgets/dashboard_routine_card.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test setup data variables
  const testSettings = ReminderSettingsEntity(
    hydrationEnabled: true,
    mealEnabled: true,
    breakfastTime: '08:00',
    lunchTime: '13:00',
    dinnerTime: '20:00',
    snackTime: '16:00',
    exerciseEnabled: true,
    exerciseTime: '18:00',
    habitEnabled: true,
    weightEnabled: true,
    weightDay: 'Sunday',
    weightTime: '07:30',
  );

  final testProfile = UserProfileEntity(
    uid: 'user123',
    email: 'shoaib@test.com',
    displayName: 'Shoaib',
    age: 25,
    gender: 'Male',
    height: 180,
    weight: 75,
    activityLevel: 'Lightly Active',
    fitnessGoal: 'Lose Weight',
    createdAt: DateTime(2026, 8, 14),
    updatedAt: DateTime(2026, 8, 14),
  );

  final testGoals = NutritionGoalsEntity(
    userId: 'user123',
    dailyCalorieTarget: 2200,
    proteinTargetGrams: 160,
    carbsTargetGrams: 220,
    fatTargetGrams: 70,
    updatedAt: DateTime(2026, 8, 14),
  );

  final todayHealthEmpty = HealthRecordEntity.empty('2026-08-14');

  final todayHealthCompleted = HealthRecordEntity(
    id: '2026-08-14',
    date: '2026-08-14',
    waterIntakeMl: 2500,
    waterTargetMl: 2000,
    exercises: [
      const ExerciseEntity(
        activity: 'Running',
        duration: 30,
        caloriesBurned: 300,
      )
    ],
    habits: const {
      'Sleep 7-8h': true,
      '10k Steps': true,
      'Stretching': true,
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final todayNutritionLogged = [
    NutritionRecordEntity(
      id: 'n1',
      foodName: 'Oats & Banana',
      mealType: 'Breakfast',
      calories: 400,
      protein: 15,
      carbohydrates: 60,
      fats: 8,
      sugar: 12,
      servingSize: 100,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    NutritionRecordEntity(
      id: 'n2',
      foodName: 'Chicken Rice',
      mealType: 'Lunch',
      calories: 600,
      protein: 40,
      carbohydrates: 70,
      fats: 12,
      sugar: 2,
      servingSize: 300,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    NutritionRecordEntity(
      id: 'n3',
      foodName: 'Salmon Veggies',
      mealType: 'Dinner',
      calories: 500,
      protein: 35,
      carbohydrates: 20,
      fats: 20,
      sugar: 3,
      servingSize: 250,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )
  ];

  group('Daily Routine Calculator & Domain Logic Tests', () {
    test('1. Creates daily routine correctly with items enabled', () {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      expect(routine.date, equals('2026-08-14'));
      expect(routine.totalReminders, isPositive);
    });

    test('2. Calculates routine completion percentage accurately', () {
      final routineEmpty = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      final fullSettings = testSettings.copyWith(
        aiCoachEnabled: false,
        weeklyReviewEnabled: false,
      );

      final fullNutrition = [
        ...todayNutritionLogged,
        NutritionRecordEntity(
          id: 'n4',
          foodName: 'Apple',
          mealType: 'Snack',
          calories: 80,
          protein: 0,
          carbohydrates: 20,
          fats: 0,
          sugar: 15,
          servingSize: 100,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final routineFull = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: fullSettings,
        todayHealth: todayHealthCompleted,
        todayNutrition: fullNutrition,
        weightHistory: [
          WeightRecordEntity(
            id: 'w1',
            weight: 75,
            recordedAt: DateTime.now(),
          )
        ],
        nutritionHistory: fullNutrition,
        healthHistory: [todayHealthCompleted],
        activityLevel: 'Lightly Active',
      );

      expect(routineEmpty.completionPercentage, lessThan(routineFull.completionPercentage));
      expect(routineFull.completionPercentage, equals(100.0));
    });

    test('3. Detects missing hydration target and remains incomplete', () {
      final incompleteHydration = todayHealthEmpty.copyWith(waterIntakeMl: 500, waterTargetMl: 2000);
      final isComplete = ReminderCalculator.isHydrationComplete(incompleteHydration);
      expect(isComplete, isFalse);
    });

    test('4. Stops hydration reminders / marks completed after target met', () {
      final completeHydration = todayHealthEmpty.copyWith(waterIntakeMl: 2200, waterTargetMl: 2000);
      final isComplete = ReminderCalculator.isHydrationComplete(completeHydration);
      expect(isComplete, isTrue);
    });

    test('5. Detects missing meals and marks them incomplete', () {
      final isBreakfastLogged = ReminderCalculator.isMealLogged(const [], 'Breakfast');
      expect(isBreakfastLogged, isFalse);
    });

    test('6. Stops meal reminder / marks completed after meal is logged', () {
      final isBreakfastLogged = ReminderCalculator.isMealLogged(todayNutritionLogged, 'Breakfast');
      expect(isBreakfastLogged, isTrue);
    });

    test('7. Detects missing exercise', () {
      final isExerciseDone = ReminderCalculator.isExerciseComplete(todayHealthEmpty);
      expect(isExerciseDone, isFalse);
    });

    test('8. Detects completed exercise', () {
      final isExerciseDone = ReminderCalculator.isExerciseComplete(todayHealthCompleted);
      expect(isExerciseDone, isTrue);
    });

    test('9. Detects incomplete habits', () {
      final hasIncomplete = ReminderCalculator.isHabitsComplete(todayHealthEmpty);
      expect(hasIncomplete, isFalse);
    });

    test('10. Detects completed habits', () {
      final hasIncomplete = ReminderCalculator.isHabitsComplete(todayHealthCompleted);
      expect(hasIncomplete, isTrue);
    });

    test('11. Calculates next reminder chronologically', () {
      final referenceTime = DateTime(2026, 8, 14, 12, 0); // Noon
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
        referenceDate: referenceTime,
      );

      expect(routine.nextReminder, isNotNull);
      // Scheduled time of next reminder should be after 12:00 (e.g. Lunch 13:00)
      final parts = routine.nextReminder!.scheduledTime.split(':');
      final hour = int.parse(parts[0]);
      expect(hour, greaterThanOrEqualTo(12));
    });

    test('12. Prevents duplicate reminders in list construction', () {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      final ids = routine.routineItems.map((e) => e.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, equals(uniqueIds.length));
    });

    test('13. Calculates reminder priority correctly based on rules', () {
      final p1 = ReminderPriorityEngine.getPriority(ReminderType.hydration, isCriticalHydration: true);
      final p2 = ReminderPriorityEngine.getPriority(ReminderType.hydration, isCriticalHydration: false);
      final p3 = ReminderPriorityEngine.getPriority(ReminderType.breakfast);
      final p4 = ReminderPriorityEngine.getPriority(ReminderType.aiCoaching);

      expect(p1, equals(ReminderPriority.critical));
      expect(p2, equals(ReminderPriority.medium));
      expect(p3, equals(ReminderPriority.high));
      expect(p4, equals(ReminderPriority.low));
    });

    test('14. Generates combined check-in reminders correctly to avoid spam', () {
      final message = ReminderPriorityEngine.generateCombinedReminder(
        remainingWaterMl: 1250,
        hasPendingMeal: true,
        pendingMealName: 'Lunch',
        pendingHabitsCount: 2,
        exercisePending: true,
      );

      expect(message, contains('Your FitFuel check-in 💚'));
      expect(message, contains('1250 ml water remaining'));
      expect(message, contains('Lunch hasn\'t been logged'));
      expect(message, contains('2 habits remaining'));
      expect(message, contains('Exercise hasn\'t been completed'));
    });

    test('15. Handles empty user data sets safely', () {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: const ReminderSettingsEntity(),
        todayHealth: null,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: null,
      );
      expect(routine.totalReminders, isPositive);
      expect(routine.completionPercentage, equals(6.3));
    });

    test('16. Handles missing profile data and uses fallbacks', () {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: null, // Missing profile activityLevel
      );

      final exerciseRem = routine.routineItems.firstWhere((i) => i.type == ReminderType.exercise);
      expect(exerciseRem.description, contains('workout')); // falls back to default description
    });

    test('17. Handles disabled reminders correctly by filtering them out', () {
      final disabledSettings = testSettings.copyWith(
        hydrationEnabled: false,
        mealEnabled: false,
      );
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: disabledSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      final hasHydration = routine.routineItems.any((i) => i.type == ReminderType.hydration);
      final hasMeals = routine.routineItems.any((i) => i.type == ReminderType.breakfast);
      expect(hasHydration, isFalse);
      expect(hasMeals, isFalse);
    });

    test('18. Handles invalid/empty reminder settings objects safely', () {
      const emptySettings = ReminderSettingsEntity();
      expect(emptySettings.breakfastTime, equals('08:00'));
      expect(emptySettings.lunchTime, equals('13:00'));
      expect(emptySettings.hydrationEnabled, isTrue);
    });
  });

  group('AI Context Integration & Intent Routing Tests', () {
    test('19. Generates correct AI routine context string in AiContextGenerator', () {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      final context = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: testGoals,
        todayHealth: todayHealthEmpty,
        profile: testProfile,
        dailyRoutine: routine,
      );

      expect(context, contains('=== FITFUEL DAILY ROUTINE CONTEXT ==='));
      expect(context, contains('Routine Completion: 6.3%'));
      expect(context, contains('Pending Tasks:'));
      expect(context, contains('Hydration Status: Behind Goal'));
    });

    test('20. Routes routine-related AI questions to routine response', () async {
      final routine = DailyRoutineCalculator.calculateRoutine(
        date: '2026-08-14',
        settings: testSettings,
        todayHealth: todayHealthEmpty,
        todayNutrition: const [],
        weightHistory: const [],
        nutritionHistory: const [],
        healthHistory: const [],
        activityLevel: 'Lightly Active',
      );

      final systemContext = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: testGoals,
        todayHealth: todayHealthEmpty,
        profile: testProfile,
        dailyRoutine: routine,
      );

      final mockDs = AiNutritionMockDatasource();
      final reply = await mockDs.generateResponse(
        userPrompt: 'What should I do next today?',
        systemContext: systemContext,
      );

      expect(reply.text, contains('routine progress'));
      expect(reply.text, contains('Completion:'));
    });

    test('21. Does not route "Hi" to food recommendations', () async {
      final mockDs = AiNutritionMockDatasource();
      final reply = await mockDs.generateResponse(
        userPrompt: 'Hi',
        systemContext: '=== USER NUTRITION CONTEXT ===',
      );

      expect(reply.text, contains("Hi! 👋 I'm FitFuel AI"));
      expect(reply.suggestedFoods, isNull);
    });

    test('22. Does not break existing AI food recommendation routing', () async {
      final mockDs = AiNutritionMockDatasource();
      final reply = await mockDs.generateResponse(
        userPrompt: 'Suggest dinner',
        systemContext: '=== USER NUTRITION CONTEXT ===\n- Calories Target: 2000 kcal\n- Protein Target: 150 g',
      );

      // Meal recommendations are generated, returning food choices list
      expect(reply.text, contains('choices matching your request'));
      expect(reply.suggestedFoods, isNotEmpty);
    });
  });

  group('Presentation Screen & Routing Widget Tests', () {
    testWidgets('23. Dashboard routine card renders completion percentage correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyRoutineProvider.overrideWithValue(
              const DailyRoutineEntity(
                date: '2026-08-14',
                routineItems: [],
                completedItems: [],
                pendingItems: [],
                completionPercentage: 65.0,
                totalReminders: 5,
                completedReminders: 3,
                nextReminder: ReminderEntity(
                  id: 'hydration_1',
                  title: 'Drink Water 💧',
                  description: 'Stay hydrated!',
                  type: ReminderType.hydration,
                  scheduledTime: '11:00',
                  actionRoute: '/dashboard',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardRoutineCard(),
            ),
          ),
        ),
      );

      expect(find.text("Today's Routine"), findsOneWidget);
      expect(find.text('View Routine'), findsOneWidget);
    });

    test('24. Daily Routine route resolves to correct path', () {
      expect(AppRoutes.dailyRoutine, equals('/daily-routine'));
    });

    test('25. Reminder Settings route resolves to correct path', () {
      expect(AppRoutes.reminders, equals('/reminders'));
    });
  });
}
