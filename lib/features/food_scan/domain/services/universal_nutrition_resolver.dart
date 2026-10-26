import 'package:flutter/foundation.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/canonical_food_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_inventory_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/recipe_formulation.dart';
import 'package:fitfuel/features/food_scan/domain/entities/universal_nutrition_profile.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';

/// Result of resolving a food candidate against the Universal Nutrition Layer.
class UniversalNutritionResolutionResult {
  final UniversalNutritionProfile? profile;
  final NutritionProfileTier tier;
  final FoodEntity? matchedCatalogFood;
  final String explanation;
  final String? recipeAssumptions;
  final String? attribution;

  const UniversalNutritionResolutionResult({
    this.profile,
    required this.tier,
    this.matchedCatalogFood,
    required this.explanation,
    this.recipeAssumptions,
    this.attribution,
  });

  bool get hasNutrition => profile != null && tier != NutritionProfileTier.unavailable;
  bool get isVerifiedExact => tier == NutritionProfileTier.verifiedExact;
  bool get isGenericBaseline => tier == NutritionProfileTier.closelyRelatedGeneric;
  bool get isRecipeEstimate => tier == NutritionProfileTier.recipeEstimate;
}

/// Service managing global multi-source nutrition retrieval and tier classification
/// (Phase 35.12 Section 5).
///
/// Decouples nutrition data from image recognition models and enforces strict
/// transparency between verified lab profiles, generic baselines, and recipe estimates.
class UniversalNutritionResolver {
  final Map<String, UniversalNutritionProfile> _profilesById = {};
  final Map<String, UniversalNutritionProfile> _genericBaselines = {};
  final Map<String, UniversalNutritionProfile> _recipeEstimates = {};
  final Map<String, RecipeFormulation> _recipeFormulations = {};
  final Map<String, UniversalNutritionProfile> _allProfilesById = {};

  int get verifiedProfilesCount => _profilesById.length;
  int get genericBaselinesCount => _genericBaselines.length;
  int get recipeProfilesCount => _recipeEstimates.length;

  /// Retrieves an active nutrition profile across all tiers by canonical ID or slug key.
  UniversalNutritionProfile? getProfileById(String id) => _allProfilesById[id];
  UniversalNutritionProfile? getProfile(String id) => _allProfilesById[id];

  /// Unmodifiable view of all generic baseline profiles.
  Map<String, UniversalNutritionProfile> get genericBaselines =>
      Map.unmodifiable(_genericBaselines);

  /// Unmodifiable view of all recipe estimate profiles.
  Map<String, UniversalNutritionProfile> get recipeEstimates =>
      Map.unmodifiable(_recipeEstimates);

  /// Unmodifiable view of all standard culinary recipe formulations.
  Map<String, RecipeFormulation> get recipeFormulations =>
      Map.unmodifiable(_recipeFormulations);

  /// Unmodifiable view of all curated FitFuel catalog profiles.
  Map<String, UniversalNutritionProfile> get curatedProfiles =>
      Map.unmodifiable(_profilesById);

  /// Returns a complete list of all 264 active universal nutrition profiles
  /// across curated catalog (238), generic baselines (22), and recipe estimates (4).
  List<UniversalNutritionProfile> getAllActiveProfiles() {
    return [
      ..._profilesById.values,
      ..._genericBaselines.values,
      ..._recipeEstimates.values,
    ];
  }

  /// Generates a complete, machine-readable inventory of every active nutrition profile
  /// with resolution tier, source provenance, measurement basis, and traceability flags (Phase 35.12.9).
  List<NutritionProfileInventoryEntry> getProfileInventory() {
    final List<NutritionProfileInventoryEntry> inventory = [];

    // 1. Curated FitFuel Catalog Profiles (238)
    for (final p in _profilesById.values) {
      inventory.add(NutritionProfileInventoryEntry(
        canonicalProfileId: p.id,
        displayName: p.foodName,
        tier: p.tier,
        sourceType: 'FitFuel Curated Database',
        sourceIdentifier: p.sourceIdentifier,
        calories: p.calories,
        protein: p.protein,
        carbohydrates: p.carbohydrates,
        totalFat: p.totalFat,
        fiber: p.fiber,
        sugar: p.sugar,
        sodium: p.sodium,
        servingSize: p.servingSize,
        servingUnit: p.servingUnit,
        measurementBasis: p.servingSize == 100.0 && p.servingUnit == 'g'
            ? 'per 100 g'
            : 'per serving (${p.servingSize.toStringAsFixed(0)} ${p.servingUnit})',
        preparationState: p.preparationState,
        recipeAssumptions: p.recipeAssumptions,
        isExternallyTraceable: true,
        profileClassification: 'curated',
        attribution: p.attribution ?? 'Curated FitFuel Food Database',
      ));
    }

    // 2. Generic Baselines (21: 18 USDA FoodData Central + 3 Non-USDA Standard References)
    for (final p in _genericBaselines.values) {
      final isUsda = p.source == 'USDA FoodData Central';
      inventory.add(NutritionProfileInventoryEntry(
        canonicalProfileId: p.id,
        displayName: p.foodName,
        tier: p.tier,
        sourceType: p.source,
        sourceIdentifier: p.sourceIdentifier,
        calories: p.calories,
        protein: p.protein,
        carbohydrates: p.carbohydrates,
        totalFat: p.totalFat,
        fiber: p.fiber,
        sugar: p.sugar,
        sodium: p.sodium,
        servingSize: p.servingSize,
        servingUnit: p.servingUnit,
        measurementBasis: 'per 100 g',
        preparationState: p.preparationState,
        recipeAssumptions: p.recipeAssumptions,
        isExternallyTraceable: isUsda,
        profileClassification: 'generic',
        attribution: p.attribution ??
            (isUsda
                ? 'USDA FoodData Central'
                : 'Standard Food Composition Reference (Unverified Generic Reference)'),
      ));
    }

    // 3. Documented Recipe Estimates (4)
    for (final p in _recipeEstimates.values) {
      inventory.add(NutritionProfileInventoryEntry(
        canonicalProfileId: p.id,
        displayName: p.foodName,
        tier: p.tier,
        sourceType: p.source,
        sourceIdentifier: p.sourceIdentifier,
        calories: p.calories,
        protein: p.protein,
        carbohydrates: p.carbohydrates,
        totalFat: p.totalFat,
        fiber: p.fiber,
        sugar: p.sugar,
        sodium: p.sodium,
        servingSize: p.servingSize,
        servingUnit: p.servingUnit,
        measurementBasis: 'per 100 g',
        preparationState: p.preparationState,
        recipeAssumptions: p.recipeAssumptions,
        isExternallyTraceable: false,
        profileClassification: 'recipe-estimated',
        attribution: p.attribution ?? 'FitFuel Standard Culinary Formulation',
      ));
    }

    return inventory;
  }

  UniversalNutritionResolver() {
    _initProfiles();
  }

