import '../entities/food_entity.dart';

/// ROOT CAUSE OF PANEER TIKKA REPETITION BUG:
/// Previously, the recommendation engine did not strictly exclude foods that failed to match
/// the active mealType. Instead, it only applied a soft score boost (+100 or +30 points) for category/meal-type match.
/// Since Paneer Tikka has a very high protein and favorable macro profile, its overall score remained
/// higher than actual breakfast/snack foods even without the timing boost, causing it to be suggested
/// for Breakfast, Morning Snack, Evening Snack, Lunch, and Dinner.
///
/// FIX:
/// We now apply strict meal-type filtering using a multi-step fallback hierarchy:
/// 1. Exact meal-type + dietary match
/// 2. Broad meal-type compatibility + dietary compatibility
/// 3. Dietary compatible (ignoring meal type)
/// 4. Broader compatible (relaxing diet checks, keeping exclusions)
/// 5. Safe empty state (No matching food found)
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
    final diet = dietaryPreference.toLowerCase().trim();
    final exclusions = excludedFoodNames.map((e) => e.toLowerCase().trim()).toList();

    // Helper functions for matching
    bool isMealTypeCompatible(List<String> foodMealTypes, String target) {
      if (foodMealTypes.isEmpty) return true;
      final cleanCurrent = target.toLowerCase().trim();
      for (final mt in foodMealTypes) {
        final cleanFoodMealType = mt.toLowerCase().trim();
        if (cleanFoodMealType == cleanCurrent) {
          return true;
        }
        // Handle 'Snacks' mapping to 'Morning Snack' or 'Evening Snack'
        if (cleanFoodMealType == 'snacks' || cleanFoodMealType == 'snack') {
          if (cleanCurrent.contains('snack')) {
            return true;
          }
        }
        // Also handle reverse
        if (cleanCurrent == 'snacks' || cleanCurrent == 'snack') {
          if (cleanFoodMealType.contains('snack')) {
            return true;
          }
        }
      }
      return false;
    }

    bool isBroadMealTypeCompatible(FoodEntity food, String target) {
      final cleanCurrent = target.toLowerCase().trim();
      if (cleanCurrent == 'lunch' || cleanCurrent == 'dinner') {
        return isMealTypeCompatible(food.mealTypes, 'Lunch') || isMealTypeCompatible(food.mealTypes, 'Dinner');
      }
      if (cleanCurrent.contains('snack')) {
        return isMealTypeCompatible(food.mealTypes, 'Snacks') || isMealTypeCompatible(food.mealTypes, 'Breakfast');
      }
      if (cleanCurrent == 'breakfast') {
        return isMealTypeCompatible(food.mealTypes, 'Breakfast') || isMealTypeCompatible(food.mealTypes, 'Snacks');
      }
      return false;
    }

    bool isExcluded(FoodEntity food, List<String> excls) {
      bool matchesExcl(String name, String exc) {
        final n = name.toLowerCase().trim();
        final e = exc.toLowerCase().trim();
        if (e.isEmpty) return false;
        if (n.contains(e) || e.contains(n)) return true;
        final eSingular = e.endsWith('s') ? e.substring(0, e.length - 1) : e;
        final nSingular = n.endsWith('s') ? n.substring(0, n.length - 1) : n;
        if (n.contains(eSingular) || eSingular.contains(n) ||
            nSingular.contains(e) || e.contains(nSingular)) {
          return true;
        }
        return false;
      }

      for (final exc in excls) {
        if (exc.isEmpty) continue;
        if (matchesExcl(food.name, exc)) return true;
        if (food.ingredients != null) {
          for (final ing in food.ingredients!) {
            if (matchesExcl(ing, exc)) return true;
          }
        }
      }
      return false;
    }

    bool isDietaryCompatible(FoodEntity food, String preference) {
      final nameLower = food.name.toLowerCase().trim();
      if (preference == 'vegetarian') {
        if (food.id.startsWith('predefined_') && !food.isVegetarian) return false;
        if (nameLower.contains('chicken') ||
            nameLower.contains('salmon') ||
            nameLower.contains('beef') ||
            nameLower.contains('fish') ||
            nameLower.contains('meat') ||
            nameLower.contains('seafood') ||
            nameLower.contains('turkey')) {
          return false;
        }
      } else if (preference == 'vegan') {
        if (food.id.startsWith('predefined_') && !food.isVegan) return false;
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
            nameLower.contains('curd') ||
            nameLower.contains('egg') ||
            nameLower.contains('dairy') ||
            nameLower.contains('ghee') ||
            nameLower.contains('butter') ||
            nameLower.contains('cheese')) {
          return false;
        }
      } else if (preference == 'keto') {
        final carbPercent = food.calories > 0 ? (food.carbohydrates * 4) / food.calories : 0.0;
        if (food.carbohydrates > 12.0 || carbPercent > 0.15) {
          return false;
        }
        if (nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('idli') ||
            nameLower.contains('upma') ||
            nameLower.contains('poha') ||
            nameLower.contains('chapati') ||
            nameLower.contains('roti') ||
            nameLower.contains('paratha') ||
            nameLower.contains('banana') ||
            nameLower.contains('potato') ||
            nameLower.contains('oats')) {
          return false;
        }
      } else if (preference == 'paleo') {
        final categoryLower = food.category.toLowerCase();
        final containsGrainsOrDairy = categoryLower.contains('grain') ||
            categoryLower.contains('dairy') ||
            categoryLower.contains('legume') ||
            nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('idli') ||
            nameLower.contains('wheat') ||
            nameLower.contains('roti') ||
            nameLower.contains('chapati') ||
            nameLower.contains('paratha') ||
            nameLower.contains('upma') ||
            nameLower.contains('poha') ||
            nameLower.contains('bread') ||
            nameLower.contains('sugar') ||
            nameLower.contains('milk') ||
            nameLower.contains('cheese') ||
            nameLower.contains('paneer') ||
            nameLower.contains('curd') ||
            nameLower.contains('yogurt') ||
            nameLower.contains('butter') ||
            nameLower.contains('ghee') ||
            nameLower.contains('chana') ||
            nameLower.contains('dal') ||
            nameLower.contains('lentil');
        if (containsGrainsOrDairy) return false;
      } else if (preference == 'low carb' || preference == 'low_carb' || preference == 'lowcarb') {
        final carbPercent = food.calories > 0 ? (food.carbohydrates * 4) / food.calories : 0.0;
        if (food.carbohydrates > 20.0 || carbPercent > 0.30) {
          return false;
        }
        if (nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('banana') ||
            nameLower.contains('sweets')) {
          return false;
        }
      }
      return true;
    }

    // Step 1: Exact meal-type + dietary match + exclusions
    List<FoodEntity> candidates = foods.where((food) {
      if (isExcluded(food, exclusions)) return false;
      if (!isDietaryCompatible(food, diet)) return false;
      if (!isMealTypeCompatible(food.mealTypes, mealType)) return false;
      return true;
    }).toList();

    // Step 2: Meal-type compatible (broad check) + dietary compatible
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        if (!isBroadMealTypeCompatible(food, mealType)) return false;
        return true;
      }).toList();
    }

    // Step 3: Dietary compatible (ignoring meal type)
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        return true;
      }).toList();
    }

    // Step 4: Broader compatible (keeping dietary checks and exclusions)
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        return true;
      }).toList();
    }

    // If still absolutely empty, return empty list
    if (candidates.isEmpty) {
      return [];
    }

    // Score and rank candidates
    final List<_ScoredRecommendation> scored = [];
    for (final food in candidates) {
      final nameLower = food.name.toLowerCase();
      double score = 0.0;

      // Category suitability
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

      // Remaining calories suitability and minor calorie penalty
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

      // Protein Deficit priority
      if (proteinDeficit > 0) {
        final proteinDensity = food.protein / (food.calories > 0 ? food.calories : 1.0);
        score += proteinDensity * 150.0;
        score += food.protein * 2.0;

        if (food.protein >= 15.0) {
          score += 40.0;
        }
      } else {
        score += food.protein * 0.2;
      }

      // Micronutrients / Fiber
      score += food.fiber * 2.0;
      score -= food.sugar * 0.5;

      // Penalize liquid shakes/supplements for main meals (Lunch/Dinner)
      if ((mtLower == 'lunch' || mtLower == 'dinner') &&
          (nameLower.contains('shake') || nameLower.contains('powder') || nameLower.contains('supplement'))) {
        score -= 100.0;
      }

      // Favorites boost
      if (favoriteFoodIds.contains(food.id)) {
        score += 30.0;
      }

      // Recent usage boost
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
