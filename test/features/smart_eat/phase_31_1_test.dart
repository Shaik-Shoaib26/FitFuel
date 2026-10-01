import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/engines/recommendation_scoring_engine.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/nutrition_gap_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/food/data/repositories/food_asset_repository.dart';

void main() {
  group('Phase 31.1 Unit Tests', () {
    late List<FoodEntity> mockFoods;
    late UserProfileEntity mockProfile;
    late NutritionGapEntity mockGap;

    setUp(() {
      mockFoods = [
        const FoodEntity(
          id: 'predefined_chicken_tikka',
          name: 'Chicken Tikka',
          category: 'Lunch',
          servingSize: 100.0,
          servingUnit: 'g',
          calories: 150.0,
          protein: 24.0,
          carbohydrates: 3.0,
          fats: 4.8,
          fiber: 0.4,
          sugar: 0.3,
          sodium: 360.0,
          isIndian: true,
          isVegetarian: false,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner', 'Snacks'],
          ingredients: ['Chicken breast', 'Yogurt', 'Spices'],
        ),
        const FoodEntity(
          id: 'predefined_paneer_tikka',
          name: 'Paneer Tikka',
          category: 'Snacks',
          servingSize: 100.0,
          servingUnit: 'g',
          calories: 275.0,
          protein: 15.0,
          carbohydrates: 9.0,
          fats: 20.0,
          fiber: 1.5,
          sugar: 1.0,
          sodium: 320.0,
          isIndian: true,
          isVegetarian: true,
          isVegan: false,
          mealTypes: ['Lunch', 'Dinner', 'Snacks'],
          ingredients: ['Paneer', 'Bell peppers', 'Yogurt', 'Spices'],
        ),
        const FoodEntity(
          id: 'predefined_poha',
          name: 'Poha',
          category: 'Breakfast',
          servingSize: 100.0,
          servingUnit: 'g',
          calories: 180.0,
          protein: 3.0,
          carbohydrates: 35.0,
          fats: 3.0,
          fiber: 2.0,
          sugar: 1.0,
          sodium: 290.0,
          isIndian: true,
          isVegetarian: true,
          isVegan: true,
          mealTypes: ['Breakfast', 'Snacks'],
          ingredients: ['Flattened Rice', 'Peanuts', 'Onion', 'Turmeric'],
        ),
      ];

      mockProfile = UserProfileEntity(
        uid: 'user_123',
        email: 'user@fitfuel.com',
        displayName: 'John Doe',
        weight: 70.0,
        height: 175.0,
        age: 25,
        gender: 'Male',
        activityLevel: 'Moderately Active',
        fitnessGoal: 'Maintain Weight',
        dietaryPreference: 'Anything',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mockGap = const NutritionGapEntity(
        remainingCalories: 500.0,
        remainingProtein: 50.0,
        remainingCarbs: 100.0,
        remainingFat: 30.0,
        remainingFiber: 10.0,
        remainingWater: 1.0,
        proteinDeficit: true,
        calorieDeficit: true,
        calorieExcess: false,
        fiberDeficit: false,
        hydrationDeficit: false,
      );
    });

    test('DietaryPreference: Anything recommends vegetarian and non-vegetarian mix', () {
      final recs = RecommendationScoringEngine.score(
        foods: mockFoods,
        profile: mockProfile,
        gap: mockGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(recs, isNotEmpty);
      final hasVeg = recs.any((r) => r.tags.contains('Vegetarian'));
      final hasNonVeg = recs.any((r) => !r.tags.contains('Vegetarian'));
      expect(hasVeg, isTrue);
      expect(hasNonVeg, isTrue);
    });

    test('DietaryPreference: Vegetarian filters out non-vegetarian foods', () {
      final vegProfile = mockProfile.copyWith(dietaryPreference: 'Vegetarian');

      final recs = RecommendationScoringEngine.score(
        foods: mockFoods,
        profile: vegProfile,
        gap: mockGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: const [],
      );

      expect(recs, isNotEmpty);
      for (final rec in recs) {
        expect(rec.tags.contains('Vegetarian'), isTrue);
        expect(rec.foodName, isNot('Chicken Tikka'));
      }
    });

    test('Exclusions by Food Name filters out matching foods', () {
      final recs = RecommendationScoringEngine.score(
        foods: mockFoods,
        profile: mockProfile,
        gap: mockGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: ['chicken'],
      );

      expect(recs.any((r) => r.foodName.toLowerCase().contains('chicken')), isFalse);
    });

    test('Exclusions by Ingredients filters out matching foods', () {
      final recs = RecommendationScoringEngine.score(
        foods: mockFoods,
        profile: mockProfile,
        gap: mockGap,
        currentMealType: 'Lunch',
        pantryItems: const [],
        groceryLists: const [],
        recentLogs: const [],
        favoriteFoods: const [],
        recentFoods: const [],
        chatExclusions: ['paneer'],
      );

      expect(recs.any((r) => r.foodName.toLowerCase().contains('paneer')), isFalse);
    });

    test('Recipe scaling scales macros and ingredients proportionally', () {
      final repo = FoodAssetRepository.instance;
      final recipe = repo.getRecipe('predefined_chicken_tikka');
      expect(recipe, isNotNull);

      final scaledRecipe = repo.getScaledRecipe('predefined_chicken_tikka', 2.0);
      expect(scaledRecipe, isNotNull);
      expect(scaledRecipe!.baseServings, 2.0);

      // Check ingredient scaling
      final baseChicken = recipe!.ingredients.firstWhere((i) => i.name.contains('Chicken'));
      final scaledChicken = scaledRecipe.ingredients.firstWhere((i) => i.name.contains('Chicken'));
      expect(scaledChicken.baseAmount, baseChicken.baseAmount * 2.0);
    });

    test('Database validation flag duplicate food IDs, missing images or recipes', () {
      final repo = FoodAssetRepository.instance;
      final result = repo.validateDatabase(mockFoods);

      expect(result, isNotNull);
      expect(result.containsKey('duplicate_ids'), isTrue);
      expect(result.containsKey('missing_images'), isTrue);
      expect(result.containsKey('missing_nutrition'), isTrue);
    });
  });
}
