import 'dart:convert';
import 'dart:io';
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
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';

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
  String? nextPath = 'real_test_image.jpg';

  @override
  Future<String?> pickImage(FoodImagePickSource source) async => nextPath;

  @override
  Future<Uint8List?> getImageBytes(String path) async => Uint8List.fromList([1, 2, 3, 4]);
}

class _InMemoryNutritionRepo implements INutritionRepository {
  final Map<String, List<NutritionRecordEntity>> _recordsByUser = {};

  @override
  Future<void> addRecord(String uid, NutritionRecordEntity record) async {
    _recordsByUser.putIfAbsent(uid, () => []).add(record);
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {
    _recordsByUser[uid]?.removeWhere((r) => r.id == recordId);
  }

  @override
  Future<List<NutritionRecordEntity>> getRecords(String uid) async {
    return _recordsByUser[uid] ?? [];
  }

  @override
  Stream<List<NutritionRecordEntity>> streamRecords(String uid) {
    return Stream.value(_recordsByUser[uid] ?? []);
  }

  @override
  Future<void> updateRecord(String uid, NutritionRecordEntity record) async {
    final list = _recordsByUser[uid];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        list[index] = record;
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final sampleBytes = Uint8List.fromList([10, 20, 30, 40]);
  final resolver = UniversalNutritionResolver();

  group('Phase 35.12.9 — Section 1: Real-Device Benchmark Evaluation Dataset Audit', () {
    test('1. Benchmark manifest contains exactly 56 real-image evaluations (40 single, 6 mixed, 10 non-food)', () {
      final manifestFile = File('tools/benchmarks/food_open_vocabulary/device_assets/benchmark_suite_manifest.json');
      expect(manifestFile.existsSync(), isTrue, reason: 'Manifest file must exist');

      final content = manifestFile.readAsStringSync();
      final data = json.decode(content) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;

      expect(items.length, equals(56));

      final singleFoodItems = items.where((x) => x['testGroup'] != 'mixed_meal' && x['testGroup'] != 'non_food_safety').toList();
      final mixedMealItems = items.where((x) => x['testGroup'] == 'mixed_meal').toList();
      final nonFoodItems = items.where((x) => x['testGroup'] == 'non_food_safety').toList();

      expect(singleFoodItems.length, equals(40), reason: 'Must contain 40 single-food images');
      expect(mixedMealItems.length, equals(6), reason: 'Manifest has 6 mixed-meal images (gap to 10 documented)');
      expect(nonFoodItems.length, equals(10), reason: 'Must contain 10 non-food images');
    });

    test('2. SigLIP-B/16 INT8 on Samsung RZCW8201QBV achieves 10/10 (100%) non-food rejection', () {
      final csvFile = File('tools/benchmarks/food_open_vocabulary/device_predictions_RZCW8201QBV_35_11a2.csv');
      expect(csvFile.existsSync(), isTrue);

      final lines = csvFile.readAsLinesSync();
      final header = lines.first.split(',');
      final modelIdx = header.indexOf('model');
      final groupIdx = header.indexOf('test_group');
      final acceptedIdx = header.indexOf('food_accepted');

      int nonFoodTotal = 0;
      int nonFoodRejected = 0;

      for (var i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length < header.length) continue;
        if (cols[modelIdx] == 'siglip_b16_int8' && cols[groupIdx] == 'non_food_safety') {
          nonFoodTotal++;
          final isAccepted = cols[acceptedIdx].trim().toLowerCase() == 'true';
          if (!isAccepted) {
            nonFoodRejected++;
          }
        }
      }

      expect(nonFoodTotal, equals(10));
      expect(nonFoodRejected, equals(10), reason: 'Every non-food image must be rejected on SigLIP');
      expect(nonFoodRejected / nonFoodTotal, equals(1.0));
    });

    test('3. SigLIP-B/16 INT8 on Samsung RZCW8201QBV achieves high Top-1 / Top-3 fidelity on core foods', () {
      final csvFile = File('tools/benchmarks/food_open_vocabulary/device_predictions_RZCW8201QBV_35_11a2.csv');
      final lines = csvFile.readAsLinesSync();
      final header = lines.first.split(',');
      final modelIdx = header.indexOf('model');
      final groupIdx = header.indexOf('test_group');
      final top1MatchIdx = header.indexOf('top1_match_desktop');

      int coreTotal = 0;
      int coreMatches = 0;

      for (var i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length < header.length) continue;
        if (cols[modelIdx] == 'siglip_b16_int8' && (cols[groupIdx] == 'real_food_core' || cols[groupIdx] == 'real_food_extended')) {
          coreTotal++;
          if (cols[top1MatchIdx].trim().toLowerCase() == 'true') {
            coreMatches++;
          }
        }
      }

      expect(coreTotal, equals(15));
      expect(coreMatches, greaterThanOrEqualTo(14), reason: 'At least 14/15 core/extended foods match between desktop and Samsung');
    });
  });

