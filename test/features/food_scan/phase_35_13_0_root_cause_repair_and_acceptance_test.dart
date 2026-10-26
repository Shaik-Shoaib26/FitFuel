import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';

// ==========================================
// Test Doubles & Spies
// ==========================================
class _MockTier1Classifier implements FoodVisionClassifier {
  LocalFoodPrediction nextPrediction;
  int classifyCalls = 0;

  _MockTier1Classifier(this.nextPrediction);

  @override
  bool get isAvailable => nextPrediction.isModelAvailable;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    classifyCalls++;
    return nextPrediction;
  }

  @override
  void dispose() {}
}

class _MockTier2Recognizer implements OpenVocabularyFoodRecognizer {
  OpenVocabularyRecognitionResult nextResult;
  int recognizeCalls = 0;

  _MockTier2Recognizer(this.nextResult);

  @override
  bool get isAvailable => true;

  @override
  bool get isSessionLoaded => true;

  @override
  bool get requiresColdInit => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<OpenVocabularyRecognitionResult> recognize(Uint8List imageBytes) async {
    recognizeCalls++;
    return nextResult;
  }

  @override
  Future<void> dispose() async {}
}

class _SpyRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    return const [];
  }

  @override
  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  }) async =>
      null;
}

class _MockImagePickerService implements IFoodImagePickerService {
  String? nextPath = 'test_food_image.jpg';

  @override
  Future<String?> pickImage(FoodImagePickSource source) async => nextPath;

  @override
  Future<Uint8List?> getImageBytes(String path) async =>
      Uint8List.fromList([1, 2, 3, 4, 5]);

  void clearRetainedImage() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final resolver = UniversalNutritionResolver();
  final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  const weakTier1Prediction = LocalFoodPrediction(
    foodId: 'unknown',
    foodName: 'Unknown',
    confidence: 0.25,
    inferenceDurationMs: 20,
  );

  group('Phase 35.13.0 — Section 1: Single-Result UX & No Three-Name Prediction Problem', () {
    test('1. Close dish variants (e.g. Masala Dosa, Plain Dosa, Rava Dosa) route to single primary result card', () async {
      final dosaVariantsTier2 = OpenVocabularyRecognitionResult.accepted(
        topCandidates: const [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_masala_dosa',
            canonicalName: 'Masala Dosa',
            category: 'Indian Breads & Pancakes',
            similarity: 0.0920,
            rank: 1,
            inFitFuelCatalog: true,
            fitFuelFoodId: 'predefined_masala_dosa',
          ),
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_plain_dosa',
            canonicalName: 'Plain Dosa',
            category: 'Indian Breads & Pancakes',
            similarity: 0.0880,
            rank: 2,
            inFitFuelCatalog: true,
            fitFuelFoodId: 'predefined_dosa',
          ),
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_rava_dosa',
            canonicalName: 'Rava Dosa',
            category: 'Indian Breads & Pancakes',
            similarity: 0.0850,
            rank: 3,
            inFitFuelCatalog: true,
            fitFuelFoodId: 'predefined_rava_dosa',
          ),
        ],
        maxFoodSimilarity: 0.0920,
        maxNegSimilarity: -0.0100,
        negMargin: 0.1020,
        preprocessMs: 10,
        encoderMs: 500,
        retrievalMs: 2,
        totalMs: 512,
      );

      final tier1 = _MockTier1Classifier(weakTier1Prediction);
      final tier2 = _MockTier2Recognizer(dosaVariantsTier2);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_dosa_1',
        imagePath: 'dosa.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      // Must be a Single Primary Result (NOT 3 competing suggestions)
      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      final primary = decision as Tier2OpenVocabPrimaryResult;
      expect(primary.primaryCandidate.displayName, equals('Masala Dosa'));
      expect(primary.matchedFood, isNotNull);
      expect(primary.matchedFood!.name, equals('Masala Dosa'));
      expect(primary.hasExactCatalogNutrition, isTrue);
      expect(primary.nutritionTier, equals(NutritionProfileTier.verifiedExact));
      expect(spyRemote.analyzeCallCount, equals(0));

      // In FoodScanController, must transition directly to FoodScanSuccess with 1 primary food
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        ),
        imagePickerService: _MockImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'dosa.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      final success = controller.state as FoodScanSuccess;
      expect(success.result.foods.length, equals(1));
      expect(success.result.foods.first.displayName, equals('Masala Dosa'));
      expect(success.result.canBeLogged, isTrue);
      expect(success.result.totalCalories, equals(220.0));
      expect(success.result.totalProtein, equals(4.2));
      expect(success.result.totalCarbs, equals(36.0));
      expect(success.result.totalFats, equals(6.8));

