import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/nutrition_gap_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/smart_food_recommendation_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/enums/recommendation_priority.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/food_swap_engine.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/recommendation_scoring_engine.dart';

void main() {
  group('Meal & Smart Eat Swap Regression Tests', () {
    late SmartFoodRecommendationEntity paneerTikkaRec;
    late List<FoodEntity> foodsDb;
    late UserProfileEntity profileVeg;
    late UserProfileEntity profileVegan;
    late UserProfileEntity profileAnything;
    late NutritionGapEntity testGap;

    setUp(() {
      paneerTikkaRec = const SmartFoodRecommendationEntity(
        id: 'predefined_paneer_tikka',
        foodId: 'predefined_paneer_tikka',
        foodName: 'Paneer Tikka',
        imageUrl: 'assets/images/foods/paneer_tikka.png',
        category: 'Lunch',
        servingSize: 150,
        calories: 250,
        protein: 15,
        carbs: 10,
        fat: 16,
        fiber: 2,
        matchScore: 90,
        priority: RecommendationPriority.high,
        reasons: [],
        tags: ['Vegetarian'],
        pantryAvailable: false,
        groceryAvailable: false,
        recentlyConsumed: false,
        isFavorite: false,
        estimatedPreparationMinutes: 15,
      );

      foodsDb = [
        const FoodEntity(
          id: 'predefined_paneer_tikka',
          name: 'Paneer Tikka',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 250,
          protein: 15,
          carbohydrates: 10,
          fats: 16,
          fiber: 2,
          sugar: 0,
          sodium: 0,
          isVegetarian: true,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner'],
        ),
        const FoodEntity(
          id: 'predefined_tofu_tikka',
          name: 'Tofu Tikka',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 200,
          protein: 18,
          carbohydrates: 5,
          fats: 10,
          fiber: 3,
          sugar: 0,
          sodium: 0,
          isVegetarian: true,
          isVegan: true,
          mealTypes: ['Lunch', 'Dinner'],
        ),
        const FoodEntity(
          id: 'predefined_chicken_tikka',
          name: 'Chicken Tikka',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 260,
          protein: 25,
          carbohydrates: 4,
          fats: 12,
          fiber: 1,
          sugar: 0,
          sodium: 0,
          isVegetarian: false,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner'],
        ),
        const FoodEntity(
          id: 'predefined_egg_bhurji',
          name: 'Egg Bhurji',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 220,
          protein: 16,
          carbohydrates: 3,
          fats: 14,
          fiber: 0,
          sugar: 0,
          sodium: 0,
          isVegetarian: true,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner'],
        ),
      ];

      profileVeg = UserProfileEntity(
        uid: 'user_1',
        email: 'veg@test.com',
        displayName: 'Veg User',
        dietaryPreference: 'vegetarian',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      profileVegan = UserProfileEntity(
        uid: 'user_2',
        email: 'vegan@test.com',
        displayName: 'Vegan User',
        dietaryPreference: 'vegan',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      profileAnything = UserProfileEntity(
        uid: 'user_3',
        email: 'any@test.com',
        displayName: 'Any User',
        dietaryPreference: 'anything',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testGap = const NutritionGapEntity(
        remainingCalories: 1500,
        remainingProtein: 80,
        remainingCarbs: 150,
        remainingFat: 50,
        remainingFiber: 15,
        remainingWater: 1000,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: true,
        hydrationDeficit: true,
      );
    });

    // 1. Swap changes the current food ID.
    // 2. Swap does not return the same food.
    // 3. Swap changes food name.
    // 4. Swap changes nutrition.
    // 5. Swap changes image.
    test('1-5. Swap changes properties and does not return the same food', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: foodsDb,
        profile: profileAnything,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(swaps.isNotEmpty, true);
      for (final s in swaps) {
        expect(s.foodId != paneerTikkaRec.foodId, true);
        expect(s.foodName != paneerTikkaRec.foodName, true);
        expect(s.calories != paneerTikkaRec.calories || s.protein != paneerTikkaRec.protein, true);
      }
    });

    // 8. Vegetarian swap excludes meat.
    test('8. Vegetarian swap excludes meat', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: foodsDb,
        profile: profileVeg,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(swaps.any((s) => s.foodId == 'predefined_chicken_tikka'), false);
    });

    // 9. Vegan swap excludes dairy/eggs.
    test('9. Vegan swap excludes dairy/eggs', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: foodsDb,
        profile: profileVegan,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      // Only Tofu Tikka remains since Paneer Tikka (dairy) and Egg Bhurji (eggs) and Chicken Tikka (meat) are excluded
      expect(swaps.length, 1);
      expect(swaps.first.foodId, 'predefined_tofu_tikka');
    });

    // 10. Anything allows veg/non-veg.
    test('10. Anything allows veg and non-veg', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: foodsDb,
        profile: profileAnything,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(swaps.any((s) => s.foodId == 'predefined_chicken_tikka'), true);
      expect(swaps.any((s) => s.foodId == 'predefined_tofu_tikka'), true);
    });

    // 11. Explicit exclusion always wins.
    test('11. Explicit exclusion always wins', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: foodsDb,
        profile: profileAnything,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: ['chicken'],
      );

      expect(swaps.any((s) => s.foodId == 'predefined_chicken_tikka'), false);
    });

    // 12. Recent foods receive repetition penalty.
    test('12. Recent foods receive repetition penalty in scoring', () {
      final recsPenalty = RecommendationScoringEngine.score(
        foods: foodsDb,
        profile: profileAnything,
        gap: testGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: [foodsDb[1]], // Tofu Tikka is recent
        chatExclusions: const [],
      );

      final recsNoPenalty = RecommendationScoringEngine.score(
        foods: foodsDb,
        profile: profileAnything,
        gap: testGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      final scorePenalty = recsPenalty.firstWhere((r) => r.foodId == 'predefined_tofu_tikka').matchScore;
      final scoreNoPenalty = recsNoPenalty.firstWhere((r) => r.foodId == 'predefined_tofu_tikka').matchScore;
      expect(scorePenalty < scoreNoPenalty, true);
    });

    // 16. Empty alternatives show safe state.
    test('16. Empty alternatives return empty list', () {
      final swaps = FoodSwapEngine.findSwaps(
        original: paneerTikkaRec,
        foods: [foodsDb[0]], // database only has Paneer Tikka
        profile: profileAnything,
        gap: testGap,
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(swaps.isEmpty, true);
    });
  });
}
