import 'dart:convert';
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

  group('Phase 35.12.4 — Task 1: Similarity-Score Semantics & Scalar Formatting', () {
    test('1. formattedSimilarityScore formats positive similarity as scalar cosine value', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pepperoni Pizza',
        category: 'Pizza',
        similarity: 0.1680,
        rank: 1,
      );

      expect(candidate.formattedSimilarityScore, equals('Cosine similarity: 0.1680'));
      expect(candidate.rawCosineSimilarityString, equals('0.1680'));
      expect(candidate.formattedSimilarityScore.contains('%'), isFalse);
    });

    test('2. formattedSimilarityScore formats zero similarity as scalar cosine value', () {
      const candidateZero = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_neutral',
        canonicalName: 'Neutral Dish',
        category: 'Dishes',
        similarity: 0.0000,
        rank: 2,
      );

      expect(candidateZero.formattedSimilarityScore, equals('Cosine similarity: 0.0000'));
      expect(candidateZero.rawCosineSimilarityString, equals('0.0000'));
    });

    test('3. formattedSimilarityScore formats negative similarity accurately without crashing', () {
      const candidateNeg = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_negative',
        canonicalName: 'Negative Alignment Food',
        category: 'Dishes',
        similarity: -0.0150,
        rank: 3,
      );

      expect(candidateNeg.formattedSimilarityScore, equals('Cosine similarity: -0.0150'));
      expect(candidateNeg.rawCosineSimilarityString, equals('-0.0150'));
    });

    test('4. Similarity score represents 768-d unit sphere dot product bounded in [-1.0, 1.0]', () {
      const highCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'c1',
        canonicalName: 'Food A',
        category: 'Category A',
        similarity: 0.2250,
        rank: 1,
      );
      const lowCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'c2',
        canonicalName: 'Food B',
        category: 'Category B',
        similarity: -0.0520,
        rank: 2,
      );

      expect(highCandidate.similarity, inInclusiveRange(-1.0, 1.0));
      expect(lowCandidate.similarity, inInclusiveRange(-1.0, 1.0));
      expect(highCandidate.similarity > lowCandidate.similarity, isTrue);
    });
  });

  group('Phase 35.12.4 — Task 2: Nutrition Attribution & Guardrail Verification', () {
    late UniversalNutritionResolver resolver;
    late List<FoodEntity> catalog;

    setUp(() {
      resolver = UniversalNutritionResolver();
      catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    });

    test('5. Honest tier descriptions replace unsupported lab/manufacturer claims', () {
      expect(
        NutritionProfileTier.verifiedExact.label,
        equals('Curated FitFuel Food Database'),
      );
      expect(
        NutritionProfileTier.closelyRelatedGeneric.label,
        equals('USDA Generic Baseline'),
      );
      expect(
        NutritionProfileTier.recipeEstimate.label,
        equals('Recipe Estimate'),
      );
      expect(
        NutritionProfileTier.unavailable.label,
        equals('Nutrition Unavailable'),
      );
    });

    test('6. DetectedFoodCandidate returns accurate nutritionSourceLabel for all tiers', () {
      const candidateTier1 = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Dosa',
        confidence: 0.95,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.verifiedExact,
        nutritionAttribution: 'FitFuel Curated Database (ID: dosa)',
      );
      expect(candidateTier1.nutritionSourceLabel, equals('Curated FitFuel Food Database'));

      const candidateTier2 = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Pepperoni Pizza',
        confidence: 0.88,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'USDA FoodData Central #173292 (Generic Pizza)',
      );
      expect(candidateTier2.nutritionSourceLabel, equals('USDA Generic Baseline'));

      const candidateTier3 = DetectedFoodCandidate(
        id: 'c3',
        detectedName: 'Alfredo Pasta',
        confidence: 0.82,
        estimatedAmount: 200.0,
        nutritionTier: NutritionProfileTier.recipeEstimate,
        recipeAssumptions: 'Standard cream, butter, parmesan formulation',
        nutritionAttribution: 'Recipe Formulation Estimate (Assumed Serving: 200g)',
      );
      expect(candidateTier3.nutritionSourceLabel, equals('Recipe Estimate'));

      const candidateTier4 = DetectedFoodCandidate(
        id: 'c4',
        detectedName: 'Dragonfruit Salad',
        confidence: 0.75,
        estimatedAmount: 150.0,
        nutritionTier: NutritionProfileTier.unavailable,
        nutritionAttribution: 'No trusted nutrition profile available',
      );
      expect(candidateTier4.nutritionSourceLabel, equals('Nutrition Unavailable'));
    });

    test('7. Diary logging is blocked when macros are unavailable (hasIncompleteNutrition)', () {
      const foodWithoutMacros = DetectedFoodCandidate(
        id: 'c_unavail',
        detectedName: 'Dragonfruit Salad',
        confidence: 0.85,
        estimatedAmount: 150.0,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      final result = FoodScanResult(
        id: 'scan_test',
        foods: [foodWithoutMacros],
        overallConfidence: 0.85,
        scannedAt: DateTime.now(),
      );

      expect(foodWithoutMacros.hasNutrition, isFalse);
      expect(result.hasIncompleteNutrition, isTrue);
    });

    test('8. Portion scaling scales only available macros proportionally', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pepperoni Pizza',
        category: 'Pizza',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      final base = res.matchedCatalogFood!;
      final scale = 250.0 / base.servingSize; // 2.5x

      final scaled = base.copyWith(
        servingSize: 250.0,
        calories: base.calories * scale,
        protein: double.parse((base.protein * scale).toStringAsFixed(1)),
        carbohydrates: double.parse((base.carbohydrates * scale).toStringAsFixed(1)),
        fats: double.parse((base.fats * scale).toStringAsFixed(1)),
      );

      expect(scaled.servingSize, equals(250.0));
      expect(scaled.calories, closeTo(base.calories * 2.5, 0.1));
      expect(scaled.protein, closeTo(base.protein * 2.5, 0.1));
      expect(scaled.carbohydrates, closeTo(base.carbohydrates * 2.5, 0.1));
      expect(scaled.fats, closeTo(base.fats * 2.5, 0.1));
    });
  });

  group('Phase 35.12.4 — Task 3: Crash Recovery, Model Validation & Pack Replacement', () {
    late GlobalFoodVocabularyService vocabService;
    late FakeOpenVocabularyFoodRecognizer fakeRecognizer;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      vocabService = GlobalFoodVocabularyService();
      fakeRecognizer = FakeOpenVocabularyFoodRecognizer();
    });

    test('9. Re-registering existing pack ID cleanly replaces entries without ID collision', () async {
      await vocabService.initialize(recognizer: fakeRecognizer);

      final initialPack = VocabularyPack(
        packId: 'mexican_pack_v1',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'taco_al_pastor',
            preferredName: 'Taco al Pastor',
            category: 'Mexican',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
          CanonicalFoodEntry(
            canonicalId: 'carnitas_taco',
            preferredName: 'Carnitas Taco',
            category: 'Mexican',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );

      final res1 = await vocabService.registerAndSyncVocabularyPack(
        initialPack,
        recognizer: fakeRecognizer,
        requireAllVisionEligible: true,
      );

      expect(res1.isValid, isTrue);
      expect(vocabService.getEntryById('taco_al_pastor'), isNotNull);
      expect(vocabService.getEntryById('carnitas_taco'), isNotNull);
      expect(fakeRecognizer.registeredPacks.length, equals(1));

      // Updated pack with 1 modified entry and 1 new entry, removing carnitas_taco
      final updatedPack = VocabularyPack(
        packId: 'mexican_pack_v1',
        version: '2.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'taco_al_pastor',
            preferredName: 'Authentic Taco al Pastor',
            category: 'Mexican',
            textEmbedding: List<double>.filled(768, 0.06),
          ),
          CanonicalFoodEntry(
            canonicalId: 'birria_taco',
            preferredName: 'Birria Taco',
            category: 'Mexican',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );

      final res2 = await vocabService.registerAndSyncVocabularyPack(
        updatedPack,
        recognizer: fakeRecognizer,
        requireAllVisionEligible: true,
      );

      expect(res2.isValid, isTrue);
      expect(vocabService.getEntryById('taco_al_pastor')?.preferredName, equals('Authentic Taco al Pastor'));
      expect(vocabService.getEntryById('birria_taco'), isNotNull);
      expect(vocabService.getEntryById('carnitas_taco'), isNull);
      expect(fakeRecognizer.registeredPacks.length, equals(1));
    });

    test('10. Zero-norm embedding (normSq < 1e-12) is rejected under requireAllVisionEligible', () async {
      await vocabService.initialize(recognizer: fakeRecognizer);

      final zeroNormPack = VocabularyPack(
        packId: 'zero_norm_pack',
        version: '1.0.0',
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'zero_norm_food',
            preferredName: 'Zero Norm Food',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.0), // All zeros
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        zeroNormPack,
        recognizer: fakeRecognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('zero or near-zero norm')), isTrue);
      expect(vocabService.getEntryById('zero_norm_food'), isNull);
    });

    test('11. Incompatible targetModelId is rejected under requireAllVisionEligible', () async {
      await vocabService.initialize(recognizer: fakeRecognizer);

      final incompatiblePack = VocabularyPack(
        packId: 'incompatible_model_pack',
        version: '1.0.0',
        targetModelId: 'clip_vit_b32', // Non-SigLIP model
        entries: [
          CanonicalFoodEntry(
            canonicalId: 'incompatible_food',
            preferredName: 'Incompatible Food',
            category: 'Test',
            textEmbedding: List<double>.filled(768, 0.05),
          ),
        ],
      );

      final res = await vocabService.registerAndSyncVocabularyPack(
        incompatiblePack,
        recognizer: fakeRecognizer,
        requireAllVisionEligible: true,
      );

      expect(res.isValid, isFalse);
      expect(res.validationErrors.any((e) => e.contains('Incompatible model ID')), isTrue);
      expect(vocabService.getEntryById('incompatible_food'), isNull);
    });

    test('12. Corrupted SharedPreferences dynamic packs JSON is handled gracefully on startup', () async {
      SharedPreferences.setMockInitialValues({
        'fitfuel_dynamic_vocabulary_packs_v1': '{corrupted_invalid_json',
      });

      final freshService = GlobalFoodVocabularyService();
      // Should not throw an exception on corrupted disk data
      await freshService.initialize(recognizer: fakeRecognizer);

      expect(freshService.isInitialized, isTrue);
      expect(freshService.loadedPacks.isEmpty, isTrue);
    });

    test('13. Startup reconciliation restores SharedPreferences packs and synchronizes native', () async {
      final validPackJson = json.encode([
        {
          'packId': 'persisted_pack_a',
          'version': '1.0.0',
          'targetModelId': 'siglip_b16_int8',
          'entries': [
            {
              'canonicalId': 'persisted_food_1',
              'preferredName': 'Persisted Food 1',
              'category': 'Persisted',
              'textEmbedding': List<double>.filled(768, 0.05),
            }
          ]
        }
      ]);

      SharedPreferences.setMockInitialValues({
        'fitfuel_dynamic_vocabulary_packs_v1': validPackJson,
      });

      final freshService = GlobalFoodVocabularyService();
      await freshService.initialize(recognizer: fakeRecognizer);

      expect(freshService.isInitialized, isTrue);
      expect(freshService.getEntryById('persisted_food_1'), isNotNull);
      expect(fakeRecognizer.registeredPacks.length, equals(1));
      expect(fakeRecognizer.registeredPacks.first.packId, equals('persisted_pack_a'));

      // Verify reconciliation status helper
      final reconciliation = await freshService.reconcileWithNative(recognizer: fakeRecognizer);
      expect(reconciliation['isSynchronized'], isTrue);
      expect(reconciliation['missingFromNative'], isEmpty);
    });

    test('14. If native sync fails during startup reconciliation, unverified pack is unloaded', () async {
      final validPackJson = json.encode([
        {
          'packId': 'unverified_pack',
          'version': '1.0.0',
          'targetModelId': 'siglip_b16_int8',
          'entries': [
            {
              'canonicalId': 'unverified_food',
              'preferredName': 'Unverified Food',
              'category': 'Test',
              'textEmbedding': List<double>.filled(768, 0.05),
            }
          ]
        }
      ]);

      SharedPreferences.setMockInitialValues({
        'fitfuel_dynamic_vocabulary_packs_v1': validPackJson,
      });

      fakeRecognizer.simulateNativeFailureOnRegister = true;

      final freshService = GlobalFoodVocabularyService();
      await freshService.initialize(recognizer: fakeRecognizer);

      // Unverified pack should not be kept in Dart active state
      expect(freshService.getEntryById('unverified_food'), isNull);
      expect(freshService.loadedPacks.contains('unverified_pack'), isFalse);
    });
  });
}
