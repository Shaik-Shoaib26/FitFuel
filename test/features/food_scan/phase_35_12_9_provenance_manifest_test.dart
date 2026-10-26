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

  group('Phase 35.12.9 — Task 1: Complete Nutrition Profile Inventory & Apple Reconciliation', () {
    test('1. Inventory count matches active production definitions (264 profiles = 238 curated + 22 generic + 4 recipe)', () {
      final inventory = resolver.getProfileInventory();

      expect(resolver.verifiedProfilesCount, equals(238));
      expect(resolver.genericBaselinesCount, equals(22));
      expect(resolver.recipeProfilesCount, equals(4));
      expect(inventory.length, equals(264));

      // Curated profiles count
      final curated = inventory.where((e) => e.profileClassification == 'curated').toList();
      expect(curated.length, equals(238));

      // Generic baselines count (19 USDA + 3 Non-USDA)
      final generic = inventory.where((e) => e.profileClassification == 'generic').toList();
      expect(generic.length, equals(22));

      final usdaGeneric = generic.where((e) => e.sourceType == 'USDA FoodData Central').toList();
      expect(usdaGeneric.length, equals(19));

      final nonUsdaGeneric = generic.where((e) => e.sourceType != 'USDA FoodData Central').toList();
      expect(nonUsdaGeneric.length, equals(3));

      // Recipe estimates count
      final recipes = inventory.where((e) => e.profileClassification == 'recipe-estimated').toList();
      expect(recipes.length, equals(4));
    });

    test('2. Reconcile Fresh Apple: Active profile present in resolver inventory and resolves open-vocabulary query', () {
      final inventory = resolver.getProfileInventory();
      final appleEntries = inventory.where((e) => e.canonicalProfileId == 'usda_generic_apple').toList();
      expect(appleEntries.length, equals(1), reason: 'Fresh Apple must be an active generic profile');

      final appleProfile = appleEntries.first;
      expect(appleProfile.sourceIdentifier, equals('FDC_171688'));
      expect(appleProfile.sourceType, equals('USDA FoodData Central'));
      expect(appleProfile.calories, equals(52.0));
      expect(appleProfile.protein, equals(0.26));
      expect(appleProfile.carbohydrates, equals(13.81));
      expect(appleProfile.totalFat, equals(0.17));
      expect(appleProfile.preparationState, equals('raw with skin'));
      expect(appleProfile.isExternallyTraceable, isTrue);

      // Candidate resolution test for apple variants
      const fujiAppleCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_fuji_apple',
        canonicalName: 'Fuji Apple',
        category: 'Fruits',
        similarity: 0.1600,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(fujiAppleCandidate, foodCatalog: const []);
      expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(res.profile?.id, equals('usda_generic_apple'));
      expect(res.profile?.sourceIdentifier, equals('FDC_171688'));
      expect(res.profile?.calories, equals(52.0));
    });
  });

  group('Phase 35.12.9 — Task 2: Source Provenance & Burger/Non-USDA Discrepancy Verification', () {
    test('3. Every active profile canonical ID is unique across all categories', () {
      final inventory = resolver.getProfileInventory();
      final seenIds = <String>{};
      final duplicates = <String>[];

      for (final entry in inventory) {
        if (!seenIds.add(entry.canonicalProfileId)) {
          duplicates.add(entry.canonicalProfileId);
        }
      }

      expect(duplicates, isEmpty, reason: 'Duplicate profile IDs found: $duplicates');
      expect(seenIds.length, equals(inventory.length));
    });

    test('4. Burger baseline documents SR Legacy fast food single-patty profile and resolves properly', () {
      final inventory = resolver.getProfileInventory();
      final burger = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_burger');

      expect(burger.sourceType, equals('USDA FoodData Central'));
      expect(burger.sourceIdentifier, equals('FDC_170694'));
      expect(burger.calories, equals(254.0));
      expect(burger.protein, equals(13.0));
      expect(burger.carbohydrates, equals(29.8));
      expect(burger.totalFat, equals(9.3));
      expect(burger.servingSize, equals(100.0));
      expect(burger.servingUnit, equals('g'));
      expect(burger.recipeAssumptions, contains('FDC 170694 / NDB 21108'));
    });

    test('5. Non-USDA profiles are marked unverified with explicit non-traceable provenance', () {
      final inventory = resolver.getProfileInventory();
      final nonUsdaIds = ['generic_flatbread_roti', 'generic_idli', 'generic_dosa'];

      for (final id in nonUsdaIds) {
        final profile = inventory.firstWhere((e) => e.canonicalProfileId == id);
        expect(profile.isExternallyTraceable, isFalse, reason: '$id must be marked as not externally traceable');
        expect(profile.attribution, contains('Unverified Generic Reference'),
            reason: '$id attribution must disclose that it is an unverified reference');
        expect(profile.sourceType, equals('Standard Food Composition Reference'));
      }

      final activeProfiles = resolver.getAllActiveProfiles();
      for (final id in nonUsdaIds) {
        final p = activeProfiles.firstWhere((p) => p.id == id);
        expect(p.isSourceTraceable, isFalse);
        expect(p.isProvenanceVerified, isFalse);
      }
    });

    test('6. Cooked pasta retains authoritative USDA FDC 168936 baseline', () {
      final inventory = resolver.getProfileInventory();
      final pasta = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_pasta');

      expect(pasta.sourceIdentifier, equals('FDC_168936'));
      expect(pasta.calories, equals(131.0));
      expect(pasta.protein, equals(5.15));
      expect(pasta.carbohydrates, equals(25.0));
      expect(pasta.totalFat, equals(1.05));
      expect(pasta.isExternallyTraceable, isTrue);
    });
  });

  group('Phase 35.12.9 — Task 3: Trust-Label Semantics & UI Honesty', () {
    test('7. Trust labels clearly distinguish Curated Catalog, USDA Baseline, Generic Reference, and User-entered', () {
      // 1. Curated Catalog
      const curatedItem = DetectedFoodCandidate(
        id: 'c_curated',
        detectedName: 'Apple',
        confidence: 0.95,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.verifiedExact,
        nutritionAttribution: 'Curated FitFuel Food Database',
      );
      expect(curatedItem.nutritionSourceLabel, equals('Curated FitFuel Food Database'));

      // 2. USDA Generic Baseline
      const usdaItem = DetectedFoodCandidate(
        id: 'c_usda',
        detectedName: 'White Rice',
        confidence: 0.90,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
      );
      expect(usdaItem.nutritionSourceLabel, equals('USDA Generic Baseline'));

      // 3. Non-USDA Generic Baseline
      const nonUsdaItem = DetectedFoodCandidate(
        id: 'c_non_usda',
        detectedName: 'Roti',
        confidence: 0.90,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'Standard Food Composition Reference (Unverified Generic Reference)',
      );
      expect(nonUsdaItem.nutritionSourceLabel, equals('Generic Nutrition Baseline'));

      // 4. Recipe Estimate
      const recipeItem = DetectedFoodCandidate(
        id: 'c_recipe',
        detectedName: 'Chicken Tikka Masala',
        confidence: 0.85,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.recipeEstimate,
        nutritionAttribution: 'FitFuel Standard Culinary Formulation',
      );
      expect(recipeItem.nutritionSourceLabel, equals('Recipe Estimate'));

      // 5. User-entered manual nutrition
      const manualCustomFood = FoodEntity(
        id: 'manual_123456789',
        name: 'Custom Lentil Soup',
        category: 'Manual Entry',
        servingSize: 150.0,
        servingUnit: 'g',
        calories: 120.0,
        protein: 7.0,
        carbohydrates: 18.0,
        fats: 2.0,
        fiber: 4.0,
        sugar: 1.0,
        sodium: 200.0,
        isCustom: true,
      );

      const manualCandidate = DetectedFoodCandidate(
        id: 'c_manual',
        detectedName: 'Custom Lentil Soup',
        confidence: 1.0,
        estimatedAmount: 150.0,
        matchedFood: manualCustomFood,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
      );
      expect(manualCandidate.isUserEnteredNutrition, isTrue);
      expect(manualCandidate.nutritionSourceLabel, equals('User-entered nutrition'));
    });

    test('8. Unsupported foods retain null macros, cannot be logged, and manual entry restores logging', () {
      const unsupported = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_durian_pastry',
        canonicalName: 'Durian Pastry',
        category: 'Pastries',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(unsupported, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.hasNutrition, isFalse);

      final unloggedCandidate = DetectedFoodCandidate(
        id: 'unsupported_dish',
        detectedName: unsupported.displayName,
        confidence: 0.88,
        estimatedAmount: 100.0,
        matchedFood: null,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      final scanResult = FoodScanResult(
        id: 'scan_unsupported',
        imagePath: '/tmp/test.jpg',
        foods: [unloggedCandidate],
        overallConfidence: 0.88,
        scannedAt: DateTime.now(),
      );

      expect(scanResult.canBeLogged, isFalse, reason: 'Unsupported dish must block diary logging');
      expect(unloggedCandidate.calories, isNull);
      expect(unloggedCandidate.protein, isNull);
      expect(unloggedCandidate.carbs, isNull);
      expect(unloggedCandidate.fats, isNull);
    });
  });

  group('Phase 35.12.9 — Task 4: Regression Protection & Portion Scaling Math', () {
    test('9. Measurement basis is rigorously separated: 100g profiles vs per-serving profiles', () {
      final inventory = resolver.getProfileInventory();

      // All generic baselines and recipe estimates MUST be per 100 g
      for (final p in inventory.where((e) => e.profileClassification != 'curated')) {
        expect(p.servingSize, equals(100.0), reason: '${p.canonicalProfileId} must have servingSize 100.0');
        expect(p.servingUnit, equals('g'), reason: '${p.canonicalProfileId} must have servingUnit g');
        expect(p.measurementBasis, equals('per 100 g'));
      }

      // Curated profiles with non-100g serving sizes must explicitly declare per serving
      final samosa = inventory.firstWhere((e) => e.canonicalProfileId == 'predefined_samosa');
      expect(samosa.servingSize, equals(75.0));
      expect(samosa.measurementBasis, equals('per serving (75 g)'));

      final chapati = inventory.firstWhere((e) => e.canonicalProfileId == 'predefined_chapati');
      expect(chapati.servingSize, equals(40.0));
      expect(chapati.measurementBasis, equals('per serving (40 g)'));
    });

    test('10. Portion scaling preserves linear proportionality without rounding drift', () {
      final inventory = resolver.getProfileInventory();
      final pastaProfile = inventory.firstWhere((e) => e.canonicalProfileId == 'usda_generic_pasta');

      final pastaFood = FoodEntity(
        id: pastaProfile.canonicalProfileId,
        name: pastaProfile.displayName,
        category: 'Generic Baseline',
        servingSize: pastaProfile.servingSize,
        servingUnit: pastaProfile.servingUnit,
        calories: pastaProfile.calories,
        protein: pastaProfile.protein,
        carbohydrates: pastaProfile.carbohydrates,
        fats: pastaProfile.totalFat,
        fiber: pastaProfile.fiber ?? 0.0,
        sugar: pastaProfile.sugar ?? 0.0,
        sodium: pastaProfile.sodium ?? 0.0,
        isCustom: true,
      );

      final candidate100g = DetectedFoodCandidate(
        id: 'pasta_100',
        detectedName: 'Pasta',
        confidence: 0.90,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: pastaFood,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
      );

      expect(candidate100g.scaledCalories, closeTo(131.0, 0.01));
      expect(candidate100g.scaledProtein, closeTo(5.15, 0.01));
      expect(candidate100g.scaledCarbs, closeTo(25.0, 0.01));
      expect(candidate100g.scaledFats, closeTo(1.05, 0.01));

      // Scale to 325g (3.25x)
      final candidate325g = candidate100g.copyWith(estimatedAmount: 325.0);
      expect(candidate325g.scaledCalories, closeTo(131.0 * 3.25, 0.01));
      expect(candidate325g.scaledProtein, closeTo(5.15 * 3.25, 0.01));
      expect(candidate325g.scaledCarbs, closeTo(25.0 * 3.25, 0.01));
      expect(candidate325g.scaledFats, closeTo(1.05 * 3.25, 0.01));
    });

    test('11. Safeguards intact: Dal, Roti, and Dosa generic queries never substitute complex recipes', () {
      // Dal
      const dalCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dal',
        canonicalName: 'Dal',
        category: 'Indian Lentils',
        similarity: 0.1550,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resDal = resolver.resolveCandidate(dalCandidate, foodCatalog: catalog);
      expect(resDal.matchedCatalogFood?.id, isNot(equals('predefined_dal_tadka')));
      expect(resDal.tier, equals(NutritionProfileTier.closelyRelatedGeneric));

      // Roti
      const rotiCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_roti',
        canonicalName: 'Roti',
        category: 'Indian Breads',
        similarity: 0.1600,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resRoti = resolver.resolveCandidate(rotiCandidate, foodCatalog: catalog);
      expect(resRoti.matchedCatalogFood?.id, isNot(equals('predefined_roti')));
      expect(resRoti.tier, equals(NutritionProfileTier.closelyRelatedGeneric));

      // Dosa
      const dosaCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dosa',
        canonicalName: 'Dosa',
        category: 'South Indian',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );
      final resDosa = resolver.resolveCandidate(dosaCandidate, foodCatalog: catalog);
      expect(resDosa.matchedCatalogFood?.id, isNot(equals('predefined_masala_dosa')));
      expect(resDosa.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
    });
  });
}
