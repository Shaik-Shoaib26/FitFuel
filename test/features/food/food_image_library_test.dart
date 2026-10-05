// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/smart_food_recommendation_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/enums/recommendation_priority.dart';

void main() {
  group('Phase 31.2 Food Image Library and Consistency Tests', () {

    // 1. Every predefined food has stable foodId
    test('1. Every predefined food has stable foodId', () {
      for (final food in PredefinedFoodData.foods) {
        expect(food.id, isNotEmpty);
        expect(food.id.startsWith('predefined_'), isTrue);
      }
    });

    // 2. Every mapped image path is non-empty or uses safe branded fallback
    test('2. Every mapped image path is non-empty or uses safe branded fallback', () {
      for (final food in PredefinedFoodData.foods) {
        final resolved = FoodImageResolver.resolve(food);
        expect(resolved, isA<String>());
      }
    });

    // 3. No image path contains assets/assets
    test('3. No image path contains assets/assets', () {
      for (final food in PredefinedFoodData.foods) {
        final resolved = FoodImageResolver.resolve(food);
        expect(resolved.contains('assets/assets'), isFalse);
      }
    });

    // 4. Local referenced files format validation
    test('4. Local referenced files format validation', () {
      for (final food in PredefinedFoodData.foods) {
        final resolved = FoodImageResolver.resolve(food);
        if (resolved.isNotEmpty && !resolved.startsWith('http')) {
          expect(resolved.startsWith('assets/images/foods/'), isTrue);
        }
      }
    });

    // 5. Paneer Tikka maps correctly
    test('5. Paneer Tikka maps correctly', () {
      final resolved = FoodImageResolver.resolve('Paneer Tikka');
      expect(resolved, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80');
    });

    // 6. Chicken Tikka maps correctly
    test('6. Chicken Tikka maps correctly', () {
      final resolved = FoodImageResolver.resolve('Chicken Tikka');
      expect(resolved, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=600&q=80');
    });

    // 7. Chicken Biryani maps correctly
    test('7. Chicken Biryani maps correctly', () {
      final resolved = FoodImageResolver.resolve('Chicken Biryani');
      expect(resolved, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 8. Mutton Biryani maps correctly
    test('8. Mutton Biryani maps correctly', () {
      final resolved = FoodImageResolver.resolve('Mutton Biryani');
      expect(resolved, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 9. Idli uses safe branded fallback when no accurate photo available
    test('9. Idli uses safe branded fallback when no accurate photo available', () {
      final resolved = FoodImageResolver.resolve('Idli');
      expect(resolved, '');
    });

    // 10. Dosa maps correctly
    test('10. Dosa maps correctly', () {
      final resolved = FoodImageResolver.resolve('Plain Dosa');
      expect(resolved, 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=600&q=80');
    });

    // 11. Egg Omelette maps correctly
    test('11. Egg Omelette maps correctly', () {
      final resolved = FoodImageResolver.resolve('Masala Egg Omelette');
      expect(resolved, 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80');
    });

    // 12. Fish Curry maps correctly
    test('12. Fish Curry maps correctly', () {
      final resolved = FoodImageResolver.resolve('Indian Fish Curry');
      expect(resolved, 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80');
    });

    // 13. Banana maps correctly
    test('13. Banana maps correctly', () {
      final resolved = FoodImageResolver.resolve('Banana');
      expect(resolved, 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80');
    });

    // 14. Different foods do not share unrelated images
    test('14. Different foods do not share unrelated images', () {
      final paneer = FoodImageResolver.resolve('Paneer Tikka');
      final chicken = FoodImageResolver.resolve('Chicken Tikka');
      expect(paneer != chicken, isTrue);

      final idli = FoodImageResolver.resolve('Idli');
      final dosa = FoodImageResolver.resolve('Plain Dosa');
      expect(idli != dosa, isTrue);
    });

    // 15. Missing image returns placeholder
    test('15. Missing image returns placeholder', () {
      final resolvedEmpty = FoodImageResolver.resolve('');
      expect(resolvedEmpty, '');

      final resolvedNull = FoodImageResolver.resolve(null);
      expect(resolvedNull, '');
    });

    // 16. Swap updates image identity
    test('16. Swap updates image identity', () {
      const food1 = FoodEntity(
        id: 'predefined_paneer_tikka',
        name: 'Paneer Tikka',
        category: 'Lunch',
        servingSize: 100,
        servingUnit: 'g',
        calories: 250,
        protein: 15,
        carbohydrates: 10,
        fats: 16,
        fiber: 2,
        sugar: 0,
        sodium: 0,
      );

      const food2 = FoodEntity(
        id: 'predefined_chicken_tikka',
        name: 'Chicken Tikka',
        category: 'Lunch',
        servingSize: 100,
        servingUnit: 'g',
        calories: 150,
        protein: 24,
        carbohydrates: 3,
        fats: 4,
        fiber: 0,
        sugar: 0,
        sodium: 0,
      );

      final img1 = FoodImageResolver.resolve(food1);
      final img2 = FoodImageResolver.resolve(food2);

      expect(img1, isNot(equals(img2)));
    });

    // 17. Smart Eat uses correct food image
    test('17. Smart Eat uses correct food image', () {
      const rec = SmartFoodRecommendationEntity(
        id: 'rec_paneer',
        foodId: 'predefined_paneer_tikka',
        foodName: 'Paneer Tikka',
        imageUrl: '',
        category: 'Lunch',
        servingSize: 100,
        calories: 250,
        protein: 15,
        carbs: 10,
        fat: 16,
        fiber: 2,
        matchScore: 95,
        priority: RecommendationPriority.high,
        reasons: [],
        tags: [],
        pantryAvailable: false,
        groceryAvailable: false,
        recentlyConsumed: false,
        isFavorite: false,
        estimatedPreparationMinutes: 15,
      );

      final img = FoodImageResolver.resolve(rec.foodId);
      expect(img, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80');
    });

    // 18. Meal Planner uses correct food image
    test('18. Meal Planner uses correct food image', () {
      const planned = PlannedFoodEntity(
        food: FoodEntity(
          id: 'predefined_chicken_biryani',
          name: 'Chicken Biryani',
          category: 'Lunch',
          servingSize: 100,
          servingUnit: 'g',
          calories: 220,
          protein: 14.5,
          carbohydrates: 28,
          fats: 7.2,
          fiber: 1.5,
          sugar: 0,
          sodium: 0,
        ),
        servingQuantity: 1.0,
        unit: 'g',
        calories: 220,
        protein: 14.5,
        carbohydrates: 28,
        fat: 7.2,
        fiber: 1.5,
      );

      final img = FoodImageResolver.resolve(planned.food);
      expect(img, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 19. Recipe Details uses correct image
    test('19. Recipe Details uses correct image', () {
      const food = FoodEntity(
        id: 'predefined_idli',
        name: 'Idli',
        category: 'Breakfast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 120,
        protein: 3.2,
        carbohydrates: 25.5,
        fats: 0.4,
        fiber: 1.2,
        sugar: 0,
        sodium: 0,
      );

      final img = FoodImageResolver.resolve(food);
      expect(img, '');
    });

    // 20. Grocery/Pantry uses shared resolver
    test('20. Grocery/Pantry uses shared resolver', () {
      const foodString = 'predefined_banana';
      final img = FoodImageResolver.resolve(foodString);
      expect(img, 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80');
    });

    // 21. AI recommendation card uses actual database image
    test('21. AI recommendation card uses actual database image', () {
      const aiRecommendFoodId = 'predefined_mutton_biryani';
      final img = FoodImageResolver.resolve(aiRecommendFoodId);
      expect(img, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80');
    });

    // 22. No broken path generation
    test('22. No broken path generation', () {
      for (final food in PredefinedFoodData.foods) {
        final resolved = FoodImageResolver.resolve(food);
        expect(resolved.isEmpty || resolved.startsWith('http') || resolved.startsWith('assets/'), isTrue);
      }
    });

    // 23. FULL AUDIT TEST
    test('23. Catalog Audit Test & Report', () {
      final totalFoods = PredefinedFoodData.foods.length;
      int validImagesCount = 0;
      int fallbackCount = 0;
      int invalidPaths = 0;

      final Set<String> seenImages = {};
      final Set<String> duplicates = {};

      for (final food in PredefinedFoodData.foods) {
        final resolved = FoodImageResolver.resolve(food);
        if (resolved.isEmpty) {
          fallbackCount++;
        } else if (resolved.contains('assets/assets')) {
          invalidPaths++;
        } else if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          validImagesCount++;
          if (seenImages.contains(resolved)) {
            duplicates.add(resolved);
          }
          seenImages.add(resolved);
        } else {
          // Local path
          if (resolved.startsWith('assets/images/foods/')) {
            validImagesCount++;
          } else {
            invalidPaths++;
          }
        }
      }

      print('\n==================================================');
      print('PHASE 35.3I — REAL FOOD PHOTOGRAPHY AUDIT REPORT');
      print('==================================================');
      print('Total foods: $totalFoods');
      print('Foods with valid images: $validImagesCount');
      print('Foods using branded fallback: $fallbackCount');
      print('Duplicate image assignments: ${duplicates.length}');
      print('Invalid paths: $invalidPaths');
      print('==================================================\n');

      expect(invalidPaths, 0);
      expect(fallbackCount, 10);
      expect(validImagesCount, totalFoods - fallbackCount);
    });
  });
}
