import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_route_decision.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
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
    this.stageMessage = 'Scanning on your device...',
  });
}

/// Phase 35.10 / 35.11B / 35.11B.1 Free-First assistance state:
/// Displays Tier-2 open-vocabulary results using Smart Single-Result UX
/// (`singlePrimary`, `primaryWithAlternatives`, or `ambiguousTop3`),
/// Tier-1 local suggestions (`suggestions`), non-food abstention guidance,
/// mixed-meal guidance, manual catalog search, and optional "Analyze with AI".
class FoodScanSuggestions extends FoodScanState {
  final String? imagePath;
  final Uint8List? imageBytes;
  final List<LocalFoodCandidate> suggestions;
  final List<OpenVocabularyFoodCandidate> openVocabSuggestions;
  final OpenVocabPresentationDecision? openVocabPresentation;
  final bool isOtherMatchesExpanded;
  final LocalFoodPrediction? prediction;
  final FoodScanRouteDecision? routeDecision;
  final bool isMixedMealSuspected;
  final bool isNonFoodAbstained;
  final bool isOffline;
  final bool isLocalModelUnavailable;
  final FoodScanFailure? aiFailure;
  final String selectedMealType;

  const FoodScanSuggestions({
    this.imagePath,
    this.imageBytes,
    this.suggestions = const [],
    this.openVocabSuggestions = const [],
    this.openVocabPresentation,
    this.isOtherMatchesExpanded = false,
    this.prediction,
    this.routeDecision,
    this.isMixedMealSuspected = false,
    this.isNonFoodAbstained = false,
    this.isOffline = false,
    this.isLocalModelUnavailable = false,
    this.aiFailure,
    this.selectedMealType = 'Lunch',
  });

  bool get hasOpenVocabSuggestions => openVocabSuggestions.isNotEmpty;

  bool get hasSuggestions =>
      suggestions.isNotEmpty || openVocabSuggestions.isNotEmpty;

  OpenVocabPresentationMode get effectiveOpenVocabMode =>
      openVocabPresentation?.mode ?? OpenVocabPresentationMode.ambiguousTop3;

  bool get isSinglePrimaryOpenVocab =>
      openVocabSuggestions.isNotEmpty &&
      effectiveOpenVocabMode == OpenVocabPresentationMode.singlePrimary;

  bool get isPrimaryWithAlternativesOpenVocab =>
      openVocabSuggestions.isNotEmpty &&
      effectiveOpenVocabMode ==
          OpenVocabPresentationMode.primaryWithAlternatives;

  bool get isSingleResultOpenVocabUx =>
      isSinglePrimaryOpenVocab || isPrimaryWithAlternativesOpenVocab;

  OpenVocabularyFoodCandidate? get primaryOpenVocabCandidate =>
      openVocabPresentation?.primaryCandidate ??
      (openVocabSuggestions.isNotEmpty ? openVocabSuggestions.first : null);

  List<OpenVocabularyFoodCandidate> get alternativeOpenVocabCandidates =>
      openVocabPresentation?.alternativeCandidates ??
      (openVocabSuggestions.length > 1
          ? openVocabSuggestions.sublist(1)
          : const []);

  bool get hasAiFailure => aiFailure != null;

  bool get isQuotaExhausted =>
      aiFailure?.type == FoodScanFailureType.dailyQuotaReached;

  bool get canRetryAi => !isOffline && !isQuotaExhausted && aiFailure != null;

  bool get canRequestAi => !isOffline && !isQuotaExhausted;

  /// True when the candidate or prediction is uncertain, low-confidence, or ambiguous.
  bool get isUncertainMatch {
    if (isNonFoodAbstained || isLocalModelUnavailable) return false;
    if (effectiveOpenVocabMode == OpenVocabPresentationMode.ambiguousTop3) {
      return true;
    }
    if (routeDecision is Tier2OpenVocabSuggestionsAvailable) return true;
    if (routeDecision is LocalSuggestionsAvailable) return true;
    return false;
  }

  /// True when no confident food was detected (e.g. complex meal or low confidence), but image is NOT classified as non-food.
  bool get isUncertainFoodMatch =>
      !isNonFoodAbstained &&
      !isLocalModelUnavailable &&
      !isMixedMealSuspected &&
      suggestions.isEmpty &&
      openVocabSuggestions.isEmpty;

  FoodScanSuggestions copyWith({
    String? imagePath,
    Uint8List? imageBytes,
    List<LocalFoodCandidate>? suggestions,
    List<OpenVocabularyFoodCandidate>? openVocabSuggestions,
    OpenVocabPresentationDecision? openVocabPresentation,
    bool? isOtherMatchesExpanded,
    LocalFoodPrediction? prediction,
    FoodScanRouteDecision? routeDecision,
    bool? isMixedMealSuspected,
    bool? isNonFoodAbstained,
    bool? isOffline,
    bool? isLocalModelUnavailable,
    FoodScanFailure? aiFailure,
    bool clearAiFailure = false,
    String? selectedMealType,
  }) {
    return FoodScanSuggestions(
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      suggestions: suggestions ?? this.suggestions,
      openVocabSuggestions: openVocabSuggestions ?? this.openVocabSuggestions,
      openVocabPresentation:
          openVocabPresentation ?? this.openVocabPresentation,
      isOtherMatchesExpanded:
          isOtherMatchesExpanded ?? this.isOtherMatchesExpanded,
      prediction: prediction ?? this.prediction,
      routeDecision: routeDecision ?? this.routeDecision,
      isMixedMealSuspected: isMixedMealSuspected ?? this.isMixedMealSuspected,
      isNonFoodAbstained: isNonFoodAbstained ?? this.isNonFoodAbstained,
      isOffline: isOffline ?? this.isOffline,
      isLocalModelUnavailable:
          isLocalModelUnavailable ?? this.isLocalModelUnavailable,
      aiFailure: clearAiFailure ? null : (aiFailure ?? this.aiFailure),
      selectedMealType: selectedMealType ?? this.selectedMealType,
    );
  }
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

enum NoFoodReason {
  nonFood,
  uncertainMatch,
  nutritionMissing,
  invalidImage,
  modelUnavailable,
  emptyResult,
}

class FoodScanNoFoodDetected extends FoodScanState {
  final String? imagePath;
  final NoFoodReason reason;
  final String? customMessage;

  const FoodScanNoFoodDetected({
    this.imagePath,
    this.reason = NoFoodReason.nonFood,
    this.customMessage,
  });
}

class FoodScanError extends FoodScanState {
  final String title;
  final String message;
  final FoodScanFailureType failureType;
  final String? imagePath;
  final Uint8List? imageBytes;
  final int? retryAfterSeconds;
  final List<LocalFoodCandidate> localSuggestions;

  const FoodScanError({
    String? title,
    required this.message,
    this.failureType = FoodScanFailureType.unknownServiceFailure,
    this.imagePath,
    this.imageBytes,
    this.retryAfterSeconds,
    this.localSuggestions = const [],
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
