import '../datasources/smart_eat_remote_datasource.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';
import '../../domain/entities/nutrition_gap_entity.dart';
import '../../domain/repositories/i_smart_eat_repository.dart';
import '../../domain/engines/nutrition_gap_engine.dart';
import '../../domain/engines/recommendation_scoring_engine.dart';
import '../../domain/engines/food_swap_engine.dart';

class SmartEatRepositoryImpl implements ISmartEatRepository {
  final SmartEatRemoteDataSource _remoteDataSource;

  SmartEatRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<SmartFoodRecommendationEntity>> getRecommendations({
    required String uid,
    required String currentMealType,
    required DateTime today,
    List<String> chatExclusions = const [],
  }) async {
    final profile = await _remoteDataSource.getUserProfile(uid);
    final goals = await _remoteDataSource.getNutritionGoals(uid);
    final nutritionHistory = await _remoteDataSource.getNutritionHistory(uid);
    final todayHealth = await _remoteDataSource.getTodayHealthRecord(uid, today);
    final pantry = await _remoteDataSource.getPantryItems(uid);
    final grocery = await _remoteDataSource.getGroceryLists(uid);
    final favoriteFoods = await _remoteDataSource.getFavoriteFoods(uid);
    final recentFoods = await _remoteDataSource.getRecentFoods(uid);
    final allFoods = await _remoteDataSource.getAllFoods(uid);

    final todayStr = today.toString().split(' ').first;
    final todayRecords = nutritionHistory.where((r) {
      return r.consumedAt.toString().split(' ').first == todayStr;
    }).toList();

    final gap = NutritionGapEngine.calculate(
      profile: profile,
      goals: goals,
      todayRecords: todayRecords,
      todayHealth: todayHealth,
    );

    return RecommendationScoringEngine.score(
      foods: allFoods,
      profile: profile,
      gap: gap,
      currentMealType: currentMealType,
      pantryItems: pantry,
      groceryLists: grocery,
      recentLogs: nutritionHistory,
      favoriteFoods: favoriteFoods,
      recentFoods: recentFoods,
      chatExclusions: chatExclusions,
    );
  }

  @override
  Future<NutritionGapEntity> getNutritionGap({
    required String uid,
    required DateTime today,
  }) async {
    final profile = await _remoteDataSource.getUserProfile(uid);
    final goals = await _remoteDataSource.getNutritionGoals(uid);
    final nutritionHistory = await _remoteDataSource.getNutritionHistory(uid);
    final todayHealth = await _remoteDataSource.getTodayHealthRecord(uid, today);

    final todayStr = today.toString().split(' ').first;
    final todayRecords = nutritionHistory.where((r) {
      return r.consumedAt.toString().split(' ').first == todayStr;
    }).toList();

    return NutritionGapEngine.calculate(
      profile: profile,
      goals: goals,
      todayRecords: todayRecords,
      todayHealth: todayHealth,
    );
  }

  @override
  Future<List<SmartFoodRecommendationEntity>> getSwaps({
    required String uid,
    required SmartFoodRecommendationEntity original,
    required DateTime today,
    List<String> chatExclusions = const [],
  }) async {
    final profile = await _remoteDataSource.getUserProfile(uid);
    final goals = await _remoteDataSource.getNutritionGoals(uid);
    final nutritionHistory = await _remoteDataSource.getNutritionHistory(uid);
    final todayHealth = await _remoteDataSource.getTodayHealthRecord(uid, today);
    final pantry = await _remoteDataSource.getPantryItems(uid);
    final grocery = await _remoteDataSource.getGroceryLists(uid);
    final favoriteFoods = await _remoteDataSource.getFavoriteFoods(uid);
    final recentFoods = await _remoteDataSource.getRecentFoods(uid);
    final allFoods = await _remoteDataSource.getAllFoods(uid);

    final todayStr = today.toString().split(' ').first;
    final todayRecords = nutritionHistory.where((r) {
      return r.consumedAt.toString().split(' ').first == todayStr;
    }).toList();

    final gap = NutritionGapEngine.calculate(
      profile: profile,
      goals: goals,
      todayRecords: todayRecords,
      todayHealth: todayHealth,
    );

    return FoodSwapEngine.findSwaps(
      original: original,
      foods: allFoods,
      profile: profile,
      gap: gap,
      pantryItems: pantry,
      groceryLists: grocery,
      recentLogs: nutritionHistory,
      favoriteFoods: favoriteFoods,
      recentFoods: recentFoods,
      chatExclusions: chatExclusions,
    );
  }
}
