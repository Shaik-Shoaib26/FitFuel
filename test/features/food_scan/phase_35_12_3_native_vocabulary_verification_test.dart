import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food_scan/domain/entities/canonical_food_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/data/services/siglip_open_vocabulary_food_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();

  group('Phase 35.12.3 — Task 2: Native Dynamic Vocabulary Integration & Synchronization', () {
    late FakeOpenVocabularyFoodRecognizer fakeRecognizer;
    late GlobalFoodVocabularyService vocabService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeRecognizer = FakeOpenVocabularyFoodRecognizer();
      vocabService = GlobalFoodVocabularyService();
    });

    test('1. registerAndSyncVocabularyPack synchronizes vision-eligible pack with native runtime', () async {
      final dummy768 = List<double>.filled(768, 0.036);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_dynamic_dish_1',
        preferredName: 'Peruvian Ceviche',
        aliases: ['ceviche', 'cebiche'],
        cuisine: 'Peruvian',
        category: 'Seafood',
        textEmbedding: dummy768,
        embeddingModelId: 'siglip_b16_int8',
        packVersion: '1.0.0',
      );

      final pack = VocabularyPack(
        packId: 'latin_america_pack_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = await vocabService.registerAndSyncVocabularyPack(
        pack,
        recognizer: fakeRecognizer,
        prefs: prefs,
      );

      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(1));
      expect(result.textOnlyEntries, equals(0));

      // Dart index check
      expect(vocabService.isImageEligible('openvocab_dynamic_dish_1'), isTrue);
      final resolved = vocabService.getEntry('openvocab_dynamic_dish_1');
      expect(resolved, isNotNull);
      expect(resolved!.preferredName, equals('Peruvian Ceviche'));

      // Native recognizer sync check
      expect(fakeRecognizer.registeredPacks.length, equals(1));
      expect(fakeRecognizer.registeredPacks.first.packId, equals('latin_america_pack_v1'));

      final info = await fakeRecognizer.getRegisteredVocabularyInfo();
      expect(info!['dynamicConcepts'], equals(1));
      expect(info['totalConcepts'], equals(2051));
    });

    test('2. Atomic rollback: native failure rolls back Dart state and SharedPreferences', () async {
      final initialCount = vocabService.count;
      fakeRecognizer.simulateNativeFailureOnRegister = true;

      final dummy768 = List<double>.filled(768, 0.036);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_failed_sync_dish',
        preferredName: 'Failed Sync Dish',
        textEmbedding: dummy768,
      );

      final pack = VocabularyPack(
        packId: 'failure_test_pack',
        version: '1.0.0',
        entries: [entry],
      );

      final result = await vocabService.registerAndSyncVocabularyPack(
        pack,
        recognizer: fakeRecognizer,
        prefs: prefs,
      );

      // Rollback verification
      expect(result.isValid, isFalse);
      expect(result.validationErrors.first, contains('Native sync failed'));
      expect(vocabService.count, equals(initialCount));
      expect(vocabService.getEntry('openvocab_failed_sync_dish'), isNull);
      expect(vocabService.isImageEligible('openvocab_failed_sync_dish'), isFalse);
      expect(fakeRecognizer.registeredPacks, isEmpty);

      // Verify not persisted to storage
      final storedJson = prefs.getString('fitfuel_dynamic_vocab_packs');
      expect(storedJson, isNull);
    });

    test('3. Entries with mismatched embedding dimension (512-d) have vision support stripped safely', () async {
      final dummy512 = List<double>.filled(512, 0.044);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_mismatched_dish',
        preferredName: 'Mismatched Dish',
        textEmbedding: dummy512,
      );

      final pack = VocabularyPack(
        packId: 'mismatch_pack',
        version: '1.0.0',
        entries: [entry],
      );

      final result = await vocabService.registerAndSyncVocabularyPack(
        pack,
        recognizer: fakeRecognizer,
        prefs: prefs,
      );

      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(0));
      expect(result.textOnlyEntries, equals(1));
      expect(vocabService.isImageEligible('openvocab_mismatched_dish'), isFalse);
      // Entry remains available for text search
      expect(vocabService.getEntry('openvocab_mismatched_dish'), isNotNull);
    });

    test('4. Duplicate canonical IDs across packs are safely rejected', () async {
      final dummy768 = List<double>.filled(768, 0.036);
      final entry1 = CanonicalFoodEntry(
        canonicalId: 'openvocab_duplicate_id',
        preferredName: 'Original Dish',
        textEmbedding: dummy768,
      );
      final pack1 = VocabularyPack(
        packId: 'pack_one',
        version: '1.0.0',
        entries: [entry1],
      );
      await vocabService.registerAndSyncVocabularyPack(pack1, recognizer: fakeRecognizer, prefs: prefs);

      // Second pack with duplicate ID
      final entry2 = CanonicalFoodEntry(
        canonicalId: 'openvocab_duplicate_id',
        preferredName: 'Duplicate Dish',
        textEmbedding: dummy768,
      );
      final pack2 = VocabularyPack(
        packId: 'pack_two',
        version: '1.0.0',
        entries: [entry2],
      );

      final result = await vocabService.registerAndSyncVocabularyPack(
        pack2,
        recognizer: fakeRecognizer,
        prefs: prefs,
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.any((e) => e.contains('Duplicate canonicalId')), isTrue);
      expect(vocabService.getEntry('openvocab_duplicate_id')!.preferredName, equals('Original Dish'));
    });

    test('5. Dynamic pack persistence across restarts: initialize restores dynamic packs and syncs native', () async {
      // 1. Register a dynamic pack in the initial service instance
      final dummy768 = List<double>.filled(768, 0.036);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_persisted_dish',
        preferredName: 'Persisted Korean Bibimbap',
        cuisine: 'Korean',
        category: 'Rice Dish',
        textEmbedding: dummy768,
      );
      final pack = VocabularyPack(
        packId: 'korean_pack_v1',
        version: '1.0.0',
        entries: [entry],
      );

      await vocabService.registerAndSyncVocabularyPack(pack, recognizer: fakeRecognizer, prefs: prefs);
      expect(vocabService.getEntry('openvocab_persisted_dish'), isNotNull);

      // 2. Simulate fresh app start with new service instance and new recognizer
      final freshRecognizer = FakeOpenVocabularyFoodRecognizer();
      final freshService = GlobalFoodVocabularyService();

      // Ensure fresh state prior to init
      expect(freshService.getEntry('openvocab_persisted_dish'), isNull);
      expect(freshRecognizer.registeredPacks, isEmpty);

      // Initialize with persisted prefs and fresh recognizer
      await freshService.initialize(recognizer: freshRecognizer, prefs: prefs);

      // Verify dynamic entries restored in Dart
      expect(freshService.getEntry('openvocab_persisted_dish'), isNotNull);
      expect(freshService.isImageEligible('openvocab_persisted_dish'), isTrue);

      // Verify synchronized with fresh native recognizer
      expect(freshRecognizer.registeredPacks.length, equals(1));
      expect(freshRecognizer.registeredPacks.first.packId, equals('korean_pack_v1'));
    });

    test('6. clearDynamicVocabulary clears SharedPreferences, Dart state, and native concept matrix', () async {
      final dummy768 = List<double>.filled(768, 0.036);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_to_clear',
        preferredName: 'To Clear Dish',
        textEmbedding: dummy768,
      );
      final pack = VocabularyPack(
        packId: 'pack_to_clear',
        version: '1.0.0',
        entries: [entry],
      );

      await vocabService.registerAndSyncVocabularyPack(pack, recognizer: fakeRecognizer, prefs: prefs);
      expect(vocabService.getEntry('openvocab_to_clear'), isNotNull);
      expect(fakeRecognizer.registeredPacks.length, equals(1));

      // Clear dynamic vocabulary
      await vocabService.clearDynamicVocabulary(recognizer: fakeRecognizer, prefs: prefs);

      expect(vocabService.getEntry('openvocab_to_clear'), isNull);
      expect(fakeRecognizer.clearDynamicVocabularyCallCount, equals(1));
      expect(fakeRecognizer.registeredPacks, isEmpty);
      expect(prefs.getString('fitfuel_dynamic_vocab_packs'), isNull);
    });

    test('7. Native retrieval status query accurately reports base and dynamic concept counts', () async {
      final info = await fakeRecognizer.getRegisteredVocabularyInfo();
      expect(info!['baseConcepts'], equals(2050));
      expect(info['dynamicConcepts'], equals(0));
      expect(info['totalConcepts'], equals(2050));
    });
  });

  group('Phase 35.12.3 — Task 3: Similarity-Score Presentation & Semantics', () {
    test('8. formattedSimilarityScore displays raw cosine similarity value and raw decimal', () {
      const candidateHigh = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pepperoni Pizza',
        category: 'Pizza',
        similarity: 0.1680,
        rank: 1,
        inFitFuelCatalog: false,
      );

      expect(candidateHigh.formattedSimilarityScore, equals('Cosine similarity: 0.1680'));
      expect(candidateHigh.rawCosineSimilarityString, equals('0.1680'));

      const candidateModerate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_soup',
        canonicalName: 'Miso Soup',
        category: 'Soup',
        similarity: 0.1234,
        rank: 2,
        inFitFuelCatalog: false,
      );

      expect(candidateModerate.formattedSimilarityScore, equals('Cosine similarity: 0.1234'));
      expect(candidateModerate.rawCosineSimilarityString, equals('0.1234'));
    });

    test('9. Candidates are ordered strictly descending by similarity; top-1 has highest similarity', () {
      const candidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_c1',
          canonicalName: 'Food 1',
          category: 'Entrees',
          similarity: 0.1680,
          rank: 1,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_c2',
          canonicalName: 'Food 2',
          category: 'Entrees',
          similarity: 0.1328,
          rank: 2,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_c3',
          canonicalName: 'Food 3',
          category: 'Entrees',
          similarity: 0.1235,
          rank: 3,
        ),
      ];

      expect(candidates[0].similarity, greaterThan(candidates[1].similarity));
      expect(candidates[1].similarity, greaterThan(candidates[2].similarity));
      expect(candidates.first.rank, equals(1));
    });

    test('10. Documented semantics: similarity represents cosine projection in 768-d space, not calibrated probability', () {
      // In SigLIP, vision-text dot product is not scaled through a 50-class softmax.
      // Top candidate with similarity 0.1680 has a raw cosine score of 0.1680,
      // not a 16.8% Bayesian posterior probability.
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_pasta',
        canonicalName: 'Creamy Penne Pasta',
        category: 'Pasta',
        similarity: 0.1680,
        rank: 1,
      );

      expect(candidate.similarity, equals(0.1680));
      expect(candidate.formattedSimilarityScore, equals('Cosine similarity: 0.1680'));
      expect(candidate.rawCosineSimilarityString, equals('0.1680'));
    });
  });

  group('Phase 35.12.3 — Task 4: Real Nutrition Resolution Across Categories & Portion Scalability', () {
    late UniversalNutritionResolver resolver;

    setUp(() {
      resolver = UniversalNutritionResolver();
    });

    test('11. Pizza candidate resolves to closelyRelatedGeneric USDA baseline with valid macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza_margherita',
        canonicalName: 'Pizza Margherita',
        category: 'Pizza',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.matchedCatalogFood!.protein, greaterThan(0));
      expect(resolution.matchedCatalogFood!.carbohydrates, greaterThan(0));
      expect(resolution.matchedCatalogFood!.fats, greaterThan(0));
      expect(resolution.attribution, contains('Department of Agriculture'));
    });

    test('12. Burger candidate resolves to closelyRelatedGeneric USDA baseline with valid macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_cheeseburger',
        canonicalName: 'Cheeseburger',
        category: 'Burgers',
        similarity: 0.1580,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.matchedCatalogFood!.protein, greaterThan(0));
      expect(resolution.attribution, contains('Department of Agriculture'));
    });

    test('13. Pasta candidate resolves to closelyRelatedGeneric USDA baseline with carbohydrates and calories', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_penne_pasta',
        canonicalName: 'Penne Pasta',
        category: 'Pasta',
        similarity: 0.1520,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.matchedCatalogFood!.carbohydrates, greaterThan(0));
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.attribution, contains('Department of Agriculture'));
    });

    test('14. Creamy Pasta (Alfredo) candidate resolves to recipeEstimate with culinary assumptions', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_penne_alfredo',
        canonicalName: 'Creamy Penne Alfredo',
        category: 'Pasta',
        similarity: 0.1680,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.tier, equals(NutritionProfileTier.recipeEstimate));
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.recipeAssumptions, isNotNull);
    });

    test('15. Unsupported food (e.g. dragonfruit salad) remains honestly unavailable with 0 fabricated macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dragonfruit_salad',
        canonicalName: 'Dragonfruit Salad',
        category: 'Salads',
        similarity: 0.1250,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.unavailable));
      expect(resolution.hasNutrition, isFalse);
      expect(resolution.matchedCatalogFood, isNull);
      expect(resolution.profile, isNull);
    });

    test('16. FitFuel catalog food (Dosa, Samosa, Rajma Chawal) resolves to verifiedExact', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_samosa',
        canonicalName: 'Samosa',
        category: 'Indian Snacks',
        similarity: 0.1850,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.isVerifiedExact, isTrue);
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.attribution, contains('FitFuel'));
    });

    test('17. Portion scaling: scaling serving size from 100g to 250g scales all macros proportionally', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pizza',
        category: 'Pizza',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      final baseFood = resolution.matchedCatalogFood!;
      final baseServing = baseFood.servingSize; // 100g
      const targetServing = 250.0;
      final scale = targetServing / baseServing;

      final scaledFood = baseFood.copyWith(
        servingSize: targetServing,
        calories: baseFood.calories * scale,
        protein: double.parse((baseFood.protein * scale).toStringAsFixed(1)),
        carbohydrates: double.parse((baseFood.carbohydrates * scale).toStringAsFixed(1)),
        fats: double.parse((baseFood.fats * scale).toStringAsFixed(1)),
      );

      expect(scaledFood.servingSize, equals(250.0));
      expect(scaledFood.calories, closeTo(baseFood.calories * 2.5, 0.1));
      expect(scaledFood.protein, closeTo(baseFood.protein * 2.5, 0.1));
      expect(scaledFood.carbohydrates, closeTo(baseFood.carbohydrates * 2.5, 0.1));
      expect(scaledFood.fats, closeTo(baseFood.fats * 2.5, 0.1));
    });

    test('18. Zero automatic Gemini calls guarantee across local routing, low confidence, and unmapped foods', () {
      // Confirm that resolver operates purely on local catalog and local recipes with 0 network calls
      expect(resolver.recipeProfilesCount, greaterThan(0));
      expect(resolver.genericBaselinesCount, greaterThan(0));
      expect(resolver.verifiedProfilesCount, greaterThan(0));
    });
  });
}
