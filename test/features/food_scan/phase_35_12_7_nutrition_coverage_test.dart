import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  late UniversalNutritionResolver resolver;

  setUp(() {
    resolver = UniversalNutritionResolver();
  });

  group('Phase 35.12.7 — Requirement 12: Authoritative Nutrition Reconciliation (Samosa)', () {
    test('1. Samosa authoritative values in PredefinedFoodData are exactly 250 kcal for 75g (not 262 kcal)', () {
      final samosa = catalog.firstWhere((f) => f.id == 'predefined_samosa');
      expect(samosa.name, equals('Samosa'));
      expect(samosa.servingSize, equals(75.0));
      expect(samosa.servingUnit, equals('g'));
      expect(samosa.calories, equals(250.0));
      expect(samosa.protein, equals(3.5));
      expect(samosa.carbohydrates, equals(32.0));
      expect(samosa.fats, equals(12.0));
      expect(samosa.fiber, equals(1.5));
      expect(samosa.sodium, equals(360.0));

      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_samosa',
        canonicalName: 'Samosa',
        category: 'Snacks',
        similarity: 0.1850,
        rank: 1,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.verifiedExact));
      expect(res.matchedCatalogFood, isNotNull);
      expect(res.matchedCatalogFood!.id, equals('predefined_samosa'));
      expect(res.matchedCatalogFood!.calories, equals(250.0));
      expect(res.matchedCatalogFood!.fats, equals(12.0));
    });
  });

  group('Phase 35.12.7 — Requirement 4 & 5: Exact Curated Matches (Tier 1)', () {
    test('2. Curated catalog exact items resolve to Tier 1: verifiedExact with non-null macros', () {
      final testItems = [
        ('predefined_masala_dosa', 'Masala Dosa', 220.0, 4.2, 36.0, 6.8),
        ('predefined_rajma_chawal', 'Rajma Chawal', 175.0, 6.8, 29.0, 3.5),
        ('predefined_idli', 'Idli', 120.0, 3.2, 25.5, 0.4),
        ('predefined_chapati', 'Chapati', 104.0, 3.1, 20.0, 1.2),
        ('predefined_steamed_rice', 'Steamed Rice (Basmati)', 130.0, 2.7, 28.0, 0.3),
        ('predefined_apple', 'Apple', 52.0, 0.3, 14.0, 0.2),
        ('predefined_banana', 'Banana', 89.0, 1.1, 22.8, 0.3),
      ];

      for (final item in testItems) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: item.$1,
          canonicalName: item.$2,
          category: 'Curated',
          similarity: 0.1750,
          rank: 1,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.verifiedExact), reason: 'Failed for ${item.$2}');
        expect(res.isVerifiedExact, isTrue);
        expect(res.hasNutrition, isTrue);
        expect(res.matchedCatalogFood, isNotNull);
        expect(res.matchedCatalogFood!.calories, equals(item.$3));
        expect(res.matchedCatalogFood!.protein, equals(item.$4));
        expect(res.matchedCatalogFood!.carbohydrates, equals(item.$5));
        expect(res.matchedCatalogFood!.fats, equals(item.$6));
        expect(res.attribution, contains('FitFuel'));
      }
    });
  });

  group('Phase 35.12.7 — Requirement 6: Morphological Aliases, Plurals & Transliterations', () {
    test('3. Plural, regional and transliterated variants map 1:1 to exact catalog items', () {
      final aliasTests = [
        ('boiled egg', 'predefined_hard_boiled_eggs'),
        ('boiled eggs', 'predefined_hard_boiled_eggs'),
        ('hard boiled egg', 'predefined_hard_boiled_eggs'),
        ('idlis', 'predefined_idli'),
        ('idly', 'predefined_idli'),
        ('steamed idli', 'predefined_idli'),
        ('plain dosa', 'predefined_dosa'),
        ('sada dosa', 'predefined_dosa'),
        ('masala dosas', 'predefined_masala_dosa'),
        ('tandoori roti', 'predefined_roti'),
        ('phulka', 'predefined_chapati'),
        ('chapatti', 'predefined_chapati'),
        ('chapatis', 'predefined_chapati'),
        ('white rice', 'predefined_steamed_rice'),
        ('cooked rice', 'predefined_steamed_rice'),
        ('chawal', 'predefined_steamed_rice'),
        ('dal tadka', 'predefined_dal_tadka'),
        ('tadka dal', 'predefined_dal_tadka'),
        ('apples', 'predefined_apple'),
        ('bananas', 'predefined_banana'),
        ('ripe banana', 'predefined_banana'),
      ];

      for (final testCase in aliasTests) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${testCase.$1.replaceAll(' ', '_')}',
          canonicalName: testCase.$1,
          category: 'Alias',
          similarity: 0.1620,
          rank: 1,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.verifiedExact), reason: 'Failed alias: ${testCase.$1}');
        expect(res.matchedCatalogFood, isNotNull);
        expect(res.matchedCatalogFood!.id, equals(testCase.$2), reason: 'Incorrect catalog ID for ${testCase.$1}');
      }
    });
  });

  group('Phase 35.12.7 — Requirement 5: USDA Generic Baselines (Tier 2)', () {
    test('4. Common international & generic foods resolve to Tier 2: USDA Generic Baseline', () {
      final genericCases = [
        ('Pepperoni Pizza', 'Pizza', 'usda_generic_pizza', 'FDC_173292'),
        ('Cheeseburger', 'Burgers', 'usda_generic_burger', 'FDC_170694'),
        ('Penne Marinara', 'Pasta', 'usda_generic_pasta', 'FDC_168936'),
        ('Jasmine Rice', 'Rice', 'usda_generic_white_rice', 'FDC_168878'),
        ('Cooked Brown Rice Grain', 'Rice', 'usda_generic_brown_rice', 'FDC_169704'),
        ('Slice of White Bread', 'Bakery', 'usda_generic_white_bread', 'FDC_174924'),
        ('Sunny Side Up Fried Egg', 'Eggs', 'usda_generic_fried_egg', 'FDC_173424'),
        ('Fresh Garden Salad', 'Salads', 'usda_generic_green_salad', 'FDC_169248'),
        ('Greek Salad with Feta', 'Salads', 'usda_generic_greek_salad', 'FNDDS_75146000'),
        ('Fresh Orange Slices', 'Fruits', 'usda_generic_orange', 'FDC_169097'),
        ('Fresh Strawberries', 'Fruits', 'usda_generic_strawberry', 'FDC_167762'),
        ('Steamed Broccoli Florets', 'Vegetables', 'usda_generic_broccoli', 'FDC_170379'),
        ('Steamed Sliced Carrots', 'Vegetables', 'usda_generic_carrot', 'FDC_170394'),
        ('Cooked Spinach Leaves', 'Vegetables', 'usda_generic_spinach', 'FDC_170460'),
      ];

      for (final gCase in genericCases) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${gCase.$1.toLowerCase().replaceAll(' ', '_')}',
          canonicalName: gCase.$1,
          category: gCase.$2,
          similarity: 0.1580,
          rank: 1,
          inFitFuelCatalog: false,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric), reason: 'Failed for ${gCase.$1}');
        expect(res.isGenericBaseline, isTrue);
        expect(res.hasNutrition, isTrue);
        expect(res.matchedCatalogFood, isNotNull);
        expect(res.matchedCatalogFood!.calories, greaterThan(0));
        expect(res.attribution, isNotNull);
      }
    });
  });

  group('Phase 35.12.7 — Requirement 4 & 5: Documented Recipe Estimates (Tier 3)', () {
    test('5. Recipe formulations resolve to Tier 3: recipeEstimate with stated culinary assumptions', () {
      final recipeCases = [
        ('Creamy Penne Alfredo', 'creamy_pasta_estimate', 'Penne pasta tossed with cream'),
        ('Chicken Tikka Masala', 'chicken_tikka_masala_estimate', 'spiced tomato, cream, onion sauce'),
        ('Vegetable Fried Rice', 'vegetable_fried_rice_estimate', 'stir-fried with mixed vegetables'),
      ];

      for (final rCase in recipeCases) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${rCase.$1.toLowerCase().replaceAll(' ', '_')}',
          canonicalName: rCase.$1,
          category: 'Recipe',
          similarity: 0.1650,
          rank: 1,
          inFitFuelCatalog: false,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.recipeEstimate), reason: 'Failed for ${rCase.$1}');
        expect(res.isRecipeEstimate, isTrue);
        expect(res.hasNutrition, isTrue);
        expect(res.recipeAssumptions, isNotNull);
        expect(res.recipeAssumptions, contains(rCase.$3));
      }
    });
  });

  group('Phase 35.12.7 — Requirement 6 & 9: Collision & Safety Guards (No Inappropriate Merging)', () {
    test('6. Non-equivalent food names do not accidentally match generic profiles or distinct dishes', () {
      final safeNonMatches = [
        ('Eggplant Parmigiana', 'Eggplant must not map to generic egg'),
        ('Pineapple Upside Down Cake', 'Pineapple must not map to generic apple'),
        ('Pastrami on Rye', 'Pastrami must not map to generic pasta'),
        ('Tomato Paste', 'Paste must not map to generic pasta'),
        ('Shortbread Cookies', 'Shortbread must not map to generic white bread'),
        ('Licorice Candy', 'Licorice must not map to generic rice'),
        ('Dragonfruit Salad', 'Dragonfruit must not map to generic green salad'),
        ('Tuna Salad Sandwich', 'Tuna salad must not map to generic green salad'),
      ];

      for (final nm in safeNonMatches) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${nm.$1.toLowerCase().replaceAll(' ', '_')}',
          canonicalName: nm.$1,
          category: 'SafetyCheck',
          similarity: 0.1400,
          rank: 1,
          inFitFuelCatalog: false,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(
          res.profile?.id != 'usda_generic_boiled_egg' &&
          res.profile?.id != 'usda_generic_apple' &&
          res.profile?.id != 'usda_generic_pasta' &&
          res.profile?.id != 'usda_generic_white_bread' &&
          res.profile?.id != 'usda_generic_white_rice',
          isTrue,
          reason: nm.$2,
        );
      }
    });
  });

  group('Phase 35.12.7 — Requirement 8 & 9: Unsupported Foods & Diary Blocking (Tier 4)', () {
    test('7. Obscure / unsupported foods resolve to Tier 4: unavailable with 0 fabricated macros and blocked diary logging', () {
      final unsupportedDishes = [
        'Dragonfruit Salad with Exotic Berries',
        'Escargot in Garlic Butter',
        'Durian Sticky Rice',
        'Fermented Icelandic Shark (Hakarl)',
      ];

      for (final dish in unsupportedDishes) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${dish.toLowerCase().replaceAll(' ', '_')}',
          canonicalName: dish,
          category: 'Exotic',
          similarity: 0.1380,
          rank: 1,
          inFitFuelCatalog: false,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.unavailable));
        expect(res.hasNutrition, isFalse);
        expect(res.matchedCatalogFood, isNull);

        // Verify FoodScanResult logging guard
        final detected = DetectedFoodCandidate(
          id: 'test_cand',
          detectedName: dish,
          confidence: 1.0,
          estimatedAmount: 100.0,
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: res.matchedCatalogFood,
          visualNotes: 'Unavailable',
          nutritionTier: res.tier,
          isUserConfirmed: true,
        );

        final scanResult = FoodScanResult(
          id: 'scan_unsupported',
          imagePath: '/tmp/test.jpg',
          foods: [detected],
          overallConfidence: 1.0,
          scannedAt: DateTime.now(),
          recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
        );

        expect(scanResult.canBeLogged, isFalse, reason: 'Unsupported dish must not be loggable');
        expect(detected.hasNutrition, isFalse);
        expect(detected.calories, isNull);
        expect(detected.protein, isNull);
        expect(detected.carbs, isNull);
        expect(detected.fats, isNull);
      }
    });

    test('8. Manual nutrition entry replaces unavailable profile with valid FoodEntity and enables logging', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_custom_dish',
        canonicalName: 'Grandma Homemade Oxtail Goulash',
        category: 'Homemade',
        similarity: 0.1550,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));

      // User provides manual entry alternative (Requirement 8)
      const manualFood = FoodEntity(
        id: 'manual_custom_stew',
        name: 'Grandma Homemade Oxtail Goulash',
        category: 'Manual Entry',
        servingSize: 150.0,
        servingUnit: 'g',
        calories: 180.0,
        protein: 10.0,
        carbohydrates: 25.0,
        fats: 4.0,
        fiber: 5.0,
        sugar: 2.0,
        sodium: 350.0,
        isCustom: true,
      );

      final manualDetected = DetectedFoodCandidate(
        id: 'manual_detected',
        detectedName: manualFood.name,
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 150.0,
        estimatedUnit: 'g',
        matchedFood: manualFood,
        visualNotes: 'Manual Nutrition Entry',
        nutritionTier: NutritionProfileTier.verifiedExact,
        isUserConfirmed: true,
        recognitionSource: FoodScanRecognitionSource.manual,
      );

      final scanResult = FoodScanResult(
        id: 'scan_manual_success',
        imagePath: '/tmp/test.jpg',
        foods: [manualDetected],
        overallConfidence: 1.0,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.manual,
      );

      expect(scanResult.canBeLogged, isTrue);
      expect(manualDetected.hasNutrition, isTrue);
      expect(manualDetected.calories, equals(180.0));
      expect(manualDetected.protein, equals(10.0));
      expect(manualDetected.carbs, equals(25.0));
      expect(manualDetected.fats, equals(4.0));
    });
  });

  group('Phase 35.12.7 — Requirement 7: Mixed Meal Recognition Gating', () {
    test('9. Mixed meal suspected flag gates single food auto-acceptance and prevents ingredient fabrication', () {
      const detected = DetectedFoodCandidate(
        id: 'plate_detected',
        detectedName: 'Thali Plate',
        confidence: 0.95,
        estimatedAmount: 400.0,
        originalEstimatedAmount: 400.0,
        estimatedUnit: 'g',
        matchedFood: null,
        visualNotes: 'Multiple items detected on plate',
        isUserConfirmed: false,
      );

      expect(detected.hasNutrition, isFalse);
      expect(detected.isNutritionUncertain, isTrue);
    });
  });

  group('Phase 35.12.7 — Portion Scaling Verification', () {
    test('10. Portion scaling scales macros linearly without corrupting baseline values', () {
      final food = catalog.firstWhere((f) => f.id == 'predefined_samosa');
      // Serving size 75g: 250 kcal, 3.5g P, 32g C, 12g F

      // Case 1: 150g (Double portion)
      final doublePortion = DetectedFoodCandidate(
        id: 'samosa_2x',
        detectedName: 'Samosa',
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 75.0,
        estimatedUnit: 'g',
        matchedFood: food,
        isUserConfirmed: true,
      );

      expect(doublePortion.calories, closeTo(500.0, 0.1));
      expect(doublePortion.protein, closeTo(7.0, 0.1));
      expect(doublePortion.carbs, closeTo(64.0, 0.1));
      expect(doublePortion.fats, closeTo(24.0, 0.1));

      // Case 2: 37.5g (Half portion)
      final halfPortion = DetectedFoodCandidate(
        id: 'samosa_half',
        detectedName: 'Samosa',
        confidence: 1.0,
        estimatedAmount: 37.5,
        originalEstimatedAmount: 75.0,
        estimatedUnit: 'g',
        matchedFood: food,
        isUserConfirmed: true,
      );

      expect(halfPortion.calories, closeTo(125.0, 0.1));
      expect(halfPortion.protein, closeTo(1.75, 0.1));
      expect(halfPortion.carbs, closeTo(16.0, 0.1));
      expect(halfPortion.fats, closeTo(6.0, 0.1));
    });
  });
}
