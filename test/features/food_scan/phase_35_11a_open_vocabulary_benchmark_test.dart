import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food_scan/experimental/open_vocabulary/open_vocabulary_benchmark_models.dart';
import 'package:fitfuel/features/food_scan/experimental/open_vocabulary/open_vocabulary_benchmark_screen.dart';
import 'package:fitfuel/features/food_scan/experimental/open_vocabulary/open_vocabulary_embedding_cache.dart';
import 'package:fitfuel/features/food_scan/experimental/open_vocabulary/open_vocabulary_food_entry.dart';
import 'package:fitfuel/features/food_scan/experimental/open_vocabulary/open_vocabulary_similarity_engine.dart';

void main() {
  group('Phase 35.11A — On-Device Open-Vocabulary Food Vision Benchmark Tests', () {
    const engine = OpenVocabularySimilarityEngine();

    test('1. Embedding normalization produces unit-length L2 vector and rejects zero/NaN/Infinity', () {
      final raw = <double>[3.0, 4.0, 0.0];
      final norm = OpenVocabularySimilarityEngine.normalizeEmbedding(raw);
      expect(norm.length, 3);
      expect(norm[0], closeTo(0.6, 1e-6));
      expect(norm[1], closeTo(0.8, 1e-6));
      expect(norm[2], closeTo(0.0, 1e-6));

      final normSq = norm.fold<double>(0.0, (sum, v) => sum + v * v);
      expect(normSq, closeTo(1.0, 1e-6));

      // Zero, empty, NaN, and Infinity vectors are rejected safely
      expect(OpenVocabularySimilarityEngine.normalizeEmbedding(const []), isEmpty);
      expect(
        OpenVocabularySimilarityEngine.normalizeEmbedding(const [0.0, 0.0, 0.0]),
        isEmpty,
      );
      expect(
        OpenVocabularySimilarityEngine.normalizeEmbedding([1.0, double.nan, 2.0]),
        isEmpty,
      );
      expect(
        OpenVocabularySimilarityEngine.normalizeEmbedding([
          1.0,
          double.infinity,
          2.0,
        ]),
        isEmpty,
      );
    });

    test('2. Cosine similarity computes exact dot product for normalized and unnormalized vectors', () {
      final a = <double>[1.0, 0.0, 0.0];
      final b = <double>[1.0, 0.0, 0.0];
      final c = <double>[0.0, 1.0, 0.0];
      final d = <double>[-1.0, 0.0, 0.0];

      expect(OpenVocabularySimilarityEngine.cosineSimilarity(a, b), closeTo(1.0, 1e-6));
      expect(OpenVocabularySimilarityEngine.cosineSimilarity(a, c), closeTo(0.0, 1e-6));
      expect(OpenVocabularySimilarityEngine.cosineSimilarity(a, d), closeTo(-1.0, 1e-6));

      // Unnormalized scaled vectors have identical cosine similarity
      expect(
        OpenVocabularySimilarityEngine.cosineSimilarity(
          const [3.0, 4.0],
          const [6.0, 8.0],
        ),
        closeTo(1.0, 1e-6),
      );

      // Mismatched dimensions return 0.0 safely
      expect(
        OpenVocabularySimilarityEngine.cosineSimilarity(
          const [1.0, 0.0],
          const [1.0, 0.0, 0.0],
        ),
        0.0,
      );
    });

    test('3. Top-K sorting ranks candidates strictly descending by similarity and exposes Top-1, Top-3, Top-5', () {
      final vocab = <OpenVocabularyFoodEntry>[
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_idli',
          canonicalName: 'Idli',
          textEmbedding: [0.2, 0.9, 0.0, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_samosa',
          canonicalName: 'Samosa',
          textEmbedding: [0.99, 0.1, 0.0, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_dosa',
          canonicalName: 'Plain Dosa',
          textEmbedding: [0.8, 0.6, 0.0, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'openvocab_pizza',
          canonicalName: 'Cheese Pizza',
          textEmbedding: [0.5, 0.5, 0.5, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'openvocab_sushi',
          canonicalName: 'Sushi',
          textEmbedding: [0.1, 0.2, 0.9, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'openvocab_ramen',
          canonicalName: 'Ramen',
          textEmbedding: [0.0, 0.1, 0.1, 0.99],
        ),
      ];

      final query = <double>[1.0, 0.0, 0.0, 0.0];
      final result = engine.retrieveTopK(
        imageEmbedding: query,
        vocabulary: vocab,
        topK: 5,
      );

      expect(result.top1?.canonicalId, 'predefined_samosa');
      expect(result.top3.length, 3);
      expect(result.top5.length, 5);
      expect(result.top3.map((c) => c.canonicalId).toList(), [
        'predefined_samosa',
        'predefined_dosa',
        'openvocab_pizza',
      ]);

      for (int i = 0; i < result.top5.length - 1; i++) {
        expect(
          result.top5[i].similarity,
          greaterThanOrEqualTo(result.top5[i + 1].similarity),
        );
      }
    });

    test('4. Alias-to-canonical resolution maps regional aliases (golgappa/pani puri/puchka, curd/yogurt, chapati/roti, brinjal/eggplant/aubergine, capsicum/bell pepper)', () {
      final vocab = OpenVocabularyEmbeddingCache.buildDefaultBenchmarkVocabulary(
        dim: 32,
      );

      for (final alias in ['golgappa', 'pani puri', 'puchka']) {
        final match = OpenVocabularySimilarityEngine.resolveAliasToCanonical(
          alias,
          vocab,
        );
        expect(match?.canonicalId, 'openvocab_pani_puri');
      }

      for (final alias in ['curd', 'yogurt', 'dahi']) {
        final match = OpenVocabularySimilarityEngine.resolveAliasToCanonical(
          alias,
          vocab,
        );
        expect(match?.canonicalId, 'predefined_curd');
      }

      for (final alias in ['chapati', 'roti', 'phulka']) {
        final match = OpenVocabularySimilarityEngine.resolveAliasToCanonical(
          alias,
          vocab,
        );
        expect(match?.canonicalId, 'predefined_chapati');
      }

      for (final alias in ['brinjal', 'eggplant', 'aubergine']) {
        final match = OpenVocabularySimilarityEngine.resolveAliasToCanonical(
          alias,
          vocab,
        );
        expect(match?.canonicalId, 'predefined_eggplant');
      }

      for (final alias in ['capsicum', 'bell pepper', 'shimla mirch']) {
        final match = OpenVocabularySimilarityEngine.resolveAliasToCanonical(
          alias,
          vocab,
        );
        expect(match?.canonicalId, 'predefined_capsicum');
      }
    });

    test('5. Duplicate canonical foods and alias embeddings collapse to a single canonical entry keeping best similarity', () {
      final vocab = <OpenVocabularyFoodEntry>[
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_samosa',
          canonicalName: 'Samosa',
          aliases: ['vegetable samosa', 'Indian fried samosa'],
          textEmbedding: [0.7, 0.7, 0.0],
          aliasEmbeddings: {
            'Indian fried samosa': [1.0, 0.0, 0.0],
          },
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_samosa',
          canonicalName: 'Samosa Duplicate',
          textEmbedding: [0.6, 0.8, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_dosa',
          canonicalName: 'Plain Dosa',
          textEmbedding: [0.0, 1.0, 0.0],
        ),
      ];

      final result = engine.retrieveTopK(
        imageEmbedding: const [1.0, 0.0, 0.0],
        vocabulary: vocab,
        topK: 5,
      );

      expect(result.candidates.length, 2);
      expect(result.top1?.canonicalId, 'predefined_samosa');
      expect(result.top1?.matchedAlias, 'Indian fried samosa');
      expect(result.top1?.similarity, closeTo(1.0, 1e-6));
    });

    test('6. Invalid embeddings (NaN, zero norm, wrong dimension) are safely skipped without crashing', () {
      const vocab = <OpenVocabularyFoodEntry>[
        OpenVocabularyFoodEntry(
          canonicalId: 'invalid_nan',
          canonicalName: 'Invalid NaN Food',
          textEmbedding: [double.nan, 1.0, 0.0],
        ),
        OpenVocabularyFoodEntry(
          canonicalId: 'invalid_zero',
          canonicalName: 'Zero Food',
          textEmbedding: [0.0, 0.0, 0.0],
        ),
        OpenVocabularyFoodEntry(
          canonicalId: 'invalid_dim',
          canonicalName: 'Wrong Dim Food',
          textEmbedding: [1.0, 0.0], // 2D instead of 3D
        ),
        OpenVocabularyFoodEntry(
          canonicalId: 'predefined_apple',
          canonicalName: 'Apple',
          textEmbedding: [1.0, 0.0, 0.0],
        ),
      ];

      final result = engine.retrieveTopK(
        imageEmbedding: const [1.0, 0.0, 0.0],
        vocabulary: vocab,
        topK: 5,
      );

      expect(result.candidates.length, 1);
      expect(result.top1?.canonicalId, 'predefined_apple');
    });

    test('7. Empty vocabulary and invalid query embeddings return empty candidates and flag non-food safely', () {
      final emptyVocabResult = engine.retrieveTopK(
        imageEmbedding: const [1.0, 0.0, 0.0],
        vocabulary: const [],
        topK: 5,
      );
      expect(emptyVocabResult.candidates, isEmpty);
      expect(emptyVocabResult.isFlaggedAsNonFood, isTrue);

      final invalidQueryResult = engine.retrieveTopK(
        imageEmbedding: const [0.0, 0.0, 0.0],
        vocabulary: const [
          OpenVocabularyFoodEntry(
            canonicalId: 'predefined_apple',
            canonicalName: 'Apple',
            textEmbedding: [1.0, 0.0, 0.0],
          ),
        ],
        topK: 5,
      );
      expect(invalidQueryResult.candidates, isEmpty);
      expect(invalidQueryResult.isFlaggedAsNonFood, isTrue);
    });

    test('8. Non-food negative concepts trigger non-food gating when image matches negative concept more closely than food', () {
      final vocab = <OpenVocabularyFoodEntry>[
        const OpenVocabularyFoodEntry(
          canonicalId: 'predefined_samosa',
          canonicalName: 'Samosa',
          textEmbedding: [1.0, 0.0, 0.0],
        ),
        const OpenVocabularyFoodEntry(
          canonicalId: 'neg_electronics',
          canonicalName: 'electronics',
          aliases: ['laptop', 'phone'],
          textEmbedding: [0.0, 1.0, 0.0],
          isNegativeConcept: true,
        ),
      ];

      // Non-food query aligned with 'neg_electronics'
      final nonFoodResult = engine.retrieveTopK(
        imageEmbedding: const [0.05, 0.99, 0.0],
        vocabulary: vocab,
        topK: 5,
      );
      expect(nonFoodResult.isFlaggedAsNonFood, isTrue);
      expect(nonFoodResult.topNegativeMatch?.canonicalId, 'neg_electronics');
      // Negative concepts are never included in food candidates list
      expect(
        nonFoodResult.candidates.any((c) => c.isNegativeConcept),
        isFalse,
      );

      // Food query aligned with 'predefined_samosa'
      final foodResult = engine.retrieveTopK(
        imageEmbedding: const [0.99, 0.05, 0.0],
        vocabulary: vocab,
        topK: 5,
      );
      expect(foodResult.isFlaggedAsNonFood, isFalse);
      expect(foodResult.top1?.canonicalId, 'predefined_samosa');
    });

    test('9. Offline operation and embedding cache load/lookup execute with 0 cloud calls', () {
      final cache = OpenVocabularyEmbeddingCache(embeddingDimension: 32);
      cache.loadEntries(
        OpenVocabularyEmbeddingCache.buildDefaultBenchmarkVocabulary(dim: 32),
      );

      expect(cache.isLoaded, isTrue);
      expect(cache.canonicalFoodCount, greaterThanOrEqualTo(20));
      expect(cache.negativeConceptCount, greaterThanOrEqualTo(5));
      expect(cache.totalTextLabelCount, greaterThan(60));
      expect(cache.memoryFootprintBytes, greaterThan(0));

      final query = OpenVocabularyEmbeddingCache.deterministicEmbeddingForText(
        'Samosa',
        dim: 32,
      );
      final result = engine.retrieveTopK(
        imageEmbedding: query,
        vocabulary: cache.entries,
        topK: 5,
        isOffline: true,
      );

      expect(result.isOffline, isTrue);
      expect(result.cloudCallsCount, 0);
      expect(result.top1?.canonicalId, 'predefined_samosa');
    });

    test('10. Benchmark result and suite serialization round-trips cleanly via JSON', () {
      const record = OpenVocabularyBenchmarkRecord(
        imageId: 'test_samosa_01',
        actualFood: 'predefined_samosa',
        cuisine: 'North Indian',
        category: 'Snacks',
        candidateModel: 'fitfuel_openvocab_mnv3_minilm_384',
        top1: 'predefined_samosa',
        top1Score: 0.812,
        top3: ['predefined_samosa', 'openvocab_kachori', 'predefined_medu_vada'],
        top5: [
          'predefined_samosa',
          'openvocab_kachori',
          'predefined_medu_vada',
          'predefined_poha',
          'predefined_dosa',
        ],
        correctTop1: true,
        correctTop3: true,
        correctTop5: true,
        latencyMs: 14.6,
        imageDecodeMs: 2.1,
        preprocessMs: 1.2,
        inferenceMs: 10.9,
        retrievalMs: 0.4,
        isFlaggedAsNonFood: false,
        matchedAlias: 'Indian fried samosa',
      );

      const summary = OpenVocabularyModelBenchmarkSummary(
        modelName: 'fitfuel_openvocab_mnv3_minilm_384',
        runtime: 'LiteRT / TensorFlow Lite CPU',
        license: 'Apache-2.0',
        commercialUseAllowed: true,
        modelSizeMb: 7.42,
        top1Accuracy: 0.684,
        top3Accuracy: 0.812,
        top5Accuracy: 0.865,
        meanReciprocalRank: 0.758,
        nonFoodFalseAcceptanceRate: 0.045,
        coldLoadMs: 38.2,
        firstInferenceMs: 21.4,
        meanWarmInferenceMs: 11.2,
        p50TotalMs: 14.5,
        p95TotalMs: 22.8,
        meanPreprocessMs: 1.4,
        meanRetrievalMs: 0.4,
        meanTotalMs: 15.1,
        peakMemoryMb: 42.0,
        decision: 'PROMISING',
      );

      const suite = OpenVocabularyBenchmarkSuiteReport(
        canonicalFoodsCount: 300,
        aliasesCount: 560,
        totalTextLabelsCount: 860,
        foodImagesCount: 540,
        distinctFoodConceptsCount: 112,
        nonFoodImagesCount: 110,
        mixedMealImagesCount: 55,
        cloudCallsCount: 0,
        models: [summary],
        records: [record],
      );

      final jsonStr = suite.toJsonString();
      final decoded = OpenVocabularyBenchmarkSuiteReport.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(decoded.phase, '35.11A');
      expect(decoded.canonicalFoodsCount, 300);
      expect(decoded.totalTextLabelsCount, 860);
      expect(decoded.cloudCallsCount, 0);
      expect(decoded.models.first.modelName, 'fitfuel_openvocab_mnv3_minilm_384');
      expect(decoded.records.first.imageId, 'test_samosa_01');
      expect(decoded.records.first.correctTop5, isTrue);
    });

    testWidgets('11. Development-only OpenVocabularyBenchmarkScreen renders Top-5 candidates, latency, and offline status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OpenVocabularyBenchmarkScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open-Vocab Benchmark (Dev 35.11A)'), findsOneWidget);
      expect(find.textContaining('OFFLINE READY (0 Cloud Calls)'), findsOneWidget);
      expect(
        find.text('Top-5 Open-Vocabulary Candidates (Never Auto-Logged):'),
        findsOneWidget,
      );

      // Tap a non-food preset ('Laptop') and verify safety gate updates
      await tester.ensureVisible(find.text('Laptop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laptop'));
      await tester.pumpAndSettle();
      expect(find.text('Selected Sample: Laptop'), findsOneWidget);
    });
  });
}
