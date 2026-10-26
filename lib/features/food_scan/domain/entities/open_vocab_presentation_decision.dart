import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';

/// Phase 35.11B.1 Smart Single-Result UX presentation modes for Tier-2
/// open-vocabulary (`SigLIP-B/16 INT8`) recognition results.
enum OpenVocabPresentationMode {
  /// Strong evidence (high similarity, clear margin, strong non-food margin,
  /// coherent family, and trusted FitFuel catalog match): present one primary
  /// food result prominently without showing an expanded alternatives section.
  singlePrimary,

  /// Recommended default for family-coherent or clear-margin Tier-2 scans
  /// (e.g., `Creamy Penne Pasta` with `Penne Alfredo` & `Creamy Pasta`):
  /// present Top-1 prominently as "Best local match" while collapsing Top-2
  /// and Top-3 under "Other possible matches" and "Change Food".
  primaryWithAlternatives,

  /// Evidence is ambiguous or candidates span contradictory/confusable dishes
  /// (e.g., `Pizza / Flammkuchen / Zanzibar Pizza`, `Tsukemen / Mien Ga / Ramen`,
  /// or `Pineapple / Grilled Chicken Breast / Medu Vada`): show Top-3 directly.
  ambiguousTop3,
}

/// Centralized presentation decision evaluated by `evaluateOpenVocabPresentation`
/// after Tier-2 (`SigLIP-B/16 INT8`) passes the food/non-food safety gate.
class OpenVocabPresentationDecision {
  static const OpenVocabPresentationMode singlePrimary =
      OpenVocabPresentationMode.singlePrimary;
  static const OpenVocabPresentationMode primaryWithAlternatives =
      OpenVocabPresentationMode.primaryWithAlternatives;
  static const OpenVocabPresentationMode ambiguousTop3 =
      OpenVocabPresentationMode.ambiguousTop3;

  final OpenVocabPresentationMode mode;
  final OpenVocabularyFoodCandidate? primaryCandidate;
  final List<OpenVocabularyFoodCandidate> alternativeCandidates;
  final List<OpenVocabularyFoodCandidate> allCandidates;
  final double top1Similarity;
  final double top2Similarity;
  final double top3Similarity;
  final double margin12;
  final double margin13;
  final double negativeMargin;
  final bool isSameCulinaryFamily;
  final String culinaryFamily;
  final bool isExactCatalogMatch;
  final bool hasVerifiedAliasMapping;
  final bool hasConfusableSiblings;
  final String reason;
  final FoodScanRecognitionSource suggestedSource;

  const OpenVocabPresentationDecision({
    required this.mode,
    this.primaryCandidate,
    this.alternativeCandidates = const [],
    this.allCandidates = const [],
    this.top1Similarity = 0.0,
    this.top2Similarity = 0.0,
    this.top3Similarity = 0.0,
    this.margin12 = 0.0,
    this.margin13 = 0.0,
    this.negativeMargin = 0.0,
    this.isSameCulinaryFamily = false,
    this.culinaryFamily = 'other',
    this.isExactCatalogMatch = false,
    this.hasVerifiedAliasMapping = false,
    this.hasConfusableSiblings = false,
    required this.reason,
    this.suggestedSource =
        FoodScanRecognitionSource.openVocabularyPrimarySuggested,
  });

  bool get isSinglePrimary => mode == OpenVocabPresentationMode.singlePrimary;

  bool get isPrimaryWithAlternatives =>
      mode == OpenVocabPresentationMode.primaryWithAlternatives;

  bool get isAmbiguousTop3 => mode == OpenVocabPresentationMode.ambiguousTop3;

  /// True when the UI should present a single primary result card (`singlePrimary` or `primaryWithAlternatives`)
  /// rather than three equal full-size candidate buttons.
  bool get isSingleResultUx => isSinglePrimary || isPrimaryWithAlternatives;

  /// True when the primary candidate has a trusted FitFuel catalog or verified 1:1 alias nutrition match.
  bool get hasTrustedNutrition =>
      isExactCatalogMatch ||
      hasVerifiedAliasMapping ||
      (primaryCandidate?.inFitFuelCatalog ?? false);

  /// Alias for [isSameCulinaryFamily].
  bool get sameCulinaryFamily => isSameCulinaryFamily;

  /// Canonical mode string for `[FoodScanPresentation]` debug logs and telemetry.
  String get modeName => mode.name;
}
