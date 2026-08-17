import '../entities/food_entity.dart';

class FoodRecommendationEngine {
  static List<FoodEntity> recommend({
    required List<FoodEntity> foods,
    required String mealType,
    required double remainingCalories,
    required double proteinDeficit,
    required String dietaryPreference,
    required List<String> excludedFoodNames,
    required List<String> favoriteFoodIds,
    required List<String> recentFoodIds,
  }) {
    final List<_ScoredRecommendation> scored = [];

    for (final food in foods) {
      final nameLower = food.name.toLowerCase();

      // 1. Strict Excluded check
      bool isExcluded = false;
      for (final excl in excludedFoodNames) {
        if (nameLower.contains(excl.toLowerCase().trim())) {
          isExcluded = true;
          break;
        }
      }
      if (isExcluded) continue;

      // 2. Strict Dietary Preference check
      final dietPref = dietaryPreference.toLowerCase().trim();
      if (dietPref == 'vegetarian') {
        if (nameLower.contains('chicken') ||
            nameLower.contains('salmon') ||
            nameLower.contains('beef') ||
            nameLower.contains('fish') ||
            nameLower.contains('meat') ||
            nameLower.contains('seafood') ||
            nameLower.contains('turkey')) {
          continue;
        }
      } else if (dietPref == 'vegan') {
        if (nameLower.contains('chicken') ||
            nameLower.contains('salmon') ||
            nameLower.contains('beef') ||
            nameLower.contains('fish') ||
            nameLower.contains('meat') ||
            nameLower.contains('seafood') ||
            nameLower.contains('turkey') ||
            nameLower.contains('paneer') ||
            nameLower.contains('milk') ||
            nameLower.contains('yogurt') ||
            nameLower.contains('egg') ||
            nameLower.contains('dairy') ||
            nameLower.contains('cheese')) {
          continue;
        }
      }

      double score = 0.0;

      // 3. Category suitability
      final catLower = food.category.toLowerCase();
      final mtLower = mealType.toLowerCase();
      if (catLower == mtLower) {
        score += 100.0;
      } else if ((mtLower == 'snack' || mtLower == 'snacks') && (catLower == 'fruits' || catLower == 'dairy' || catLower == 'snacks')) {
        score += 50.0;
      } else if (mtLower == 'breakfast' && (catLower == 'dairy' || catLower == 'fruits' || catLower == 'grains')) {
        score += 30.0;
      } else if ((mtLower == 'lunch' || mtLower == 'dinner') && (catLower == 'protein' || catLower == 'vegetables' || catLower == 'grains')) {
        score += 30.0;
      }

      // 4. Remaining calories suitability and minor calorie penalty
      score -= food.calories * 0.1;
      if (remainingCalories > 0) {
        if (food.calories <= remainingCalories) {
          final ratio = food.calories / remainingCalories;
          if (ratio >= 0.4 && ratio <= 1.0) {
            score += 30.0;
          } else {
            score += 15.0;
          }
        } else {
          score -= 50.0;
        }
      } else {
        score += (500.0 - food.calories).clamp(0.0, 50.0);
      }

      // 5. Protein Deficit priority
      if (proteinDeficit > 0) {
        final proteinDensity = food.protein / (food.calories > 0 ? food.calories : 1.0);
        score += proteinDensity * 150.0;
        score += food.protein * 2.0;

        if (food.protein >= 15.0) {
          score += 40.0;
        }
      } else {
        // If no deficit, just minor weight for standard balance
        score += food.protein * 0.2;
      }

      // 6. Micronutrients / Fiber
      score += food.fiber * 2.0;
      score -= food.sugar * 0.5;

      // Penalize liquid shakes/supplements for main meals (Lunch/Dinner)
      if ((mtLower == 'lunch' || mtLower == 'dinner') &&
          (nameLower.contains('shake') || nameLower.contains('powder') || nameLower.contains('supplement'))) {
        score -= 100.0;
      }

      // 7. Favorites boost
      if (favoriteFoodIds.contains(food.id)) {
        score += 30.0;
      }

      // 8. Recent usage boost
      if (recentFoodIds.contains(food.id)) {
        score += 15.0;
      }

      scored.add(_ScoredRecommendation(food: food, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.food).toList();
  }
}

class _ScoredRecommendation {
  final FoodEntity food;
  final double score;

  const _ScoredRecommendation({required this.food, required this.score});
}
