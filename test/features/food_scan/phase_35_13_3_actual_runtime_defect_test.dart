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
  late FoodRecognitionCascade cascade;

  setUp(() {
    catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    resolver = UniversalNutritionResolver();
    cascade = const FoodRecognitionCascade();
  });

  group('Phase 35.13.3 Defect A: Missing Macros & Nutrition Resolution', () {
    test('1. Nihari resolves with complete nutrition (calories, protein, carbs, fat) and preserves displayName', () {
      const nihariCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_nihari',
        canonicalName: 'Nihari',
        category: 'Main Course',
        similarity: 0.1411,
        rank: 1,
      );

      final res = resolver.resolveCandidate(nihariCandidate, foodCatalog: catalog);

      expect(res.hasNutrition, isTrue);
      expect(res.tier, equals(NutritionProfileTier.verifiedExact));
      expect(res.matchedCatalogFood, isNotNull);
      expect(res.matchedCatalogFood!.name, equals('Nihari'));
      expect(res.matchedCatalogFood!.calories, equals(240.0));
      expect(res.matchedCatalogFood!.protein, equals(19.0));
      expect(res.matchedCatalogFood!.carbohydrates, equals(4.0));
      expect(res.matchedCatalogFood!.fats, equals(16.5));
    });

    test('2. Paneer Butter Masala resolves with complete verified paneer nutrition', () {
      const pbmCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_paneer_butter_masala',
        canonicalName: 'Paneer Butter Masala',
        category: 'Main Course',
        similarity: 0.1250,
        rank: 1,
      );

      final res = resolver.resolveCandidate(pbmCandidate, foodCatalog: catalog);

      expect(res.hasNutrition, isTrue);
      expect(res.tier, equals(NutritionProfileTier.verifiedExact));
      expect(res.matchedCatalogFood, isNotNull);
      expect(res.matchedCatalogFood!.name, equals('Paneer Butter Masala'));
      expect(res.matchedCatalogFood!.calories, equals(165.0));
      expect(res.matchedCatalogFood!.protein, equals(8.5));
      expect(res.matchedCatalogFood!.carbohydrates, equals(4.8));
      expect(res.matchedCatalogFood!.fats, equals(13.0));
    });

    test('3. Dal Makhani resolves with complete verified dal nutrition', () {
      const dalMakhani = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_dal_makhani',
        canonicalName: 'Dal Makhani',
        category: 'Main Course',
        similarity: 0.1320,
        rank: 1,
      );

      final res = resolver.resolveCandidate(dalMakhani, foodCatalog: catalog);

      expect(res.hasNutrition, isTrue);
      expect(res.tier, equals(NutritionProfileTier.verifiedExact));
      expect(res.matchedCatalogFood, isNotNull);
      expect(res.matchedCatalogFood!.name, equals('Dal Makhani'));
      expect(res.matchedCatalogFood!.calories, equals(118.0));
      expect(res.matchedCatalogFood!.protein, equals(6.5));
      expect(res.matchedCatalogFood!.carbohydrates, equals(17.0));
      expect(res.matchedCatalogFood!.fats, equals(2.8));
    });

    test('4. Butter Naan resolves with complete flatbread nutrition', () {
      const naan = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_butter_naan',
        canonicalName: 'Butter Naan',
        category: 'Breads',
        similarity: 0.1180,
        rank: 1,
      );

      final res = resolver.resolveCandidate(naan, foodCatalog: catalog);

      expect(res.hasNutrition, isTrue);
      expect(res.matchedCatalogFood, isNotNull);
      expect(res.matchedCatalogFood!.name, equals('Butter Naan'));
      expect(res.matchedCatalogFood!.calories, greaterThan(0));
      expect(res.matchedCatalogFood!.protein, greaterThan(0));
      expect(res.matchedCatalogFood!.carbohydrates, greaterThan(0));
      expect(res.matchedCatalogFood!.fats, greaterThan(0));
    });

    test('5. Truly unsupported food (Kimbap) remains honest unavailable without fabricated values', () {
      const kimbap = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_kimbap',
        canonicalName: 'Kimbap',
        category: 'Asian',
        similarity: 0.0950,
        rank: 1,
      );

      final res = resolver.resolveCandidate(kimbap, foodCatalog: catalog);

      expect(res.hasNutrition, isFalse);
      expect(res.tier, equals(NutritionProfileTier.unavailable));
      expect(res.matchedCatalogFood, isNull);
    });

    test('6. Portion scaling accurately scales all 4 macronutrients without loss', () {
      final food = catalog.firstWhere((f) => f.id == 'predefined_chapati');
      final candidate = DetectedFoodCandidate(
        id: 'test_c1',
        detectedName: 'Chapati',
        confidence: 0.95,
        estimatedAmount: 80.0, // 2 chapatis (serving basis is 40g = 104 kcal)
        originalEstimatedAmount: 40.0,
        estimatedUnit: 'g',
        matchedFood: food,
        matchConfidence: 1.0,
      );

      expect(candidate.hasNutrition, isTrue);
      expect(candidate.scaledCalories, equals(208.0));
      expect(candidate.scaledProtein, closeTo(6.2, 0.05));
      expect(candidate.scaledCarbs, closeTo(40.0, 0.05));
      expect(candidate.scaledFats, closeTo(2.4, 0.05));
    });
  });

  group('Phase 35.13.3 Defect B: Mixed Meals (Chapati, Dal, Curry, Salad)', () {
    test('7. Mixed meal workflow: starts with 1 recognized food and allows adding components with accurate totals', () {
      final chapati = catalog.firstWhere((f) => f.id == 'predefined_chapati');
      final dal = catalog.firstWhere((f) => f.id == 'predefined_dal_tadka');
      final curry = catalog.firstWhere((f) => f.id == 'predefined_mixed_veg_curry');
      final salad = catalog.firstWhere((f) => f.id == 'predefined_mixed_veg_salad');

      final initialFood = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Chapati',
        confidence: 0.88,
        estimatedAmount: 40.0,
        originalEstimatedAmount: 40.0,
        estimatedUnit: 'g',
        matchedFood: chapati,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
      );

      var scanResult = FoodScanResult(
        id: 'scan_mixed_1',
        imagePath: '/test/mixed.jpg',
        foods: [initialFood],
        overallConfidence: 0.88,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
      );

      expect(scanResult.foods.length, equals(1));
      expect(scanResult.totalCalories, equals(104.0));

      // User adds Dal Tadka
      final dalCandidate = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Dal Tadka',
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 150.0,
        estimatedUnit: 'g',
        matchedFood: dal,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
      );
      scanResult = scanResult.copyWith(foods: [...scanResult.foods, dalCandidate]);

      // User adds Mixed Veg Curry
      final curryCandidate = DetectedFoodCandidate(
        id: 'c3',
        detectedName: 'Mixed Vegetable Curry',
        confidence: 1.0,
        estimatedAmount: 150.0,
        originalEstimatedAmount: 150.0,
        estimatedUnit: 'g',
        matchedFood: curry,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
      );
      scanResult = scanResult.copyWith(foods: [...scanResult.foods, curryCandidate]);

      // User adds Salad
      final saladCandidate = DetectedFoodCandidate(
        id: 'c4',
        detectedName: 'Mixed Veg Salad',
        confidence: 1.0,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 150.0, // adjusted portion
        estimatedUnit: 'g',
        matchedFood: salad,
        matchConfidence: 1.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        isUserConfirmed: true,
      );
      scanResult = scanResult.copyWith(foods: [...scanResult.foods, saladCandidate]);

      // Verify full 4-component mixed meal
      expect(scanResult.foods.length, equals(4));
      expect(scanResult.canBeLogged, isTrue);
      expect(scanResult.hasIncompleteNutrition, isFalse);

      // Verify combined totals
      // Chapati (40g): 104 kcal, 3.1 P, 20.0 C, 1.2 F
      // Dal (150g): 177 kcal, 9.75 P, 25.5 C, 4.2 F
      // Curry (150g): 172.5 kcal, 4.5 P, 22.5 C, 7.5 F
      // Salad (100g): 30 kcal, 1.0 P, 5.33 C, 0.8 F
      // Total: 483.5 kcal, 18.35g P, 73.33g C, 13.7g F
      expect(scanResult.totalCalories, closeTo(483.5, 0.5));
      expect(scanResult.totalProtein, closeTo(18.35, 0.5));
      expect(scanResult.totalCarbs, closeTo(73.33, 0.5));
      expect(scanResult.totalFats, closeTo(13.7, 0.5));

      // User removes salad (remaining: 483.5 - 30 = 453.5 kcal)
      scanResult = scanResult.copyWith(foods: scanResult.foods.take(3).toList());
      expect(scanResult.foods.length, equals(3));
      expect(scanResult.totalCalories, closeTo(453.5, 0.5));
    });
  });

  group('Phase 35.13.3 Defect C: Complex & Heavy Meal Rejection Repair', () {
    test('8. Heavy meal where Tier 1 has confident food detection is NEVER rejected as non-food', () {
      const rawResult = OpenVocabularyRecognitionResult(
        accepted: false,
        abstained: true,
        isNonFoodRejected: true,
        isUnavailable: false,
        topCandidates: [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_sambar',
            canonicalName: 'Sambar',
            category: 'Main Course',
            similarity: 0.0518,
            rank: 1,
          ),
        ],
        modelId: 'siglip_b16_int8',
        topSimilarity: 0.0518,
        negativeSimilarity: 0.0111,
        negativeMargin: 0.0407,
        decisionReason: 'rejected_non_food_margin',
      );

      // Tier 1 MobileNet has 54.6% Sambar prediction (Scan 2 scenario)
      const tier1Sambar = LocalFoodPrediction(
        foodId: 'predefined_sambar',
        foodName: 'Sambar',
        confidence: 0.546,
        topCandidates: [
          LocalFoodCandidate(
            foodId: 'predefined_sambar',
            foodName: 'Sambar',
            confidence: 0.546,
          ),
        ],
        isModelAvailable: true,
      );

      final evaluation = cascade.evaluateTier2Result(
        rawResult,
        foodCatalog: catalog,
        tier1Prediction: tier1Sambar,
      );

      // Must NOT be rejected as non-food!
      expect(evaluation.isNonFoodRejected, isFalse);
      expect(evaluation.route, equals('tier2_no_reliable_match'));
      expect(evaluation.reason, equals('uncertain_complex_meal_tight_margin'));
    });

    test('9. Controller retains Tier 1 food candidate as suggestion on Tier2NoReliableMatch', () async {
      final mockTier1 = _MockTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_sambar',
          foodName: 'Sambar',
          confidence: 0.546,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_sambar',
              foodName: 'Sambar',
              confidence: 0.546,
            ),
          ],
          isModelAvailable: true,
        ),
      );

      final mockTier2 = _MockTier2Recognizer(
        const OpenVocabularyRecognitionResult(
          accepted: false,
          abstained: true,
          isNonFoodRejected: true,
          isUnavailable: false,
          topCandidates: [],
          modelId: 'siglip_b16_int8',
          topSimilarity: 0.0518,
          negativeSimilarity: 0.0111,
          negativeMargin: 0.0407,
          decisionReason: 'rejected_non_food_margin',
        ),
      );

      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: mockTier1,
        openVocabularyRecognizer: mockTier2,
        remoteDataSource: spyRemote,
        config: kDefaultFoodScanRouterConfig,
      );

      final repository = FoodScanRepositoryImpl(
        remoteDataSource: spyRemote,
        router: router,
      );

      final controller = FoodScanController(
        repository: repository,
        imagePickerService: _MockImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: '/test/sambar.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final suggestionsState = controller.state as FoodScanSuggestions;
      expect(suggestionsState.isNonFoodAbstained, isFalse);
      expect(suggestionsState.suggestions.isNotEmpty, isTrue);
      expect(suggestionsState.suggestions.first.foodId, equals('predefined_sambar'));
      expect(suggestionsState.suggestions.first.confidence, equals(0.546));
    });

    test('10. Genuine non-food image (Desk/Keyboard) with weak Tier 1 is reliably rejected as non-food', () {
      const nonFoodResult = OpenVocabularyRecognitionResult(
        accepted: false,
        abstained: true,
        isNonFoodRejected: true,
        isUnavailable: false,
        topCandidates: [],
        modelId: 'siglip_b16_int8',
        topSimilarity: 0.0350,
        negativeSimilarity: 0.0980,
        negativeMargin: -0.0630,
        decisionReason: 'rejected_non_food_margin',
      );

      // Weak Tier 1 (no confident food prediction)
      const weakTier1 = LocalFoodPrediction(
        foodId: 'unknown',
        foodName: 'Unknown',
        confidence: 0.12,
        topCandidates: [],
        isModelAvailable: true,
      );

      final evaluation = cascade.evaluateTier2Result(
        nonFoodResult,
        foodCatalog: catalog,
        tier1Prediction: weakTier1,
      );

      expect(evaluation.isNonFoodRejected, isTrue);
      expect(evaluation.route, equals('tier2_abstained_non_food'));
    });
  });
}
