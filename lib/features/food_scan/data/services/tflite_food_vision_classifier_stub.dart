import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';

/// Web and stub implementation of [FoodVisionClassifier].
/// TFLite mobile native inference is unavailable in browser environments;
/// seamlessly delegates recognition to the Gemini cloud fallback pathway.
class TfliteFoodVisionClassifier implements FoodVisionClassifier {
  final String modelPath;
  final String labelsPath;

  TfliteFoodVisionClassifier({
    this.modelPath = 'assets/ml/fitfuel_food_classifier.tflite',
    this.labelsPath = 'assets/ml/fitfuel_food_labels.txt',
  });

  @override
  bool get isAvailable => false;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    return LocalFoodPrediction.unavailable(
      reason: 'On-device TFLite inference is not supported on this platform.',
    );
  }

  @override
  void dispose() {}
}
