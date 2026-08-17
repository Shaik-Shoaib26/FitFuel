import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/weekly_report/domain/utils/weekly_report_calculator.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';

void main() {
  final now = DateTime.now();

  group('WeeklyReportCalculator & Score Tests', () {
    test('Calculates perfect weekly score (100) when all targets are fully met', () {
      final List<NutritionRecordEntity> nutrition = [];
      final List<HealthRecordEntity> health = [];

      // Populate 7 days of completed perfect records
      for (int i = 1; i <= 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toString().split(' ').first;

        nutrition.add(
          NutritionRecordEntity(
            id: 'n_$i',
            foodName: 'Chicken and Rice',
            mealType: 'Dinner',
            calories: 2000.0, // perfect 2000 kcal target
            protein: 150.0,
            carbohydrates: 200.0,
            fats: 65.0,
            sugar: 0.0,
            servingSize: 100.0,
            consumedAt: date,
            createdAt: now,
            updatedAt: now,
          ),
        );

        health.add(
          HealthRecordEntity(
            id: 'h_$i',
            date: dateStr,
            waterIntakeMl: 2500.0, // met target
            waterTargetMl: 2500.0,
            exercises: const [
              ExerciseEntity(activity: 'Running', duration: 45, caloriesBurned: 400.0),
            ],
            habits: const {
              'Sleep 7-8h': true,
              '10k Steps': true,
            },
            createdAt: date,
            updatedAt: date,
          ),
        );
      }

      final goals = NutritionGoalsEntity(
        userId: 'uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 150.0,
        carbsTargetGrams: 200.0,
        fatTargetGrams: 65.0,
        updatedAt: now,
      );

      final report = WeeklyReportCalculator.calculateReport(
        nutritionHistory: nutrition,
        healthHistory: health,
        weightHistory: [],
        goals: goals,
        profile: null,
        period: 'completed',
        referenceDate: now,
      );

      expect(report.healthScore, 100.0);
      expect(report.nutritionScore, 100.0);
      expect(report.hydrationScore, 100.0);
      expect(report.exerciseScore, 100.0); // 7 active days is > 3 target
      expect(report.habitsScore, 100.0);
      expect(report.wellnessScore, 100.0);
    });

    test('Handles missing metrics dynamically without penalizing scores', () {
      final List<NutritionRecordEntity> nutrition = [];
      // Only log nutrition - omit hydration, exercise, habits, wellness logs
      for (int i = 1; i <= 7; i++) {
        final date = now.subtract(Duration(days: i));
        nutrition.add(
          NutritionRecordEntity(
            id: 'n_$i',
            foodName: 'Oats',
            mealType: 'Breakfast',
            calories: 2000.0,
            protein: 150.0,
            carbohydrates: 200.0,
            fats: 65.0,
            sugar: 0.0,
            servingSize: 100.0,
            consumedAt: date,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final goals = NutritionGoalsEntity(
        userId: 'uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 150.0,
        carbsTargetGrams: 200.0,
        fatTargetGrams: 65.0,
        updatedAt: now,
      );

      final report = WeeklyReportCalculator.calculateReport(
        nutritionHistory: nutrition,
        healthHistory: [], // empty health history
        weightHistory: [],
        goals: goals,
        profile: null,
        period: 'completed',
        referenceDate: now,
      );

      expect(report.nutritionScore, 100.0);
      expect(report.healthScore, 100.0);
    });

    test('Identifies strongest and weakest areas and suggests plans', () {
      final List<NutritionRecordEntity> nutrition = [];
      final List<HealthRecordEntity> health = [];

      for (int i = 1; i <= 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toString().split(' ').first;

        nutrition.add(
          NutritionRecordEntity(
            id: 'n_$i',
            foodName: 'Food',
            mealType: 'Snack',
            calories: 2000.0,
            protein: 150.0,
            carbohydrates: 200.0,
            fats: 65.0,
            sugar: 0.0,
            servingSize: 100.0,
            consumedAt: date,
            createdAt: now,
            updatedAt: now,
          ),
        );

        health.add(
          HealthRecordEntity(
            id: 'h_$i',
            date: dateStr,
            waterIntakeMl: 500.0, // hydration is very weak (500/2500)
            waterTargetMl: 2500.0,
            exercises: const [], // no exercise
            habits: const {},
            createdAt: date,
            updatedAt: date,
          ),
        );
      }

      final goals = NutritionGoalsEntity(
        userId: 'uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 150.0,
        carbsTargetGrams: 200.0,
        fatTargetGrams: 65.0,
        updatedAt: now,
      );

      final report = WeeklyReportCalculator.calculateReport(
        nutritionHistory: nutrition,
        healthHistory: health,
        weightHistory: [],
        goals: goals,
        profile: null,
        period: 'completed',
        referenceDate: now,
      );

      expect(report.strongestArea, 'Nutrition');
      expect(report.weakestArea, 'Hydration');
      expect(report.actionPlan.contains('Reach hydration target at least 5 days'), isTrue);
    });

    test('Evaluates date boundaries for completed, previous, and preview weeks', () {
      final List<NutritionRecordEntity> nutrition = [
        // Completed week date
        NutritionRecordEntity(
          id: 'nc',
          foodName: 'Oats',
          mealType: 'Breakfast',
          calories: 2000.0,
          protein: 150.0,
          carbohydrates: 200.0,
          fats: 65.0,
          sugar: 0.0,
          servingSize: 100.0,
          consumedAt: now.subtract(const Duration(days: 3)),
          createdAt: now,
          updatedAt: now,
        ),
        // Previous week date
        NutritionRecordEntity(
          id: 'np',
          foodName: 'Oats',
          mealType: 'Breakfast',
          calories: 2000.0,
          protein: 150.0,
          carbohydrates: 200.0,
          fats: 65.0,
          sugar: 0.0,
          servingSize: 100.0,
          consumedAt: now.subtract(const Duration(days: 10)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final goals = NutritionGoalsEntity(
        userId: 'uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 150.0,
        carbsTargetGrams: 200.0,
        fatTargetGrams: 65.0,
        updatedAt: now,
      );

      final completedReport = WeeklyReportCalculator.calculateReport(
        nutritionHistory: nutrition,
        healthHistory: [],
        weightHistory: [],
        goals: goals,
        profile: null,
        period: 'completed',
        referenceDate: now,
      );

      final previousReport = WeeklyReportCalculator.calculateReport(
        nutritionHistory: nutrition,
        healthHistory: [],
        weightHistory: [],
        goals: goals,
        profile: null,
        period: 'previous',
        referenceDate: now,
      );

      expect(completedReport.nutritionDaysLogged, 1);
      expect(previousReport.nutritionDaysLogged, 1);
    });

    test('Calculates weight changes, starting, and percentage trends', () {
      final List<WeightRecordEntity> weights = [
        WeightRecordEntity(id: 'w1', weight: 80.0, recordedAt: now.subtract(const Duration(days: 5))),
        WeightRecordEntity(id: 'w2', weight: 79.2, recordedAt: now.subtract(const Duration(days: 1))),
      ];

      final report = WeeklyReportCalculator.calculateReport(
        nutritionHistory: [],
        healthHistory: [],
        weightHistory: weights,
        goals: null,
        profile: null,
        period: 'completed',
        referenceDate: now,
      );

      expect(report.startingWeight, 80.0);
      expect(report.currentWeight, 79.2);
      expect(report.weightChange, -0.8);
      expect(report.weightChangePercent, -1.0); // -0.8 / 80.0 * 100
    });
  });

  group('Gemini Context & Intent Routing Tests', () {
    test('GenerateContext includes smart weekly health report sections in buffer', () {
      final context = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
      );

      expect(context.contains('=== FITFUEL WEEKLY HEALTH REPORT ==='), isTrue);
      expect(context.contains('Weekly Health Score:'), isTrue);
      expect(context.contains('Strongest Area:'), isTrue);
      expect(context.contains('Weakest Area:'), isTrue);
    });

    test('AiNutritionMockDatasource parses and routes weekly performance queries correctly', () async {
      final datasource = AiNutritionMockDatasource();
      
      const systemContext = '''
=== FITFUEL WEEKLY HEALTH REPORT ===
Period: Completed Week
Weekly Health Score: 75/100
Previous Week Score: 68/100
Score Change: +7.0 points
Strongest Area: Habits (You completed an average of 92% of your habit checklists)
Weakest Area: Hydration (You met your water intake targets on 3 of 7 days)

Nutrition:
- calorie consistency: 85%
- protein consistency: 80%
- nutrition logging days: 5

Hydration:
- target days: 3
- total water: 1500 ml
- hydration consistency: 40%

Exercise:
- active days: 3
- workout minutes: 120
- calories burned: 900

Habits:
- average completion: 92%
- most consistent habit: Sleep 8h
- least consistent habit: Walk 10k

Wellness:
- average score: 76
- trend: Improving

Weight:
- starting weight: 80.0 kg
- current weight: 79.6 kg
- change: -0.4 kg
- percentage change: -0.5%

Achievements: Scale Step, First Meal
Current Streak: 5 days
Next Week Action Plan: Reach hydration target at least 5 days; Keep water bottle near desk
=== END WEEKLY HEALTH REPORT ===
''';

      // 1. Weekly Overview
      final overviewRes = await datasource.generateResponse(userPrompt: 'How was my week?', systemContext: systemContext);
      expect(overviewRes.text.contains('Health Score: 75/100'), isTrue);
      expect(overviewRes.text.contains('Strongest Area: Habits'), isTrue);
      expect(overviewRes.text.contains('Weakest Area: Hydration'), isTrue);

      // 2. Strongest Area
      final strongestRes = await datasource.generateResponse(userPrompt: 'What was my strongest health area this week?', systemContext: systemContext);
      expect(strongestRes.text.contains('strongest health area'), isTrue);
      expect(strongestRes.text.contains('Habits'), isTrue);

      // 3. Weakest Area
      final weakestRes = await datasource.generateResponse(userPrompt: 'What was my weakest health area?', systemContext: systemContext);
      expect(weakestRes.text.contains('weakest health area'), isTrue);
      expect(weakestRes.text.contains('Hydration'), isTrue);

      // 4. Next Week Action Plan
      final actionRes = await datasource.generateResponse(userPrompt: 'What should I improve next week?', systemContext: systemContext);
      expect(actionRes.text.contains('focus plan for next week'), isTrue);
      expect(actionRes.text.contains('Reach hydration target at least 5 days'), isTrue);

      // 5. Score Change
      final changeRes = await datasource.generateResponse(userPrompt: 'Why did my health score change compared with last week?', systemContext: systemContext);
      expect(changeRes.text.contains('Weekly Health Score is **75/100**'), isTrue);
      expect(changeRes.text.contains('Previous Week Score: **68/100**'), isTrue);
      expect(changeRes.text.contains('Overall Change: **+7.0 points**'), isTrue);

      // 6. Nutrition
      final nutritionRes = await datasource.generateResponse(userPrompt: 'How was my nutrition this week?', systemContext: systemContext);
      expect(nutritionRes.text.contains('Calorie Consistency: 85%'), isTrue);
      expect(nutritionRes.text.contains('Protein Consistency: 80%'), isTrue);

      // 7. Hydration
      final hydrationRes = await datasource.generateResponse(userPrompt: 'How was my hydration this week?', systemContext: systemContext);
      expect(hydrationRes.text.contains('Hydration Consistency: 40%'), isTrue);

      // 8. Exercise
      final exerciseRes = await datasource.generateResponse(userPrompt: 'How much did I exercise this week?', systemContext: systemContext);
      expect(exerciseRes.text.contains('Exercise Consistency: 3'), isTrue); // active days: 3

      // 9. Habits
      final habitsRes = await datasource.generateResponse(userPrompt: 'How were my habits this week?', systemContext: systemContext);
      expect(habitsRes.text.contains('Habit Completion Rate: 92%'), isTrue);

      // 10. Wellness
      final wellnessRes = await datasource.generateResponse(userPrompt: 'How was my wellness score?', systemContext: systemContext);
      expect(wellnessRes.text.contains('Wellness Trend: Improving'), isTrue);

      // 11. Weight
      final weightRes = await datasource.generateResponse(userPrompt: 'What happened to my weight this week?', systemContext: systemContext);
      expect(weightRes.text.contains('Weight Change: -0.4 kg'), isTrue);

      // 12. Achievements
      final achievementsRes = await datasource.generateResponse(userPrompt: 'What achievements did I unlock?', systemContext: systemContext);
      expect(achievementsRes.text.contains('Milestones: Scale Step, First Meal'), isTrue);

      // 13. Streak
      final streakRes = await datasource.generateResponse(userPrompt: 'What is my current streak?', systemContext: systemContext);
      expect(streakRes.text.contains('Streak details: 5 days'), isTrue);
    });
  });
}
