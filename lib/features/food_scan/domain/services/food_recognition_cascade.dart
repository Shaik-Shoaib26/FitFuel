import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocab_presentation_decision.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';

export 'package:fitfuel/features/food_scan/domain/entities/open_vocab_presentation_decision.dart';

/// Centralized top-level presentation gate helper for Phase 35.11B.1.
OpenVocabPresentationDecision evaluateOpenVocabPresentation(
  OpenVocabularyRecognitionResult result, {
  List<FoodEntity> foodCatalog = const [],
  FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
}) {
  return FoodRecognitionCascade(config: config).evaluateOpenVocabPresentation(
    result,
    foodCatalog: foodCatalog,
  );
}

/// Outcome of evaluating the Tier-2 open-vocabulary (`SigLIP-B/16 INT8`) safety gate
/// and Phase 35.11B.1 Smart Single-Result UX presentation gate.
class OpenVocabSafetyEvaluation {
  final bool accepted;
  final bool abstained;
  final bool isNonFoodRejected;
  final bool isUnavailable;
  final String route;
  final String reason;
  final List<OpenVocabularyFoodCandidate> deduplicatedCandidates;
  final OpenVocabularyRecognitionResult normalizedResult;
  final OpenVocabPresentationDecision? presentationDecision;

  const OpenVocabSafetyEvaluation({
    required this.accepted,
    required this.abstained,
    required this.isNonFoodRejected,
    required this.isUnavailable,
    required this.route,
    required this.reason,
    required this.deduplicatedCandidates,
    required this.normalizedResult,
    this.presentationDecision,
  });
}

/// Coordinates the Phase 35.11B / 35.11B.1 Two-Tier Local Open-Vocabulary Food Recognition Cascade:
///
/// - **Tier 1 (`fitfuel_food_v5` TFLite):** Fast closed-set classifier with 8 trusted
///   auto-local classes (`confidence >= 0.85` AND `margin >= 0.15`).
/// - **Tier 2 (`SigLIP-B/16 INT8` ONNX):** True image-text-aligned open-vocabulary
///   recognizer over 2,050 canonical food concepts and 12 negative non-food prompts,
///   with centralized 3-mode Smart Single-Result UX presentation gating
///   (`singlePrimary`, `primaryWithAlternatives`, `ambiguousTop3`).
///   Never auto-logs without explicit user confirmation or strict safety gate + trusted nutrition.
class FoodRecognitionCascade {
  final FoodScanRouterConfig config;

  const FoodRecognitionCascade({
    this.config = kDefaultFoodScanRouterConfig,
  });

