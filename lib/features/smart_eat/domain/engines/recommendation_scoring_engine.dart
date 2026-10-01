import '../../../food/domain/entities/food_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../../grocery/domain/entities/grocery_list_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../entities/nutrition_gap_entity.dart';
import '../entities/recommendation_reason_entity.dart';
import '../entities/smart_food_recommendation_entity.dart';
import '../enums/recommendation_priority.dart';

/// ROOT CAUSE OF PANEER TIKKA REPETITION BUG:
/// Previously, the scoring engine scored all foods in the database regardless of whether
/// they matched the currentMealType or not. Mismatching foods only received a 0 contribution
/// to timing score, but were not excluded. Highly scoring foods (like Paneer Tikka due to
/// high protein/macros) therefore floated to the top of all meal types (Breakfast, Snacks, etc.).
///
/// FIX:
/// We now strictly filter candidates using the 5-step fallback hierarchy:
/// 1. Exact meal-type + dietary match + exclusions check
/// 2. broad meal-type compatible + dietary compatible
/// 3. dietary compatible only
/// 4. broader compatible only
/// 5. Safe empty state (No matching food found)
class RecommendationScoringEngine {
  static List<SmartFoodRecommendationEntity> score({
    required List<FoodEntity> foods,
    required UserProfileEntity? profile,
    required NutritionGapEntity gap,
    required String currentMealType,
    required List<PantryItemEntity> pantryItems,
    required List<GroceryListEntity> groceryLists,
    required List<NutritionRecordEntity> recentLogs,
    required List<FoodEntity> favoriteFoods,
    required List<FoodEntity> recentFoods,
    required List<String> chatExclusions,
  }) {
    final diet = profile?.dietaryPreference?.toLowerCase() ?? 'anything';
    final fitnessGoal = profile?.fitnessGoal ?? 'Maintain Weight';
    final exclusions = chatExclusions.map((e) => e.toLowerCase().trim()).toList();

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

    // Step 1: Exact meal-type + dietary match + exclusions check
    List<FoodEntity> candidates = foods.where((food) {
      if (isExcluded(food, exclusions)) return false;
      if (!isDietaryCompatible(food, diet)) return false;
      if (!isMealTypeCompatible(food.mealTypes, currentMealType)) return false;
      return true;
    }).toList();

    // Step 2: broad meal-type compatible + dietary compatible
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        if (!isBroadMealTypeCompatible(food, currentMealType)) return false;
        return true;
      }).toList();
    }

    // Step 3: dietary compatible only
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        return true;
      }).toList();
    }

    // Step 4: broader compatible only (keeping dietary checks and exclusions)
    if (candidates.isEmpty) {
      candidates = foods.where((food) {
        if (isExcluded(food, exclusions)) return false;
        if (!isDietaryCompatible(food, diet)) return false;
        return true;
      }).toList();
    }

    if (candidates.isEmpty) {
      return [];
    }

    final scored = <SmartFoodRecommendationEntity>[];

    for (final food in candidates) {
      final nameLower = food.name.toLowerCase().trim();

      // Calculate score breakdown
      final reasons = <RecommendationReasonEntity>[];
      int totalScore = 0;

      // 1. Timing suitability (Max 15)
      bool timingMatch = isMealTypeCompatible(food.mealTypes, currentMealType);
      if (timingMatch) {
        totalScore += 15;
        reasons.add(const RecommendationReasonEntity(
          title: 'Meal Suitability',
          description: 'Perfect timing for your current meal slot.',
          scoreContribution: 15,
        ));
      } else {
        reasons.add(const RecommendationReasonEntity(
          title: 'Timing Incompatibility',
          description: 'Normally eaten at other times of day.',
          scoreContribution: 0,
        ));
      }

      // 2. Calories & Macros Fit (Max 30)
      int macroScore = 0;
      if (gap.remainingCalories > 0) {
        if (food.calories <= gap.remainingCalories) {
          macroScore += 15;
        } else {
          macroScore += ((gap.remainingCalories / food.calories) * 15).round();
        }
      }
      if (gap.proteinDeficit) {
        final isHighProtein = food.protein >= 15.0 || (food.calories > 0 && (food.protein * 4) / food.calories >= 0.25);
        if (isHighProtein) {
          macroScore += 15;
        } else {
          macroScore += ((food.protein / 15.0) * 15).round().clamp(0, 15);
        }
      } else {
        macroScore += 10;
      }
      totalScore += macroScore;
      reasons.add(RecommendationReasonEntity(
        title: 'Macronutrient Alignment',
        description: gap.proteinDeficit
            ? 'Helps resolve today\'s remaining protein deficit.'
            : 'Fits cleanly within your remaining calorie target.',
        scoreContribution: macroScore,
      ));

      // 3. Goal Compatibility (Max 20)
      int goalScore = 0;
      if (fitnessGoal.toLowerCase().contains('lose')) {
        final isHighProtein = food.protein >= 15.0;
        final isHighFiber = food.fiber >= 3.0;
        if (isHighProtein) goalScore += 10;
        if (isHighFiber) goalScore += 10;
      } else if (fitnessGoal.toLowerCase().contains('gain')) {
        final isHighProtein = food.protein >= 15.0;
        final isCalorieDense = food.calories >= 250.0;
        if (isHighProtein) goalScore += 15;
        if (isCalorieDense) goalScore += 5;
      } else {
        final isBalanced = food.protein > 5.0 && food.carbohydrates > 10.0;
        goalScore += isBalanced ? 20 : 10;
      }
      totalScore += goalScore;
      reasons.add(RecommendationReasonEntity(
        title: 'Goal Compatibility',
        description: 'Optimized for your fitness goal of $fitnessGoal.',
        scoreContribution: goalScore,
      ));

      // 4. Pantry Availability (Max 15)
      bool pantryAvailable = false;
      for (final p in pantryItems) {
        final pName = p.foodName.toLowerCase().trim();
        if (pName.isNotEmpty && (nameLower.contains(pName) || pName.contains(nameLower))) {
          pantryAvailable = true;
        }
      }
      if (pantryAvailable) {
        totalScore += 15;
        reasons.add(const RecommendationReasonEntity(
          title: 'Pantry Synergy',
          description: 'Uses ingredients already available in your pantry.',
          scoreContribution: 15,
        ));
      }

      // 5. User Preference / Favorites (Max 10)
      final isFav = favoriteFoods.any((f) => f.id == food.id) || food.isFavorite;
      if (isFav) {
        totalScore += 10;
        reasons.add(const RecommendationReasonEntity(
          title: 'Favorite Food Boost',
          description: 'You\'ve previously saved this food as a favorite.',
          scoreContribution: 10,
        ));
      }

      // 6. Food History / Penalty (Max 10, subtracted if eaten recently)
      final recentLogsCount = recentLogs.where((l) => l.foodName.toLowerCase().trim() == nameLower).length;
      final inRecentList = recentFoods.any((f) => f.id == food.id || f.name.toLowerCase().trim() == nameLower);

      if (recentLogsCount > 1) {
        totalScore -= 20;
        reasons.add(const RecommendationReasonEntity(
          title: 'Recent Overconsumption',
          description: 'You\'ve eaten this multiple times recently. Variety is key!',
          scoreContribution: -20,
        ));
      } else if (recentLogsCount == 1 || inRecentList) {
        totalScore -= 10;
        reasons.add(const RecommendationReasonEntity(
          title: 'Recent History Penalty',
          description: 'Eaten recently. Suggesting alternatives for daily variety.',
          scoreContribution: -10,
        ));
      } else {
        totalScore += 10;
        reasons.add(const RecommendationReasonEntity(
          title: 'Dietary Variety',
          description: 'Adds healthy variety to your recent meal logs.',
          scoreContribution: 10,
        ));
      }

      // Grocery list detection
      bool groceryAvailable = false;
      for (final list in groceryLists) {
        for (final item in list.items) {
          final iName = item.foodName.toLowerCase().trim();
          if (iName.isNotEmpty && (nameLower.contains(iName) || iName.contains(nameLower))) {
            groceryAvailable = true;
          }
        }
      }

      // Tags generation
      final tags = <String>[];
      if (food.protein >= 15.0) tags.add('High Protein');
      if (food.fiber >= 3.0) tags.add('High Fiber');
      if (food.sugar < 2.0) tags.add('Low Sugar');
      if (pantryAvailable) tags.add('Pantry Available');
      if (groceryAvailable) tags.add('Grocery List');
      if (food.isVegetarian) tags.add('Vegetarian');
      if (food.isVegan) tags.add('Vegan');
      if (food.isIndian) tags.add('Indian');
      if (food.calories < 150) tags.add('Quick Snack');
      if (isFav) tags.add('Favorite');

      final finalScore = totalScore.clamp(0, 100);

      scored.add(SmartFoodRecommendationEntity(
        id: 'rec_${food.id}',
        foodId: food.id,
        foodName: food.name,
        imageUrl: food.imageAsset ?? '',
        category: food.category,
        servingSize: food.servingSize,
        calories: food.calories,
        protein: food.protein,
        carbs: food.carbohydrates,
        fat: food.fats,
        fiber: food.fiber,
        matchScore: finalScore,
        priority: finalScore >= 80
            ? RecommendationPriority.critical
            : (finalScore >= 60
                ? RecommendationPriority.high
                : (finalScore >= 40
                    ? RecommendationPriority.medium
                    : RecommendationPriority.low)),
        reasons: reasons,
        tags: tags,
        pantryAvailable: pantryAvailable,
        groceryAvailable: groceryAvailable,
        recentlyConsumed: recentLogsCount > 0 || inRecentList,
        isFavorite: isFav,
        estimatedPreparationMinutes: food.prepTimeMinutes ??
            (food.category.toLowerCase().contains('breakfast')
                ? 10
                : (food.category.toLowerCase().contains('lunch') || food.category.toLowerCase().contains('dinner')
                    ? 25
                    : 5)),
      ));
    }

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Balanced mix for dietaryPreference = Anything
    if (diet == 'anything' && scored.isNotEmpty) {
      final vegs = scored.where((r) => r.tags.contains('Vegetarian')).toList();
      final nonVegs = scored.where((r) => !r.tags.contains('Vegetarian')).toList();

      if (vegs.isNotEmpty && nonVegs.isNotEmpty) {
        final mixed = <SmartFoodRecommendationEntity>[];
        final firstIsVeg = vegs[0].matchScore >= nonVegs[0].matchScore;
        
        int vegIdx = 0;
        int nonVegIdx = 0;
        
        if (firstIsVeg) {
          mixed.add(vegs[vegIdx++]);
        } else {
          mixed.add(nonVegs[nonVegIdx++]);
        }
        
        bool pickVeg = !firstIsVeg;
        while (vegIdx < vegs.length || nonVegIdx < nonVegs.length) {
          if (pickVeg && vegIdx < vegs.length) {
            mixed.add(vegs[vegIdx++]);
            pickVeg = false;
          } else if (!pickVeg && nonVegIdx < nonVegs.length) {
            mixed.add(nonVegs[nonVegIdx++]);
            pickVeg = true;
          } else if (vegIdx < vegs.length) {
            mixed.add(vegs[vegIdx++]);
          } else if (nonVegIdx < nonVegs.length) {
            mixed.add(nonVegs[nonVegIdx++]);
          }
        }
        return mixed;
      }
    }

    return scored;
  }
}