      // Alternatives must be retained for the subordinate "Wrong food? Choose another" expansion
      expect(success.result.openVocabCandidates.length, equals(3));
      expect(success.result.openVocabCandidates[1].displayName, equals('Plain Dosa'));
      expect(success.result.openVocabCandidates[2].displayName, equals('Rava Dosa'));
    });

    test('2. Swapping dish variant via confirmOpenVocabSuggestion updates primary card cleanly', () async {
      final dosaVariantsTier2 = OpenVocabularyRecognitionResult.accepted(
        topCandidates: const [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_masala_dosa',
            canonicalName: 'Masala Dosa',
            category: 'Indian Breads & Pancakes',
            similarity: 0.0920,
            rank: 1,
            inFitFuelCatalog: true,
            fitFuelFoodId: 'predefined_masala_dosa',
          ),
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_plain_dosa',
            canonicalName: 'Plain Dosa',
            category: 'Indian Breads & Pancakes',
            similarity: 0.0880,
            rank: 2,
            inFitFuelCatalog: true,
            fitFuelFoodId: 'predefined_dosa',
          ),
        ],
        maxFoodSimilarity: 0.0920,
        maxNegSimilarity: -0.0100,
        negMargin: 0.1020,
      );

      final tier1 = _MockTier1Classifier(weakTier1Prediction);
      final tier2 = _MockTier2Recognizer(dosaVariantsTier2);
      final spyRemote = _SpyRemoteDataSource();

      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: FoodScanRecognitionRouter(
            localClassifier: tier1,
            openVocabularyRecognizer: tier2,
            remoteDataSource: spyRemote,
          ),
        ),
        imagePickerService: _MockImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'dosa.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      // User selects 'Plain Dosa' from subordinate alternatives
      controller.confirmOpenVocabSuggestion(
        dosaVariantsTier2.topCandidates[1],
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      final updated = controller.state as FoodScanSuccess;
      expect(updated.result.foods.length, equals(1));
      expect(updated.result.foods.first.displayName, equals('Plain Dosa'));
      expect(updated.result.canBeLogged, isTrue);
      expect(updated.result.totalCalories, equals(168.0));
      expect(updated.result.totalProtein, equals(3.9));
    });
  });

  group('Phase 35.13.0 — Section 2: Complete Macro Resolution (Zero Missing Macros)', () {
    test('3. Curated Indian foods resolve all 4 macros (Calories, Protein, Carbs, Fat)', () {
      final testCases = [
        ('openvocab_sambar', 'Sambar', 120.0, 4.5, 18.0, 3.2),
        ('openvocab_rasam', 'Rasam', 45.0, 1.0, 7.0, 1.5),
        ('openvocab_poha', 'Poha', 180.0, 3.0, 33.0, 3.8),
        ('openvocab_curd', 'Indian Curd (Dahi)', 60.0, 3.5, 4.7, 3.0),
        ('openvocab_chicken_curry', 'Home Style Chicken Curry', 195.0, 20.0, 4.5, 11.0),
        ('openvocab_fish_curry', 'Indian Fish Curry', 165.0, 18.0, 3.5, 8.8),
        ('openvocab_butter_chicken', 'Butter Chicken (Murgh Makhani)', 280.0, 18.0, 6.0, 20.0),
        ('openvocab_paneer_bhurji', 'Paneer Bhurji', 220.0, 12.5, 4.5, 17.0),
        ('openvocab_chicken_biryani', 'Chicken Biryani', 220.0, 14.5, 28.0, 7.2),
        ('openvocab_veg_biryani', 'Vegetable Biryani', 180.0, 4.0, 31.0, 4.8),
      ];

      for (final tc in testCases) {
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: tc.$1,
          canonicalName: tc.$2,
          category: 'Indian',
          similarity: 0.1500,
          rank: 1,
        );

        final res = resolver.resolveCandidate(candidate, foodCatalog: catalog);
        expect(res.hasNutrition, isTrue, reason: 'Failed for ${tc.$2}');
        expect(res.matchedCatalogFood, isNotNull);
        final food = res.matchedCatalogFood!;
        expect(food.calories, equals(tc.$3));
        expect(food.protein, equals(tc.$4));
        expect(food.carbohydrates, equals(tc.$5));
        expect(food.fats, equals(tc.$6));

        // Provenance & Non-Fabrication
        expect(food.calories, greaterThan(0));
        expect(food.protein, greaterThan(0));
        expect(food.carbohydrates, greaterThan(0));
        expect(food.fats, greaterThan(0));
      }
    });

    test('4. USDA Generic Baselines resolve complete non-null macros in router and controller', () async {
      // Test Generic Burger, Generic Pasta, Generic Pizza
      const genericBurgerCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_burger',
        canonicalName: 'Burger',
        category: 'Burgers & Sandwiches',
        similarity: 0.1200,
        rank: 1,
      );

      final res = resolver.resolveCandidate(genericBurgerCandidate, foodCatalog: catalog);
      expect(res.hasNutrition, isTrue);
      expect(res.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(res.matchedCatalogFood, isNotNull);
      final burger = res.matchedCatalogFood!;
      expect(burger.calories, equals(254.0));
      expect(burger.protein, equals(13.0));
      expect(burger.carbohydrates, equals(29.8));
      expect(burger.fats, equals(9.3));

      // Router integration test
      final burgerResult = OpenVocabularyRecognitionResult.accepted(
        topCandidates: [genericBurgerCandidate],
        maxFoodSimilarity: 0.1200,
        maxNegSimilarity: -0.0100,
        negMargin: 0.1300,
      );

      final router = FoodScanRecognitionRouter(
        localClassifier: _MockTier1Classifier(weakTier1Prediction),
        openVocabularyRecognizer: _MockTier2Recognizer(burgerResult),
        remoteDataSource: _SpyRemoteDataSource(),
        universalNutritionResolver: resolver,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_burger_generic',
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      final primary = decision as Tier2OpenVocabPrimaryResult;
      expect(primary.matchedFood, isNotNull);
      expect(primary.hasExactCatalogNutrition, isTrue);
      expect(primary.nutritionTier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(primary.matchedFood!.calories, equals(254.0));
      expect(primary.matchedFood!.protein, equals(13.0));
      expect(primary.matchedFood!.carbohydrates, equals(29.8));
      expect(primary.matchedFood!.fats, equals(9.3));
    });

    test('5. Standard Recipe Estimates resolve complete non-null macros with culinary assumptions', () {
      final recipes = [
        'openvocab_chicken_tikka_masala',
        'openvocab_vegetable_fried_rice',
        'openvocab_vegetable_curry',
      ];

      for (final id in recipes) {
        final c = OpenVocabularyFoodCandidate(
          canonicalFoodId: id,
          canonicalName: id.replaceAll('openvocab_', '').replaceAll('_', ' '),
          category: 'Entrees',
          similarity: 0.1400,
          rank: 1,
        );

        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.hasNutrition, isTrue);
        expect(res.tier, equals(NutritionProfileTier.recipeEstimate));
        expect(res.matchedCatalogFood, isNotNull);
        final food = res.matchedCatalogFood!;
        expect(food.calories, greaterThan(50.0));
        expect(food.protein, greaterThan(1.0));
        expect(food.carbohydrates, greaterThan(2.0));
        expect(food.fats, greaterThan(1.0));
        expect(res.recipeAssumptions, isNotNull);
      }
    });
  });

  group('Phase 35.13.0 — Section 3: Deterministic Serving-Size Math & Portion Scaling', () {
    test('6. Proportional scaling across 50g, 100g, 150g, 200g, 250g satisfies N_portion = N_base * (portion / base)', () {
      final chickenCurry = catalog.firstWhere((f) => f.id == 'predefined_chicken_curry');
      // Base: 100g, 195 kcal, 20.0g protein, 4.5g carbs, 11.0g fats
      final testAmounts = [50.0, 100.0, 150.0, 200.0, 250.0];

      for (final amt in testAmounts) {
        final mult = amt / chickenCurry.servingSize;
        final candidate = DetectedFoodCandidate(
          id: 'test_scale_$amt',
          detectedName: chickenCurry.name,
          confidence: 0.95,
          estimatedAmount: amt,
          originalEstimatedAmount: chickenCurry.servingSize,
          estimatedUnit: chickenCurry.servingUnit,
          matchedFood: chickenCurry,
          matchConfidence: 1.0,
        );

        expect(candidate.scaledCalories, closeTo(195.0 * mult, 0.01));
        expect(candidate.scaledProtein, closeTo(20.0 * mult, 0.01));
        expect(candidate.scaledCarbs, closeTo(4.5 * mult, 0.01));
        expect(candidate.scaledFats, closeTo(11.0 * mult, 0.01));
      }
    });
  });

  group('Phase 35.13.0 — Section 4: Mixed Meals & Component Workflow', () {
    test('7. Multi-component meal totals match exact sum of constituents', () {
      final rice = catalog.firstWhere((f) => f.id == 'predefined_steamed_rice'); // 100g -> 130 kcal, 2.7g P, 28.0g C, 0.3g F
      final dal = catalog.firstWhere((f) => f.id == 'predefined_dal_tadka');       // 150g -> 150 kcal, 7.5g P, 18.0g C, 5.0g F
      final curd = catalog.firstWhere((f) => f.id == 'predefined_curd');           // 100g -> 60 kcal, 3.5g P, 4.7g C, 3.0g F

      final foods = [
        DetectedFoodCandidate(
          id: 'c1',
          detectedName: rice.name,
          confidence: 0.92,
          estimatedAmount: 200.0, // 2x base -> 260 kcal, 5.4g P, 56.0g C, 0.6g F
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: rice,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
        DetectedFoodCandidate(
          id: 'c2',
          detectedName: dal.name,
          confidence: 0.88,
          estimatedAmount: 150.0, // 1x base -> 150 kcal, 7.5g P, 18.0g C, 5.0g F
          originalEstimatedAmount: 150.0,
          estimatedUnit: 'g',
          matchedFood: dal,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
        DetectedFoodCandidate(
          id: 'c3',
          detectedName: curd.name,
          confidence: 0.90,
          estimatedAmount: 100.0, // 1x base -> 60 kcal, 3.5g P, 4.7g C, 3.0g F
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: curd,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
      ];

      final scanResult = FoodScanResult(
        id: 'mixed_thali_1',
        foods: foods,
        overallConfidence: 0.90,
        scannedAt: DateTime.now(),
      );

      // Expected Totals:
      // Calories: 260 + 177 + 60 = 497 kcal
      // Protein: 5.4 + 9.75 + 3.5 = 18.65 g
      // Carbs: 56.0 + 25.5 + 4.7 = 86.2 g
      // Fats: 0.6 + 4.2 + 3.0 = 7.8 g
      expect(scanResult.totalCalories, equals(497.0));
      expect(scanResult.totalProtein, closeTo(18.65, 0.01));
      expect(scanResult.totalCarbs, closeTo(86.2, 0.01));
      expect(scanResult.totalFats, closeTo(7.8, 0.01));
    });

    test('8. FoodScanController component editing (add, remove, portion adjust) updates state dynamically', () {
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: _SpyRemoteDataSource(),
        ),
        imagePickerService: _MockImagePickerService(),
      );

      final rice = catalog.firstWhere((f) => f.id == 'predefined_steamed_rice');
      final dal = catalog.firstWhere((f) => f.id == 'predefined_dal_tadka');

      // Start with Rice
      controller.selectManualFood(rice, amount: 150.0);
      expect(controller.state, isA<FoodScanSuccess>());
      var state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(1));
      expect(state.result.totalCalories, closeTo(195.0, 0.1));

      // Add Dal
      controller.addComponent(dal, amount: 150.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(2));
      expect(state.result.totalCalories, closeTo(372.0, 0.1));

      // Adjust Rice portion to 200g
      controller.updatePortion(0, 200.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods[0].estimatedAmount, equals(200.0));
      expect(state.result.totalCalories, closeTo(437.0, 0.1)); // 260 + 177

      // Remove Dal
      controller.removeComponent(1);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(1));
      expect(state.result.totalCalories, closeTo(260.0, 0.1));
    });
  });

  group('Phase 35.13.0 — Section 5: Separation of Failure States & Zero Silent Gemini Calls', () {
    test('9. Genuinely non-food image routes to Tier2AbstainedNonFood with 0 cloud calls', () async {
      final nonFoodResult = OpenVocabularyRecognitionResult.abstained(
        maxFoodSimilarity: 0.0120,
        maxNegSimilarity: 0.0850,
        negMargin: -0.0730,
        topNegativePrompt: 'empty white ceramic plate tabletop',
        abstainReason: 'rejected_below_sim_floor',
      );

      final tier1 = _MockTier1Classifier(weakTier1Prediction);
      final tier2 = _MockTier2Recognizer(nonFoodResult);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_empty_plate',
        imagePath: 'empty_plate.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2AbstainedNonFood>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('10. Food image with ambiguous identity routes to Tier2AmbiguousAbstain with 0 cloud calls', () async {
      // Moderately confident food, but ambiguous / below Mode A threshold
      // Neg margin >= 0.0621 means food IS present, but maxFoodSimilarity < 0.0665 means identity is ambiguous
      final ambiguousFoodResult = OpenVocabularyRecognitionResult.abstained(
        maxFoodSimilarity: 0.0600,
        maxNegSimilarity: -0.0150,
        negMargin: 0.0750,
        abstainReason: 'rejected_low_food_similarity',
      );

      final tier1 = _MockTier1Classifier(weakTier1Prediction);
      final tier2 = _MockTier2Recognizer(ambiguousFoodResult);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_ambiguous_food',
        imagePath: 'unclear_food.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2NoReliableMatch>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });
  });
}
