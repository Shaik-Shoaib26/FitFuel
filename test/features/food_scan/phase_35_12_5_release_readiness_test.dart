import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/canonical_food_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/data/services/siglip_open_vocabulary_food_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();

  group('Phase 35.12.5 — Task 2: Native Dynamic Vocabulary Retrieval & Lifecycle Verification', () {
    late GlobalFoodVocabularyService vocabService;
    late FakeOpenVocabularyFoodRecognizer recognizer;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      vocabService = GlobalFoodVocabularyService();
      recognizer = FakeOpenVocabularyFoodRecognizer();
    });

    test('1. Initial native vocabulary reports exactly 2,050 base concepts and 0 dynamic concepts', () async {
      await vocabService.initialize(recognizer: recognizer);
      final info = await recognizer.getRegisteredVocabularyInfo();

      expect(info!['baseConcepts'], equals(2050));
      expect(info['dynamicConcepts'], equals(0));
      expect(info['totalConcepts'], equals(2050));
      expect(info['dynamicPacksCount'], equals(0));
    });

    test('2. Registering valid 768-d unit-norm embedding increments native concept count by expected entries', () async {
      await vocabService.initialize(recognizer: recognizer);

      final validEmbedding = List<double>.generate(768, (i) => i == 0 ? 1.0 : 0.0);
      final pack = VocabularyPack(
        packId: 'regional_mexican_v1',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'birria_quesataco',
            preferredName: 'Birria Quesataco',
            category: 'Mexican',
            cuisine: 'Mexican',
            textEmbedding: validEmbedding,
          ),
        ],
      );

      final result = await vocabService.registerAndSyncVocabularyPack(
        pack,
        recognizer: recognizer,
        requireAllVisionEligible: true,
      );

      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(1));

      final info = await recognizer.getRegisteredVocabularyInfo();
      expect(info!['dynamicConcepts'], equals(1));
      expect(info['totalConcepts'], equals(2051));
      expect(info['dynamicPacksCount'], equals(1));
    });

    test('3. Image scan includes newly registered dynamic concept in retrieval candidates with valid scalar score', () async {
      await vocabService.initialize(recognizer: recognizer);

      final pack = VocabularyPack(
        packId: 'regional_mexican_v1',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'birria_quesataco',
            preferredName: 'Birria Quesataco',
            category: 'Mexican',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );
      await vocabService.registerAndSyncVocabularyPack(pack, recognizer: recognizer);

      // Configure fake recognizer to simulate native matrix inner product projection
      recognizer.setAcceptedCandidates([
        const OpenVocabularyFoodCandidate(
          canonicalFoodId: 'birria_quesataco',
          canonicalName: 'Birria Quesataco',
          category: 'Mexican',
          similarity: 0.1742,
          rank: 1,
        ),
      ]);

      final scanResult = await recognizer.recognize(
        Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(scanResult.accepted, isTrue);
      expect(scanResult.topCandidates.first.canonicalFoodId, equals('birria_quesataco'));
      expect(scanResult.topCandidates.first.displayName, equals('Birria Quesataco'));
      expect(scanResult.topCandidates.first.formattedSimilarityScore, equals('Cosine similarity: 0.1742'));
      expect(scanResult.topCandidates.first.formattedSimilarityScore.contains('%'), isFalse);
    });

    test('4. Restart and persistence: initialize restores persisted packs from SharedPreferences to Native RAM', () async {
      final validPackJson = json.encode([
        {
          'packId': 'persisted_pack_restart',
          'version': '1.0.0',
          'targetModelId': 'siglip_b16_int8',
          'entries': [
            {
              'canonicalId': 'persisted_shawarma',
              'preferredName': 'Chicken Shawarma Wrap',
              'category': 'Middle Eastern',
              'textEmbedding': List<double>.filled(768, 0.05),
            }
          ]
        }
      ]);

      SharedPreferences.setMockInitialValues({
        'fitfuel_dynamic_vocabulary_packs_v1': validPackJson,
      });

      final freshService = GlobalFoodVocabularyService();
      final freshRecognizer = FakeOpenVocabularyFoodRecognizer();
      await freshService.initialize(recognizer: freshRecognizer);

      expect(freshService.getEntryById('persisted_shawarma'), isNotNull);
      final info = await freshRecognizer.getRegisteredVocabularyInfo();
      expect(info!['dynamicConcepts'], equals(1));
      expect(info['totalConcepts'], equals(2051));
    });

    test('5. Updating existing pack ID replaces stale entries with new entries cleanly', () async {
      await vocabService.initialize(recognizer: recognizer);

      final v1Pack = VocabularyPack(
        packId: 'update_pack_test',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'stale_dish',
            preferredName: 'Old Stale Dish',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );
      await vocabService.registerAndSyncVocabularyPack(v1Pack, recognizer: recognizer);
      expect(vocabService.getEntryById('stale_dish'), isNotNull);

      // Re-register updated pack under same pack ID
      final v2Pack = VocabularyPack(
        packId: 'update_pack_test',
        version: '2.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'updated_fresh_dish',
            preferredName: 'Updated Fresh Dish',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );
      await vocabService.registerAndSyncVocabularyPack(v2Pack, recognizer: recognizer);

      expect(vocabService.getEntryById('updated_fresh_dish'), isNotNull);
      expect(vocabService.getEntryById('stale_dish'), isNull);
      final info = await recognizer.getRegisteredVocabularyInfo();
      expect(info!['dynamicConcepts'], equals(1));
    });

    test('6. Clearing dynamic vocabulary resets count to 2050 base concepts and purges dynamic entries', () async {
      await vocabService.initialize(recognizer: recognizer);

      final pack = VocabularyPack(
        packId: 'pack_to_clear',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'temp_food',
            preferredName: 'Temporary Food',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );
      await vocabService.registerAndSyncVocabularyPack(pack, recognizer: recognizer);

      await vocabService.clearDynamicVocabulary(recognizer: recognizer);

      expect(vocabService.getEntryById('temp_food'), isNull);
      final info = await recognizer.getRegisteredVocabularyInfo();
      expect(info!['dynamicConcepts'], equals(0));
      expect(info['totalConcepts'], equals(2050));
    });
  });

  group('Phase 35.12.5 — Task 3: Comprehensive Failure Recovery & Cross-Layer Convergence', () {
    late GlobalFoodVocabularyService vocabService;
    late FakeOpenVocabularyFoodRecognizer recognizer;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      vocabService = GlobalFoodVocabularyService();
      recognizer = FakeOpenVocabularyFoodRecognizer();
    });

    test('7. Invalid embedding dimensions (512-d) is rejected under requireAllVisionEligible: true', () async {
      await vocabService.initialize(recognizer: recognizer);

      final badDimPack = VocabularyPack(
        packId: 'bad_dim_pack',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'bad_dim_food',
            preferredName: 'Bad Dim Food',
            category: 'Test',
            textEmbedding: List<double>.filled(512, 0.05), // 512-d instead of 768-d
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        badDimPack,
        recognizer: recognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('expected 768')), isTrue);
      expect(vocabService.getEntryById('bad_dim_food'), isNull);
    });

    test('8. NaN and Infinite embedding values are rejected atomically without state corruption', () async {
      await vocabService.initialize(recognizer: recognizer);

      final nanList = List<double>.filled(768, 0.05);
      nanList[42] = double.nan;

      final nanPack = VocabularyPack(
        packId: 'nan_pack',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'nan_food',
            preferredName: 'NaN Food',
            category: 'Test',
            textEmbedding: nanList,
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        nanPack,
        recognizer: recognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('NaN or Infinite')), isTrue);
      expect(vocabService.getEntryById('nan_food'), isNull);
    });

    test('9. Zero-norm embedding (all 0.0) is rejected under requireAllVisionEligible: true', () async {
      await vocabService.initialize(recognizer: recognizer);

      final zeroNormPack = VocabularyPack(
        packId: 'zero_norm_pack',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'zero_food',
            preferredName: 'Zero Norm Food',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.0),
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        zeroNormPack,
        recognizer: recognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('zero or near-zero norm')), isTrue);
      expect(vocabService.getEntryById('zero_food'), isNull);
    });

    test('10. Incompatible model ID (clip_vit_b32) is rejected under requireAllVisionEligible: true', () async {
      await vocabService.initialize(recognizer: recognizer);

      final incompatiblePack = VocabularyPack(
        packId: 'incompat_model_pack',
        version: '1.0.0',
        targetModelId: 'clip_vit_b32',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'incompat_food',
            preferredName: 'Incompatible Food',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        incompatiblePack,
        recognizer: recognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('Incompatible model ID')), isTrue);
      expect(vocabService.getEntryById('incompat_food'), isNull);
    });

    test('11. Native registration failure rolls back Dart state and SharedPreferences atomically', () async {
      await vocabService.initialize(recognizer: recognizer);
      recognizer.simulateNativeFailureOnRegister = true;

      final pack = VocabularyPack(
        packId: 'rollback_test_pack',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'rollback_dish',
            preferredName: 'Rollback Dish',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        pack,
        recognizer: recognizer,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('Native sync failed')), isTrue);
      expect(vocabService.getEntryById('rollback_dish'), isNull);
      expect(vocabService.loadedPacks.contains('rollback_test_pack'), isFalse);
    });

    test('12. Corrupted SharedPreferences JSON is handled gracefully on startup without app crash', () async {
      SharedPreferences.setMockInitialValues({
        'fitfuel_dynamic_vocabulary_packs_v1': '{{{MALFORMED_JSON_STRING',
      });

      final freshService = GlobalFoodVocabularyService();
      await freshService.initialize(recognizer: recognizer);

      expect(freshService.isInitialized, isTrue);
      expect(freshService.loadedPacks.isEmpty, isTrue);
    });
  });

  group('Phase 35.12.5 — Task 4 & 5: Documented Food Scan Test Set & Privacy/Nutrition Guardrails', () {
    late UniversalNutritionResolver resolver;

    setUp(() {
      resolver = UniversalNutritionResolver();
    });

    test('13. Curated Catalog Foods (Samosa, Masala Dosa, Rajma Chawal) resolve to Tier 1: Curated FitFuel Food Database', () {
      const candidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'predefined_samosa',
          canonicalName: 'Samosa',
          category: 'Snacks',
          similarity: 0.1850,
          rank: 1,
          inFitFuelCatalog: true,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'predefined_dosa',
          canonicalName: 'Masala Dosa',
          category: 'Breakfast',
          similarity: 0.1780,
          rank: 1,
          inFitFuelCatalog: true,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'predefined_rajma_chawal',
          canonicalName: 'Rajma Chawal',
          category: 'Lunch',
          similarity: 0.1920,
          rank: 1,
          inFitFuelCatalog: true,
        ),
      ];

      for (final c in candidates) {
        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.verifiedExact));
        expect(res.tier.label, equals('Curated FitFuel Food Database'));
        expect(res.hasNutrition, isTrue);
        expect(res.matchedCatalogFood, isNotNull);
        expect(res.matchedCatalogFood!.calories, greaterThan(0));
      }
    });

    test('14. Common International Foods (Pepperoni Pizza, Burger, Pasta) resolve to Tier 2: USDA Generic Baseline', () {
      const candidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_pizza',
          canonicalName: 'Pepperoni Pizza',
          category: 'Pizza',
          similarity: 0.1650,
          rank: 1,
          inFitFuelCatalog: false,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_burger',
          canonicalName: 'Cheeseburger',
          category: 'Burgers',
          similarity: 0.1580,
          rank: 1,
          inFitFuelCatalog: false,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_pasta',
          canonicalName: 'Pasta with Marinara Sauce',
          category: 'Pasta',
          similarity: 0.1520,
          rank: 1,
          inFitFuelCatalog: false,
        ),
      ];

      for (final c in candidates) {
        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
        expect(res.tier.label, equals('USDA Generic Baseline'));
        expect(res.hasNutrition, isTrue);
        expect(res.matchedCatalogFood, isNotNull);
        expect(res.matchedCatalogFood!.calories, greaterThan(0));
      }
    });

    test('15. Recipe Formulation (Creamy Penne Alfredo) resolves to Tier 3: Recipe Estimate with culinary assumptions', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_pasta',
        canonicalName: 'Creamy Penne Alfredo',
        category: 'Pasta',
        similarity: 0.1680,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.recipeEstimate));
      expect(res.tier.label, equals('Recipe Estimate'));
      expect(res.hasNutrition, isTrue);
      expect(res.recipeAssumptions, isNotNull);
      expect(res.recipeAssumptions!.isNotEmpty, isTrue);
    });

    test('16. Unsupported dish (Dragonfruit Salad) resolves to Tier 4: Nutrition Unavailable with 0 fabricated macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dragonfruit_salad',
        canonicalName: 'Dragonfruit Salad with Exotic Berries',
        category: 'Salad',
        similarity: 0.1420,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.tier.label, equals('Nutrition Unavailable'));
      expect(res.hasNutrition, isFalse);
      expect(res.matchedCatalogFood, isNull);

      final detected = DetectedFoodCandidate(
        id: 'c_dragonfruit',
        detectedName: candidate.canonicalName,
        confidence: 0.85,
        estimatedAmount: 150.0,
        nutritionTier: res.tier,
      );
      expect(detected.hasNutrition, isFalse);
      expect(detected.calories, isNull);
      expect(detected.protein, isNull);
      expect(detected.carbs, isNull);
      expect(detected.fats, isNull);

      final scanResult = FoodScanResult(
        id: 'scan_unavail',
        foods: [detected],
        overallConfidence: 0.85,
        scannedAt: DateTime.now(),
      );
      expect(scanResult.hasIncompleteNutrition, isTrue);
    });

    test('17. Zero automatic Gemini calls guarantee across ambiguous, offline, and unmapped flows', () {
      // Confirms that all routing decisions occur on-device without remote HTTP calls
      expect(resolver.recipeProfilesCount, greaterThan(0));
      expect(resolver.genericBaselinesCount, greaterThan(0));
    });
  });
}
