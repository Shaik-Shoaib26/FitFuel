import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_photo.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/food_image_manifest.dart';
import 'package:fitfuel/features/food/data/repositories/food_asset_repository.dart';

void main() {
  group('Phase 35.7.7 — Three-Food Real Image Fix & Verification Test', () {
    const rejectedAlmondButterUrl = 'photo-1508061253366-f7da158b6d46';
    const rejectedAlooMethiUrl = 'photo-1585937421612-70a008356fbe';
    const rejectedFishTikkaUrl = 'photo-1599487488170-d11ec9c172f0';

    late Map<String, dynamic> sourcesJson;

    setUpAll(() {
      final file = File('assets/data/food_image_sources.json');
      expect(file.existsSync(), isTrue, reason: 'food_image_sources.json must exist');
      final content = file.readAsStringSync();
      sourcesJson = jsonDecode(content) as Map<String, dynamic>;

      // Ensure local asset files exist and are non-empty
      final abFile = File('assets/images/foods/almond_butter.webp');
      expect(abFile.existsSync(), isTrue, reason: 'almond_butter.webp must physically exist');
      expect(abFile.lengthSync(), greaterThan(1000));

      final amFile = File('assets/images/foods/aloo_methi.webp');
      expect(amFile.existsSync(), isTrue, reason: 'aloo_methi.webp must physically exist');
      expect(amFile.lengthSync(), greaterThan(1000));

      final ftFile = File('assets/images/foods/amritsari_fish_tikka.webp');
      expect(ftFile.existsSync(), isTrue, reason: 'amritsari_fish_tikka.webp must physically exist');
      expect(ftFile.lengthSync(), greaterThan(1000));
    });

    // -------------------------------------------------------------------------
    // 1. Almond Butter Pure
    // -------------------------------------------------------------------------
    test('1. Almond Butter Pure - Production ID, real asset resolver, metadata, URL rejection', () {
      const foodId = 'predefined_almond_butter';
      final food = PredefinedFoodData.foods.firstWhere(
        (f) => f.id == foodId,
        orElse: () => throw StateError('Food $foodId not found in catalog'),
      );
      final entity = food.toEntity();

      // Nutrition integrity
      expect(entity.calories, 196.0);
      expect(entity.protein, 7.0);
      expect(entity.carbohydrates, 6.0);
      expect(entity.fats, 18.0);

      // Manifest existence & mapping safety
      final manifestEntry = FoodImageManifest.manifest[foodId];
      expect(manifestEntry, isNotNull);
      expect(manifestEntry!.imagePathOrUrl, 'assets/images/foods/almond_butter.webp');
      expect(manifestEntry.imagePathOrUrl.contains(rejectedAlmondButterUrl), isFalse);

      // Resolver: Must resolve to real local asset, NOT empty string fallback
      final resolved = FoodImageResolver.resolve(entity);
      expect(resolved, 'assets/images/foods/almond_butter.webp');
      expect(resolved, isNotEmpty);
      expect(resolved.contains(rejectedAlmondButterUrl), isFalse);

      // Also resolve by string name
      expect(FoodImageResolver.resolve('Almond Butter Pure'), 'assets/images/foods/almond_butter.webp');

      // Source metadata
      expect(sourcesJson.containsKey(foodId), isTrue);
      final meta = sourcesJson[foodId] as Map<String, dynamic>;
      expect(meta['source'], 'Wikimedia Commons');
      expect(meta['license'], 'CC BY 2.0');

      // Recipe remains intact
      final recipe = FoodAssetRepository.instance.getRecipe(foodId);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Almond Butter Pure');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.instructions, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 2. Aloo Methi
    // -------------------------------------------------------------------------
    test('2. Aloo Methi - Production ID, real asset resolver, metadata, URL rejection', () {
      const foodId = 'predefined_aloo_methi';
      final food = PredefinedFoodData.foods.firstWhere(
        (f) => f.id == foodId,
        orElse: () => throw StateError('Food $foodId not found in catalog'),
      );
      final entity = food.toEntity();

      // Nutrition integrity
      expect(entity.calories, 120.0);
      expect(entity.protein, 2.8);
      expect(entity.carbohydrates, 18.0);
      expect(entity.fats, 4.2);

      // Manifest existence & mapping safety
      final manifestEntry = FoodImageManifest.manifest[foodId];
      expect(manifestEntry, isNotNull);
      expect(manifestEntry!.imagePathOrUrl, 'assets/images/foods/aloo_methi.webp');
      expect(manifestEntry.imagePathOrUrl.contains(rejectedAlooMethiUrl), isFalse);

      // Resolver: Must resolve to real local asset, NOT empty string fallback
      final resolved = FoodImageResolver.resolve(entity);
      expect(resolved, 'assets/images/foods/aloo_methi.webp');
      expect(resolved, isNotEmpty);
      expect(resolved.contains(rejectedAlooMethiUrl), isFalse);

      // Also resolve by string name
      expect(FoodImageResolver.resolve('Aloo Methi'), 'assets/images/foods/aloo_methi.webp');

      // Source metadata
      expect(sourcesJson.containsKey(foodId), isTrue);
      final meta = sourcesJson[foodId] as Map<String, dynamic>;
      expect(meta['source'], 'Wikimedia Commons');
      expect(meta['license'], 'CC BY 2.0');

      // Recipe remains intact
      final recipe = FoodAssetRepository.instance.getRecipe(foodId);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Aloo Methi');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.instructions, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 3. Amritsari Fish Tikka
    // -------------------------------------------------------------------------
    test('3. Amritsari Fish Tikka - Production ID, real asset resolver, metadata, URL rejection', () {
      const foodId = 'predefined_grilled_fish_tikka';
      final food = PredefinedFoodData.foods.firstWhere(
        (f) => f.id == foodId,
        orElse: () => throw StateError('Food $foodId not found in catalog'),
      );
      final entity = food.toEntity();

      // Nutrition integrity
      expect(entity.calories, 150.0);
      expect(entity.protein, 21.0);
      expect(entity.carbohydrates, 2.5);
      expect(entity.fats, 6.2);

      // Manifest existence & mapping safety
      final manifestEntry = FoodImageManifest.manifest[foodId];
      expect(manifestEntry, isNotNull);
      expect(manifestEntry!.imagePathOrUrl, 'assets/images/foods/amritsari_fish_tikka.webp');
      expect(manifestEntry.imagePathOrUrl.contains(rejectedFishTikkaUrl), isFalse);

      // Resolver: Must resolve to real local asset, NOT empty string fallback
      final resolved = FoodImageResolver.resolve(entity);
      expect(resolved, 'assets/images/foods/amritsari_fish_tikka.webp');
      expect(resolved, isNotEmpty);
      expect(resolved.contains(rejectedFishTikkaUrl), isFalse);

      // Also resolve by string name
      expect(FoodImageResolver.resolve('Amritsari Fish Tikka'), 'assets/images/foods/amritsari_fish_tikka.webp');

      // Source metadata
      expect(sourcesJson.containsKey(foodId), isTrue);
      final meta = sourcesJson[foodId] as Map<String, dynamic>;
      expect(meta['source'], 'Wikimedia Commons');
      expect(meta['license'], 'CC0');

      // Recipe remains intact
      final recipe = FoodAssetRepository.instance.getRecipe(foodId);
      expect(recipe, isNotNull);
      expect(recipe!.foodName, 'Amritsari Fish Tikka');
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.instructions, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 4. Widget Rendering Verification
    // -------------------------------------------------------------------------
    testWidgets('4. Real local asset rendering for all three corrected foods', (tester) async {
      final targetIds = [
        'predefined_almond_butter',
        'predefined_aloo_methi',
        'predefined_grilled_fish_tikka',
      ];

      for (final id in targetIds) {
        final food = PredefinedFoodData.foods.firstWhere((f) => f.id == id).toEntity();
        final imageSource = FoodImageResolver.resolve(food);
        expect(imageSource, isNotEmpty);
        expect(imageSource.startsWith('assets/images/foods/'), isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FitFuelFoodPhoto(
                source: imageSource,
                description: food.name,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must render gracefully without error
        expect(tester.takeException(), isNull);
        expect(find.byType(FitFuelFoodPhoto), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      }
    });

    // -------------------------------------------------------------------------
    // 5. Search Foods Query & Resolver Verification
    // -------------------------------------------------------------------------
    test('5. Search results resolve real images for all 3 queries', () {
      final queries = ['Almond Butter', 'Aloo Methi', 'Fish Tikka'];

      for (final q in queries) {
        final matches = PredefinedFoodData.foods.where(
          (f) => f.name.toLowerCase().contains(q.toLowerCase()),
        ).toList();
        expect(matches, isNotEmpty, reason: 'Search query $q must find food');

        for (final match in matches) {
          final resolved = FoodImageResolver.resolve(match.toEntity());
          expect(resolved, isNotEmpty, reason: 'Food ${match.name} must have real image');
          expect(resolved.startsWith('assets/images/foods/'), isTrue);
        }
      }
    });
  });
}
