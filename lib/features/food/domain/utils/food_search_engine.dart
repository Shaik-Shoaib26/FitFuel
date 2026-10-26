import '../entities/food_entity.dart';

class FoodSearchEngine {
  static List<FoodEntity> search({
    required List<FoodEntity> foods,
    required String query,
  }) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return [];

    final scoredFoods = <_ScoredFood>[];

    for (final food in foods) {
      final nameLower = food.name.toLowerCase();
      final catLower = food.category.toLowerCase();
      int score = 0;

      final idLower = food.id.toLowerCase();
      final strippedId = idLower.replaceFirst('predefined_', '').replaceAll('_', ' ');
      final cleanQueryNoUnderscore = cleanQuery.replaceAll('_', ' ');

      // ID matching
      if (idLower == cleanQuery) {
        score += 120;
      } else if (strippedId == cleanQueryNoUnderscore || strippedId == cleanQuery) {
        score += 100;
      } else if (idLower.contains(cleanQuery) || strippedId.contains(cleanQueryNoUnderscore)) {
        score += 40;
      }

      if (nameLower == cleanQuery) {
        score += 100;
      } else if (nameLower.startsWith(cleanQuery)) {
        score += 50;
      } else if (nameLower.contains(cleanQuery)) {
        score += 25;
      }

      if (catLower == cleanQuery) {
        score += 30;
      } else if (catLower.contains(cleanQuery)) {
        score += 15;
      }

      // Check inside dietary tags or meal types
      for (final tag in food.dietaryTags) {
        final tagLower = tag.toLowerCase();
        if (tagLower == cleanQuery) {
          score += 15;
        } else if (tagLower.contains(cleanQuery)) {
          score += 8;
        }
      }
      for (final mt in food.mealTypes) {
        final mtLower = mt.toLowerCase();
        if (mtLower == cleanQuery) {
          score += 15;
        } else if (mtLower.contains(cleanQuery)) {
          score += 8;
        }
      }

      // Comprehensive culinary aliases & synonyms
      for (final entry in _searchAliases.entries) {
        final key = entry.key;
        final synonyms = entry.value;
        if (cleanQuery == key || synonyms.contains(cleanQuery)) {
          if (nameLower.contains(key) || strippedId.contains(key) ||
              synonyms.any((s) => nameLower.contains(s) || strippedId.contains(s))) {
            score += 35;
          }
        }
      }

      // Plural handling (e.g. samosas -> samosa, burgers -> burger)
      if (cleanQuery.endsWith('s') && cleanQuery.length > 2) {
        final singular = cleanQuery.substring(0, cleanQuery.length - 1);
        if (nameLower.contains(singular) || strippedId.contains(singular)) {
          score += 30;
        }
      }

      // Check partial words matching
      final queryWords = cleanQuery.split(RegExp(r'\s+'));
      final nameWords = nameLower.split(RegExp(r'\s+'));

      int partialMatches = 0;
      for (final qw in queryWords) {
        if (qw.isEmpty) continue;
        for (final nw in nameWords) {
          if (nw.startsWith(qw)) {
            partialMatches++;
            break;
          }
        }
      }

      if (partialMatches > 0) {
        score += partialMatches * 5;
      }

      if (score > 0) {
        scoredFoods.add(_ScoredFood(food: food, score: score));
      }
    }

    scoredFoods.sort((a, b) => b.score.compareTo(a.score));

    return scoredFoods.map((sf) => sf.food).toList();
  }

  static const Map<String, List<String>> _searchAliases = {
    'roti': ['chapati', 'phulka', 'flatbread', 'wheat roti'],
    'chapati': ['roti', 'phulka', 'flatbread'],
    'dahi': ['curd', 'yogurt'],
    'curd': ['dahi', 'yogurt'],
    'chaas': ['buttermilk'],
    'buttermilk': ['chaas'],
    'karela': ['bitter gourd'],
    'bitter gourd': ['karela'],
    'lauki': ['bottle gourd', 'ghiya'],
    'bottle gourd': ['lauki', 'ghiya'],
    'paneer': ['cottage cheese'],
    'cottage cheese': ['paneer'],
    'rice': ['chawal', 'basmati', 'steamed rice', 'brown rice'],
    'chawal': ['rice', 'steamed rice'],
    'dal': ['lentils', 'yellow dal', 'dal tadka', 'dal fry', 'moong dal'],
    'lentils': ['dal', 'yellow dal'],
    'rajma': ['kidney beans', 'rajma curry', 'rajma chawal'],
    'kidney beans': ['rajma', 'rajma chawal', 'rajma curry'],
    'samosa': ['samosas', 'sambusa', 'singara'],
    'samosas': ['samosa'],
    'dosa': ['dosas', 'plain dosa', 'masala dosa', 'rava dosa', 'neer dosa'],
    'dosas': ['dosa'],
    'pasta': ['standard pasta', 'whole grain pasta', 'penne', 'spaghetti', 'macaroni', 'noodles'],
    'spaghetti': ['pasta', 'standard pasta', 'whole grain pasta'],
    'penne': ['pasta', 'standard pasta', 'whole grain pasta'],
    'pizza': ['cheese pizza', 'margherita'],
    'burger': ['burgers', 'cheeseburger', 'hamburger', 'veggie burger'],
    'burgers': ['burger'],
    'chicken': ['chicken breast', 'chicken curry', 'murgh'],
    'murgh': ['chicken'],
    'egg': ['eggs', 'boiled egg', 'egg omelette', 'scrambled eggs'],
    'eggs': ['egg'],
  };
}

class _ScoredFood {
  final FoodEntity food;
  final int score;

  const _ScoredFood({required this.food, required this.score});
}
