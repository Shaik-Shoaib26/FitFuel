import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/universal_nutrition_profile.dart';

/// Provenance classification of an individual recipe ingredient (Phase 35.12.12).
enum IngredientProvenanceType {
  /// Sourced directly from an authoritative food composition database (e.g. USDA FoodData Central).
  directlySourced,

  /// Composite ingredient calculated from explicitly defined sub-components (e.g. seasoning blends).
  definedComposite,

  /// Generic baseline or culinary estimate whose provenance is not independently verified in a lab.
  culinaryEstimate,
}

/// Cooked batch yield classification for a recipe formulation (Phase 35.12.12).
enum BatchYieldType {
  /// Batch mass is measured post-cooking in a calibrated test environment.
  measuredAfterCooking,

  /// Batch mass is calculated from the combined masses of already-cooked/prepared ingredients.
  calculatedFromPreparedIngredients,

  /// Batch mass represents an assumed commercial recipe target yield with expected simmer reduction.
  assumedTargetYield,
}

/// Disclosed component of a composite recipe ingredient (e.g. salt, soy sauce, garlic in seasoning).
class IngredientComponent {
  final String name;
  final String? sourceIdentifier;
  final double massGrams;
  final double sodiumMg;
  final double calories;
  final String notes;

  const IngredientComponent({
    required this.name,
    this.sourceIdentifier,
    required this.massGrams,
    required this.sodiumMg,
    this.calories = 0.0,
    required this.notes,
  });
}

/// Represents a single culinary ingredient in a recipe formulation.
class RecipeIngredient {
  final String name;
  final String? sourceIdentifier;
  final double massGrams;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double sodiumMgPer100g;
  final String? notes;
  final IngredientProvenanceType provenanceType;
  final List<IngredientComponent> components;
  final String? sodiumCalculationMethod;

  const RecipeIngredient({
    required this.name,
    this.sourceIdentifier,
    required this.massGrams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0.0,
    this.sodiumMgPer100g = 0.0,
    this.notes,
    this.provenanceType = IngredientProvenanceType.directlySourced,
    this.components = const [],
    this.sodiumCalculationMethod,
  });

  /// Nutrient contribution (mass × nutrientPer100g ÷ 100).
  double get caloriesContribution => massGrams * caloriesPer100g / 100.0;
  double get proteinContribution => massGrams * proteinPer100g / 100.0;
  double get carbsContribution => massGrams * carbsPer100g / 100.0;
  double get fatContribution => massGrams * fatPer100g / 100.0;
  double get fiberContribution => massGrams * fiberPer100g / 100.0;
  double get sodiumContribution => massGrams * sodiumMgPer100g / 100.0;

  /// Total sodium across disclosed sub-components (mg).
  double get totalComponentSodium =>
      components.fold(0.0, (sum, c) => sum + c.sodiumMg);
}

/// Represents a standard culinary recipe formulation with disclosed ingredient
/// contributions, batch mass, cooked yield, and mathematically derived per-100-g profile.
class RecipeFormulation {
  final String recipeId;
  final String foodName;
  final double targetBatchMassGrams;
  final List<RecipeIngredient> ingredients;
  final String preparationState;
  final String sourceIdentifier;
  final String culinaryNotes;
  final double? sugarPer100g;
  final BatchYieldType yieldType;
  final String yieldExplanation;

  const RecipeFormulation({
    required this.recipeId,
    required this.foodName,
    required this.targetBatchMassGrams,
    required this.ingredients,
    required this.preparationState,
    required this.sourceIdentifier,
    required this.culinaryNotes,
    this.sugarPer100g,
    this.yieldType = BatchYieldType.assumedTargetYield,
    required this.yieldExplanation,
  });

  /// Sum of all ingredient masses (g).
  double get totalIngredientMass =>
      ingredients.fold(0.0, (sum, i) => sum + i.massGrams);

  /// Total calories in this batch formulation (kcal).
  double get batchCalories =>
      ingredients.fold(0.0, (sum, i) => sum + i.caloriesContribution);

  /// Total protein in this batch formulation (g).
  double get batchProtein =>
      ingredients.fold(0.0, (sum, i) => sum + i.proteinContribution);

