import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/pantry_item_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_list_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/nutrition_gap_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/nutrition_gap_engine.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/recommendation_scoring_engine.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/food_swap_engine.dart';
import 'package:fitfuel/features/smart_eat/domain/enums/recommendation_priority.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/smart_food_recommendation_entity.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';

void main() {
  group('Smart Eat Phase 31 Tests', () {
    late UserProfileEntity testProfile;
    late NutritionGoalsEntity testGoals;
    late List<FoodEntity> testFoods;
    late List<PantryItemEntity> testPantry;
    late List<GroceryListEntity> testGrocery;

    setUp(() {
      testProfile = UserProfileEntity(
        uid: 'test_uid',
        email: 'test@fitfuel.com',
        displayName: 'Tester',
        age: 25,
        gender: 'Male',
        height: 180,
        weight: 75,
        activityLevel: 'Active',
        fitnessGoal: 'Lose Weight',
        dietaryPreference: 'anything',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testGoals = NutritionGoalsEntity(
        userId: 'test_uid',
        dailyCalorieTarget: 2000,
        proteinTargetGrams: 150,
        carbsTargetGrams: 200,
        fatTargetGrams: 65,
        updatedAt: DateTime.now(),
      );

      testFoods = [
        const FoodEntity(
          id: '1',
          name: 'Chicken Breast and Rice',
          category: 'Lunch',
          servingSize: 200,
          servingUnit: 'g',
          calories: 450,
          protein: 40,
          carbohydrates: 45,
          fats: 8,
          fiber: 2,
          sugar: 0,
          sodium: 120,
          isVegetarian: false,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner'],
        ),
        const FoodEntity(
          id: '2',
          name: 'Eggs and Spinach',
          category: 'Breakfast',
          servingSize: 150,
          servingUnit: 'g',
          calories: 180,
          protein: 16,
          carbohydrates: 2,
          fats: 12,
          fiber: 1,
          sugar: 0,
          sodium: 80,
          isVegetarian: true,
          isVegan: false,
          mealTypes: ['Breakfast', 'Lunch'],
        ),
        const FoodEntity(
          id: '3',
          name: 'Tofu Broccoli Salad',
          category: 'Lunch',
          servingSize: 250,
          servingUnit: 'g',
          calories: 220,
          protein: 18,
          carbohydrates: 12,
          fats: 10,
          fiber: 6,
          sugar: 1,
          sodium: 90,
          isVegetarian: true,
          isVegan: true,
          mealTypes: ['Lunch', 'Dinner'],
        ),
      ];

      testPantry = [
        PantryItemEntity(
          id: 'p1',
          foodName: 'Spinach',
          quantity: 2,
          unit: 'bag',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          addedAt: DateTime.now(),
        ),
      ];

      testGrocery = [];
    });

    // 1-5. Nutrition Gap Engine
    test('NutritionGapEngine calculations correct remaining values', () {
      final gap = NutritionGapEngine.calculate(
        profile: testProfile,
        goals: testGoals,
        todayRecords: [
          NutritionRecordEntity(
            id: 'r1',
            foodName: 'Eggs and Spinach',
            mealType: 'Breakfast',
            calories: 180,
            protein: 16,
            carbohydrates: 2,
            fats: 12,
            sugar: 0,
            servingSize: 150,
            consumedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        ],
        todayHealth: HealthRecordEntity(
          id: 'h1',
          date: '2026-08-17',
          waterIntakeMl: 500,
          waterTargetMl: 2000,
          exercises: const [],
          habits: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      expect(gap.remainingCalories, 1820.0);
      expect(gap.remainingProtein, 134.0);
      expect(gap.proteinDeficit, true);
      expect(gap.calorieDeficit, true);
      expect(gap.hydrationDeficit, true);
    });

    test('NutritionGapEngine calorie excess trigger when target exceeded', () {
      final gap = NutritionGapEngine.calculate(
        profile: testProfile,
        goals: testGoals,
        todayRecords: [
          NutritionRecordEntity(
            id: 'r1',
            foodName: 'Massive Feast',
            mealType: 'Dinner',
            calories: 2500,
            protein: 160,
            carbohydrates: 200,
            fats: 90,
            sugar: 0,
            servingSize: 1000,
            consumedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        ],
        todayHealth: null,
      );

      expect(gap.remainingCalories, -500.0);
      expect(gap.calorieExcess, true);
      expect(gap.calorieDeficit, false);
    });

    // 6-12. Recommendation Scoring Engine Dietary Restrictions
    test('Scoring Engine excludes non-vegetarian food if Vegetarian', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      final recs = RecommendationScoringEngine.score(
        foods: testFoods,
        profile: testProfile.copyWith(dietaryPreference: 'vegetarian'),
        gap: gap,
        currentMealType: 'Lunch',
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(recs.any((r) => r.foodName.contains('Chicken')), false);
      expect(recs.any((r) => r.foodName.contains('Tofu')), true);
    });

    test('Scoring Engine excludes dairy/grains if Paleo', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      final recs = RecommendationScoringEngine.score(
        foods: testFoods,
        profile: testProfile.copyWith(dietaryPreference: 'paleo'),
        gap: gap,
        currentMealType: 'Lunch',
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(recs.any((r) => r.foodName.contains('Rice')), false);
    });

    test('Scoring Engine excludes high carbs if Keto', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      final recs = RecommendationScoringEngine.score(
        foods: testFoods,
        profile: testProfile.copyWith(dietaryPreference: 'keto'),
        gap: gap,
        currentMealType: 'Lunch',
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(recs.any((r) => r.foodName.contains('Rice')), false);
    });

    // 13-18. History Penalties & Favoriting
    test('Scoring Engine applies penalty for recently consumed foods', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      final recent = [
        NutritionRecordEntity(
          id: 'rec_log',
          foodName: 'Chicken Breast and Rice',
          mealType: 'Lunch',
          calories: 450,
          protein: 40,
          carbohydrates: 45,
          fats: 8,
          sugar: 0,
          servingSize: 200,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      final recs = RecommendationScoringEngine.score(
        foods: testFoods,
        profile: testProfile,
        gap: gap,
        currentMealType: 'Lunch',
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: recent,
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      final chickenRec = recs.firstWhere((r) => r.foodName.contains('Chicken'));
      final tofuRec = recs.firstWhere((r) => r.foodName.contains('Tofu'));

      expect(tofuRec.matchScore > chickenRec.matchScore, true);
    });

    test('Scoring Engine gives boost for favorite foods', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      final recs = RecommendationScoringEngine.score(
        foods: testFoods,
        profile: testProfile,
        gap: gap,
        currentMealType: 'Lunch',
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: const [],
        favoriteFoods: [testFoods.last],
        recentFoods: const [],
        chatExclusions: const [],
      );

      final tofuRec = recs.firstWhere((r) => r.foodName.contains('Tofu'));
      expect(tofuRec.tags.contains('Favorite'), true);
    });

    // 19-24. Swaps & pantry matches
    test('FoodSwapEngine finds nutritionally compatible alternatives', () {
      const gap = NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 100,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 20,
        remainingWater: 1500,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );

      const original = SmartFoodRecommendationEntity(
        id: 'rec_3',
        foodId: '3',
        foodName: 'Tofu Broccoli Salad',
        imageUrl: '',
        category: 'Lunch',
        servingSize: 250,
        calories: 220,
        protein: 18,
        carbs: 12,
        fat: 10,
        fiber: 6,
        matchScore: 85,
        priority: RecommendationPriority.high,
        reasons: [],
        tags: [],
        pantryAvailable: false,
        groceryAvailable: false,
        recentlyConsumed: false,
        isFavorite: false,
        estimatedPreparationMinutes: 10,
      );

      final swaps = FoodSwapEngine.findSwaps(
        original: original,
        foods: testFoods,
        profile: testProfile,
        gap: gap,
        pantryItems: testPantry,
        groceryLists: testGrocery,
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(swaps.any((s) => s.foodName.contains('Chicken')), false);
      expect(swaps.any((s) => s.foodName.contains('Eggs')), true);
    });

    // 25-30. AI Context and Intent Mocking
    test('AiContextGenerator generates FITFUEL SMART EAT CONTEXT block', () {
      final context = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: testGoals,
        profile: testProfile,
        availableFoods: testFoods,
        pantryItems: testPantry,
      );

      expect(context.contains('=== FITFUEL SMART EAT FOOD CONTEXT ==='), true);
      expect(context.contains('Remaining calories: 2000'), true);
    });

    test('AiNutritionMockDatasource routes Smart Eat queries correctly', () async {
      const query = 'what should I eat for dinner?';
      final isMealPlan = query.toLowerCase().contains('what should i eat');
      expect(isMealPlan, true);

      const systemContext = '''
=== FITFUEL SMART EAT FOOD CONTEXT ===
- Current meal: Dinner
- Remaining calories: 1500
- Remaining protein: 80
- Top recommendation: Chicken Breast and Rice
  * Calories: 450
  * Protein: 40
  * Carbs: 45
  * Fats: 8
  * Match Score: 95%
- Alternative recommendations:
  * Tofu Broccoli Salad (88% Match)
=== END CONTEXT ===
''';

      final mockDataSource = AiNutritionMockDatasource();
      final response = await mockDataSource.generateResponse(
        userPrompt: query,
        systemContext: systemContext,
      );

      expect(response.text.contains('Based on your FitFuel Smart Eat analysis'), true);
      expect(response.text.contains('Top Recommendation: Chicken Breast and Rice'), true);
      expect(response.suggestedFoods != null, true);
      expect(response.suggestedFoods!.first.foodName, 'Chicken Breast and Rice');
    });
  });
}
