// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/data/food_image_manifest.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Audit Task 1: Food database and nutrition profiles inventory', () async {
    final catalog = PredefinedFoodData.foods;
    final resolver = UniversalNutritionResolver();
    final inventory = resolver.getProfileInventory();

    print('=== TASK 1: DATABASE AUDIT METRICS ===');
    print('1. Curated Food Profiles (PredefinedFoodData.foods): ${catalog.length}');
    print('2. Resolver Verified Profiles Count: ${resolver.verifiedProfilesCount}');
    print('3. Resolver Generic Baselines Count: ${resolver.genericBaselinesCount}');
    print('4. Resolver Recipe Profiles Count: ${resolver.recipeProfilesCount}');
    print('5. Total Active Resolver Profiles Inventory: ${inventory.length}');

    // Completeness of macros in curated catalog
    int completeCurated = 0;
    int incompleteCurated = 0;
    final nameCounts = <String, int>{};
    final idCounts = <String, int>{};

    for (final food in catalog) {
      nameCounts[food.name.toLowerCase().trim()] = (nameCounts[food.name.toLowerCase().trim()] ?? 0) + 1;
      idCounts[food.id] = (idCounts[food.id] ?? 0) + 1;

      if (food.calories > 0 && food.protein >= 0 && food.carbohydrates >= 0 && food.fats >= 0) {
        completeCurated++;
      } else {
        incompleteCurated++;
        print('INCOMPLETE CURATED FOOD: id=${food.id}, name=${food.name}, cal=${food.calories}, p=${food.protein}, c=${food.carbohydrates}, f=${food.fats}');
      }
    }

    final duplicateNames = nameCounts.entries.where((e) => e.value > 1).toList();
    final duplicateIds = idCounts.entries.where((e) => e.value > 1).toList();

    print('6. Curated Profiles with complete macros (Cal, P, C, F): $completeCurated');
    print('7. Curated Profiles incomplete: $incompleteCurated');
    print('8. Duplicate Names in Curated: ${duplicateNames.map((e) => "${e.key} (x${e.value})").toList()}');
    print('9. Duplicate IDs in Curated: ${duplicateIds.map((e) => "${e.key} (x${e.value})").toList()}');

    // Completeness of inventory (all 264 profiles)
    int inventoryComplete = 0;
    int inventoryIncomplete = 0;
    for (final p in inventory) {
      if (p.calories > 0 && p.protein >= 0 && p.carbohydrates >= 0 && p.totalFat >= 0) {
        inventoryComplete++;
      } else {
        inventoryIncomplete++;
      }
    }
    print('10. Total Profiles with complete macros: $inventoryComplete');
    print('11. Total Profiles incomplete: $inventoryIncomplete');

    // Audit assets/ml/vocab_concepts_2050.json
    final vocabFile = File('assets/ml/vocab_concepts_2050.json');
    if (vocabFile.existsSync()) {
      final jsonMap = jsonDecode(vocabFile.readAsStringSync()) as Map<String, dynamic>;
      final concepts = jsonMap['concepts'] as List<dynamic>;
      final numCanonical = jsonMap['numCanonicalFoods'];
      final numNegatives = jsonMap['numNegativePrompts'];
      final negativeLabels = jsonMap['negativeLabels'] as List<dynamic>;

      int inFitFuel238Count = 0;
      int notInFitFuelCount = 0;
      for (final c in concepts) {
        final map = c as Map<String, dynamic>;
        if (map['inFitFuel238'] == true) {
          inFitFuel238Count++;
        } else {
          notInFitFuelCount++;
        }
      }

      print('12. Recognition Concepts in vocab_concepts_2050.json: ${concepts.length} (declared: $numCanonical)');
      print('13. Concepts marked inFitFuel238 = true: $inFitFuel238Count');
      print('14. Concepts marked inFitFuel238 = false: $notInFitFuelCount');
      print('15. Negative Prompts in JSON: ${negativeLabels.length} (declared: $numNegatives)');

      final conceptIds = <String, int>{};
      final conceptNames = <String, int>{};
      for (final c in concepts) {
        final map = c as Map<String, dynamic>;
        final id = map['id'] as String;
        final name = (map['name'] as String).toLowerCase().trim();
        conceptIds[id] = (conceptIds[id] ?? 0) + 1;
        conceptNames[name] = (conceptNames[name] ?? 0) + 1;
      }
      final dupConceptIds = conceptIds.entries.where((e) => e.value > 1).toList();
      final dupConceptNames = conceptNames.entries.where((e) => e.value > 1).toList();
      print('15b. Duplicate Concept IDs in vocab_concepts_2050.json: ${dupConceptIds.length}');
      print('15c. Duplicate Concept Names in vocab_concepts_2050.json: ${dupConceptNames.length}');
      int exactCount = 0;
      int genericCount = 0;
      int recipeCount = 0;
      int unavailableCount = 0;

      for (final c in concepts) {
        final map = c as Map<String, dynamic>;
        final id = map['id'] as String;
        final name = map['name'] as String;
        final cat = map['cat'] as String? ?? 'General';
        final inFitFuel = map['inFitFuel238'] == true;

        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: id,
          canonicalName: name,
          category: cat,
          similarity: 0.1500,
          rank: 1,
          inFitFuelCatalog: inFitFuel,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog.map((m) => m.toEntity()).toList());
        switch (res.tier) {
          case NutritionProfileTier.verifiedExact:
            exactCount++;
            break;
          case NutritionProfileTier.closelyRelatedGeneric:
            genericCount++;
            break;
          case NutritionProfileTier.recipeEstimate:
            recipeCount++;
            break;
          case NutritionProfileTier.unavailable:
            unavailableCount++;
            break;
        }
      }

      print('=== 2,050 CONCEPT NUTRITION RESOLUTION COVERAGE ===');
      print('A. Resolved to Verified Exact: $exactCount (${(exactCount * 100.0 / concepts.length).toStringAsFixed(1)}%)');
      print('B. Resolved to Generic Baseline: $genericCount (${(genericCount * 100.0 / concepts.length).toStringAsFixed(1)}%)');
      print('C. Resolved to Recipe Estimate: $recipeCount (${(recipeCount * 100.0 / concepts.length).toStringAsFixed(1)}%)');
      print('D. Currently UNAVAILABLE (Requires profile selection): $unavailableCount (${(unavailableCount * 100.0 / concepts.length).toStringAsFixed(1)}%)');

      expect(exactCount, equals(274));
      expect(genericCount, equals(76));
      expect(recipeCount, equals(16));
      expect(unavailableCount, equals(1684));
    }

    // Audit Tier 1 MobileNet labels
    final labelsFile = File('assets/ml/fitfuel_food_labels.txt');
    if (labelsFile.existsSync()) {
      final lines = labelsFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      print('16. Tier 1 MobileNetV2 Labels: ${lines.length}');
    }

    // Audit Mappings in TrustedOpenVocabNutritionMapper
    print('17. TrustedOpenVocabNutritionMapper 1:1 ID mappings: ${TrustedOpenVocabNutritionMapper.kVerifiedOpenVocabToFitFuelCatalogIds.length}');
    print('18. TrustedOpenVocabNutritionMapper Normalized Name Aliases: ${TrustedOpenVocabNutritionMapper.kVerifiedNormalizedNameAliases.length}');

    // Audit Images in FoodImageManifest
    final manifestKeys = FoodImageManifest.manifest.keys.toList();
    print('19. FoodImageManifest Image Mappings: ${manifestKeys.length}');

    // Check recipes and ingredients in PredefinedFoodData
    int withIngredients = 0;
    int withRecipe = 0;
    int withInstructions = 0;
    int withCuisine = 0;

    for (final food in catalog) {
      if (food.ingredients != null && food.ingredients!.isNotEmpty) withIngredients++;
      if (food.recipe != null && food.recipe!.isNotEmpty) withRecipe++;
      if (food.instructions != null && food.instructions!.isNotEmpty) withInstructions++;
      if (food.cuisine != null && food.cuisine!.isNotEmpty) withCuisine++;
    }

    print('21. Foods in PredefinedFoodData with ingredients: $withIngredients / ${catalog.length}');
    print('22. Foods in PredefinedFoodData with recipe: $withRecipe / ${catalog.length}');
    print('23. Foods in PredefinedFoodData with instructions: $withInstructions / ${catalog.length}');
    print('24. Foods in PredefinedFoodData with cuisine: $withCuisine / ${catalog.length}');
  });
}
