import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocab_presentation_decision.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/single_result_reliability_gate.dart';

export 'package:fitfuel/features/food_scan/domain/entities/open_vocab_presentation_decision.dart';
export 'package:fitfuel/features/food_scan/domain/entities/single_result_reliability_gate.dart';

/// Explicit routing outcome returned by [FoodScanRecognitionRouter] in Phase 35.10 / 35.11B Free-First mode.
sealed class FoodScanRouteDecision {
  final String requestId;
  final String imagePath;
  final LocalFoodPrediction? prediction;
  final int localInferenceDurationMs;
  final bool isOffline;

  const FoodScanRouteDecision({
    required this.requestId,
    required this.imagePath,
    this.prediction,
    this.localInferenceDurationMs = 0,
    this.isOffline = false,
  });
}

/// High-confidence production-enabled prediction accepted automatically on-device (0 Gemini calls).
class LocalAutoAccepted extends FoodScanRouteDecision {
  final FoodScanResult result;

  const LocalAutoAccepted({
    required super.requestId,
    required super.imagePath,
    required this.result,
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B / 35.11B.1 alias for Tier-1 auto-local acceptance.
typedef Tier1AutoLocalAccepted = LocalAutoAccepted;

/// Auto-local acceptance did not pass, but valid Top-K local suggestions are available for user confirmation (0 Gemini calls).
class LocalSuggestionsAvailable extends FoodScanRouteDecision {
  final List<LocalFoodCandidate> suggestions;

  const LocalSuggestionsAvailable({
    required super.requestId,
    required super.imagePath,
    required this.suggestions,
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B / 35.11B.1 Tier-2 Open-Vocabulary route decision:
/// Base class for Tier-2 open-vocabulary recognition outcomes.
class Tier2OpenVocabSuggestionsAvailable extends FoodScanRouteDecision {
  final List<OpenVocabularyFoodCandidate> candidates;
  final OpenVocabularyRecognitionResult openVocabResult;
  final OpenVocabPresentationDecision? presentationDecision;
  final int tier1DurationMs;
  final int tier2DurationMs;

  const Tier2OpenVocabSuggestionsAvailable({
    required super.requestId,
    required super.imagePath,
    required this.candidates,
    required this.openVocabResult,
    this.presentationDecision,
    super.prediction,
    this.tier1DurationMs = 0,
    this.tier2DurationMs = 0,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B.1 Tier-2 Single Primary Result route decision:
/// Tier 1 did not qualify for auto-local acceptance, and Tier 2 (`SigLIP-B/16 INT8`)
/// passed both the food/non-food gate AND the strict [SingleResultReliabilityGate].
/// Production Food Scan displays MAXIMUM ONE detected food name.
/// Candidate #2 and #3 are retained strictly internally for diagnostics/margin calculation
/// and are NEVER exposed to normal users (0 Gemini calls).
class Tier2OpenVocabPrimaryResult extends Tier2OpenVocabSuggestionsAvailable {
  final SingleResultReliabilityDecision reliabilityDecision;
  final FoodScanRecognitionSource recognitionSource;
  final bool hasExactCatalogNutrition;
  final FoodEntity? matchedFood;
  final NutritionProfileTier nutritionTier;
  final String? nutritionExplanation;
  final String? recipeAssumptions;
  final String? nutritionAttribution;

  Tier2OpenVocabPrimaryResult({
    required super.requestId,
    required super.imagePath,
    required OpenVocabularyFoodCandidate primaryCandidate,
    required this.reliabilityDecision,
    this.recognitionSource = FoodScanRecognitionSource.openVocabularyPrimary,
    required this.hasExactCatalogNutrition,
    this.matchedFood,
    this.nutritionTier = NutritionProfileTier.unavailable,
    this.nutritionExplanation,
    this.recipeAssumptions,
    this.nutritionAttribution,
    required super.openVocabResult,
    List<OpenVocabularyFoodCandidate> internalCandidates = const [],
    super.presentationDecision,
    super.prediction,
    super.tier1DurationMs,
    super.tier2DurationMs,
    super.localInferenceDurationMs,
    super.isOffline,
  }) : super(
          candidates: internalCandidates.isNotEmpty
              ? internalCandidates
              : [primaryCandidate],
        );

  OpenVocabularyFoodCandidate get primaryCandidate => candidates.first;
  List<OpenVocabularyFoodCandidate> get internalCandidates => candidates;
  bool get hasNutrition => matchedFood != null && nutritionTier != NutritionProfileTier.unavailable;
}

/// Multiple foods are detected or suspected on the plate; user can add foods manually or analyze with AI.
class MixedMealNeedsDecision extends FoodScanRouteDecision {
  final List<LocalFoodCandidate> suggestions;
  final String reason;

  const MixedMealNeedsDecision({
    required super.requestId,
    required super.imagePath,
    this.suggestions = const [],
    this.reason = 'Multiple foods detected or suspected.',
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// On-device TFLite model failed to load or is unsupported on the current platform.
class LocalModelUnavailable extends FoodScanRouteDecision {
  final String reason;

  const LocalModelUnavailable({
    required super.requestId,
    required super.imagePath,
    this.reason = 'On-device classifier model is unavailable.',
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// All 50 local model predictions fell below [minimumSuggestionConfidence] or failed OOV reliability checks;
/// user can search manually or request AI.
class CloudRequired extends FoodScanRouteDecision {
  final String reason;

  const CloudRequired({
    required super.requestId,
    required super.imagePath,
    this.reason = 'No local suggestions met minimum confidence threshold.',
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.10.3 OOV safety route decision:
/// Local model candidates are weak, flat, or semantically contradictory (likely out-of-vocabulary food).
/// Suppresses misleading local suggestions and guides user to Search Foods or Analyze with AI (0 Gemini calls).
class NoReliableLocalMatch extends CloudRequired {
  final List<LocalFoodCandidate> suppressedCandidates;

  const NoReliableLocalMatch({
    required super.requestId,
    required super.imagePath,
    super.reason = 'No reliable local match found.',
    this.suppressedCandidates = const [],
    super.prediction,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B Tier-2 Non-Food Abstention route decision:
/// Tier 2 (`SigLIP-B/16 INT8`) rejected the image via the negative non-food safety gate
/// (`topFoodSim < modeB_sim_floor` or `negMargin < modeB_neg_margin_threshold`).
/// Never exposes internal food guesses; shows "No food detected" with Try Another Photo,
/// Search Foods, and optional Analyze with AI (0 Gemini calls).
class Tier2AbstainedNonFood extends NoReliableLocalMatch {
  final OpenVocabularyRecognitionResult openVocabResult;
  final int tier1DurationMs;
  final int tier2DurationMs;

  const Tier2AbstainedNonFood({
    required super.requestId,
    required super.imagePath,
    required this.openVocabResult,
    super.reason = 'rejected_non_food_margin',
    super.prediction,
    this.tier1DurationMs = 0,
    this.tier2DurationMs = 0,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B / 35.11B.1 alias for Tier-2 non-food abstention.
typedef Tier2NonFoodAbstained = Tier2AbstainedNonFood;

/// Phase 35.11B Tier-2 Low Food Similarity Abstention route decision:
/// Tier 2 (`SigLIP-B/16 INT8`) passed the negative non-food floor/margin but
/// `topFoodSim < modeA_sim_threshold`. Suppresses weak guesses and shows
/// "No reliable local match found" (0 Gemini calls).
class Tier2NoReliableMatch extends NoReliableLocalMatch {
  final OpenVocabularyRecognitionResult openVocabResult;
  final int tier1DurationMs;
  final int tier2DurationMs;

  const Tier2NoReliableMatch({
    required super.requestId,
    required super.imagePath,
    required this.openVocabResult,
    super.reason = 'rejected_low_food_similarity',
    super.prediction,
    this.tier1DurationMs = 0,
    this.tier2DurationMs = 0,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}

/// Phase 35.11B.1 Tier-2 Ambiguous Abstention route decision:
/// Tier 2 passed food/non-food floor but failed the strict [SingleResultReliabilityGate]
/// (e.g. low margin, confusable siblings like Spaghetti/Bolognese or Pizza/Flammkuchen,
/// or incoherent candidate families). Suppresses all food names and shows
/// "No reliable food match found." with [Search Foods], [Analyze with AI], [Try Another Photo].
class Tier2AmbiguousAbstain extends Tier2NoReliableMatch {
  final SingleResultReliabilityDecision reliabilityDecision;

  const Tier2AmbiguousAbstain({
    required super.requestId,
    required super.imagePath,
    required super.openVocabResult,
    required this.reliabilityDecision,
    super.reason = 'ambiguous_single_result',
    super.prediction,
    super.tier1DurationMs = 0,
    super.tier2DurationMs = 0,
    super.localInferenceDurationMs,
    super.isOffline,
  });
}
