/// Centralized configuration for hybrid food scan recognition routing.
class FoodScanRouterConfig {
  /// Minimum confidence threshold for trusting an on-device prediction without cloud fallback.
  final double highConfidenceThreshold;

  /// Minimum margin between top-1 and top-2 candidates to avoid ambiguous classification.
  final double minimumConfidenceMargin;

  /// Minimum confidence threshold required for a local candidate to appear in Top-K suggestion mode.
  final double minimumSuggestionConfidence;

  /// Phase 35.10.3: Minimum Top-1 confidence required for a suggestion set to be considered reliable
  /// unless supported by a coherent multi-candidate food neighborhood above [coherentNeighborhoodMinTop1].
  final double suggestionReliabilityThreshold;

  /// Phase 35.10.3: Minimum Top-1 vs Top-2 margin required when candidates do not form a coherent food neighborhood.
  final double suggestionReliabilityMargin;

  /// Phase 35.10.3: Hard minimum Top-1 confidence floor even when candidates belong to a coherent food neighborhood.
  final double coherentNeighborhoodMinTop1;

  /// Global feature flag toggling local model inference.
  final bool enableOnDeviceFoodRecognition;

  /// Phase 35.10 Free-First routing flag: prefers local Top-K suggestions over automatic Gemini calls.
  final bool preferFreeLocalScan;

  /// Debug flag controlling whether raw route labels and technical confidence percentages are shown in UI.
  final bool enableDebugTelemetryUi;

  /// Target model metadata version string.
  final String modelVersion;

  /// Target labels metadata version string.
  final String labelVersion;

  /// Maximum candidates to preserve from classifier output (default Top 3).
  final int maxCandidates;

  /// Set of food IDs officially supported by the local model (e.g. 50 V1 classes).
  /// All 50 classes may participate in Top-K suggestion mode.
  final Set<String> supportedFoodIds;

  /// Optional restricted set of food IDs verified for automatic production-local resolution.
  /// If provided, only foods in this set will auto-resolve locally without user confirmation.
  final Set<String>? productionEnabledFoodIds;

  /// Phase 35.11B: Whether Tier-2 open-vocabulary recognition (`SigLIP-B/16 INT8`) is enabled
  /// when Tier-1 (`fitfuel_food_v5`) does not qualify for trusted auto-local acceptance.
  final bool enableOpenVocabularyTier2;

  /// Phase 35.11B: Target Tier-2 open-vocabulary model identifier.
  final String openVocabModelVersion;

  /// Phase 35.11B: Calibrated Mode A food similarity threshold (`0.0665` for `siglip_b16_int8`).
  final double openVocabModeASimThreshold;

  /// Phase 35.11B: Calibrated Mode B non-food similarity floor (`0.0181` for `siglip_b16_int8`).
  final double openVocabModeBSimFloor;

  /// Phase 35.11B: Calibrated Mode B food-vs-negative margin threshold (`0.0621` for `siglip_b16_int8`).
  final double openVocabModeBNegMarginThreshold;

  /// Phase 35.11B: Maximum deduplicated canonical open-vocabulary suggestions to show (`3`).
  final int openVocabMaxSuggestions;

  /// Phase 35.11B.1: Calibrated Top-1 similarity threshold for `SINGLE_PRIMARY_RESULT` mode (`0.1050`).
  final double openVocabSinglePrimarySimThreshold;

  /// Phase 35.11B.1: Calibrated Top-1 vs Top-2 similarity margin for `SINGLE_PRIMARY_RESULT` mode (`0.0150`).
  final double openVocabSinglePrimaryMarginThreshold;

  /// Phase 35.11B.1: Calibrated food-vs-negative margin for `SINGLE_PRIMARY_RESULT` mode (`0.0950`).
  final double openVocabSinglePrimaryNegMarginThreshold;

  /// Phase 35.11B.1: Calibrated Top-1 similarity threshold for margin-based `PRIMARY_WITH_ALTERNATIVES` mode (`0.0750`).
  final double openVocabPrimaryAltSimThreshold;

  /// Phase 35.11B.1: Calibrated Top-1 vs Top-2 margin for margin-based `PRIMARY_WITH_ALTERNATIVES` mode (`0.0140`).
  final double openVocabPrimaryAltMarginThreshold;

  /// Phase 35.11B.1: Calibrated food-vs-negative margin for margin-based `PRIMARY_WITH_ALTERNATIVES` mode (`0.0750`).
  final double openVocabPrimaryAltNegMarginThreshold;

  /// Phase 35.11B.1: Calibrated Top-1 similarity threshold for strict single-result reliability gate (`0.0800`).
  final double openVocabSingleResultSimThreshold;

