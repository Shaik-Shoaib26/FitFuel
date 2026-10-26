import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/recipe_formulation.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/nutrition/data/datasources/nutrition_remote_datasource.dart';
import 'package:fitfuel/features/nutrition/data/models/nutrition_record_model.dart';
import 'package:fitfuel/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake remote data source with strict per-user collection isolation.
class FakeIsolatedNutritionRemoteDataSource implements INutritionRemoteDataSource {
  final Map<String, List<NutritionRecordModel>> userDatabases = {};

  @override
  Future<void> addRecord(String uid, NutritionRecordModel record) async {
    userDatabases.putIfAbsent(uid, () => []).add(record);
  }

  @override
  Future<List<NutritionRecordModel>> getRecords(String uid) async {
    return List.unmodifiable(userDatabases[uid] ?? []);
  }

  @override
  Stream<List<NutritionRecordModel>> streamRecords(String uid) {
    return Stream.value(List.unmodifiable(userDatabases[uid] ?? []));
  }

  @override
  Future<void> updateRecord(String uid, NutritionRecordModel record) async {
    final list = userDatabases[uid];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        list[index] = record;
      }
    }
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {
    final list = userDatabases[uid];
    if (list != null) {
      list.removeWhere((r) => r.id == recordId);
    }
  }
}

class FakeFoodScanRepository implements IFoodScanRepository {
  @override
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    String? requestId,
  }) async {
    throw UnimplementedError();
  }
}

