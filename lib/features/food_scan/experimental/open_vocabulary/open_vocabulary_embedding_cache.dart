import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'open_vocabulary_food_entry.dart';
import 'open_vocabulary_similarity_engine.dart';

/// Lazy-loaded local cache for precomputed normalized food text embeddings.
///
/// Tracks:
/// - [loadTimeMs]: time taken to deserialize and normalize the vocabulary
/// - [memoryFootprintBytes]: estimated RAM usage of the loaded vocabulary
/// - [entries]: immutable list of canonical food entries and negative concepts
class OpenVocabularyEmbeddingCache {
  static const String defaultAssetPath =
      'assets/ml/open_vocab_food_embeddings_35_11a.json';

  final int embeddingDimension;

  List<OpenVocabularyFoodEntry> _entries = const [];
  bool _isLoaded = false;
  double _loadTimeMs = 0.0;
  int _memoryFootprintBytes = 0;

  OpenVocabularyEmbeddingCache({this.embeddingDimension = 384});

  bool get isLoaded => _isLoaded;
  double get loadTimeMs => _loadTimeMs;
  int get memoryFootprintBytes => _memoryFootprintBytes;
  List<OpenVocabularyFoodEntry> get entries => _entries;

  /// Count of canonical food entries (excluding negative non-food concepts).
  int get canonicalFoodCount =>
      _entries.where((e) => !e.isNegativeConcept).length;

  /// Count of negative non-food safety concepts.
  int get negativeConceptCount =>
      _entries.where((e) => e.isNegativeConcept).length;

  /// Total number of text labels (canonical names + aliases) across food entries.
  int get totalTextLabelCount => _entries
      .where((e) => !e.isNegativeConcept)
      .fold<int>(0, (sum, e) => sum + e.allLabels.length);

  /// Loads precomputed embeddings from a JSON string (or falls back to asset bundle).
  Future<void> loadFromAsset({
    String assetPath = defaultAssetPath,
    AssetBundle? bundle,
  }) async {
    if (_isLoaded && _entries.isNotEmpty) return;

    final sw = Stopwatch()..start();
    try {
      final effectiveBundle = bundle ?? rootBundle;
      final jsonStr = await effectiveBundle.loadString(assetPath);
      loadFromJsonString(jsonStr);
    } catch (_) {
      // Fallback to deterministic built-in benchmark vocabulary if asset is not bundled
      loadEntries(buildDefaultBenchmarkVocabulary(dim: embeddingDimension));
    } finally {
      sw.stop();
      if (_loadTimeMs <= 0.0) {
        _loadTimeMs = sw.elapsedMicroseconds / 1000.0;
      }
    }
  }