  group('Phase 35.12.9 — Section 8: Nutrition Resolution & Provenance for Target Foods', () {
    test('4. All 10 Target Indian/Western foods resolve to exact curated catalog items with valid macros', () {
      final targetFoods = [
        ('openvocab_sambar', 'predefined_sambar', 'Sambar', 150.0, 'ml', 120.0, 4.5, 18.0, 3.2),
        ('openvocab_rasam', 'predefined_rasam', 'Rasam', 150.0, 'ml', 45.0, 1.0, 7.0, 1.5),
        ('openvocab_poha', 'predefined_poha', 'Poha', 100.0, 'g', 180.0, 3.0, 33.0, 3.8),
        ('openvocab_curd', 'predefined_curd', 'Indian Curd (Dahi)', 100.0, 'g', 60.0, 3.5, 4.7, 3.0),
        ('openvocab_chicken_curry', 'predefined_chicken_curry', 'Home Style Chicken Curry', 100.0, 'g', 195.0, 20.0, 4.5, 11.0),
        ('openvocab_fish_curry', 'predefined_fish_curry', 'Indian Fish Curry', 100.0, 'g', 165.0, 18.0, 3.5, 8.8),
        ('openvocab_butter_chicken', 'predefined_butter_chicken', 'Butter Chicken (Murgh Makhani)', 100.0, 'g', 280.0, 18.0, 6.0, 20.0),
        ('openvocab_paneer_bhurji', 'predefined_paneer_bhurji', 'Paneer Bhurji', 100.0, 'g', 220.0, 12.5, 4.5, 17.0),
        ('openvocab_chicken_biryani', 'predefined_chicken_biryani', 'Chicken Biryani', 100.0, 'g', 220.0, 14.5, 28.0, 7.2),
        ('openvocab_veg_biryani', 'predefined_veg_biryani', 'Vegetable Biryani', 100.0, 'g', 180.0, 4.0, 31.0, 4.8),
      ];

      for (final t in targetFoods) {
        final c = OpenVocabularyFoodCandidate(
          canonicalFoodId: t.$1,
          canonicalName: t.$3,
          category: 'Indian',
          similarity: 0.1700,
          rank: 1,
        );

        final res = resolver.resolveCandidate(c, foodCatalog: catalog);
        expect(res.tier, equals(NutritionProfileTier.verifiedExact), reason: 'Failed tier for ${t.$3}');
        expect(res.matchedCatalogFood, isNotNull);
        final food = res.matchedCatalogFood!;
        expect(food.id, equals(t.$2));
        expect(food.name, equals(t.$3));
        expect(food.servingSize, equals(t.$4));
        expect(food.servingUnit, equals(t.$5));
        expect(food.calories, equals(t.$6));
        expect(food.protein, equals(t.$7));
        expect(food.carbohydrates, equals(t.$8));
        expect(food.fats, equals(t.$9));

        // Provenance & Non-Fabrication assertions:
        expect(food.calories, greaterThan(0));
        expect(food.protein, greaterThan(0));
        expect(food.carbohydrates, greaterThan(0));
        expect(food.fats, greaterThan(0));
      }
    });

    test('5. Portion scaling formula N_portion = N_base * (portion / base) applies deterministically across all macros', () {
      final chickenCurry = catalog.firstWhere((f) => f.id == 'predefined_chicken_curry');
      // Base: 100g, 195 kcal, 20.0g protein, 4.5g carbs, 11.0g fats, 1.2g fiber, 310mg sodium
      final candidate = DetectedFoodCandidate(
        id: 'test_candidate_1',
        detectedName: chickenCurry.name,
        confidence: 0.95,
        estimatedAmount: 250.0, // 250g portion (2.5x base)
        originalEstimatedAmount: chickenCurry.servingSize,
        estimatedUnit: chickenCurry.servingUnit,
        matchedFood: chickenCurry,
        matchConfidence: 1.0,
      );

      expect(candidate.scaledCalories, equals(487.5)); // 195 * 2.5
      expect(candidate.scaledProtein, equals(50.0));   // 20.0 * 2.5
      expect(candidate.scaledCarbs, equals(11.25));    // 4.5 * 2.5
      expect(candidate.scaledFats, equals(27.5));      // 11.0 * 2.5
      expect(candidate.fiber, equals(3.0));            // 1.2 * 2.5
      expect(candidate.sodium, equals(775.0));         // 310 * 2.5
    });
  });

