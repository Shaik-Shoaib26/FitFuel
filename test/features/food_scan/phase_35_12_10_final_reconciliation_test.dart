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

  final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final resolver = UniversalNutritionResolver();

  group('Phase 35.12.10 — Task 1: Burger Source Conflict Resolution', () {
    test('1. Burger profile canonical ID is FDC_170694 (SR Legacy NDB 21108) and resolves with non-conflicting source', () {
      final inventory = resolver.getProfileInventory();
      final burger = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_burger');

      // Canonical source identifier must be FDC_170694 everywhere (NOT FDC_173307 Egg McMuffin)
      expect(burger.sourceIdentifier, equals('FDC_170694'));
      expect(burger.sourceType, equals('USDA FoodData Central'));
      expect(burger.calories, equals(254.0));
      expect(burger.protein, equals(13.0));
      expect(burger.carbohydrates, equals(29.8));
      expect(burger.totalFat, equals(9.3));
      expect(burger.servingSize, equals(100.0));
      expect(burger.servingUnit, equals('g'));
      expect(burger.isExternallyTraceable, isTrue);
      expect(burger.recipeAssumptions, contains('FDC 170694 / NDB 21108'));
      expect(burger.recipeAssumptions, contains('FDC 173307 Egg McMuffin conflict resolved'));

      const burgerCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_cheeseburger',
        canonicalName: 'Cheeseburger',
        category: 'Burgers',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(burgerCandidate, foodCatalog: const []);
      expect(res.profile?.sourceIdentifier, equals('FDC_170694'));
      expect(res.profile?.sourceIdentifier, isNot(equals('FDC_173307')));
    });
  });

  group('Phase 35.12.10 — Task 2: White Bread Discrepancy Resolution', () {
    test('2. White bread profile is FDC_174924 (NDB 18069) with 49.42g carbs and verified commercial slice data', () {
      final inventory = resolver.getProfileInventory();
      final bread = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_white_bread');

      // Canonical source identifier must be FDC_174924 (NOT FDC_172688 whole-wheat or FDC_172685 toasted rye)
      expect(bread.sourceIdentifier, equals('FDC_174924'));
      expect(bread.sourceType, equals('USDA FoodData Central'));
      expect(bread.calories, equals(265.0));
      expect(bread.protein, equals(8.85));
      expect(bread.carbohydrates, equals(49.42)); // 49.42g per SR Legacy NDB 18069
      expect(bread.totalFat, equals(3.20));
      expect(bread.fiber, equals(2.7));
      expect(bread.sodium, equals(491.0));
      expect(bread.servingSize, equals(100.0));
      expect(bread.servingUnit, equals('g'));
      expect(bread.isExternallyTraceable, isTrue);
      expect(bread.recipeAssumptions, contains('FDC 174924 / NDB 18069'));
    });
  });

  group('Phase 35.12.10 — Task 3: Audit of All 18 Active USDA Profiles', () {
    test('3. Every active USDA generic profile maps to an authoritative, non-conflicting identifier', () {
      final inventory = resolver.getProfileInventory();
      final usdaProfiles = inventory.where((e) => e.sourceType == 'USDA FoodData Central').toList();

      expect(usdaProfiles.length, equals(18), reason: 'Must have exactly 18 active USDA generic profiles');

      // Canonical expected map: profileId -> (expectedSourceId, expectedCalories, expectedProtein, expectedCarbs, expectedFat)
      final expectedUsdaCatalog = <String, (String, double, double, double, double)>{
        'usda_generic_pasta': ('FDC_168936', 131.0, 5.15, 25.0, 1.05),
        'usda_generic_pizza': ('FDC_173292', 266.0, 11.3, 33.3, 9.8),
        'usda_generic_burger': ('FDC_170694', 254.0, 13.0, 29.8, 9.3),
        'usda_generic_white_rice': ('FDC_168878', 130.0, 2.69, 28.17, 0.28),
        'usda_generic_brown_rice': ('FDC_169704', 112.0, 2.32, 23.51, 0.83),
        'usda_generic_white_bread': ('FDC_174924', 265.0, 8.85, 49.42, 3.20),
        'usda_generic_boiled_egg': ('FDC_171287', 155.0, 12.58, 1.12, 10.61),
        'usda_generic_fried_egg': ('FDC_173424', 196.0, 13.61, 0.83, 15.31),
        'usda_generic_green_salad': ('FDC_169248', 20.0, 1.50, 3.80, 0.20),
        'usda_generic_greek_salad': ('FNDDS_75146000', 104.0, 3.20, 4.50, 8.30),
        'usda_generic_apple': ('FDC_171688', 52.0, 0.26, 13.81, 0.17),
        'usda_generic_banana': ('FDC_173944', 89.0, 1.09, 22.84, 0.33),
        'usda_generic_orange': ('FDC_169097', 47.0, 0.94, 11.75, 0.12),
        'usda_generic_strawberry': ('FDC_167762', 32.0, 0.67, 7.68, 0.30),
        'usda_generic_broccoli': ('FDC_170379', 35.0, 2.38, 7.18, 0.41),
        'usda_generic_carrot': ('FDC_170394', 35.0, 0.76, 8.22, 0.18),
        'usda_generic_spinach': ('FDC_170460', 23.0, 2.97, 3.75, 0.26),
        'usda_generic_dal': ('FDC_172421', 116.0, 9.02, 20.13, 0.38),
      };

      for (final profile in usdaProfiles) {
        final expected = expectedUsdaCatalog[profile.canonicalProfileId];
        expect(expected, isNotNull, reason: 'Profile ${profile.canonicalProfileId} must be in USDA catalog');
        expect(profile.sourceIdentifier, equals(expected!.$1),
            reason: '${profile.canonicalProfileId} source identifier mismatch');
        expect(profile.calories, equals(expected.$2),
            reason: '${profile.canonicalProfileId} calories mismatch');
        expect(profile.protein, equals(expected.$3),
            reason: '${profile.canonicalProfileId} protein mismatch');
        expect(profile.carbohydrates, equals(expected.$4),
            reason: '${profile.canonicalProfileId} carbs mismatch');
        expect(profile.totalFat, equals(expected.$5),
            reason: '${profile.canonicalProfileId} fat mismatch');
        expect(profile.servingSize, equals(100.0));
        expect(profile.servingUnit, equals('g'));
        expect(profile.isExternallyTraceable, isTrue);
      }
    });

    test('4. Non-USDA profiles strictly do NOT receive USDA attribution or false traceability', () {
      final inventory = resolver.getProfileInventory();
      final nonUsda = inventory.where((e) => e.sourceType != 'USDA FoodData Central' && e.profileClassification == 'generic').toList();

      expect(nonUsda.length, equals(3));
      for (final p in nonUsda) {
        expect(p.sourceType, equals('Standard Food Composition Reference'));
        expect(p.attribution, contains('Unverified Generic Reference'));
        expect(p.attribution, isNot(contains('USDA')));
        expect(p.isExternallyTraceable, isFalse);
      }
    });
  });

  group('Phase 35.12.10 — Task 4: Reconcile Recipe Estimates & Disclose Calculations', () {
    test('5. Recipe estimates have documented culinary assumptions, batch yields, and non-verified labels', () {
      final inventory = resolver.getProfileInventory();
      final recipeProfiles = inventory.where((e) => e.profileClassification == 'recipe-estimated').toList();

      expect(recipeProfiles.length, equals(4));

      final alfredo = recipeProfiles.firstWhere((p) => p.canonicalProfileId == 'recipe_est_creamy_pasta');
      expect(alfredo.calories, equals(195.0));
      expect(alfredo.protein, equals(6.77));
      expect(alfredo.carbohydrates, equals(16.74));
      expect(alfredo.totalFat, equals(11.17));
      expect(alfredo.sodium, equals(320.4));
      expect(alfredo.recipeAssumptions, contains('Penne pasta tossed with cream, parmesan, and butter'));
      expect(alfredo.sourceType, equals('Culinary Formulation Estimate'));
      expect(alfredo.isExternallyTraceable, isFalse);

      final tikka = recipeProfiles.firstWhere((p) => p.canonicalProfileId == 'recipe_est_chicken_tikka_masala');
      expect(tikka.calories, equals(149.24));
      expect(tikka.protein, equals(16.42));
      expect(tikka.carbohydrates, equals(3.54));
      expect(tikka.totalFat, equals(7.28));
      expect(tikka.sodium, equals(380.0));
      expect(tikka.recipeAssumptions, contains('chicken breast pieces in spiced tomato, cream, onion sauce'));
      expect(tikka.isExternallyTraceable, isFalse);

      final friedRice = recipeProfiles.firstWhere((p) => p.canonicalProfileId == 'recipe_est_veg_fried_rice');
      expect(friedRice.calories, equals(150.80));
      expect(friedRice.protein, equals(2.74));
      expect(friedRice.carbohydrates, equals(22.52));
      expect(friedRice.totalFat, equals(5.30));
      expect(friedRice.sodium, equals(320.1));
      expect(friedRice.recipeAssumptions, contains('Cooked white rice stir-fried with mixed vegetables'));
      expect(friedRice.isExternallyTraceable, isFalse);

      final curry = recipeProfiles.firstWhere((p) => p.canonicalProfileId == 'recipe_est_vegetable_curry');
      expect(curry.calories, equals(73.17));
      expect(curry.protein, equals(1.67));
      expect(curry.carbohydrates, equals(8.00));
      expect(curry.totalFat, equals(3.80));
      expect(curry.sodium, equals(310.8));
      expect(curry.recipeAssumptions, contains('Mixed seasonal vegetables simmered in spiced onion-tomato curry'));
      expect(curry.isExternallyTraceable, isFalse);
    });
  });

  group('Phase 35.12.10 — Task 5: Regression Safeguards & Integrity Protections', () {
    test('6. User-entered manual nutrition remains clearly labeled as user-supplied data', () {
      const customFood = FoodEntity(
        id: 'manual_998877',
        name: 'Homemade Lentil Stew',
        category: 'Manual Entry',
        servingSize: 200.0,
        servingUnit: 'g',
        calories: 140.0,
        protein: 8.0,
        carbohydrates: 22.0,
        fats: 2.0,
        fiber: 4.0,
        sugar: 1.0,
        sodium: 150.0,
        isCustom: true,
      );

      const candidate = DetectedFoodCandidate(
        id: 'user_cand_1',
        detectedName: 'Homemade Lentil Stew',
        confidence: 1.0,
        estimatedAmount: 200.0,
        matchedFood: customFood,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
      );

      expect(candidate.isUserEnteredNutrition, isTrue);
      expect(candidate.nutritionSourceLabel, equals('User-entered nutrition'));
    });

    test('7. Generic Dosa, Roti, and Dal never silently inherit incompatible recipes', () {
      // Dosa
      const dosa = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dosa',
        canonicalName: 'Dosa',
        category: 'South Indian',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resDosa = resolver.resolveCandidate(dosa, foodCatalog: catalog);
      expect(resDosa.matchedCatalogFood?.id, isNot(equals('predefined_masala_dosa')));
      expect(resDosa.tier, equals(NutritionProfileTier.closelyRelatedGeneric));

      // Roti
      const roti = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_roti',
        canonicalName: 'Roti',
        category: 'Indian Breads',
        similarity: 0.1620,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resRoti = resolver.resolveCandidate(roti, foodCatalog: catalog);
      expect(resRoti.matchedCatalogFood?.id, isNot(equals('predefined_roti')));
      expect(resRoti.tier, equals(NutritionProfileTier.closelyRelatedGeneric));

      // Dal
      const dal = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dal',
        canonicalName: 'Dal',
        category: 'Indian Lentils',
        similarity: 0.1580,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resDal = resolver.resolveCandidate(dal, foodCatalog: catalog);
      expect(resDal.matchedCatalogFood?.id, isNot(equals('predefined_dal_tadka')));
      expect(resDal.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
    });

    test('8. Unsupported food dishes retain null macros and strictly block diary logging', () {
      const unsupported = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_truffle_souffle',
        canonicalName: 'Truffle Souffle',
        category: 'French Cuisine',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(unsupported, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.hasNutrition, isFalse);

      final candidate = DetectedFoodCandidate(
        id: 'unsupported_item',
        detectedName: unsupported.displayName,
        confidence: 0.85,
        estimatedAmount: 100.0,
        matchedFood: null,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      final scanResult = FoodScanResult(
        id: 'scan_unsupported_dish',
        imagePath: '/tmp/test.jpg',
        foods: [candidate],
        overallConfidence: 0.85,
        scannedAt: DateTime.now(),
      );

      expect(scanResult.canBeLogged, isFalse);
      expect(candidate.calories, isNull);
      expect(candidate.protein, isNull);
      expect(candidate.carbs, isNull);
      expect(candidate.fats, isNull);
    });

    test('9. Portion scaling remains strictly proportional across both catalog and generic baselines', () {
      final inventory = resolver.getProfileInventory();
      final riceProfile = inventory.firstWhere((p) => p.canonicalProfileId == 'usda_generic_white_rice');

      final riceFood = FoodEntity(
        id: riceProfile.canonicalProfileId,
        name: riceProfile.displayName,
        category: 'Generic Baseline',
        servingSize: riceProfile.servingSize,
        servingUnit: riceProfile.servingUnit,
        calories: riceProfile.calories,
        protein: riceProfile.protein,
        carbohydrates: riceProfile.carbohydrates,
        fats: riceProfile.totalFat,
        fiber: riceProfile.fiber ?? 0.0,
        sugar: riceProfile.sugar ?? 0.0,
        sodium: riceProfile.sodium ?? 0.0,
        isCustom: true,
      );

      final cand100g = DetectedFoodCandidate(
        id: 'rice_scale_100',
        detectedName: 'White Rice',
        confidence: 0.95,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: riceFood,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
      );

      expect(cand100g.scaledCalories, closeTo(130.0, 0.01));
      expect(cand100g.scaledProtein, closeTo(2.69, 0.01));
      expect(cand100g.scaledCarbs, closeTo(28.17, 0.01));
      expect(cand100g.scaledFats, closeTo(0.28, 0.01));

      // Scale to 275g (2.75x)
      final cand275g = cand100g.copyWith(estimatedAmount: 275.0);
      expect(cand275g.scaledCalories, closeTo(130.0 * 2.75, 0.01));
      expect(cand275g.scaledProtein, closeTo(2.69 * 2.75, 0.01));
      expect(cand275g.scaledCarbs, closeTo(28.17 * 2.75, 0.01));
      expect(cand275g.scaledFats, closeTo(0.28 * 2.75, 0.01));
    });
  });
}
