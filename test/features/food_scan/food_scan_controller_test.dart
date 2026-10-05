import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';

class _FakeFoodImagePickerService implements IFoodImagePickerService {
  String? nextPath = '/tmp/meal_photo.jpg';
  Uint8List? nextBytes = Uint8List.fromList([1, 2, 3, 4]);

  @override
  Future<String?> pickImage(FoodImagePickSource source) async => nextPath;

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async => nextBytes;
}

class _FakeFoodScanRepository implements IFoodScanRepository {
  FoodScanResult? nextResult;
  Exception? errorToThrow;

  @override
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
  }) async {
    if (errorToThrow != null) {
      throw const ServerFailure('AI vision service unavailable');
    }
    return nextResult ??
        FoodScanResult(
          id: 'test_scan_1',
          imagePath: imagePath,
          foods: const [
            DetectedFoodCandidate(
              id: 'c1',
              detectedName: 'Basmati Rice',
              confidence: 0.95,
              estimatedAmount: 150.0,
              matchedFood: FoodEntity(
                id: 'food_rice',
                name: 'Basmati Rice',
                category: 'Grains',
                servingSize: 100.0,
                servingUnit: 'g',
                calories: 130.0,
                protein: 2.7,
                carbohydrates: 28.0,
                fats: 0.3,
                fiber: 0.4,
                sugar: 0.1,
                sodium: 1.0,
              ),
            ),
          ],
          overallConfidence: 0.95,
          scannedAt: DateTime.now(),
        );
  }
}

class _FakeNutritionRepository extends Fake implements INutritionRepository {
  final List<NutritionRecordEntity> loggedRecords = [];

  @override
  Future<void> addRecord(String uid, NutritionRecordEntity record) async {
    loggedRecords.add(record);
  }

  @override
  Stream<List<NutritionRecordEntity>> streamRecords(String uid) =>
      Stream.value(loggedRecords);
}

void main() {
  late _FakeFoodImagePickerService pickerService;
  late _FakeFoodScanRepository scanRepo;
  late FoodScanController controller;
  late _FakeNutritionRepository nutritionRepo;

  setUp(() {
    pickerService = _FakeFoodImagePickerService();
    scanRepo = _FakeFoodScanRepository();
    controller = FoodScanController(
      repository: scanRepo,
      imagePickerService: pickerService,
    );
    nutritionRepo = _FakeNutritionRepository();
  });

  group('Phase 35.5 — FoodScanController State Transitions', () {
    test('1. Starts in FoodScanIdle state', () {
      expect(controller.state, isA<FoodScanIdle>());
    });

    test('2. Handles picker cancellation gracefully by keeping state', () async {
      pickerService.nextPath = null;
      await controller.pickAndScan(FoodImagePickSource.camera);
      expect(controller.state, isA<FoodScanIdle>());
    });

    test('3. Successfully scans image and transitions to FoodScanSuccess', () async {
      await controller.pickAndScan(FoodImagePickSource.gallery);
      expect(controller.state, isA<FoodScanSuccess>());
      final successState = controller.state as FoodScanSuccess;
      expect(successState.result.foods.length, 1);
      expect(successState.result.foods.first.detectedName, 'Basmati Rice');
      expect(successState.result.totalCalories, closeTo(195.0, 0.01)); // 130 * 1.5 = 195
    });

    test('4. Adjusts portion size and updates scaled calories', () async {
      await controller.pickAndScan(FoodImagePickSource.camera);
      expect(controller.state, isA<FoodScanSuccess>());

      // Update portion to 200g (2x 100g serving -> 260 kcal)
      controller.updatePortion(0, 200.0);
      final updated = controller.state as FoodScanSuccess;
      expect(updated.result.foods.first.estimatedAmount, 200.0);
      expect(updated.result.totalCalories, closeTo(260.0, 0.01));
    });

    test('5. Replaces matched food with new database entity', () async {
      await controller.pickAndScan(FoodImagePickSource.camera);

      const chicken = FoodEntity(
        id: 'food_chicken',
        name: 'Grilled Chicken Breast',
        category: 'Meat',
        servingSize: 100.0,
        servingUnit: 'g',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
        fiber: 0.0,
        sugar: 0.0,
        sodium: 74.0,
      );

      controller.updateMatchedFood(0, chicken);
      final updated = controller.state as FoodScanSuccess;
      expect(updated.result.foods.first.matchedFood?.name, 'Grilled Chicken Breast');
      expect(updated.result.foods.first.displayName, 'Grilled Chicken Breast');
    });

    test('6. Removes a food component and transitions to NoFood if empty', () async {
      await controller.pickAndScan(FoodImagePickSource.camera);
      controller.removeComponent(0);
      expect(controller.state, isA<FoodScanNoFoodDetected>());
    });

    test('7. Adds an extra food component and updates meal total', () async {
      await controller.pickAndScan(FoodImagePickSource.camera);

      const salad = FoodEntity(
        id: 'food_salad',
        name: 'Green Salad',
        category: 'Vegetables',
        servingSize: 100.0,
        servingUnit: 'g',
        calories: 25.0,
        protein: 1.0,
        carbohydrates: 4.0,
        fats: 0.5,
        fiber: 2.0,
        sugar: 1.0,
        sodium: 10.0,
      );

      controller.addComponent(salad, amount: 100.0);
      final updated = controller.state as FoodScanSuccess;
      expect(updated.result.foods.length, 2);
      expect(updated.result.totalCalories, closeTo(220.0, 0.01)); // 195 + 25 = 220
    });

    test('8. Logs confirmed meal to food diary and emits FoodScanLogged', () async {
      await controller.pickAndScan(FoodImagePickSource.camera);
      controller.selectMealType('Dinner');

      final success = await controller.logToDiary('user_123', nutritionRepo);
      expect(success, isTrue);
      expect(controller.state, isA<FoodScanLogged>());
      expect(nutritionRepo.loggedRecords.length, 1);
      expect(nutritionRepo.loggedRecords.first.foodName, 'Basmati Rice');
      expect(nutritionRepo.loggedRecords.first.mealType, 'Dinner');
      expect(nutritionRepo.loggedRecords.first.calories, closeTo(195.0, 0.01));
    });

    test('9. Handles AI vision error by emitting FoodScanError', () async {
      scanRepo.errorToThrow = Exception('Network timeout');
      await controller.pickAndScan(FoodImagePickSource.camera);
      expect(controller.state, isA<FoodScanError>());
    });
  });
}
