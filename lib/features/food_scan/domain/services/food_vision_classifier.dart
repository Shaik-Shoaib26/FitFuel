import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';

/// Contract for on-device food vision classifier implementations.
abstract interface class FoodVisionClassifier {
  /// Classifies preprocessed food image bytes on-device.
  /// Returns top food candidates and confidence scores.
  /// Never throws fatal exceptions; returns [LocalFoodPrediction.unavailable] on failure.
  Future<LocalFoodPrediction> classify(Uint8List imageBytes);

  /// True if the local model artifact and labels are loaded and ready for inference.
  bool get isAvailable;

  /// Disposes interpreter instances and frees native tensor buffers.
  void dispose();
}
