import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_recognition_cascade.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
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
  Future<OpenVocabularyRecognitionResult> recognize(
    Uint8List imageBytes, {
    int topK = 5,
    double threshold = 0.0181,
  }) async {
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

  late List<FoodEntity> catalog;
  late UniversalNutritionResolver resolver;
  final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  setUp(() {
    catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    resolver = UniversalNutritionResolver();
  });

  group('Phase 35.13.2 Defect A: Nutrition Coverage & Resolution', () {
    test('Recognized supported food resolves to correct profile and displays all core macros', () {
      const chapatiCand = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_chapati',
        canonicalName: 'Chapati',
        category: 'Indian Breads',
        similarity: 0.1250,
        rank: 1,
      );
      final res = resolver.resolveCandidate(chapatiCand, foodCatalog: catalog);

      expect(res.isVerifiedExact, isTrue);
      expect(res.hasNutrition, isTrue);
      final food = res.matchedCatalogFood;
      expect(food, isNotNull);
      expect(food!.calories, greaterThan(0));
      expect(food.protein, greaterThan(0));
      expect(food.carbohydrates, greaterThan(0));
      expect(food.fats, greaterThanOrEqualTo(0));

      final detected = DetectedFoodCandidate(
        id: 'det_1',
        detectedName: food.name,
        confidence: 0.95,
        estimatedAmount: food.servingSize,
        originalEstimatedAmount: food.servingSize,
        estimatedUnit: food.servingUnit,
        matchedFood: food,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: res.tier,
      );

      expect(detected.hasNutrition, isTrue);
      expect(detected.calories, isNotNull);
      expect(detected.protein, isNotNull);
      expect(detected.carbs, isNotNull);
      expect(detected.fats, isNotNull);
    });

    test('Known regional aliases resolve to intended canonical profiles with complete nutrition', () {
      const dalAlias = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dal',
        canonicalName: 'Dal',
        category: 'Indian Curries',
        similarity: 0.0890,
        rank: 1,
      );
      final dalRes = resolver.resolveCandidate(dalAlias, foodCatalog: catalog);
      expect(dalRes.hasNutrition, isTrue);
      expect(dalRes.matchedCatalogFood?.name.toLowerCase(), contains('dal'));

      const saladAlias = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_salad',
        canonicalName: 'Salad',
        category: 'Salads',
        similarity: 0.0820,
        rank: 1,
      );
      final saladRes = resolver.resolveCandidate(saladAlias, foodCatalog: catalog);
      expect(saladRes.hasNutrition, isTrue);
      expect(saladRes.matchedCatalogFood?.name.toLowerCase(), contains('salad'));

      const vegCurryAlias = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_curry',
        canonicalName: 'Curry',
        category: 'Indian Curries',
        similarity: 0.0780,
        rank: 1,
      );
      final curryRes = resolver.resolveCandidate(vegCurryAlias, foodCatalog: catalog);
      expect(curryRes.hasNutrition, isTrue);
      expect(curryRes.matchedCatalogFood?.name.toLowerCase(), contains('curry'));
    });

    test('Indiscriminate profile sharing is prevented: Kimbap does NOT resolve to sushi baseline', () {
      const kimbapCand = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_kimbap',
        canonicalName: 'Kimbap',
        category: 'Korean Dishes',
        similarity: 0.0910,
        rank: 1,
      );
      final res = resolver.resolveCandidate(kimbapCand, foodCatalog: catalog);

      // Kimbap must return honest unavailable state without fabricating sushi raw fish macros
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.matchedCatalogFood, isNull);
      expect(res.hasNutrition, isFalse);

      final detected = DetectedFoodCandidate(
        id: 'det_kimbap',
        detectedName: kimbapCand.displayName,
        confidence: kimbapCand.similarity,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: null,
        matchConfidence: 0.0,
        recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
        nutritionTier: res.tier,
      );

      expect(detected.hasNutrition, isFalse);
      expect(detected.calories, isNull);
      expect(detected.protein, isNull);
      expect(detected.carbs, isNull);
      expect(detected.fats, isNull);
    });

    test('Portion changes scale all available nutrition values accurately', () {
      final chapatiFood = catalog.firstWhere((f) => f.id == 'predefined_chapati');
      final baseServing = chapatiFood.servingSize; // e.g. 50g

      final detected100g = DetectedFoodCandidate(
        id: 'det_scale',
        detectedName: chapatiFood.name,
        confidence: 0.95,
        estimatedAmount: baseServing * 2.0, // 2x portion
        originalEstimatedAmount: baseServing,
        estimatedUnit: chapatiFood.servingUnit,
        matchedFood: chapatiFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      expect(detected100g.calories, closeTo(chapatiFood.calories * 2.0, 0.01));
      expect(detected100g.protein, closeTo(chapatiFood.protein * 2.0, 0.01));
      expect(detected100g.carbs, closeTo(chapatiFood.carbohydrates * 2.0, 0.01));
      expect(detected100g.fats, closeTo(chapatiFood.fats * 2.0, 0.01));

      final detectedHalf = DetectedFoodCandidate(
        id: 'det_scale_half',
        detectedName: chapatiFood.name,
        confidence: 0.95,
        estimatedAmount: baseServing * 0.5, // 0.5x portion
        originalEstimatedAmount: baseServing,
        estimatedUnit: chapatiFood.servingUnit,
        matchedFood: chapatiFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      expect(detectedHalf.calories, closeTo(chapatiFood.calories * 0.5, 0.01));
      expect(detectedHalf.protein, closeTo(chapatiFood.protein * 0.5, 0.01));
      expect(detectedHalf.carbs, closeTo(chapatiFood.carbohydrates * 0.5, 0.01));
      expect(detectedHalf.fats, closeTo(chapatiFood.fats * 0.5, 0.01));
    });
  });

  group('Phase 35.13.2 Defect B: Mixed Meals (Chapati, Dal, Curry, Salad)', () {
    test('A 4-component meal calculates honest totals across confirmed components', () {
      final chapatiFood = catalog.firstWhere((f) => f.id == 'predefined_chapati');
      final dalFood = catalog.firstWhere((f) => f.id == 'predefined_dal_tadka');
      final curryFood = catalog.firstWhere((f) => f.id == 'predefined_mixed_veg_curry');
      final saladFood = catalog.firstWhere((f) => f.id == 'predefined_mixed_veg_salad');

      final chapati = DetectedFoodCandidate(
        id: 'comp_1',
        detectedName: chapatiFood.name,
        confidence: 0.92,
        estimatedAmount: 100.0, // 2 chapatis (~100g)
        originalEstimatedAmount: chapatiFood.servingSize,
        estimatedUnit: chapatiFood.servingUnit,
        matchedFood: chapatiFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      final dal = DetectedFoodCandidate(
        id: 'comp_2',
        detectedName: dalFood.name,
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: dalFood.servingSize,
        estimatedUnit: dalFood.servingUnit,
        matchedFood: dalFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      final curry = DetectedFoodCandidate(
        id: 'comp_3',
        detectedName: curryFood.name,
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: curryFood.servingSize,
        estimatedUnit: curryFood.servingUnit,
        matchedFood: curryFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      final salad = DetectedFoodCandidate(
        id: 'comp_4',
        detectedName: saladFood.name,
        confidence: 1.0,
        estimatedAmount: 80.0,
        originalEstimatedAmount: saladFood.servingSize,
        estimatedUnit: saladFood.servingUnit,
        matchedFood: saladFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      final meal = FoodScanResult(
        id: 'mixed_meal_4_comp',
        foods: [chapati, dal, curry, salad],
        overallConfidence: 0.95,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.localModel,
      );

      expect(meal.foods.length, equals(4));
      expect(meal.hasIncompleteNutrition, isFalse);
      expect(meal.canBeLogged, isTrue);

      final expectedCal = chapati.scaledCalories + dal.scaledCalories + curry.scaledCalories + salad.scaledCalories;
      final expectedProt = chapati.scaledProtein + dal.scaledProtein + curry.scaledProtein + salad.scaledProtein;
      final expectedCarb = chapati.scaledCarbs + dal.scaledCarbs + curry.scaledCarbs + salad.scaledCarbs;
      final expectedFat = chapati.scaledFats + dal.scaledFats + curry.scaledFats + salad.scaledFats;

      expect(meal.totalCalories, closeTo(expectedCal, 0.01));
      expect(meal.verifiedTotalCalories, isNotNull);
      expect(meal.verifiedTotalCalories!, closeTo(expectedCal, 0.01));

      expect(meal.totalProtein, closeTo(expectedProt, 0.01));
      expect(meal.verifiedTotalProtein!, closeTo(expectedProt, 0.01));

      expect(meal.totalCarbs, closeTo(expectedCarb, 0.01));
      expect(meal.verifiedTotalCarbs!, closeTo(expectedCarb, 0.01));

      expect(meal.totalFats, closeTo(expectedFat, 0.01));
      expect(meal.verifiedTotalFats!, closeTo(expectedFat, 0.01));

      // Removing salad updates item count and totals correctly
      final updatedMeal = meal.copyWith(foods: [chapati, dal, curry]);
      expect(updatedMeal.foods.length, equals(3));
      expect(updatedMeal.totalCalories, closeTo(expectedCal - salad.scaledCalories, 0.01));
    });

    test('Incomplete component nutrition is reported honestly and blocks diary logging', () {
      final chapatiFood = catalog.firstWhere((f) => f.id == 'predefined_chapati');

      final chapati = DetectedFoodCandidate(
        id: 'comp_1',
        detectedName: chapatiFood.name,
        confidence: 0.92,
        estimatedAmount: 100.0,
        originalEstimatedAmount: chapatiFood.servingSize,
        estimatedUnit: chapatiFood.servingUnit,
        matchedFood: chapatiFood,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.localModel,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      const unresolvedFood = DetectedFoodCandidate(
        id: 'comp_unresolved',
        detectedName: 'Regional Special Stew',
        confidence: 0.85,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 150.0,
        estimatedUnit: 'g',
        matchedFood: null,
        matchConfidence: 0.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      final meal = FoodScanResult(
        id: 'mixed_meal_with_unresolved',
        foods: [chapati, unresolvedFood],
        overallConfidence: 0.90,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.localModel,
      );

      expect(meal.hasIncompleteNutrition, isTrue);
      expect(meal.canBeLogged, isFalse);
      expect(meal.unresolvedFoods.length, equals(1));
      expect(meal.verifiedTotalCalories, isNull); // Never converts missing to zero!
      expect(meal.verifiedTotalProtein, isNull);
      expect(meal.verifiedTotalCarbs, isNull);
      expect(meal.verifiedTotalFats, isNull);
    });
  });

  group('Phase 35.13.2 Defect C: Complex-Meal Rejection & Routing Repair', () {
    late FoodRecognitionCascade cascade;

    setUp(() {
      cascade = const FoodRecognitionCascade();
    });

    test('Complex meal with tight negative margin routes to tier2_no_reliable_match, NOT non-food', () {
      // Simulates a mixed thali: top similarity is diffused (0.0650) and table rim gives negSim 0.0250 -> negMargin 0.0400 < 0.0621
      const rawResult = OpenVocabularyRecognitionResult(
        accepted: false,
        abstained: false,
        isNonFoodRejected: false,
        isUnavailable: false,
        topCandidates: [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_curry',
            canonicalName: 'Vegetable Curry',
            category: 'Indian Curries',
            similarity: 0.0650,
            rank: 1,
          ),
        ],
        modelId: 'siglip_b16_int8',
        topSimilarity: 0.0650,
        negativeSimilarity: 0.0250,
        negativeMargin: 0.0400,
        topNegativePrompt: 'Dinner Plate Rim',
        decisionReason: 'open_vocab_eval',
      );

      final evaluation = cascade.evaluateTier2Result(rawResult, foodCatalog: catalog);

      expect(evaluation.isNonFoodRejected, isFalse,
          reason: 'Food similarity exceeds negative similarity; must not be labeled non-food.');
      expect(evaluation.route, equals('tier2_no_reliable_match'));
      expect(evaluation.reason, equals('uncertain_complex_meal_tight_margin'));
    });

    test('Genuinely non-food image is reliably rejected as tier2_abstained_non_food', () {
      const rawResult = OpenVocabularyRecognitionResult(
        accepted: false,
        abstained: true,
        isNonFoodRejected: true,
        isUnavailable: false,
        topCandidates: [],
        modelId: 'siglip_b16_int8',
        topSimilarity: 0.0300,
        negativeSimilarity: 0.0450, // Negative prompt beats food similarity!
        negativeMargin: -0.0150,
        topNegativePrompt: 'Laptop Keyboard',
        decisionReason: 'rejected_non_food_margin',
      );

      final evaluation = cascade.evaluateTier2Result(rawResult, foodCatalog: catalog);

      expect(evaluation.isNonFoodRejected, isTrue);
      expect(evaluation.route, equals('tier2_abstained_non_food'));
    });

    test('End-to-end Router: Complex meal routes to Tier2NoReliableMatch and Controller sets uncertain state', () async {
      final tier1Mock = _MockTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'none',
          foodName: 'Unknown',
          confidence: 0.10,
          inferenceDurationMs: 15,
        ),
      );
      final tier2Mock = _MockTier2Recognizer(
        const OpenVocabularyRecognitionResult(
          accepted: false,
          abstained: false,
          isNonFoodRejected: false,
          isUnavailable: false,
          topCandidates: [
            OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_curry',
              canonicalName: 'Vegetable Curry',
              category: 'Indian Curries',
              similarity: 0.0680,
              rank: 1,
            ),
          ],
          modelId: 'siglip_b16_int8',
          topSimilarity: 0.0680,
          negativeSimilarity: 0.0220,
          negativeMargin: 0.0460,
          topNegativePrompt: 'Plate Rim',
          decisionReason: 'open_vocab_eval',
        ),
      );

      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1Mock,
        openVocabularyRecognizer: tier2Mock,
        remoteDataSource: spyRemote,
        config: kDefaultFoodScanRouterConfig,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_complex_1',
        imagePath: 'dummy_complex_plate.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2NoReliableMatch>());
      final noMatch = decision as Tier2NoReliableMatch;
      expect(noMatch.reason, equals('uncertain_complex_meal_tight_margin'));

      final repo = FoodScanRepositoryImpl(
        remoteDataSource: spyRemote,
        router: router,
      );

      final controller = FoodScanController(
        repository: repo,
        imagePickerService: _MockImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'dummy_complex_plate.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final suggestionsState = controller.state as FoodScanSuggestions;
      expect(suggestionsState.isNonFoodAbstained, isFalse,
          reason: 'Complex meal must not show "No food detected"');
      expect(suggestionsState.isUncertainFoodMatch, isTrue,
          reason: 'Must present actionable "We couldn\'t identify this meal confidently" card');
    });
  });
}