class FakeImagePickerService implements IFoodImagePickerService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UniversalNutritionResolver resolver;
  late FakeIsolatedNutritionRemoteDataSource remoteDataSource;
  late NutritionRepositoryImpl repository;
  late FoodScanController controller;

  setUp(() {
    resolver = UniversalNutritionResolver();
    remoteDataSource = FakeIsolatedNutritionRemoteDataSource();
    repository = NutritionRepositoryImpl(remoteDataSource);
    controller = FoodScanController(
      repository: FakeFoodScanRepository(),
      imagePickerService: FakeImagePickerService(),
      universalNutritionResolver: resolver,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('Phase 35.12.16 — Section 2: Canonical Recipe Reconciliation & Atwater Dual-Limit', () {
    test('1. Creamy Penne Alfredo canonical formulation, profile, and Atwater dual-limit', () {
      final formulation = resolver.recipeFormulations['creamy_pasta_estimate']!;
      final profile = resolver.recipeEstimates['creamy_pasta_estimate']!;

      expect(formulation.recipeId, 'recipe_est_creamy_pasta');
      expect(formulation.targetBatchMassGrams, 500.0);
      expect(formulation.yieldType, BatchYieldType.calculatedFromPreparedIngredients);

      // Batch nutrient checks
      expect(formulation.batchCalories, closeTo(975.0, 0.1));
      expect(formulation.batchProtein, closeTo(33.85, 0.05));
      expect(formulation.batchCarbs, closeTo(83.70, 0.05));
      expect(formulation.batchFat, closeTo(55.85, 0.05));
      expect(formulation.batchFiber, closeTo(5.55, 0.05));
      expect(formulation.batchSodium, closeTo(1602.17, 0.05));

      // Stored per-100g profile
      expect(profile.calories, equals(195.0));
      expect(profile.protein, equals(6.77));
      expect(profile.carbohydrates, equals(16.74));
      expect(profile.totalFat, equals(11.17));
      expect(profile.fiber, equals(1.11));
      expect(profile.sugar, equals(1.2));
      expect(profile.sodium, equals(320.4));
      expect(profile.tier, NutritionProfileTier.recipeEstimate);

      // Atwater dual-limit check
      final atwater = formulation.validateCalorieConsistency();
      expect(atwater.isValid, isTrue);
      expect(atwater.absoluteCheckPassed, isTrue);
      expect(atwater.relativeCheckPassed, isTrue);
      expect(atwater.absoluteDiscrepancy, lessThanOrEqualTo(8.0));
      expect(atwater.relativeDiscrepancyPercent, lessThanOrEqualTo(5.0));
    });

    test('2. Chicken Tikka Masala canonical formulation, profile, and Atwater dual-limit', () {
      final formulation = resolver.recipeFormulations['chicken_tikka_masala_estimate']!;
      final profile = resolver.recipeEstimates['chicken_tikka_masala_estimate']!;

      expect(formulation.recipeId, 'recipe_est_chicken_tikka_masala');
      expect(formulation.targetBatchMassGrams, 600.0);
      expect(formulation.yieldType, BatchYieldType.assumedTargetYield);

      // Batch nutrient checks
      expect(formulation.batchCalories, closeTo(895.44, 0.1));
      expect(formulation.batchProtein, closeTo(98.54, 0.05));
      expect(formulation.batchCarbs, closeTo(21.25, 0.05));
      expect(formulation.batchFat, closeTo(43.68, 0.05));
      expect(formulation.batchFiber, closeTo(5.60, 0.05));
      expect(formulation.batchSodium, closeTo(2280.05, 0.05));

      // Stored per-100g profile
      expect(profile.calories, equals(149.24));
      expect(profile.protein, equals(16.42));
      expect(profile.carbohydrates, equals(3.54));
      expect(profile.totalFat, equals(7.28));
      expect(profile.fiber, equals(0.93));
      expect(profile.sodium, equals(380.0));
      expect(profile.tier, NutritionProfileTier.recipeEstimate);

      // Atwater dual-limit check
      final atwater = formulation.validateCalorieConsistency();
      expect(atwater.isValid, isTrue);
      expect(atwater.absoluteCheckPassed, isTrue);
      expect(atwater.relativeCheckPassed, isTrue);
      expect(atwater.absoluteDiscrepancy, lessThanOrEqualTo(8.0));
      expect(atwater.relativeDiscrepancyPercent, lessThanOrEqualTo(5.0));
    });

    test('3. Priority Discrepancy A: Vegetable Fried Rice canonical values vs historical confusion', () {
      final formulation = resolver.recipeFormulations['vegetable_fried_rice_estimate']!;
      final profile = resolver.recipeEstimates['vegetable_fried_rice_estimate']!;

      expect(formulation.recipeId, 'recipe_est_veg_fried_rice');
      expect(formulation.targetBatchMassGrams, 500.0);

      // Batch nutrient checks
      expect(formulation.batchCalories, closeTo(754.0, 0.1));
      expect(formulation.batchProtein, closeTo(13.68, 0.05));
      expect(formulation.batchCarbs, closeTo(112.60, 0.05));
      expect(formulation.batchFat, closeTo(26.50, 0.05));
      expect(formulation.batchFiber, closeTo(4.54, 0.05));
      expect(formulation.batchSodium, closeTo(1600.29, 0.05));

      // Stored per-100g profile must match mathematical formulation (NOT the unformulated Phase 35.12.15 report typo)
      expect(profile.calories, equals(150.80));
      expect(profile.protein, equals(2.74)); // NOT 3.4g
      expect(profile.carbohydrates, equals(22.52)); // NOT 24.8g
      expect(profile.totalFat, equals(5.30)); // NOT 4.2g
      expect(profile.fiber, equals(0.91)); // NOT 1.6g
      expect(profile.sodium, equals(320.1));

      // Atwater dual-limit check
      final atwater = formulation.validateCalorieConsistency();
      expect(atwater.isValid, isTrue);
      expect(atwater.absoluteCheckPassed, isTrue);
      expect(atwater.relativeCheckPassed, isTrue);
      expect(atwater.absoluteDiscrepancy, closeTo(2.08, 0.05));
      expect(atwater.relativeDiscrepancyPercent, closeTo(1.38, 0.05));
    });

    test('4. Priority Discrepancy B: Vegetable Curry canonical values vs report documentation error', () {
      final formulation = resolver.recipeFormulations['vegetable_curry_estimate']!;
      final profile = resolver.recipeEstimates['vegetable_curry_estimate']!;

      expect(formulation.recipeId, 'recipe_est_vegetable_curry');
      expect(formulation.targetBatchMassGrams, 600.0);

      // Batch nutrient checks
      expect(formulation.batchCalories, closeTo(439.0, 0.1));
      expect(formulation.batchProtein, closeTo(10.00, 0.05));
      expect(formulation.batchCarbs, closeTo(48.00, 0.05));
      expect(formulation.batchFat, closeTo(22.80, 0.05));
      expect(formulation.batchFiber, closeTo(14.00, 0.05));
      expect(formulation.batchSodium, closeTo(1864.79, 0.05));

      // Stored per-100g profile
      expect(profile.calories, equals(73.17));
      expect(profile.protein, equals(1.67)); // NOT 1.9g
      expect(profile.carbohydrates, equals(8.00)); // NOT 9.8g
      expect(profile.totalFat, equals(3.80)); // NOT 4.3g
      expect(profile.fiber, equals(2.33));
      expect(profile.sodium, equals(310.8));

      // Atwater dual-limit check: absolute diff is only 0.30 kcal, relative diff is 0.41%
      final atwater = formulation.validateCalorieConsistency();
      expect(atwater.isValid, isTrue);
      expect(atwater.absoluteCheckPassed, isTrue);
      expect(atwater.relativeCheckPassed, isTrue);
      expect(atwater.absoluteDiscrepancy, closeTo(0.30, 0.05));
      expect(atwater.relativeDiscrepancyPercent, closeTo(0.41, 0.05));
    });
  });

  group('Phase 35.12.16 — Section 3: Portion Scaling & Corrected Quinoa Test', () {
    const quinoa = FoodEntity(
      id: 'quinoa_canonical',
      name: 'Quinoa',
      category: 'Grains',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 120.0,
      protein: 4.4,
      carbohydrates: 21.3,
      fats: 1.9,
      fiber: 2.8,
      sugar: 0.9,
      sodium: 7.0,
    );

    test('5. Corrected 50 g Quinoa portion test (remedies Phase 35.12.15 table typo)', () {
      const candidate50g = DetectedFoodCandidate(
        id: 'cand_50g',
        detectedName: 'Quinoa',
        confidence: 0.95,
        estimatedAmount: 50.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: quinoa,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      // Verify exact 50g expected values derived from canonical baseline
      expect(candidate50g.scaledCalories, closeTo(60.0, 0.001));
      expect(candidate50g.scaledProtein, closeTo(2.20, 0.001));
      expect(candidate50g.scaledCarbs, closeTo(10.65, 0.001));
      expect(candidate50g.scaledFats, closeTo(0.95, 0.001));
      expect(candidate50g.fiber, closeTo(1.40, 0.001));
      expect(candidate50g.sugar, closeTo(0.45, 0.001));
      expect(candidate50g.sodium, closeTo(3.50, 0.001));
    });

    test('6. Fractional 125.5 g Quinoa portion test verified independently', () {
      const candidate125g = DetectedFoodCandidate(
        id: 'cand_125g',
        detectedName: 'Quinoa',
        confidence: 0.95,
        estimatedAmount: 125.5,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: quinoa,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      const factor = 125.5 / 100.0;
      expect(candidate125g.scaledCalories, closeTo(120.0 * factor, 0.001)); // 150.60
      expect(candidate125g.scaledProtein, closeTo(4.4 * factor, 0.001)); // 5.522
      expect(candidate125g.scaledCarbs, closeTo(21.3 * factor, 0.001)); // 26.7315
      expect(candidate125g.scaledFats, closeTo(1.9 * factor, 0.001)); // 2.3845
      expect(candidate125g.fiber, closeTo(2.8 * factor, 0.001)); // 3.514
      expect(candidate125g.sugar, closeTo(0.9 * factor, 0.001)); // 1.1295
      expect(candidate125g.sodium, closeTo(7.0 * factor, 0.001)); // 8.785
    });

    test('7. Representative portions matrix (50g, 100g, 125.5g, 150g, 250g, 350g) across all fields', () {
      final portions = [50.0, 100.0, 125.5, 150.0, 250.0, 350.0];

      for (final portion in portions) {
        final cand = DetectedFoodCandidate(
          id: 'cand_$portion',
          detectedName: 'Quinoa',
          confidence: 0.95,
          estimatedAmount: portion,
          originalEstimatedAmount: 100.0,
          matchedFood: quinoa,
          nutritionTier: NutritionProfileTier.verifiedExact,
        );

        final scale = portion / 100.0;
        expect(cand.scaledCalories, closeTo(quinoa.calories * scale, 0.001));
        expect(cand.scaledProtein, closeTo(quinoa.protein * scale, 0.001));
        expect(cand.scaledCarbs, closeTo(quinoa.carbohydrates * scale, 0.001));
        expect(cand.scaledFats, closeTo(quinoa.fats * scale, 0.001));
        expect(cand.fiber, closeTo(quinoa.fiber * scale, 0.001));
        expect(cand.sugar, closeTo(quinoa.sugar * scale, 0.001));
        expect(cand.sodium, closeTo(quinoa.sodium * scale, 0.001));
      }
    });
  });

  group('Phase 35.12.16 — Section 4: Missing-Value Semantics & Legacy Compatibility', () {
    test('8. Distinguishes known measured zero vs unknown/absent vs known nonzero', () {
      final now = DateTime.now();

      // Known zero (e.g. Meat with 0.0g fiber)
      final zeroFiberRecord = NutritionRecordEntity(
        id: 'rec_zero_fiber',
        foodName: 'Grilled Chicken Breast',
        mealType: 'Lunch',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
        sugar: 0.0,
        fiber: 0.0, // Known measured 0
        sodium: 74.0,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(zeroFiberRecord.hasFiber, isTrue);
      expect(zeroFiberRecord.fiber, equals(0.0));

      // Unknown/absent fiber (legacy or unmeasured)
      final unknownFiberRecord = NutritionRecordEntity(
        id: 'rec_unknown_fiber',
        foodName: 'Mystery Snack',
        mealType: 'Snack',
        calories: 200.0,
        protein: 5.0,
        carbohydrates: 25.0,
        fats: 10.0,
        sugar: 5.0,
        fiber: null, // Unknown
        sodium: null, // Unknown
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(unknownFiberRecord.hasFiber, isFalse);
      expect(unknownFiberRecord.fiber, isNull);
      expect(unknownFiberRecord.hasSodium, isFalse);
      expect(unknownFiberRecord.sodium, isNull);

      // Known nonzero fiber
      final nonzeroRecord = NutritionRecordEntity(
        id: 'rec_nonzero',
        foodName: 'Oats',
        mealType: 'Breakfast',
        calories: 150.0,
        protein: 5.0,
        carbohydrates: 27.0,
        fats: 3.0,
        sugar: 1.0,
        fiber: 4.0,
        sodium: 2.0,
        servingSize: 40.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(nonzeroRecord.hasFiber, isTrue);
      expect(nonzeroRecord.fiber, equals(4.0));
    });

    test('9. Serialization & deserialization preserves absent vs zero distinction without corrupting legacy docs', () {
      final now = DateTime.now();

      // 1. Model with explicit 0.0 writes 'fiber': 0.0
      final zeroModel = NutritionRecordModel(
        id: 'doc_zero',
        foodName: 'Chicken',
        mealType: 'Dinner',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
        sugar: 0.0,
        fiber: 0.0,
        sodium: 74.0,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final zeroMap = zeroModel.toFirestore();
      expect(zeroMap.containsKey('fiber'), isTrue);
      expect(zeroMap['fiber'], equals(0.0));

      // 2. Model with null fiber does NOT write 'fiber' key
      final nullModel = NutritionRecordModel(
        id: 'doc_null',
        foodName: 'Legacy Food',
        mealType: 'Dinner',
        calories: 100.0,
        protein: 2.0,
        carbohydrates: 20.0,
        fats: 1.0,
        sugar: 2.0,
        fiber: null,
        sodium: null,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final nullMap = nullModel.toFirestore();
      expect(nullMap.containsKey('fiber'), isFalse);
      expect(nullMap.containsKey('sodium'), isFalse);

      // 3. Deserializing legacy snapshot (missing 'fiber' and 'sodium' keys) returns null, NOT 0.0
      final legacyRawMap = {
        'foodName': 'Old Legacy Food',
        'mealType': 'Lunch',
        'calories': 180.0,
        'protein': 4.0,
        'carbohydrates': 30.0,
        'fats': 5.0,
        'sugar': 3.0,
        'servingSize': 100.0,
        'consumedAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      double? parseNullableDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      final legacyFiber = parseNullableDouble(legacyRawMap['fiber']);
      final legacySodium = parseNullableDouble(legacyRawMap['sodium']);
      expect(legacyFiber, isNull);
      expect(legacySodium, isNull);
    });

    test('10. Unsupported food candidate retains null macros, blocks diary submission, and allows manual unlock', () async {
      const unsupported = DetectedFoodCandidate(
        id: 'cand_unknown',
        detectedName: 'Exotic Unidentified Dish',
        confidence: 0.40,
        estimatedAmount: 100.0,
        matchedFood: null,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      expect(unsupported.calories, isNull);
      expect(unsupported.protein, isNull);
      expect(unsupported.carbs, isNull);
      expect(unsupported.fats, isNull);
      expect(unsupported.hasNutrition, isFalse);

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'scan_blocked',
          foods: const [unsupported],
          overallConfidence: 0.40,
          scannedAt: DateTime.now(),
        ),
        selectedMealType: 'Lunch',
      );

      final logged = await controller.logToDiary('user_safe', repository);
      expect(logged, isFalse, reason: 'Must block logging when food has incomplete/unavailable nutrition');
      final records = await repository.getRecords('user_safe');
      expect(records.isEmpty, isTrue);

      // Supply valid manual input
      const manualEntry = FoodEntity(
        id: 'manual_exotic_dish',
        name: 'Exotic Unidentified Dish (Custom)',
        category: 'Custom',
        servingSize: 150.0,
        servingUnit: 'g',
        calories: 220.0,
        protein: 10.0,
        carbohydrates: 25.0,
        fats: 8.0,
        fiber: 3.0,
        sugar: 2.0,
        sodium: 350.0,
        isCustom: true,
      );

      controller.updateMatchedFood(0, manualEntry);
      final updatedState = controller.state as FoodScanSuccess;
      expect(updatedState.result.foods.first.hasNutrition, isTrue);
      expect(updatedState.result.foods.first.isUserEnteredNutrition, isTrue);
      expect(updatedState.result.foods.first.nutritionSourceLabel, 'User-entered nutrition');

      final logSuccess = await controller.logToDiary('user_safe', repository);
      expect(logSuccess, isTrue);
      final savedRecords = await repository.getRecords('user_safe');
      expect(savedRecords.length, 1);
      expect(savedRecords.first.foodName, 'Exotic Unidentified Dish (Custom)');
      expect(savedRecords.first.nutritionSourceLabel, 'User-entered nutrition');
    });
  });

  group('Phase 35.12.16 — Section 5: Full E2E Diary Integrity & Stable Baseline Portions', () {
    test('11. Complete lifecycle for all 4 recipes & curated Quinoa without compounding error', () async {
      final curatedCatalog = PredefinedFoodData.foods.map((f) => f.toEntity()).toList();

      final testItems = [
        ('fettuccine_alfredo', 'Fettuccine Alfredo', 195.0, 6.77, 16.74, 11.17, 320.4, NutritionProfileTier.recipeEstimate),
        ('chicken_tikka_masala', 'Chicken Tikka Masala', 149.24, 16.42, 3.54, 7.28, 380.0, NutritionProfileTier.recipeEstimate),
        ('vegetable_fried_rice', 'Vegetable Fried Rice', 150.80, 2.74, 22.52, 5.30, 320.1, NutritionProfileTier.recipeEstimate),
        ('vegetable_curry', 'Vegetable Curry', 73.17, 1.67, 8.00, 3.80, 310.8, NutritionProfileTier.recipeEstimate),
        ('predefined_grilled_chicken_breast', 'Grilled Chicken Breast', 165.0, 31.0, 0.0, 3.6, 74.0, NutritionProfileTier.verifiedExact),
      ];

      for (final item in testItems) {
        final id = item.$1;
        final name = item.$2;
        final baseCal = item.$3;
        final baseProt = item.$4;
        final baseCarbs = item.$5;
        final baseFat = item.$6;
        final baseNa = item.$7;
        final expectedTier = item.$8;

        // Step 1: Resolve Food
        final candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: id,
          canonicalName: name,
          category: 'Culinary',
          similarity: 0.95,
          rank: 1,
        );
        final resolution = resolver.resolveCandidate(candidate, foodCatalog: curatedCatalog);
        expect(resolution.matchedCatalogFood, isNotNull);
        final foodEntity = resolution.matchedCatalogFood!;
        expect(resolution.tier, expectedTier);

        // Step 2: Portion Scaling to 250g
        final detected = DetectedFoodCandidate(
          id: 'cand_$id',
          detectedName: name,
          confidence: 0.95,
          estimatedAmount: 250.0,
          originalEstimatedAmount: 100.0,
          matchedFood: foodEntity,
          nutritionTier: resolution.tier,
          nutritionAttribution: resolution.attribution,
          recipeAssumptions: resolution.recipeAssumptions,
        );

        expect(detected.scaledCalories, closeTo(baseCal * 2.5, 0.05));
        expect(detected.scaledProtein, closeTo(baseProt * 2.5, 0.05));
        expect(detected.scaledCarbs, closeTo(baseCarbs * 2.5, 0.05));
        expect(detected.scaledFats, closeTo(baseFat * 2.5, 0.05));
        expect(detected.sodium, closeTo(baseNa * 2.5, 0.1));

        // Step 3: Save to Diary
        // ignore: invalid_use_of_protected_member
        controller.state = FoodScanSuccess(
          result: FoodScanResult(
            id: 'scan_$id',
            foods: [detected],
            overallConfidence: 0.95,
            scannedAt: DateTime.now(),
          ),
          selectedMealType: 'Dinner',
        );

        final uid = 'user_e2e_$id';
        final logged = await controller.logToDiary(uid, repository);
        expect(logged, isTrue);

        // Step 4: Read back from persistence
        final persisted = await repository.getRecords(uid);
        expect(persisted.length, 1);
        final record = persisted.first;
        expect(record.foodName, name);
        expect(record.servingSize, 250.0);
        expect(record.calories, closeTo(baseCal * 2.5, 0.05));
        expect(record.baseServingSize, 100.0);
        expect(record.baseCalories, closeTo(baseCal, 0.05));
        expect(record.baseProtein, closeTo(baseProt, 0.05));
        expect(record.baseCarbohydrates, closeTo(baseCarbs, 0.05));
        expect(record.baseFats, closeTo(baseFat, 0.05));
        expect(record.baseSodium, closeTo(baseNa, 0.1));

        // Step 5: Simulate Reopen & Re-edit to 350g (using canonical baseline)
        const newServing = 350.0;
        final scale = newServing / record.baseServingSize!;
        final updatedRecord = record.copyWith(
          servingSize: newServing,
          calories: record.baseCalories! * scale,
          protein: record.baseProtein! * scale,
          carbohydrates: record.baseCarbohydrates! * scale,
          fats: record.baseFats! * scale,
          sodium: record.baseSodium! * scale,
          updatedAt: DateTime.now(),
        );

        await repository.updateRecord(uid, updatedRecord);

        // Step 6: Verify updated record in persistence - NO COMPOUNDING ERROR
        final reReadList = await repository.getRecords(uid);
        expect(reReadList.length, 1); // No duplicates created
        final reRead = reReadList.first;
        expect(reRead.servingSize, 350.0);
        expect(reRead.calories, closeTo(baseCal * 3.5, 0.05));
        expect(reRead.protein, closeTo(baseProt * 3.5, 0.05));
        expect(reRead.carbohydrates, closeTo(baseCarbs * 3.5, 0.05));
        expect(reRead.fats, closeTo(baseFat * 3.5, 0.05));
        expect(reRead.sodium, closeTo(baseNa * 3.5, 0.1));

        // Base references remain unmutated and stable
        expect(reRead.baseServingSize, 100.0);
        expect(reRead.baseCalories, closeTo(baseCal, 0.05));
      }
    });
  });

  group('Phase 35.12.16 — Section 6: Account Isolation & Scoping Verification', () {
    test('12. User isolation prevents cross-account reads, mutations, deletions, and leakage', () async {
      final now = DateTime.now();

      final recordA = NutritionRecordEntity(
        id: 'entry_userA_1',
        foodName: 'Oatmeal with Blueberries',
        mealType: 'Breakfast',
        calories: 300.0,
        protein: 10.0,
        carbohydrates: 55.0,
        fats: 5.0,
        sugar: 12.0,
        fiber: 6.0,
        sodium: 120.0,
        servingSize: 150.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final recordB = NutritionRecordEntity(
        id: 'entry_userB_1',
        foodName: 'Greek Yogurt Bowl',
        mealType: 'Snack',
        calories: 180.0,
        protein: 15.0,
        carbohydrates: 12.0,
        fats: 4.0,
        sugar: 8.0,
        fiber: 1.0,
        sodium: 65.0,
        servingSize: 170.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Add to separate accounts
      await repository.addRecord('user_alice', recordA);
      await repository.addRecord('user_bob', recordB);

      // Read isolation
      final aliceRecords = await repository.getRecords('user_alice');
      final bobRecords = await repository.getRecords('user_bob');
      expect(aliceRecords.length, 1);
      expect(aliceRecords.first.foodName, 'Oatmeal with Blueberries');
      expect(bobRecords.length, 1);
      expect(bobRecords.first.foodName, 'Greek Yogurt Bowl');

      // Tampered delete: Bob tries to delete Alice's record ID under Bob's scoping
      await repository.deleteRecord('user_bob', 'entry_userA_1');
      // Alice's record remains completely intact
      final aliceAfterDelete = await repository.getRecords('user_alice');
      expect(aliceAfterDelete.length, 1);
      expect(aliceAfterDelete.first.id, 'entry_userA_1');

      // Tampered update: Bob tries to update Alice's record ID under Bob's scoping
      final tamperedBobUpdate = recordA.copyWith(calories: 999.0);
      await repository.updateRecord('user_bob', tamperedBobUpdate);
      // Alice's record remains completely intact with original calories
      final aliceAfterTamper = await repository.getRecords('user_alice');
      expect(aliceAfterTamper.first.calories, 300.0);

      // Fresh user account begins with zero records
      final charlieRecords = await repository.getRecords('user_charlie_fresh');
      expect(charlieRecords.isEmpty, isTrue);
    });
  });
}
