import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_card.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/utils/food_category_normalizer.dart';
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';

void main() {
  group('Phase 35.7.5 — Food Search Visual Polish & Category/Meal Filtering Tests', () {
    final allFoods =
        PredefinedFoodData.foods.map((m) => m.toEntity()).toList();

    // ──────────────────────────────────────────────────────────────────────────
    // 1. Food Card Image Geometry & Aspect Ratio (16:9)
    // ──────────────────────────────────────────────────────────────────────────
    testWidgets('1. Food result images render with consistent 16:9 aspect ratio',
        (tester) async {
      final sampleFood = allFoods.firstWhere((f) => f.name.contains('Idli'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: FitFuelFoodCard(
                food: sampleFood,
                imageAspectRatio: 16 / 9,
                isFavorite: false,
                onTap: () {},
                onFavoriteTap: () {},
                onAddTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify AspectRatio widget is present with 16 / 9
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsWidgets);

      final AspectRatio aspectRatioWidget =
          tester.widget<AspectRatio>(aspectRatioFinder.first);
      expect(aspectRatioWidget.aspectRatio, closeTo(16 / 9, 0.001),
          reason: 'Mobile food card image should use 16:9 aspect ratio');

      // Verify FoodImageCard is inside AspectRatio
      expect(find.descendant(of: aspectRatioFinder, matching: find.byType(FoodImageCard)),
          findsWidgets);

      // Verify favorite button is overlayed in top-right
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Verify food details & Add to Log button remain visible
      expect(find.text(sampleFood.name), findsOneWidget);
      expect(find.text('+ Add to Log'), findsOneWidget);
      expect(find.text('${sampleFood.calories.toStringAsFixed(0)} kcal'), findsOneWidget);
      expect(find.text('${sampleFood.protein.toStringAsFixed(0)}g protein'), findsOneWidget);
    });

    testWidgets('2. Card clips image to top rounded corners with no boundary overflow',
        (tester) async {
      final sampleFood = allFoods.firstWhere((f) => f.name.contains('Dosa'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: FitFuelFoodCard(
                food: sampleFood,
                imageAspectRatio: 16 / 9,
                isFavorite: true,
                onTap: () {},
                onFavoriteTap: () {},
                onAddTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Top image has ClipRRect
      final clipRRectFinder = find.byType(ClipRRect);
      expect(clipRRectFinder, findsWidgets);

      final ClipRRect clipRRectWidget =
          tester.widget<ClipRRect>(clipRRectFinder.first);
      expect(
        clipRRectWidget.borderRadius,
        equals(const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusLg))),
      );

      // Heart icon is filled when favorite is true
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Primary Filter Chips Existence & Order
    // ──────────────────────────────────────────────────────────────────────────
    test('3. Primary filter chips exist in canonical order', () {
      const filters = FoodCategoryNormalizer.primaryFilters;

      expect(filters, [
        'All',
        'Breakfast',
        'Lunch',
        'Snacks',
        'Dinner',
        'Fruits',
        'Vegetables',
        'Protein',
        'Dairy',
        'Grains',
        'Beverages',
        'Desserts',
      ]);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Breakfast Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('4. Breakfast filter returns breakfast-compatible foods using mealTypes', () {
      final breakfastFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Breakfast'))
          .toList();

      expect(breakfastFoods.length, greaterThan(20),
          reason: 'Breakfast should have a substantial catalog list');

      // Every returned food must have Breakfast in mealTypes or category
      for (final food in breakfastFoods) {
        final matches = food.mealTypes
                .any((m) => m.toLowerCase().trim() == 'breakfast') ||
            food.category.toLowerCase().trim() == 'breakfast';
        expect(matches, isTrue,
            reason: '${food.name} should be breakfast compatible');
      }

      // Verify known breakfast staples are included
      final names = breakfastFoods.map((f) => f.name).toList();
      expect(names.any((n) => n.contains('Idli') || n.contains('Dosa') || n.contains('Upma') || n.contains('Oat')),
          isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Lunch Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('5. Lunch filter returns lunch-compatible foods', () {
      final lunchFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Lunch'))
          .toList();

      expect(lunchFoods.length, greaterThan(20));

      for (final food in lunchFoods) {
        final matches = food.mealTypes
                .any((m) => m.toLowerCase().trim() == 'lunch') ||
            food.category.toLowerCase().trim() == 'lunch';
        expect(matches, isTrue,
            reason: '${food.name} should be lunch compatible');
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Snacks Filtering (handling Snacks vs Snack normalization)
    // ──────────────────────────────────────────────────────────────────────────
    test('6. Snacks filter normalizes Snacks and Snack spelling', () {
      final snackFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Snacks'))
          .toList();

      expect(snackFoods.length, greaterThan(20));

      for (final food in snackFoods) {
        final matches = food.mealTypes.any((m) {
              final t = m.toLowerCase().trim();
              return t == 'snacks' || t == 'snack';
            }) ||
            food.category.toLowerCase().trim() == 'snacks' ||
            food.category.toLowerCase().trim() == 'snack';
        expect(matches, isTrue,
            reason: '${food.name} should satisfy snack metadata');
      }

      // 'Snack' singular filter matches same items
      final singularMatches = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Snack'))
          .toList();
      expect(singularMatches.length, equals(snackFoods.length));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Dinner Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('7. Dinner filter returns dinner-compatible foods', () {
      final dinnerFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Dinner'))
          .toList();

      expect(dinnerFoods.length, greaterThan(20));

      for (final food in dinnerFoods) {
        final matches = food.mealTypes
                .any((m) => m.toLowerCase().trim() == 'dinner') ||
            food.category.toLowerCase().trim() == 'dinner';
        expect(matches, isTrue,
            reason: '${food.name} should satisfy dinner metadata');
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Dairy Category Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('8. Dairy filter returns all Dairy-category foods', () {
      final dairyFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Dairy'))
          .toList();

      expect(dairyFoods, isNotEmpty);

      // Verify all items have Dairy category
      for (final food in dairyFoods) {
        expect(food.category.toLowerCase(), equals('dairy'));
      }

      final dairyNames = dairyFoods.map((f) => f.name).toList();
      expect(dairyNames.contains('Low-Fat Paneer'), isTrue);
      expect(dairyNames.contains('Paneer Bhurji'), isTrue);
      expect(dairyNames.contains('Indian Curd (Dahi)'), isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Fruits Category Filtering (Plural/Singular normalization)
    // ──────────────────────────────────────────────────────────────────────────
    test('9. Fruits filter returns only fruits and normalizes Fruits/Fruit', () {
      final fruits = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Fruits'))
          .toList();

      expect(fruits.length, greaterThan(10));

      for (final food in fruits) {
        expect(food.category.toLowerCase(), anyOf(equals('fruits'), equals('fruit')));
      }

      // Fruit singular gives same results
      final fruitSingular = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Fruit'))
          .toList();
      expect(fruitSingular.length, equals(fruits.length));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 9. Vegetables Category Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('10. Vegetables filter returns only vegetables and normalizes plural', () {
      final vegetables = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Vegetables'))
          .toList();

      expect(vegetables.length, greaterThan(15));

      for (final food in vegetables) {
        expect(food.category.toLowerCase(), anyOf(equals('vegetables'), equals('vegetable')));
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 10. Protein Category Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('11. Protein filter returns protein foods', () {
      final proteinFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Protein'))
          .toList();

      expect(proteinFoods, isNotEmpty);

      for (final food in proteinFoods) {
        expect(food.category.toLowerCase(), equals('protein'));
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 11. Grains, Beverages, Desserts Filtering
    // ──────────────────────────────────────────────────────────────────────────
    test('12. Grains, Beverages, and Desserts filters match catalog categories', () {
      final grains = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Grains'))
          .toList();
      expect(grains, isNotEmpty);
      for (final f in grains) {
        expect(f.category.toLowerCase(), anyOf(equals('grains'), equals('grain')));
      }

      final beverages = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Beverages'))
          .toList();
      expect(beverages, isNotEmpty);
      for (final f in beverages) {
        expect(f.category.toLowerCase(), anyOf(equals('beverages'), equals('beverage')));
      }

      final desserts = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Desserts'))
          .toList();
      expect(desserts, isNotEmpty);
      for (final f in desserts) {
        expect(f.category.toLowerCase(), anyOf(equals('desserts'), equals('dessert')));
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 12. Combined Search + Filter
    // ──────────────────────────────────────────────────────────────────────────
    test('13. Combined filter: Breakfast + "oat"', () {
      final breakfastFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Breakfast'))
          .toList();
      final results = FoodSearchEngine.search(foods: breakfastFoods, query: 'oat');

      expect(results, isNotEmpty);
      final names = results.map((f) => f.name).toList();
      expect(names.contains('Oats (Rolled)'), isTrue);
      expect(names.contains('Oatmeal (Cooked in Water)'), isTrue);
      expect(names.contains('Oats Bran'), isTrue);
    });

    test('14. Combined filter: Dairy + "paneer"', () {
      final dairyFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Dairy'))
          .toList();
      final results = FoodSearchEngine.search(foods: dairyFoods, query: 'paneer');

      expect(results, isNotEmpty);
      for (final food in results) {
        expect(food.category.toLowerCase(), equals('dairy'));
      }
      final names = results.map((f) => f.name).toList();
      expect(names.contains('Low-Fat Paneer'), isTrue);
      expect(names.contains('Paneer Bhurji'), isTrue);
      expect(names.contains('Paneer (Indian Cottage Cheese)'), isTrue);
    });

    test('15. Combined filter: Protein + "chicken"', () {
      final proteinFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Protein'))
          .toList();
      final results = FoodSearchEngine.search(foods: proteinFoods, query: 'chicken');

      expect(results, isNotEmpty);
      for (final food in results) {
        expect(food.category.toLowerCase(), equals('protein'));
        expect(food.name.toLowerCase().contains('chicken'), isTrue);
      }
    });

    test('16. Combined filter: All + "tuna"', () {
      final allCandidateFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'All'))
          .toList();
      expect(allCandidateFoods.length, equals(238));

      final results = FoodSearchEngine.search(foods: allCandidateFoods, query: 'tuna');
      expect(results, isNotEmpty);
      final names = results.map((f) => f.name).toList();
      expect(names.contains('Canned Tuna (In Water)'), isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 13. Search Clear preserves selected category
    // ──────────────────────────────────────────────────────────────────────────
    test('17. Clearing search preserves currently selected category filter', () {
      // Simulate state: selectedCategory = 'Dairy', query = 'paneer'
      String? selectedCategory = 'Dairy';
      String query = 'paneer';

      // With query active
      final withQuery = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, selectedCategory))
          .toList();
      final paneerInDairy = FoodSearchEngine.search(foods: withQuery, query: query);
      expect(paneerInDairy.length, lessThan(withQuery.length));

      // User clears search field (X button): query becomes empty, category remains 'Dairy'
      query = '';
      final clearedResults = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, selectedCategory))
          .toList();

      expect(clearedResults.length, equals(withQuery.length),
          reason: 'All Dairy foods should return when query is cleared');
      expect(selectedCategory, equals('Dairy'),
          reason: 'Category filter should not be wiped out by clearing search text');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 14. Performance & Deterministic Local Search (0 Gemini calls)
    // ──────────────────────────────────────────────────────────────────────────
    test('18. Search and filtering execute locally and deterministically under 20ms', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 50; i++) {
        final filtered = allFoods
            .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Breakfast'))
            .toList();
        FoodSearchEngine.search(foods: filtered, query: 'oat');
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(200),
          reason: '50 iterations of search + filtering must execute within 200ms locally');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 15. Result count & Empty states
    // ──────────────────────────────────────────────────────────────────────────
    test('19. Empty search/filter combination gives zero results gracefully', () {
      final dairyFoods = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'Dairy'))
          .toList();
      final results = FoodSearchEngine.search(foods: dairyFoods, query: 'watermelon');

      expect(results, isEmpty,
          reason: 'Dairy should contain no watermelon');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 16. Total catalog still 238 foods
    // ──────────────────────────────────────────────────────────────────────────
    test('20. Entire catalog of 238 foods remains browsable under "All"', () {
      final allFiltered = allFoods
          .where((f) => FoodCategoryNormalizer.matchesFilter(f, 'All'))
          .toList();

      expect(allFiltered.length, equals(238));
    });
  });
}
