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

  group('Phase 35.12.13 — Task 1: Chicken Tikka Masala Dairy Composite & Full Formulation Reconciliation', () {
    test('1. Dairy composite mass-weighting derives 104.56 kcal/100g and 8.28g fat/100g from declared components', () {
      final formulations = resolver.recipeFormulations;
      final tikka = formulations['chicken_tikka_masala_estimate']!;

      final dairy = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_DAIRY_BLEND');
      expect(dairy.massGrams, equals(75.0));
      expect(dairy.provenanceType, equals(IngredientProvenanceType.definedComposite));
      expect(dairy.components.length, equals(2));

      // Component 1: 50g Whole Milk Yogurt (FDC 171284: 61 kcal, 3.47g P, 4.66g C, 3.25g F, 46mg Na / 100g)
      final yogurt = dairy.components.firstWhere((c) => c.sourceIdentifier == 'FDC_171284');
      expect(yogurt.massGrams, equals(50.0));
      expect(yogurt.calories, closeTo(30.5, 0.01)); // 50 * 61 / 100
      expect(yogurt.sodiumMg, equals(23.0)); // 50 * 46 / 100

      // Component 2: 25g Light Cooking Cream (FDC 170859: 191.67 kcal, 2.83g P, 3.67g C, 18.33g F, 40mg Na / 100g)
      final cream = dairy.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170859');
      expect(cream.massGrams, equals(25.0));
      expect(cream.calories, closeTo(47.92, 0.01)); // 25 * 191.667 / 100
      expect(cream.sodiumMg, equals(10.0)); // 25 * 40 / 100

      // Total 75g blend energy and macros
      final blendCalories = yogurt.calories + cream.calories;
      expect(blendCalories, closeTo(78.42, 0.05)); // 30.5 + 47.92 = 78.42 kcal
      final blendSodium = yogurt.sodiumMg + cream.sodiumMg;
      expect(blendSodium, equals(33.0)); // 23 + 10 = 33 mg

      // Per 100g basis of dairy blend
      expect(dairy.caloriesPer100g, closeTo(104.56, 0.05)); // 78.4167 * 100 / 75 = 104.556
      expect(dairy.proteinPer100g, closeTo(3.26, 0.05)); // (1.735 + 0.708) * 100 / 75 = 3.258
      expect(dairy.carbsPer100g, closeTo(4.33, 0.05)); // (2.33 + 0.917) * 100 / 75 = 4.329
      expect(dairy.fatPer100g, closeTo(8.28, 0.05)); // (1.625 + 4.583) * 100 / 75 = 8.278
      expect(dairy.sodiumMgPer100g, equals(44.0)); // 33 * 100 / 75 = 44 mg

      // Verify the legacy contradictory values (149.33 kcal, 13.33g fat) are eliminated
      expect(dairy.caloriesPer100g, isNot(closeTo(149.33, 1.0)));
      expect(dairy.fatPer100g, isNot(closeTo(13.33, 0.5)));
    });

    test('2. Chicken Tikka Masala 600g batch recalculates to 895.42 kcal and 149.24 kcal/100g', () {
      final formulations = resolver.recipeFormulations;
      final tikka = formulations['chicken_tikka_masala_estimate']!;

      expect(tikka.targetBatchMassGrams, equals(600.0));
      expect(tikka.totalIngredientMass, equals(600.0));

      // Batch nutrient totals from ingredient contributions
      expect(tikka.batchCalories, closeTo(895.42, 0.05));
      expect(tikka.batchProtein, closeTo(98.54, 0.05));
      expect(tikka.batchCarbs, closeTo(21.25, 0.05));
      expect(tikka.batchFat, closeTo(43.71, 0.05));
      expect(tikka.batchSodium, closeTo(2280.05, 0.05));

      // Stored per-100-g profile generated via toUniversalNutritionProfile()
      final profile = resolver.recipeEstimates['chicken_tikka_masala_estimate']!;
      expect(profile.calories, equals(149.24));
      expect(profile.protein, equals(16.42));
      expect(profile.carbohydrates, equals(3.54));
      expect(profile.totalFat, equals(7.28));
      expect(profile.sodium, equals(380.0));
      expect(profile.fiber, equals(0.93));
    });
  });

  group('Phase 35.12.13 — Task 2: Nonzero Seasoning Sodium Accounting Across All Formulations', () {
    test('3. Alfredo seasoning accounts for garlic (1.97mg) and black pepper (0.20mg) sodium', () {
      final formulations = resolver.recipeFormulations;
      final alfredo = formulations['creamy_pasta_estimate']!;

      final seasoning = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_ALFREDO_SEASONING');
      expect(seasoning.components.length, equals(3));

      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final garlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170496');
      final pepper = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170931');

      expect(salt.sodiumMg, closeTo(934.65, 0.05));
      expect(garlic.sodiumMg, closeTo(1.97, 0.05));
      expect(pepper.sodiumMg, closeTo(0.20, 0.05));

      final totalSeasoningSodium = salt.sodiumMg + garlic.sodiumMg + pepper.sodiumMg;
      expect(totalSeasoningSodium, closeTo(936.82, 0.05));

      // Batch sodium: pasta (3.0) + cream (48.0) + butter (2.75) + parmesan (611.60) + seasoning (936.82) = 1602.17 mg
      expect(alfredo.batchSodium, closeTo(1602.17, 0.05));

      // Per 100g sodium: 1602.17 / 5 = 320.4338 -> 320.4 mg stored
      final profile = resolver.recipeEstimates['creamy_pasta_estimate']!;
      expect(profile.sodium, equals(320.4));
    });

    test('4. Fried Rice seasoning accounts for garlic (0.32mg) and white pepper (0.03mg) sodium', () {
      final formulations = resolver.recipeFormulations;
      final friedRice = formulations['vegetable_fried_rice_estimate']!;

      final seasoning = friedRice.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_SOY_SEASONING');
      expect(seasoning.components.length, equals(4));

      final soy = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_174277');
      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final garlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170496');
      final pepper = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170935');

      expect(soy.sodiumMg, equals(549.30));
      expect(salt.sodiumMg, closeTo(1022.05, 0.05));
      expect(garlic.sodiumMg, closeTo(0.32, 0.05));
      expect(pepper.sodiumMg, closeTo(0.025, 0.01));

      // Batch sodium: rice (3.6) + veg (25.0) + oil (0.0) + seasoning (1571.69) = 1600.29 mg
      expect(friedRice.batchSodium, closeTo(1600.29, 0.05));

      // Per 100g sodium: 1600.29 / 5 = 320.058 -> 320.1 mg stored
      final profile = resolver.recipeEstimates['vegetable_fried_rice_estimate']!;
      expect(profile.sodium, equals(320.1));
    });

    test('5. Vegetable Curry seasoning accounts for curry spices (4.16mg) and ginger/garlic (0.64mg) sodium', () {
      final formulations = resolver.recipeFormulations;
      final curry = formulations['vegetable_curry_estimate']!;

      final seasoning = curry.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_CURRY_SPICES');
      expect(seasoning.components.length, equals(3));

      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final spices = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_171323');
      final gingerGarlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');

      expect(salt.sodiumMg, closeTo(1250.99, 0.05));
      expect(spices.sodiumMg, closeTo(4.16, 0.05));
      expect(gingerGarlic.sodiumMg, closeTo(0.64, 0.05));

      // Batch sodium: veg (105.0) + gravy (504.0) + oil (0.0) + seasoning (1255.80) + water (0.0) = 1864.79 mg
      expect(curry.batchSodium, closeTo(1864.79, 0.05));

      // Per 100g sodium: 1864.79 / 6 = 310.799 -> 310.8 mg stored
      final profile = resolver.recipeEstimates['vegetable_curry_estimate']!;
      expect(profile.sodium, equals(310.8));
    });

    test('6. Tikka Masala seasoning accounts for ginger/garlic (2.06mg) and garam masala (2.50mg) sodium', () {
      final formulations = resolver.recipeFormulations;
      final tikka = formulations['chicken_tikka_masala_estimate']!;

      final seasoning = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_TIKKA_SPICE_BLEND');
      expect(seasoning.components.length, equals(3));

      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final gingerGarlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');
      final garamMasala = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GARAM_MASALA');

      expect(salt.sodiumMg, closeTo(1120.49, 0.05));
      expect(gingerGarlic.sodiumMg, closeTo(2.06, 0.05));
      expect(garamMasala.sodiumMg, closeTo(2.50, 0.05));

      // Batch sodium: chicken (222.0) + gravy (900.0) + dairy (33.0) + oil (0.0) + seasoning (1125.05) = 2280.05 mg
      expect(tikka.batchSodium, closeTo(2280.05, 0.05));

      // Per 100g sodium: 2280.05 / 6 = 380.008 -> 380.0 mg stored
      final profile = resolver.recipeEstimates['chicken_tikka_masala_estimate']!;
      expect(profile.sodium, equals(380.0));
    });
  });

  group('Phase 35.12.13 — Task 3: RecipeEnergyValidator Dual-Limit Atwater Consistency & Boundaries', () {
    test('7. All 4 active recipe formulations pass both absolute (<=8.0 kcal) and relative (<=5.0%) limits', () {
      final formulations = resolver.recipeFormulations;

      for (final formulation in formulations.values) {
        final result = formulation.validateCalorieConsistency();
        expect(result.isValid, isTrue,
            reason: '${formulation.foodName} failed calorie consistency: ${result.details}');
        expect(result.absoluteCheckPassed, isTrue);
        expect(result.relativeCheckPassed, isTrue);
        expect(result.absoluteDiscrepancy, lessThanOrEqualTo(8.0));
        expect(result.relativeDiscrepancyPercent, lessThanOrEqualTo(5.0));
      }
    });

    test('8. Boundary tests verify exact dual-limit behavior (absolute <= 8 kcal AND relative <= 5%)', () {
      // Test 1: Both pass comfortably (200 kcal stated vs 196 kcal Atwater: abs = 4 kcal <= 8, rel = 2.0% <= 5%)
      final resultBothPass = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 200.0,
        proteinGrams: 10.0, // 40 kcal
        carbsGrams: 20.0, // 80 kcal
        fatGrams: 8.444444444444445, // 76 kcal -> total 196 kcal
      );
      expect(resultBothPass.isValid, isTrue);
      expect(resultBothPass.absoluteCheckPassed, isTrue);
      expect(resultBothPass.relativeCheckPassed, isTrue);

      // Test 2: Absolute passes but relative FAILS (50 kcal stated vs 46 kcal Atwater: abs = 4 kcal <= 8, but rel = 8.0% > 5%)
      final resultRelativeFails = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 50.0,
        proteinGrams: 2.0, // 8 kcal
        carbsGrams: 5.0, // 20 kcal
        fatGrams: 2.0, // 18 kcal -> total 46 kcal
      );
      expect(resultRelativeFails.absoluteCheckPassed, isTrue);
      expect(resultRelativeFails.relativeCheckPassed, isFalse);
      expect(resultRelativeFails.isValid, isFalse, reason: 'Must fail when relative discrepancy exceeds 5%');

      // Test 3: Relative passes but absolute FAILS (300 kcal stated vs 286 kcal Atwater: abs = 14 kcal > 8, rel = 4.67% <= 5%)
      final resultAbsoluteFails = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 300.0,
        proteinGrams: 20.0, // 80 kcal
        carbsGrams: 30.0, // 120 kcal
        fatGrams: 9.555555555555555, // 86 kcal -> total 286 kcal
      );
      expect(resultAbsoluteFails.relativeCheckPassed, isTrue);
      expect(resultAbsoluteFails.absoluteCheckPassed, isFalse);
      expect(resultAbsoluteFails.isValid, isFalse, reason: 'Must fail when absolute discrepancy exceeds 8 kcal');

      // Test 4: Low-energy food (< 10 kcal/100g) where relative check is not evaluated
      // 5 kcal stated vs 4 kcal Atwater: abs = 1 kcal <= 8, rel check is not evaluated
      final resultLowEnergyPass = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 5.0,
        proteinGrams: 0.5, // 2 kcal
        carbsGrams: 0.5, // 2 kcal
        fatGrams: 0.0, // 0 kcal -> total 4 kcal
      );
      expect(resultLowEnergyPass.isValid, isTrue);
      expect(resultLowEnergyPass.absoluteCheckPassed, isTrue);
      expect(resultLowEnergyPass.relativeCheckPassed, isTrue);
      expect(resultLowEnergyPass.relativeCheckEvaluated, isFalse);
      expect(resultLowEnergyPass.relativeDiscrepancyPercent, isNull);

      // Test 5: Low-energy food where absolute check fails (5 kcal stated vs 15 kcal Atwater: abs = 10 kcal > 8)
      final resultLowEnergyFail = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 5.0,
        proteinGrams: 1.0, // 4 kcal
        carbsGrams: 1.0, // 4 kcal
        fatGrams: 0.7777777777777778, // 7 kcal -> total 15 kcal
      );
      expect(resultLowEnergyFail.absoluteCheckPassed, isFalse);
      expect(resultLowEnergyFail.isValid, isFalse);
    });
  });

  group('Phase 35.12.13 — Task 4: Invariants, Scaling & Negative Safety Protections', () {
    test('9. Portion scaling maintains proportionality with reconciled values', () {
      final tikkaEntity = resolver.recipeEstimates['chicken_tikka_masala_estimate']!.toFoodEntity();

      final candidate = DetectedFoodCandidate(
        id: 'scaling_tikka_250g',
        detectedName: 'Chicken Tikka Masala',
        confidence: 0.94,
        estimatedAmount: 250.0, // 2.5x portion
        matchedFood: tikkaEntity,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.recipeEstimate,
      );

      expect(candidate.scaledCalories, closeTo(149.24 * 2.5, 0.05));
      expect(candidate.scaledProtein, closeTo(16.42 * 2.5, 0.05));
      expect(candidate.scaledCarbs, closeTo(3.54 * 2.5, 0.05));
      expect(candidate.scaledFats, closeTo(7.28 * 2.5, 0.05));
      expect(candidate.sodium, closeTo(380.0 * 2.5, 0.1));
    });

    test('10. Unsupported food dish retains null macros and is never assigned recipe estimates', () {
      const unsupported = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_unsupported_dragonfruit_parfait',
        canonicalName: 'Dragonfruit Parfait',
        category: 'Desserts',
        similarity: 0.1250,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(unsupported, foodCatalog: catalog);
      expect(res.profile, isNull);
      expect(res.matchedCatalogFood, isNull);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
    });
  });
}