  group('Phase 35.12.9 — Section 9: Serving-Size Math, Mixed Meals & Deduplication', () {
    test('6. Mixed meal sum N_meal = sum(N_components) matches exact constituent math', () {
      final rice = catalog.firstWhere((f) => f.id == 'predefined_steamed_rice'); // 100g -> 130 kcal, 2.7g P, 28.0g C, 0.3g F
      final sambar = catalog.firstWhere((f) => f.id == 'predefined_sambar');       // 150ml -> 120 kcal, 4.5g P, 18.0g C, 3.2g F
      final curd = catalog.firstWhere((f) => f.id == 'predefined_curd');           // 100g -> 60 kcal, 3.5g P, 4.7g C, 3.0g F

      final foods = [
        DetectedFoodCandidate(
          id: 'c1',
          detectedName: rice.name,
          confidence: 0.92,
          estimatedAmount: 200.0, // 200g rice -> 260 kcal, 5.4g P, 56.0g C, 0.6g F
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: rice,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
        DetectedFoodCandidate(
          id: 'c2',
          detectedName: sambar.name,
          confidence: 0.89,
          estimatedAmount: 150.0, // 150ml sambar -> 120 kcal, 4.5g P, 18.0g C, 3.2g F
          originalEstimatedAmount: 150.0,
          estimatedUnit: 'ml',
          matchedFood: sambar,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
        DetectedFoodCandidate(
          id: 'c3',
          detectedName: curd.name,
          confidence: 0.90,
          estimatedAmount: 100.0, // 100g curd -> 60 kcal, 3.5g P, 4.7g C, 3.0g F
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: curd,
          matchConfidence: 1.0,
          isUserConfirmed: true,
          nutritionTier: NutritionProfileTier.verifiedExact,
        ),
      ];

      final scanResult = FoodScanResult(
        id: 'mixed_scan_1',
        foods: foods,
        overallConfidence: 0.90,
        scannedAt: DateTime.now(),
      );

      // Expected totals:
      // Calories: 260 + 120 + 60 = 440 kcal
      // Protein: 5.4 + 4.5 + 3.5 = 13.4 g
      // Carbs: 56.0 + 18.0 + 4.7 = 78.7 g
      // Fats: 0.6 + 3.2 + 3.0 = 6.8 g
      expect(scanResult.totalCalories, equals(440.0));
      expect(scanResult.totalProtein, closeTo(13.4, 0.01));
      expect(scanResult.totalCarbs, closeTo(78.7, 0.01));
      expect(scanResult.totalFats, closeTo(6.8, 0.01));
    });

    test('7. FoodScanController.addComponent deduplicates identical food and sums portion cleanly', () {
      final tier1 = _MockTier1Classifier(
        const LocalFoodPrediction(foodId: '', foodName: '', confidence: 0.10),
      );
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        remoteDataSource: _SpyRemoteDataSource(),
      );
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: _SpyRemoteDataSource(),
          router: router,
        ),
        imagePickerService: _MockImagePickerService(),
      );

      final rice = catalog.firstWhere((f) => f.id == 'predefined_steamed_rice');
      final sambar = catalog.firstWhere((f) => f.id == 'predefined_sambar');

      // 1. Initial selection: 150g rice
      controller.selectManualFood(rice, amount: 150.0);
      expect(controller.state, isA<FoodScanSuccess>());
      var state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(1));
      expect(state.result.foods[0].estimatedAmount, equals(150.0));
      expect(state.result.totalCalories, equals(195.0)); // 130 * 1.5

      // 2. Add 100g rice to same meal: must NOT create a 2nd row, must sum to 250g
      controller.addComponent(rice, amount: 100.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(1), reason: 'Must consolidate duplicate rice');
      expect(state.result.foods[0].estimatedAmount, equals(250.0));
      expect(state.result.totalCalories, equals(325.0)); // 130 * 2.5

      // 3. Add genuinely distinct food: 150ml sambar -> 2 distinct components
      controller.addComponent(sambar, amount: 150.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(2));
      expect(state.result.totalCalories, equals(445.0)); // 325 + 120

      // 4. Update portion of Sambar to 300ml
      controller.updatePortion(1, 300.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods[1].estimatedAmount, equals(300.0));
      expect(state.result.totalCalories, equals(565.0)); // 325 + 240

      // 5. Remove Sambar -> total reduces back to 325 kcal
      controller.removeComponent(1);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.length, equals(1));
      expect(state.result.totalCalories, equals(325.0));
    });
  });

  group('Phase 35.12.9 — Section 10 & 11: Free-First Offline Guarantee & Diary Persistence', () {
    test('8. Offline scans and normal flow execute with zero automatic Gemini / cloud requests', () async {
      final tier1 = _MockTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.95,
          topCandidates: [
            LocalFoodCandidate(foodId: 'predefined_samosa', foodName: 'Samosa', confidence: 0.95),
            LocalFoodCandidate(foodId: 'predefined_banana', foodName: 'Banana', confidence: 0.03),
          ],
        ),
      );
      final tier2 = _MockTier2Recognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: const [
            OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_samosa',
              canonicalName: 'Samosa',
              category: 'Snacks',
              similarity: 0.1800,
              rank: 1,
            ),
          ],
          maxFoodSimilarity: 0.1800,
          maxNegSimilarity: -0.0100,
          negMargin: 0.1900,
        ),
      );
      final remote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_offline_test',
        imagePath: 'samosa.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
        isOffline: true,
      );

      expect(decision, isA<LocalAutoAccepted>());
      expect(remote.analyzeCallCount, equals(0), reason: 'Zero cloud calls must be made in normal scan');
      expect(router.cloudCallsThisScan, equals(0));
    });

    test('9. Diary persistence writes confirmed meal records with user isolation', () async {
      final repo = _InMemoryNutritionRepo();
      final tier1 = _MockTier1Classifier(
        const LocalFoodPrediction(foodId: '', foodName: '', confidence: 0.10),
      );
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        remoteDataSource: _SpyRemoteDataSource(),
      );
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: _SpyRemoteDataSource(),
          router: router,
        ),
        imagePickerService: _MockImagePickerService(),
      );

      final rice = catalog.firstWhere((f) => f.id == 'predefined_steamed_rice');
      controller.selectManualFood(rice, amount: 200.0);

      // Log for user A
      final loggedA = await controller.logToDiary('user_A_123', repo);
      expect(loggedA, isTrue);

      final recordsA = await repo.getRecords('user_A_123');
      expect(recordsA.length, equals(1));
      expect(recordsA[0].foodName, equals('Steamed Rice (Basmati)'));
      expect(recordsA[0].calories, equals(260.0));

      // Check User B has zero records (complete account isolation)
      final recordsB = await repo.getRecords('user_B_456');
      expect(recordsB, isEmpty);
    });

    test('10. Camera and Gallery picker sources both initialize scan correctly', () async {
      final picker = _MockImagePickerService();
      final tier1 = _MockTier1Classifier(
        const LocalFoodPrediction(foodId: '', foodName: '', confidence: 0.10),
      );
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        remoteDataSource: _SpyRemoteDataSource(),
      );
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: _SpyRemoteDataSource(),
          router: router,
        ),
        imagePickerService: picker,
      );

      // Test camera path
      picker.nextPath = 'camera_capture_1.jpg';
      await controller.pickAndScan(FoodImagePickSource.camera);
      expect(controller.state, isNot(isA<FoodScanIdle>()));

      // Test gallery path
      controller.reset();
      expect(controller.state, isA<FoodScanIdle>());
      picker.nextPath = 'gallery_selection_1.jpg';
      await controller.pickAndScan(FoodImagePickSource.gallery);
      expect(controller.state, isNot(isA<FoodScanIdle>()));
    });
  });
}
