import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';

abstract class FoodScanState {
  const FoodScanState();
}

class FoodScanIdle extends FoodScanState {
  const FoodScanIdle();
}

class FoodScanAnalyzing extends FoodScanState {
  final String? imagePath;
  final String stageMessage;
  const FoodScanAnalyzing({
    this.imagePath,
    this.stageMessage = 'Analyzing your meal...',
  });
}

class FoodScanSuccess extends FoodScanState {
  final FoodScanResult result;
  final String selectedMealType; // 'Breakfast', 'Lunch', 'Dinner', 'Snack'

  const FoodScanSuccess({
    required this.result,
    this.selectedMealType = 'Lunch',
  });

  FoodScanSuccess copyWith({
    FoodScanResult? result,
    String? selectedMealType,
  }) {
    return FoodScanSuccess(
      result: result ?? this.result,
      selectedMealType: selectedMealType ?? this.selectedMealType,
    );
  }
}

class FoodScanNoFoodDetected extends FoodScanState {
  final String? imagePath;
  const FoodScanNoFoodDetected({this.imagePath});
}


class FoodScanError extends FoodScanState {
  final String title;
  final String message;
  final FoodScanFailureType failureType;
  final String? imagePath;
  final Uint8List? imageBytes;
  final int? retryAfterSeconds;

  const FoodScanError({
    String? title,
    required this.message,
    this.failureType = FoodScanFailureType.unknownServiceFailure,
    this.imagePath,
    this.imageBytes,
    this.retryAfterSeconds,
  }) : title = title ?? FoodScanErrorCopy.unknownTitle;

  bool get isRetryable =>
      failureType == FoodScanFailureType.rateLimited ||
      failureType == FoodScanFailureType.serviceUnavailable ||
      failureType == FoodScanFailureType.timeout ||
      failureType == FoodScanFailureType.offline ||
      imageBytes != null;
}

class FoodScanLogging extends FoodScanState {
  final FoodScanResult result;
  final String selectedMealType;
  const FoodScanLogging({required this.result, required this.selectedMealType});
}

class FoodScanLogged extends FoodScanState {
  final int itemsLoggedCount;
  final double totalCalories;
  final String mealType;
  const FoodScanLogged({
    required this.itemsLoggedCount,
    required this.totalCalories,
    required this.mealType,
  });
}
