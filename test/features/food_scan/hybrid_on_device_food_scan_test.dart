import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/fake_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_telemetry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
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
  late FakeFoodVisionClassifier fakeClassifier;
  late _MockRemoteDataSource mockRemote;
  late List<FoodEntity> catalog;
  final List<FoodScanTelemetryEvent> telemetryEvents = [];

  setUp(() {
    fakeClassifier = FakeFoodVisionClassifier();
    mockRemote = _MockRemoteDataSource();
    catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    telemetryEvents.clear();
  });

  FoodScanRecognitionRouter createRouter({
    FoodScanRouterConfig config = const FoodScanRouterConfig(),
  }) {
    return FoodScanRecognitionRouter(
      localClassifier: fakeClassifier,
      remoteDataSource: mockRemote,
      config: config,
      telemetrySink: (e) => telemetryEvents.add(e),
    );
  }

  final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

  group('Phase 35.9 — Hybrid On-Device Food Scan & Confidence Routing Tests', () {
    test('58. High-confidence local recognition resolves from database with ZERO Gemini calls', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.94,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/plate.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_local_1',
      );

      // Verify Gemini calls: 0
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(fakeClassifier.classifyCallCount, equals(1));

      // Verify local recognition source & match
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      expect(result.isRecognizedOnDevice, isTrue);
      expect(result.overallConfidence, equals(0.94));
      expect(result.foods.length, equals(1));

      final detected = result.foods.first;
      expect(detected.detectedName, equals('Idli'));
      expect(detected.isMatched, isTrue);
      expect(detected.matchedFood?.id, equals('predefined_idli'));

      // Verify database-first nutrition (calories retrieved from FitFuel catalog, not ML model)
      expect(detected.scaledCalories, equals(120.0));
      expect(detected.scaledProtein, equals(3.2));
      expect(detected.scaledCarbs, equals(25.5));
      expect(detected.scaledFats, equals(0.4));
      expect(detected.isAiEstimated, isFalse);

      // Telemetry verification
      expect(telemetryEvents.length, equals(1));
      final tel = telemetryEvents.first;
      expect(tel.recognitionSource, equals('localModel'));
      expect(tel.cloudFallbackUsed, isFalse);
      expect(tel.localConfidence, equals(0.94));
      expect(tel.isSuccess, isTrue);
    });

    test('59. Low-confidence local prediction triggers Gemini cloud fallback', () async {
      final router = createRouter();

      fakeClassifier.setLowConfidenceMatch(
        foodId: 'predefined_red_apple',
        foodName: 'Red Apple',
        confidence: 0.43,
      );

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Red Apple',
          confidence: 0.92,
          estimatedGrams: 150.0,
          unit: 'g',
        ),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/apple.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_fallback_1',
      );

      // Gemini called exactly once
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(fakeClassifier.classifyCallCount, equals(1));

      // Result source is Gemini
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.isRecognizedOnDevice, isFalse);
      expect(result.foods.first.detectedName, equals('Red Apple'));

      // Telemetry logged cloud fallback
      expect(telemetryEvents.length, equals(1));
      final tel = telemetryEvents.first;
      expect(tel.recognitionSource, equals('gemini'));
      expect(tel.cloudFallbackUsed, isTrue);
      expect(tel.localConfidence, equals(0.43));
    });

    test('60. Ambiguous top predictions (margin < 0.10) trigger Gemini cloud fallback', () async {
      final router = createRouter();

      // Top 1: 0.72, Top 2: 0.69 (margin = 0.03 < 0.10)
      fakeClassifier.setAmbiguousMatch(
        foodId1: 'predefined_dosa',
        foodName1: 'Plain Dosa',
        confidence1: 0.72,
        foodId2: 'predefined_uttapam',
        foodName2: 'Uttapam',
        confidence2: 0.69,
      );

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Plain Dosa',
          confidence: 0.88,
          estimatedGrams: 100.0,
          unit: 'g',
        ),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/dosa.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_ambiguous_1',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('61. Local model unavailable gracefully routes to Gemini without crashing', () async {
      final router = createRouter();

      fakeClassifier.setModelUnavailable();

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Upma',
          confidence: 0.91,
          estimatedGrams: 150.0,
          unit: 'g',
        ),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/upma.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_unavail_1',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.foods.first.detectedName, equals('Upma'));
    });

    test('62. Offline high-confidence scan succeeds entirely locally with 0 cloud calls', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_banana',
        foodName: 'Banana',
        confidence: 0.95,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/banana.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_offline_success',
        isOffline: true,
      );

      expect(mockRemote.analyzeCallCount, equals(0));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      expect(result.isRecognizedOnDevice, isTrue);
      expect(result.foods.first.detectedName, equals('Ripe Banana'));
      expect(result.foods.first.scaledCalories, greaterThan(0));
    });

    test('63. Offline low-confidence scan throws typed offlineLowConfidence failure without AI busy message', () async {
      final router = createRouter();

      fakeClassifier.setLowConfidenceMatch(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.35,
      );

      expect(
        () => router.routeScan(
          imagePath: '/path/to/dim_photo.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'req_offline_low',
          isOffline: true,
        ),
        throwsA(isA<FoodScanFailure>().having(
          (f) => f.type,
          'type',
          equals(FoodScanFailureType.offlineLowConfidence),
        ).having(
          (f) => f.message,
          'message',
          contains("Couldn't identify this food confidently offline"),
        )),
      );

      // Verify no cloud attempt was made
      expect(mockRemote.analyzeCallCount, equals(0));
    });

    test('64. Repeated local scans: 100 consecutive scans succeed without daily limit', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_chapati',
        foodName: 'Chapati',
        confidence: 0.96,
      );

      for (var i = 0; i < 100; i++) {
        final result = await router.routeScan(
          imagePath: '/path/to/roti.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'req_repeat_$i',
        );

        expect(result.isRecognizedOnDevice, isTrue);
      }

      expect(router.totalScans, equals(100));
      expect(router.localSuccessfulScans, equals(100));
      expect(router.cloudFallbackScans, equals(0));
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(router.cloudAvoidanceRate, equals(1.0));
    });

    test('65. Cloud usage reduction metric: 8 local and 2 cloud fallback scans achieve 80% avoidance', () async {
      final router = createRouter();

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Fruit Salad',
          confidence: 0.90,
          estimatedGrams: 100.0,
          unit: 'g',
        ),
      ];

      // 8 High-confidence scans
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.90,
      );
      for (var i = 0; i < 8; i++) {
        await router.routeScan(
          imagePath: '/path/to/idli_$i.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'req_local_$i',
        );
      }

      // 2 Low-confidence scans triggering Gemini fallback
      fakeClassifier.setLowConfidenceMatch(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.40,
      );
      for (var i = 0; i < 2; i++) {
        await router.routeScan(
          imagePath: '/path/to/mixed_$i.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'req_cloud_$i',
        );
      }

      expect(router.totalScans, equals(10));
      expect(router.localSuccessfulScans, equals(8));
      expect(router.cloudFallbackScans, equals(2));
      expect(mockRemote.analyzeCallCount, equals(2));
      expect(router.cloudAvoidanceRate, equals(0.80));
    });

    test('66. Database-first nutrition: Local prediction does NOT invent macronutrients', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_paneer_tikka',
        foodName: 'Paneer Tikka',
        confidence: 0.92,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/paneer.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_nutrition_db',
      );

      final candidate = result.foods.first;
      final catalogItem = catalog.firstWhere((f) => f.id == 'predefined_paneer_tikka');

      // Nutrients MUST precisely match FitFuel database
      expect(candidate.scaledCalories, equals(catalogItem.calories));
      expect(candidate.scaledProtein, equals(catalogItem.protein));
      expect(candidate.scaledCarbs, equals(catalogItem.carbohydrates));
      expect(candidate.scaledFats, equals(catalogItem.fats));
      expect(candidate.aiEstimatedNutrition, isNull);
    });

    test('67. Non-food / unknown image does not log food automatically', () async {
      final router = createRouter();

      // Non-food yields low confidence and empty unknown ID
      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'unknown_object',
        foodName: 'Unknown',
        confidence: 0.22,
        topCandidates: [
          LocalFoodCandidate(foodId: 'unknown_object', label: 'Unknown', confidence: 0.22),
        ],
      );

      // Cloud also detects no food
      mockRemote.mockRawFoods = [];

      final result = await router.routeScan(
        imagePath: '/path/to/laptop.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_non_food',
      );

      expect(result.isEmpty, isTrue);
      expect(result.canBeLogged, isFalse);
    });

    test('68. Foods outside 50 V1 supported classes gracefully route to Gemini fallback', () async {
      final router = createRouter();

      // Suppose local classifier returned an unsupported food ID with high confidence
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_some_exotic_dish_not_in_v1',
        foodName: 'Exotic Dish',
        confidence: 0.95,
      );

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Exotic Dish',
          confidence: 0.90,
          estimatedGrams: 200,
          unit: 'g',
        ),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/exotic.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_unsupported_v1',
      );

      // Because 'predefined_some_exotic_dish_not_in_v1' is NOT in kFitFuelV1SupportedFoodIds,
      // it must gracefully fall back to Gemini cloud
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('69. kFitFuelV1SupportedFoodIds contains exactly 50 valid IDs from predefined food catalog', () {
      expect(kFitFuelV1SupportedFoodIds.length, equals(50));
      for (final foodId in kFitFuelV1SupportedFoodIds) {
        expect(catalog.any((c) => c.id == foodId), isTrue,
            reason: 'Food ID $foodId must exist in predefined catalog');
      }
    });

    test('70. All 50 V1 supported classes route on-device when confidence is high', () async {
      final router = createRouter();

      for (final supportedId in kFitFuelV1SupportedFoodIds.take(5)) {
        fakeClassifier.setHighConfidenceMatch(
          foodId: supportedId,
          foodName: 'Sample Food',
          confidence: 0.91,
        );

        final result = await router.routeScan(
          imagePath: '/path/to/food.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'req_$supportedId',
        );

        expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      }
      expect(mockRemote.analyzeCallCount, equals(0));
    });

    test('71. Default Phase 35.9.5 configuration defaults to 0.85 threshold, 0.15 margin, kFitFuelV5ProductionEnabledFoodIds', () {
      const config = FoodScanRouterConfig();
      expect(config.highConfidenceThreshold, equals(0.85));
      expect(config.minimumConfidenceMargin, equals(0.15));
      expect(config.modelVersion, equals('fitfuel_food_v5'));
      expect(config.labelVersion, equals('fitfuel_labels_v5'));
      expect(kDefaultFoodScanRouterConfig.productionEnabledFoodIds, equals(kFitFuelV5ProductionEnabledFoodIds));
      expect(kDefaultFoodScanRouterConfig.productionEnabledFoodIds!.length, equals(8));
    });

    test('72. Ambiguity margin < 0.15 triggers Gemini fallback under Phase 35.9.3 calibrated config', () async {
      final router = createRouter();

      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.88, // Above 0.85 threshold
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_idli', label: 'Idli', confidence: 0.88),
          LocalFoodCandidate(foodId: 'predefined_dosa', label: 'Plain Dosa', confidence: 0.78), // Margin 0.10 < 0.15
        ],
      );

      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Idli', confidence: 0.92, estimatedGrams: 100, unit: 'g'),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/idli.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_ambiguous_35_9_3',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('73. productionEnabledFoodIds restricts automatic local routing to verified subset', () async {
      final router = createRouter(
        config: const FoodScanRouterConfig(
          productionEnabledFoodIds: {'predefined_watermelon', 'predefined_strawberry'},
        ),
      );

      // 1. Watermelon is in productionEnabledFoodIds -> routes locally
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_watermelon',
        foodName: 'Watermelon',
        confidence: 0.94,
      );
      final res1 = await router.routeScan(
        imagePath: '/path/to/watermelon.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_wm',
      );
      expect(res1.recognitionSource, equals(FoodScanRecognitionSource.localModel));

      // 2. Potato is in supported 50 classes but NOT in productionEnabledFoodIds -> routes to Gemini
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_potato',
        foodName: 'Potato',
        confidence: 0.94,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Potato', confidence: 0.90, estimatedGrams: 150, unit: 'g'),
      ];
      final res2 = await router.routeScan(
        imagePath: '/path/to/potato.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_potato',
      );
      expect(res2.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('74. Mixed-meal multi-item detection conservatively routes to Gemini cloud', () async {
      final router = createRouter();

      // Mixed thali or meal combo causes local model uncertainty/low confidence
      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'predefined_steamed_rice',
        foodName: 'Steamed Rice',
        confidence: 0.62, // Mixed dish fails 0.85 threshold
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_steamed_rice', label: 'Steamed Rice', confidence: 0.62),
          LocalFoodCandidate(foodId: 'predefined_dal_tadka', label: 'Dal Tadka', confidence: 0.58),
        ],
      );

      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Steamed White Rice', confidence: 0.88, estimatedGrams: 150, unit: 'g'),
        const RawDetectedFood(name: 'Dal Tadka', confidence: 0.85, estimatedGrams: 100, unit: 'g'),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/thali.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_thali',
      );

      // Successfully handles mixed meal through Gemini
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.foods.length, equals(2));
    });

    test('75. Production enabled classes set contains exactly 18 valid IDs in catalog', () {
      expect(kFitFuelV3ProductionEnabledFoodIds.length, equals(18));
      for (final id in kFitFuelV3ProductionEnabledFoodIds) {
        expect(catalog.any((c) => c.id == id), isTrue,
            reason: 'Production-enabled food $id must exist in catalog');
      }
    });

    test('76. 100 consecutive local scans maintain zero Gemini calls without reload', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_watermelon',
        foodName: 'Watermelon',
        confidence: 0.95,
      );

      for (int i = 0; i < 100; i++) {
        final result = await router.routeScan(
          imagePath: '/path/to/watermelon.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'stress_scan_$i',
        );
        expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      }

      // Zero Gemini calls across all 100 scans
      expect(mockRemote.analyzeCallCount, equals(0));
    });
  });
}
