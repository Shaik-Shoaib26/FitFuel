import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_recommendation_engine.dart';

void main() {
  group('Food Recommendation Engine Tests', () {
    final listFoods = [
      const FoodEntity(
        id: 'r_chicken',
        name: 'Grilled Chicken Breast',
        category: 'Protein',
        servingSize: 100,
        servingUnit: 'g',
        calories: 165,
        protein: 31,
        carbohydrates: 0,
        fats: 3.6,
        fiber: 0,
        sugar: 0,
        sodium: 74,
      ),
      const FoodEntity(
        id: 'r_apple',
        name: 'Red Apple',
        category: 'Fruits',
        servingSize: 100,
        servingUnit: 'g',
        calories: 52,
        protein: 0.3,
        carbohydrates: 14,
        fats: 0.2,
        fiber: 2.4,
        sugar: 10,
        sodium: 1,
      ),
      const FoodEntity(
        id: 'r_oats',
        name: 'Oats Cooked',
        category: 'Breakfast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 68,
        protein: 2.4,
        carbohydrates: 12,
        fats: 1.4,
        fiber: 1.7,
        sugar: 0.2,
        sodium: 2,
      ),
      const FoodEntity(
        id: 'r_yogurt',
        name: 'Greek Yogurt',
        category: 'Dairy',
        servingSize: 100,
        servingUnit: 'g',
        calories: 59,
        protein: 10,
        carbohydrates: 3.6,
        fats: 0.4,
        fiber: 0,
        sugar: 3.2,
        sodium: 36,
      ),
    ];

    test('High-protein ranking', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Lunch',
        remainingCalories: 1000,
        proteinDeficit: 50,
        dietaryPreference: 'none',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      expect(recs.first.id, 'r_chicken'); // Highest protein density
    });

    test('Low-calorie ranking', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Snack',
        remainingCalories: 100,
        proteinDeficit: 0,
        dietaryPreference: 'none',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      // Apple is lowest calories snack
      expect(recs.first.id, 'r_apple');
    });

    test('Dietary preference filtering', () {
      // Vegetarian
      final vegRecs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Lunch',
        remainingCalories: 1000,
        proteinDeficit: 30,
        dietaryPreference: 'vegetarian',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      expect(vegRecs.any((f) => f.id == 'r_chicken'), isFalse);
      expect(vegRecs.any((f) => f.id == 'r_yogurt'), isTrue);

      // Vegan
      final veganRecs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Lunch',
        remainingCalories: 1000,
        proteinDeficit: 10,
        dietaryPreference: 'vegan',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      expect(veganRecs.any((f) => f.id == 'r_chicken'), isFalse);
      expect(veganRecs.any((f) => f.id == 'r_yogurt'), isFalse);
      expect(veganRecs.any((f) => f.id == 'r_apple'), isTrue);
    });

    test('Excluded food filtering', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Lunch',
        remainingCalories: 1000,
        proteinDeficit: 40,
        dietaryPreference: 'none',
        excludedFoodNames: ['chicken'],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      expect(recs.any((f) => f.id == 'r_chicken'), isFalse);
    });

    test('Meal category filtering', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Breakfast',
        remainingCalories: 1000,
        proteinDeficit: 0,
        dietaryPreference: 'none',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      // Oats is a Breakfast category food
      expect(recs.first.id, 'r_oats');
    });

    test('Remaining calorie consideration', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: listFoods,
        mealType: 'Lunch',
        remainingCalories: 60, // Very tight budget
        proteinDeficit: 0,
        dietaryPreference: 'none',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );
      // Chicken has 165 calories, so it exceeds remainingCalories (60) and should be penalized/ranked lower
      expect(recs.first.calories <= 60, isTrue);
    });
  });
}
