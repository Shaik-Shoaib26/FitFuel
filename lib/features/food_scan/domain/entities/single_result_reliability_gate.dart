import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_recognition_cascade.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';

/// Evaluation decision produced by [SingleResultReliabilityGate] for Phase 35.11B.1.
/// Answers: "Is Top-1 reliable enough to present as the ONE detected food in production UI?"
class SingleResultReliabilityDecision {
  final bool isReliable;
  final String reason;
  final OpenVocabularyFoodCandidate? primaryCandidate;
  final double top1Similarity;
  final double top2Similarity;
  final double margin12;
  final double negativeMargin;
  final bool isSameCulinaryFamily;
  final String culinaryFamily;
  final bool hasConfusableSiblings;
  final bool isExactCatalogMatch;
  final bool hasVerifiedAliasMapping;
  final bool isMixedMealSuspected;
  final bool isNonFoodRejected;
  final bool isCrossModelDisagreement;
  final String? tier1CandidateId;

  const SingleResultReliabilityDecision({
    required this.isReliable,
    required this.reason,
    this.primaryCandidate,
    this.top1Similarity = 0.0,
    this.top2Similarity = 0.0,
    this.margin12 = 0.0,
    this.negativeMargin = 0.0,
    this.isSameCulinaryFamily = false,
    this.culinaryFamily = 'other',
    this.hasConfusableSiblings = false,
    this.isExactCatalogMatch = false,
    this.hasVerifiedAliasMapping = false,
    this.isMixedMealSuspected = false,
    this.isNonFoodRejected = false,
    this.isCrossModelDisagreement = false,
    this.tier1CandidateId,
  });

  @override
  String toString() =>
      'SingleResultReliabilityDecision(reliable=$isReliable, reason=$reason, '
      'top1=${primaryCandidate?.canonicalFoodId}, top1Sim=${top1Similarity.toStringAsFixed(4)}, '
      'margin12=${margin12.toStringAsFixed(4)}, negMargin=${negativeMargin.toStringAsFixed(4)}, '
      'sameFamily=$isSameCulinaryFamily, confusable=$hasConfusableSiblings, exactCatalog=$isExactCatalogMatch, '
      'crossModelDisagreement=$isCrossModelDisagreement, tier1=$tier1CandidateId)';
}

/// Phase 35.11B.1 Strict Single-Result Reliability Gate:
/// Evaluates whether Tier-2 (`SigLIP-B/16 INT8`) Top-1 candidate is sufficiently reliable
/// to be displayed as the SINGLE detected food result to normal users.
///
/// Signals evaluated:
/// 1. Non-food negative margin & floor (Mode B safety gate)
/// 2. Mixed-meal suspicion
/// 3. Top-1 similarity vs calibrated threshold (`0.0800`)
/// 4. Top-1 vs Top-2 similarity margin (`margin12 >= 0.0150`)
/// 5. Food vs negative non-food margin (`negMargin >= 0.0750`)
/// 6. Cross-dish / regional confusable siblings (Pizza/Flammkuchen, Ramen/Tsukemen, Spaghetti/Bolognese/Chili)
/// 7. Semantic / culinary family coherence between Top-1 and Top-2
/// 8. Exact FitFuel catalog presence & verified 1:1 alias mapping
class SingleResultReliabilityGate {
  final FoodScanRouterConfig config;

  const SingleResultReliabilityGate({
    this.config = kDefaultFoodScanRouterConfig,
  });

