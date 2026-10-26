import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';

/// Test and mock implementation of [FoodVisionClassifier]
/// for deterministic testing of hybrid confidence routing, offline scans, and quota avoidance.
class FakeFoodVisionClassifier implements FoodVisionClassifier {
  LocalFoodPrediction? predeterminedPrediction;
  bool simulateAvailable;
  int classifyCallCount = 0;
  int delayMs;

  FakeFoodVisionClassifier({
    this.predeterminedPrediction,
    this.simulateAvailable = true,
    this.delayMs = 0,
  });

  @override
  bool get isAvailable => simulateAvailable;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    classifyCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (!simulateAvailable) {
      return LocalFoodPrediction.unavailable(
        reason: 'Simulated unavailable local model artifact.',
      );
    }

    return predeterminedPrediction ??
        const LocalFoodPrediction(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.95,
          topCandidates: [
            LocalFoodCandidate(foodId: 'predefined_idli', label: 'Idli', confidence: 0.95),
            LocalFoodCandidate(foodId: 'predefined_dosa', label: 'Plain Dosa', confidence: 0.03),
            LocalFoodCandidate(foodId: 'predefined_upma', label: 'Upma', confidence: 0.02),
          ],
          inferenceDurationMs: 12,
        );
  }

  /// Convenience setter for simulating high-confidence recognition.
  void setHighConfidenceMatch({
    required String foodId,
    required String foodName,
    double confidence = 0.94,
  }) {
    simulateAvailable = true;
    predeterminedPrediction = LocalFoodPrediction(
      foodId: foodId,
      foodName: foodName,
      confidence: confidence,
      topCandidates: [
        LocalFoodCandidate(foodId: foodId, label: foodName, confidence: confidence),
        LocalFoodCandidate(foodId: 'predefined_banana', label: 'Banana', confidence: (1.0 - confidence) * 0.7),
        LocalFoodCandidate(foodId: 'predefined_orange', label: 'Orange', confidence: (1.0 - confidence) * 0.3),
      ],
      inferenceDurationMs: 14,
    );
  }

  /// Convenience setter for simulating low-confidence recognition.
  void setLowConfidenceMatch({
    required String foodId,
    required String foodName,
    double confidence = 0.43,
  }) {
    simulateAvailable = true;
    predeterminedPrediction = LocalFoodPrediction(
      foodId: foodId,
      foodName: foodName,
      confidence: confidence,
      topCandidates: [
        LocalFoodCandidate(foodId: foodId, label: foodName, confidence: confidence),
        const LocalFoodCandidate(foodId: 'predefined_dosa', label: 'Plain Dosa', confidence: 0.35),
        const LocalFoodCandidate(foodId: 'predefined_upma', label: 'Upma', confidence: 0.22),
      ],
      inferenceDurationMs: 16,
    );
  }

  /// Convenience setter for simulating ambiguous predictions (margin < 0.10).
  void setAmbiguousMatch({
    required String foodId1,
    required String foodName1,
    required double confidence1,
    required String foodId2,
    required String foodName2,
    required double confidence2,
  }) {
    simulateAvailable = true;
    predeterminedPrediction = LocalFoodPrediction(
      foodId: foodId1,
      foodName: foodName1,
      confidence: confidence1,
      topCandidates: [
        LocalFoodCandidate(foodId: foodId1, label: foodName1, confidence: confidence1),
        LocalFoodCandidate(foodId: foodId2, label: foodName2, confidence: confidence2),
      ],
      inferenceDurationMs: 15,
    );
  }

  /// Convenience setter for model unavailable state.
  void setModelUnavailable() {
    simulateAvailable = false;
    predeterminedPrediction = LocalFoodPrediction.unavailable();
  }

  /// Convenience setter for Phase 35.10 Top-K suggestion mode.
  void setTopKSuggestions(
    List<LocalFoodCandidate> candidates, {
    bool isMixedMealSuspected = false,
  }) {
    simulateAvailable = true;
    final top = candidates.isNotEmpty ? candidates.first : null;
    predeterminedPrediction = LocalFoodPrediction(
      foodId: top?.foodId ?? '',
      foodName: top?.foodName ?? '',
      confidence: top?.confidence ?? 0.0,
      topCandidates: candidates,
      inferenceDurationMs: 14,
      isModelAvailable: true,
      isMixedMealSuspected: isMixedMealSuspected,
    );
  }

  /// Convenience setter for suspected mixed-meal plates.
  void setMixedMealSuspected({
    List<LocalFoodCandidate>? candidates,
  }) {
    simulateAvailable = true;
    final list = candidates ??
        const [
          LocalFoodCandidate(
            foodId: 'predefined_steamed_rice',
            foodName: 'Steamed White Rice',
            confidence: 0.42,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_dal_tadka',
            foodName: 'Dal Tadka',
            confidence: 0.38,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_chapati',
            foodName: 'Chapati / Roti',
            confidence: 0.20,
          ),
        ];
    setTopKSuggestions(list, isMixedMealSuspected: true);
  }

  /// Convenience setter simulating all 50 predictions below minimumSuggestionConfidence.
  void setBelowMinimumSuggestions({double maxConfidence = 0.08}) {
    simulateAvailable = true;
    predeterminedPrediction = LocalFoodPrediction(
      foodId: 'predefined_potato',
      foodName: 'Potato',
      confidence: maxConfidence,
      topCandidates: [
        LocalFoodCandidate(
          foodId: 'predefined_potato',
          foodName: 'Potato',
          confidence: maxConfidence,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_onion',
          foodName: 'Onion',
          confidence: maxConfidence * 0.8,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_tomato',
          foodName: 'Tomato',
          confidence: maxConfidence * 0.5,
        ),
      ],
      inferenceDurationMs: 12,
      isModelAvailable: true,
    );
  }

  @override
  void dispose() {}
}
