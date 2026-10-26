import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/repositories/food_asset_repository.dart';
import 'package:fitfuel/features/food/presentation/screens/food_details_screen.dart';
import 'package:fitfuel/features/food/presentation/widgets/recipe_sections.dart';

void main() {
  group('Phase 35.7.3 — Targeted Food Image & Recipe Verification Tests', () {
    // ------------------------------------------------------------------------
    // 1. Egg White Omelette
    // ------------------------------------------------------------------------
    test('1. Egg White Omelette image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_egg_white_omelette')
          .toEntity();

      // Nutrition integrity
      expect(food.calories, 90.0);
      expect(food.protein, 18.0);
      expect(food.carbohydrates, 1.5);
      expect(food.fats, 1.2);

      // Image resolution
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1786213591036-96b02dbff18e'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Egg White Omelette');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Egg Whites')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('whisk') || s.contains('skillet')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 2. Low-Fat Paneer
    // ------------------------------------------------------------------------
    test('2. Low-Fat Paneer image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_low_fat_paneer')
          .toEntity();

      // Nutrition integrity
      expect(food.calories, 160.0);
      expect(food.protein, 20.0);
      expect(food.carbohydrates, 2.0);
      expect(food.fats, 8.0);

      // Image resolution: Clean branded fallback (empty string) to prevent Tikka/Curry misrepresentation
      final image = FoodImageResolver.resolve(food);
      expect(image, isEmpty);

      // Recipe verification: Sensible preparation/serving recipe
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Low-Fat Paneer');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Low-Fat Paneer Block')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('cubes') || s.contains('Sear')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 3. Healthy Chicken Salad
    // ------------------------------------------------------------------------
    test('3. Healthy Chicken Salad image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_chicken_salad')
          .toEntity();

      // Nutrition integrity
      expect(food.calories, 220.0);
      expect(food.protein, 26.0);
      expect(food.carbohydrates, 6.0);
      expect(food.fats, 10.0);

      // Image resolution
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1781332149415-f420708ab98f'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Healthy Chicken Salad');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Chicken Breast')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('Grill') || s.contains('salad')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 4. Couscous (Dry)
    // ------------------------------------------------------------------------
    test('4. Couscous (Dry) image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_couscous')
          .toEntity();

      // Nutrition integrity: Remains dry uncooked couscous
      expect(food.calories, 376.0);
      expect(food.protein, 12.8);
      expect(food.carbohydrates, 77.0);
      expect(food.fats, 0.6);

      // Image resolution: Clean branded fallback (empty string) to prevent cooked salad misrepresentation
      final image = FoodImageResolver.resolve(food);
      expect(image, isEmpty);

      // Recipe verification: Basic dry couscous preparation guide
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Couscous (Dry)');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Dry Couscous Grains')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('boiling') || s.contains('fluff')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 5. Banana Protein Smoothie
    // ------------------------------------------------------------------------
    test('5. Banana Protein Smoothie image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_protein_smoothie')
          .toEntity();

      // Nutrition integrity
      expect(food.calories, 220.0);
      expect(food.protein, 21.0);
      expect(food.carbohydrates, 28.0);
      expect(food.fats, 2.8);

      // Image resolution
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1707219811295-0f283760668b'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Banana Protein Smoothie');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Banana')), isTrue);
      expect(recipe.ingredients.any((i) => i.name.contains('Protein Powder')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('Blend') || s.contains('blender')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 6. Oats Bran
    // ------------------------------------------------------------------------
    test('6. Oats Bran image and recipe verification', () {
      final food = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_oats_bran')
          .toEntity();

      // Nutrition integrity: Remains raw grain/ingredient
      expect(food.calories, 246.0);
      expect(food.protein, 17.3);
      expect(food.carbohydrates, 66.0);
      expect(food.fats, 7.0);
      expect(food.fiber, 15.4);

      // Image resolution: Clean branded fallback (empty string) to prevent rolled oats confusion
      final image = FoodImageResolver.resolve(food);
      expect(image, isEmpty);

      // Recipe verification: Basic oat bran cereal preparation guide
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Oats Bran');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Raw Oat Bran')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('simmer') || s.contains('saucepan')), isTrue);
    });

    // ------------------------------------------------------------------------
    // 7. Widget Tests: RecipeSections renders without empty state for all 6 foods
    // ------------------------------------------------------------------------
    testWidgets('7. RecipeSections widget renders ingredients & instructions for all 6 foods', (tester) async {
      final targetFoodIds = [
        'predefined_egg_white_omelette',
        'predefined_low_fat_paneer',
        'predefined_chicken_salad',
        'predefined_couscous',
        'predefined_protein_smoothie',
        'predefined_oats_bran',
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
    // 8. Widget Tests: FoodDetailsScreen with showRecipe=true renders cleanly
    // ------------------------------------------------------------------------
    testWidgets('8. FoodDetailsScreen renders cleanly with recipe section for all 6 target foods', (tester) async {
      final targetFoodIds = [
        'predefined_egg_white_omelette',
        'predefined_low_fat_paneer',
        'predefined_chicken_salad',
        'predefined_couscous',
        'predefined_protein_smoothie',
        'predefined_oats_bran',
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
    // 9. Regression Tests: Phase 35.7.2 Foods Still Pass
    // ------------------------------------------------------------------------
    test('9. Phase 35.7.2 regression check for 5 previously fixed foods', () {
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
  });
}
