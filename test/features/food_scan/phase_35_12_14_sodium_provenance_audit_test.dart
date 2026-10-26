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

  group('Phase 35.12.14 — Task 1: Exact Table-Salt Sodium Concentration & Arithmetic', () {
    test('1. Table salt concentration 387.58 mg/g computes exact sodium across all 4 recipes', () {
      const saltConcentration = 387.58; // mg Na / g salt (USDA FDC 173468 / NDB 2047: 38,758 mg/100g)

      // 1. Alfredo salt: 2.4115g
      const alfredoSalt = 2.4115 * saltConcentration;
      expect(alfredoSalt, closeTo(934.64917, 0.0001));

      // 2. Fried rice salt: 2.637g
      const friedRiceSalt = 2.637 * saltConcentration;
      expect(friedRiceSalt, closeTo(1022.04846, 0.0001));

      // 3. Curry salt: 3.2277g
      const currySalt = 3.2277 * saltConcentration;
      expect(currySalt, closeTo(1250.991966, 0.0001));

      // 4. Tikka salt: 2.891g
      const tikkaSalt = 2.891 * saltConcentration;
      expect(tikkaSalt, closeTo(1120.49378, 0.0001));
    });
  });

  group('Phase 35.12.14 — Task 2: Seasoning Component Sums, Blend Masses & No Double Counting', () {
    test('2. Alfredo seasoning: declared mass is 15.0g and component sodium sums to 936.82 mg', () {
      final alfredo = resolver.recipeFormulations['creamy_pasta_estimate']!;
      final seasoning = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_ALFREDO_SEASONING');

      expect(seasoning.massGrams, equals(15.0));
      final componentMassSum = seasoning.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(componentMassSum, closeTo(15.0, 0.0001));

      // Disclosed components
      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final garlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170496');
      final pepper = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170931');

      expect(salt.massGrams, equals(2.4115));
      expect(salt.sodiumMg, closeTo(934.64917, 0.001));
      expect(garlic.massGrams, equals(11.5885));
      expect(garlic.sodiumMg, closeTo(1.970045, 0.001)); // 11.5885 * 0.17
      expect(pepper.massGrams, equals(1.00));
      expect(pepper.sodiumMg, closeTo(0.20, 0.001)); // 1.00 * 0.20

      // No double counting: seasoning totalComponentSodium equals its sodiumContribution
      expect(seasoning.totalComponentSodium, closeTo(936.819215, 0.001));
      expect(seasoning.sodiumContribution, closeTo(seasoning.totalComponentSodium, 0.001));
    });

    test('3. Fried Rice seasoning: declared mass is 15.0g and component sodium sums to 1,571.69 mg', () {
      final friedRice = resolver.recipeFormulations['vegetable_fried_rice_estimate']!;
      final seasoning = friedRice.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_SOY_SEASONING');

      expect(seasoning.massGrams, equals(15.0));
      final componentMassSum = seasoning.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(componentMassSum, closeTo(15.0, 0.0001));

      final soy = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_174277');
      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final garlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170496');
      final pepper = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170935');

      expect(soy.massGrams, equals(10.00));
      expect(soy.sodiumMg, closeTo(549.30, 0.001));
      expect(salt.massGrams, equals(2.637));
      expect(salt.sodiumMg, closeTo(1022.04846, 0.001));
      expect(garlic.massGrams, equals(1.863));
      expect(garlic.sodiumMg, closeTo(0.31671, 0.001)); // 1.863 * 0.17
      expect(pepper.massGrams, equals(0.50));
      expect(pepper.sodiumMg, closeTo(0.025, 0.001)); // 0.50 * 0.05

      expect(seasoning.totalComponentSodium, closeTo(1571.69017, 0.001));
      expect(seasoning.sodiumContribution, closeTo(seasoning.totalComponentSodium, 0.001));
    });

    test('4. Vegetable Curry seasoning: declared mass is 15.0g and component sodium sums to 1,255.80 mg', () {
      final curry = resolver.recipeFormulations['vegetable_curry_estimate']!;
      final seasoning = curry.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_CURRY_SPICES');

      expect(seasoning.massGrams, equals(15.0));
      final componentMassSum = seasoning.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(componentMassSum, closeTo(15.0, 0.0001));

      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final curryPowder = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_171323');
      final gingerGarlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');

      expect(salt.massGrams, equals(3.2277));
      expect(salt.sodiumMg, closeTo(1250.991966, 0.001));
      expect(curryPowder.massGrams, equals(8.00));
      expect(curryPowder.sodiumMg, closeTo(4.16, 0.001)); // 8.00 * 0.52
      expect(curryPowder.sourceIdentifier, equals('FDC_171323')); // Verified USDA accession
      expect(gingerGarlic.massGrams, equals(3.7723));
      expect(gingerGarlic.sodiumMg, closeTo(0.641291, 0.001)); // 3.7723 * 0.17

      expect(seasoning.totalComponentSodium, closeTo(1255.793257, 0.001));
      expect(seasoning.sodiumContribution, closeTo(seasoning.totalComponentSodium, 0.001));
    });

    test('5. Tikka Masala seasoning: declared mass is 20.0g and component sodium sums to 1,125.05 mg', () {
      final tikka = resolver.recipeFormulations['chicken_tikka_masala_estimate']!;
      final seasoning = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_TIKKA_SPICE_BLEND');

      expect(seasoning.massGrams, equals(20.0));
      final componentMassSum = seasoning.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(componentMassSum, closeTo(20.0, 0.0001));

      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      final gingerGarlic = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');
      final garamMasala = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GARAM_MASALA');

      expect(salt.massGrams, equals(2.891));
      expect(salt.sodiumMg, closeTo(1120.49378, 0.001));
      expect(gingerGarlic.massGrams, equals(12.109));
      expect(gingerGarlic.sodiumMg, closeTo(2.05853, 0.001)); // 12.109 * 0.17
      expect(garamMasala.massGrams, equals(5.00));
      expect(garamMasala.sodiumMg, closeTo(2.50, 0.001)); // 5.00 * 0.50

      expect(seasoning.totalComponentSodium, closeTo(1125.05231, 0.001));
      expect(seasoning.sodiumContribution, closeTo(seasoning.totalComponentSodium, 0.001));
    });
  });

  group('Phase 35.12.14 — Task 3: Complete Batch Sodium Summation & Derived Per-100-g Profiles', () {
    test('6. Batch sodium sums reproduce arithmetic checkpoints exactly and derive correct per-100-g profiles', () {
      final formulations = resolver.recipeFormulations;
      final profiles = resolver.recipeEstimates;

      // 1. Alfredo: 1,602.17 mg batch -> 320.43 mg unrounded / 320.4 mg stored
      final alfredo = formulations['creamy_pasta_estimate']!;
      expect(alfredo.batchSodium, closeTo(1602.169215, 0.01));
      expect(alfredo.per100gSodium, closeTo(320.433843, 0.01));
      expect(profiles['creamy_pasta_estimate']!.sodium, equals(320.4));

      // 2. Fried Rice: 1,600.29 mg batch -> 320.06 mg unrounded / 320.1 mg stored
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      expect(friedRice.batchSodium, closeTo(1600.29017, 0.01));
      expect(friedRice.per100gSodium, closeTo(320.058034, 0.01));
      expect(profiles['vegetable_fried_rice_estimate']!.sodium, equals(320.1));

      // 3. Vegetable Curry: 1,864.79 mg batch -> 310.80 mg unrounded / 310.8 mg stored
      final curry = formulations['vegetable_curry_estimate']!;
      expect(curry.batchSodium, closeTo(1864.793257, 0.01));
      expect(curry.per100gSodium, closeTo(310.798876, 0.01));
      expect(profiles['vegetable_curry_estimate']!.sodium, equals(310.8));

      // 4. Tikka Masala: 2,280.05 mg batch -> 380.01 mg unrounded / 380.0 mg stored
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      expect(tikka.batchSodium, closeTo(2280.05231, 0.01));
      expect(tikka.per100gSodium, closeTo(380.008718, 0.01));
      expect(profiles['chicken_tikka_masala_estimate']!.sodium, equals(380.0));
    });
  });

  group('Phase 35.12.14 — Task 4: Seasoning Provenance Consistency & Ginger/Garlic Transparency', () {
    test('7. Curry powder is directly sourced from USDA FDC 171323 and ginger/garlic is documented as an approximation', () {
      final formulations = resolver.recipeFormulations;

      // 1. Curry powder in Vegetable Curry
      final curry = formulations['vegetable_curry_estimate']!;
      final currySeasoning = curry.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_CURRY_SPICES');
      final curryPowder = currySeasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_171323');
      expect(curryPowder.notes, contains('USDA SR Legacy FDC 171323'));
      expect(curryPowder.notes, contains('52.0 mg Na / 100g'));

      // 2. Ginger and garlic in Vegetable Curry
      final curryGingerGarlic = currySeasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');
      expect(curryGingerGarlic.notes, contains('FDC 169231')); // Ginger cited
      expect(curryGingerGarlic.notes, contains('FDC 170496')); // Garlic cited
      expect(curryGingerGarlic.notes, contains('culinary baseline approximation'));

      // 3. Ginger and garlic in Tikka Masala
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      final tikkaSeasoning = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_TIKKA_SPICE_BLEND');
      final tikkaGingerGarlic = tikkaSeasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GINGER_GARLIC');
      expect(tikkaGingerGarlic.notes, contains('FDC 169231'));
      expect(tikkaGingerGarlic.notes, contains('FDC 170496'));
      expect(tikkaGingerGarlic.notes, contains('culinary baseline approximation'));

      // 4. Garam Masala in Tikka Masala
      final garamMasala = tikkaSeasoning.components.firstWhere((c) => c.sourceIdentifier == 'EST_GARAM_MASALA');
      expect(garamMasala.notes, contains('Culinary baseline estimate'));
    });
  });

  group('Phase 35.12.14 — Task 5: Calorie Consistency, Low-Energy Representation & Guardrails', () {
    test('8. When relative calorie check is skipped for low-energy foods, it is represented as not evaluated', () {
      // 5 kcal food (< 10 kcal threshold): relative check must be not evaluated (null discrepancy, evaluated=false)
      final lowEnergyResult = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 5.0,
        proteinGrams: 0.5,
        carbsGrams: 0.5,
        fatGrams: 0.0,
      );
      expect(lowEnergyResult.isValid, isTrue);
      expect(lowEnergyResult.absoluteCheckPassed, isTrue);
      expect(lowEnergyResult.relativeCheckPassed, isTrue);
      expect(lowEnergyResult.relativeCheckEvaluated, isFalse);
      expect(lowEnergyResult.relativeDiscrepancyPercent, isNull);
      expect(lowEnergyResult.details, contains('not evaluated'));

      // Standard food (> 10 kcal): relative check evaluated
      final normalResult = RecipeEnergyValidator.validateAtwaterConsistency(
        statedCalories: 150.0,
        proteinGrams: 10.0,
        carbsGrams: 15.0,
        fatGrams: 5.0,
      );
      expect(normalResult.relativeCheckEvaluated, isTrue);
      expect(normalResult.relativeDiscrepancyPercent, isNotNull);
    });

    test('9. Dairy composite mass-weighting and Tikka batch calories remain fully preserved', () {
      final tikka = resolver.recipeFormulations['chicken_tikka_masala_estimate']!;
      final dairy = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_DAIRY_BLEND');

      expect(dairy.caloriesPer100g, closeTo(104.56, 0.05));
      expect(dairy.fatPer100g, closeTo(8.28, 0.05));
      expect(tikka.batchCalories, closeTo(895.42, 0.05));
      expect(resolver.recipeEstimates['chicken_tikka_masala_estimate']!.calories, equals(149.24));
    });

    test('10. Portion scaling and unavailable food diary blocking safeguards remain strictly enforced', () {
      // 1. Portion scaling proportionality with reconciled sodium
      final alfredoFood = resolver.recipeEstimates['creamy_pasta_estimate']!.toFoodEntity();
      final cand150g = DetectedFoodCandidate(
        id: 'scale_150g',
        detectedName: 'Penne Alfredo',
        confidence: 0.95,
        estimatedAmount: 150.0,
        matchedFood: alfredoFood,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.recipeEstimate,
      );
      expect(cand150g.scaledCalories, closeTo(195.0 * 1.5, 0.05));
      expect(cand150g.sodium, closeTo(320.4 * 1.5, 0.05));

      // 2. Unavailable food safeguards
      const unavailable = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_unsupported_passionfruit_souffle',
        canonicalName: 'Passionfruit Souffle',
        category: 'Desserts',
        similarity: 0.1150,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final res = resolver.resolveCandidate(unavailable, foodCatalog: catalog);
      expect(res.profile, isNull);
      expect(res.matchedCatalogFood, isNull);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
    });
  });
}