  /// Evaluates the calibrated Phase 35.11A.1 / 35.11A.2 SigLIP-B/16 safety gate
  /// (`modeA_sim_threshold = 0.0665`, `modeB_sim_floor = 0.0181`,
  /// `modeB_neg_margin_threshold = 0.0621`), deduplicates Top-3 canonical candidates,
  /// and computes the centralized Phase 35.11B.1 [OpenVocabPresentationDecision].
  OpenVocabSafetyEvaluation evaluateTier2Result(
    OpenVocabularyRecognitionResult rawResult, {
    List<FoodEntity> foodCatalog = const [],
    LocalFoodPrediction? tier1Prediction,
  }) {
    if (rawResult.isUnavailable) {
      return OpenVocabSafetyEvaluation(
        accepted: false,
        abstained: true,
        isNonFoodRejected: false,
        isUnavailable: true,
        route: 'tier2_unavailable_fallback',
        reason: rawResult.errorReason ?? 'tier2_unavailable',
        deduplicatedCandidates: const [],
        normalizedResult: rawResult,
      );
    }

    final topSim = rawResult.topSimilarity;
    final negSim = rawResult.negativeSimilarity;
    final negMargin = rawResult.negativeMargin != 0.0
        ? rawResult.negativeMargin
        : (topSim - negSim);

    // Phase 35.13.3: Food-classifier awareness for complex / heavy meals
    final hasTier1FoodConfidence = tier1Prediction != null &&
        tier1Prediction.isModelAvailable &&
        tier1Prediction.foodId.isNotEmpty &&
        tier1Prediction.foodId != 'unknown' &&
        tier1Prediction.confidence >= 0.30;

    // 1. Check Non-Food / Negative Margin Gate (Mode B)
    // Only classify as non-food if:
    // - Tier 1 closed-set food classifier did NOT confidently detect food, AND
    // - (Explicitly marked non-food with dominant negative similarity / margin <= 0.0200, OR
    //    Negative prompt strictly beats or equals the top food candidate (topSim <= negSim), OR
    //    Top similarity is below the absolute floor AND negative margin is non-positive).
    final isGenuinelyNonFood = !hasTier1FoodConfidence &&
        (((rawResult.isNonFoodRejected &&
                (negSim >= 0.0850 || topSim <= negSim || negMargin <= 0.0200))) ||
            topSim <= negSim ||
            (topSim < config.openVocabModeBSimFloor && negMargin <= 0.0));

    if (isGenuinelyNonFood) {
      final reason = topSim < config.openVocabModeBSimFloor
          ? 'rejected_below_sim_floor'
          : 'rejected_non_food_margin';
      final updated = rawResult.copyWith(
        accepted: false,
        abstained: true,
        isNonFoodRejected: true,
        negativeMargin: negMargin,
        decisionReason: reason,
      );
      return OpenVocabSafetyEvaluation(
        accepted: false,
        abstained: true,
        isNonFoodRejected: true,
        isUnavailable: false,
        route: 'tier2_abstained_non_food',
        reason: reason,
        deduplicatedCandidates: const [],
        normalizedResult: updated,
      );
    }

    // 2. Check Food Similarity Threshold (Mode A) & Tight-Margin Complex Meals
    // When food similarity exceeds negative prompt similarity (topSim > negSim) but
    // margin is tight (< config.openVocabModeBNegMarginThreshold) or similarity is low,
    // this indicates a complex multi-item plate or uncertain dish, NOT non-food!
    final failedSimFloor = topSim < config.openVocabModeBSimFloor;
    final failedNegMargin = negMargin < config.openVocabModeBNegMarginThreshold;
    final isLowFoodSim =
        topSim < config.openVocabModeASimThreshold || !rawResult.accepted;

    if (failedSimFloor || failedNegMargin || isLowFoodSim) {
      final reason = failedSimFloor
          ? 'rejected_below_sim_floor'
          : (failedNegMargin
              ? 'uncertain_complex_meal_tight_margin'
              : 'rejected_low_food_similarity');
      final updated = rawResult.copyWith(
        accepted: false,
        abstained: true,
        isNonFoodRejected: false,
        negativeMargin: negMargin,
        decisionReason: reason,
      );
      return OpenVocabSafetyEvaluation(
        accepted: false,
        abstained: true,
        isNonFoodRejected: false,
        isUnavailable: false,
        route: 'tier2_no_reliable_match',
        reason: reason,
        deduplicatedCandidates: const [],
        normalizedResult: updated,
      );
    }

    // 3. Deduplicate canonical candidates and enrich FitFuel catalog availability
    final deduplicated = TrustedOpenVocabNutritionMapper.deduplicateCandidates(
      rawResult.topCandidates,
      maxSuggestions: config.openVocabMaxSuggestions,
      foodCatalog: foodCatalog,
    );

    if (deduplicated.isEmpty) {
      const reason = 'no_candidates_after_deduplication';
      final updated = rawResult.copyWith(
        accepted: false,
        abstained: true,
        isNonFoodRejected: false,
        negativeMargin: negMargin,
        decisionReason: reason,
      );
      return OpenVocabSafetyEvaluation(
        accepted: false,
        abstained: true,
        isNonFoodRejected: false,
        isUnavailable: false,
        route: 'tier2_no_reliable_match',
        reason: reason,
        deduplicatedCandidates: const [],
        normalizedResult: updated,
      );
    }

    const reason = 'accepted_open_vocab';
    final updated = rawResult.copyWith(
      accepted: true,
      abstained: false,
      isNonFoodRejected: false,
      negativeMargin: negMargin,
      decisionReason: reason,
      topCandidates: deduplicated,
    );

    final presentationDecision = evaluateOpenVocabPresentation(
      updated,
      foodCatalog: foodCatalog,
    );

    return OpenVocabSafetyEvaluation(
      accepted: true,
      abstained: false,
      isNonFoodRejected: false,
      isUnavailable: false,
      route: 'tier2_open_vocab_suggestions',
      reason: reason,
      deduplicatedCandidates: deduplicated,
      normalizedResult: updated,
      presentationDecision: presentationDecision,
    );
  }

