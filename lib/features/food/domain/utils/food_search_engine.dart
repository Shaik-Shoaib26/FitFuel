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

      if (nameLower == cleanQuery) {
        score += 100;
      } else if (nameLower.startsWith(cleanQuery)) {
        score += 50;
      } else if (nameLower.contains(cleanQuery)) {
        score += 20;
      }

      if (catLower == cleanQuery) {
        score += 15;
      } else if (catLower.contains(cleanQuery)) {
        score += 10;
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

      // Simple regional aliases
      if (cleanQuery == 'roti' && nameLower.contains('chapati')) {
        score += 30;
      } else if (cleanQuery == 'chapati' && nameLower.contains('roti')) {
        score += 30;
      } else if (cleanQuery == 'dahi' && nameLower.contains('curd')) {
        score += 30;
      } else if (cleanQuery == 'chaas' && nameLower.contains('buttermilk')) {
        score += 30;
      } else if (cleanQuery == 'karela' && nameLower.contains('bitter gourd')) {
        score += 30;
      } else if (cleanQuery == 'lauki' && nameLower.contains('bottle gourd')) {
        score += 30;
      } else if (cleanQuery == 'paneer' && nameLower.contains('cottage cheese')) {
        score += 20;
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
}

class _ScoredFood {
  final FoodEntity food;
  final int score;

  const _ScoredFood({required this.food, required this.score});
}
