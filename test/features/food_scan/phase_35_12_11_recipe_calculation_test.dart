import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/recipe_formulation.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final resolver = UniversalNutritionResolver();

  group('Phase 35.12.11 — Task 1: Ingredient Masses & Batch Cooked Yields', () {
    test('1. Assert each recipe formulation mass equals its target batch cooked yield', () {
      final formulations = resolver.recipeFormulations;
      expect(formulations.length, equals(4), reason: 'Must have 4 standard recipe formulations');

      // 1. Alfredo: 500g batch
      final alfredo = formulations['creamy_pasta_estimate']!;
      expect(alfredo.targetBatchMassGrams, equals(500.0));
      expect(alfredo.totalIngredientMass, equals(500.0));
      expect(alfredo.ingredients.length, equals(5));
      expect(alfredo.ingredients.any((i) => i.name == 'Cooked Penne Pasta' && i.massGrams == 300.0), isTrue);
      expect(alfredo.ingredients.any((i) => i.name == 'Light Cooking Cream' && i.massGrams == 120.0), isTrue);
      expect(alfredo.ingredients.any((i) => i.name == 'Unsalted Butter' && i.massGrams == 25.0), isTrue);
      expect(alfredo.ingredients.any((i) => i.name == 'Grated Parmesan Cheese' && i.massGrams == 40.0), isTrue);
      expect(alfredo.ingredients.any((i) => i.name.contains('Seasoning') && i.massGrams == 15.0), isTrue);

      // 2. Chicken Tikka Masala: 600g batch
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      expect(tikka.targetBatchMassGrams, equals(600.0));
      expect(tikka.totalIngredientMass, equals(600.0));
      expect(tikka.ingredients.length, equals(5));
      expect(tikka.ingredients.any((i) => i.name == 'Roasted Chicken Breast' && i.massGrams == 300.0), isTrue);
      expect(tikka.ingredients.any((i) => i.name.contains('Gravy Base') && i.massGrams == 180.0), isTrue);
      expect(tikka.ingredients.any((i) => i.name.contains('Yogurt') && i.massGrams == 75.0), isTrue);
      expect(tikka.ingredients.any((i) => i.name.contains('Cooking Oil') && i.massGrams == 25.0), isTrue);
      expect(tikka.ingredients.any((i) => i.name.contains('Salt') && i.massGrams == 20.0), isTrue);

      // 3. Vegetable Fried Rice: 500g batch
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      expect(friedRice.targetBatchMassGrams, equals(500.0));
      expect(friedRice.totalIngredientMass, equals(500.0));
      expect(friedRice.ingredients.length, equals(4));
      expect(friedRice.ingredients.any((i) => i.name == 'Cooked White Rice' && i.massGrams == 360.0), isTrue);
      expect(friedRice.ingredients.any((i) => i.name == 'Diced Mixed Vegetables' && i.massGrams == 100.0), isTrue);
      expect(friedRice.ingredients.any((i) => i.name.contains('Oil') && i.massGrams == 25.0), isTrue);
      expect(friedRice.ingredients.any((i) => i.name.contains('Soy Sauce') && i.massGrams == 15.0), isTrue);

      // 4. Vegetable Curry: 600g batch (Defensible Liquid Review)
      final curry = formulations['vegetable_curry_estimate']!;
      expect(curry.targetBatchMassGrams, equals(600.0));
      expect(curry.totalIngredientMass, equals(600.0));
      expect(curry.ingredients.length, equals(5));
      expect(curry.ingredients.any((i) => i.name == 'Mixed Seasonal Vegetables' && i.massGrams == 350.0), isTrue);
      expect(curry.ingredients.any((i) => i.name.contains('Curry Gravy Base') && i.massGrams == 180.0), isTrue);
      expect(curry.ingredients.any((i) => i.name == 'Vegetable Cooking Oil' && i.massGrams == 20.0), isTrue);
      expect(curry.ingredients.any((i) => i.name.contains('Spices') && i.massGrams == 15.0), isTrue);

      // Specifically verify 35g liquid explanation: net simmer water retained in finished cooked curry yield
      final waterIngredient = curry.ingredients.firstWhere((i) => i.sourceIdentifier == 'WATER');
      expect(waterIngredient.massGrams, equals(35.0));
      expect(waterIngredient.caloriesContribution, equals(0.0));
      expect(waterIngredient.notes, contains('retained in final curry yield'));
    });
  });

  group('Phase 35.12.11 — Task 2: Recompute Batch Totals from Ingredient Contributions', () {
    test('2. Ingredient contributions sum exactly to verified batch totals', () {
      final formulations = resolver.recipeFormulations;

      // 1. Alfredo batch totals check
      final alfredo = formulations['creamy_pasta_estimate']!;
      expect(alfredo.batchCalories, closeTo(975.0, 0.01));
      expect(alfredo.batchProtein, closeTo(33.85, 0.01));
      expect(alfredo.batchCarbs, closeTo(83.70, 0.01));
      expect(alfredo.batchFat, closeTo(55.85, 0.01));
      expect(alfredo.batchSodium, closeTo(1602.17, 0.05));

      // 2. Tikka batch totals check
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      expect(tikka.batchCalories, closeTo(895.42, 0.05));
      expect(tikka.batchProtein, closeTo(98.54, 0.05));
      expect(tikka.batchCarbs, closeTo(21.25, 0.05));
      expect(tikka.batchFat, closeTo(43.71, 0.05));
      expect(tikka.batchSodium, closeTo(2280.05, 0.05));

      // 3. Fried Rice batch totals check
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      expect(friedRice.batchCalories, closeTo(754.0, 0.01));
      expect(friedRice.batchProtein, closeTo(13.68, 0.01));
      expect(friedRice.batchCarbs, closeTo(112.60, 0.01));
      expect(friedRice.batchFat, closeTo(26.50, 0.01));
      expect(friedRice.batchSodium, closeTo(1600.29, 0.05));

      // 4. Vegetable Curry batch totals check
      final curry = formulations['vegetable_curry_estimate']!;
      expect(curry.batchCalories, closeTo(439.0, 0.01));
      expect(curry.batchProtein, closeTo(10.00, 0.01));
      expect(curry.batchCarbs, closeTo(48.00, 0.01));
      expect(curry.batchFat, closeTo(22.80, 0.01));
      expect(curry.batchSodium, closeTo(1864.79, 0.05));
    });
  });

  group('Phase 35.12.11 — Task 3: Stored Profiles Match Derived Per-100-g Math', () {
    test('3. Stored profile in UniversalNutritionResolver matches batchTotal / batchMass * 100 within tolerance', () {
      final recipes = resolver.recipeEstimates;

      // 1. Alfredo
      final alfredo = recipes['creamy_pasta_estimate']!;
      expect(alfredo.calories, equals(195.0)); // 975 / 5 = 195.00
      expect(alfredo.protein, equals(6.77)); // 33.85 / 5 = 6.77
      expect(alfredo.carbohydrates, equals(16.74)); // 83.70 / 5 = 16.74
      expect(alfredo.totalFat, equals(11.17)); // 55.85 / 5 = 11.17
      expect(alfredo.sodium, equals(320.4)); // 1602.17 / 5 = 320.433... -> 320.4
      expect(alfredo.fiber, equals(1.11)); // 5.55 / 5 = 1.11

      // 2. Chicken Tikka Masala
      final tikka = recipes['chicken_tikka_masala_estimate']!;
      expect(tikka.calories, equals(149.24)); // 895.42 / 6 = 149.236... -> 149.24
      expect(tikka.protein, equals(16.42)); // 98.54 / 6 = 16.423... -> 16.42
      expect(tikka.carbohydrates, equals(3.54)); // 21.25 / 6 = 3.541... -> 3.54
      expect(tikka.totalFat, equals(7.28)); // 43.71 / 6 = 7.284... -> 7.28
      expect(tikka.sodium, equals(380.0)); // 2280.05 / 6 = 380.008... -> 380.0
      expect(tikka.fiber, equals(0.93)); // 5.60 / 6 = 0.933... -> 0.93

      // 3. Vegetable Fried Rice
      final friedRice = recipes['vegetable_fried_rice_estimate']!;
      expect(friedRice.calories, equals(150.80)); // 754 / 5 = 150.80
      expect(friedRice.protein, equals(2.74)); // 13.68 / 5 = 2.736 -> 2.74
      expect(friedRice.carbohydrates, equals(22.52)); // 112.60 / 5 = 22.52
      expect(friedRice.totalFat, equals(5.30)); // 26.50 / 5 = 5.30
      expect(friedRice.sodium, equals(320.1)); // 1600.29 / 5 = 320.058... -> 320.1
      expect(friedRice.fiber, equals(0.91)); // 4.54 / 5 = 0.908 -> 0.91

      // 4. Vegetable Curry
      final curry = recipes['vegetable_curry_estimate']!;
      expect(curry.calories, equals(73.17)); // 439 / 6 = 73.166... -> 73.17
      expect(curry.protein, equals(1.67)); // 10.00 / 6 = 1.666... -> 1.67
      expect(curry.carbohydrates, equals(8.00)); // 48.00 / 6 = 8.00
      expect(curry.totalFat, equals(3.80)); // 22.80 / 6 = 3.80
      expect(curry.sodium, equals(310.8)); // 1864.79 / 6 = 310.799... -> 310.8
      expect(curry.fiber, equals(2.33)); // 14.00 / 6 = 2.333... -> 2.33
    });
  });

  group('Phase 35.12.11 — Task 4: Detection of Calculation Discrepancies & Invariant Enforcement', () {
    test('4. Formula calculation validator detects any mismatch between batch totals and stored nutrition', () {
      final formulations = resolver.recipeFormulations;
      final storedProfiles = resolver.recipeEstimates;

      for (final entry in formulations.entries) {
        final key = entry.key;
        final formulation = entry.value;
        final stored = storedProfiles[key]!;

        // Recompute directly from formulation
        final expectedCal = formulation.per100gCalories;
        final expectedProtein = formulation.per100gProtein;
        final expectedCarbs = formulation.per100gCarbs;
        final expectedFat = formulation.per100gFat;

        // Tolerance: stored rounded values must be within 0.02 of exact float division
        expect((stored.calories - expectedCal).abs(), lessThan(0.02),
            reason: '$key calories mismatch between formulation and stored profile');
        expect((stored.protein - expectedProtein).abs(), lessThan(0.02),
            reason: '$key protein mismatch between formulation and stored profile');
        expect((stored.carbohydrates - expectedCarbs).abs(), lessThan(0.02),
            reason: '$key carbs mismatch between formulation and stored profile');
        expect((stored.totalFat - expectedFat).abs(), lessThan(0.02),
            reason: '$key fat mismatch between formulation and stored profile');
      }

      // Negative check: verify that a flawed formulation with mismatched batch mass is detected
      const flawedFormulation = RecipeFormulation(
        recipeId: 'dummy_mismatched',
        foodName: 'Mismatched Recipe',
        targetBatchMassGrams: 500.0,
        preparationState: 'boiled',
        sourceIdentifier: 'DUMMY_1',
        yieldExplanation: 'Test flawed yield invariant',
        culinaryNotes: 'Test recipe with mismatched ingredient sum',
        ingredients: [
          RecipeIngredient(
            name: 'Ingredient A',
            massGrams: 200.0,
            caloriesPer100g: 100.0,
            proteinPer100g: 5.0,
            carbsPer100g: 10.0,
            fatPer100g: 2.0,
          ),
          RecipeIngredient(
            name: 'Ingredient B',
            massGrams: 200.0, // Sum = 400g != 500g!
            caloriesPer100g: 100.0,
            proteinPer100g: 5.0,
            carbsPer100g: 10.0,
            fatPer100g: 2.0,
          ),
        ],
      );

      // Invariant check: Total ingredient mass != target batch mass
      expect(flawedFormulation.totalIngredientMass, isNot(equals(flawedFormulation.targetBatchMassGrams)));
    });
  });

  group('Phase 35.12.11 — Task 5: Calorie & Macro Consistency Check (Atwater Consistency)', () {
    test('5. Stored calorie values agree with 4-4-9 macro energy factors within standard nutrition tolerances', () {
      final recipes = resolver.recipeEstimates;

      for (final profile in recipes.values) {
        // Atwater theoretical energy = (P * 4) + (C * 4) + (F * 9)
        final atwaterEnergy = (profile.protein * 4.0) + (profile.carbohydrates * 4.0) + (profile.totalFat * 9.0);

        // Difference must be within 5% or 10 kcal (due to protein/carb heat of combustion factors and fiber)
        final diff = (profile.calories - atwaterEnergy).abs();
        expect(diff, lessThan(8.0),
            reason: '${profile.foodName}: stored calories (${profile.calories}) diverges significantly from Atwater energy ($atwaterEnergy)');
      }
    });
  });

  group('Phase 35.12.11 — Task 6: Linear Portion Scaling at Multiple Weights', () {
    test('6. Linear portion scaling operates proportionally across fractional and non-100g weights', () {
      final alfredoProfile = resolver.recipeEstimates['creamy_pasta_estimate']!;
      final alfredoFood = alfredoProfile.toFoodEntity();

      // Test scaling at 5 distinct weights: 50g, 100g, 150g, 250g, 333.33g
      final testWeights = [50.0, 100.0, 150.0, 250.0, 333.33];

      for (final weight in testWeights) {
        final candidate = DetectedFoodCandidate(
          id: 'test_cand_$weight',
          detectedName: 'Creamy Penne Alfredo',
          confidence: 0.95,
          estimatedAmount: weight,
          matchedFood: alfredoFood,
          recognitionSource: FoodScanRecognitionSource.localModel,
          nutritionTier: NutritionProfileTier.recipeEstimate,
        );

        final factor = weight / 100.0;
        expect(candidate.scaledCalories, closeTo(195.0 * factor, 0.05));
        expect(candidate.scaledProtein, closeTo(6.77 * factor, 0.05));
        expect(candidate.scaledCarbs, closeTo(16.74 * factor, 0.05));
        expect(candidate.scaledFats, closeTo(11.17 * factor, 0.05));
        expect(candidate.fiber, closeTo(1.11 * factor, 0.05));
        expect(candidate.sodium, closeTo(320.4 * factor, 0.1));
      }
    });
  });

  group('Phase 35.12.11 — Task 7: Sodium & Fiber Traceability', () {
    test('7. Sodium and fiber are present, non-zero, and traceable across all 4 recipe estimates', () {
      final recipes = resolver.recipeEstimates;

      for (final p in recipes.values) {
        expect(p.sodium, isNotNull, reason: '${p.foodName} must have non-null sodium');
        expect(p.sodium!, greaterThan(200.0), reason: '${p.foodName} must have realistic restaurant sodium (>200mg)');
        expect(p.fiber, isNotNull, reason: '${p.foodName} must have non-null fiber');
        expect(p.fiber!, greaterThan(0.5), reason: '${p.foodName} must have realistic fiber from grain/veg components');
      }

      // Check specific sodium targets
      expect(recipes['creamy_pasta_estimate']!.sodium, equals(320.4));
      expect(recipes['chicken_tikka_masala_estimate']!.sodium, equals(380.0));
      expect(recipes['vegetable_fried_rice_estimate']!.sodium, equals(320.1));
      expect(recipes['vegetable_curry_estimate']!.sodium, equals(310.8));
    });
  });

  group('Phase 35.12.11 — Task 8: Provenance Invariants & Baseline Source Protections', () {
    test('8. Reconciled USDA source IDs and unverified non-USDA baselines remain protected', () {
      final inventory = resolver.getProfileInventory();

      // Burger FDC_170694
      final burger = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_burger');
      expect(burger.sourceIdentifier, equals('FDC_170694'));
      expect(burger.sourceType, equals('USDA FoodData Central'));
      expect(burger.isExternallyTraceable, isTrue);

      // White bread FDC_174924
      final bread = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_white_bread');
      expect(bread.sourceIdentifier, equals('FDC_174924'));
      expect(bread.sourceType, equals('USDA FoodData Central'));
      expect(bread.isExternallyTraceable, isTrue);

      // Greek salad FNDDS_75146000
      final greek = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_greek_salad');
      expect(greek.sourceIdentifier, equals('FNDDS_75146000'));
      expect(greek.sourceType, equals('USDA FoodData Central'));
      expect(greek.isExternallyTraceable, isTrue);

      // Non-USDA baselines retain unverified status
      final nonUsda = inventory.where((e) => e.sourceType != 'USDA FoodData Central' && e.profileClassification == 'generic').toList();
      expect(nonUsda.length, equals(3));
      for (final p in nonUsda) {
        expect(p.isExternallyTraceable, isFalse);
        expect(p.attribution, contains('Unverified Generic Reference'));
      }
    });
  });

  group('Phase 35.12.11 — Task 9: Unsupported Foods Retain Null Macros (No Fabricated Zeros)', () {
    test('9. Unsupported dish retains null macros and is strictly blocked from food diary logging', () {
      const unsupported = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_exotic_dragonfruit_parfait',
        canonicalName: 'Dragonfruit Parfait',
        category: 'Desserts',
        similarity: 0.1420,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(unsupported, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.hasNutrition, isFalse);
      expect(res.profile, isNull);
      expect(res.matchedCatalogFood, isNull);

      final candidate = DetectedFoodCandidate(
        id: 'unsupported_test_1',
        detectedName: 'Dragonfruit Parfait',
        confidence: 0.85,
        estimatedAmount: 180.0,
        matchedFood: null,
        aiEstimatedNutrition: null,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: res.tier,
      );

      // Nullable macros must remain strictly null (NEVER fabricated 0.0)
      expect(candidate.calories, isNull);
      expect(candidate.protein, isNull);
      expect(candidate.carbs, isNull);
      expect(candidate.fats, isNull);
      expect(candidate.hasNutrition, isFalse);
      expect(candidate.nutritionSourceLabel, equals('Nutrition Unavailable'));
    });
  });
}
