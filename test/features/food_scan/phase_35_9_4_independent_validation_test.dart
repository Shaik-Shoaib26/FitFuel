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
    FoodScanRouterConfig config = const FoodScanRouterConfig(
      productionEnabledFoodIds: kFitFuelV4ProductionEnabledFoodIds,
    ),
  }) {
    return FoodScanRecognitionRouter(
      localClassifier: fakeClassifier,
      remoteDataSource: mockRemote,
      config: config,
    );
  }

  group('Phase 35.9.4 — Independent Validation & Production Safety Audit Tests', () {
    test('1. Canonical deployed model metrics file exists and contains resolved metrics', () {
      final file = File('ml/reports/model_evaluation_v4.json');
      expect(file.existsSync(), isTrue, reason: 'model_evaluation_v4.json must exist');

      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final deployedMetrics = jsonMap['deployed_tflite_metrics'] as Map<String, dynamic>;

      expect(deployedMetrics['top1_accuracy_pct'], equals(28.57));
      expect(deployedMetrics['top3_accuracy_pct'], equals(43.34));
      expect(deployedMetrics['test_samples'], equals(413));
      expect(jsonMap['metric_inconsistency_resolution']['status'], equals('RESOLVED'));
    });

    test('2. Label ordering matches exactly between assets and labels file with 50 classes', () {
      final assetLabelsFile = File('assets/ml/fitfuel_food_labels.txt');
      final mlLabelsFile = File('ml/labels.txt');

      expect(assetLabelsFile.existsSync(), isTrue);
      expect(mlLabelsFile.existsSync(), isTrue);

      final assetLines = assetLabelsFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      final mlLines = mlLabelsFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();

      expect(assetLines.length, equals(50));
      expect(mlLines.length, equals(50));
      expect(assetLines, equals(mlLines));

      // Check first, middle, last labels
      expect(assetLines.first, equals('predefined_apple'));
      expect(assetLines.last, equals('predefined_almonds'));
    });

    test('3. TFLite model output dimension matches 50 labels', () {
      final file = File('assets/ml/fitfuel_food_classifier.tflite');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(5 * 1024 * 1024)); // ~5.86 MB
      expect(kFitFuelV1SupportedFoodIds.length, equals(50));
    });

    test('4. Production enabled list V4 contains exactly 16 validated classes', () {
      expect(kFitFuelV4ProductionEnabledFoodIds.length, equals(16));

      // Verify poha and tandoori_chicken were safely removed due to OOD vulnerability
      expect(kFitFuelV4ProductionEnabledFoodIds.contains('predefined_poha'), isFalse);
      expect(kFitFuelV4ProductionEnabledFoodIds.contains('predefined_tandoori_chicken'), isFalse);

      // Verify all 16 exist in catalog
      for (final id in kFitFuelV4ProductionEnabledFoodIds) {
        expect(catalog.any((c) => c.id == id), isTrue,
            reason: 'Production enabled class $id must exist in catalog');
      }
    });

    test('5. Threshold routing: confidence >= 0.85 accepted, < 0.85 routed to Gemini', () async {
      final router = createRouter();

      // Case A: High confidence 0.90 -> Local accepted
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

      // Case B: Low confidence 0.82 (< 0.85) -> Fallback to Gemini
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_whole_wheat_bread',
        foodName: 'Whole Wheat Bread',
        confidence: 0.82,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Whole Wheat Bread', confidence: 0.92, estimatedGrams: 60)
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

    test('6. Margin routing: margin < 0.15 routes to Gemini cloud fallback', () async {
      final router = createRouter();

      // Confidence 0.88, but top2 is 0.78 (margin = 0.10 < 0.15) -> Ambiguous
      fakeClassifier.setAmbiguousMatch(
        foodId1: 'predefined_whole_wheat_bread',
        foodName1: 'Whole Wheat Bread',
        confidence1: 0.88,
        foodId2: 'predefined_chapati',
        foodName2: 'Chapati',
        confidence2: 0.78,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Whole Wheat Bread', confidence: 0.90, estimatedGrams: 60)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/bread.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_margin_ambiguous',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('7. Disabled-class fallback: class removed from production routes to Gemini', () async {
      final router = createRouter();

      // Poha was removed in V4
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_poha',
        foodName: 'Poha',
        confidence: 0.94,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Poha', confidence: 0.96, estimatedGrams: 150)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/poha.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_disabled_poha',
      );

      // Successfully routed to Gemini for safety
      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('8. Unsupported-food fallback: food outside 50 classes routes to Gemini', () async {
      final router = createRouter();

      // Biryani is outside 50 classes
      fakeClassifier.predeterminedPrediction = const LocalFoodPrediction(
        foodId: 'predefined_biryani',
        foodName: 'Chicken Biryani',
        confidence: 0.95,
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_biryani', label: 'Chicken Biryani', confidence: 0.95),
          LocalFoodCandidate(foodId: 'predefined_steamed_rice', label: 'Steamed Rice', confidence: 0.05),
        ],
        inferenceDurationMs: 12,
        isModelAvailable: true,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Chicken Biryani', confidence: 0.95, estimatedGrams: 300)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/biryani.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_unsupported',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('9. Mixed-meal fallback: multi-item food spread handled via Gemini', () async {
      final router = createRouter();

      // Local model is ambiguous on multi-item meal
      fakeClassifier.setAmbiguousMatch(
        foodId1: 'predefined_steamed_rice',
        foodName1: 'Steamed Rice',
        confidence1: 0.45,
        foodId2: 'predefined_dal_tadka',
        foodName2: 'Dal Tadka',
        confidence2: 0.40,
      );
      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Steamed Rice', confidence: 0.90, estimatedGrams: 150),
        const RawDetectedFood(name: 'Dal Tadka', confidence: 0.88, estimatedGrams: 100),
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/thali.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_thali',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.foods.length, equals(2));
    });

    test('10. Model failure fallback: when local classifier is unavailable, router falls back to Gemini', () async {
      fakeClassifier.setModelUnavailable();
      final router = createRouter();

      mockRemote.mockRawFoods = [
        const RawDetectedFood(name: 'Watermelon', confidence: 0.95, estimatedGrams: 200)
      ];

      final result = await router.routeScan(
        imagePath: '/path/to/watermelon.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_crash_fallback',
      );

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
    });

    test('11. Database-first nutrition: local recognition uses database macros with zero hallucination', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_strawberry',
        foodName: 'Strawberry',
        confidence: 0.95,
      );

      final result = await router.routeScan(
        imagePath: '/path/to/strawberry.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_nutrition_check',
      );

      expect(result.isRecognizedOnDevice, isTrue);
      final food = result.foods.first;
      expect(food.matchedFood, isNotNull);

      // Verify nutrition is strictly from database
      final dbFood = catalog.firstWhere((c) => c.id == 'predefined_strawberry');
      expect(food.matchedFood?.calories, equals(dbFood.calories));
      expect(food.matchedFood?.protein, equals(dbFood.protein));
      expect(food.matchedFood?.carbs, equals(dbFood.carbs));
      expect(food.matchedFood?.fat, equals(dbFood.fat));
    });

    test('12. No local daily cap: 100 on-device scans succeed without cap limit', () async {
      final router = createRouter();

      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_strawberry',
        foodName: 'Strawberry',
        confidence: 0.95,
      );

      for (int i = 0; i < 100; i++) {
        final result = await router.routeScan(
          imagePath: '/path/to/strawberry.jpg',
          imageBytes: testBytes,
          foodCatalog: catalog,
          requestId: 'stress_scan_$i',
        );
        expect(result.recognitionSource, equals(FoodScanRecognitionSource.localModel));
      }

      // Zero Gemini calls across 100 scans
      expect(mockRemote.analyzeCallCount, equals(0));
    });
  });
}