  /// Phase 35.11B.1: Calibrated Top-1 vs Top-2 similarity margin for strict single-result reliability gate (`0.0150`).
  final double openVocabSingleResultMarginThreshold;

  /// Phase 35.11B.1: Calibrated food-vs-negative margin for strict single-result reliability gate (`0.0750`).
  final double openVocabSingleResultNegMarginThreshold;

  /// Phase 35.11B.1: Minimum margin required to override confusable cross-dish siblings (`0.0250`).
  final double openVocabConfusableSiblingMinMargin;

  /// Phase 35.12: Whether the extensible global food vocabulary is active.
  final bool enableGlobalFoodVocabulary;

  /// Phase 35.12: Whether multi-tier universal nutrition resolution (exact vs generic vs estimate) is active.
  final bool enableUniversalNutritionResolution;

  /// Phase 35.12: Whether user feedback, correction, and unrecognized food reporting is active.
  final bool enableUserFeedbackWorkflow;

  const FoodScanRouterConfig({
    this.highConfidenceThreshold = 0.85,
    this.minimumConfidenceMargin = 0.15,
    this.minimumSuggestionConfidence = 0.15,
    this.suggestionReliabilityThreshold = 0.45,
    this.suggestionReliabilityMargin = 0.12,
    this.coherentNeighborhoodMinTop1 = 0.35,
    this.enableOnDeviceFoodRecognition = true,
    this.preferFreeLocalScan = true,
    this.enableDebugTelemetryUi = false,
    this.modelVersion = 'fitfuel_food_v5',
    this.labelVersion = 'fitfuel_labels_v5',
    this.maxCandidates = 3,
    this.supportedFoodIds = kFitFuelV1SupportedFoodIds,
    this.productionEnabledFoodIds,
    this.enableOpenVocabularyTier2 = true,
    this.openVocabModelVersion = 'siglip_b16_int8',
    this.openVocabModeASimThreshold = 0.0665,
    this.openVocabModeBSimFloor = 0.0181,
    this.openVocabModeBNegMarginThreshold = 0.0621,
    this.openVocabMaxSuggestions = 3,
    this.openVocabSinglePrimarySimThreshold = 0.1050,
    this.openVocabSinglePrimaryMarginThreshold = 0.0150,
    this.openVocabSinglePrimaryNegMarginThreshold = 0.0950,
    this.openVocabPrimaryAltSimThreshold = 0.0750,
    this.openVocabPrimaryAltMarginThreshold = 0.0140,
    this.openVocabPrimaryAltNegMarginThreshold = 0.0750,
    this.openVocabSingleResultSimThreshold = 0.0800,
    this.openVocabSingleResultMarginThreshold = 0.0150,
    this.openVocabSingleResultNegMarginThreshold = 0.0750,
    this.openVocabConfusableSiblingMinMargin = 0.0250,
    this.enableGlobalFoodVocabulary = true,
    this.enableUniversalNutritionResolution = true,
    this.enableUserFeedbackWorkflow = true,
  });