  /// Synchronously parses and normalizes a JSON-serialized vocabulary payload.
  void loadFromJsonString(String jsonStr) {
    final sw = Stopwatch()..start();
    final decoded = jsonDecode(jsonStr);
    final List<dynamic> rawList;
    if (decoded is Map<String, dynamic> && decoded['entries'] is List) {
      rawList = decoded['entries'] as List<dynamic>;
    } else if (decoded is List<dynamic>) {
      rawList = decoded;
    } else {
      rawList = const [];
    }

    final parsed = <OpenVocabularyFoodEntry>[];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final entry = OpenVocabularyFoodEntry.fromJson(item);
        final normVec = OpenVocabularySimilarityEngine.normalizeEmbedding(
          entry.textEmbedding,
        );
        if (normVec.isNotEmpty) {
          parsed.add(
            OpenVocabularyFoodEntry(
              canonicalId: entry.canonicalId,
              canonicalName: entry.canonicalName,
              aliases: entry.aliases,
              textEmbedding: normVec,
              aliasEmbeddings: entry.aliasEmbeddings,
              cuisine: entry.cuisine,
              category: entry.category,
              hierarchyPath: entry.hierarchyPath,
              isNegativeConcept: entry.isNegativeConcept,
            ),
          );
        }
      }
    }

    sw.stop();
    _entries = List<OpenVocabularyFoodEntry>.unmodifiable(parsed);
    _isLoaded = true;
    _loadTimeMs = sw.elapsedMicroseconds / 1000.0;
    _memoryFootprintBytes = _estimateMemoryBytes(_entries);
  }

  /// Loads an explicit list of entries directly into the cache (used in tests and benchmarks).
  void loadEntries(List<OpenVocabularyFoodEntry> entries) {
    final sw = Stopwatch()..start();
    final cleaned = <OpenVocabularyFoodEntry>[];
    final seenIds = <String>{};

    for (final entry in entries) {
      final id = entry.canonicalId.trim();
      if (id.isEmpty || !seenIds.add(id)) continue;
      final normVec = OpenVocabularySimilarityEngine.normalizeEmbedding(
        entry.textEmbedding,
      );
      if (normVec.isEmpty) continue;
      cleaned.add(
        OpenVocabularyFoodEntry(
          canonicalId: id,
          canonicalName: entry.canonicalName.trim(),
          aliases: entry.aliases,
          textEmbedding: normVec,
          aliasEmbeddings: entry.aliasEmbeddings,
          cuisine: entry.cuisine,
          category: entry.category,
          hierarchyPath: entry.hierarchyPath,
          isNegativeConcept: entry.isNegativeConcept,
        ),
      );
    }

    sw.stop();
    _entries = List<OpenVocabularyFoodEntry>.unmodifiable(cleaned);
    _isLoaded = true;
    _loadTimeMs = sw.elapsedMicroseconds / 1000.0;
    _memoryFootprintBytes = _estimateMemoryBytes(_entries);
  }

  void clear() {
    _entries = const [];
    _isLoaded = false;
    _loadTimeMs = 0.0;
    _memoryFootprintBytes = 0;
  }

  static int _estimateMemoryBytes(List<OpenVocabularyFoodEntry> entries) {
    int bytes = 0;
    for (final e in entries) {
      bytes += 64; // Object header overhead
      bytes += (e.canonicalId.length + e.canonicalName.length) * 2;
      for (final a in e.aliases) {
        bytes += a.length * 2 + 16;
      }
      bytes += e.textEmbedding.length * 8; // 64-bit IEEE-754 double per dim
      for (final ae in e.aliasEmbeddings.values) {
        bytes += ae.length * 8;
      }
    }
    return bytes;
  }

  /// Generates a deterministic, L2-normalized pseudo-semantic vector for [seedText]
  /// when running unit/widget tests without loading the full binary embedding table.
  static List<double> deterministicEmbeddingForText(
    String seedText, {
    int dim = 64,
  }) {
    final normalized = seedText.trim().toLowerCase();
    final vec = List<double>.filled(dim, 0.0);
    int hash = 2166136261;
    for (int i = 0; i < normalized.length; i++) {
      hash ^= normalized.codeUnitAt(i);
      hash = (hash * 16777619) & 0x7fffffff;
      final idx = i % dim;
      vec[idx] += math.sin(hash * 0.0001 + i) + math.cos(hash * 0.00007);
    }
    for (int d = 0; d < dim; d++) {
      final tokenSalt = ((hash + d * 31) & 0x7fffffff) / 2147483647.0;
      vec[d] += (tokenSalt - 0.5) * 0.5;
    }
    return OpenVocabularySimilarityEngine.normalizeEmbedding(vec);
  }

  /// Builds a representative default vocabulary covering Indian, Asian, Middle Eastern,
  /// European, American, African, and Latin American foods plus negative non-food concepts.
  static List<OpenVocabularyFoodEntry> buildDefaultBenchmarkVocabulary({
    int dim = 64,
  }) {
    final specs = <Map<String, dynamic>>[
      {
        'id': 'predefined_samosa',
        'name': 'Samosa',
        'aliases': ['vegetable samosa', 'Indian fried samosa', 'punjabi samosa'],
        'cuisine': 'North Indian',
        'category': 'Snacks',
        'hierarchy': ['food', 'Indian', 'snack', 'fried pastry', 'samosa'],
      },
      {
        'id': 'predefined_dosa',
        'name': 'Plain Dosa',
        'aliases': ['dosa', 'masala dosa', 'south indian dosa', 'crispy dosa'],
        'cuisine': 'South Indian',
        'category': 'Breakfast',
        'hierarchy': ['food', 'South Indian', 'breakfast', 'crepe', 'dosa'],
      },
      {
        'id': 'predefined_idli',
        'name': 'Idli',
        'aliases': ['steamed idli', 'rice idli', 'south indian idli'],
        'cuisine': 'South Indian',
        'category': 'Breakfast',
        'hierarchy': ['food', 'South Indian', 'breakfast', 'steamed cake', 'idli'],
      },
      {
        'id': 'predefined_medu_vada',
        'name': 'Medu Vada',
        'aliases': ['urad dal vada', 'uddina vada', 'south indian vada'],
        'cuisine': 'South Indian',
        'category': 'Breakfast',
        'hierarchy': ['food', 'South Indian', 'breakfast', 'lentil fritter', 'medu vada'],
      },
      {
        'id': 'predefined_uttapam',
        'name': 'Uttapam',
        'aliases': ['onion uttapam', 'vegetable uttapam', 'oothappam'],
        'cuisine': 'South Indian',
        'category': 'Breakfast',
        'hierarchy': ['food', 'South Indian', 'breakfast', 'savory pancake', 'uttapam'],
      },
      {
        'id': 'predefined_poha',
        'name': 'Poha',
        'aliases': ['kanda poha', 'flattened rice poha', 'avalakki'],
        'cuisine': 'Indian',
        'category': 'Breakfast',
        'hierarchy': ['food', 'Indian', 'breakfast', 'flattened rice', 'poha'],
      },
      {
        'id': 'predefined_chapati',
        'name': 'Chapati',
        'aliases': ['roti', 'phulka', 'whole wheat flatbread'],
        'cuisine': 'North Indian',
        'category': 'Breads',
        'hierarchy': ['food', 'Indian', 'bread', 'flatbread', 'chapati'],
      },
      {
        'id': 'predefined_curd',
        'name': 'Curd',
        'aliases': ['yogurt', 'dahi', 'plain curd', 'natural yogurt'],
        'cuisine': 'Indian',
        'category': 'Dairy',
        'hierarchy': ['food', 'Indian', 'dairy', 'fermented milk', 'curd'],
      },
      {
        'id': 'predefined_eggplant',
        'name': 'Eggplant',
        'aliases': ['brinjal', 'aubergine', 'baingan'],
        'cuisine': 'Global',
        'category': 'Vegetables',
        'hierarchy': ['food', 'vegetable', 'nightshade', 'eggplant'],
      },
      {
        'id': 'predefined_capsicum',
        'name': 'Capsicum',
        'aliases': ['bell pepper', 'green bell pepper', 'shimla mirch'],
        'cuisine': 'Global',
        'category': 'Vegetables',
        'hierarchy': ['food', 'vegetable', 'pepper', 'capsicum'],
      },
      {
        'id': 'openvocab_pani_puri',
        'name': 'Pani Puri',
        'aliases': ['golgappa', 'puchka', 'gupchup', 'pani puri chaat'],
        'cuisine': 'Indian',
        'category': 'Snacks',
        'hierarchy': ['food', 'Indian', 'street food', 'chaat', 'pani puri'],
      },
      {
        'id': 'openvocab_biryani',
        'name': 'Chicken Biryani',
        'aliases': ['biryani', 'hyderabadi biryani', 'dum biryani'],
        'cuisine': 'Indian',
        'category': 'Rice Dishes',
        'hierarchy': ['food', 'Indian', 'rice dish', 'biryani', 'chicken biryani'],
      },
      {
        'id': 'openvocab_paneer_butter_masala',
        'name': 'Paneer Butter Masala',
        'aliases': ['paneer makhani', 'butter paneer curry', 'shahi paneer'],
        'cuisine': 'North Indian',
        'category': 'Curries',
        'hierarchy': ['food', 'North Indian', 'curry', 'paneer', 'paneer butter masala'],
      },
      {
        'id': 'predefined_rajma_curry',
        'name': 'Rajma Curry',
        'aliases': ['rajma masala', 'red kidney bean curry', 'punjabi rajma'],
        'cuisine': 'North Indian',
        'category': 'Curries',
        'hierarchy': ['food', 'North Indian', 'curry', 'legume', 'rajma curry'],
      },
      {
        'id': 'predefined_chole_masala',
        'name': 'Chole Masala',
        'aliases': ['chana masala', 'punjabi chole', 'chickpea curry'],
        'cuisine': 'North Indian',
        'category': 'Curries',
        'hierarchy': ['food', 'North Indian', 'curry', 'legume', 'chole masala'],
      },
      {
        'id': 'openvocab_pizza',
        'name': 'Cheese Pizza',
        'aliases': ['pizza', 'margherita pizza', 'neapolitan pizza'],
        'cuisine': 'European',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'European', 'Italian', 'flatbread dish', 'pizza'],
      },
      {
        'id': 'openvocab_burger',
        'name': 'Burger',
        'aliases': ['cheeseburger', 'hamburger', 'beef burger'],
        'cuisine': 'American',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'American', 'sandwich', 'burger'],
      },
      {
        'id': 'openvocab_pasta',
        'name': 'Pasta',
        'aliases': ['spaghetti', 'penne pasta', 'pasta carbonara'],
        'cuisine': 'European',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'European', 'Italian', 'noodle dish', 'pasta'],
      },
      {
        'id': 'openvocab_sushi',
        'name': 'Sushi',
        'aliases': ['nigiri sushi', 'maki roll', 'japanese sushi'],
        'cuisine': 'Asian',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'Asian', 'Japanese', 'rice dish', 'sushi'],
      },
      {
        'id': 'openvocab_ramen',
        'name': 'Ramen',
        'aliases': ['ramen noodles', 'japanese noodle soup', 'tonkotsu ramen'],
        'cuisine': 'Asian',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'Asian', 'Japanese', 'noodle soup', 'ramen'],
      },
      {
        'id': 'openvocab_tacos',
        'name': 'Tacos',
        'aliases': ['mexican tacos', 'street tacos', 'corn tortilla tacos'],
        'cuisine': 'Latin American',
        'category': 'Main Dishes',
        'hierarchy': ['food', 'Latin American', 'Mexican', 'tortilla dish', 'tacos'],
      },
      {
        'id': 'openvocab_falafel',
        'name': 'Falafel',
        'aliases': ['chickpea falafel', 'middle eastern falafel balls'],
        'cuisine': 'Middle Eastern',
        'category': 'Snacks',
        'hierarchy': ['food', 'Middle Eastern', 'fritter', 'falafel'],
      },
      {
        'id': 'openvocab_croissant',
        'name': 'Croissant',
        'aliases': ['butter croissant', 'french pastry croissant'],
        'cuisine': 'European',
        'category': 'Breakfast',
        'hierarchy': ['food', 'European', 'French', 'pastry', 'croissant'],
      },
      {
        'id': 'openvocab_jollof_rice',
        'name': 'Jollof Rice',
        'aliases': ['west african jollof rice', 'spiced tomato rice'],
        'cuisine': 'African',
        'category': 'Rice Dishes',
        'hierarchy': ['food', 'African', 'West African', 'rice dish', 'jollof rice'],
      },
      {
        'id': 'predefined_grilled_chicken_breast',
        'name': 'Grilled Chicken Breast',
        'aliases': ['grilled chicken', 'roasted chicken breast'],
        'cuisine': 'American',
        'category': 'Meat Dishes',
        'hierarchy': ['food', 'meat dish', 'poultry', 'grilled chicken breast'],
      },
      {
        'id': 'predefined_apple',
        'name': 'Apple',
        'aliases': ['red apple', 'fresh apple fruit'],
        'cuisine': 'Global',
        'category': 'Fruits',
        'hierarchy': ['food', 'fruit', 'pome fruit', 'apple'],
      },
      {
        'id': 'predefined_banana',
        'name': 'Banana',
        'aliases': ['ripe banana', 'yellow banana fruit'],
        'cuisine': 'Global',
        'category': 'Fruits',
        'hierarchy': ['food', 'fruit', 'tropical fruit', 'banana'],
      },
      // Negative non-food concepts for Section 41 safety gating
      {
        'id': 'neg_not_food',
        'name': 'not food',
        'aliases': ['non-food object', 'inanimate background'],
        'isNegative': true,
      },
      {
        'id': 'neg_electronics',
        'name': 'electronics',
        'aliases': ['laptop', 'phone', 'smartphone', 'computer keyboard'],
        'isNegative': true,
      },
      {
        'id': 'neg_furniture',
        'name': 'furniture',
        'aliases': ['chair', 'table', 'desk', 'sofa', 'couch'],
        'isNegative': true,
      },
      {
        'id': 'neg_footwear',
        'name': 'footwear',
        'aliases': ['shoe', 'sneakers', 'leather shoe'],
        'isNegative': true,
      },
      {
        'id': 'neg_vehicle',
        'name': 'vehicle',
        'aliases': ['car', 'automobile', 'truck'],
        'isNegative': true,
      },
      {
        'id': 'neg_person_animal',
        'name': 'person or animal',
        'aliases': ['person', 'pet', 'cat', 'dog'],
        'isNegative': true,
      },
    ];

    return specs.map((s) {
      final id = s['id'] as String;
      final name = s['name'] as String;
      final aliases = (s['aliases'] as List<dynamic>).cast<String>();
      return OpenVocabularyFoodEntry(
        canonicalId: id,
        canonicalName: name,
        aliases: aliases,
        textEmbedding: deterministicEmbeddingForText(name, dim: dim),
        cuisine: s['cuisine'] as String?,
        category: s['category'] as String?,
        hierarchyPath:
            (s['hierarchy'] as List<dynamic>? ?? const []).cast<String>(),
        isNegativeConcept: s['isNegative'] as bool? ?? false,
      );
    }).toList(growable: false);
  }
}