  /// Evaluates an [OpenVocabularyRecognitionResult] and returns a [SingleResultReliabilityDecision].
  SingleResultReliabilityDecision evaluate(
    OpenVocabularyRecognitionResult result, {
    List<FoodEntity> foodCatalog = const [],
    bool isMixedMealSuspected = false,
    LocalFoodPrediction? tier1Prediction,
  }) {
    final topSim = result.topSimilarity;
    final negSim = result.negativeSimilarity;
    final negMargin = result.negativeMargin != 0.0
        ? result.negativeMargin
        : (topSim - negSim);

    // 1. Check Non-Food / Negative Margin Gate (Mode B)
    final isGenuinelyNonFood = (result.isNonFoodRejected &&
            (negSim >= 0.0850 || topSim <= negSim || negMargin <= 0.0200)) ||
        topSim <= negSim ||
        (topSim < config.openVocabModeBSimFloor && negMargin <= 0.0);

    if (isGenuinelyNonFood) {
      final reason = topSim < config.openVocabModeBSimFloor
          ? 'rejected_below_sim_floor'
          : 'rejected_non_food_margin';
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: reason,
        top1Similarity: topSim,
        negativeMargin: negMargin,
        isNonFoodRejected: true,
      );
    }

    final failedSimFloor = topSim < config.openVocabModeBSimFloor;
    final failedNegMargin = negMargin < config.openVocabModeBNegMarginThreshold;
    if (failedSimFloor || failedNegMargin) {
      final reason = failedSimFloor
          ? 'rejected_below_sim_floor'
          : 'uncertain_complex_meal_tight_margin';
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: reason,
        top1Similarity: topSim,
        negativeMargin: negMargin,
        isNonFoodRejected: false,
      );
    }

    // 2. Check Mixed Meal suspicion
    if (isMixedMealSuspected) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'mixed_meal_suspected',
        top1Similarity: topSim,
        negativeMargin: negMargin,
        isMixedMealSuspected: true,
      );
    }

    // 3. Deduplicate candidates using canonical FitFuel mapper
    final deduplicated = TrustedOpenVocabNutritionMapper.deduplicateCandidates(
      result.topCandidates,
      maxSuggestions: config.openVocabMaxSuggestions,
      foodCatalog: foodCatalog,
    );

    if (deduplicated.isEmpty) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'no_candidates',
        top1Similarity: topSim,
        negativeMargin: negMargin,
      );
    }

    final top1 = deduplicated[0];
    final top2 = deduplicated.length >= 2 ? deduplicated[1] : null;

    final top1Sim = top1.similarity;
    final top2Sim = top2?.similarity ?? 0.0;
    final margin12 = top2 != null ? (top1Sim - top2Sim).clamp(0.0, 1.0) : top1Sim;

    final isExactCatalog = TrustedOpenVocabNutritionMapper.isExactCatalogFood(
      top1,
      foodCatalog: foodCatalog,
    );
    final hasVerifiedAlias =
        TrustedOpenVocabNutritionMapper.hasVerifiedAlias(top1);

    // 4. Strict Calibrated Top-1 Similarity Floor
    final minTop1Sim = config.openVocabSingleResultSimThreshold;
    if (top1Sim < minTop1Sim) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'low_top1_similarity',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
      );
    }

    // 5. Food vs Negative Margin Gate
    final minNegMargin = config.openVocabSingleResultNegMarginThreshold;
    if (negMargin < minNegMargin) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'low_negative_margin',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
      );
    }

    // 5.1 Cross-Model Disagreement Check between Tier 1 (TFLite) and Tier 2 (SigLIP)
    bool isCrossModelDisagreement = false;
    String? tier1CandidateId;
    if (tier1Prediction != null &&
        tier1Prediction.isModelAvailable &&
        tier1Prediction.foodId.isNotEmpty &&
        tier1Prediction.foodId != 'unknown' &&
        tier1Prediction.confidence >= 0.30) {
      tier1CandidateId = tier1Prediction.foodId;
      final t1Id = tier1Prediction.foodId.toLowerCase().trim();
      final t1Name = tier1Prediction.foodName.toLowerCase().trim();
      final t2Id = top1.canonicalFoodId.toLowerCase().trim();
      final t2CatalogId = (top1.fitFuelFoodId ?? '').toLowerCase().trim();
      final t2Name = top1.canonicalName.toLowerCase().trim();

      final idMatch = t1Id == t2Id ||
          (t2CatalogId.isNotEmpty && t1Id == t2CatalogId) ||
          t1Id.replaceFirst('predefined_', '') ==
              t2Id.replaceFirst('openvocab_', '') ||
          t1Id.replaceFirst('predefined_', '') ==
              t2Id.replaceFirst('predefined_', '');

      final nameMatch = t1Name == t2Name ||
          (t1Name.isNotEmpty && t2Name.contains(t1Name)) ||
          (t2Name.isNotEmpty && t1Name.contains(t2Name));

      final t1Family = FoodRecognitionCascade.inferCulinaryFamily(
        OpenVocabularyFoodCandidate(
          canonicalFoodId: t1Id,
          canonicalName: t1Name,
          category: '',
          similarity: 1.0,
          rank: 1,
        ),
      );
      final t2Family = FoodRecognitionCascade.inferCulinaryFamily(top1);
      final familyMatch = t1Family == t2Family ||
          FoodRecognitionCascade.areFamiliesCompatible(t1Family, t2Family);

      if (!idMatch && !nameMatch && !familyMatch) {
        isCrossModelDisagreement = true;
      }
    }

    if (isCrossModelDisagreement &&
        margin12 < config.openVocabConfusableSiblingMinMargin) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'cross_model_disagreement',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        isSameCulinaryFamily: false,
        culinaryFamily: 'disagreement',
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        isCrossModelDisagreement: true,
        tier1CandidateId: tier1CandidateId,
      );
    }

    // 6. Confusable cross-dish / regional sibling detection (Pizza/Flammkuchen, Ramen/Tsukemen, Spaghetti/Bolognese)
    final hasConfusableSiblings = FoodRecognitionCascade.hasConfusableCrossDishSiblings(
      deduplicated,
      margin12: margin12,
      confusableMarginThreshold: config.openVocabConfusableSiblingMinMargin,
    );
    if (hasConfusableSiblings) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'ambiguous_confusable_siblings',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        hasConfusableSiblings: true,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        isCrossModelDisagreement: isCrossModelDisagreement,
        tier1CandidateId: tier1CandidateId,
      );
    }

    // 7. Top-1 vs Top-2 Margin Gate
    final minMargin = config.openVocabSingleResultMarginThreshold;
    if (margin12 < minMargin) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: isCrossModelDisagreement
            ? 'cross_model_disagreement'
            : 'ambiguous_margin',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        isCrossModelDisagreement: isCrossModelDisagreement,
        tier1CandidateId: tier1CandidateId,
      );
    }

    // 8. Culinary Family Coherence Check
    final families = deduplicated.map(FoodRecognitionCascade.inferCulinaryFamily).toList();
    final primaryFamily = families.first;
    final sameFamily = FoodRecognitionCascade.areFamiliesCoherent(
      families,
      margin12: margin12,
      primaryAltMarginThreshold: minMargin,
    );

    if (!sameFamily) {
      return SingleResultReliabilityDecision(
        isReliable: false,
        reason: 'incoherent_candidate_families',
        primaryCandidate: top1,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        margin12: margin12,
        negativeMargin: negMargin,
        isSameCulinaryFamily: false,
        culinaryFamily: primaryFamily,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        isCrossModelDisagreement: isCrossModelDisagreement,
        tier1CandidateId: tier1CandidateId,
      );
    }

    // All strict single-result criteria passed with flying colors!
    return SingleResultReliabilityDecision(
      isReliable: true,
      reason: isExactCatalog
          ? 'reliable_catalog_match'
          : 'reliable_single_result',
      primaryCandidate: top1,
      top1Similarity: top1Sim,
      top2Similarity: top2Sim,
      margin12: margin12,
      negativeMargin: negMargin,
      isSameCulinaryFamily: true,
      culinaryFamily: primaryFamily,
      hasConfusableSiblings: false,
      isExactCatalogMatch: isExactCatalog,
      hasVerifiedAliasMapping: hasVerifiedAlias,
      isCrossModelDisagreement: isCrossModelDisagreement,
      tier1CandidateId: tier1CandidateId,
    );
  }
}
