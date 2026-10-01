import 'recommendation_scoring_engine.dart';
import '../entities/smart_food_recommendation_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../../grocery/domain/entities/grocery_list_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../entities/nutrition_gap_entity.dart';

class FoodSwapEngine {
  static List<SmartFoodRecommendationEntity> findSwaps({
    required SmartFoodRecommendationEntity original,
    required List<FoodEntity> foods,
    required UserProfileEntity? profile,
    required NutritionGapEntity gap,
    required List<PantryItemEntity> pantryItems,
    required List<GroceryListEntity> groceryLists,
    required List<NutritionRecordEntity> recentLogs,
    required List<FoodEntity> favoriteFoods,
    required List<FoodEntity> recentFoods,
    required List<String> chatExclusions,
  }) {
    // 1. Get all scored recommendations
    final recommendations = RecommendationScoringEngine.score(
      foods: foods,
      profile: profile,
      gap: gap,
      currentMealType: original.category, // match by timing/category
      pantryItems: pantryItems,
      groceryLists: groceryLists,
      recentLogs: recentLogs,
      favoriteFoods: favoriteFoods,
      recentFoods: recentFoods,
      chatExclusions: chatExclusions,
    );

    return recommendations.where((rec) {
      if (rec.foodId == original.foodId) return false;

      final cleanRecName = rec.foodName.toLowerCase().trim();
      final cleanOriginalName = original.foodName.toLowerCase().trim();
      if (cleanRecName == cleanOriginalName) return false;

      final calorieDiff = (rec.calories - original.calories).abs();
      if (calorieDiff > 200.0) return false; // compatible calorie range

      final proteinDiff = (rec.protein - original.protein).abs();
      if (proteinDiff > 16.0) return false; // compatible protein range

      return true;
    }).toList();
  }
}