  /// Phase 35.11B.1 Centralized Smart Presentation Gate:
  /// Classifies an accepted [OpenVocabularyRecognitionResult] into one of:
  /// - [OpenVocabPresentationMode.singlePrimary] (`SINGLE_PRIMARY_RESULT`)
  /// - [OpenVocabPresentationMode.primaryWithAlternatives] (`PRIMARY_WITH_ALTERNATIVES`)
  /// - [OpenVocabPresentationMode.ambiguousTop3] (`AMBIGUOUS_TOP3`)
  ///
  /// Evaluates multiple signals:
  /// - Top-1, Top-2, Top-3 similarity scores
  /// - Top-1 vs Top-2 (`margin12`) and Top-1 vs Top-3 (`margin13`) margins
  /// - Food vs non-food negative margin (`negativeMargin`)
  /// - Semantic / culinary family coherence across Top-3 candidates
  /// - Known confusable cross-dish / regional sibling ambiguity sets
  /// - Exact FitFuel trusted catalog match (`isExactCatalogMatch`) and verified 1:1 alias status (`hasVerifiedAliasMapping`)
  OpenVocabPresentationDecision evaluateOpenVocabPresentation(
    OpenVocabularyRecognitionResult result, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    final deduplicated = TrustedOpenVocabNutritionMapper.deduplicateCandidates(
      result.topCandidates,
      maxSuggestions: config.openVocabMaxSuggestions,
      foodCatalog: foodCatalog,
    );

    final top1 = deduplicated.isNotEmpty ? deduplicated[0] : null;
    final top2 = deduplicated.length >= 2 ? deduplicated[1] : null;
    final top3 = deduplicated.length >= 3 ? deduplicated[2] : null;
    final alternatives = deduplicated.length > 1
        ? deduplicated.sublist(1)
        : const <OpenVocabularyFoodCandidate>[];

    final top1Sim = top1?.similarity ?? result.topSimilarity;
    final top2Sim = top2?.similarity ?? 0.0;
    final top3Sim = top3?.similarity ?? 0.0;
    final margin12 =
        top2 != null ? (top1Sim - top2Sim).clamp(0.0, 1.0) : top1Sim;
    final margin13 =
        top3 != null ? (top1Sim - top3Sim).clamp(0.0, 1.0) : margin12;
    final negMargin = result.negativeMargin != 0.0
        ? result.negativeMargin
        : (top1Sim - result.negativeSimilarity);

    if (!result.accepted ||
        result.abstained ||
        result.isNonFoodRejected ||
        result.isUnavailable ||
        top1 == null) {
      return OpenVocabPresentationDecision(
        mode: OpenVocabPresentationMode.ambiguousTop3,
        primaryCandidate: top1,
        alternativeCandidates: alternatives,
        allCandidates: deduplicated,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        top3Similarity: top3Sim,
        margin12: margin12,
        margin13: margin13,
        negativeMargin: negMargin,
        isSameCulinaryFamily: false,
        culinaryFamily: 'none',
        isExactCatalogMatch: false,
        hasVerifiedAliasMapping: false,
        hasConfusableSiblings: false,
        reason: result.decisionReason.isNotEmpty
            ? result.decisionReason
            : 'not_accepted',
      );
    }

    final isExactCatalog = TrustedOpenVocabNutritionMapper.isExactCatalogFood(
      top1,
      foodCatalog: foodCatalog,
    );
    final hasVerifiedAlias =
        TrustedOpenVocabNutritionMapper.hasVerifiedAlias(top1);
    final hasTrustedNutrition =
        isExactCatalog || hasVerifiedAlias || top1.inFitFuelCatalog;

    final families = deduplicated.map(_inferCulinaryFamily).toList();
    final primaryFamily = families.first;

    final hasConfusableSiblings = _hasConfusableCrossDishSiblings(
      deduplicated,
      margin12: margin12,
    );

    final isSameFamily = !hasConfusableSiblings &&
        _areCandidatesFamilyCoherent(
          families,
          margin12: margin12,
          primaryAltMarginThreshold: config.openVocabPrimaryAltMarginThreshold,
        );

    // 1. Confusable cross-dish / regional siblings (e.g. Pizza vs Flammkuchen vs Zanzibar Pizza,
    //    Tsukemen vs Mien Ga vs Ramen, Spaghetti vs Spaghetti Bolognese vs Cincinnati Chili)
    //    must show Top-3 directly so the user chooses.
    if (hasConfusableSiblings) {
      return OpenVocabPresentationDecision(
        mode: OpenVocabPresentationMode.ambiguousTop3,
        primaryCandidate: top1,
        alternativeCandidates: alternatives,
        allCandidates: deduplicated,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        top3Similarity: top3Sim,
        margin12: margin12,
        margin13: margin13,
        negativeMargin: negMargin,
        isSameCulinaryFamily: false,
        culinaryFamily: primaryFamily,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        hasConfusableSiblings: true,
        reason: 'ambiguous_confusable_siblings',
      );
    }

    // 2. Strict SINGLE_PRIMARY_RESULT Gate (Section 10):
    //    Requires strong calibrated Top-1 similarity, clear Top-1 vs Top-2 margin,
    //    strong food/non-food negative margin, coherent culinary family with no
    //    contradictory siblings, AND trusted FitFuel catalog / verified alias nutrition.
    if (hasTrustedNutrition &&
        isSameFamily &&
        top1Sim >= config.openVocabSinglePrimarySimThreshold &&
        margin12 >= config.openVocabSinglePrimaryMarginThreshold &&
        negMargin >= config.openVocabSinglePrimaryNegMarginThreshold) {
      return OpenVocabPresentationDecision(
        mode: OpenVocabPresentationMode.singlePrimary,
        primaryCandidate: top1,
        alternativeCandidates: alternatives,
        allCandidates: deduplicated,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        top3Similarity: top3Sim,
        margin12: margin12,
        margin13: margin13,
        negativeMargin: negMargin,
        isSameCulinaryFamily: true,
        culinaryFamily: primaryFamily,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        hasConfusableSiblings: false,
        reason: 'strong_catalog_match_and_margin',
      );
    }

    // 3. PRIMARY_WITH_ALTERNATIVES Gate (Sections 4, 8, 9, 11):
    //    Recommended default when Top-3 belong to a coherent culinary family
    //    (e.g., Creamy Penne Pasta / Penne Alfredo / Creamy Pasta, Masala Dosa / Plain Dosa / Rava Dosa,
    //    Burger / Chicken Burger / Veggie Burger) OR when Top-1 has a clear margin over compatible Top-2.
    if (isSameFamily && top1Sim >= config.openVocabModeASimThreshold) {
      return OpenVocabPresentationDecision(
        mode: OpenVocabPresentationMode.primaryWithAlternatives,
        primaryCandidate: top1,
        alternativeCandidates: alternatives,
        allCandidates: deduplicated,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        top3Similarity: top3Sim,
        margin12: margin12,
        margin13: margin13,
        negativeMargin: negMargin,
        isSameCulinaryFamily: true,
        culinaryFamily: primaryFamily,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        hasConfusableSiblings: false,
        reason: 'coherent_culinary_family',
      );
    }

    final top2Compatible = families.length < 2 ||
        _areFamiliesCompatible(families[0], families[1]);
    if (top2Compatible &&
        top1Sim >= config.openVocabPrimaryAltSimThreshold &&
        margin12 >= config.openVocabPrimaryAltMarginThreshold &&
        negMargin >= config.openVocabPrimaryAltNegMarginThreshold) {
      return OpenVocabPresentationDecision(
        mode: OpenVocabPresentationMode.primaryWithAlternatives,
        primaryCandidate: top1,
        alternativeCandidates: alternatives,
        allCandidates: deduplicated,
        top1Similarity: top1Sim,
        top2Similarity: top2Sim,
        top3Similarity: top3Sim,
        margin12: margin12,
        margin13: margin13,
        negativeMargin: negMargin,
        isSameCulinaryFamily: isSameFamily,
        culinaryFamily: primaryFamily,
        isExactCatalogMatch: isExactCatalog,
        hasVerifiedAliasMapping: hasVerifiedAlias,
        hasConfusableSiblings: false,
        reason: 'clear_top1_margin',
      );
    }

    // 4. AMBIGUOUS_TOP3 (Section 15):
    //    Incoherent cross-category candidates (e.g., Pineapple / Grilled Chicken Breast / Medu Vada)
    //    or flat ambiguous candidates without family consensus.
    return OpenVocabPresentationDecision(
      mode: OpenVocabPresentationMode.ambiguousTop3,
      primaryCandidate: top1,
      alternativeCandidates: alternatives,
      allCandidates: deduplicated,
      top1Similarity: top1Sim,
      top2Similarity: top2Sim,
      top3Similarity: top3Sim,
      margin12: margin12,
      margin13: margin13,
      negativeMargin: negMargin,
      isSameCulinaryFamily: isSameFamily,
      culinaryFamily: primaryFamily,
      isExactCatalogMatch: isExactCatalog,
      hasVerifiedAliasMapping: hasVerifiedAlias,
      hasConfusableSiblings: false,
      reason: isSameFamily
          ? 'low_margin_ambiguous'
          : 'incoherent_candidate_families',
    );
  }