  FoodScanRouterConfig copyWith({
    double? highConfidenceThreshold,
    double? minimumConfidenceMargin,
    double? minimumSuggestionConfidence,
    double? suggestionReliabilityThreshold,
    double? suggestionReliabilityMargin,
    double? coherentNeighborhoodMinTop1,
    bool? enableOnDeviceFoodRecognition,
    bool? preferFreeLocalScan,
    bool? enableDebugTelemetryUi,
    String? modelVersion,
    String? labelVersion,
    int? maxCandidates,
    Set<String>? supportedFoodIds,
    Set<String>? productionEnabledFoodIds,
    bool? enableOpenVocabularyTier2,
    String? openVocabModelVersion,
    double? openVocabModeASimThreshold,
    double? openVocabModeBSimFloor,
    double? openVocabModeBNegMarginThreshold,
    int? openVocabMaxSuggestions,
    double? openVocabSinglePrimarySimThreshold,
    double? openVocabSinglePrimaryMarginThreshold,
    double? openVocabSinglePrimaryNegMarginThreshold,
    double? openVocabPrimaryAltSimThreshold,
    double? openVocabPrimaryAltMarginThreshold,
    double? openVocabPrimaryAltNegMarginThreshold,
    double? openVocabSingleResultSimThreshold,
    double? openVocabSingleResultMarginThreshold,
    double? openVocabSingleResultNegMarginThreshold,
    double? openVocabConfusableSiblingMinMargin,
    bool? enableGlobalFoodVocabulary,
    bool? enableUniversalNutritionResolution,
    bool? enableUserFeedbackWorkflow,
  }) {
    return FoodScanRouterConfig(
      highConfidenceThreshold:
          highConfidenceThreshold ?? this.highConfidenceThreshold,
      minimumConfidenceMargin:
          minimumConfidenceMargin ?? this.minimumConfidenceMargin,
      minimumSuggestionConfidence:
          minimumSuggestionConfidence ?? this.minimumSuggestionConfidence,
      suggestionReliabilityThreshold:
          suggestionReliabilityThreshold ?? this.suggestionReliabilityThreshold,
      suggestionReliabilityMargin:
          suggestionReliabilityMargin ?? this.suggestionReliabilityMargin,
      coherentNeighborhoodMinTop1:
          coherentNeighborhoodMinTop1 ?? this.coherentNeighborhoodMinTop1,
      enableOnDeviceFoodRecognition:
          enableOnDeviceFoodRecognition ?? this.enableOnDeviceFoodRecognition,
      preferFreeLocalScan: preferFreeLocalScan ?? this.preferFreeLocalScan,
      enableDebugTelemetryUi:
          enableDebugTelemetryUi ?? this.enableDebugTelemetryUi,
      modelVersion: modelVersion ?? this.modelVersion,
      labelVersion: labelVersion ?? this.labelVersion,
      maxCandidates: maxCandidates ?? this.maxCandidates,
      supportedFoodIds: supportedFoodIds ?? this.supportedFoodIds,
      productionEnabledFoodIds:
          productionEnabledFoodIds ?? this.productionEnabledFoodIds,
      enableOpenVocabularyTier2:
          enableOpenVocabularyTier2 ?? this.enableOpenVocabularyTier2,
      openVocabModelVersion:
          openVocabModelVersion ?? this.openVocabModelVersion,
      openVocabModeASimThreshold:
          openVocabModeASimThreshold ?? this.openVocabModeASimThreshold,
      openVocabModeBSimFloor:
          openVocabModeBSimFloor ?? this.openVocabModeBSimFloor,
      openVocabModeBNegMarginThreshold: openVocabModeBNegMarginThreshold ??
          this.openVocabModeBNegMarginThreshold,
      openVocabMaxSuggestions:
          openVocabMaxSuggestions ?? this.openVocabMaxSuggestions,
      openVocabSinglePrimarySimThreshold: openVocabSinglePrimarySimThreshold ??
          this.openVocabSinglePrimarySimThreshold,
      openVocabSinglePrimaryMarginThreshold:
          openVocabSinglePrimaryMarginThreshold ??
              this.openVocabSinglePrimaryMarginThreshold,
      openVocabSinglePrimaryNegMarginThreshold:
          openVocabSinglePrimaryNegMarginThreshold ??
              this.openVocabSinglePrimaryNegMarginThreshold,
      openVocabPrimaryAltSimThreshold: openVocabPrimaryAltSimThreshold ??
          this.openVocabPrimaryAltSimThreshold,
      openVocabPrimaryAltMarginThreshold: openVocabPrimaryAltMarginThreshold ??
          this.openVocabPrimaryAltMarginThreshold,
      openVocabPrimaryAltNegMarginThreshold:
          openVocabPrimaryAltNegMarginThreshold ??
              this.openVocabPrimaryAltNegMarginThreshold,
      openVocabSingleResultSimThreshold: openVocabSingleResultSimThreshold ??
          this.openVocabSingleResultSimThreshold,
      openVocabSingleResultMarginThreshold:
          openVocabSingleResultMarginThreshold ??
              this.openVocabSingleResultMarginThreshold,
      openVocabSingleResultNegMarginThreshold:
          openVocabSingleResultNegMarginThreshold ??
              this.openVocabSingleResultNegMarginThreshold,
      openVocabConfusableSiblingMinMargin:
          openVocabConfusableSiblingMinMargin ??
              this.openVocabConfusableSiblingMinMargin,
      enableGlobalFoodVocabulary:
          enableGlobalFoodVocabulary ?? this.enableGlobalFoodVocabulary,
      enableUniversalNutritionResolution: enableUniversalNutritionResolution ??
          this.enableUniversalNutritionResolution,
      enableUserFeedbackWorkflow:
          enableUserFeedbackWorkflow ?? this.enableUserFeedbackWorkflow,
    );
  }
}

