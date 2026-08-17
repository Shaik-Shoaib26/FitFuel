import '../entities/food_entity.dart';

abstract class FoodRepository {
  Future<List<FoodEntity>> searchFoods(String query);
  Future<FoodEntity?> getFoodById(String id);
  Future<List<FoodEntity>> getFoodsByCategory(String category);
  Future<List<FoodEntity>> getFavoriteFoods();
  Future<List<FoodEntity>> getRecentFoods();
  Future<FoodEntity> addCustomFood(FoodEntity food);
  Future<void> updateCustomFood(FoodEntity food);
  Future<void> deleteCustomFood(String id);
  Future<void> toggleFavorite(String id);
  Future<void> addRecentFood(FoodEntity food);
  Future<List<FoodEntity>> getCustomFoods();
}