  /// Infers a canonical culinary family key for a Tier-2 open-vocabulary candidate
  /// using both its category metadata and dish lexical tokens.
  static String _inferCulinaryFamily(OpenVocabularyFoodCandidate c) {
    final text = '${c.canonicalFoodId} ${c.canonicalName}'
        .toLowerCase()
        .replaceAll('_', ' ');
    final cat = c.category.toLowerCase().trim();

    if (_containsAny(text, const [
      'pasta',
      'penne',
      'spaghetti',
      'fettuccine',
      'alfredo',
      'macaroni',
      'lasagna',
      'ravioli',
      'gnocchi',
      'rigatoni',
      'linguine',
      'tagliatelle',
      'carbonara',
      'bolognese',
      'fusilli',
      'farfalle',
      'orzo',
      'noodle',
      'ramen',
      'tsukemen',
      'udon',
      'soba',
      'pho',
      'mien ga',
      'chow mein',
      'lo mein',
      'pad thai',
      'vermicelli',
      'hakka',
    ]) ||
        cat.contains('pasta') ||
        cat.contains('noodle')) {
      return 'pasta_noodles';
    }

    if (_containsAny(text, const [
      'pizza',
      'flammkuchen',
      'calzone',
      'stromboli',
      'focaccia',
      'flatbread',
    ]) ||
        cat.contains('pizza')) {
      return 'pizza_flatbread';
    }

    if (_containsAny(text, const [
      'burger',
      'hamburger',
      'cheeseburger',
      'sandwich',
      'panini',
      'sub ',
      'hoagie',
      'wrap',
      'shawarma',
      'gyro',
      'burrito',
      'taco',
      'quesadilla',
      'hot dog',
      'bake and shark',
      'slider',
      'blt',
    ]) ||
        cat.contains('burger') ||
        cat.contains('sandwich')) {
      return 'burger_sandwich';
    }

    if (_containsAny(text, const [
      'dosa',
      'idli',
      'uttapam',
      'vada',
      'medu vada',
      'sambar',
      'appam',
      'pesarattu',
      'pongal',
      'upma',
      'puttu',
      'idiyappam',
    ]) ||
        cat.contains('south indian')) {
      return 'south_indian';
    }

    if (_containsAny(text, const [
      'biryani',
      'pulao',
      'pilaf',
      'fried rice',
      'steamed rice',
      'brown rice',
      'jeera rice',
      'lemon rice',
      'curd rice',
      'khichdi',
      'risotto',
      'paella',
      'jollof',
      'nasi',
      'poha',
      'flattened rice',
    ]) ||
        cat.contains('biryani') ||
        cat.contains('rice')) {
      return 'rice_biryani';
    }

    if (_containsAny(text, const [
      'paneer',
      'tikka',
      'masala',
      'makhani',
      'korma',
      'vindaloo',
      'rogan josh',
      'dal ',
      'daal',
      'chole',
      'rajma',
      'curry',
      'kadai',
      'palak',
      'saag',
      'kofta',
      'keema',
      'samosa',
      'sambusa',
      'briouat',
      'kachori',
      'pakora',
      'bhaji',
      'paratha',
      'naan',
      'chapati',
      'roti',
      'kulcha',
      'bhatura',
      'puri',
    ]) ||
        cat.contains('north indian') ||
        cat.contains('curry') ||
        cat.contains('curries') ||
        cat.contains('indian snack') ||
        cat.contains('legume')) {
      return 'indian_curry_savory';
    }

    if (_containsAny(text, const [
      'salmon',
      'tuna',
      'cod',
      'tilapia',
      'trout',
      'mackerel',
      'sardine',
      'shrimp',
      'prawn',
      'crab',
      'lobster',
      'fish',
      'calamari',
      'ceviche',
      'sushi',
      'sashimi',
    ]) ||
        cat.contains('seafood') ||
        cat.contains('fish')) {
      return 'seafood_fish';
    }

    if (_containsAny(text, const [
      'chicken',
      'steak',
      'beef',
      'pork',
      'lamb',
      'mutton',
      'turkey',
      'duck',
      'bacon',
      'sausage',
      'ham',
      'prosciutto',
      'salami',
      'ribs',
      'meatball',
      'schnitzel',
      'kebab',
      'poulet',
      'paprikash',
    ]) ||
        cat.contains('meat') ||
        cat.contains('poultry')) {
      return 'poultry_meat';
    }

    if (_containsAny(text, const [
      'egg',
      'omelette',
      'omelet',
      'frittata',
      'shakshuka',
      'pancake',
      'waffle',
      'french toast',
      'oatmeal',
      'oats',
      'porridge',
      'granola',
      'cereal',
      'muesli',
    ]) ||
        cat.contains('egg') ||
        cat.contains('breakfast')) {
      return 'eggs_breakfast';
    }

    if (_containsAny(text, const [
      'apple',
      'banana',
      'orange',
      'mango',
      'papaya',
      'watermelon',
      'pineapple',
      'grape',
      'guava',
      'strawberry',
      'blueberry',
      'raspberry',
      'blackberry',
      'kiwi',
      'peach',
      'pear',
      'plum',
      'cherry',
      'pomegranate',
      'avocado',
      'melon',
      'cantaloupe',
      'muskmelon',
      'fig',
      'lychee',
      'dragon fruit',
    ]) ||
        cat.contains('fruit')) {
      return 'fruits';
    }

    if (_containsAny(text, const [
      'salad',
      'broccoli',
      'cauliflower',
      'carrot',
      'potato',
      'tomato',
      'cucumber',
      'spinach',
      'capsicum',
      'bell pepper',
      'onion',
      'zucchini',
      'eggplant',
      'aubergine',
      'mushroom',
      'asparagus',
      'kale',
      'cabbage',
      'lettuce',
      'gourd',
    ]) ||
        cat.contains('vegetable') ||
        cat.contains('salad')) {
      return 'vegetables_salads';
    }

    if (_containsAny(text, const [
      'milk',
      'yogurt',
      'curd',
      'lassi',
      'cheese',
      'butter',
      'cream',
      'smoothie',
      'shake',
      'juice',
      'coffee',
      'espresso',
      'latte',
      'cappuccino',
      'tea',
      'chai',
      'matcha',
      'coconut water',
    ]) ||
        cat.contains('dairy') ||
        cat.contains('beverage') ||
        cat.contains('drink')) {
      return 'dairy_beverages';
    }

    if (_containsAny(text, const [
      'bread',
      'toast',
      'bagel',
      'croissant',
      'muffin',
      'baguette',
      'ciabatta',
      'sourdough',
      'roll',
      'bun',
      'pretzel',
      'smorrebrod',
      'smørrebrød',
    ]) ||
        cat.contains('bread') ||
        cat.contains('bakery')) {
      return 'bread_bakery';
    }

    if (_containsAny(text, const [
      'soup',
      'stew',
      'broth',
      'chowder',
      'bisque',
      'gazpacho',
      'minestrone',
      'goulash',
      'chili',
    ]) ||
        cat.contains('soup') ||
        cat.contains('stew')) {
      return 'soups_stews';
    }

    if (_containsAny(text, const [
      'cake',
      'cookie',
      'brownie',
      'ice cream',
      'gelato',
      'pudding',
      'custard',
      'pie',
      'tart',
      'pastry',
      'donut',
      'doughnut',
      'chocolate',
      'gulab jamun',
      'jalebi',
      'rasgulla',
      'kheer',
      'halwa',
      'barfi',
      'laddu',
      'tiramisu',
    ]) ||
        cat.contains('dessert') ||
        cat.contains('sweet')) {
      return 'desserts_sweets';
    }

    if (_containsAny(text, const [
      'almond',
      'walnut',
      'cashew',
      'peanut',
      'pistachio',
      'chips',
      'fries',
      'french fries',
      'popcorn',
      'nachos',
      'cracker',
      'hummus',
      'falafel',
    ]) ||
        cat.contains('snack') ||
        cat.contains('nut')) {
      return 'snacks_nuts';
    }

    if (cat.isNotEmpty &&
        cat != 'other' &&
        cat != 'general' &&
        cat != 'global dishes' &&
        cat != 'main course') {
      return cat;
    }

    return 'other';
  }

