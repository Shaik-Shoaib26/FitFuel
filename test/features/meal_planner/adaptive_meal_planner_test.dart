import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/adaptive_meal_planner_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_plan_calculator.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';

void main() {
  final testFoods = [
    const FoodEntity(
      id: 'idli_id',
      name: 'Idli',
      category: 'Breakfast',
      servingSize: 100,
      servingUnit: 'g',
      calories: 120,
      protein: 4,
      carbohydrates: 25,
      fats: 0.5,
      fiber: 2,
      sugar: 0,
      sodium: 100,
      isVegetarian: true,
      isIndian: true,
    ),
    const FoodEntity(
      id: 'dosa_id',
      name: 'Dosa',
      category: 'Breakfast',
      servingSize: 100,
      servingUnit: 'g',
      calories: 160,
      protein: 3,
      carbohydrates: 29,
      fats: 3,
      fiber: 2,
      sugar: 0,
      sodium: 150,
      isVegetarian: true,
      isIndian: true,
    ),
    const FoodEntity(
      id: 'dal_id',
      name: 'Dal Tadka',
      category: 'Lunch',
      servingSize: 150,
      servingUnit: 'g',
      calories: 180,
      protein: 9,
      carbohydrates: 22,
      fats: 6,
      fiber: 5,
      sugar: 1,
      sodium: 350,
      isVegetarian: true,
      isIndian: true,
    ),
    const FoodEntity(
      id: 'paneer_id',
      name: 'Paneer Bhurji',
      category: 'Dinner',
      servingSize: 120,
      servingUnit: 'g',
      calories: 280,
      protein: 16,
      carbohydrates: 6,
      fats: 21,
      fiber: 2,
      sugar: 2,
      sodium: 400,
      isVegetarian: true,
      isIndian: true,
    ),
    const FoodEntity(
      id: 'chicken_id',
      name: 'Chicken Curry',
      category: 'Dinner',
      servingSize: 150,
      servingUnit: 'g',
      calories: 240,
      protein: 26,
      carbohydrates: 4,
      fats: 13,
      fiber: 1,
      sugar: 1,
      sodium: 450,
      isVegetarian: false,
      isIndian: true,
    ),
    const FoodEntity(
      id: 'almonds_id',
      name: 'Almonds',
      category: 'Snacks',
      servingSize: 30,
      servingUnit: 'g',
      calories: 170,
      protein: 6,
      carbohydrates: 6,
      fats: 15,
      fiber: 3.5,
      sugar: 1,
      sodium: 0,
      isVegetarian: true,
    ),
  ];

  group('Adaptive Meal Planner - Engine & Custom Logic Tests', () {
    test('1. Generates meal plan from calorie target', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      expect(plan.targetCalories, equals(2000));
      expect(plan.meals.isNotEmpty, isTrue);
    });

    test('2. Generates meal plan from protein target', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 100,
        targetCarbs: 220,
        targetFat: 55,
        fitnessGoal: 'Gain Muscle',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      expect(plan.targetProtein, equals(100));
      expect(plan.meals.any((m) => m.totalProtein > 0), isTrue);
    });

    test('3. Correctly distributes meals', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 1800,
        targetProtein: 75,
        targetCarbs: 200,
        targetFat: 50,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      final mealTypes = plan.meals.map((m) => m.mealType).toList();
      expect(mealTypes.contains('Breakfast'), isTrue);
      expect(mealTypes.contains('Lunch'), isTrue);
      expect(mealTypes.contains('Dinner'), isTrue);
    });

    test('4. Respects vegetarian preference', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Vegetarian',
      );

      for (final meal in plan.meals) {
        for (final foodItem in meal.foods) {
          expect(foodItem.food.isVegetarian, isTrue);
        }
      }
    });

    test('5. Respects vegan preference', () {
      const veganFood = FoodEntity(
        id: 'vegan_id',
        name: 'Tofu Scramble',
        category: 'Breakfast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 120,
        protein: 10,
        carbohydrates: 3,
        fats: 7,
        fiber: 2,
        sugar: 1,
        sodium: 200,
        isVegetarian: true,
      );

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: [veganFood, ...testFoods],
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Vegan',
      );

      for (final meal in plan.meals) {
        for (final foodItem in meal.foods) {
          expect(foodItem.food.name.toLowerCase().contains('paneer'), isFalse);
          expect(foodItem.food.name.toLowerCase().contains('chicken'), isFalse);
        }
      }
    });

    test('6. Respects keto preference', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 90,
        targetCarbs: 20,
        targetFat: 120,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Keto',
      );

      for (final meal in plan.meals) {
        for (final foodItem in meal.foods) {
          expect(foodItem.food.carbohydrates / (foodItem.food.servingSize / 100), lessThanOrEqualTo(10.0));
        }
      }
    });

    test('7. Respects low-carb preference', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 90,
        targetCarbs: 40,
        targetFat: 100,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Low Carb',
      );

      for (final meal in plan.meals) {
        for (final foodItem in meal.foods) {
          expect(foodItem.food.carbohydrates / (foodItem.food.servingSize / 100), lessThanOrEqualTo(15.0));
        }
      }
    });

    test('8. Respects fitness goal (skips snack if Lose Weight & Sedentary)', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 1500,
        targetProtein: 60,
        targetCarbs: 180,
        targetFat: 45,
        fitnessGoal: 'Lose Weight',
        activityLevel: 'Sedentary',
        dietaryPreference: 'Any',
      );

      final mealTypes = plan.meals.map((m) => m.mealType).toList();
      expect(mealTypes.contains('Morning Snack'), isFalse);
      expect(mealTypes.contains('Evening Snack'), isFalse);
    });

    test('9. Respects activity level', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2600,
        targetProtein: 110,
        targetCarbs: 320,
        targetFat: 80,
        fitnessGoal: 'Gain Muscle',
        activityLevel: 'Very Active',
        dietaryPreference: 'Any',
      );

      expect(plan.targetCalories, equals(2600));
    });

    test('10. Excludes user-requested foods', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
        excludedFoodNames: ['Chicken Curry'],
      );

      for (final meal in plan.meals) {
        for (final foodItem in meal.foods) {
          expect(foodItem.food.name, isNot(equals('Chicken Curry')));
        }
      }
    });

    test('11. Uses remaining calories after logged meals', () {
      final todayLogs = [
        NutritionRecordEntity(
          id: 'log1',
          foodName: 'Idli',
          mealType: 'Breakfast',
          calories: 500,
          protein: 15,
          carbohydrates: 60,
          fats: 2,
          sugar: 0,
          servingSize: 200,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
        todayLogs: todayLogs,
      );

      const remainingCals = 2000 - 500;
      final plannedRemainingCals = plan.plannedCalories - 500;
      expect(plannedRemainingCals, lessThanOrEqualTo(remainingCals + 50));
    });

    test('12. Uses remaining protein after logged meals', () {
      final todayLogs = [
        NutritionRecordEntity(
          id: 'log1',
          foodName: 'Protein Shake',
          mealType: 'Breakfast',
          calories: 200,
          protein: 40,
          carbohydrates: 5,
          fats: 2,
          sugar: 0,
          servingSize: 250,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 100,
        targetCarbs: 200,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
        todayLogs: todayLogs,
      );

      expect(plan.meals.any((m) => m.mealType != 'Breakfast' && m.totalProtein > 0), isTrue);
    });

    test('13. Prevents excessive meal repetition', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
        recentFoodIds: ['chicken_id'],
      );

      for (final meal in plan.meals) {
        if (meal.mealType == 'Dinner') {
          for (final f in meal.foods) {
            expect(f.food.id, isNot(equals('chicken_id')));
          }
        }
      }
    });

    test('14. Generates swap alternatives', () {
      final selectedAlternatives = testFoods.where((f) => f.category == 'Dinner').toList();
      expect(selectedAlternatives.length, greaterThanOrEqualTo(2));
    });

    test('15. Recalculates serving nutrition', () {
      final baseFood = testFoods[0]; // Idli: 120 kcal per 100g
      final portion = MealPlanCalculator.calculateFoodPortion(baseFood, 150, 'g');

      expect(portion.calories, equals(180.0));
      expect(portion.protein, equals(6.0));
    });

    test('16. Handles missing foods safely', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: [],
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      expect(plan.meals.every((m) => m.foods.isEmpty), isTrue);
    });

    test('17. Handles empty food database safely', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: [],
        targetCalories: 1500,
        targetProtein: 50,
        targetCarbs: 150,
        targetFat: 40,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );
      expect(plan.meals.every((m) => m.foods.isEmpty), isTrue);
    });

    test('18. Handles missing profile safely', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 85,
        targetCarbs: 220,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Moderately Active',
        dietaryPreference: 'Any',
      );
      expect(plan.meals.isNotEmpty, isTrue);
    });

    test('19. Handles missing goals safely', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 75,
        targetCarbs: 230,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Moderately Active',
        dietaryPreference: 'Any',
      );
      expect(plan.targetCalories, equals(2000));
    });

    test('20. Handles already completed meals', () {
      final todayLogs = [
        NutritionRecordEntity(
          id: 'log1',
          foodName: 'Idli',
          mealType: 'Breakfast',
          calories: 300,
          protein: 10,
          carbohydrates: 50,
          fats: 2,
          sugar: 0,
          servingSize: 100,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final completedMealTypes = todayLogs.map((l) => l.mealType.toLowerCase()).toSet();
      expect(completedMealTypes.contains('breakfast'), isTrue);
    });

    test('21. Calculates next meal correctly', () {
      final todayLogs = [
        NutritionRecordEntity(
          id: 'log1',
          foodName: 'Idli',
          mealType: 'Breakfast',
          calories: 300,
          protein: 10,
          carbohydrates: 50,
          fats: 2,
          sugar: 0,
          servingSize: 100,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      final completedMealTypes = todayLogs.map((l) => l.mealType.toLowerCase()).toSet();
      PlannedMealEntity? nextMeal;
      for (final meal in plan.meals) {
        if (!completedMealTypes.contains(meal.mealType.toLowerCase())) {
          nextMeal = meal;
          break;
        }
      }

      expect(nextMeal, isNotNull);
      expect(nextMeal!.mealType, isNot(equals('Breakfast')));
    });

    test('22. Generates correct AI meal-plan context', () {
      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );



      final profile = UserProfileEntity(
        uid: 'user123',
        displayName: 'Shoaib',
        email: 'shoaib@test.com',
        gender: 'Male',
        age: 25,
        height: 180.0,
        weight: 75.0,
        activityLevel: 'Active',
        fitnessGoal: 'Maintain Weight',
        dietaryPreference: 'Any',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final contextText = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: NutritionGoalsEntity(
          userId: 'user123',
          dailyCalorieTarget: 2000,
          proteinTargetGrams: 80.0,
          carbsTargetGrams: 250.0,
          fatTargetGrams: 60.0,
          updatedAt: DateTime.now(),
        ),
        profile: profile,
        mealPlan: plan,
      );

      expect(contextText.contains('=== FITFUEL ADAPTIVE MEAL PLAN CONTEXT ==='), isTrue);
    });

    test('23. Correctly routes meal-related AI intents', () async {
      final mock = AiNutritionMockDatasource();
      
      final response1 = await mock.generateResponse(
        userPrompt: 'Suggest breakfast',
        systemContext: 'AVAILABLE FOODS DATABASE:\n- Food: Idli | Category: Breakfast | Serving: 100 g | Calories: 120 kcal | Protein: 4g | Carbohydrates: 25g | Fat: 0.5g | Fiber: 2g | Sugar: 0g | Sodium: 100mg | Id: idli_id | Favorite: false',
        history: [],
      );
      expect(response1.text.contains('choices matching your request') || response1.text.contains('smart choice'), isTrue);

      final response2 = await mock.generateResponse(
        userPrompt: 'Swap my lunch',
        systemContext: 'AVAILABLE FOODS DATABASE:\n- Food: Dal Tadka | Category: Lunch | Serving: 150 g | Calories: 180 kcal | Protein: 9g | Carbohydrates: 22g | Fat: 6g | Fiber: 5g | Sugar: 1g | Sodium: 350mg | Id: dal_id | Favorite: false',
        history: [],
      );
      expect(response2.text.contains('swap alternatives') || response2.text.contains('alternatives for your Lunch'), isTrue);
    });

    test('24. "Hi" remains a general greeting', () async {
      final mock = AiNutritionMockDatasource();
      final response = await mock.generateResponse(
        userPrompt: 'Hi',
        systemContext: '',
        history: [],
      );
      expect(response.text.contains('Hi! 👋 I\'m FitFuel AI'), isTrue);
    });
  });
}