/// The 50 curated high-value, visually distinctive food classes supported by FitFuel V1 on-device model.
const Set<String> kFitFuelV1SupportedFoodIds = {
  // Fruits (10)
  'predefined_apple',
  'predefined_banana',
  'predefined_orange',
  'predefined_mango',
  'predefined_papaya',
  'predefined_watermelon',
  'predefined_pineapple',
  'predefined_grapes',
  'predefined_guava',
  'predefined_strawberry',

  // Breakfast / Indian (6)
  'predefined_idli',
  'predefined_dosa',
  'predefined_uttapam',
  'predefined_poha',
  'predefined_upma',
  'predefined_medu_vada',

  // Staples / Grains (6)
  'predefined_steamed_rice',
  'predefined_brown_rice_ind',
  'predefined_chapati',
  'predefined_roti',
  'predefined_oats',
  'predefined_whole_wheat_bread',

  // Protein / Eggs / Meat (8)
  'predefined_hard_boiled_eggs',
  'predefined_egg_omelette',
  'predefined_scrambled_eggs',
  'predefined_grilled_chicken_breast',
  'predefined_tandoori_chicken',
  'predefined_ind_paneer',
  'predefined_firm_tofu',
  'predefined_paneer_tikka',

  // Dairy / Beverages (4)
  'predefined_low_fat_milk',
  'predefined_curd',
  'predefined_greek_yogurt_plain',
  'predefined_coconut_water',

  // Legumes / Curries (5)
  'predefined_dal_tadka',
  'predefined_chole_masala',
  'predefined_rajma_curry',
  'predefined_moong_dal',
  'predefined_sambar',

  // Vegetables (9)
  'predefined_potato',
  'predefined_tomato',
  'predefined_carrot',
  'predefined_broccoli',
  'predefined_cauliflower',
  'predefined_cucumber',
  'predefined_spinach',
  'predefined_capsicum',
  'predefined_onion',

  // Snacks (2)
  'predefined_samosa',
  'predefined_almonds',
};

/// Verified subset of food classes calibrated for safe automatic local recognition in Phase 35.9.3.
/// Retained for reference and backward compatibility.
const Set<String> kFitFuelV3ProductionEnabledFoodIds = {
  'predefined_watermelon',
  'predefined_strawberry',
  'predefined_medu_vada',
  'predefined_steamed_rice',
  'predefined_scrambled_eggs',
  'predefined_rajma_curry',
  'predefined_capsicum',
  'predefined_whole_wheat_bread',
  'predefined_guava',
  'predefined_dosa',
  'predefined_broccoli',
  'predefined_chole_masala',
  'predefined_low_fat_milk',
  'predefined_poha',
  'predefined_potato',
  'predefined_samosa',
  'predefined_tandoori_chicken',
  'predefined_paneer_tikka',
};

/// Verified subset of food classes calibrated for safe automatic local recognition in Phase 35.9.4.
/// Classes with unsupported OOD false acceptance vulnerabilities (predefined_poha mistaking Biryani,
/// predefined_tandoori_chicken mistaking Paneer Butter Masala) have been removed from local automatic
/// resolution and routed to Gemini cloud fallback for dietary and macro safety.
const Set<String> kFitFuelV4ProductionEnabledFoodIds = {
  'predefined_watermelon',
  'predefined_strawberry',
  'predefined_medu_vada',
  'predefined_steamed_rice',
  'predefined_scrambled_eggs',
  'predefined_rajma_curry',
  'predefined_capsicum',
  'predefined_whole_wheat_bread',
  'predefined_guava',
  'predefined_dosa',
  'predefined_broccoli',
  'predefined_chole_masala',
  'predefined_low_fat_milk',
  'predefined_potato',
  'predefined_samosa',
  'predefined_paneer_tikka',
};

/// Verified subset of food classes calibrated for safe automatic local recognition in Phase 35.9.5.
/// Validated against the untouched 465-image Final Lockbox V5 with 100% precision (0 wrong accepts),
/// zero non-food false accepts, zero unsupported-food false accepts, and zero dietary risk violations.
/// All other classes route to Gemini cloud fallback.
const Set<String> kFitFuelV5ProductionEnabledFoodIds = {
  'predefined_medu_vada',
  'predefined_samosa',
  'predefined_whole_wheat_bread',
  'predefined_scrambled_eggs',
  'predefined_watermelon',
  'predefined_dosa',
  'predefined_low_fat_milk',
  'predefined_capsicum',
};

/// Default global configuration for hybrid food scan recognition routing.
const FoodScanRouterConfig kDefaultFoodScanRouterConfig =
    FoodScanRouterConfig(
  modelVersion: 'fitfuel_food_v5',
  labelVersion: 'fitfuel_labels_v5',
  productionEnabledFoodIds: kFitFuelV5ProductionEnabledFoodIds,
);
