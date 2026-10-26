import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/repositories/food_asset_repository.dart';
import 'package:fitfuel/features/food/presentation/screens/food_details_screen.dart';
import 'package:fitfuel/features/food/presentation/widgets/recipe_sections.dart';

void main() {
  group('Phase 35.7.2 — Targeted Food Image & Recipe Verification Tests', () {
    test('1. Oats (Rolled) image and recipe verification', () {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_oats').toEntity();
      
      // Image resolution verification
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1517673400267-0251440c45dc'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Oats (Rolled)');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Rolled Oats')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('saucepan')), isTrue);
    });

    test('2. Indian Mutton Curry image and recipe verification', () {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_mutton_curry').toEntity();

      // Image resolution verification
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1603894584373-5ac82b2ae398'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Indian Mutton Curry');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Mutton Pieces')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('pressure cooker')), isTrue);
    });

    test('3. Canned Tuna (In Water) image and recipe verification', () {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_canned_tuna').toEntity();

      // Image resolution verification
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1501595091296-3aa970afb3ff'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Canned Tuna (In Water)');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Tuna')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('tuna')), isTrue);
    });

    test('4. Double Chocolate Protein Bar image and recipe verification', () {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_protein_bar').toEntity();

      // Image resolution verification
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1622484216802-0e5f5f4b5242'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Double Chocolate Protein Bar');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Protein Bar')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('microwave') || s.contains('Unwrap')), isTrue);
    });

    test('5. Whey Protein Shake image and recipe verification', () {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_whey_protein_shake').toEntity();

      // Image resolution verification
      final image = FoodImageResolver.resolve(food);
      expect(image, isNotEmpty);
      expect(image.startsWith('https://'), isTrue);
      expect(image.contains('photo-1579722821273-0f6c7d44362f'), isTrue);

      // Recipe verification
      final recipe = FoodAssetRepository.instance.getRecipe(food.id);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Whey Protein Shake');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.ingredients.any((i) => i.name.contains('Protein Powder')), isTrue);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.any((s) => s.contains('shaker')), isTrue);
    });

    testWidgets('6. RecipeSections widget renders ingredients & instructions for all 5 foods', (tester) async {
      final foodIds = [
        'predefined_oats',
        'predefined_mutton_curry',
        'predefined_canned_tuna',
        'predefined_protein_bar',
        'predefined_whey_protein_shake',
      ];

      for (final foodId in foodIds) {
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

        // Verify Recipe header and section titles appear
        expect(find.text('Recipe'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(find.text('Ingredients'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(find.text('Method'), findsOneWidget, reason: 'Failed on food $foodId');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('7. FoodDetailsScreen renders cleanly with recipe section for Oats (Rolled)', (tester) async {
      final food = PredefinedFoodData.foods.firstWhere((f) => f.id == 'predefined_oats').toEntity();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: FoodDetailsScreen(food: food, showRecipe: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oats (Rolled)'), findsOneWidget);
      expect(find.text('Recipe'), findsOneWidget);
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