  /// Total carbohydrates in this batch formulation (g).
  double get batchCarbs =>
      ingredients.fold(0.0, (sum, i) => sum + i.carbsContribution);

  /// Total fat in this batch formulation (g).
  double get batchFat =>
      ingredients.fold(0.0, (sum, i) => sum + i.fatContribution);

  /// Total dietary fiber in this batch formulation (g).
  double get batchFiber =>
      ingredients.fold(0.0, (sum, i) => sum + i.fiberContribution);

  /// Total sodium in this batch formulation (mg).
  double get batchSodium =>
      ingredients.fold(0.0, (sum, i) => sum + i.sodiumContribution);

  /// Derived per-100-g calories (kcal).
  double get per100gCalories =>
      (batchCalories * 100.0 / targetBatchMassGrams);

  /// Derived per-100-g protein (g).
  double get per100gProtein =>
      (batchProtein * 100.0 / targetBatchMassGrams);

  /// Derived per-100-g carbohydrates (g).
  double get per100gCarbs =>
      (batchCarbs * 100.0 / targetBatchMassGrams);

  /// Derived per-100-g fat (g).
  double get per100gFat =>
      (batchFat * 100.0 / targetBatchMassGrams);

  /// Derived per-100-g fiber (g).
  double get per100gFiber =>
      (batchFiber * 100.0 / targetBatchMassGrams);

  /// Derived per-100-g sodium (mg).
  double get per100gSodium =>
      (batchSodium * 100.0 / targetBatchMassGrams);

  /// Builds a [UniversalNutritionProfile] with rounded stored values matching
  /// the mathematical derivation from this formulation.
  UniversalNutritionProfile toUniversalNutritionProfile({
    DateTime? lastVerifiedDate,
  }) {
    // Round to 2 decimal places for macro storage
    final calRounded = double.parse(per100gCalories.toStringAsFixed(2));
    final pRounded = double.parse(per100gProtein.toStringAsFixed(2));
    final cRounded = double.parse(per100gCarbs.toStringAsFixed(2));
    final fRounded = double.parse(per100gFat.toStringAsFixed(2));
    final fiberRounded = double.parse(per100gFiber.toStringAsFixed(2));
    final naRounded = double.parse(per100gSodium.toStringAsFixed(1));

    return UniversalNutritionProfile(
      id: recipeId,
      foodName: foodName,
      tier: NutritionProfileTier.recipeEstimate,
      calories: calRounded,
      protein: pRounded,
      carbohydrates: cRounded,
      totalFat: fRounded,
      fiber: fiberRounded,
      sugar: sugarPer100g,
      sodium: naRounded,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: preparationState,
      source: 'Culinary Formulation Estimate',
      sourceIdentifier: sourceIdentifier,
      lastVerifiedDate: lastVerifiedDate ?? DateTime(2026, 3, 1),
      recipeAssumptions: culinaryNotes,
      attribution: 'FitFuel Standard Culinary Formulation',
    );
  }

  /// Validates the per-100-g profile's calorie consistency against Atwater factors.
  CalorieValidationResult validateCalorieConsistency({
    double absoluteToleranceKcal = RecipeEnergyValidator.defaultAbsoluteToleranceKcal,
    double relativeTolerancePercent = RecipeEnergyValidator.defaultRelativeTolerancePercent,
  }) {
    return RecipeEnergyValidator.validateAtwaterConsistency(
      statedCalories: per100gCalories,
      proteinGrams: per100gProtein,
      carbsGrams: per100gCarbs,
      fatGrams: per100gFat,
      absoluteToleranceKcal: absoluteToleranceKcal,
      relativeTolerancePercent: relativeTolerancePercent,
    );
  }
}

/// Result of calorie consistency evaluation against Atwater factors (Phase 35.12.13 / Phase 35.12.14).
class CalorieValidationResult {
  final bool isValid;
  final double statedCalories;
  final double calculatedCalories;
  final double absoluteDiscrepancy;
  final double? relativeDiscrepancyPercent;
  final bool relativeCheckEvaluated;
  final bool absoluteCheckPassed;
  final bool relativeCheckPassed;
  final String details;

