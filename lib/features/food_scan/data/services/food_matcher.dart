import 'package:fitfuel/features/food/domain/entities/food_entity.dart';

class FoodMatchResult {
  final FoodEntity? food;
  final double matchScore; // 0.0 - 1.0

  const FoodMatchResult({
    this.food,
    required this.matchScore,
  });

  bool get isMatched => food != null && matchScore >= 0.50;
}

class FoodMatcher {
  /// Known common culinary synonyms/aliases for robust matching
  static const Map<String, List<String>> _aliases = {
    'rice': ['basmati rice', 'cooked rice', 'white rice', 'brown rice', 'steamed rice', 'chawal'],
    'chapati': ['roti', 'phulka', 'flatbread', 'wheat roti'],
    'dal': ['dal tadka', 'yellow dal', 'dal fry', 'moong dal', 'lentil soup'],
    'chicken': ['chicken breast', 'grilled chicken', 'roast chicken', 'chicken curry', 'chicken masala'],
    'chicken curry': ['chicken masala', 'murgh curry', 'chicken gravy'],
    'egg': ['boiled egg', 'fried egg', 'egg omelette', 'poached egg'],
    'salad': ['cucumber salad', 'green salad', 'mixed vegetable salad', 'onion salad'],
    'yogurt': ['curd', 'dahi', 'greek yogurt', 'plain yogurt'],
    'paneer': ['cottage cheese', 'paneer cubes', 'paneer tikka'],
    'oats': ['oatmeal', 'rolled oats', 'porridge'],
    'banana': ['ripe banana', 'fresh banana'],
    'apple': ['fresh apple', 'red apple', 'green apple'],
    'milk': ['whole milk', 'cow milk', 'low fat milk'],
    'dosa': ['plain dosa', 'masala dosa', 'crispy dosa'],
    'idli': ['steamed idli', 'rice idli', 'idly'],
    'curry': ['vegetable curry', 'mix veg curry', 'sabzi', 'mixed vegetable curry'],
    'pickle': ['mixed pickle', 'mango pickle', 'achar', 'lemon pickle'],
  };

  /// Matches a [detectedName] against a list of [catalog] foods.
  static FoodMatchResult match(String detectedName, List<FoodEntity> catalog) {
    if (detectedName.trim().isEmpty || catalog.isEmpty) {
      return const FoodMatchResult(matchScore: 0.0);
    }

    final query = _normalize(detectedName);

    // 1. Exact match (case-insensitive)
    for (final item in catalog) {
      if (_normalize(item.name) == query) {
        return FoodMatchResult(food: item, matchScore: 1.0);
      }
    }

    // 2. Starts with / Ends with match
    for (final item in catalog) {
      final name = _normalize(item.name);
      if (name.startsWith(query) || query.startsWith(name)) {
        return FoodMatchResult(food: item, matchScore: 0.90);
      }
    }

    // 3. Substring containment match
    FoodEntity? bestSubstringMatch;
    double bestSubstringScore = 0.0;
    for (final item in catalog) {
      final name = _normalize(item.name);
      if (name.contains(query) || query.contains(name)) {
        // Longer overlap yields higher score
        final minLen = query.length < name.length ? query.length : name.length;
        final maxLen = query.length > name.length ? query.length : name.length;
        final score = 0.70 + (0.18 * (minLen / maxLen));
        if (score > bestSubstringScore) {
          bestSubstringScore = score;
          bestSubstringMatch = item;
        }
      }
    }
    if (bestSubstringMatch != null && bestSubstringScore >= 0.75) {
      return FoodMatchResult(food: bestSubstringMatch, matchScore: bestSubstringScore);
    }

    // 4. Token overlap match (e.g. "grilled chicken salad" vs "Chicken Salad")
    final queryTokens = _tokenize(query);
    FoodEntity? bestTokenMatch;
    double bestTokenScore = 0.0;

    for (final item in catalog) {
      final nameTokens = _tokenize(_normalize(item.name));
      final intersection = queryTokens.intersection(nameTokens);
      if (intersection.isNotEmpty) {
        final union = queryTokens.union(nameTokens);
        final jaccard = intersection.length / union.length;
        final score = 0.50 + (0.40 * jaccard);
        if (score > bestTokenScore) {
          bestTokenScore = score;
          bestTokenMatch = item;
        }
      }
    }
    if (bestTokenMatch != null && bestTokenScore >= 0.65) {
      return FoodMatchResult(food: bestTokenMatch, matchScore: bestTokenScore);
    }

    // 5. Alias/Synonym lookup
    for (final entry in _aliases.entries) {
      final key = entry.key;
      final synonyms = entry.value;
      final matchesKey = query.contains(key);
      final matchesSynonym = synonyms.any((s) => query.contains(s));

      if (matchesKey || matchesSynonym) {
        // Find catalog food matching key or synonyms
        for (final item in catalog) {
          final normName = _normalize(item.name);
          if (normName.contains(key) || synonyms.any((s) => normName.contains(s))) {
            return FoodMatchResult(food: item, matchScore: 0.60);
          }
        }
      }
    }

    return FoodMatchResult(food: bestSubstringMatch ?? bestTokenMatch, matchScore: (bestSubstringScore > bestTokenScore ? bestSubstringScore : bestTokenScore));
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  static Set<String> _tokenize(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toSet();
  }

  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'with', 'and', 'in', 'of', 'for', 'style', 'dish',
    'plate', 'bowl', 'portion', 'fresh', 'homemade', 'cooked', 'steamed', 'raw',
  };
}