  void _initProfiles() {
    // 1. Seed FitFuel's 238 Curated Exact Profiles
    for (final food in PredefinedFoodData.foods) {
      final p = UniversalNutritionProfile(
        id: food.id,
        foodName: food.name,
        tier: NutritionProfileTier.verifiedExact,
        calories: food.calories,
        protein: food.protein,
        carbohydrates: food.carbohydrates,
        totalFat: food.fats,
        servingSize: food.servingSize,
        servingUnit: food.servingUnit,
        source: 'FitFuel Curated Database',
        sourceIdentifier: food.id,
        lastVerifiedDate: DateTime(2026, 1, 1),
        attribution: 'Curated FitFuel Food Database',
      );
      _profilesById[food.id] = p;
    }

    // 2. Global Documented Generic Baselines (USDA FoodData Central standard references)
    // E.g. Generic Cooked Pasta for restaurant pasta variants
    _genericBaselines['pasta_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_pasta',
      foodName: 'Pasta',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 131.0,
      protein: 5.15,
      carbohydrates: 25.0,
      totalFat: 1.05,
      fiber: 1.8,
      sugar: 0.56,
      sodium: 1.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_168936',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Standard enriched wheat pasta boiled without added fat or salt.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // E.g. Generic Pizza Baseline
    _genericBaselines['pizza_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_pizza',
      foodName: 'Pizza',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 266.0,
      protein: 11.3,
      carbohydrates: 33.3,
      totalFat: 9.8,
      fiber: 2.3,
      sugar: 3.6,
      sodium: 598.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'baked',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_173292',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Standard cheese pizza slice, regular crust, tomato sauce, mozzarella cheese.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // E.g. Generic Burger Baseline
    _genericBaselines['burger_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_burger',
      foodName: 'Burger',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 254.0,
      protein: 13.0,
      carbohydrates: 29.8,
      totalFat: 9.3,
      fiber: 1.4,
      sugar: 4.8,
      sodium: 414.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'grilled',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_170694',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fast foods, hamburger; single regular patty with condiments (USDA SR Legacy FDC 170694 / NDB 21108; FDC 173307 Egg McMuffin conflict resolved).',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Cooked White Rice
    _genericBaselines['rice_white_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_white_rice',
      foodName: 'White Rice',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 130.0,
      protein: 2.69,
      carbohydrates: 28.17,
      totalFat: 0.28,
      fiber: 0.4,
      sodium: 1.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled/cooked',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_168878',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Standard long-grain white rice cooked without added fat or salt.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Cooked Brown Rice
    _genericBaselines['rice_brown_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_brown_rice',
      foodName: 'Brown Rice',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 112.0,
      protein: 2.32,
      carbohydrates: 23.51,
      totalFat: 0.83,
      fiber: 1.8,
      sodium: 1.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled/cooked',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_169704',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Whole-grain brown rice cooked without added fat or salt.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic White Bread
    _genericBaselines['bread_white_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_white_bread',
      foodName: 'White Bread',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 265.0,
      protein: 8.85,
      carbohydrates: 49.42,
      totalFat: 3.20,
      fiber: 2.7,
      sodium: 491.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'baked slice',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_174924',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Commercially prepared sliced white wheat bread (USDA SR Legacy FDC 174924 / NDB 18069; FDC 172688 whole-wheat bread conflict resolved).',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Hard-Boiled Egg
    _genericBaselines['egg_boiled_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_boiled_egg',
      foodName: 'Boiled Egg',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 155.0,
      protein: 12.58,
      carbohydrates: 1.12,
      totalFat: 10.61,
      sodium: 124.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'hard-boiled in shell',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_171287',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Whole hard-boiled chicken egg cooked in shell without butter or oil.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Fried Egg
    _genericBaselines['egg_fried_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_fried_egg',
      foodName: 'Fried Egg',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 196.0,
      protein: 13.61,
      carbohydrates: 0.83,
      totalFat: 15.31,
      sodium: 182.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'pan-fried',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_173424',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Whole fried egg cooked with standard cooking fat in skillet.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Mixed Green Garden Salad
    _genericBaselines['salad_green_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_green_salad',
      foodName: 'Green Salad (Garden Salad)',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 20.0,
      protein: 1.50,
      carbohydrates: 3.80,
      totalFat: 0.20,
      fiber: 1.8,
      sodium: 18.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'raw fresh',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_169248',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fresh mixed leafy greens with tomato and cucumber; dressings and croutons excluded.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Greek Salad
    _genericBaselines['salad_greek_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_greek_salad',
      foodName: 'Greek Salad',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 104.0,
      protein: 3.20,
      carbohydrates: 4.50,
      totalFat: 8.30,
      fiber: 1.4,
      sodium: 340.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'tossed with oil and feta',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FNDDS_75146000',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Tossed salad with feta cheese, black olives, tomato, cucumber, olive oil & vinegar (USDA FNDDS food code 75146000 / FDC 2709830; SR Legacy 170425 peas/carrots conflict resolved).',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Fresh Apple
    _genericBaselines['apple_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_apple',
      foodName: 'Apple',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 52.0,
      protein: 0.26,
      carbohydrates: 13.81,
      totalFat: 0.17,
      fiber: 2.4,
      sugar: 10.39,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'raw with skin',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_171688',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fresh raw apple with skin.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Fresh Banana
    _genericBaselines['banana_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_banana',
      foodName: 'Banana',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 89.0,
      protein: 1.09,
      carbohydrates: 22.84,
      totalFat: 0.33,
      fiber: 2.6,
      sugar: 12.23,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'raw peeled',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_173944',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fresh ripe raw banana without peel.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Fresh Orange
    _genericBaselines['orange_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_orange',
      foodName: 'Orange',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 47.0,
      protein: 0.94,
      carbohydrates: 11.75,
      totalFat: 0.12,
      fiber: 2.4,
      sugar: 9.35,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'raw peeled',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_169097',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fresh raw sweet orange sections without peel.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Fresh Strawberries
    _genericBaselines['strawberry_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_strawberry',
      foodName: 'Strawberries',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 32.0,
      protein: 0.67,
      carbohydrates: 7.68,
      totalFat: 0.30,
      fiber: 2.0,
      sugar: 4.89,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'raw fresh',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_167762',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Fresh raw whole strawberries.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Steamed Broccoli
    _genericBaselines['broccoli_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_broccoli',
      foodName: 'Broccoli',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 35.0,
      protein: 2.38,
      carbohydrates: 7.18,
      totalFat: 0.41,
      fiber: 3.3,
      sodium: 41.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'steamed/boiled',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_170379',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Cooked/steamed broccoli florets without added fat or cheese sauce.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Steamed/Boiled Carrots
    _genericBaselines['carrot_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_carrot',
      foodName: 'Carrot',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 35.0,
      protein: 0.76,
      carbohydrates: 8.22,
      totalFat: 0.18,
      fiber: 3.0,
      sodium: 58.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled/steamed',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_170394',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Cooked/steamed sliced carrots without added sugar or butter.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Steamed/Boiled Spinach
    _genericBaselines['spinach_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_spinach',
      foodName: 'Spinach',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 23.0,
      protein: 2.97,
      carbohydrates: 3.75,
      totalFat: 0.26,
      fiber: 2.4,
      sodium: 70.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled/steamed',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_170460',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Cooked spinach leaves drained without butter or cream.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Indian Flatbread (Roti / Chapati)
    _genericBaselines['roti_generic'] = UniversalNutritionProfile(
      id: 'generic_flatbread_roti',
      foodName: 'Roti / Chapati',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 260.0,
      protein: 7.8,
      carbohydrates: 45.0,
      totalFat: 5.5,
      fiber: 5.0,
      sodium: 180.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'griddle-baked',
      source: 'Standard Food Composition Reference',
      sourceIdentifier: 'REF_WHOLE_WHEAT_FLATBREAD',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Unleavened whole-wheat flatbread cooked on griddle with light fat brush.',
      attribution: 'Standard Food Composition Reference (Unverified Generic Reference)',
    );

    // Generic Cooked Lentil Dal
    _genericBaselines['dal_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_dal',
      foodName: 'Lentil Dal',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 116.0,
      protein: 9.02,
      carbohydrates: 20.13,
      totalFat: 0.38,
      fiber: 7.9,
      sodium: 2.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'boiled/simmered',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_172421',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Cooked yellow/brown lentils simmered in water; tempering fat and spices vary.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // Generic Steamed Idli
    _genericBaselines['idli_generic'] = UniversalNutritionProfile(
      id: 'generic_idli',
      foodName: 'Idli',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 156.0,
      protein: 4.8,
      carbohydrates: 31.2,
      totalFat: 1.2,
      fiber: 2.0,
      sodium: 140.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'steamed',
      source: 'Standard Food Composition Reference',
      sourceIdentifier: 'REF_STEAMED_CAKE',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Steamed fermented rice and black gram cake without oil.',
      attribution: 'Standard Food Composition Reference (Unverified Generic Reference)',
    );

    // Generic Dosa
    _genericBaselines['dosa_generic'] = UniversalNutritionProfile(
      id: 'generic_dosa',
      foodName: 'Dosa',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 210.0,
      protein: 4.9,
      carbohydrates: 36.0,
      totalFat: 4.6,
      fiber: 2.2,
      sodium: 220.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'pan-fried',
      source: 'Standard Food Composition Reference',
      sourceIdentifier: 'REF_FERMENTED_CREPE',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Pan-fried fermented rice and black gram crepe prepared with moderate cooking oil.',
      attribution: 'Standard Food Composition Reference (Unverified Generic Reference)',
    );

    // Generic Sushi Baseline (USDA FoodData Central standard reference)
    _genericBaselines['sushi_generic'] = UniversalNutritionProfile(
      id: 'usda_generic_sushi',
      foodName: 'Sushi',
      tier: NutritionProfileTier.closelyRelatedGeneric,
      calories: 143.0,
      protein: 4.0,
      carbohydrates: 27.0,
      totalFat: 1.8,
      fiber: 1.5,
      sugar: 2.5,
      sodium: 380.0,
      servingSize: 100.0,
      servingUnit: 'g',
      preparationState: 'ready-to-eat',
      source: 'USDA FoodData Central',
      sourceIdentifier: 'FDC_173834',
      lastVerifiedDate: DateTime(2026, 2, 1),
      recipeAssumptions: 'Standard mixed sushi roll / nigiri baseline (vinegared rice, nori, fish/vegetable) without extra mayonnaise or sweetened sauces.',
      attribution: 'U.S. Department of Agriculture, Agricultural Research Service (Public Domain)',
    );

    // 3. Documented Recipe Estimates (Mathematically derived from disclosed ingredient formulations)
    // 3.1 Creamy Penne Alfredo Formulation
    const alfredoFormulation = RecipeFormulation(
      recipeId: 'recipe_est_creamy_pasta',
      foodName: 'Creamy Penne Alfredo (Standard Restaurant Recipe)',
      targetBatchMassGrams: 500.0,
      preparationState: 'cooked with cream sauce',
      sourceIdentifier: 'FITFUEL_EST_RECIPE_ALFREDO',
      sugarPer100g: 1.2,
      yieldType: BatchYieldType.calculatedFromPreparedIngredients,
      yieldExplanation:
          'Calculated from the combined masses of already-cooked penne (300g), cream (120g), butter (25g), parmesan (40g), and seasoning (15g) tossed together over low heat without measured moisture reduction.',
      culinaryNotes:
          'Penne pasta tossed with cream, parmesan, and butter. Standard restaurant formulation (500g batch: 300g cooked penne, 120g light cream, 25g butter, 40g parmesan, 15g seasoning). Per 100g derived from 975 kcal batch total. Sodium and fat vary by kitchen.',
      ingredients: [
        RecipeIngredient(
          name: 'Cooked Penne Pasta',
          sourceIdentifier: 'FDC_168936',
          massGrams: 300.0,
          caloriesPer100g: 131.0,
          proteinPer100g: 5.15,
          carbsPer100g: 25.00,
          fatPer100g: 1.05,
          fiberPer100g: 1.80,
          sodiumMgPer100g: 1.00,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 168936 / NDB 20421 (1.0 mg Na / 100g)',
          notes: 'Standard cooked enriched wheat penne.',
        ),
        RecipeIngredient(
          name: 'Light Cooking Cream',
          sourceIdentifier: 'FDC_170859',
          massGrams: 120.0,
          caloriesPer100g: 191.66666666666666,
          proteinPer100g: 2.8333333333333335,
          carbsPer100g: 3.6666666666666665,
          fatPer100g: 18.333333333333332,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 40.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 170859 / NDB 1052 (40.0 mg Na / 100g)',
          notes: 'Commercial light cream (18-20% milkfat).',
        ),
        RecipeIngredient(
          name: 'Unsalted Butter',
          sourceIdentifier: 'FDC_173410',
          massGrams: 25.0,
          caloriesPer100g: 716.0,
          proteinPer100g: 0.80,
          carbsPer100g: 0.0,
          fatPer100g: 81.20,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 11.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 173410 / NDB 1001 (11.0 mg Na / 100g)',
          notes: 'Standard churned dairy butter.',
        ),
        RecipeIngredient(
          name: 'Grated Parmesan Cheese',
          sourceIdentifier: 'FDC_170845',
          massGrams: 40.0,
          caloriesPer100g: 392.5,
          proteinPer100g: 35.75,
          carbsPer100g: 3.25,
          fatPer100g: 25.75,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 1529.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 170845 / NDB 1032 (1,529.0 mg Na / 100g)',
          notes: 'Aged hard parmesan cheese.',
        ),
        RecipeIngredient(
          name: 'Garlic, Salt & Pepper Seasoning Blend',
          sourceIdentifier: 'COMPOSITE_ALFREDO_SEASONING',
          massGrams: 15.0,
          caloriesPer100g: 106.66666666666667,
          proteinPer100g: 3.3333333333333335,
          carbsPer100g: 20.0,
          fatPer100g: 0.6666666666666666,
          fiberPer100g: 1.0,
          sodiumMgPer100g: 6245.461433333333,
          provenanceType: IngredientProvenanceType.definedComposite,
          sodiumCalculationMethod:
              'Calculated from 2.4115g table salt (USDA FDC 173468: 934.65 mg Na) + 11.5885g garlic (1.97 mg Na) + 1.0g black pepper (0.20 mg Na) = 936.82 mg Na in 15g (6245.46 mg Na / 100g)',
          notes: 'Minced garlic, black pepper, and 2.4115g table salt (934.65mg Na).',
          components: [
            IngredientComponent(
              name: 'Table Salt',
              sourceIdentifier: 'FDC_173468',
              massGrams: 2.4115,
              sodiumMg: 934.64917,
              calories: 0.0,
              notes: 'USDA SR Legacy NDB 2047 (38,758 mg Na / 100g = 387.58 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Minced Fresh Garlic',
              sourceIdentifier: 'FDC_170496',
              massGrams: 11.5885,
              sodiumMg: 1.970045,
              calories: 17.27,
              notes: 'USDA SR Legacy NDB 11215 (17.0 mg Na / 100g = 0.17 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Ground Black Pepper',
              sourceIdentifier: 'FDC_170931',
              massGrams: 1.00,
              sodiumMg: 0.20,
              calories: 2.51,
              notes: 'USDA SR Legacy NDB 2030 (20.0 mg Na / 100g = 0.20 mg Na / g)',
            ),
          ],
        ),
      ],
    );
    _recipeFormulations['creamy_pasta_estimate'] = alfredoFormulation;
    _recipeEstimates['creamy_pasta_estimate'] =
        alfredoFormulation.toUniversalNutritionProfile();

    // 3.2 Chicken Tikka Masala Formulation
    const tikkaFormulation = RecipeFormulation(
      recipeId: 'recipe_est_chicken_tikka_masala',
      foodName: 'Chicken Tikka Masala (Standard Restaurant Recipe)',
      targetBatchMassGrams: 600.0,
      preparationState: 'simmered in spiced tomato cream gravy',
      sourceIdentifier: 'FITFUEL_EST_CHICKEN_TIKKA',
      yieldType: BatchYieldType.assumedTargetYield,
      yieldExplanation:
          'Assumed commercial recipe target yield (600g cooked yield from 300g cooked chicken breast, 180g gravy reduction, 75g yogurt-cream blend, 25g fat, 20g seasoning); simmer evaporation is unmeasured.',
      culinaryNotes:
          'chicken breast pieces in spiced tomato, cream, onion sauce. Standard restaurant formulation (600g batch: 300g roasted chicken breast, 180g onion-tomato gravy, 75g yogurt/cream, 25g oil/ghee, 20g spices/salt). Per 100g derived from 895.4 kcal batch total. Oil/cream varies by kitchen.',
      ingredients: [
        RecipeIngredient(
          name: 'Roasted Chicken Breast',
          sourceIdentifier: 'FDC_171077',
          massGrams: 300.0,
          caloriesPer100g: 165.0,
          proteinPer100g: 31.0,
          carbsPer100g: 0.0,
          fatPer100g: 3.60,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 74.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 171077 / NDB 5064 (74.0 mg Na / 100g)',
          notes: 'Boneless, skinless chicken breast roasted.',
        ),
        RecipeIngredient(
          name: 'Spiced Onion-Tomato Gravy Base',
          sourceIdentifier: 'EST_GRAVY_BASE',
          massGrams: 180.0,
          caloriesPer100g: 45.0,
          proteinPer100g: 1.3888888888888888,
          carbsPer100g: 8.055555555555555,
          fatPer100g: 0.8333333333333334,
          fiberPer100g: 2.0,
          sodiumMgPer100g: 500.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod:
              'Culinary baseline estimate (500.0 mg Na / 100g = 900.0 mg Na for 180g)',
          notes: 'Simmered onion, tomato, ginger puree with 900mg Na; kitchen variances occur.',
        ),
        RecipeIngredient(
          name: 'Plain Yogurt & Light Cream Blend',
          sourceIdentifier: 'COMPOSITE_DAIRY_BLEND',
          massGrams: 75.0,
          caloriesPer100g: 104.55555555555556,
          proteinPer100g: 3.257777777777778,
          carbsPer100g: 4.328888888888889,
          fatPer100g: 8.277777777777777,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 44.0,
          provenanceType: IngredientProvenanceType.definedComposite,
          sodiumCalculationMethod:
              'Calculated from 50g whole yogurt (FDC 171284: 23.0 mg Na) + 25g cream (FDC 170859: 10.0 mg Na) = 33.0 mg Na in 75g (44.0 mg Na / 100g)',
          notes:
              'Defined composite dairy mixture mass-weighting 50g whole milk yogurt (FDC 171284) and 25g light cream (FDC 170859); yields 78.42 kcal (104.56 kcal/100g) and 6.21g fat (8.28g/100g).',
          components: [
            IngredientComponent(
              name: 'Whole Milk Plain Yogurt',
              sourceIdentifier: 'FDC_171284',
              massGrams: 50.0,
              sodiumMg: 23.0,
              calories: 30.5,
              notes: 'USDA SR Legacy NDB 1119 (61 kcal / 100g, 3.47g P, 4.66g C, 3.25g F, 46 mg Na / 100g)',
            ),
            IngredientComponent(
              name: 'Light Cooking Cream',
              sourceIdentifier: 'FDC_170859',
              massGrams: 25.0,
              sodiumMg: 10.0,
              calories: 47.92,
              notes: 'USDA SR Legacy NDB 1052 (191.67 kcal / 100g, 2.833g P, 3.667g C, 18.333g F, 40 mg Na / 100g)',
            ),
          ],
        ),
        RecipeIngredient(
          name: 'Vegetable Cooking Oil / Ghee',
          sourceIdentifier: 'EST_COOKING_FAT',
          massGrams: 25.0,
          caloriesPer100g: 884.0,
          proteinPer100g: 0.0,
          carbsPer100g: 0.0,
          fatPer100g: 100.0,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 0.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod: 'Pure cooking fat (0.0 mg Na)',
          notes: 'Refined vegetable cooking oil/clarified butter.',
        ),
        RecipeIngredient(
          name: 'Ginger, Garlic, Garam Masala & Salt',
          sourceIdentifier: 'COMPOSITE_TIKKA_SPICE_BLEND',
          massGrams: 20.0,
          caloriesPer100g: 100.0,
          proteinPer100g: 3.0,
          carbsPer100g: 17.5,
          fatPer100g: 1.0,
          fiberPer100g: 10.0,
          sodiumMgPer100g: 5625.26155,
          provenanceType: IngredientProvenanceType.definedComposite,
          sodiumCalculationMethod:
              'Calculated from 2.891g table salt (USDA FDC 173468: 1120.49 mg Na) + 12.109g ginger/garlic blend (2.06 mg Na) + 5.0g garam masala (2.50 mg Na) = 1125.05 mg Na in 20g (5625.26 mg Na / 100g)',
          notes: 'Tikka spices with 2.891g salt (1120.49mg Na) plus ginger/garlic and garam masala sodium.',
          components: [
            IngredientComponent(
              name: 'Table Salt',
              sourceIdentifier: 'FDC_173468',
              massGrams: 2.891,
              sodiumMg: 1120.49378,
              calories: 0.0,
              notes: 'USDA SR Legacy NDB 2047 (38,758 mg Na / 100g = 387.58 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Fresh Minced Ginger & Garlic Blend',
              sourceIdentifier: 'EST_GINGER_GARLIC',
              massGrams: 12.109,
              sodiumMg: 2.05853,
              calories: 15.0,
              notes:
                  'Fresh ginger root (FDC 169231: 13 mg Na/100g) and garlic (FDC 170496: 17 mg Na/100g); evaluated at garlic baseline (17.0 mg Na / 100g = 0.17 mg/g) as documented upper-bound culinary baseline approximation',
            ),
            IngredientComponent(
              name: 'Garam Masala & Indian Spices',
              sourceIdentifier: 'EST_GARAM_MASALA',
              massGrams: 5.0,
              sodiumMg: 2.50,
              calories: 15.0,
              notes: 'Culinary baseline estimate for commercial ground spice blend (50.0 mg Na / 100g)',
            ),
          ],
        ),
      ],
    );
    _recipeFormulations['chicken_tikka_masala_estimate'] = tikkaFormulation;
    _recipeEstimates['chicken_tikka_masala_estimate'] =
        tikkaFormulation.toUniversalNutritionProfile();

    // 3.3 Vegetable Fried Rice Formulation
    const friedRiceFormulation = RecipeFormulation(
      recipeId: 'recipe_est_veg_fried_rice',
      foodName: 'Vegetable Fried Rice (Standard Restaurant Recipe)',
      targetBatchMassGrams: 500.0,
      preparationState: 'wok-fried',
      sourceIdentifier: 'FITFUEL_EST_VEG_FRIED_RICE',
      yieldType: BatchYieldType.assumedTargetYield,
      yieldExplanation:
          'Assumed commercial recipe target yield (500g cooked yield from 360g cooked rice, 100g vegetables, 25g oil, 15g seasoning); quick wok stir-fry steam loss is unmeasured.',
      culinaryNotes:
          'Cooked white rice stir-fried with mixed vegetables, soy sauce, and cooking oil. Standard formulation (500g batch: 360g cooked white rice, 100g mixed vegetables, 25g stir-fry oil, 15g soy sauce & seasonings). Per 100g derived from 754 kcal batch total.',
      ingredients: [
        RecipeIngredient(
          name: 'Cooked White Rice',
          sourceIdentifier: 'FDC_168878',
          massGrams: 360.0,
          caloriesPer100g: 130.0,
          proteinPer100g: 2.688888888888889,
          carbsPer100g: 28.166666666666668,
          fatPer100g: 0.2777777777777778,
          fiberPer100g: 0.40,
          sodiumMgPer100g: 1.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod:
              'USDA FoodData Central SR Legacy FDC 168878 / NDB 20445 (1.0 mg Na / 100g)',
          notes: 'Steamed long-grain white rice.',
        ),
        RecipeIngredient(
          name: 'Diced Mixed Vegetables',
          sourceIdentifier: 'EST_MIXED_VEG',
          massGrams: 100.0,
          caloriesPer100g: 50.0,
          proteinPer100g: 2.50,
          carbsPer100g: 10.0,
          fatPer100g: 0.40,
          fiberPer100g: 2.80,
          sodiumMgPer100g: 25.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod:
              'Culinary baseline estimate (25.0 mg Na / 100g = 25.0 mg Na for 100g)',
          notes: 'Carrots, green peas, corn kernels, scallions.',
        ),
        RecipeIngredient(
          name: 'Sesame & Vegetable Stir-Fry Oil',
          sourceIdentifier: 'EST_STIR_FRY_FAT',
          massGrams: 25.0,
          caloriesPer100g: 884.0,
          proteinPer100g: 0.0,
          carbsPer100g: 0.0,
          fatPer100g: 100.0,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 0.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod: 'Pure cooking fat (0.0 mg Na)',
          notes: 'Vegetable and sesame cooking oil blend.',
        ),
        RecipeIngredient(
          name: 'Soy Sauce, Garlic & Seasoning',
          sourceIdentifier: 'COMPOSITE_SOY_SEASONING',
          massGrams: 15.0,
          caloriesPer100g: 100.0,
          proteinPer100g: 10.0,
          carbsPer100g: 8.0,
          fatPer100g: 0.6666666666666666,
          fiberPer100g: 2.0,
          sodiumMgPer100g: 10477.934466666667,
          provenanceType: IngredientProvenanceType.definedComposite,
          sodiumCalculationMethod:
              'Calculated from 10.0g soy sauce (USDA FDC 174277: 549.30 mg Na) + 2.637g table salt (USDA FDC 173468: 1022.05 mg Na) + 1.863g garlic (0.32 mg Na) + 0.5g white pepper (0.025 mg Na) = 1571.69 mg Na in 15g (10477.93 mg Na / 100g)',
          notes:
              'Defined composite seasoning: 10.0g soy sauce (FDC 174277) + 2.637g table salt (FDC 173468) + 1.863g garlic + 0.5g pepper.',
          components: [
            IngredientComponent(
              name: 'Soy Sauce (Shoyu)',
              sourceIdentifier: 'FDC_174277',
              massGrams: 10.00,
              sodiumMg: 549.30,
              calories: 5.30,
              notes: 'USDA SR Legacy NDB 16124 (5493.0 mg Na / 100g)',
            ),
            IngredientComponent(
              name: 'Table Salt',
              sourceIdentifier: 'FDC_173468',
              massGrams: 2.637,
              sodiumMg: 1022.04846,
              calories: 0.0,
              notes: 'USDA SR Legacy NDB 2047 (38,758 mg Na / 100g = 387.58 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Minced Fresh Garlic',
              sourceIdentifier: 'FDC_170496',
              massGrams: 1.863,
              sodiumMg: 0.31671,
              calories: 2.78,
              notes: 'USDA SR Legacy NDB 11215 (17.0 mg Na / 100g = 0.17 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Ground White Pepper',
              sourceIdentifier: 'FDC_170935',
              massGrams: 0.50,
              sodiumMg: 0.025,
              calories: 1.48,
              notes: 'USDA SR Legacy NDB 2032 (5.0 mg Na / 100g = 0.05 mg Na / g)',
            ),
          ],
        ),
      ],
    );
    _recipeFormulations['vegetable_fried_rice_estimate'] = friedRiceFormulation;
    _recipeEstimates['vegetable_fried_rice_estimate'] =
        friedRiceFormulation.toUniversalNutritionProfile();

    // 3.4 Mixed Vegetable Curry Formulation
    const vegCurryFormulation = RecipeFormulation(
      recipeId: 'recipe_est_vegetable_curry',
      foodName: 'Vegetable Curry (Standard Mixed Vegetable Gravy)',
      targetBatchMassGrams: 600.0,
      preparationState: 'simmered gravy',
      sourceIdentifier: 'FITFUEL_EST_VEG_CURRY',
      yieldType: BatchYieldType.assumedTargetYield,
      yieldExplanation:
          'Assumed commercial recipe target yield (600g cooked yield from 350g mixed vegetables, 180g gravy base, 20g oil, 15g spices/salt, 35g net retained simmer water); dishes simmer down to target weight with unmeasured evaporation.',
      culinaryNotes:
          'Mixed seasonal vegetables simmered in spiced onion-tomato curry with vegetable oil. Standard formulation (600g batch: 350g mixed vegetables, 180g onion-tomato gravy base, 20g oil, 15g spices/salt, 35g added simmer water). Per 100g derived from 439 kcal batch total. Net 35g liquid represents retained cooking water.',
      ingredients: [
        RecipeIngredient(
          name: 'Mixed Seasonal Vegetables',
          sourceIdentifier: 'EST_SEASONAL_VEG',
          massGrams: 350.0,
          caloriesPer100g: 50.0,
          proteinPer100g: 2.00,
          carbsPer100g: 9.142857142857142,
          fatPer100g: 0.42857142857142855,
          fiberPer100g: 2.80,
          sodiumMgPer100g: 30.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod:
              'Culinary baseline estimate (30.0 mg Na / 100g = 105.0 mg Na for 350g)',
          notes: 'Cauliflower, green beans, potato cubes, carrots.',
        ),
        RecipeIngredient(
          name: 'Onion-Tomato Curry Gravy Base',
          sourceIdentifier: 'EST_CURRY_GRAVY',
          massGrams: 180.0,
          caloriesPer100g: 40.0,
          proteinPer100g: 1.3888888888888888,
          carbsPer100g: 7.222222222222222,
          fatPer100g: 0.5555555555555556,
          fiberPer100g: 1.50,
          sodiumMgPer100g: 280.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod:
              'Culinary baseline estimate (280.0 mg Na / 100g = 504.0 mg Na for 180g)',
          notes: 'Simmered spiced onion and tomato gravy (504mg Na).',
        ),
        RecipeIngredient(
          name: 'Vegetable Cooking Oil',
          sourceIdentifier: 'EST_COOKING_FAT',
          massGrams: 20.0,
          caloriesPer100g: 885.0,
          proteinPer100g: 0.0,
          carbsPer100g: 0.0,
          fatPer100g: 100.0,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 0.0,
          provenanceType: IngredientProvenanceType.culinaryEstimate,
          sodiumCalculationMethod: 'Pure cooking fat (0.0 mg Na)',
          notes: 'Refined cooking oil.',
        ),
        RecipeIngredient(
          name: 'Indian Curry Spices & Salt',
          sourceIdentifier: 'COMPOSITE_CURRY_SPICES',
          massGrams: 15.0,
          caloriesPer100g: 100.0,
          proteinPer100g: 3.3333333333333335,
          carbsPer100g: 20.0,
          fatPer100g: 2.0,
          fiberPer100g: 10.0,
          sodiumMgPer100g: 8371.955046666667,
          provenanceType: IngredientProvenanceType.definedComposite,
          sodiumCalculationMethod:
              'Calculated from 3.2277g table salt (USDA FDC 173468: 1250.99 mg Na) + 8.0g curry powder (USDA FDC 171323: 4.16 mg Na) + 3.7723g ginger/garlic blend (0.64 mg Na) = 1255.79 mg Na in 15g (8371.96 mg Na / 100g)',
          notes: 'Curry spice blend with 3.2277g salt (1250.99mg Na) plus curry powder and ginger/garlic sodium.',
          components: [
            IngredientComponent(
              name: 'Table Salt',
              sourceIdentifier: 'FDC_173468',
              massGrams: 3.2277,
              sodiumMg: 1250.991966,
              calories: 0.0,
              notes: 'USDA SR Legacy NDB 2047 (38,758 mg Na / 100g = 387.58 mg Na / g)',
            ),
            IngredientComponent(
              name: 'Ground Curry Powder (Turmeric, Cumin, Coriander, Chili)',
              sourceIdentifier: 'FDC_171323',
              massGrams: 8.00,
              sodiumMg: 4.16,
              calories: 26.0,
              notes: 'USDA SR Legacy FDC 171323 / NDB 2015 (325 kcal / 100g, 52.0 mg Na / 100g)',
            ),
            IngredientComponent(
              name: 'Fresh Minced Ginger & Garlic Blend',
              sourceIdentifier: 'EST_GINGER_GARLIC',
              massGrams: 3.7723,
              sodiumMg: 0.641291,
              calories: 5.0,
              notes:
                  'Fresh ginger root (FDC 169231: 13 mg Na/100g) and garlic (FDC 170496: 17 mg Na/100g); evaluated at garlic baseline (17.0 mg Na / 100g = 0.17 mg/g) as documented upper-bound culinary baseline approximation',
            ),
          ],
        ),
        RecipeIngredient(
          name: 'Added Simmer Water (Retained Cooking Liquid)',
          sourceIdentifier: 'WATER',
          massGrams: 35.0,
          caloriesPer100g: 0.0,
          proteinPer100g: 0.0,
          carbsPer100g: 0.0,
          fatPer100g: 0.0,
          fiberPer100g: 0.0,
          sodiumMgPer100g: 0.0,
          provenanceType: IngredientProvenanceType.directlySourced,
          sodiumCalculationMethod: 'Tap/filtered water (0.0 mg Na)',
          notes:
              'Net cooking liquid volume retained in final curry yield after evaporation.',
        ),
      ],
    );
    _recipeFormulations['vegetable_curry_estimate'] = vegCurryFormulation;
    _recipeEstimates['vegetable_curry_estimate'] =
        vegCurryFormulation.toUniversalNutritionProfile();

    // Unified multi-tier profile indexing for canonical ID & slug lookup
    _allProfilesById.clear();
    for (final p in _profilesById.values) {
      _allProfilesById[p.id] = p;
    }
    for (final entry in _genericBaselines.entries) {
      _allProfilesById[entry.key] = entry.value;
      _allProfilesById[entry.value.id] = entry.value;
    }
    for (final entry in _recipeEstimates.entries) {
      _allProfilesById[entry.key] = entry.value;
      _allProfilesById[entry.value.id] = entry.value;
    }
  }

  void _logResolution(
    OpenVocabularyFoodCandidate candidate,
    UniversalNutritionResolutionResult res,
  ) {
    final food = res.matchedCatalogFood;
    final prof = res.profile;
    final serving = food != null
        ? '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}'
        : (prof != null ? '${prof.servingSize.toStringAsFixed(0)} ${prof.servingUnit}' : '0 g');
    final missing = <String>[];
    if (food?.calories == null && prof?.calories == null) missing.add('calories');
    if (food?.protein == null && prof?.protein == null) missing.add('protein');
    if (food?.carbohydrates == null && prof?.carbohydrates == null) missing.add('carbohydrates');
    if (food?.fats == null && prof?.totalFat == null) missing.add('fat');
    final missingStr = missing.isEmpty ? 'none' : missing.join(',');

    debugPrint(
      '[NutritionResolution] candidate=${candidate.canonicalFoodId} '
      'profile=${prof?.id ?? "none"} outcome=${res.tier.name} '
      'serving=$serving '
      'missingFields=$missingStr '
      'reason=${res.explanation}',
    );
  }

  /// Resolves an open-vocabulary candidate against universal nutrition profiles.
  UniversalNutritionResolutionResult resolveCandidate(
    OpenVocabularyFoodCandidate candidate, {
    List<FoodEntity> foodCatalog = const [],
    CanonicalFoodEntry? canonicalEntry,
  }) {
    final result = _resolveCandidateInternal(
      candidate,
      foodCatalog: foodCatalog,
      canonicalEntry: canonicalEntry,
    );
    _logResolution(candidate, result);
    return result;
  }

  UniversalNutritionResolutionResult _resolveCandidateInternal(
    OpenVocabularyFoodCandidate candidate, {
    List<FoodEntity> foodCatalog = const [],
    CanonicalFoodEntry? canonicalEntry,
  }) {
    // 1. Try exact FitFuel catalog match first (Verified Exact)
    final catalogMatch = TrustedOpenVocabNutritionMapper.resolveTrustedCatalogFood(
      candidate,
      foodCatalog: foodCatalog,
    );

    if (catalogMatch != null) {
      final exactProfile = _profilesById[catalogMatch.id] ??
          UniversalNutritionProfile(
            id: catalogMatch.id,
            foodName: catalogMatch.name,
            tier: NutritionProfileTier.verifiedExact,
            calories: catalogMatch.calories,
            protein: catalogMatch.protein,
            carbohydrates: catalogMatch.carbohydrates,
            totalFat: catalogMatch.fats,
            servingSize: catalogMatch.servingSize,
            servingUnit: catalogMatch.servingUnit,
            source: 'FitFuel Curated Database',
            sourceIdentifier: catalogMatch.id,
            lastVerifiedDate: DateTime(2026, 1, 1),
          );

      return UniversalNutritionResolutionResult(
        profile: exactProfile,
        tier: NutritionProfileTier.verifiedExact,
        matchedCatalogFood: catalogMatch.copyWith(
          name: candidate.displayName,
        ),
        explanation: 'Curated profile from FitFuel food database.',
        attribution: exactProfile.attribution,
      );
    }

    // 2. Check canonical entry's linked nutrition IDs if provided
    if (canonicalEntry != null && canonicalEntry.nutritionProfileIds.isNotEmpty) {
      for (final profileId in canonicalEntry.nutritionProfileIds) {
        final profile = _allProfilesById[profileId] ?? _profilesById[profileId];
        if (profile != null) {
          return UniversalNutritionResolutionResult(
            profile: profile,
            tier: canonicalEntry.nutritionTier,
            matchedCatalogFood: profile.toFoodEntity(),
            explanation: 'Linked from global food taxonomy.',
            attribution: profile.attribution,
          );
        }
      }
    }

    // 3. Check for specific recipe-based estimates with stated culinary assumptions
    final idLower = candidate.canonicalFoodId.toLowerCase();
    final nameLower = candidate.canonicalName.toLowerCase();
    final idNormalized = idLower.replaceAll('_', ' ');

    // Creamy / Alfredo Pasta Recipe Estimate
    final isAlfredo = idLower.contains('alfredo') ||
        nameLower.contains('alfredo') ||
        (nameLower.contains('creamy') && nameLower.contains('pasta'));
    if (isAlfredo) {
      final estimate = _recipeEstimates['creamy_pasta_estimate']!;
      return UniversalNutritionResolutionResult(
        profile: estimate,
        tier: NutritionProfileTier.recipeEstimate,
        matchedCatalogFood:
            estimate.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Recipe estimate with standard culinary assumptions.',
        recipeAssumptions: estimate.recipeAssumptions,
        attribution: estimate.attribution,
      );
    }

    // Chicken Tikka Masala / Butter Chicken Recipe Estimate
    final isChickenTikka = RegExp(r'\b(tikka masala|butter chicken|chicken curry)\b',
                caseSensitive: false)
            .hasMatch(nameLower) ||
        idLower.contains('tikka_masala') ||
        idLower.contains('butter_chicken');
    if (isChickenTikka) {
      final estimate = _recipeEstimates['chicken_tikka_masala_estimate']!;
      return UniversalNutritionResolutionResult(
        profile: estimate,
        tier: NutritionProfileTier.recipeEstimate,
        matchedCatalogFood:
            estimate.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Recipe estimate with standard culinary assumptions.',
        recipeAssumptions: estimate.recipeAssumptions,
        attribution: estimate.attribution,
      );
    }

    // Vegetable Fried Rice Recipe Estimate
    final isFriedRice = RegExp(r'\b(fried rice)\b', caseSensitive: false)
            .hasMatch(nameLower) ||
        idLower.contains('fried_rice');
    if (isFriedRice) {
      final estimate = _recipeEstimates['vegetable_fried_rice_estimate']!;
      return UniversalNutritionResolutionResult(
        profile: estimate,
        tier: NutritionProfileTier.recipeEstimate,
        matchedCatalogFood:
            estimate.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Recipe estimate with standard culinary assumptions.',
        recipeAssumptions: estimate.recipeAssumptions,
        attribution: estimate.attribution,
      );
    }

    // Meat Curry / Stew Recipe Estimate (Nihari, Mutton/Lamb/Beef Curry)
    final isMeatCurry = RegExp(
            r'\b(nihari|mutton curry|meat curry|beef curry|lamb curry|goat curry|gosht|rogan josh)\b',
            caseSensitive: false)
        .hasMatch(nameLower) ||
        idLower.contains('nihari');
    if (isMeatCurry) {
      final muttonProfile = _profilesById['predefined_mutton_curry'];
      if (muttonProfile != null) {
        return UniversalNutritionResolutionResult(
          profile: muttonProfile,
          tier: NutritionProfileTier.verifiedExact,
          matchedCatalogFood: muttonProfile.toFoodEntity(
            nameOverride: candidate.displayName,
          ),
          explanation: 'Curated Indian meat curry profile from FitFuel food database.',
          attribution: muttonProfile.attribution,
        );
      }
    }

    // Mixed Vegetable Curry / Rich Sabzi Recipe Estimate
    final isVegCurry = RegExp(
            r'\b(curry|curries|veg curry|vegetable curry|mixed vegetable curry|sabzi curry|mixed curry|malai kofta|navratan korma|gatte ki sabzi|korma|kofta|kaju curry|kofta curry|soya chaap|soya chaap masala|dhokar dalna|odia dalma|pav bhaji)\b',
            caseSensitive: false)
        .hasMatch(nameLower) ||
        idLower == 'curry' ||
        idLower == 'openvocab_curry' ||
        idLower == 'openvocab_vegetable_curry' ||
        idLower.contains('veg_curry') ||
        idLower.contains('pav_bhaji') ||
        idLower.contains('malai_kofta') ||
        idLower.contains('navratan_korma');
    if (isVegCurry) {
      final estimate = _recipeEstimates['vegetable_curry_estimate']!;
      return UniversalNutritionResolutionResult(
        profile: estimate,
        tier: NutritionProfileTier.recipeEstimate,
        matchedCatalogFood:
            estimate.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Recipe estimate with standard culinary assumptions.',
        recipeAssumptions: estimate.recipeAssumptions,
        attribution: estimate.attribution,
      );
    }

    // 4. Check for closely related generic baseline profiles using strict word-boundary matching
    // (Prevents misclassifying dishes like pastrami, fish paste, tomato paste, creamy pasta as generic plain cooked pasta)
    final pastaRegex = RegExp(
        r'\b(pasta|spaghetti|penne|macaroni|fettuccine|linguine|fusilli|rigatoni)\b',
        caseSensitive: false);
    final isPasta = (pastaRegex.hasMatch(nameLower) ||
            pastaRegex.hasMatch(idNormalized)) &&
        !nameLower.contains('pastrami') &&
        !nameLower.contains('paste') &&
        !nameLower.contains('creamy') &&
        !idLower.contains('creamy');
    if (isPasta) {
      final generic = _genericBaselines['pasta_generic']!;
      final pastaCatalog = foodCatalog
              .where((f) => f.id == 'predefined_standard_pasta')
              .firstOrNull ??
          generic.toFoodEntity(nameOverride: candidate.displayName);
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood: pastaCatalog,
        explanation:
            'Generic pasta baseline profile. Verify cooking fat and sauces.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final pizzaRegex = RegExp(r'\b(pizza|margherita)\b', caseSensitive: false);
    final isPizza =
        pizzaRegex.hasMatch(nameLower) || pizzaRegex.hasMatch(idNormalized);
    if (isPizza) {
      final generic = _genericBaselines['pizza_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation:
            'Generic cheese pizza baseline. Verify toppings and crust thickness.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final burgerRegex =
        RegExp(r'\b(burger|hamburger|cheeseburger)\b', caseSensitive: false);
    final isBurger =
        burgerRegex.hasMatch(nameLower) || burgerRegex.hasMatch(idNormalized);
    if (isBurger) {
      final generic = _genericBaselines['burger_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation:
            'Generic single hamburger baseline. Condiments not included.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Rice Baselines (Brown Rice vs White Rice)
    final isBrownRice =
        RegExp(r'\b(brown rice)\b', caseSensitive: false).hasMatch(nameLower);
    if (isBrownRice) {
      final generic = _genericBaselines['rice_brown_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic cooked brown rice baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isWhiteRice = (RegExp(
                    r'\b(rice|white rice|steamed rice|boiled rice|jasmine rice|basmati rice|chawal)\b',
                    caseSensitive: false)
                .hasMatch(nameLower) ||
            RegExp(r'\b(rice|white_rice|steamed_rice)\b', caseSensitive: false)
                .hasMatch(idNormalized)) &&
        !nameLower.contains('licorice') &&
        !nameLower.contains('pudding') &&
        !nameLower.contains('kheer') &&
        !nameLower.contains('cake') &&
        !nameLower.contains('sticky') &&
        !nameLower.contains('fried');
    if (isWhiteRice) {
      final generic = _genericBaselines['rice_white_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic cooked white rice baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Bread Baseline
    final isBread = RegExp(
                r'\b(bread|white bread|toast|sandwich bread|sliced bread)\b',
                caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('shortbread') &&
        !nameLower.contains('gingerbread') &&
        !nameLower.contains('sweetbread') &&
        !nameLower.contains('cornbread') &&
        !nameLower.contains('crumbs');
    if (isBread) {
      final generic = _genericBaselines['bread_white_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic white bread baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Egg Baselines (Fried Egg vs Boiled/Cooked Egg)
    final isEggFried = RegExp(
            r'\b(fried egg|sunny side up|fried eggs|over easy|over medium|over hard)\b',
            caseSensitive: false)
        .hasMatch(nameLower);
    if (isEggFried) {
      final generic = _genericBaselines['egg_fried_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic fried egg baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isEggBoiled = (RegExp(
                    r'\b(boiled egg|boiled eggs|poached egg|poached eggs|hard-boiled egg|soft-boiled egg|egg|eggs)\b',
                    caseSensitive: false)
                .hasMatch(nameLower) ||
            idLower.contains('boiled_egg')) &&
        !nameLower.contains('eggplant') &&
        !idLower.contains('eggplant') &&
        !nameLower.contains('roll') &&
        !nameLower.contains('noodle') &&
        !nameLower.contains('fried');
    if (isEggBoiled) {
      final generic = _genericBaselines['egg_boiled_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic whole boiled egg baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Salad Baselines (Greek Salad vs Green Salad)
    final isGreekSalad = RegExp(
            r'\b(greek salad|caprese salad|tabbouleh salad|tabbouleh|som tum)\b',
            caseSensitive: false)
        .hasMatch(nameLower);
    if (isGreekSalad) {
      final generic = _genericBaselines['salad_greek_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic Greek salad baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isGreenSalad = RegExp(
                r'\b(salad|green salad|garden salad|mixed salad|tossed salad|side salad)\b',
                caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('fruit') &&
        !nameLower.contains('dragonfruit') &&
        !nameLower.contains('tuna') &&
        !nameLower.contains('chicken') &&
        !nameLower.contains('potato') &&
        !nameLower.contains('egg') &&
        !nameLower.contains('pasta');
    if (isGreenSalad) {
      final generic = _genericBaselines['salad_green_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic garden salad baseline profile (undressed).',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Fruit Baselines
    final isApple = RegExp(r'\b(apple|apples)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('pineapple') &&
        !nameLower.contains('custard') &&
        !nameLower.contains('cider') &&
        !nameLower.contains('pie') &&
        !nameLower.contains('sauce');
    if (isApple) {
      final generic = _genericBaselines['apple_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic fresh apple baseline profile with skin.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isBanana = RegExp(r'\b(banana|bananas)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('bread') &&
        !nameLower.contains('split') &&
        !nameLower.contains('pudding') &&
        !nameLower.contains('chips');
    if (isBanana) {
      final generic = _genericBaselines['banana_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic fresh banana baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isOrange = RegExp(r'\b(orange|oranges)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('chicken') &&
        !nameLower.contains('juice') &&
        !nameLower.contains('peel') &&
        !nameLower.contains('marmalade');
    if (isOrange) {
      final generic = _genericBaselines['orange_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic sweet orange baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isStrawberry =
        RegExp(r'\b(strawberry|strawberries)\b', caseSensitive: false)
                .hasMatch(nameLower) &&
            !nameLower.contains('jam') &&
            !nameLower.contains('shortcake') &&
            !nameLower.contains('pie') &&
            !nameLower.contains('ice cream');
    if (isStrawberry) {
      final generic = _genericBaselines['strawberry_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic fresh strawberries baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Vegetable Baselines
    final isBroccoli = RegExp(r'\b(broccoli)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('cheddar') &&
        !nameLower.contains('soup');
    if (isBroccoli) {
      final generic = _genericBaselines['broccoli_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic steamed broccoli florets baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isCarrot = RegExp(r'\b(carrot|carrots)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('cake') &&
        !nameLower.contains('halwa') &&
        !nameLower.contains('juice');
    if (isCarrot) {
      final generic = _genericBaselines['carrot_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic steamed/boiled carrots baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    final isSpinach = RegExp(r'\b(spinach)\b', caseSensitive: false)
            .hasMatch(nameLower) &&
        !nameLower.contains('dip') &&
        !nameLower.contains('paneer') &&
        !nameLower.contains('pie');
    if (isSpinach) {
      final generic = _genericBaselines['spinach_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic cooked spinach leaves baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Indian Flatbread (Roti / Chapati / Naan)
    final isRoti = RegExp(
            r'\b(roti|rotis|chapati|chapatis|chapatti|phulka|fulka|flatbread|naan|naans|butter naan|garlic naan|akki roti)\b',
            caseSensitive: false)
        .hasMatch(nameLower);
    if (isRoti) {
      final generic = _genericBaselines['roti_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation:
            'Generic Indian flatbread baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Dal / Lentils
    final isDal = RegExp(
            r'\b(dal|daal|dhal|lentil|lentils|cooked lentils|lentil soup|dal makhani|panchmel dal|cholar dal|dal pakwan|dal dhokli|odia dalma|dal baati churma)\b',
            caseSensitive: false)
        .hasMatch(nameLower);
    if (isDal) {
      final generic = _genericBaselines['dal_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic cooked lentil dal baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Idli
    final isIdli = RegExp(r'\b(idli|idlis|idly|idlys)\b', caseSensitive: false)
        .hasMatch(nameLower);
    if (isIdli) {
      final generic = _genericBaselines['idli_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic steamed idli baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Dosa
    final isDosa = RegExp(r'\b(dosa|dosas)\b', caseSensitive: false)
        .hasMatch(nameLower);
    if (isDosa) {
      final generic = _genericBaselines['dosa_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic fermented dosa crepe baseline profile.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // Sushi / Maki / Nigiri / California Roll (Note: Kimbap is distinct and excluded from generic sushi)
    final sushiRegex = RegExp(
        r'\b(sushi|maki|nigiri|california roll)\b',
        caseSensitive: false);
    final isSushi = (sushiRegex.hasMatch(nameLower) ||
            idLower.contains('sushi') ||
            idNormalized.contains('sushi') ||
            idLower.contains('california_roll')) &&
        !nameLower.contains('kimbap') &&
        !nameLower.contains('gimbap') &&
        !idLower.contains('kimbap') &&
        !idLower.contains('gimbap');
    if (isSushi) {
      final generic = _genericBaselines['sushi_generic']!;
      return UniversalNutritionResolutionResult(
        profile: generic,
        tier: NutritionProfileTier.closelyRelatedGeneric,
        matchedCatalogFood:
            generic.toFoodEntity(nameOverride: candidate.displayName),
        explanation: 'Generic sushi baseline profile from USDA FoodData Central.',
        recipeAssumptions: generic.recipeAssumptions,
        attribution: generic.attribution,
      );
    }

    // 5. Honest fallback: Nutrition Unavailable (no fabricated macros)
    return UniversalNutritionResolutionResult(
      tier: NutritionProfileTier.unavailable,
      matchedCatalogFood: null,
      explanation: 'No verified profile or defensible estimate exists for "${candidate.displayName}". Please choose from search.',
    );
  }
}
