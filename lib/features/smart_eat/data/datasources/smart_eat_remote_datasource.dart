import '../../../food/domain/entities/food_entity.dart';
import '../../../food/domain/repositories/food_repository.dart';
import '../../../grocery/domain/entities/grocery_list_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../../grocery/domain/repositories/i_grocery_repository.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/repositories/i_health_repository.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/repositories/i_nutrition_repository.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/domain/repositories/i_profile_repository.dart';
import '../../../food/data/datasources/predefined_food_data.dart';
import '../../../food/data/repositories/food_asset_repository.dart';

abstract class SmartEatRemoteDataSource {
  Future<UserProfileEntity?> getUserProfile(String uid);
  Future<NutritionGoalsEntity?> getNutritionGoals(String uid);
  Future<List<NutritionRecordEntity>> getNutritionHistory(String uid);
  Future<HealthRecordEntity?> getTodayHealthRecord(String uid, DateTime today);
  Future<List<PantryItemEntity>> getPantryItems(String uid);
  Future<List<GroceryListEntity>> getGroceryLists(String uid);
  Future<List<FoodEntity>> getAllFoods(String uid);
  Future<List<FoodEntity>> getFavoriteFoods(String uid);
  Future<List<FoodEntity>> getRecentFoods(String uid);
}

class SmartEatRemoteDataSourceImpl implements SmartEatRemoteDataSource {
  final FoodRepository _foodRepository;
  final IProfileRepository _profileRepository;
  final INutritionRepository _nutritionRepository;
  final IHealthRepository _healthRepository;
  final IGroceryRepository _groceryRepository;

  SmartEatRemoteDataSourceImpl({
    required FoodRepository foodRepository,
    required IProfileRepository profileRepository,
    required INutritionRepository nutritionRepository,
    required IHealthRepository healthRepository,
    required IGroceryRepository groceryRepository,
  })  : _foodRepository = foodRepository,
        _profileRepository = profileRepository,
        _nutritionRepository = nutritionRepository,
        _healthRepository = healthRepository,
        _groceryRepository = groceryRepository;

  @override
  Future<UserProfileEntity?> getUserProfile(String uid) async {
    try {
      final profile = await _profileRepository.getProfile(uid);
      if (profile != null) return profile;
    } catch (_) {}
    
    try {
      final cachedProfile = await _profileRepository.getProfileStream(uid).first.timeout(const Duration(milliseconds: 500));
      if (cachedProfile != null) return cachedProfile;
    } catch (_) {}

    return UserProfileEntity(
      uid: uid,
      email: '',
      displayName: 'FitFuel User',
      age: 25,
      gender: 'Male',
      height: 175.0,
      weight: 70.0,
      activityLevel: 'Moderately Active',
      fitnessGoal: 'Maintain Weight',
      dietaryPreference: 'Anything',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<NutritionGoalsEntity?> getNutritionGoals(String uid) async {
    try {
      final goals = await _profileRepository.getGoals(uid);
      if (goals != null) return goals;
    } catch (_) {}

    try {
      final cachedGoals = await _profileRepository.getGoalsStream(uid).first.timeout(const Duration(milliseconds: 500));
      if (cachedGoals != null) return cachedGoals;
    } catch (_) {}

    return NutritionGoalsEntity(
      userId: uid,
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 150.0,
      carbsTargetGrams: 200.0,
      fatTargetGrams: 67.0,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<NutritionRecordEntity>> getNutritionHistory(String uid) async {
    try {
      return await _nutritionRepository.getRecords(uid);
    } catch (_) {
      try {
        return await _nutritionRepository.streamRecords(uid).first.timeout(const Duration(milliseconds: 500));
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<HealthRecordEntity?> getTodayHealthRecord(String uid, DateTime today) async {
    final dateStr = today.toString().split(' ').first;
    try {
      return await _healthRepository.getRecord(uid, dateStr);
    } catch (_) {
      try {
        final cached = await _healthRepository.streamRecord(uid, dateStr).first.timeout(const Duration(milliseconds: 500));
        if (cached != null) return cached;
      } catch (_) {}
      return HealthRecordEntity.empty(dateStr);
    }
  }

  @override
  Future<List<PantryItemEntity>> getPantryItems(String uid) async {
    try {
      return await _groceryRepository.streamPantryItems(uid).first.timeout(const Duration(milliseconds: 500));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<GroceryListEntity>> getGroceryLists(String uid) async {
    try {
      return await _groceryRepository.streamGroceryLists(uid).first.timeout(const Duration(milliseconds: 500));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<FoodEntity>> getAllFoods(String uid) async {
    final List<FoodEntity> all = [];
    final repo = FoodAssetRepository.instance;
    for (final m in PredefinedFoodData.foods) {
      var entity = m.toEntity();
      final recipe = repo.getRecipe(entity.id);
      final img = repo.getImage(entity.id);
      entity = entity.copyWith(
        imageAsset: img.isNotEmpty ? img : entity.imageAsset,
        dietType: recipe?.dietType,
        cuisine: recipe?.cuisine,
        ingredients: recipe?.ingredients.map((i) => i.name).toList(),
        instructions: recipe?.instructions,
        prepTimeMinutes: recipe?.prepTimeMinutes,
        cookTimeMinutes: recipe?.cookTimeMinutes,
        totalTimeMinutes: recipe?.totalTimeMinutes,
        servings: recipe?.baseServings.toInt(),
        difficulty: recipe?.difficulty,
      );
      all.add(entity);
    }
    try {
      final customs = await _foodRepository.getCustomFoods();
      all.addAll(customs);
    } catch (_) {}
    return all;
  }

  @override
  Future<List<FoodEntity>> getFavoriteFoods(String uid) async {
    try {
      return await _foodRepository.getFavoriteFoods();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<FoodEntity>> getRecentFoods(String uid) async {
    try {
      return await _foodRepository.getRecentFoods();
    } catch (_) {
      return [];
    }
  }
}
