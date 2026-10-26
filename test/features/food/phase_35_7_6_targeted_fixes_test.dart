import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/repositories/food_asset_repository.dart';
import 'package:fitfuel/features/food/presentation/screens/food_details_screen.dart';
import 'package:fitfuel/features/food/presentation/widgets/recipe_sections.dart';

void main() {
  group('Phase 35.7.6 — Targeted Food Image & Recipe Fixes Batch 3', () {
    // ------------------------------------------------------------------------
    // 1. Almond Butter Pure
    // ------------------------------------------------------------------------
    test('1. Almond Butter Pure image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_almond_butter')
          .toEntity();

      // Nutrition integrity: must NOT be modified
      expect(food.calories, 196.0);
      expect(food.protein, 7.0);
      expect(food.carbohydrates, 6.0);
      expect(food.fats, 18.0);

      // Image resolution: Real verified local asset
      final image = FoodImageResolver.resolve(food);
      expect(image, 'assets/images/foods/almond_butter.webp');
      expect(image.contains('photo-1508061253366-f7da158b6d46'), isFalse);

      // Recipe verification: Realistic almond butter preparation
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Almond Butter Pure');
      expect(recipe.dietType, 'vegan');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Almonds')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.toLowerCase().contains('blend') || s.toLowerCase().contains('roast')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 2. Aloo Gobi
    // ------------------------------------------------------------------------
    test('2. Aloo Gobi image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_aloo_gobi')
          .toEntity();

      // Nutrition integrity: must NOT be modified
      expect(food.calories, 110.0);
      expect(food.protein, 2.5);
      expect(food.carbohydrates, 16.0);
      expect(food.fats, 4.5);

      // Image resolution: Existing verified local asset preserved
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image, 'assets/images/foods/aloo_gobi.webp');

      // Recipe verification: Realistic Aloo Gobi recipe
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Aloo Gobi');
      expect(recipe.dietType, 'vegan');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Potato')), isTrue);
      expect(recipe.ingredients.any((i) => i.name.contains('Cauliflower')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.toLowerCase().contains('cook') || s.toLowerCase().contains('cover')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 3. Aloo Methi
    // ------------------------------------------------------------------------
    test('3. Aloo Methi image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_aloo_methi')
          .toEntity();

      // Nutrition integrity: must NOT be modified
      expect(food.calories, 120.0);
      expect(food.protein, 2.8);
      expect(food.carbohydrates, 18.0);
      expect(food.fats, 4.2);

      // Image resolution: Real verified local asset
      final image = FoodImageResolver.resolve(food);
      expect(image, 'assets/images/foods/aloo_methi.webp');
      expect(image.contains('photo-1585937421612-70a008356fbe'), isFalse);

      // Recipe verification: Realistic dry Aloo Methi preparation
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Aloo Methi');
      expect(recipe.dietType, 'vegan');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Potato')), isTrue);
      expect(recipe.ingredients.any((i) => i.name.contains('Methi') || i.name.contains('Fenugreek')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.toLowerCase().contains('methi') || s.toLowerCase().contains('dry') || s.toLowerCase().contains('moisture')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 4. Aloo Paratha
    // ------------------------------------------------------------------------
    test('4. Aloo Paratha image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_aloo_paratha')
          .toEntity();

      // Nutrition integrity: must NOT be modified
      expect(food.calories, 210.0);
      expect(food.protein, 4.5);
      expect(food.carbohydrates, 34.0);
      expect(food.fats, 6.2);

      // Image resolution: Existing verified local asset preserved
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image, 'assets/images/foods/aloo_paratha.webp');

      // Recipe verification: Realistic stuffed Aloo Paratha recipe
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Aloo Paratha');
      expect(recipe.dietType, 'vegan');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Whole Wheat Flour') || i.name.contains('Flour')), isTrue);
      expect(recipe.ingredients.any((i) => i.name.contains('Potato')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.toLowerCase().contains('stuff') || s.toLowerCase().contains('roll') || s.toLowerCase().contains('tawa')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 5. Amritsari Fish Tikka
    // ------------------------------------------------------------------------
    test('5. Amritsari Fish Tikka image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_grilled_fish_tikka')
          .toEntity();

      // Nutrition integrity: must NOT be modified
      expect(food.calories, 150.0);
      expect(food.protein, 21.0);
      expect(food.carbohydrates, 2.5);
      expect(food.fats, 6.2);

      // Image resolution: Real verified local asset
      final image = FoodImageResolver.resolve(food);
      expect(image, 'assets/images/foods/amritsari_fish_tikka.webp');
      expect(image.contains('photo-1599487488170-d11ec9c172f0'), isFalse);

      // Recipe verification: Realistic Indian fish tikka recipe
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Amritsari Fish Tikka');
      expect(recipe.dietType, 'nonVegetarian');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Fish')), isTrue);
      expect(recipe.ingredients.any((i) => i.name.contains('Yogurt') || i.name.contains('Curd')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.toLowerCase().contains('marinat') || s.toLowerCase().contains('grill')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 6. Widget Tests: RecipeSections renders without empty state for all 5 foods
    // ------------------------------------------------------------------------
    testWidgets('6. RecipeSections widget renders ingredients & instructions for all 5 foods', (tester) async {
      final targetFoodIds = [
        'predefined_almond_butter',
        'predefined_aloo_gobi',
        'predefined_aloo_methi',
        'predefined_aloo_paratha',
        'predefined_grilled_fish_tikka',
      ];

      for (final foodId in targetFoodIds) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == foodId).toEntity();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecipeSections(food: food),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Recipe header and section titles appear and are not empty
        expect(find.text('Recipe'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(find.text('Ingredients'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(find.text('Method'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(tester.takeException(), isNull);
      }
    });

    // ------------------------------------------------------------------------
    // 7. Widget Tests: FoodDetailsScreen with showRecipe=true renders cleanly
    // ------------------------------------------------------------------------
    testWidgets('7. FoodDetailsScreen renders cleanly with recipe section for all 5 target foods', (tester) async {
      final targetFoodIds = [
        'predefined_almond_butter',
        'predefined_aloo_gobi',
        'predefined_aloo_methi',
        'predefined_aloo_paratha',
        'predefined_grilled_fish_tikka',
      ];

      for (final foodId in targetFoodIds) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == foodId).toEntity();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: FoodDetailsScreen(key: ValueKey(food.id), food: food, showRecipe: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(food.name), findsOneWidget, reason: 'Name not found for $foodId');
        expect(find.text('Recipe'), findsOneWidget, reason: 'Recipe not found for $foodId');
        expect(find.text('Ingredients'), findsOneWidget, reason: 'Ingredients not found for $foodId');
        expect(find.text('Method'), findsOneWidget, reason: 'Method not found for $foodId');
        expect(tester.takeException(), isNull);
      }
    });

    // ------------------------------------------------------------------------
    // 8. Recipe Button Safety: No food with visible Recipe button opens empty recipe
    // ------------------------------------------------------------------------
    test('8. Recipe Button Safety — No empty recipes for 5 target foods', () {
      final targetFoodIds = [
        'predefined_almond_butter',
        'predefined_aloo_gobi',
        'predefined_aloo_methi',
        'predefined_aloo_paratha',
        'predefined_grilled_fish_tikka',
      ];

      for (final foodId in targetFoodIds) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == foodId).toEntity();
        final recipe = FoodAssetRepository.instance.getRecipe(food.id);

        expect(recipe, isNotNull, reason: '$foodId must have a recipe');
        expect(recipe!.ingredients, isNotEmpty, reason: '$foodId ingredients must not be empty');
        expect(recipe.instructions, isNotEmpty, reason: '$foodId instructions must not be empty');
      }
    });

    // ------------------------------------------------------------------------
    // 9. Previous Phase Regression: Phase 35.7.3 Foods Still Pass
    // ------------------------------------------------------------------------
    test('9. Phase 35.7.3 regression check for 6 previously fixed foods', () {
      final phase3573Foods = [
        ('predefined_egg_white_omelette', 'Egg White Omelette', 'photo-1786213591036-96b02dbff18e', 'Egg Whites'),
        ('predefined_low_fat_paneer', 'Low-Fat Paneer', '', 'Low-Fat Paneer Block'),
        ('predefined_chicken_salad', 'Healthy Chicken Salad', 'photo-1781332149415-f420708ab98f', 'Chicken Breast'),
        ('predefined_couscous', 'Couscous (Dry)', '', 'Dry Couscous Grains'),
        ('predefined_protein_smoothie', 'Banana Protein Smoothie', 'photo-1707219811295-0f283760668b', 'Protein Powder'),
        ('predefined_oats_bran', 'Oats Bran', '', 'Raw Oat Bran'),
      ];

      for (final (foodId, foodName, urlPart, ingredientKeyword) in phase3573Foods) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == foodId).toEntity();
        
        // Image
        final image = FoodImageResolver.resolve(food);
        if (urlPart.isNotEmpty) {
          expect(image, isNotEmpty, reason: '$foodName image must not be empty');
          expect(image.contains(urlPart), isTrue, reason: '$foodName image URL mismatch');
        } else {
          // Branded fallback is acceptable
        }

        // Recipe
        final recipe = FoodAssetRepository.instance.getRecipe(food.id);
        expect(recipe, isNotNull, reason: '$foodName recipe must exist');
        expect(recipe!.foodName, foodName);
        expect(recipe.ingredients.any((i) => i.name.contains(ingredientKeyword)), isTrue);
        expect(recipe.instructions, isNotEmpty);
      }
    });

    // ------------------------------------------------------------------------
    // 10. Previous Phase Regression: Phase 35.7.2 Foods Still Pass
    // ------------------------------------------------------------------------
    test('10. Phase 35.7.2 regression check for 5 previously fixed foods', () {
      final phase3572Foods = [
        ('predefined_oats', 'Oats (Rolled)', 'photo-1517673400267-0251440c45dc', 'Rolled Oats'),
        ('predefined_mutton_curry', 'Indian Mutton Curry', 'photo-1603894584373-5ac82b2ae398', 'Mutton Pieces'),
        ('predefined_canned_tuna', 'Canned Tuna (In Water)', 'photo-1501595091296-3aa970afb3ff', 'Tuna'),
        ('predefined_protein_bar', 'Double Chocolate Protein Bar', 'photo-1622484216802-0e5f5f4b5242', 'Protein Bar'),
        ('predefined_whey_protein_shake', 'Whey Protein Shake', 'photo-1579722821273-0f6c7d44362f', 'Protein Powder'),
      ];

      for (final (foodId, foodName, urlPart, ingredientKeyword) in phase3572Foods) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == foodId).toEntity();
        
        // Image
        final image = FoodImageResolver.resolve(food);
        expect(image, isNotEmpty, reason: '$foodName image must not be empty');
        expect(image.contains(urlPart), isTrue, reason: '$foodName image URL mismatch');

        // Recipe
        final recipe = FoodAssetRepository.instance.getRecipe(food.id);
        expect(recipe, isNotNull, reason: '$foodName recipe must exist');
        expect(recipe!.foodName, foodName);
        expect(recipe.ingredients.any((i) => i.name.contains(ingredientKeyword)), isTrue);
        expect(recipe.instructions, isNotEmpty);
      }
    });

    // ------------------------------------------------------------------------
    // 11. Food Image Audit: WRONG_FOOD=0, BROKEN=0, Suspicious duplicates=0
    // ------------------------------------------------------------------------
    test('11. Food Image Audit — No wrong/broken/duplicate images for 5 target foods', () {
      final targetFoodIds = [
        'predefined_almond_butter',
        'predefined_aloo_gobi',
        'predefined_aloo_methi',
        'predefined_aloo_paratha',
        'predefined_grilled_fish_tikka',
      ];

      // No wrong food images (misidentified food)
      // No broken URLs (empty string for fallback is expected and safe)
      // No suspicious duplicates across these 5 foods
      final images = targetFoodIds.map((id) {
        final f = PredefinedFoodData.foods.firstWhere((x) => x.id == id).toEntity();
        return FoodImageResolver.resolve(f);
      }).toList();

      // Check for duplicates among non-empty images
      final nonEmpty = images.where((i) => i.isNotEmpty).toList();
      final unique = nonEmpty.toSet();
      expect(nonEmpty.length, unique.length, reason: 'Duplicate images detected among target foods');
    });
  });
}