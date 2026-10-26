/// Internal ranking bands for local Top-K suggestions.
/// Used strictly as internal ranking hints without exposing misleading accuracy percentages.
enum SuggestionConfidenceBand {
  /// Confidence >= 0.60
  strong,

  /// Confidence >= 0.30 and < 0.60
  moderate,

  /// Confidence >= minimumSuggestionConfidence and < 0.30
  weak,

  /// Below minimumSuggestionConfidence threshold
  belowMinimum,
}

/// Represents a single candidate classification returned by the on-device food vision model.
class LocalFoodCandidate {
  final String foodId;
  final String foodName;
  final double confidence;

  const LocalFoodCandidate({
    required this.foodId,
    String? foodName,
    String? label,
    required this.confidence,
  }) : foodName = foodName ?? label ?? '';

  /// Backward-compatible alias for [foodName].
  String get label => foodName;

  /// Classifies suggestion strength internally without exposing raw percentage claims.
  SuggestionConfidenceBand confidenceBand({
    double minimumSuggestionConfidence = 0.15,
  }) {
    if (confidence >= 0.60) return SuggestionConfidenceBand.strong;
    if (confidence >= 0.30) return SuggestionConfidenceBand.moderate;
    if (confidence >= minimumSuggestionConfidence) {
      return SuggestionConfidenceBand.weak;
    }
    return SuggestionConfidenceBand.belowMinimum;
  }

  LocalFoodCandidate copyWith({
    String? foodId,
    String? foodName,
    double? confidence,
  }) {
    return LocalFoodCandidate(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'food_id': foodId,
        'food_name': foodName,
        'label': foodName,
        'confidence': confidence,
      };

  @override
  String toString() =>
      '$foodName ($foodId) [${(confidence * 100).toStringAsFixed(1)}%]';
}

/// Aggregated prediction from the local on-device food classifier.
/// Does NOT contain nutritional values (nutrition is always database-first).
class LocalFoodPrediction {
  final String foodId;
  final String foodName;
  final double confidence;
  final List<LocalFoodCandidate> topCandidates;
  final int inferenceDurationMs;
  final bool isModelAvailable;
  final String? failureReason;
  final bool isMixedMealSuspected;

  const LocalFoodPrediction({
    required this.foodId,
    required this.foodName,
    required this.confidence,
    this.topCandidates = const [],
    this.inferenceDurationMs = 0,
    this.isModelAvailable = true,
    this.failureReason,
    this.isMixedMealSuspected = false,
  });

  /// Top-1 candidate from the classifier output.
  LocalFoodCandidate? get top1 {
    if (topCandidates.isNotEmpty) {
      return topCandidates.first;
    }
    if (foodId.isNotEmpty) {
      return LocalFoodCandidate(
        foodId: foodId,
        foodName: foodName,
        confidence: confidence,
      );
    }
    return null;
  }

  /// Factory when the local model artifact is absent or unsupported.
  factory LocalFoodPrediction.unavailable({String? reason}) {
    return LocalFoodPrediction(
      foodId: '',
      foodName: '',
      confidence: 0.0,
      topCandidates: const [],
      inferenceDurationMs: 0,
      isModelAvailable: false,
      failureReason: reason ?? 'On-device classifier model is unavailable.',
    );
  }

  /// Empty prediction when no food features could be determined.
  factory LocalFoodPrediction.empty() {
    return const LocalFoodPrediction(
      foodId: '',
      foodName: '',
      confidence: 0.0,
      topCandidates: [],
      inferenceDurationMs: 0,
      isModelAvailable: true,
    );
  }

  /// Confidence gap between candidate 1 and candidate 2.
  double get confidenceMargin {
    if (topCandidates.length >= 2) {
      return topCandidates[0].confidence - topCandidates[1].confidence;
    }
    return topCandidates.isNotEmpty ? topCandidates[0].confidence : confidence;
  }

  /// True if prediction meets or exceeds the required confidence threshold and margin.
  bool isConfident({
    double threshold = 0.80,
    double minMargin = 0.10,
  }) {
    if (!isModelAvailable || foodId.isEmpty || isMixedMealSuspected) {
      return false;
    }
    if (confidence < threshold) return false;
    if (topCandidates.length >= 2 && confidenceMargin < minMargin) return false;
    return true;
  }

  /// True if top predictions are too close together to decide safely.
  bool isAmbiguous({double minMargin = 0.10}) {
    if (!isModelAvailable || topCandidates.length < 2) return false;
    return confidenceMargin < minMargin;
  }

  @override
  String toString() =>
      'LocalFoodPrediction(foodId: $foodId, name: $foodName, '
      'conf: ${(confidence * 100).toStringAsFixed(1)}%, '
      'margin: ${(confidenceMargin * 100).toStringAsFixed(1)}%, '
      'available: $isModelAvailable, '
      'mixedMeal: $isMixedMealSuspected, '
      'duration: ${inferenceDurationMs}ms)';
}
