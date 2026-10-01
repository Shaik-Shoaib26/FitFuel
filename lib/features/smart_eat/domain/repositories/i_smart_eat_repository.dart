import '../entities/smart_food_recommendation_entity.dart';
import '../entities/nutrition_gap_entity.dart';

abstract class ISmartEatRepository {
  Future<List<SmartFoodRecommendationEntity>> getRecommendations({
    required String uid,
    required String currentMealType,
    required DateTime today,
    List<String> chatExclusions = const [],
  });

  Future<NutritionGapEntity> getNutritionGap({
    required String uid,
    required DateTime today,
  });

  Future<List<SmartFoodRecommendationEntity>> getSwaps({
    required String uid,
    required SmartFoodRecommendationEntity original,
    required DateTime today,
    List<String> chatExclusions = const [],
  });
}
