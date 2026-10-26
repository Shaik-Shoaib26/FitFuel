/// Classification of nutrition data reliability and source transparency (Phase 35.12 Section 5).
///
/// Distinguishes among:
/// 1. Verified exact nutrition profile
/// 2. Closely related generic food profile
/// 3. Recipe-based estimate with stated assumptions
/// 4. Nutrition unavailable
enum NutritionProfileTier {
  /// Verified exact nutrition profile matched directly to the recognized dish.
  verifiedExact,

  /// Closely related generic food profile (e.g. generic cooked pasta for specialty pasta).
  closelyRelatedGeneric,

  /// Recipe-based estimate constructed with stated culinary assumptions.
  recipeEstimate,

  /// Nutrition unavailable — user must select a profile manually or search catalog.
  unavailable,
}

extension NutritionProfileTierX on NutritionProfileTier {
  String get label {
    switch (this) {
      case NutritionProfileTier.verifiedExact:
        return 'Curated FitFuel Food Database';
      case NutritionProfileTier.closelyRelatedGeneric:
        return 'USDA Generic Baseline';
      case NutritionProfileTier.recipeEstimate:
        return 'Recipe Estimate';
      case NutritionProfileTier.unavailable:
        return 'Nutrition Unavailable';
    }
  }

  String get userExplanation {
    switch (this) {
      case NutritionProfileTier.verifiedExact:
        return 'Curated profile from the FitFuel food database. Please verify portion size before logging.';
      case NutritionProfileTier.closelyRelatedGeneric:
        return 'Based on a USDA FoodData Central generic baseline. Cooking methods and ingredients may differ.';
      case NutritionProfileTier.recipeEstimate:
        return 'Estimated from standard recipe formulation. Discloses culinary assumptions; not lab-tested.';
      case NutritionProfileTier.unavailable:
        return 'No nutrition profile exists for this food. Please select from search or enter custom nutrition.';
    }
  }

  bool get isDirectlyLoggable =>
      this == NutritionProfileTier.verifiedExact ||
      this == NutritionProfileTier.closelyRelatedGeneric ||
      this == NutritionProfileTier.recipeEstimate;
}
