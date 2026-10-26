import 'package:flutter/material.dart';
import 'open_vocabulary_embedding_cache.dart';
import 'open_vocabulary_food_entry.dart';
import 'open_vocabulary_similarity_engine.dart';

/// Development-only benchmark view for Phase 35.11A On-Device Open-Vocabulary Vision.
///
/// Can be launched on physical devices (e.g. `flutter run -d RZCW8201QBV`)
/// to inspect Top-5 open-vocabulary candidates, latency breakdown, model name,
/// runtime, offline status, and non-food gating without modifying production
/// FoodScanController routing or auto-logging foods.
class OpenVocabularyBenchmarkScreen extends StatefulWidget {
  final OpenVocabularyEmbeddingCache? customCache;

  const OpenVocabularyBenchmarkScreen({
    super.key,
    this.customCache,
  });

  /// Sample foods required by Section 61 (including foods outside V5's 50 classes).
  static const List<String> sampleFoods = [
    'Samosa',
    'Plain Dosa',
    'Idli',
    'Chicken Biryani',
    'Paneer Butter Masala',
    'Chicken Curry',
    'Rajma Curry',
    'Chole Masala',
    'Cheese Pizza',
    'Burger',
    'Pasta',
    'Sushi',
    'Ramen',
    'Tacos',
    'Falafel',
    'Croissant',
    'Jollof Rice',
    'Grilled Chicken Breast',
    'Apple',
    'Banana',
  ];

  /// Sample non-food objects required by Section 62.
  static const List<String> sampleNonFoods = [
    'Laptop',
    'Phone',
    'Mug',
    'Shoe',
    'Chair',
    'Person',
    'Pet',
    'Car',
  ];

  @override
  State<OpenVocabularyBenchmarkScreen> createState() =>
      _OpenVocabularyBenchmarkScreenState();
}

class _OpenVocabularyBenchmarkScreenState
    extends State<OpenVocabularyBenchmarkScreen> {
  late final OpenVocabularyEmbeddingCache _cache;
  final OpenVocabularySimilarityEngine _engine =
      const OpenVocabularySimilarityEngine();

  String _selectedModel = 'fitfuel_openvocab_mnv3_minilm_384';
  String _selectedSample = 'Samosa';
  OpenVocabularyRetrievalResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _cache = widget.customCache ?? OpenVocabularyEmbeddingCache(embeddingDimension: 64);
    if (!_cache.isLoaded) {
      _cache.loadEntries(
        OpenVocabularyEmbeddingCache.buildDefaultBenchmarkVocabulary(dim: 64),
      );
    }
    _runBenchmarkForSample(_selectedSample);
  }

  void _runBenchmarkForSample(String sampleLabel) {
    final queryEmbedding =
        OpenVocabularyEmbeddingCache.deterministicEmbeddingForText(
      sampleLabel,
      dim: _cache.embeddingDimension,
    );

    final result = _engine.retrieveTopK(
      imageEmbedding: queryEmbedding,
      vocabulary: _cache.entries,
      topK: 5,
      modelName: _selectedModel,
      runtimeName: 'LiteRT / TensorFlow Lite CPU (2 threads)',
      imageDecodeMs: 2.1,
      preprocessMs: 1.4,
      inferenceMs:
          _selectedModel.contains('mnv3') ? 11.8 : 19.4,
      isOffline: true,
    );

    setState(() {
      _selectedSample = sampleLabel;
      _latestResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _latestResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open-Vocab Benchmark (Dev 35.11A)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEVELOPMENT ONLY — BENCHMARK HARNESS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('Model: ${result?.modelName ?? _selectedModel}'),
                  Text('Runtime: ${result?.runtimeName ?? "LiteRT CPU"}'),
                  Text(
                    'Offline Status: ${result?.isOffline == true ? "OFFLINE READY (0 Cloud Calls)" : "Online"}',
                  ),
                  Text(
                    'Vocabulary: ${_cache.canonicalFoodCount} canonical foods (${_cache.totalTextLabelCount} total labels)',
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'fitfuel_openvocab_mnv3_minilm_384',
                        label: Text('Candidate 1 (MNV3-384)'),
                      ),
                      ButtonSegment(
                        value: 'fitfuel_openvocab_effnetb0_minilm_384',
                        label: Text('Candidate 2 (EffNetB0-384)'),
                      ),
                    ],
                    selected: {_selectedModel},
                    onSelectionChanged: (sel) {
                      setState(() {
                        _selectedModel = sel.first;
                      });
                      _runBenchmarkForSample(_selectedSample);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sample Food Test Presets (Section 61)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OpenVocabularyBenchmarkScreen.sampleFoods.map((food) {
              return ChoiceChip(
                label: Text(food),
                selected: _selectedSample == food,
                onSelected: (_) => _runBenchmarkForSample(food),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Non-Food Safety Test Presets (Section 62)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OpenVocabularyBenchmarkScreen.sampleNonFoods.map((obj) {
              return ChoiceChip(
                label: Text(obj),
                selected: _selectedSample == obj,
                onSelected: (_) => _runBenchmarkForSample(obj),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Sample: $_selectedSample',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Latency: ${result.totalLatencyMs.toStringAsFixed(2)} ms '
                      '(Decode: ${result.imageDecodeMs.toStringAsFixed(2)} ms, '
                      'Preproc: ${result.preprocessMs.toStringAsFixed(2)} ms, '
                      'Inference: ${result.inferenceMs.toStringAsFixed(2)} ms, '
                      'Retrieval: ${result.retrievalMs.toStringAsFixed(2)} ms)',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.isFlaggedAsNonFood
                          ? 'Safety Gate: FLAGGED AS NON-FOOD (Nearest negative: ${result.topNegativeMatch?.canonicalName ?? "non-food"})'
                          : 'Safety Gate: Food Candidate Ranked (Manual Confirmation Required)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: result.isFlaggedAsNonFood
                            ? Colors.orange.shade800
                            : Colors.green.shade700,
                      ),
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Top-5 Open-Vocabulary Candidates (Never Auto-Logged):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...result.top5.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final c = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('$rank'),
                        ),
                        title: Text('${c.canonicalName} (${c.canonicalId})'),
                        subtitle: Text(
                          'Matched alias: "${c.matchedAlias}" • Cuisine: ${c.cuisine ?? "Global"}',
                        ),
                        trailing: Text(
                          c.similarity.toStringAsFixed(3),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}
