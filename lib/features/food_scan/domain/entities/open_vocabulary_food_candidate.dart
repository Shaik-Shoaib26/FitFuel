/// Represents a canonical food candidate returned by the Tier-2 on-device
/// open-vocabulary image-text food recognizer (`SigLIP-B/16 INT8`).
///
/// Note: [similarity] is an internal cosine/dot-product similarity score in the
/// SigLIP embedding space and must NEVER be displayed as a percentage confidence
/// in normal user-facing UI.
class OpenVocabularyFoodCandidate {
  final String canonicalFoodId;
  final String canonicalName;
  final String category;
  final double similarity;
  final int rank;
  final bool inFitFuelCatalog;
  final String? fitFuelFoodId;
  final List<String> aliases;

  const OpenVocabularyFoodCandidate({
    required this.canonicalFoodId,
    required this.canonicalName,
    required this.category,
    required this.similarity,
    required this.rank,
    this.inFitFuelCatalog = false,
    this.fitFuelFoodId,
    this.aliases = const [],
  });

  /// Human-friendly display name for UI cards.
  String get displayName => canonicalName;

  /// Formats the raw cosine similarity score for UI presentation.
  ///
  /// Semantics:
  /// - Represents raw cosine similarity (u · v) in the 768-dimensional SigLIP
  ///   multimodal feature space formatted as a 4-decimal scalar (e.g. "Cosine similarity: 0.1680").
  /// - It is NOT a calibrated class probability, statistical confidence level, or percentage.
  /// - Negative scores indicate opposite directional alignment; zero indicates orthogonality;
  ///   higher positive values indicate closer multimodal vector alignment.
  String get formattedSimilarityScore =>
      'Cosine similarity: ${similarity.toStringAsFixed(4)}';

  /// Provides raw cosine similarity formatted to 4 decimal places for audit/diagnostics.
  String get rawCosineSimilarityString => similarity.toStringAsFixed(4);

  OpenVocabularyFoodCandidate copyWith({
    String? canonicalFoodId,
    String? canonicalName,
    String? category,
    double? similarity,
    int? rank,
    bool? inFitFuelCatalog,
    String? fitFuelFoodId,
    List<String>? aliases,
  }) {
    return OpenVocabularyFoodCandidate(
      canonicalFoodId: canonicalFoodId ?? this.canonicalFoodId,
      canonicalName: canonicalName ?? this.canonicalName,
      category: category ?? this.category,
      similarity: similarity ?? this.similarity,
      rank: rank ?? this.rank,
      inFitFuelCatalog: inFitFuelCatalog ?? this.inFitFuelCatalog,
      fitFuelFoodId: fitFuelFoodId ?? this.fitFuelFoodId,
      aliases: aliases ?? this.aliases,
    );
  }

  Map<String, dynamic> toJson() => {
        'canonical_food_id': canonicalFoodId,
        'canonical_name': canonicalName,
        'category': category,
        'similarity': similarity,
        'rank': rank,
        'in_fitfuel_catalog': inFitFuelCatalog,
        'fitfuel_food_id': fitFuelFoodId,
        'aliases': aliases,
      };

  factory OpenVocabularyFoodCandidate.fromJson(
    Map<dynamic, dynamic> json, {
    int fallbackRank = 1,
  }) {
    final rawAliases = json['aliases'];
    final aliasesList = rawAliases is List
        ? rawAliases.map((e) => e.toString()).toList()
        : const <String>[];
    final id = (json['canonical_food_id'] ??
            json['canonicalFoodId'] ??
            json['id'] ??
            '')
        .toString();
    final inCatalog = (json['in_fitfuel_catalog'] ??
            json['inFitFuelCatalog'] ??
            json['inFitFuel238'] ??
            false) ==
        true;
    return OpenVocabularyFoodCandidate(
      canonicalFoodId: id,
      canonicalName: (json['canonical_name'] ??
              json['canonicalName'] ??
              json['name'] ??
              '')
          .toString(),
      category:
          (json['category'] ?? json['cat'] ?? 'Food & Drink').toString(),
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      rank: (json['rank'] as num?)?.toInt() ?? fallbackRank,
      inFitFuelCatalog: inCatalog,
      fitFuelFoodId: (json['fitfuel_food_id'] ??
              json['fitFuelFoodId'] ??
              (inCatalog ? id : null))
          ?.toString(),
      aliases: aliasesList,
    );
  }

  @override
  String toString() =>
      'OpenVocabularyFoodCandidate(rank: $rank, id: $canonicalFoodId, '
      'name: $canonicalName, cat: $category, sim: ${similarity.toStringAsFixed(4)}, '
      'inFitFuelCatalog: $inFitFuelCatalog)';
}
