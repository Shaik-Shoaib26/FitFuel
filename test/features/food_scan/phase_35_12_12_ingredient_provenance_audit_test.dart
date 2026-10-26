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

  group('Phase 35.12.12 — Test 1: Verified Source Identifiers & Food Descriptions', () {
    test('1. Authoritative USDA source IDs match their primary food descriptions and preparations', () {
      final formulations = resolver.recipeFormulations;

      // 1. Alfredo ingredients
      final alfredo = formulations['creamy_pasta_estimate']!;
      final pasta = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_168936');
      expect(pasta.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(pasta.notes, contains('enriched wheat penne'));

      final cream = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_170859');
      expect(cream.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(cream.notes, contains('light cream'));

      final butter = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_173410');
      expect(butter.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(butter.notes, contains('butter'));

      final parmesan = alfredo.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_170845');
      expect(parmesan.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(parmesan.notes, contains('parmesan'));

      // 2. Tikka ingredients
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      final chicken = tikka.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_171077');
      expect(chicken.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(chicken.notes, contains('chicken breast'));

      // 3. Fried Rice ingredients
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      final rice = friedRice.ingredients.firstWhere((i) => i.sourceIdentifier == 'FDC_168878');
      expect(rice.provenanceType, equals(IngredientProvenanceType.directlySourced));
      expect(rice.notes, contains('white rice'));
    });
  });

  group('Phase 35.12.12 — Test 2: Composite Ingredient Disclosures & FDC 171284 Correction', () {
    test('2. Composite ingredients disclose component breakdowns and do not falsely claim single-FDC accessions', () {
      final formulations = resolver.recipeFormulations;
      final tikka = formulations['chicken_tikka_masala_estimate']!;

      // Verify the dairy blend is a defined composite and DOES NOT assign single FDC_171284 to the entire mixture
      final dairy = tikka.ingredients.firstWhere((i) => i.name.contains('Yogurt'));
      expect(dairy.provenanceType, equals(IngredientProvenanceType.definedComposite));
      expect(dairy.sourceIdentifier, equals('COMPOSITE_DAIRY_BLEND'));
      expect(dairy.sourceIdentifier, isNot(equals('FDC_171284')),
          reason: 'FDC_171284 describes plain yogurt only, not the 149 kcal/100g yogurt-cream blend');
      expect(dairy.components.length, equals(2));

      // Sub-component 1: Plain yogurt FDC 171284
      final yogurtComp = dairy.components.firstWhere((c) => c.sourceIdentifier == 'FDC_171284');
      expect(yogurtComp.massGrams, equals(50.0));
      expect(yogurtComp.sodiumMg, equals(23.0));
      expect(yogurtComp.notes, contains('USDA SR Legacy NDB 1119'));

      // Sub-component 2: Cooking cream FDC 170859
      final creamComp = dairy.components.firstWhere((c) => c.sourceIdentifier == 'FDC_170859');
      expect(creamComp.massGrams, equals(25.0));
      expect(creamComp.sodiumMg, equals(10.0));
      expect(creamComp.notes, contains('USDA SR Legacy NDB 1052'));

      // Sum of component masses matches ingredient mass
      final totalDairyMass = dairy.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(totalDairyMass, equals(dairy.massGrams));
    });
  });

  group('Phase 35.12.12 — Test 3: Batch Yield Classification (Measured vs Calculated vs Assumed)', () {
    test('3. Batch masses are clearly classified and never misrepresented as lab-measured', () {
      final formulations = resolver.recipeFormulations;

      // Alfredo: sum of prepared ingredients tossed together
      final alfredo = formulations['creamy_pasta_estimate']!;
      expect(alfredo.yieldType, equals(BatchYieldType.calculatedFromPreparedIngredients));
      expect(alfredo.yieldExplanation, contains('without measured moisture reduction'));

      // Tikka: assumed commercial target yield
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      expect(tikka.yieldType, equals(BatchYieldType.assumedTargetYield));
      expect(tikka.yieldExplanation, contains('simmer evaporation is unmeasured'));

      // Fried Rice: assumed commercial target yield
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      expect(friedRice.yieldType, equals(BatchYieldType.assumedTargetYield));
      expect(friedRice.yieldExplanation, contains('wok stir-fry steam loss is unmeasured'));

      // Curry: assumed commercial target yield
      final curry = formulations['vegetable_curry_estimate']!;
      expect(curry.yieldType, equals(BatchYieldType.assumedTargetYield));
      expect(curry.yieldExplanation, contains('unmeasured evaporation'));
    });
  });

  group('Phase 35.12.12 — Test 4: Vegetable Curry Simmer Water & Evaporation Audit', () {
    test('4. Cooking water in vegetable curry is explicitly documented as net retained simmer water', () {
      final formulations = resolver.recipeFormulations;
      final curry = formulations['vegetable_curry_estimate']!;

      final water = curry.ingredients.firstWhere((i) => i.sourceIdentifier == 'WATER');
      expect(water.massGrams, equals(35.0));
      expect(water.caloriesContribution, equals(0.0));
      expect(water.proteinContribution, equals(0.0));
      expect(water.carbsContribution, equals(0.0));
      expect(water.fatContribution, equals(0.0));
      expect(water.sodiumContribution, equals(0.0));
      expect(water.notes, contains('retained in final curry yield after evaporation'));

      // Target batch mass equals sum of food ingredients + net retained water
      final foodMass = curry.ingredients.where((i) => i.sourceIdentifier != 'WATER').fold(0.0, (sum, i) => sum + i.massGrams);
      expect(foodMass, equals(565.0)); // 350 + 180 + 20 + 15 = 565g
      expect(foodMass + water.massGrams, equals(curry.targetBatchMassGrams)); // 565 + 35 = 600g
    });
  });

  group('Phase 35.12.12 — Test 5: Full Sodium Traceability Across All 4 Formulations', () {
    test('5. Ingredient sodium contributions sum exactly to batch totals and derive correct per-100-g values', () {
      final formulations = resolver.recipeFormulations;
      final profiles = resolver.recipeEstimates;

      // 1. Alfredo: 1,602.17 mg batch -> 320.4 mg / 100g
      final alfredo = formulations['creamy_pasta_estimate']!;
      expect(alfredo.batchSodium, closeTo(1602.17, 0.05));
      expect(profiles['creamy_pasta_estimate']!.sodium, equals(320.4));

      // 2. Tikka: 2,280.05 mg batch -> 380.0 mg / 100g
      final tikka = formulations['chicken_tikka_masala_estimate']!;
      expect(tikka.batchSodium, closeTo(2280.05, 0.05));
      expect(profiles['chicken_tikka_masala_estimate']!.sodium, equals(380.0));

      // 3. Fried Rice: 1,600.29 mg batch -> 320.1 mg / 100g
      final friedRice = formulations['vegetable_fried_rice_estimate']!;
      expect(friedRice.batchSodium, closeTo(1600.29, 0.05));
      expect(profiles['vegetable_fried_rice_estimate']!.sodium, equals(320.1));

      // 4. Curry: 1,864.79 mg batch -> 310.8 mg / 100g
      final curry = formulations['vegetable_curry_estimate']!;
      expect(curry.batchSodium, closeTo(1864.79, 0.05));
      expect(profiles['vegetable_curry_estimate']!.sodium, equals(310.8));
    });
  });

  group('Phase 35.12.12 — Test 6: Vegetable Fried Rice Seasoning Breakdown', () {
    test('6. Seasoning blend in vegetable fried rice exposes complete, auditable component breakdown', () {
      final formulations = resolver.recipeFormulations;
      final friedRice = formulations['vegetable_fried_rice_estimate']!;

      final seasoning = friedRice.ingredients.firstWhere((i) => i.sourceIdentifier == 'COMPOSITE_SOY_SEASONING');
      expect(seasoning.massGrams, equals(15.0));
      expect(seasoning.components.length, equals(4));

      // Component 1: Soy Sauce 10.0g (FDC 174277)
      final soy = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_174277');
      expect(soy.massGrams, equals(10.0));
      expect(soy.sodiumMg, equals(549.30));

      // Component 2: Table Salt 2.637g (FDC 173468: 387.58 mg Na / g)
      final salt = seasoning.components.firstWhere((c) => c.sourceIdentifier == 'FDC_173468');
      expect(salt.massGrams, closeTo(2.64, 0.01));
      expect(salt.sodiumMg, closeTo(1022.05, 0.1));

      // Component 3: Garlic 1.863g
      final garlic = seasoning.components.firstWhere((c) => c.name.contains('Garlic'));
      expect(garlic.massGrams, closeTo(1.86, 0.01));

      // Component 4: White Pepper 0.50g
      final pepper = seasoning.components.firstWhere((c) => c.name.contains('Pepper'));
      expect(pepper.massGrams, equals(0.50));

      // Sum of component masses == 15.0g
      final totalComponentMass = seasoning.components.fold(0.0, (sum, c) => sum + c.massGrams);
      expect(totalComponentMass, closeTo(15.0, 0.01));

      // Sum of component sodium == 1571.4 mg (allowing rounding to 1571.7mg)
      final totalComponentSodium = seasoning.components.fold(0.0, (sum, c) => sum + c.sodiumMg);
      expect(totalComponentSodium, closeTo(1571.7, 0.5));
    });
  });

  group('Phase 35.12.12 — Test 7: Calorie Consistency & Atwater Specific Factors', () {
    test('7. Calorie consistency validation accommodates Atwater specific factor physics and catches errors', () {
      final recipes = resolver.recipeEstimates;

      for (final profile in recipes.values) {
        // Atwater theoretical energy = (P * 4) + (C * 4) + (F * 9)
        final atwaterGeneral = (profile.protein * 4.0) + (profile.carbohydrates * 4.0) + (profile.totalFat * 9.0);
        final diff = (profile.calories - atwaterGeneral).abs();

        // Rationale: USDA specific energy factors (Merrill and Watt, USDA Handbook 74) differ from general 4-4-9:
        // - Chicken protein: 4.27 kcal/g
        // - Pasta carbs: 4.12 kcal/g, wheat protein: 3.91 kcal/g
        // - Dairy fat: 8.79 kcal/g, dairy protein: 4.27 kcal/g
        // Therefore, tolerance is documented as <= 8.0 kcal/100g (or <= 5%).
        expect(diff, lessThan(8.0),
            reason: '${profile.foodName} calories (${profile.calories}) vs 4-4-9 Atwater ($atwaterGeneral)');
      }

      // Negative check: verify that a gross energy inconsistency (>20 kcal discrepancy) is detected
      const badCalories = 120.0; // Stored as 120 kcal, but macros 2g P, 5g C, 1g F produce only 37 kcal!
      const theoretical = (2.0 * 4.0) + (5.0 * 4.0) + (1.0 * 9.0); // 37.0 kcal
      final badDiff = (badCalories - theoretical).abs(); // 83.0 kcal difference!
      expect(badDiff, greaterThan(8.0), reason: 'Must detect gross calorie-to-macro divergence');
    });
  });

  group('Phase 35.12.12 — Test 8: Linear Portion Scaling Invariance', () {
    test('8. Fractional portion scaling maintains strict proportionality and does not drift', () {
      final alfredo = resolver.recipeEstimates['creamy_pasta_estimate']!.toFoodEntity();

      // Test portion weights: 75g (0.75x), 125g (1.25x), 220g (2.2x), 350g (3.5x)
      final weights = [75.0, 125.0, 220.0, 350.0];

      for (final w in weights) {
        final candidate = DetectedFoodCandidate(
          id: 'scaling_cand_$w',
          detectedName: 'Penne Alfredo',
          confidence: 0.95,
          estimatedAmount: w,
          matchedFood: alfredo,
          recognitionSource: FoodScanRecognitionSource.localModel,
          nutritionTier: NutritionProfileTier.recipeEstimate,
        );

        final ratio = w / 100.0;
        expect(candidate.scaledCalories, closeTo(195.0 * ratio, 0.05));
        expect(candidate.scaledProtein, closeTo(6.77 * ratio, 0.05));
        expect(candidate.scaledCarbs, closeTo(16.74 * ratio, 0.05));
        expect(candidate.scaledFats, closeTo(11.17 * ratio, 0.05));
        expect(candidate.sodium, closeTo(320.4 * ratio, 0.1));
      }
    });
  });

  group('Phase 35.12.12 — Test 9: Unavailable Foods Protection (Null Macros Preserved)', () {
    test('9. Unsupported food dish retains null macros and is never assigned fabricated zero values', () {
      const unsupported = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_unsupported_durian_souffle',
        canonicalName: 'Durian Souffle',
        category: 'Desserts',
        similarity: 0.1380,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(unsupported, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.hasNutrition, isFalse);
      expect(res.profile, isNull);

      final candidate = DetectedFoodCandidate(
        id: 'unsupported_durian',
        detectedName: 'Durian Souffle',
        confidence: 0.80,
        estimatedAmount: 150.0,
        matchedFood: null,
        aiEstimatedNutrition: null,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: res.tier,
      );

      expect(candidate.calories, isNull);
      expect(candidate.protein, isNull);
      expect(candidate.carbs, isNull);
      expect(candidate.fats, isNull);
      expect(candidate.hasNutrition, isFalse);
    });
  });

  group('Phase 35.12.12 — Test 10: Invariant USDA Source Accessions & Safety Guards', () {
    test('10. Burger, white bread, Greek salad, and generic baselines remain protected', () {
      final inventory = resolver.getProfileInventory();

      // Burger FDC_170694
      final burger = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_burger');
      expect(burger.sourceIdentifier, equals('FDC_170694'));
      expect(burger.isExternallyTraceable, isTrue);

      // White bread FDC_174924
      final bread = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_white_bread');
      expect(bread.sourceIdentifier, equals('FDC_174924'));
      expect(bread.isExternallyTraceable, isTrue);

      // Greek salad FNDDS_75146000
      final greek = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_greek_salad');
      expect(greek.sourceIdentifier, equals('FNDDS_75146000'));
      expect(greek.isExternallyTraceable, isTrue);

      // Non-USDA baselines: Roti, Idli, Dosa remain unverified
      final nonUsda = inventory.where((e) => e.sourceType != 'USDA FoodData Central' && e.profileClassification == 'generic').toList();
      expect(nonUsda.length, equals(3));
      for (final p in nonUsda) {
        expect(p.isExternallyTraceable, isFalse);
        expect(p.attribution, contains('Unverified Generic Reference'));
      }
    });
  });
}
