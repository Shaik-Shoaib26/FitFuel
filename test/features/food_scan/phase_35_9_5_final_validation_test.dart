import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/fake_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';

class _MockRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;
  List<RawDetectedFood> mockRawFoods = [];
  Exception? exceptionToThrow;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockRawFoods;
  }

  @override
  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  }) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFoodVisionClassifier fakeClassifier;
  late _MockRemoteDataSource mockRemote;
  late List<FoodEntity> catalog;
  final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

  setUp(() {
    fakeClassifier = FakeFoodVisionClassifier();
    mockRemote = _MockRemoteDataSource();
    catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  });

  FoodScanRecognitionRouter createRouter({
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
  }) {
    return FoodScanRecognitionRouter(
      localClassifier: fakeClassifier,
      remoteDataSource: mockRemote,
      config: config,
    );
  }

  group('Phase 35.9.5 — Final Local Model V5 Validation & Production Safety Audit Tests', () {
    test('1. V5 model metadata and canonical evaluation report exist with fitfuel_food_v5', () {
      expect(kDefaultFoodScanRouterConfig.modelVersion, equals('fitfuel_food_v5'));
      expect(kDefaultFoodScanRouterConfig.labelVersion, equals('fitfuel_labels_v5'));

      final evalFile = File('ml/reports/model_evaluation_v5.json');
      expect(evalFile.existsSync(), isTrue, reason: 'model_evaluation_v5.json must exist');

      final evalJson = jsonDecode(evalFile.readAsStringSync()) as Map<String, dynamic>;
      expect(evalJson['model_version'], equals('fitfuel_food_v5'));
      expect(evalJson['architecture'], equals('MobileNetV3Large'));
    });

    test('2. 50 classes labels ordering verified in assets and labels.txt', () {
      final assetLabels = File('assets/ml/fitfuel_food_labels.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      final mlLabels = File('ml/labels.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();

      expect(assetLabels.length, equals(50));
      expect(mlLabels.length, equals(50));
      expect(assetLabels, equals(mlLabels));
    });

    test('3. kFitFuelV5ProductionEnabledFoodIds contains exactly 8 validated classes', () {
      expect(kFitFuelV5ProductionEnabledFoodIds.length, equals(8));
      expect(kDefaultFoodScanRouterConfig.productionEnabledFoodIds, equals(kFitFuelV5ProductionEnabledFoodIds));

      final expected = {
        'predefined_medu_vada',
        'predefined_samosa',
        'predefined_whole_wheat_bread',
        'predefined_scrambled_eggs',
        'predefined_watermelon',
        'predefined_dosa',
        'predefined_low_fat_milk',
        'predefined_capsicum',
      };
      expect(kFitFuelV5ProductionEnabledFoodIds, equals(expected));

      for (final id in kFitFuelV5ProductionEnabledFoodIds) {
        expect(catalog.any((c) => c.id == id), isTrue);
      }
    });

    test('4. Threshold routing: confidence >= 0.85 accepted, < 0.85 routed to Gemini', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_whole_wheat_bread',
        foodName: 'Whole Wheat Bread',
        confidence: 0.90,
      );

      var result = await router.routeScan(
        imagePath: '/path/to/bread.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_th_high',
      );
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      expect(mockRemote.analyzeCallCount, equals(0));

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_whole_wheat_bread',
        foodName: 'Whole Wheat Bread',
        confidence: 0.80, // Below 0.85
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Whole Wheat Bread', confidence: 0.90, estimatedGrams: 60)
      ];

      result = await router.routeScan(
        imagePath: '/path/to/bread.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_th_low',
      );
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(mockRemote.analyzeCallCount, equals(1));
    });

    test('5. Margin routing: margin < 0.15 routes to Gemini cloud fallback', () async {
      final router = createRouter();

      fakeClassifier.setAmbiguousMatch(
        foodId1: 'predefined_whole_wheat_bread',
        foodName1: 'Whole Wheat Bread',
        confidence1: 0.88,
        foodId2: 'predefined_chapati',
        foodName2: 'Chapati',
        confidence2: 0.78, // margin 0.10 < 0.15
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Whole Wheat Bread', confidence: 0.90, estimatedGrams: 60)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/bread.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_margin',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('6. Cloud-only classes: unverified class routes to Gemini regardless of high local confidence', () async {
      final router = createRouter();

      // Apple is currently cloud-only
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_apple',
        foodName: 'Apple',
        confidence: 0.95,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Apple', confidence: 0.95, estimatedGrams: 150)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/apple.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_cloud_only',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('7. Poha protection: Poha remains cloud-only and Biryani cannot be accepted as Poha', () async {
      final router = createRouter();

      expect(kFitFuelV5ProductionEnabledFoodIds.contains('predefined_poha'), isFalse);

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_poha',
        foodName: 'Poha',
        confidence: 0.94,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Chicken Biryani', confidence: 0.95, estimatedGrams: 300)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/biryani.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_biryani_poha_prot',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('8. Tandoori Chicken protection: Tandoori Chicken remains cloud-only and Paneer cannot be accepted locally as chicken', () async {
      final router = createRouter();

      expect(kFitFuelV5ProductionEnabledFoodIds.contains('predefined_tandoori_chicken'), isFalse);

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_tandoori_chicken',
        foodName: 'Tandoori Chicken',
        confidence: 0.93,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Paneer Butter Masala', confidence: 0.95, estimatedGrams: 250)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/paneer.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_tandoori_paneer_prot',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('9. Vegetarian/meat safety routing: V5 allow-list contains zero ambiguous meat classes', () {
      const allowed = kFitFuelV5ProductionEnabledFoodIds;
      // Scrambled eggs is clearly identifiable ovo-vegetarian breakfast
      // Medu Vada, Samosa, Whole Wheat Bread, Watermelon, Dosa, Low Fat Milk, Capsicum are vegetarian
      expect(allowed.contains('predefined_tandoori_chicken'), isFalse);
      expect(allowed.contains('predefined_grilled_chicken_breast'), isFalse);
    });

    test('10. Unsupported food fallback: food outside 50 classes routes to Gemini', () async {
      final router = createRouter();

      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'predefined_pasta',
        foodName: 'Pasta',
        confidence: 0.95,
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_pasta', label: 'Pasta', confidence: 0.95),
        ],
        inferenceDurationMs: 12,
        isModelAvailable: true,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Pasta', confidence: 0.95, estimatedGrams: 200)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/pasta.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_pasta',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('11. Mixed-meal fallback: multi-dish meal routes to Gemini', () async {
      final router = createRouter();

      fakeClassifier.setAmbiguousMatch(
        foodId1: 'predefined_dosa',
        foodName1: 'Plain Dosa',
        confidence1: 0.50,
        foodId2: 'predefined_sambar',
        foodName2: 'Sambar',
        confidence2: 0.45,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Plain Dosa', confidence: 0.90, estimatedGrams: 100),
        const RawDetectedFood(name: 'Sambar', confidence: 0.88, estimatedGrams: 150),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/dosa_sambar.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_mixed',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.foods.length, equals(2));
    });

    test('12. Non-food fallback: non-food image does not log food automatically', () async {
      final router = createRouter();

      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'predefined_potato',
        foodName: 'Potato',
        confidence: 0.40, // Low confidence on non-food
        topCandidates: [],
        inferenceDurationMs: 12,
        isModelAvailable: true,
      );
      mockRemote.mockRawFoods = [];

      final result = await router.routeScan(
        imagePath: '/path/to/shoes.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_non_food',
      );
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.foods, isEmpty);
    });

    test('13. Offline local success: high-confidence allowed class succeeds offline with zero cloud calls', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_samosa',
        foodName: 'Samosa',
        confidence: 0.94,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/samosa.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_offline',
        isOffline: true,
      );
      expect(result.isRecognizedOnDevice, isTrue);
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      expect(mockRemote.analyzeCallCount, equals(0));
    });

    test('14. Model failure -> Gemini fallback: classifier failure safely routes to Gemini', () async {
      fakeClassifier.setModelUnavailable();
      final router = createRouter();

      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Samosa', confidence: 0.95, estimatedGrams: 80)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/samosa.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_model_fail',
      );
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('15. Database-first nutrition: local recognition pulls macros from catalog with zero hallucination', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_samosa',
        foodName: 'Samosa',
        confidence: 0.94,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/samosa.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_nutrition',
      );

      final food = result.foods.first;
      final dbFood = catalog.firstWhere((c) => c.id == 'predefined_samosa');
      expect(food.matchedFood?.calories, equals(dbFood.calories));
      expect(food.matchedFood?.protein, equals(dbFood.protein));
      expect(food.matchedFood?.carbs, equals(dbFood.carbs));
      expect(food.matchedFood?.fat, equals(dbFood.fat));
    });

    test('16. No local daily limit: 100 on-device scans succeed without cap limit', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_samosa',
        foodName: 'Samosa',
        confidence: 0.95,
      );

      for (int i = 0; i < 100; i++) {
        final result = await router.routeScan(
          imagePath: '/path/to/samosa.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'stress_$i',
        );
        expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      }
      expect(mockRemote.analyzeCallCount, equals(0));
    });
  });
}
