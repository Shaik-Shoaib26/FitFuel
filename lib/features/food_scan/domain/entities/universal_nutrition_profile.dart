import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';

/// Comprehensive universal nutrition profile supporting multi-source nutrition data
/// (FitFuel Curated, USDA FoodData Central, Open Food Facts, etc.).
class UniversalNutritionProfile {
  final String id;
  final String foodName;
  final NutritionProfileTier tier;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double totalFat;
  final double? fiber;
  final double? sugar;
  final double? sodium;
  final double servingSize;
  final String servingUnit;
  final String? preparationState;
  final String source;
  final String? sourceIdentifier;
  final DateTime lastVerifiedDate;
  final String? recipeAssumptions;
  final String? attribution;

  const UniversalNutritionProfile({
    required this.id,
    required this.foodName,
    required this.tier,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.totalFat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingSize = 100.0,
    this.servingUnit = 'g',
    this.preparationState,
    required this.source,
    this.sourceIdentifier,
    required this.lastVerifiedDate,
    this.recipeAssumptions,
    this.attribution,
  });

  /// Whether this profile's source is externally traceable to an official accession/database ID.
  bool get isSourceTraceable {
    if (source == 'USDA FoodData Central') {
      return sourceIdentifier != null &&
          (sourceIdentifier!.startsWith('FDC_') ||
              sourceIdentifier!.startsWith('FNDDS_'));
    }
    if (source == 'FitFuel Curated Database') {
      return sourceIdentifier != null && sourceIdentifier!.startsWith('predefined_');
    }
    return false;
  }

  /// Whether the nutrition data has been formally verified against a traceable database.
  bool get isProvenanceVerified => isSourceTraceable;

  /// High-level classification of this profile: curated, generic, recipe-estimated, or user-entered.
  String get profileClassification {
    switch (tier) {
      case NutritionProfileTier.verifiedExact:
        return 'curated';
      case NutritionProfileTier.closelyRelatedGeneric:
        return 'generic';
      case NutritionProfileTier.recipeEstimate:
        return 'recipe-estimated';
      case NutritionProfileTier.unavailable:
        return 'unavailable';
    }
  }

  /// Measurement basis: 'per 100 g' or 'per serving (X g)'.
  String get measurementBasis =>
      servingSize == 100.0 && servingUnit == 'g'
          ? 'per 100 g'
          : 'per serving (${servingSize.toStringAsFixed(0)} $servingUnit)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'foodName': foodName,
        'tier': tier.name,
        'calories': calories,
        'protein': protein,
        'carbohydrates': carbohydrates,
        'totalFat': totalFat,
        if (fiber != null) 'fiber': fiber,
        if (sugar != null) 'sugar': sugar,
        if (sodium != null) 'sodium': sodium,
        'servingSize': servingSize,
        'servingUnit': servingUnit,
        if (preparationState != null) 'preparationState': preparationState,
        'source': source,
        if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
        'lastVerifiedDate': lastVerifiedDate.toIso8601String(),
        if (recipeAssumptions != null) 'recipeAssumptions': recipeAssumptions,
        if (attribution != null) 'attribution': attribution,
      };

  factory UniversalNutritionProfile.fromJson(Map<String, dynamic> json) {
    return UniversalNutritionProfile(
      id: json['id'] as String? ?? '',
      foodName: json['foodName'] as String? ?? '',
      tier: NutritionProfileTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => NutritionProfileTier.unavailable,
      ),
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
      servingSize: (json['servingSize'] as num?)?.toDouble() ?? 100.0,
      servingUnit: json['servingUnit'] as String? ?? 'g',
      preparationState: json['preparationState'] as String?,
      source: json['source'] as String? ?? 'FitFuel Curated',
      sourceIdentifier: json['sourceIdentifier'] as String?,
      lastVerifiedDate: json['lastVerifiedDate'] != null
          ? DateTime.tryParse(json['lastVerifiedDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      recipeAssumptions: json['recipeAssumptions'] as String?,
      attribution: json['attribution'] as String?,
    );
  }

  /// Converts this universal nutrition profile to a FitFuel [FoodEntity] for
  /// rendering in UI cards and logging into the Food Diary.
  FoodEntity toFoodEntity({String? nameOverride, String? categoryOverride}) {
    return FoodEntity(
      id: id,
      name: nameOverride ?? foodName,
      category: categoryOverride ??
          (tier == NutritionProfileTier.verifiedExact
              ? 'FitFuel Curated'
              : tier == NutritionProfileTier.closelyRelatedGeneric
                  ? 'Generic Baseline'
                  : 'Recipe Estimate'),
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fats: totalFat,
      fiber: fiber ?? 0.0,
      sugar: sugar ?? 0.0,
      sodium: sodium ?? 0.0,
      isCustom: false,
      cuisine: preparationState,
    );
  }
}
