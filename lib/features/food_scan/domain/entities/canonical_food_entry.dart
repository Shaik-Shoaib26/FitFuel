import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';

/// Scalable canonical food entry representing a recognized dish or ingredient
/// in the extensible global food taxonomy (Phase 35.12 Section 2).
class CanonicalFoodEntry {
  /// Stable canonical food identifier (e.g. 'predefined_samosa', 'openvocab_pizza', 'global_dosa').
  final String canonicalId;

  /// Preferred standard display name (e.g. 'Samosa', 'Cheese Pizza', 'Masala Dosa').
  final String preferredName;

  /// International/regional spellings, synonyms, culinary aliases, and transliterations.
  final List<String> aliases;

  /// Cuisine or regional origin (e.g. 'Indian', 'Italian', 'Mexican', 'East Asian', 'American').
  final String? cuisine;

  /// Food category (e.g. 'Street Food & Chaat', 'Main Dishes', 'Breakfast', 'Snacks', 'Desserts').
  final String? category;

  /// Characteristic ingredients when known.
  final List<String> ingredients;

  /// Preparation method (e.g. 'Deep fried', 'Baked', 'Steamed', 'Pan griddled', 'Fermented').
  final String? preparationMethod;

  /// Serving form (e.g. 'Whole with chutney', 'Slice', 'Bowl', 'Roll').
  final String? servingForm;

  /// Data provenance and taxonomy source (e.g. 'FitFuel Curated', 'Open Food Vocabulary 2050', 'USDA FDC').
  final String source;

  /// Linked nutrition profile IDs in the universal nutrition data layer.
  final List<String> nutritionProfileIds;

  /// Default nutrition profile tier for this food concept.
  final NutritionProfileTier nutritionTier;

  /// Precomputed 768-dimensional text embedding for SigLIP-B/16 vision-language matching.
  /// Null if this entry was loaded without embeddings (text-search-only).
  final List<double>? textEmbedding;

  /// Model identifier under which textEmbedding was generated (e.g. 'siglip_b16_int8').
  final String? embeddingModelId;

  /// Pack version string for provenance and update tracking.
  final String? packVersion;

  const CanonicalFoodEntry({
    required this.canonicalId,
    required this.preferredName,
    this.aliases = const [],
    this.cuisine,
    this.category,
    this.ingredients = const [],
    this.preparationMethod,
    this.servingForm,
    this.source = 'FitFuel Global Taxonomy',
    this.nutritionProfileIds = const [],
    this.nutritionTier = NutritionProfileTier.unavailable,
    this.textEmbedding,
    this.embeddingModelId,
    this.packVersion,
  });

  /// True if this concept has a valid 768-d normalized embedding compatible
  /// with SigLIP-B/16 on-device vision inference.
  bool get hasImageSupport =>
      textEmbedding != null &&
      textEmbedding!.length == 768 &&
      !textEmbedding!.any((v) => v.isNaN || v.isInfinite);

  /// True if this concept maps directly to a verified FitFuel nutrition catalog entry.
  bool get inFitFuelCatalog =>
      nutritionTier == NutritionProfileTier.verifiedExact ||
      nutritionProfileIds.isNotEmpty;

  /// All searchable label strings (preferred name + aliases) deduplicated.
  List<String> get allSearchableLabels {
    final seen = <String>{};
    final labels = <String>[];
    for (final label in [preferredName, ...aliases]) {
      final trimmed = label.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        labels.add(trimmed);
      }
    }
    return labels;
  }

  CanonicalFoodEntry copyWith({
    String? canonicalId,
    String? preferredName,
    List<String>? aliases,
    String? cuisine,
    String? category,
    List<String>? ingredients,
    String? preparationMethod,
    String? servingForm,
    String? source,
    List<String>? nutritionProfileIds,
    NutritionProfileTier? nutritionTier,
    List<double>? textEmbedding,
    String? embeddingModelId,
    String? packVersion,
  }) {
    return CanonicalFoodEntry(
      canonicalId: canonicalId ?? this.canonicalId,
      preferredName: preferredName ?? this.preferredName,
      aliases: aliases ?? this.aliases,
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      ingredients: ingredients ?? this.ingredients,
      preparationMethod: preparationMethod ?? this.preparationMethod,
      servingForm: servingForm ?? this.servingForm,
      source: source ?? this.source,
      nutritionProfileIds: nutritionProfileIds ?? this.nutritionProfileIds,
      nutritionTier: nutritionTier ?? this.nutritionTier,
      textEmbedding: textEmbedding ?? this.textEmbedding,
      embeddingModelId: embeddingModelId ?? this.embeddingModelId,
      packVersion: packVersion ?? this.packVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'canonicalId': canonicalId,
        'preferredName': preferredName,
        'aliases': aliases,
        if (cuisine != null) 'cuisine': cuisine,
        if (category != null) 'category': category,
        if (ingredients.isNotEmpty) 'ingredients': ingredients,
        if (preparationMethod != null) 'preparationMethod': preparationMethod,
        if (servingForm != null) 'servingForm': servingForm,
        'source': source,
        if (nutritionProfileIds.isNotEmpty)
          'nutritionProfileIds': nutritionProfileIds,
        'nutritionTier': nutritionTier.name,
        if (textEmbedding != null) 'textEmbedding': textEmbedding,
        if (embeddingModelId != null) 'embeddingModelId': embeddingModelId,
        if (packVersion != null) 'packVersion': packVersion,
        'hasImageSupport': hasImageSupport,
      };

  factory CanonicalFoodEntry.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['textEmbedding'] as List<dynamic>?;
    final embedding = rawEmbedding?.map((e) => (e as num).toDouble()).toList();

    return CanonicalFoodEntry(
      canonicalId: json['canonicalId'] as String? ?? json['id'] as String? ?? '',
      preferredName:
          json['preferredName'] as String? ?? json['name'] as String? ?? '',
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      cuisine: json['cuisine'] as String?,
      category: json['category'] as String? ?? json['cat'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      preparationMethod: json['preparationMethod'] as String?,
      servingForm: json['servingForm'] as String?,
      source: json['source'] as String? ?? 'FitFuel Global Taxonomy',
      nutritionProfileIds: (json['nutritionProfileIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      nutritionTier: NutritionProfileTier.values.firstWhere(
        (t) => t.name == json['nutritionTier'],
        orElse: () => (json['inFitFuel238'] == true)
            ? NutritionProfileTier.verifiedExact
            : NutritionProfileTier.unavailable,
      ),
      textEmbedding: embedding,
      embeddingModelId: json['embeddingModelId'] as String?,
      packVersion: json['packVersion'] as String?,
    );
  }
}
