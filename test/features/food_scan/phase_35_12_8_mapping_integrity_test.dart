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

  group('Phase 35.12.8 — Task 1: Audit Nutrition Mappings & Eliminate Unsafe Substitutions', () {
    test('1. Generic Dosa does NOT silently resolve to specific Masala Dosa recipe', () {
      const genericDosaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dosa',
        canonicalName: 'Dosa',
        category: 'South Indian',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resGeneric = resolver.resolveCandidate(genericDosaCandidate, foodCatalog: catalog);
      // Must NOT be Masala Dosa
      expect(resGeneric.matchedCatalogFood?.id, isNot(equals('predefined_masala_dosa')));
      expect(resGeneric.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resGeneric.explanation, contains('fermented dosa crepe'));

      // Explicit Masala Dosa candidate genuinely matches Masala Dosa recipe
      const masalaDosaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_masala_dosa',
        canonicalName: 'Masala Dosa',
        category: 'South Indian',
        similarity: 0.1700,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resMasala = resolver.resolveCandidate(masalaDosaCandidate, foodCatalog: catalog);
      expect(resMasala.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resMasala.matchedCatalogFood?.id, equals('predefined_masala_dosa'));
      expect(resMasala.matchedCatalogFood?.name, equals('Masala Dosa'));
      expect(resMasala.matchedCatalogFood?.calories, equals(220.0)); // Masala dosa: 220 kcal/100g

      // Explicit Plain Dosa candidate genuinely matches Plain Dosa in catalog
      const plainDosaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_plain_dosa',
        canonicalName: 'Plain Dosa',
        category: 'South Indian',
        similarity: 0.1680,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resPlain = resolver.resolveCandidate(plainDosaCandidate, foodCatalog: catalog);
      expect(resPlain.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resPlain.matchedCatalogFood?.id, equals('predefined_dosa'));
      expect(resPlain.matchedCatalogFood?.name, equals('Plain Dosa'));
      expect(resPlain.matchedCatalogFood?.calories, equals(168.0)); // Plain dosa: 168 kcal/100g
    });

    test('2. Generic Roti does NOT silently resolve to restaurant Tandoori Roti recipe', () {
      const genericRotiCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_roti',
        canonicalName: 'Roti',
        category: 'Indian Breads',
        similarity: 0.1620,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resGeneric = resolver.resolveCandidate(genericRotiCandidate, foodCatalog: catalog);
      // Must NOT map to predefined_roti (which is Tandoori Roti in FitFuel catalog)
      expect(resGeneric.matchedCatalogFood?.id, isNot(equals('predefined_roti')));
      expect(resGeneric.matchedCatalogFood?.name, isNot(equals('Tandoori Roti')));
      expect(resGeneric.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resGeneric.profile?.sourceIdentifier, equals('REF_WHOLE_WHEAT_FLATBREAD'));

      // Explicit Tandoori Roti candidate genuinely matches Tandoori Roti
      const tandooriRotiCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_tandoori_roti',
        canonicalName: 'Tandoori Roti',
        category: 'Indian Breads',
        similarity: 0.1700,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resTandoori = resolver.resolveCandidate(tandooriRotiCandidate, foodCatalog: catalog);
      expect(resTandoori.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resTandoori.matchedCatalogFood?.id, equals('predefined_roti'));
      expect(resTandoori.matchedCatalogFood?.name, equals('Tandoori Roti'));
      expect(resTandoori.matchedCatalogFood?.calories, equals(120.0)); // Tandoori roti: 120 kcal/50g

      // Chapati and Phulka genuinely match Chapati in catalog
      const chapatiCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_chapati',
        canonicalName: 'Chapati',
        category: 'Indian Breads',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resChapati = resolver.resolveCandidate(chapatiCandidate, foodCatalog: catalog);
      expect(resChapati.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resChapati.matchedCatalogFood?.id, equals('predefined_chapati'));
      expect(resChapati.matchedCatalogFood?.name, equals('Chapati'));
      expect(resChapati.matchedCatalogFood?.calories, equals(104.0)); // Chapati: 104 kcal/40g

      const phulkaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_phulka',
        canonicalName: 'Phulka',
        category: 'Indian Breads',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resPhulka = resolver.resolveCandidate(phulkaCandidate, foodCatalog: catalog);
      expect(resPhulka.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resPhulka.matchedCatalogFood?.id, equals('predefined_chapati'));
    });

    test('3. Generic Dal does NOT silently resolve to restaurant Dal Tadka recipe', () {
      const genericDalCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dal',
        canonicalName: 'Dal',
        category: 'Indian Lentils',
        similarity: 0.1580,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resDal = resolver.resolveCandidate(genericDalCandidate, foodCatalog: catalog);
      // Must NOT map to predefined_dal_tadka (which has tempered ghee/oil)
      expect(resDal.matchedCatalogFood?.id, isNot(equals('predefined_dal_tadka')));
      expect(resDal.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resDal.profile?.sourceIdentifier, equals('FDC_172421')); // Cooked lentils baseline

      // Explicit Dal Tadka candidate genuinely matches Dal Tadka
      const dalTadkaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dal_tadka',
        canonicalName: 'Dal Tadka',
        category: 'Indian Lentils',
        similarity: 0.1700,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resTadka = resolver.resolveCandidate(dalTadkaCandidate, foodCatalog: catalog);
      expect(resTadka.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resTadka.matchedCatalogFood?.id, equals('predefined_dal_tadka'));
      expect(resTadka.matchedCatalogFood?.name, equals('Dal Tadka'));
      expect(resTadka.matchedCatalogFood?.calories, equals(118.0)); // Dal tadka: 118 kcal/100g in FitFuel catalog
    });

    test('4. Boiled egg maps cleanly to hard boiled egg and never substitutes scrambled or fried', () {
      const boiledEggCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_boiled_egg',
        canonicalName: 'Boiled Egg',
        category: 'Eggs',
        similarity: 0.1600,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final res = resolver.resolveCandidate(boiledEggCandidate, foodCatalog: catalog);
      expect(res.matchedCatalogFood?.id, equals('predefined_hard_boiled_eggs'));
      expect(res.matchedCatalogFood?.name, equals('Hard Boiled Eggs'));
      expect(res.matchedCatalogFood?.id, isNot(equals('predefined_scrambled_eggs')));
      expect(res.matchedCatalogFood?.id, isNot(equals('predefined_egg_omelette')));
    });

    test('5. Standard Samosa aliases map to catalog, while meat/cheese variants remain unavailable', () {
      // Standard vegetable/potato samosa aliases
      final standardSamosas = ['samosa', 'samosas', 'punjabi samosa', 'vegetable samosa'];
      for (final name in standardSamosas) {
        final c = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${name.replaceAll(' ', '_')}',
          canonicalName: name,
          category: 'Snacks',
          similarity: 0.1650,
          rank: 1,
          inFitFuelCatalog: true,
        );
        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.verifiedExact), reason: '$name must match predefined_samosa');
        expect(res.matchedCatalogFood?.id, equals('predefined_samosa'));
        expect(res.matchedCatalogFood?.calories, equals(250.0));
        expect(res.matchedCatalogFood?.servingSize, equals(75.0));
      }

      // Meat and cheese variants must NOT silently inherit vegetable samosa profile
      final nonVegSamosas = ['keema samosa', 'mutton samosa', 'chicken samosa', 'cheese samosa'];
      for (final name in nonVegSamosas) {
        final c = OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_${name.replaceAll(' ', '_')}',
          canonicalName: name,
          category: 'Snacks',
          similarity: 0.1650,
          rank: 1,
          inFitFuelCatalog: false,
        );
        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.unavailable),
            reason: '$name must be unavailable, not silently inherit vegetarian potato samosa');
        expect(res.matchedCatalogFood, isNull);
        expect(res.hasNutrition, isFalse);
      }
    });

    test('6. Chicken Noodle Soup does NOT silently inherit Chicken Soup without noodles', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_chicken_noodle_soup',
        canonicalName: 'Chicken Noodle Soup',
        category: 'Soups',
        similarity: 0.1550,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      // Plain chicken soup lacks carbohydrate noodles; must not silently match
      expect(res.matchedCatalogFood?.id, isNot(equals('predefined_chicken_soup')));
      expect(res.tier, equals(NutritionProfileTier.unavailable));
    });
  });

  group('Phase 35.12.8 — Task 2: Reconcile Nutrition Data and Source Provenance', () {
    test('7. Cooked Pasta: FDC_168936, 131 kcal / 100g, USDA FoodData Central', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_spaghetti',
        canonicalName: 'Spaghetti',
        category: 'Pasta',
        similarity: 0.1550,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(res.profile?.sourceIdentifier, equals('FDC_168936'));
      expect(res.profile?.source, equals('USDA FoodData Central'));
      expect(res.profile?.calories, equals(131.0));
      expect(res.profile?.protein, equals(5.15));
      expect(res.profile?.carbohydrates, equals(25.0));
      expect(res.profile?.totalFat, equals(1.05));
      expect(res.profile?.servingSize, equals(100.0));
      expect(res.profile?.servingUnit, equals('g'));
    });

    test('8. White Rice & Brown Rice: Valid FDC IDs and nutrient verification', () {
      const whiteRice = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_jasmine_rice',
        canonicalName: 'Jasmine Rice',
        category: 'Grains',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resWhite = resolver.resolveCandidate(whiteRice, foodCatalog: catalog);
      expect(resWhite.profile?.sourceIdentifier, equals('FDC_168878'));
      expect(resWhite.profile?.calories, equals(130.0));
      expect(resWhite.profile?.protein, equals(2.69));
      expect(resWhite.profile?.carbohydrates, equals(28.17));
      expect(resWhite.profile?.totalFat, equals(0.28));

      const brownRice = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_brown_rice_grain',
        canonicalName: 'Cooked Brown Rice Grain',
        category: 'Grains',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resBrown = resolver.resolveCandidate(brownRice, foodCatalog: catalog);
      expect(resBrown.profile?.sourceIdentifier, equals('FDC_169704'));
      expect(resBrown.profile?.calories, equals(112.0));
      expect(resBrown.profile?.protein, equals(2.32));
      expect(resBrown.profile?.carbohydrates, equals(23.51));
      expect(resBrown.profile?.totalFat, equals(0.83));
    });

    test('9. Hard-Boiled and Fried Eggs: Valid FDC IDs and nutrient distinction', () {
      const boiled = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_poached_egg',
        canonicalName: 'Poached Egg',
        category: 'Eggs',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resBoiled = resolver.resolveCandidate(boiled, foodCatalog: catalog);
      expect(resBoiled.profile?.sourceIdentifier, equals('FDC_171287'));
      expect(resBoiled.profile?.calories, equals(155.0));
      expect(resBoiled.profile?.totalFat, equals(10.61));

      const fried = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_fried_egg',
        canonicalName: 'Fried Egg',
        category: 'Eggs',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resFried = resolver.resolveCandidate(fried, foodCatalog: catalog);
      expect(resFried.profile?.sourceIdentifier, equals('FDC_173424'));
      expect(resFried.profile?.calories, equals(196.0));
      expect(resFried.profile?.totalFat, equals(15.31));
    });

    test('10. Greek Salad vs Green Garden Salad: Valid FDC IDs and dressing assumptions', () {
      const greenSalad = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_fresh_garden_salad',
        canonicalName: 'Fresh Garden Salad',
        category: 'Salads',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resGreen = resolver.resolveCandidate(greenSalad, foodCatalog: catalog);
      expect(resGreen.profile?.sourceIdentifier, equals('FDC_169248'));
      expect(resGreen.profile?.calories, equals(20.0));
      expect(resGreen.profile?.recipeAssumptions, contains('dressings and croutons excluded'));

      const greekSalad = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_greek_salad',
        canonicalName: 'Greek Salad',
        category: 'Salads',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resGreek = resolver.resolveCandidate(greekSalad, foodCatalog: catalog);
      expect(resGreek.profile?.sourceIdentifier, equals('FNDDS_75146000'));
      expect(resGreek.profile?.calories, equals(104.0));
      expect(resGreek.profile?.totalFat, equals(8.30));
      expect(resGreek.profile?.recipeAssumptions, contains('feta cheese, black olives'));
    });

    test('11. Generic Pizza and Burger: Valid FDC IDs and serving basis', () {
      const pizza = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_cheese_pizza',
        canonicalName: 'Cheese Pizza',
        category: 'Pizza',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resPizza = resolver.resolveCandidate(pizza, foodCatalog: catalog);
      expect(resPizza.profile?.sourceIdentifier, equals('FDC_173292'));
      expect(resPizza.profile?.calories, equals(266.0));
      expect(resPizza.profile?.protein, equals(11.3));
      expect(resPizza.profile?.carbohydrates, equals(33.3));
      expect(resPizza.profile?.totalFat, equals(9.8));

      const burger = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_hamburger',
        canonicalName: 'Hamburger',
        category: 'Burgers',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resBurger = resolver.resolveCandidate(burger, foodCatalog: catalog);
      expect(resBurger.profile?.sourceIdentifier, equals('FDC_170694'));
      expect(resBurger.profile?.calories, equals(254.0));
      expect(resBurger.profile?.protein, equals(13.0));
      expect(resBurger.profile?.carbohydrates, equals(29.8));
      expect(resBurger.profile?.totalFat, equals(9.3));
    });

    test('12. Generic Flatbread / Roti: Source accurately identifies Standard Reference, not USDA', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_flatbread',
        canonicalName: 'Flatbread',
        category: 'Breads',
        similarity: 0.1400,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(res.profile?.id, equals('generic_flatbread_roti'));
      expect(res.profile?.source, equals('Standard Food Composition Reference'));
      expect(res.profile?.source, isNot(contains('USDA')));
      expect(res.profile?.calories, equals(260.0));
    });
  });

  group('Phase 35.12.8 — Task 3 & 4: Resolution Behavior, Honest Labels & Safety', () {
    test('13. Accurate chip labels distinguish USDA baselines from non-USDA generic baselines', () {
      const usdaDetected = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'White Rice',
        confidence: 0.90,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
      );
      expect(usdaDetected.nutritionSourceLabel, equals('USDA Generic Baseline'));

      const nonUsdaDetected = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Flatbread',
        confidence: 0.90,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'Standard Food Composition Reference (Public Domain)',
      );
      expect(nonUsdaDetected.nutritionSourceLabel, equals('Generic Nutrition Baseline'));
    });

    test('14. Unsupported dish keeps macros null, blocks logging, and manual entry restores logging', () {
      const exoticCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dragonfruit_salad',
        canonicalName: 'Dragonfruit Salad',
        category: 'Exotic Salads',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(exoticCandidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.hasNutrition, isFalse);

      final unloggedCandidate = DetectedFoodCandidate(
        id: 'unresolved_item',
        detectedName: exoticCandidate.displayName,
        confidence: 0.90,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: null,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      final unloggedResult = FoodScanResult(
        id: 'scan_unlogged',
        imagePath: '/tmp/test.jpg',
        foods: [unloggedCandidate],
        overallConfidence: 0.90,
        scannedAt: DateTime.now(),
      );
      expect(unloggedResult.canBeLogged, isFalse);
      expect(unloggedCandidate.calories, isNull);
      expect(unloggedCandidate.protein, isNull);
      expect(unloggedCandidate.carbs, isNull);
      expect(unloggedCandidate.fats, isNull);

      // User performs manual entry
      const manualFood = FoodEntity(
        id: 'manual_dragonfruit',
        name: 'Custom Dragonfruit Salad',
        category: 'Manual Entry',
        servingSize: 150.0,
        servingUnit: 'g',
        calories: 90.0,
        protein: 1.5,
        carbohydrates: 20.0,
        fats: 0.5,
        fiber: 2.0,
        sugar: 1.0,
        sodium: 50.0,
        isCustom: true,
      );

      final manualDetected = DetectedFoodCandidate(
        id: 'manual_item',
        detectedName: manualFood.name,
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 150.0,
        estimatedUnit: 'g',
        matchedFood: manualFood,
        nutritionTier: NutritionProfileTier.verifiedExact,
        isUserConfirmed: true,
        recognitionSource: FoodScanRecognitionSource.manual,
      );

      final manualResult = FoodScanResult(
        id: 'scan_manual',
        imagePath: '/tmp/test.jpg',
        foods: [manualDetected],
        overallConfidence: 1.0,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.manual,
      );

      expect(manualResult.canBeLogged, isTrue);
      expect(manualDetected.calories, equals(90.0));
      expect(manualDetected.protein, equals(1.5));
      expect(manualDetected.carbs, equals(20.0));
      expect(manualDetected.fats, equals(0.5));
    });

    test('15. Linear portion scaling operates correctly across generic baseline profiles', () {
      const riceCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_jasmine_rice',
        canonicalName: 'Jasmine Rice',
        category: 'Rice',
        similarity: 0.1600,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(riceCandidate, foodCatalog: catalog);
      final genericFood = res.matchedCatalogFood!;

      // 100g serving: 130 kcal, 2.69g protein, 28.17g carbs, 0.28g fats
      final candidate100g = DetectedFoodCandidate(
        id: 'rice_100',
        detectedName: 'Jasmine Rice',
        confidence: 0.95,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: genericFood,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
      );
      expect(candidate100g.scaledCalories, closeTo(130.0, 0.1));
      expect(candidate100g.scaledProtein, closeTo(2.69, 0.05));
      expect(candidate100g.scaledCarbs, closeTo(28.17, 0.05));
      expect(candidate100g.scaledFats, closeTo(0.28, 0.05));

      // 250g serving (scaled 2.5x)
      final candidate250g = candidate100g.copyWith(estimatedAmount: 250.0);
      expect(candidate250g.scaledCalories, closeTo(325.0, 0.1));
      expect(candidate250g.scaledProtein, closeTo(6.725, 0.05));
      expect(candidate250g.scaledCarbs, closeTo(70.425, 0.05));
      expect(candidate250g.scaledFats, closeTo(0.70, 0.05));
    });
  });
}
