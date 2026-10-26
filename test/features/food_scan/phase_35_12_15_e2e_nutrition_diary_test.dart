import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/nutrition/data/datasources/nutrition_remote_datasource.dart';
import 'package:fitfuel/features/nutrition/data/models/nutrition_record_model.dart';
import 'package:fitfuel/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';

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

  group('Phase 35.12.15: Nutrition Workflow & Serving Size Scaling', () {
    test('Fettuccine Alfredo resolves, scales to 50g, 100g, 250g, 350g, and logs to diary', () async {
      final resolution = resolver.resolveCandidate(
        const OpenVocabularyFoodCandidate(
          canonicalFoodId: 'fettuccine_alfredo',
          canonicalName: 'Fettuccine Alfredo',
          category: 'Pasta',
          similarity: 0.92,
          rank: 1,
        ),
      );
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.tier, NutritionProfileTier.recipeEstimate);

      final matched = resolution.matchedCatalogFood!;
      expect(matched.calories, 195.0);
      expect(matched.protein, 6.77);
      expect(matched.carbohydrates, 16.74);
      expect(matched.fats, 11.17);
      expect(matched.fiber, 1.11);
      expect(matched.sugar, 1.2);
      expect(matched.sodium, 320.4);

      // Initialize FoodScanSuccess with Alfredo at 100g
      final candidate = DetectedFoodCandidate(
        id: 'alfredo_cand',
        detectedName: 'Fettuccine Alfredo',
        confidence: 0.92,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: matched,
        nutritionTier: resolution.tier,
        nutritionAttribution: resolution.attribution,
        recipeAssumptions: resolution.recipeAssumptions,
      );

      final scanResult = FoodScanResult(
        id: 'scan_alfredo',
        foods: [candidate],
        overallConfidence: 0.92,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
      );

      controller.selectMealType('Dinner');
      // Set state to success
      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: scanResult,
        selectedMealType: 'Dinner',
      );

      // Verify initial 100g display values
      var state = controller.state as FoodScanSuccess;
      var food = state.result.foods.first;
      expect(food.nutritionSourceLabel, 'Recipe Estimate');
      expect(food.scaledCalories, closeTo(195.0, 0.01));
      expect(food.scaledProtein, closeTo(6.77, 0.01));
      expect(food.scaledCarbs, closeTo(16.74, 0.01));
      expect(food.scaledFats, closeTo(11.17, 0.01));
      expect(food.fiber, closeTo(1.11, 0.01));
      expect(food.sugar, closeTo(1.2, 0.01));
      expect(food.sodium, closeTo(320.4, 0.01));

      // Test portion scaling: 50 g
      controller.updatePortion(0, 50.0);
      state = controller.state as FoodScanSuccess;
      food = state.result.foods.first;
      expect(food.estimatedAmount, 50.0);
      expect(food.scaledCalories, closeTo(97.5, 0.01));
      expect(food.scaledProtein, closeTo(3.385, 0.01));
      expect(food.scaledCarbs, closeTo(8.37, 0.01));
      expect(food.scaledFats, closeTo(5.585, 0.01));
      expect(food.fiber, closeTo(0.555, 0.01));
      expect(food.sugar, closeTo(0.6, 0.01));
      expect(food.sodium, closeTo(160.2, 0.01));

      // Test portion scaling: 250 g
      controller.updatePortion(0, 250.0);
      state = controller.state as FoodScanSuccess;
      food = state.result.foods.first;
      expect(food.estimatedAmount, 250.0);
      expect(food.scaledCalories, closeTo(487.5, 0.01));
      expect(food.scaledProtein, closeTo(16.925, 0.01));
      expect(food.scaledCarbs, closeTo(41.85, 0.01));
      expect(food.scaledFats, closeTo(27.925, 0.01));
      expect(food.fiber, closeTo(2.775, 0.01));
      expect(food.sugar, closeTo(3.0, 0.01));
      expect(food.sodium, closeTo(801.0, 0.01));

      // Test portion scaling: 350 g
      controller.updatePortion(0, 350.0);
      state = controller.state as FoodScanSuccess;
      food = state.result.foods.first;
      expect(food.estimatedAmount, 350.0);
      expect(food.scaledCalories, closeTo(682.5, 0.01));
      expect(food.scaledProtein, closeTo(23.695, 0.01));
      expect(food.scaledCarbs, closeTo(58.59, 0.01));
      expect(food.scaledFats, closeTo(39.095, 0.01));
      expect(food.fiber, closeTo(3.885, 0.01));
      expect(food.sugar, closeTo(4.2, 0.01));
      expect(food.sodium, closeTo(1121.4, 0.01));

      // Re-scale to 250 g before logging to verify no repeated compounding
      controller.updatePortion(0, 250.0);
      state = controller.state as FoodScanSuccess;
      food = state.result.foods.first;
      expect(food.scaledCalories, closeTo(487.5, 0.01));
      expect(food.scaledProtein, closeTo(16.925, 0.01));
      expect(food.scaledCarbs, closeTo(41.85, 0.01));
      expect(food.scaledFats, closeTo(27.925, 0.01));

      // Save to diary for user 'user_alice'
      final logged = await controller.logToDiary('user_alice', repository);
      expect(logged, isTrue);

      // Verify read-back from persistence
      final savedRecords = await repository.getRecords('user_alice');
      expect(savedRecords.length, 1);
      final saved = savedRecords.first;
      expect(saved.foodName, 'Fettuccine Alfredo');
      expect(saved.mealType, 'Dinner');
      expect(saved.servingSize, 250.0);
      expect(saved.calories, closeTo(487.5, 0.01));
      expect(saved.protein, closeTo(16.925, 0.01));
      expect(saved.carbohydrates, closeTo(41.85, 0.01));
      expect(saved.fats, closeTo(27.925, 0.01));
      expect(saved.fiber, closeTo(2.775, 0.01));
      expect(saved.sugar, closeTo(3.0, 0.01));
      expect(saved.sodium, closeTo(801.0, 0.01));
      expect(saved.nutritionTier, NutritionProfileTier.recipeEstimate);
      expect(saved.nutritionSourceLabel, 'Recipe Estimate');
      expect(saved.baseServingSize, 100.0);
      expect(saved.baseCalories, 195.0);

      // Step 8 & 9: Reopen and edit serving size in diary
      // When edited from 250g to 350g, recalculates from stable base profile
      const newServing = 350.0;
      final scaleFactor = newServing / saved.baseServingSize!;
      final updatedRecord = saved.copyWith(
        servingSize: newServing,
        calories: saved.baseCalories! * scaleFactor,
        protein: saved.baseProtein! * scaleFactor,
        carbohydrates: saved.baseCarbohydrates! * scaleFactor,
        fats: saved.baseFats! * scaleFactor,
        fiber: saved.baseFiber! * scaleFactor,
        sugar: saved.baseSugar! * scaleFactor,
        sodium: saved.baseSodium! * scaleFactor,
        updatedAt: DateTime.now(),
      );

      await repository.updateRecord('user_alice', updatedRecord);

      // Read back again to verify clean recalculation without cumulative errors
      final reloadedRecords = await repository.getRecords('user_alice');
      expect(reloadedRecords.length, 1);
      final reloaded = reloadedRecords.first;
      expect(reloaded.servingSize, 350.0);
      expect(reloaded.calories, closeTo(682.5, 0.01));
      expect(reloaded.protein, closeTo(23.695, 0.01));
      expect(reloaded.carbohydrates, closeTo(58.59, 0.01));
      expect(reloaded.fats, closeTo(39.095, 0.01));
      expect(reloaded.fiber, closeTo(3.885, 0.01));
      expect(reloaded.sugar, closeTo(4.2, 0.01));
      expect(reloaded.sodium, closeTo(1121.4, 0.01));
    });

    test('Chicken Tikka Masala (Recipe Estimate) portion scaling & diary workflow', () async {
      final resolution = resolver.resolveCandidate(
        const OpenVocabularyFoodCandidate(
          canonicalFoodId: 'chicken_tikka_masala',
          canonicalName: 'Chicken Tikka Masala',
          category: 'Indian',
          similarity: 0.88,
          rank: 1,
        ),
      );
      expect(resolution.hasNutrition, isTrue);
      final matched = resolution.matchedCatalogFood!;
      expect(matched.calories, closeTo(149.24, 0.01));
      expect(matched.protein, closeTo(16.42, 0.01));
      expect(matched.carbohydrates, closeTo(3.54, 0.01));
      expect(matched.fats, closeTo(7.28, 0.01));
      expect(matched.fiber, closeTo(0.93, 0.01));
      expect(matched.sodium, 380.0);

      final candidate = DetectedFoodCandidate(
        id: 'tikka_cand',
        detectedName: 'Chicken Tikka Masala',
        confidence: 0.88,
        estimatedAmount: 250.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: matched,
        nutritionTier: resolution.tier,
        nutritionAttribution: resolution.attribution,
        recipeAssumptions: resolution.recipeAssumptions,
      );

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'scan_tikka',
          foods: [candidate],
          overallConfidence: 0.88,
          scannedAt: DateTime.now(),
        ),
        selectedMealType: 'Lunch',
      );

      final food = (controller.state as FoodScanSuccess).result.foods.first;
      expect(food.scaledCalories, closeTo(149.24 * 2.5, 0.01));
      expect(food.scaledProtein, closeTo(16.42 * 2.5, 0.01));
      expect(food.scaledCarbs, closeTo(3.54 * 2.5, 0.01));
      expect(food.scaledFats, closeTo(7.28 * 2.5, 0.01));
      expect(food.fiber, closeTo(0.93 * 2.5, 0.01));
      expect(food.sodium, closeTo(380.0 * 2.5, 0.01));

      // Log to diary
      await controller.logToDiary('user_tikka', repository);
      final list = await repository.getRecords('user_tikka');
      expect(list.length, 1);
      final item = list.first;
      expect(item.calories, closeTo(149.24 * 2.5, 0.01));
      expect(item.sodium, closeTo(950.0, 0.01));
      expect(item.nutritionSourceLabel, 'Recipe Estimate');
    });

    test('Vegetable Fried Rice & Homestyle Vegetable Curry portion scaling & diary workflow', () async {
      final friedRiceRes = resolver.resolveCandidate(
        const OpenVocabularyFoodCandidate(
          canonicalFoodId: 'vegetable_fried_rice',
          canonicalName: 'Vegetable Fried Rice',
          category: 'Asian',
          similarity: 0.90,
          rank: 1,
        ),
      );
      final curryRes = resolver.resolveCandidate(
        const OpenVocabularyFoodCandidate(
          canonicalFoodId: 'vegetable_curry',
          canonicalName: 'Vegetable Curry',
          category: 'Indian',
          similarity: 0.85,
          rank: 1,
        ),
      );

      final frFood = friedRiceRes.matchedCatalogFood!;
      final curryFood = curryRes.matchedCatalogFood!;

      // 100g Fried Rice: 150.8 kcal, 320.1 mg Na
      expect(frFood.calories, 150.8);
      expect(frFood.sodium, 320.1);

      // 100g Curry: 73.17 kcal, 310.8 mg Na
      expect(curryFood.calories, closeTo(73.17, 0.01));
      expect(curryFood.sodium, 310.8);

      final candidates = [
        DetectedFoodCandidate(
          id: 'c1',
          detectedName: 'Vegetable Fried Rice',
          confidence: 0.90,
          estimatedAmount: 250.0, // 377.0 kcal, 800.25 mg Na
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: frFood,
          nutritionTier: friedRiceRes.tier,
          nutritionAttribution: friedRiceRes.attribution,
        ),
        DetectedFoodCandidate(
          id: 'c2',
          detectedName: 'Vegetable Curry',
          confidence: 0.85,
          estimatedAmount: 200.0, // 73.1666 * 2.0 = 146.33 kcal, 621.6 mg Na
          originalEstimatedAmount: 100.0,
          estimatedUnit: 'g',
          matchedFood: curryFood,
          nutritionTier: curryRes.tier,
          nutritionAttribution: curryRes.attribution,
        ),
      ];

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'scan_meal',
          foods: candidates,
          overallConfidence: 0.88,
          scannedAt: DateTime.now(),
        ),
        selectedMealType: 'Dinner',
      );

      final successState = controller.state as FoodScanSuccess;
      expect(successState.result.totalCalories, closeTo(377.0 + (curryFood.calories * 2.0), 0.05));
      expect(successState.result.totalSodium, closeTo(800.25 + 621.6, 0.01));

      await controller.logToDiary('user_combo', repository);
      final entries = await repository.getRecords('user_combo');
      expect(entries.length, 2);
      expect(entries[0].foodName, 'Vegetable Fried Rice');
      expect(entries[0].calories, closeTo(377.0, 0.01));
      expect(entries[1].foodName, 'Vegetable Curry');
      expect(entries[1].calories, closeTo(curryFood.calories * 2.0, 0.05));
    });

    test('Curated FitFuel Food Database item (Grilled Chicken Breast) workflow', () async {
      final chicken = PredefinedFoodData.foods
          .firstWhere((f) => f.id == 'predefined_grilled_chicken_breast')
          .toEntity();

      final candidate = DetectedFoodCandidate(
        id: 'chicken_cand',
        detectedName: chicken.name,
        confidence: 0.95,
        estimatedAmount: 150.0, // 1.5 * 165 = 247.5 kcal
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: chicken,
        nutritionTier: NutritionProfileTier.verifiedExact,
        nutritionAttribution: 'Curated FitFuel Food Database',
      );

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'scan_chicken',
          foods: [candidate],
          overallConfidence: 0.95,
          scannedAt: DateTime.now(),
        ),
        selectedMealType: 'Lunch',
      );

      final food = (controller.state as FoodScanSuccess).result.foods.first;
      expect(food.nutritionSourceLabel, 'Curated FitFuel Food Database');
      expect(food.scaledCalories, closeTo(247.5, 0.01));
      expect(food.scaledProtein, closeTo(46.5, 0.01));
      expect(food.scaledFats, closeTo(5.4, 0.01));
      expect(food.sodium, closeTo(111.0, 0.01));

      await controller.logToDiary('user_chicken', repository);
      final records = await repository.getRecords('user_chicken');
      expect(records.length, 1);
      expect(records.first.nutritionSourceLabel, 'Curated FitFuel Food Database');
      expect(records.first.calories, closeTo(247.5, 0.01));
    });
  });

  group('Phase 35.12.15: Nutrition Provenance, Fallback & Unsupported Food Safeguards', () {
    test('All trust labels produce expected human-readable strings across tiers', () {
      const exactCandidate = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Apple',
        confidence: 0.99,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );
      expect(exactCandidate.nutritionSourceLabel, 'Curated FitFuel Food Database');

      const usdaCandidate = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Burger',
        confidence: 0.85,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'USDA FoodData Central FDC 170694',
      );
      expect(usdaCandidate.nutritionSourceLabel, 'USDA Generic Baseline');

      const genericCandidate = DetectedFoodCandidate(
        id: 'c3',
        detectedName: 'Pita',
        confidence: 0.80,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.closelyRelatedGeneric,
        nutritionAttribution: 'Generic Nutrition Table',
      );
      expect(genericCandidate.nutritionSourceLabel, 'Generic Nutrition Baseline');

      const recipeCandidate = DetectedFoodCandidate(
        id: 'c4',
        detectedName: 'Alfredo',
        confidence: 0.88,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.recipeEstimate,
      );
      expect(recipeCandidate.nutritionSourceLabel, 'Recipe Estimate');

      const manualCandidate = DetectedFoodCandidate(
        id: 'c5',
        detectedName: 'Custom Smoothie',
        confidence: 1.0,
        estimatedAmount: 250.0,
        recognitionSource: FoodScanRecognitionSource.manual,
        matchedFood: FoodEntity(
          id: 'manual_smoothie',
          name: 'Custom Smoothie',
          category: 'Beverages',
          servingSize: 250.0,
          servingUnit: 'ml',
          calories: 220.0,
          protein: 8.0,
          carbohydrates: 38.0,
          fats: 4.0,
          fiber: 4.0,
          sugar: 26.0,
          sodium: 45.0,
          isCustom: true,
        ),
      );
      expect(manualCandidate.isUserEnteredNutrition, isTrue);
      expect(manualCandidate.nutritionSourceLabel, 'User-entered nutrition');

      const unavailCandidate = DetectedFoodCandidate(
        id: 'c6',
        detectedName: 'Unrecognized Dish',
        confidence: 0.50,
        estimatedAmount: 100.0,
        nutritionTier: NutritionProfileTier.unavailable,
      );
      expect(unavailCandidate.nutritionSourceLabel, 'Nutrition Unavailable');
    });

    test('Unsupported food retains null macros, blocks diary logging, and requires manual entry', () async {
      const unavailCandidate = DetectedFoodCandidate(
        id: 'c_unknown',
        detectedName: 'Space Alien Stew',
        confidence: 0.70,
        estimatedAmount: 100.0,
        matchedFood: null,
        aiEstimatedNutrition: null,
        nutritionTier: NutritionProfileTier.unavailable,
      );

      // Verify null macros and incomplete nutrition
      expect(unavailCandidate.calories, isNull);
      expect(unavailCandidate.protein, isNull);
      expect(unavailCandidate.carbs, isNull);
      expect(unavailCandidate.fats, isNull);
      expect(unavailCandidate.hasNutrition, isFalse);

      final scanResult = FoodScanResult(
        id: 'scan_unavail',
        foods: const [unavailCandidate],
        overallConfidence: 0.70,
        scannedAt: DateTime.now(),
      );

      expect(scanResult.hasIncompleteNutrition, isTrue);
      expect(scanResult.canBeLogged, isFalse);

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: scanResult,
        selectedMealType: 'Dinner',
      );

      // Attempting to log incomplete nutrition MUST return false and block write
      final logged = await controller.logToDiary('user_blocked', repository);
      expect(logged, isFalse);
      final records = await repository.getRecords('user_blocked');
      expect(records.isEmpty, isTrue);

      // User supplies manual nutrition entry
      const manualFood = FoodEntity(
        id: 'manual_alien_stew',
        name: 'Space Alien Stew (Homemade)',
        category: 'Soups',
        servingSize: 200.0,
        servingUnit: 'g',
        calories: 180.0,
        protein: 12.0,
        carbohydrates: 15.0,
        fats: 6.0,
        fiber: 3.0,
        sugar: 2.0,
        sodium: 400.0,
        isCustom: true,
      );

      controller.updateMatchedFood(0, manualFood);
      final updatedState = controller.state as FoodScanSuccess;
      final resolvedFood = updatedState.result.foods.first;

      expect(resolvedFood.hasNutrition, isTrue);
      expect(resolvedFood.isUserEnteredNutrition, isTrue);
      expect(resolvedFood.nutritionSourceLabel, 'User-entered nutrition');
      expect(updatedState.result.canBeLogged, isTrue);

      // Now logging succeeds
      final loggedAfterManual = await controller.logToDiary('user_blocked', repository);
      expect(loggedAfterManual, isTrue);

      final savedRecords = await repository.getRecords('user_blocked');
      expect(savedRecords.length, 1);
      expect(savedRecords.first.foodName, 'Space Alien Stew (Homemade)');
      expect(savedRecords.first.calories, 180.0);
      expect(savedRecords.first.nutritionSourceLabel, 'User-entered nutrition');
    });
  });

  group('Phase 35.12.15: Portion Scaling Constraints & Fractional Arithmetic', () {
    test('Portion scaling enforces bounds [5.0 g, 2500.0 g]', () {
      final food = PredefinedFoodData.foods.first.toEntity();
      final candidate = DetectedFoodCandidate(
        id: 'cand_limits',
        detectedName: food.name,
        confidence: 0.90,
        estimatedAmount: 100.0,
        matchedFood: food,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      // ignore: invalid_use_of_protected_member
      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'scan_limits',
          foods: [candidate],
          overallConfidence: 0.90,
          scannedAt: DateTime.now(),
        ),
        selectedMealType: 'Lunch',
      );

      // Clamp low (negative or zero)
      controller.updatePortion(0, -100.0);
      var state = controller.state as FoodScanSuccess;
      expect(state.result.foods.first.estimatedAmount, 5.0);

      controller.updatePortion(0, 0.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.first.estimatedAmount, 5.0);

      // Clamp high (> 2500g)
      controller.updatePortion(0, 5000.0);
      state = controller.state as FoodScanSuccess;
      expect(state.result.foods.first.estimatedAmount, 2500.0);
    });

    test('Fractional portion scaling (125.5 g) computes exact proportional values', () {
      const canonicalFood = FoodEntity(
        id: 'test_grain',
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

      const candidate = DetectedFoodCandidate(
        id: 'cand_fraction',
        detectedName: 'Quinoa',
        confidence: 0.95,
        estimatedAmount: 125.5,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: canonicalFood,
        nutritionTier: NutritionProfileTier.verifiedExact,
      );

      const factor = 125.5 / 100.0; // 1.255
      expect(candidate.scaledCalories, closeTo(120.0 * factor, 0.001));
      expect(candidate.scaledProtein, closeTo(4.4 * factor, 0.001));
      expect(candidate.scaledCarbs, closeTo(21.3 * factor, 0.001));
      expect(candidate.scaledFats, closeTo(1.9 * factor, 0.001));
      expect(candidate.fiber, closeTo(2.8 * factor, 0.001));
      expect(candidate.sugar, closeTo(0.9 * factor, 0.001));
      expect(candidate.sodium, closeTo(7.0 * factor, 0.001));
    });
  });

  group('Phase 35.12.15: Diary Persistence & User Account Isolation', () {
    test('User account isolation ensures private diaries cannot be read, modified, or inherited', () async {
      final now = DateTime.now();

      final recordA1 = NutritionRecordEntity(
        id: 'userA_entry_1',
        foodName: 'Oatmeal',
        mealType: 'Breakfast',
        calories: 250.0,
        protein: 8.0,
        carbohydrates: 45.0,
        fats: 4.0,
        sugar: 2.0,
        fiber: 5.0,
        sodium: 110.0,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final recordB1 = NutritionRecordEntity(
        id: 'userB_entry_1',
        foodName: 'Greek Yogurt',
        mealType: 'Snack',
        calories: 150.0,
        protein: 15.0,
        carbohydrates: 8.0,
        fats: 2.0,
        sugar: 6.0,
        fiber: 0.0,
        sodium: 50.0,
        servingSize: 150.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Save for User A and User B
      await repository.addRecord('user_A', recordA1);
      await repository.addRecord('user_B', recordB1);

      // User A reads only user A's entries
      final recordsA = await repository.getRecords('user_A');
      expect(recordsA.length, 1);
      expect(recordsA.first.id, 'userA_entry_1');
      expect(recordsA.first.foodName, 'Oatmeal');

      // User B reads only user B's entries
      final recordsB = await repository.getRecords('user_B');
      expect(recordsB.length, 1);
      expect(recordsB.first.id, 'userB_entry_1');
      expect(recordsB.first.foodName, 'Greek Yogurt');

      // User B attempts to delete User A's record using User B's context
      await repository.deleteRecord('user_B', 'userA_entry_1');

      // User A's record remains untouched
      final recordsAAfter = await repository.getRecords('user_A');
      expect(recordsAAfter.length, 1);
      expect(recordsAAfter.first.id, 'userA_entry_1');

      // User B attempts to update User A's record under User B's context
      final hijackedRecord = recordA1.copyWith(foodName: 'Tampered Oatmeal');
      await repository.updateRecord('user_B', hijackedRecord);

      // User A's record remains untouched
      final recordsAFinal = await repository.getRecords('user_A');
      expect(recordsAFinal.first.foodName, 'Oatmeal');

      // New user C gets 0 entries, inherits nothing
      final recordsC = await repository.getRecords('user_C_new');
      expect(recordsC.isEmpty, isTrue);
    });

    test('Delete operation updates diary persistence correctly', () async {
      final now = DateTime.now();
      final record = NutritionRecordEntity(
        id: 'del_test_1',
        foodName: 'Apple',
        mealType: 'Snack',
        calories: 52.0,
        protein: 0.3,
        carbohydrates: 14.0,
        fats: 0.2,
        sugar: 10.0,
        fiber: 2.4,
        sodium: 1.0,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addRecord('user_del', record);
      var records = await repository.getRecords('user_del');
      expect(records.length, 1);

      await repository.deleteRecord('user_del', 'del_test_1');
      records = await repository.getRecords('user_del');
      expect(records.isEmpty, isTrue);
    });
  });
}
