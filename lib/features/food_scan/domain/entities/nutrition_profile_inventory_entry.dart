import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';

/// Machine-readable inventory entry representing an active nutrition profile
/// in FitFuel's food recognition and nutrition resolution pipeline (Phase 35.12.9).
class NutritionProfileInventoryEntry {
  final String canonicalProfileId;
  final String displayName;
  final NutritionProfileTier tier;
  final String sourceType;
  final String? sourceIdentifier;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double totalFat;
  final double? fiber;
  final double? sugar;
  final double? sodium;
  final double servingSize;
  final String servingUnit;
  final String measurementBasis;
  final String? preparationState;
  final String? recipeAssumptions;
  final bool isExternallyTraceable;
  final String profileClassification;
  final String attribution;

  const NutritionProfileInventoryEntry({
    required this.canonicalProfileId,
    required this.displayName,
    required this.tier,
    required this.sourceType,
    this.sourceIdentifier,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.totalFat,
    this.fiber,
    this.sugar,
    this.sodium,
    required this.servingSize,
    required this.servingUnit,
    required this.measurementBasis,
    this.preparationState,
    this.recipeAssumptions,
    required this.isExternallyTraceable,
    required this.profileClassification,
    required this.attribution,
  });

  Map<String, dynamic> toJson() => {
        'canonicalProfileId': canonicalProfileId,
        'displayName': displayName,
        'tier': tier.name,
        'sourceType': sourceType,
        if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
        'calories': calories,
        'protein': protein,
        'carbohydrates': carbohydrates,
        'totalFat': totalFat,
        if (fiber != null) 'fiber': fiber,
        if (sugar != null) 'sugar': sugar,
        if (sodium != null) 'sodium': sodium,
        'servingSize': servingSize,
        'servingUnit': servingUnit,
        'measurementBasis': measurementBasis,
        if (preparationState != null) 'preparationState': preparationState,
        if (recipeAssumptions != null) 'recipeAssumptions': recipeAssumptions,
        'isExternallyTraceable': isExternallyTraceable,
        'profileClassification': profileClassification,
        'attribution': attribution,
      };

  @override
  String toString() =>
      '[$canonicalProfileId] $displayName ($profileClassification, $measurementBasis): '
      '${calories.toStringAsFixed(1)} kcal, ${protein.toStringAsFixed(1)}g P, '
      '${carbohydrates.toStringAsFixed(1)}g C, ${totalFat.toStringAsFixed(1)}g F '
      '[Source: $sourceType | ID: $sourceIdentifier | Traceable: $isExternallyTraceable]';
}
