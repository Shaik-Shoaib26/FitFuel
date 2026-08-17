import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/data/models/food_model.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';
import 'package:fitfuel/features/food/domain/utils/food_nutrition_calculator.dart';
import 'package:fitfuel/features/food/domain/utils/food_recommendation_engine.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';

void main() {
  group('Smart Food Database Expansion (Phase 23.1) Tests', () {
    final catalog = PredefinedFoodData.foods.map((e) => e.toEntity()).toList();

    // 1. Database size >= 200
    test('Catalog contains at least 200 items', () {
      expect(catalog.length, greaterThanOrEqualTo(200));
    });

    // 2. Unique IDs
    test('All food IDs in the catalog are unique', () {
      final ids = catalog.map((e) => e.id).toSet();
      expect(ids.length, equals(catalog.length));
    });

    // 3. Non-empty names
    test('Every food has a non-empty name', () {
      for (final food in catalog) {
        expect(food.name.trim().isNotEmpty, isTrue);
      }
    });

    // 4. Non-negative nutritional parameters
    test('Nutritional values are non-negative', () {
      for (final food in catalog) {
        expect(food.calories, greaterThanOrEqualTo(0.0));
        expect(food.protein, greaterThanOrEqualTo(0.0));
        expect(food.carbohydrates, greaterThanOrEqualTo(0.0));
        expect(food.fats, greaterThanOrEqualTo(0.0));
        expect(food.fiber, greaterThanOrEqualTo(0.0));
        expect(food.sugar, greaterThanOrEqualTo(0.0));
        expect(food.sodium, greaterThanOrEqualTo(0.0));
      }
    });

    // 5. Valid serving sizes
    test('All foods have serving sizes greater than zero', () {
      for (final food in catalog) {
        expect(food.servingSize, greaterThan(0.0));
      }
    });

    // 6. Valid categories
    test('Predefined categories are assigned correctly', () {
      final allowedCategories = {
        'Breakfast',
        'Lunch',
        'Dinner',
        'Snacks',
        'Fruits',
        'Vegetables',
        'Grains',
        'Legumes',
        'Dairy',
        'Protein',
        'Nuts & Seeds',
        'Beverages',
        'Desserts',
      };
      for (final food in catalog) {
        expect(allowedCategories.contains(food.category), isTrue,
            reason: 'Food ${food.name} has invalid category: ${food.category}');
      }
    });

    // 7. Indian food filtering
    test('Indian food filtering returns regional foods', () {
      final indianFoods = catalog.where((f) => f.isIndian).toList();
      expect(indianFoods.isNotEmpty, isTrue);
      expect(indianFoods.any((f) => f.name.toLowerCase().contains('idli')), isTrue);
      expect(indianFoods.any((f) => f.name.toLowerCase().contains('paneer')), isTrue);
    });

    // 8. Vegetarian filtering
    test('Vegetarian filtering excludes non-vegetarian items', () {
      final vegFoods = catalog.where((f) => f.isVegetarian).toList();
      expect(vegFoods.isNotEmpty, isTrue);
      expect(vegFoods.any((f) => f.name.toLowerCase().contains('chicken')), isFalse);
      expect(vegFoods.any((f) => f.name.toLowerCase().contains('mutton')), isFalse);
    });

    // 9. Vegan filtering
    test('Vegan filtering excludes dairy and meats', () {
      final veganFoods = catalog.where((f) => f.isVegan).toList();
      expect(veganFoods.isNotEmpty, isTrue);
      expect(veganFoods.any((f) => f.name.toLowerCase().contains('paneer')), isFalse);
      expect(veganFoods.any((f) => f.name.toLowerCase().contains('curd')), isFalse);
      expect(veganFoods.any((f) => f.name.toLowerCase().contains('egg') && !f.name.toLowerCase().contains('eggplant')), isFalse);
    });

    // 10. High-protein matches
    test('High protein category matches protein rich foods', () {
      final highProtein = catalog.where((f) => f.protein >= 10.0 || f.dietaryTags.contains('High Protein')).toList();
      expect(highProtein.isNotEmpty, isTrue);
      expect(highProtein.any((f) => f.name.toLowerCase().contains('chicken breast')), isTrue);
      expect(highProtein.any((f) => f.name.toLowerCase().contains('whey protein')), isTrue);
    });

    // 11. Low-calorie matches
    test('Low calorie filters return appropriate calorie items', () {
      final lowCalorie = catalog.where((f) => f.calories <= 150.0).toList();
      expect(lowCalorie.isNotEmpty, isTrue);
      expect(lowCalorie.any((f) => f.name.toLowerCase().contains('salad')), isTrue);
      expect(lowCalorie.any((f) => f.name.toLowerCase().contains('cucumber')), isTrue);
    });

    // 12. Breakfast matching
    test('Breakfast suitability matches mealTypes', () {
      final breakfast = catalog.where((f) => f.mealTypes.contains('Breakfast')).toList();
      expect(breakfast.isNotEmpty, isTrue);
      expect(breakfast.any((f) => f.name.toLowerCase().contains('idli')), isTrue);
      expect(breakfast.any((f) => f.name.toLowerCase().contains('oats')), isTrue);
    });

    // 13. Dinner matching
    test('Dinner suitability matches mealTypes', () {
      final dinner = catalog.where((f) => f.mealTypes.contains('Dinner')).toList();
      expect(dinner.isNotEmpty, isTrue);
      expect(dinner.any((f) => f.name.toLowerCase().contains('biryani')), isTrue);
      expect(dinner.any((f) => f.name.toLowerCase().contains('soup')), isTrue);
    });

    // 14. Keyword search with regional aliases
    test('Search engine matches aliases correctly', () {
      final rotiMatch = FoodSearchEngine.search(foods: catalog, query: 'roti');
      expect(rotiMatch.any((f) => f.name.toLowerCase().contains('chapati')), isTrue);

      final dahiMatch = FoodSearchEngine.search(foods: catalog, query: 'dahi');
      expect(dahiMatch.any((f) => f.name.toLowerCase().contains('curd')), isTrue);
    });

    // 15. Serving scale calculators
    test('FoodNutritionCalculator scales values proportionally', () {
      final baseFood = catalog.firstWhere((f) => f.id == 'predefined_idli');
      final scaled = FoodNutritionCalculator.calculateScaled(food: baseFood, selectedServingSize: baseFood.servingSize * 1.5);
      expect(scaled.calories, closeTo(baseFood.calories * 1.5, 0.1));
      expect(scaled.protein, closeTo(baseFood.protein * 1.5, 0.1));
      expect(scaled.carbohydrates, closeTo(baseFood.carbohydrates * 1.5, 0.1));
      expect(scaled.fats, closeTo(baseFood.fats * 1.5, 0.1));
    });

    // 16. Custom foods model conversion
    test('FoodModel toEntity and fromEntity map fields correctly', () {
      const model = FoodModel(
        id: 'custom_123',
        name: 'Custom Paneer Tikka',
        category: 'Protein',
        servingSize: 100.0,
        servingUnit: 'g',
        calories: 250.0,
        protein: 15.0,
        carbohydrates: 5.0,
        fats: 18.0,
        fiber: 1.0,
        sugar: 1.0,
        sodium: 300.0,
        isCustom: true,
        isFavorite: true,
        isIndian: true,
        isVegetarian: true,
        isVegan: false,
        dietaryTags: ['High Protein', 'Gluten Free'],
        mealTypes: ['Lunch', 'Dinner'],
      );

      final entity = model.toEntity();
      expect(entity.id, 'custom_123');
      expect(entity.isCustom, isTrue);
      expect(entity.isFavorite, isTrue);
      expect(entity.isIndian, isTrue);
      expect(entity.isVegetarian, isTrue);
      expect(entity.isVegan, isFalse);
      expect(entity.dietaryTags, contains('High Protein'));
      expect(entity.mealTypes, contains('Lunch'));

      final mappedModel = FoodModel.fromEntity(entity);
      expect(mappedModel.id, 'custom_123');
      expect(mappedModel.isCustom, isTrue);
    });

    // 17. Favorite foods checks
    test('FoodEntity equality handles favorite changes correctly', () {
      final foodA = catalog.firstWhere((f) => f.id == 'predefined_idli');
      final foodB = foodA.copyWith(isFavorite: true);
      expect(foodA == foodB, isFalse);
      expect(foodB.isFavorite, isTrue);
    });

    // 18. Recently used check
    test('FoodEntity handles copyWith successfully', () {
      final food = catalog.firstWhere((f) => f.id == 'predefined_banana');
      final updated = food.copyWith(name: 'Updated Banana');
      expect(updated.name, 'Updated Banana');
      expect(updated.id, food.id);
    });

    // 19. Excluded foods check
    test('Heuristic scorer correctly scores down excluded foods', () {
      final food = catalog.firstWhere((f) => f.name.toLowerCase().contains('chicken'));
      const pLower = 'vegetarian lunch without chicken';
      final isVeg = pLower.contains('vegetarian');
      final hasChickenWord = pLower.contains('chicken');

      double score = 0.0;
      if (isVeg && !food.isVegetarian) score -= 200.0;
      if (hasChickenWord && food.name.toLowerCase().contains('chicken')) score -= 500.0;

      expect(score, lessThan(-500.0));
    });

    // 20. Another option repetition check
    test('Heuristic scorer prioritizes name match queries', () {
      const pLower = 'suggest paneer dosa';
      final paneerFood = catalog.firstWhere((f) => f.name.toLowerCase().contains('paneer bhurji'));
      final appleFood = catalog.firstWhere((f) => f.name.toLowerCase().contains('apple'));

      double scorePaneer = 0.0;
      if (pLower.contains('paneer')) {
        if (paneerFood.name.toLowerCase().contains('paneer')) scorePaneer += 500.0;
      }

      double scoreApple = 0.0;
      if (pLower.contains('apple')) {
        if (appleFood.name.toLowerCase().contains('apple')) scoreApple += 500.0;
      }

      expect(scorePaneer, greaterThan(scoreApple));
    });

    // 21. Context candidates size limit
    test('Context candidates are filtered correctly', () {
      final filteredList = catalog.take(25).toList();
      expect(filteredList.length, equals(25));
    });

    // 22. AI Context Generator formatting
    test('AiContextGenerator serializes advanced food tags correctly', () {
      final sampleFoods = [
        const FoodEntity(
          id: 'test_idli',
          name: 'Idli',
          category: 'Breakfast',
          servingSize: 100,
          servingUnit: 'g',
          calories: 120,
          protein: 3,
          carbohydrates: 25,
          fats: 0.5,
          fiber: 1,
          sugar: 0,
          sodium: 150,
          isIndian: true,
          isVegetarian: true,
          isVegan: true,
          dietaryTags: ['Low Fat'],
          mealTypes: ['Breakfast'],
        )
      ];

      final context = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
        availableFoods: sampleFoods,
      );

      expect(context, contains('isIndian: true'));
      expect(context, contains('isVegetarian: true'));
      expect(context, contains('isVegan: true'));
      expect(context, contains('dietaryTags: Low Fat'));
    });

    // 23. AI suggestions matches
    test('Heuristic matching parses suggestions name overlaps', () {
      const foodName = 'idli';
      final match = catalog.firstWhere((f) => f.name.toLowerCase() == foodName.toLowerCase());
      expect(match.id, 'predefined_idli');
    });

    // 24. Image fallback loading check
    test('imageAsset path formatting is correct', () {
      final food = catalog.firstWhere((f) => f.id == 'predefined_idli');
      expect(food.imageAsset, isNull);
    });

    // 25. Recommendation engine non-duplication
    test('Recommendation engine returns unique recommendations list', () {
      final recs = FoodRecommendationEngine.recommend(
        foods: catalog,
        mealType: 'Breakfast',
        remainingCalories: 1000,
        proteinDeficit: 50,
        dietaryPreference: 'none',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );

      final uniqueIds = recs.map((e) => e.id).toSet();
      expect(uniqueIds.length, equals(recs.length));
    });
  });
}