  /// Public accessor for culinary family inference.
  static String inferCulinaryFamily(OpenVocabularyFoodCandidate c) =>
      _inferCulinaryFamily(c);

  /// Public accessor for candidate family coherence.
  static bool areFamiliesCoherent(
    List<String> families, {
    required double margin12,
    required double primaryAltMarginThreshold,
  }) =>
      _areCandidatesFamilyCoherent(
        families,
        margin12: margin12,
        primaryAltMarginThreshold: primaryAltMarginThreshold,
      );

  /// Public accessor for family compatibility.
  static bool areFamiliesCompatible(String a, String b) =>
      _areFamiliesCompatible(a, b);

  /// Detects known confusable cross-dish / regional sibling sets (Sections 2, 15, 36, 40)
  /// that must remain ambiguous unless Top-1 has an overwhelming margin (`>= confusableMarginThreshold`).
  static bool hasConfusableCrossDishSiblings(
    List<OpenVocabularyFoodCandidate> candidates, {
    required double margin12,
    double confusableMarginThreshold = 0.025,
  }) =>
      _hasConfusableCrossDishSiblings(
        candidates,
        margin12: margin12,
        confusableMarginThreshold: confusableMarginThreshold,
      );

  /// Internal implementation for confusable cross-dish sibling detection.
  static bool _hasConfusableCrossDishSiblings(
    List<OpenVocabularyFoodCandidate> candidates, {
    required double margin12,
    double confusableMarginThreshold = 0.025,
  }) {
    if (candidates.length < 2) return false;
    if (margin12 >= confusableMarginThreshold) return false;

    final joined = candidates
        .map((c) => '${c.canonicalFoodId} ${c.canonicalName}'.toLowerCase())
        .join(' | ');

    // 1. Pizza vs Flammkuchen vs Zanzibar Pizza vs Smørrebrød
    final hasFlammkuchenOrZanzibar = joined.contains('flammkuchen') ||
        joined.contains('zanzibar_pizza') ||
        joined.contains('zanzibar pizza');
    if (hasFlammkuchenOrZanzibar &&
        (joined.contains('pizza') || joined.contains('prosciutto'))) {
      return true;
    }
    if (joined.contains('pizza') &&
        (joined.contains('smorrebrod') ||
            joined.contains('smørrebrød') ||
            joined.contains('ciabatta'))) {
      return true;
    }

    // 2. Ramen vs Tsukemen vs Mien Ga vs Pho
    final hasTsukemenOrMienGa = joined.contains('tsukemen') ||
        joined.contains('mien_ga') ||
        joined.contains('mien ga');
    if (hasTsukemenOrMienGa &&
        (joined.contains('ramen') || joined.contains('pho'))) {
      return true;
    }

    // 3. Plain Spaghetti vs Spaghetti Bolognese vs Cincinnati Chili vs Carbonara
    final hasBologneseOrChili = joined.contains('bolognese') ||
        joined.contains('cincinnati_chili') ||
        joined.contains('cincinnati chili') ||
        joined.contains('carbonara');
    final hasPlainSpaghetti = candidates.any((c) {
      final n = c.canonicalName.toLowerCase().trim();
      return n == 'spaghetti' || n == 'spaghetti pasta';
    });
    if (hasBologneseOrChili && hasPlainSpaghetti) {
      return true;
    }

    // 4. Conflicting pasta preparation variants with close margin
    // (e.g. Alfredo vs Carbonara vs Bolognese)
    const pastaTypes = [
      'bolognese',
      'carbonara',
      'cincinnati chili',
      'alfredo',
      'penne',
      'fideua',
      'fideuà',
      'ravioli',
      'macaroni'
    ];
    final foundTypes = pastaTypes.where((t) => joined.contains(t)).toList();
    if (foundTypes.length >= 2 && margin12 < confusableMarginThreshold) {
      return true;
    }

    return false;
  }

