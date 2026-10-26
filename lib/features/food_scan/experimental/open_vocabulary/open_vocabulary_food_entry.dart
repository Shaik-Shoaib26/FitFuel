/// Experimental Open-Vocabulary Food Vision data models for Phase 35.11A.
///
/// IMPORTANT: This module is strictly experimental and benchmark-only.
/// It is NOT wired into the production FoodScanController routing path
/// and never auto-logs foods or modifies PredefinedFoodData.
class OpenVocabularyFoodEntry {
  /// Canonical identifier (e.g. 'predefined_samosa' or 'openvocab_sushi').
  final String canonicalId;

  /// Canonical human-readable name (e.g. 'Samosa').
  final String canonicalName;

  /// Regional names, synonyms, and descriptive aliases mapping back to [canonicalId].
  final List<String> aliases;

  /// L2-normalized text embedding vector for the canonical concept.
  final List<double> textEmbedding;

  /// Optional per-alias normalized text embeddings if individual alias vectors are stored.
  final Map<String, List<double>> aliasEmbeddings;

  /// Cuisine classification (e.g. 'Indian', 'South Indian', 'Asian', 'European').
  final String? cuisine;

  /// Food category (e.g. 'Snacks', 'Breakfast', 'Rice Dishes', 'Curries', 'Desserts').
  final String? category;

  /// Optional hierarchical path (e.g. ['food', 'Indian', 'rice dish', 'biryani', 'chicken biryani']).
  final List<String> hierarchyPath;

  /// True when this entry represents an explicit non-food safety concept
  /// (e.g. 'not food', 'person', 'vehicle', 'electronics', 'furniture', 'animal').
  final bool isNegativeConcept;

  const OpenVocabularyFoodEntry({
    required this.canonicalId,
    required this.canonicalName,
    this.aliases = const [],
    required this.textEmbedding,
    this.aliasEmbeddings = const {},
    this.cuisine,
    this.category,
    this.hierarchyPath = const [],
    this.isNegativeConcept = false,
  });

  /// Returns all text labels associated with this canonical concept (canonicalName + aliases).
  List<String> get allLabels {
    final seen = <String>{};
    final result = <String>[];
    for (final item in [canonicalName, ...aliases]) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        result.add(trimmed);
      }
    }
    return result;
  }

  /// Checks whether [textEmbedding] is non-empty, finite, and matches [expectedDim] if specified.
  bool hasValidEmbedding({int? expectedDim}) {
    if (textEmbedding.isEmpty) return false;
    if (expectedDim != null && textEmbedding.length != expectedDim) {
      return false;
    }
    double normSq = 0.0;
    for (final v in textEmbedding) {
      if (v.isNaN || v.isInfinite) return false;
      normSq += v * v;
    }
    return normSq > 1e-12;
  }

  Map<String, dynamic> toJson() => {
        'canonicalId': canonicalId,
        'canonicalName': canonicalName,
        'aliases': aliases,
        'textEmbedding': textEmbedding,
        if (aliasEmbeddings.isNotEmpty) 'aliasEmbeddings': aliasEmbeddings,
        if (cuisine != null) 'cuisine': cuisine,
        if (category != null) 'category': category,
        if (hierarchyPath.isNotEmpty) 'hierarchyPath': hierarchyPath,
        'isNegativeConcept': isNegativeConcept,
      };

  factory OpenVocabularyFoodEntry.fromJson(Map<String, dynamic> json) {
    final rawAliasMap = json['aliasEmbeddings'] as Map<String, dynamic>?;
    final parsedAliasEmbeddings = <String, List<double>>{};
    if (rawAliasMap != null) {
      for (final entry in rawAliasMap.entries) {
        final list = (entry.value as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(growable: false);
        parsedAliasEmbeddings[entry.key] = list;
      }
    }

    return OpenVocabularyFoodEntry(
      canonicalId: json['canonicalId'] as String? ?? '',
      canonicalName: json['canonicalName'] as String? ?? '',
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      textEmbedding: (json['textEmbedding'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(growable: false),
      aliasEmbeddings: parsedAliasEmbeddings,
      cuisine: json['cuisine'] as String?,
      category: json['category'] as String?,
      hierarchyPath: (json['hierarchyPath'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      isNegativeConcept: json['isNegativeConcept'] as bool? ?? false,
    );
  }
}

/// Ranked candidate returned by open-vocabulary cosine similarity retrieval.
class OpenVocabularyCandidateMatch {
  final String canonicalId;
  final String canonicalName;
  final double similarity;
  final String matchedAlias;
  final String? cuisine;
  final String? category;
  final List<String> hierarchyPath;
  final bool isNegativeConcept;

  const OpenVocabularyCandidateMatch({
    required this.canonicalId,
    required this.canonicalName,
    required this.similarity,
    required this.matchedAlias,
    this.cuisine,
    this.category,
    this.hierarchyPath = const [],
    this.isNegativeConcept = false,
  });

  Map<String, dynamic> toJson() => {
        'canonicalId': canonicalId,
        'canonicalName': canonicalName,
        'similarity': similarity,
        'matchedAlias': matchedAlias,
        if (cuisine != null) 'cuisine': cuisine,
        if (category != null) 'category': category,
        if (hierarchyPath.isNotEmpty) 'hierarchyPath': hierarchyPath,
        'isNegativeConcept': isNegativeConcept,
      };

  factory OpenVocabularyCandidateMatch.fromJson(Map<String, dynamic> json) {
    return OpenVocabularyCandidateMatch(
      canonicalId: json['canonicalId'] as String? ?? '',
      canonicalName: json['canonicalName'] as String? ?? '',
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      matchedAlias: json['matchedAlias'] as String? ?? '',
      cuisine: json['cuisine'] as String?,
      category: json['category'] as String?,
      hierarchyPath: (json['hierarchyPath'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      isNegativeConcept: json['isNegativeConcept'] as bool? ?? false,
    );
  }
}

/// Complete output of a single local open-vocabulary retrieval pass.
class OpenVocabularyRetrievalResult {
  final List<OpenVocabularyCandidateMatch> candidates;
  final OpenVocabularyCandidateMatch? topNegativeMatch;
  final bool isFlaggedAsNonFood;
  final double nonFoodScore;
  final double imageDecodeMs;
  final double preprocessMs;
  final double inferenceMs;
  final double retrievalMs;
  final double totalLatencyMs;
  final String modelName;
  final String runtimeName;
  final bool isOffline;
  final int cloudCallsCount;

  const OpenVocabularyRetrievalResult({
    required this.candidates,
    this.topNegativeMatch,
    this.isFlaggedAsNonFood = false,
    this.nonFoodScore = 0.0,
    this.imageDecodeMs = 0.0,
    this.preprocessMs = 0.0,
    this.inferenceMs = 0.0,
    this.retrievalMs = 0.0,
    this.totalLatencyMs = 0.0,
    required this.modelName,
    required this.runtimeName,
    this.isOffline = true,
    this.cloudCallsCount = 0,
  });

  OpenVocabularyCandidateMatch? get top1 =>
      candidates.isNotEmpty ? candidates.first : null;

  List<OpenVocabularyCandidateMatch> get top3 =>
      candidates.take(3).toList(growable: false);

  List<OpenVocabularyCandidateMatch> get top5 =>
      candidates.take(5).toList(growable: false);
}