  const CalorieValidationResult({
    required this.isValid,
    required this.statedCalories,
    required this.calculatedCalories,
    required this.absoluteDiscrepancy,
    this.relativeDiscrepancyPercent,
    required this.relativeCheckEvaluated,
    required this.absoluteCheckPassed,
    required this.relativeCheckPassed,
    required this.details,
  });

  @override
  String toString() => 'CalorieValidationResult(isValid: $isValid, $details)';
}

/// Explicit calorie validator enforcing dual-limit Atwater consistency (Phase 35.12.13 / Phase 35.12.14).
class RecipeEnergyValidator {
  /// Default maximum allowable absolute calorie discrepancy (kcal / 100g).
  static const double defaultAbsoluteToleranceKcal = 8.0;

  /// Default maximum allowable relative calorie discrepancy (percentage of stated energy).
  static const double defaultRelativeTolerancePercent = 5.0;

  /// Threshold below which relative percentage validation is bypassed to prevent low-energy division distortion.
  static const double lowEnergyThresholdKcal = 10.0;

  /// Validates stated energy against general Atwater 4-4-9 macro energy factors.
  ///
  /// Implements a dual-limit rule:
  /// 1. Absolute discrepancy |statedCalories - (4P + 4C + 9F)| <= [absoluteToleranceKcal] (default 8.0 kcal/100g)
  /// 2. Relative discrepancy <= [relativeTolerancePercent]% (default 5.0%)
  ///
  /// Low-energy safety: when stated energy < 10.0 kcal/100g, the relative check is not evaluated
  /// to avoid division distortion on small rounding differences.
  static CalorieValidationResult validateAtwaterConsistency({
    required double statedCalories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    double absoluteToleranceKcal = defaultAbsoluteToleranceKcal,
    double relativeTolerancePercent = defaultRelativeTolerancePercent,
  }) {
    final calculatedCalories =
        (proteinGrams * 4.0) + (carbsGrams * 4.0) + (fatGrams * 9.0);
    final absoluteDiscrepancy = (statedCalories - calculatedCalories).abs();
    final absoluteCheckPassed = absoluteDiscrepancy <= absoluteToleranceKcal;

    final bool relativeCheckEvaluated;
    final bool relativeCheckPassed;
    final double? relativeDiscrepancyPercent;

    if (statedCalories < lowEnergyThresholdKcal) {
      relativeCheckEvaluated = false;
      relativeDiscrepancyPercent = null;
      relativeCheckPassed = true;
    } else {
      relativeCheckEvaluated = true;
      relativeDiscrepancyPercent =
          (absoluteDiscrepancy / statedCalories) * 100.0;
      relativeCheckPassed =
          relativeDiscrepancyPercent <= relativeTolerancePercent;
    }

    final isValid = absoluteCheckPassed && relativeCheckPassed;

    final buffer = StringBuffer();
    buffer.write('Stated: ${statedCalories.toStringAsFixed(2)} kcal, ');
    buffer.write('Calculated: ${calculatedCalories.toStringAsFixed(2)} kcal, ');
    buffer.write(
        'Abs diff: ${absoluteDiscrepancy.toStringAsFixed(2)} kcal (limit: $absoluteToleranceKcal), ');
    if (!relativeCheckEvaluated) {
      buffer.write(
          'Rel check: not evaluated (stated energy < $lowEnergyThresholdKcal kcal)');
    } else {
      buffer.write(
          'Rel diff: ${relativeDiscrepancyPercent!.toStringAsFixed(2)}% (limit: $relativeTolerancePercent%)');
    }

    return CalorieValidationResult(
      isValid: isValid,
      statedCalories: statedCalories,
      calculatedCalories: calculatedCalories,
      absoluteDiscrepancy: absoluteDiscrepancy,
      relativeDiscrepancyPercent: relativeDiscrepancyPercent,
      relativeCheckEvaluated: relativeCheckEvaluated,
      absoluteCheckPassed: absoluteCheckPassed,
      relativeCheckPassed: relativeCheckPassed,
      details: buffer.toString(),
    );
  }
}