  static bool _areCandidatesFamilyCoherent(
    List<String> families, {
    required double margin12,
    required double primaryAltMarginThreshold,
  }) {
    if (families.isEmpty) return false;
    final f0 = families.first;
    if (f0 == 'other') return false;
    if (families.length == 1) return true;

    // All candidates belong to the exact same culinary family
    if (families.every((f) => f == f0)) {
      return true;
    }

    // All candidates belong to mutually compatible culinary families (e.g. Indian curry + South Indian / rice)
    if (families.every((f) => _areFamiliesCompatible(f0, f))) {
      return true;
    }

    // Top-1 and Top-2 share the exact same family and Top-1 has a clear margin over Top-2
    if (families.length >= 2 &&
        families[0] == families[1] &&
        margin12 >= primaryAltMarginThreshold) {
      return true;
    }

    return false;
  }

  static bool _areFamiliesCompatible(String a, String b) {
    if (a == 'other' || b == 'other') return false;
    if (a == b) return true;
    final pair = {a, b};
    const compatiblePairs = <Set<String>>[
      {'south_indian', 'indian_curry_savory'},
      {'rice_biryani', 'indian_curry_savory'},
    ];
    for (final allowed in compatiblePairs) {
      if (allowed.length == pair.length && allowed.containsAll(pair)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }
}
