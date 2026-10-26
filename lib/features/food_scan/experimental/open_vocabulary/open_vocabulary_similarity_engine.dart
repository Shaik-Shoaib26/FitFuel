import 'dart:math' as math;
import 'open_vocabulary_food_entry.dart';

/// Pure Dart vector similarity and Top-K open-vocabulary retrieval engine.
///
/// Supports:
/// - L2 embedding normalization with zero/NaN/Infinity guards
/// - Cosine similarity over normalized or unnormalized vectors
/// - Alias-to-canonical concept resolution without duplicate canonical IDs
/// - Explicit negative non-food concept gating (e.g. 'not food', 'person', 'electronics')
/// - Top-K ranking (Top-1, Top-3, Top-5) with deterministic tie-breaking
class OpenVocabularySimilarityEngine {
  /// Default minimum cosine similarity required to consider a food candidate viable.
  static const double defaultMinFoodSimilarity = 0.18;

  /// Margin by which the top negative concept can trigger non-food gating.
  static const double defaultNonFoodMargin = -0.02;

  const OpenVocabularySimilarityEngine();

  /// Validates that [embedding] is non-empty, contains only finite numbers,
  /// has non-zero norm, and matches [expectedDim] if specified.
  static bool isValidEmbedding(List<double> embedding, {int? expectedDim}) {
    if (embedding.isEmpty) return false;
    if (expectedDim != null && embedding.length != expectedDim) {
      return false;
    }
    double normSq = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      final v = embedding[i];
      if (v.isNaN || v.isInfinite) return false;
      normSq += v * v;
    }
    return normSq > 1e-12;
  }

  /// L2-normalizes [embedding] to unit length.
  /// Returns an empty list if [embedding] is empty, contains NaN/Infinity, or has zero norm.
  static List<double> normalizeEmbedding(List<double> embedding) {
    if (embedding.isEmpty) return const [];
    double normSq = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      final v = embedding[i];
      if (v.isNaN || v.isInfinite) return const [];
      normSq += v * v;
    }
    if (normSq <= 1e-12) return const [];
    final invNorm = 1.0 / math.sqrt(normSq);
    return List<double>.generate(
      embedding.length,
      (i) => embedding[i] * invNorm,
      growable: false,
    );
  }

  /// Computes cosine similarity in [-1.0, 1.0] between [a] and [b].
  /// Returns 0.0 if vectors are invalid or have mismatched dimensions.
  static double cosineSimilarity(
    List<double> a,
    List<double> b, {
    bool assumeNormalized = false,
  }) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      return 0.0;
    }
    if (assumeNormalized) {
      double dot = 0.0;
      for (int i = 0; i < a.length; i++) {
        final av = a[i];
        final bv = b[i];
        if (av.isNaN || av.isInfinite || bv.isNaN || bv.isInfinite) {
          return 0.0;
        }
        dot += av * bv;
      }
      return dot.clamp(-1.0, 1.0);
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      final av = a[i];
      final bv = b[i];
      if (av.isNaN || av.isInfinite || bv.isNaN || bv.isInfinite) {
        return 0.0;
      }
      dot += av * bv;
      normA += av * av;
      normB += bv * bv;
    }
    if (normA <= 1e-12 || normB <= 1e-12) return 0.0;
    return (dot / (math.sqrt(normA) * math.sqrt(normB))).clamp(-1.0, 1.0);
  }

  /// Resolves an alias or food name query to a canonical [OpenVocabularyFoodEntry]
  /// via case-insensitive exact or normalized token matching.
  static OpenVocabularyFoodEntry? resolveAliasToCanonical(
    String aliasOrName,
    List<OpenVocabularyFoodEntry> vocabulary,
  ) {
    final normalizedQuery = _normalizeLabel(aliasOrName);
    if (normalizedQuery.isEmpty || vocabulary.isEmpty) return null;

    for (final entry in vocabulary) {
      if (entry.isNegativeConcept) continue;
      if (_normalizeLabel(entry.canonicalId) == normalizedQuery ||
          _normalizeLabel(entry.canonicalName) == normalizedQuery) {
        return entry;
      }
      for (final alias in entry.aliases) {
        if (_normalizeLabel(alias) == normalizedQuery) {
          return entry;
        }
      }
    }
    return null;
  }

  static String _normalizeLabel(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Ranks [vocabulary] against [imageEmbedding] and returns the Top-K deduplicated
  /// canonical food candidates along with non-food safety gating analysis.
  OpenVocabularyRetrievalResult retrieveTopK({
    required List<double> imageEmbedding,
    required List<OpenVocabularyFoodEntry> vocabulary,
    int topK = 5,
    double minFoodSimilarity = defaultMinFoodSimilarity,
    double nonFoodMargin = defaultNonFoodMargin,
    String modelName = 'fitfuel_openvocab_mnv3_minilm_384',
    String runtimeName = 'LiteRT / TensorFlow Lite CPU',
    double imageDecodeMs = 0.0,
    double preprocessMs = 0.0,
    double inferenceMs = 0.0,
    bool isOffline = true,
  }) {
    final sw = Stopwatch()..start();
    final normImage = normalizeEmbedding(imageEmbedding);

    if (normImage.isEmpty || vocabulary.isEmpty || topK <= 0) {
      sw.stop();
      final retrievalMs = sw.elapsedMicroseconds / 1000.0;
      return OpenVocabularyRetrievalResult(
        candidates: const [],
        topNegativeMatch: null,
        isFlaggedAsNonFood: true,
        nonFoodScore: 0.0,
        imageDecodeMs: imageDecodeMs,
        preprocessMs: preprocessMs,
        inferenceMs: inferenceMs,
        retrievalMs: retrievalMs,
        totalLatencyMs: imageDecodeMs + preprocessMs + inferenceMs + retrievalMs,
        modelName: modelName,
        runtimeName: runtimeName,
        isOffline: isOffline,
        cloudCallsCount: 0,
      );
    }

    final expectedDim = normImage.length;

    // Map from canonicalId -> best candidate match (deduplicating aliases and duplicate entries)
    final bestFoodByCanonicalId = <String, OpenVocabularyCandidateMatch>{};
    OpenVocabularyCandidateMatch? bestNegativeMatch;

    for (final entry in vocabulary) {
      final canonicalId = entry.canonicalId.trim();
      final canonicalName = entry.canonicalName.trim();
      if (canonicalId.isEmpty || canonicalName.isEmpty) continue;

      double bestEntrySim = -2.0;
      String bestMatchedAlias = canonicalName;

      if (isValidEmbedding(entry.textEmbedding, expectedDim: expectedDim)) {
        final normCanon = normalizeEmbedding(entry.textEmbedding);
        if (normCanon.isNotEmpty) {
          bestEntrySim = cosineSimilarity(
            normImage,
            normCanon,
            assumeNormalized: true,
          );
        }
      }

      if (entry.aliasEmbeddings.isNotEmpty) {
        for (final aliasEntry in entry.aliasEmbeddings.entries) {
          final aliasVec = aliasEntry.value;
          if (!isValidEmbedding(aliasVec, expectedDim: expectedDim)) continue;
          final normAlias = normalizeEmbedding(aliasVec);
          if (normAlias.isEmpty) continue;
          final sim = cosineSimilarity(
            normImage,
            normAlias,
            assumeNormalized: true,
          );
          if (sim > bestEntrySim) {
            bestEntrySim = sim;
            bestMatchedAlias = aliasEntry.key;
          }
        }
      }

      if (bestEntrySim <= -1.5) {
        continue; // No valid embedding found for this entry
      }

      final candidate = OpenVocabularyCandidateMatch(
        canonicalId: canonicalId,
        canonicalName: canonicalName,
        similarity: bestEntrySim,
        matchedAlias: bestMatchedAlias,
        cuisine: entry.cuisine,
        category: entry.category,
        hierarchyPath: entry.hierarchyPath,
        isNegativeConcept: entry.isNegativeConcept,
      );

      if (entry.isNegativeConcept) {
        if (bestNegativeMatch == null ||
            candidate.similarity > bestNegativeMatch.similarity) {
          bestNegativeMatch = candidate;
        }
      } else {
        final existing = bestFoodByCanonicalId[canonicalId];
        if (existing == null || candidate.similarity > existing.similarity) {
          bestFoodByCanonicalId[canonicalId] = candidate;
        }
      }
    }

    final sortedFoods = bestFoodByCanonicalId.values.toList()
      ..sort((a, b) {
        final cmp = b.similarity.compareTo(a.similarity);
        if (cmp != 0) return cmp;
        return a.canonicalId.compareTo(b.canonicalId);
      });

    final topCandidates = sortedFoods.take(topK).toList(growable: false);
    final topFoodScore =
        topCandidates.isNotEmpty ? topCandidates.first.similarity : -1.0;
    final topNegScore = bestNegativeMatch?.similarity ?? -1.0;

    final isNonFood = topCandidates.isEmpty ||
        topFoodScore < minFoodSimilarity ||
        (bestNegativeMatch != null &&
            (topNegScore - topFoodScore) > nonFoodMargin);

    sw.stop();
    final retrievalMs = sw.elapsedMicroseconds / 1000.0;

    return OpenVocabularyRetrievalResult(
      candidates: topCandidates,
      topNegativeMatch: bestNegativeMatch,
      isFlaggedAsNonFood: isNonFood,
      nonFoodScore: bestNegativeMatch?.similarity ?? 0.0,
      imageDecodeMs: imageDecodeMs,
      preprocessMs: preprocessMs,
      inferenceMs: inferenceMs,
      retrievalMs: retrievalMs,
      totalLatencyMs: imageDecodeMs + preprocessMs + inferenceMs + retrievalMs,
      modelName: modelName,
      runtimeName: runtimeName,
      isOffline: isOffline,
      cloudCallsCount: 0,
    );
  }
}
