import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';

class FoodScanController extends StateNotifier<FoodScanState> {
  final IFoodScanRepository _repository;
  final IFoodImagePickerService _imagePickerService;

  String? _retainedImagePath;
  Uint8List? _retainedImageBytes;
  List<FoodEntity> _cachedCatalog = const [];
  String _selectedMealType = defaultMealType();

  FoodScanController({
    required IFoodScanRepository repository,
    required IFoodImagePickerService imagePickerService,
  })  : _repository = repository,
        _imagePickerService = imagePickerService,
        super(const FoodScanIdle());

  /// Default meal type determined by local time of day.
  static String defaultMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 16) return 'Lunch';
    if (hour < 19) return 'Snack';
    return 'Dinner';
  }

  /// Retained image path for retry operations without retaking photos.
  String? get retainedImagePath => _retainedImagePath;

  /// Retained image bytes for retry operations without re-reading disks.
  Uint8List? get retainedImageBytes => _retainedImageBytes;

  /// Current meal type target.
  String get selectedMealType => _selectedMealType;

  /// Initiates image acquisition (camera or gallery) and AI analysis.
  Future<void> pickAndScan(
    FoodImagePickSource source, {
    List<FoodEntity> catalog = const [],
  }) async {
    if (state is FoodScanAnalyzing || state is FoodScanLogging) {
      return; // Prevent double invocation
    }

    try {
      final imagePath = await _imagePickerService.pickImage(source);
      if (imagePath == null) {
        // User cancelled picker; keep idle or prior state
        return;
      }

      _retainedImagePath = imagePath;
      _cachedCatalog = catalog;

      state = FoodScanAnalyzing(
        imagePath: imagePath,
        stageMessage: 'Analyzing your meal...',
      );

      final bytes = await _imagePickerService.getImageBytes(imagePath);
      if (bytes == null || bytes.isEmpty) {
        state = FoodScanError(
          title: FoodScanErrorCopy.imageQualityTitle,
          message: FoodScanErrorCopy.imageQualityMessage,
          failureType: FoodScanFailureType.invalidImage,
          imagePath: imagePath,
        );
        return;
      }

      _retainedImageBytes = bytes;

      await scanImageBytes(
        imagePath: imagePath,
        imageBytes: bytes,
        catalog: catalog,
      );
    } catch (e, stackTrace) {
      LoggerService.error('FoodScanController error during pickAndScan', e, stackTrace);
      if (e is FoodScanFailure) {
        state = FoodScanError(
          title: e.title,
          message: e.message,
          failureType: e.type,
          imagePath: _retainedImagePath,
          imageBytes: _retainedImageBytes,
          retryAfterSeconds: e.retryAfterSeconds,
        );
      } else {
        state = FoodScanError(
          title: FoodScanErrorCopy.unknownTitle,
          message: e is Failure ? e.message : FoodScanErrorCopy.unknownMessage,
          imagePath: _retainedImagePath,
          imageBytes: _retainedImageBytes,
        );
      }
    }
  }

  /// Directly analyzes raw image bytes (used by test suites & picked images).
  Future<void> scanImageBytes({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> catalog = const [],
  }) async {
    _retainedImagePath = imagePath;
    _retainedImageBytes = imageBytes;
    _cachedCatalog = catalog;

    state = FoodScanAnalyzing(
      imagePath: imagePath,
      stageMessage: 'Identifying foods and estimating portions...',
    );

    try {
      final result = await _repository.scanFoodImage(
        imagePath: imagePath,
        imageBytes: imageBytes,
        foodCatalog: catalog,
      );

      if (result.isEmpty) {
        state = FoodScanNoFoodDetected(imagePath: imagePath);
      } else {
        _selectedMealType = defaultMealType();
        state = FoodScanSuccess(
          result: result,
          selectedMealType: _selectedMealType,
        );
      }
    } on FoodScanFailure catch (e) {
      state = FoodScanError(
        title: e.title,
        message: e.message,
        failureType: e.type,
        imagePath: imagePath,
        imageBytes: imageBytes,
        retryAfterSeconds: e.retryAfterSeconds,
      );
    } on Failure catch (e) {
      state = FoodScanError(
        title: FoodScanErrorCopy.unknownTitle,
        message: e.message,
        failureType: FoodScanFailureType.unknownServiceFailure,
        imagePath: imagePath,
        imageBytes: imageBytes,
      );
    } catch (e, stackTrace) {
      LoggerService.error('FoodScanController error analyzing image', e, stackTrace);
      state = FoodScanError(
        title: FoodScanErrorCopy.offlineTitle,
        message: FoodScanErrorCopy.offlineMessage,
        failureType: FoodScanFailureType.offline,
        imagePath: imagePath,
        imageBytes: imageBytes,
      );
    }
  }

  /// Retries scanning with the retained image without reopening camera or picker.
  Future<void> retryScan() async {
    if (state is FoodScanAnalyzing || state is FoodScanLogging) return;
    if (_retainedImagePath == null || _retainedImageBytes == null) {
      state = const FoodScanIdle();
      return;
    }

    await scanImageBytes(
      imagePath: _retainedImagePath!,
      imageBytes: _retainedImageBytes!,
      catalog: _cachedCatalog,
    );
  }

  /// Adjusts the estimated portion size for a candidate at [index].
  void updatePortion(int index, double newAmount) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    final existing = updatedFoods[index];
    updatedFoods[index] = existing.copyWith(
      estimatedAmount: newAmount.clamp(5.0, 2500.0),
    );

    state = current.copyWith(
      result: current.result.copyWith(foods: updatedFoods),
    );
  }

  /// Replaces or assigns a FitFuel database [FoodEntity] to a candidate at [index].
  void updateMatchedFood(int index, FoodEntity newFood) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    final existing = updatedFoods[index];
    updatedFoods[index] = existing.copyWith(
      matchedFood: newFood,
      matchConfidence: 1.0,
    );

    state = current.copyWith(
      result: current.result.copyWith(foods: updatedFoods),
    );
  }

  /// Removes a detected food component at [index].
  void removeComponent(int index) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    updatedFoods.removeAt(index);

    if (updatedFoods.isEmpty) {
      state = FoodScanNoFoodDetected(imagePath: current.result.imagePath);
    } else {
      state = current.copyWith(
        result: current.result.copyWith(foods: updatedFoods),
      );
    }
  }

  /// Adds an extra food item from the database to the current scan result.
  void addComponent(FoodEntity food, {double amount = 100.0}) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;

    final newCandidate = DetectedFoodCandidate(
      id: 'added_${DateTime.now().millisecondsSinceEpoch}',
      detectedName: food.name,
      confidence: 1.0,
      estimatedAmount: amount,
      estimatedUnit: food.servingUnit,
      matchedFood: food,
      matchConfidence: 1.0,
    );

    final updatedFoods = [...current.result.foods, newCandidate];
    state = current.copyWith(
      result: current.result.copyWith(foods: updatedFoods),
    );
  }

  /// Changes the targeted meal slot (Breakfast / Lunch / Dinner / Snack).
  void selectMealType(String mealType) {
    _selectedMealType = mealType;
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    state = current.copyWith(selectedMealType: mealType);
  }

  /// Adds all confirmed detected foods to the Food Diary.
  /// Requires all items to have valid nutrition (incomplete items must be resolved first).
  Future<bool> logToDiary(String uid, INutritionRepository nutritionRepo) async {
    if (state is! FoodScanSuccess) return false;
    final current = state as FoodScanSuccess;
    final confirmedFoods = current.result.foods;

    if (confirmedFoods.isEmpty) return false;

    // Safety rule: Never log foods with incomplete nutrition
    if (current.result.hasIncompleteNutrition) {
      return false;
    }

    state = FoodScanLogging(
      result: current.result,
      selectedMealType: current.selectedMealType,
    );

    try {
      final now = DateTime.now();
      for (var i = 0; i < confirmedFoods.length; i++) {
        final item = confirmedFoods[i];
        final record = NutritionRecordEntity(
          id: 'scan_${now.millisecondsSinceEpoch}_$i',
          foodName: item.displayName,
          mealType: current.selectedMealType,
          calories: item.scaledCalories,
          protein: item.scaledProtein,
          carbohydrates: item.scaledCarbs,
          fats: item.scaledFats,
          sugar: 0.0,
          servingSize: item.estimatedAmount,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await nutritionRepo.addRecord(uid, record);
      }

      state = FoodScanLogged(
        itemsLoggedCount: confirmedFoods.length,
        totalCalories: current.result.totalCalories,
        mealType: current.selectedMealType,
      );
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('FoodScanController error logging to diary', e, stackTrace);
      state = FoodScanError(
        title: FoodScanErrorCopy.unknownTitle,
        message: 'Failed to add meal to Food Diary. Please try again.',
        imagePath: current.result.imagePath,
        imageBytes: _retainedImageBytes,
      );
      return false;
    }
  }

  /// Resets back to idle state and clears retained image.
  void reset() {
    _retainedImagePath = null;
    _retainedImageBytes = null;
    state = const FoodScanIdle();
  }
}
