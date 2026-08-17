import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/food_remote_datasource.dart';
import '../../data/datasources/predefined_food_data.dart';
import '../../data/repositories/food_repository_impl.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/utils/food_recommendation_engine.dart';
import '../../domain/utils/food_search_engine.dart';

final foodRemoteDataSourceProvider = Provider<FoodRemoteDataSource>((ref) {
  return FoodRemoteDataSourceImpl();
});

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final dataSource = ref.watch(foodRemoteDataSourceProvider);
  return FoodRepositoryImpl(dataSource);
});

// Search query states
final foodSearchQueryProvider = StateProvider<String>((ref) => '');
final foodCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Advanced Filter States
final foodDietFilterProvider = StateProvider<String>((ref) => 'Any');
final foodMealFilterProvider = StateProvider<String>((ref) => 'Any');
final foodCuisineFilterProvider = StateProvider<String>((ref) => 'Any');
final foodNutritionFiltersProvider = StateProvider<Set<String>>((ref) => const {});

// State Provider to trigger full refreshes easily
final foodRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Recommended foods matching active user profile, remaining budget, and meal type
final recommendedFoodsProvider = FutureProvider<List<FoodEntity>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  final profile = ref.watch(currentProfileStreamProvider).value;
  final goals = ref.watch(nutritionGoalsStreamProvider).value;
  final records = ref.watch(nutritionStreamProvider).value ?? [];
  final favorites = ref.watch(favoriteFoodsProvider).value ?? [];
  final recents = ref.watch(recentFoodsProvider).value ?? [];
  ref.watch(foodRefreshTriggerProvider);

  // Get all foods
  final allFoods = <FoodEntity>[];
  allFoods.addAll(PredefinedFoodData.foods.map((m) => m.toEntity()));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      final customFoods = await repo.getCustomFoods();
      allFoods.addAll(customFoods);
    } catch (_) {}
  }

  // Calculate consumed for today
  final now = DateTime.now();
  final todayRecords = records.where((r) {
    return r.consumedAt.year == now.year &&
        r.consumedAt.month == now.month &&
        r.consumedAt.day == now.day;
  }).toList();

  final consumedCals = todayRecords.fold(0.0, (sum, r) => sum + r.calories);
  final consumedPro = todayRecords.fold(0.0, (sum, r) => sum + r.protein);

  final goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
  final goalPro = goals?.proteinTargetGrams ?? 150.0;

  final remainingCals = goalCals - consumedCals;
  final proteinDeficit = goalPro - consumedPro;

  final dietPref = profile?.dietaryPreference ?? 'none';
  final favIds = favorites.map((f) => f.id).toList();
  final recentIds = recents.map((f) => f.id).toList();

  final hour = now.hour;
  String mealType = 'Snacks';
  if (hour >= 6 && hour < 11) {
    mealType = 'Breakfast';
  } else if (hour >= 11 && hour < 16) {
    mealType = 'Lunch';
  } else if (hour >= 16 && hour < 22) {
    mealType = 'Dinner';
  }

  return FoodRecommendationEngine.recommend(
    foods: allFoods,
    mealType: mealType,
    remainingCalories: remainingCals,
    proteinDeficit: proteinDeficit,
    dietaryPreference: dietPref,
    excludedFoodNames: [],
    favoriteFoodIds: favIds,
    recentFoodIds: recentIds,
  );
});

// Active Search foods matching query + category filter + advanced filters
final searchFoodsProvider = FutureProvider<List<FoodEntity>>((ref) async {
  final query = ref.watch(foodSearchQueryProvider);
  final category = ref.watch(foodCategoryFilterProvider);
  final diet = ref.watch(foodDietFilterProvider);
  final meal = ref.watch(foodMealFilterProvider);
  final cuisine = ref.watch(foodCuisineFilterProvider);
  final nutrition = ref.watch(foodNutritionFiltersProvider);

  final repo = ref.watch(foodRepositoryProvider);
  ref.watch(foodRefreshTriggerProvider); // Re-run when refreshed

  // Fetch all foods as base candidate list
  final allFoods = <FoodEntity>[];
  allFoods.addAll(PredefinedFoodData.foods.map((m) => m.toEntity()));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      final customFoods = await repo.getCustomFoods();
      allFoods.addAll(customFoods);
    } catch (_) {}
  }

  // 1. Search Query filter (using FoodSearchEngine if not empty)
  List<FoodEntity> filtered = allFoods;
  if (query.trim().isNotEmpty) {
    filtered = FoodSearchEngine.search(foods: allFoods, query: query);
  }

  // 2. Category filter
  if (category != null && category.toLowerCase() != 'all') {
    filtered = filtered.where((food) {
      final cleanCat = category.toLowerCase().trim();
      if (cleanCat == 'indian') return food.isIndian;
      if (cleanCat == 'breakfast') return food.mealTypes.contains('Breakfast');
      if (cleanCat == 'lunch') return food.mealTypes.contains('Lunch');
      if (cleanCat == 'dinner') return food.mealTypes.contains('Dinner');
      if (cleanCat == 'snacks') return food.mealTypes.contains('Snacks') || food.mealTypes.contains('Snack') || food.category.toLowerCase() == 'snacks';
      if (cleanCat == 'healthy / fitness' || cleanCat == 'healthy' || cleanCat == 'fitness') {
        return food.dietaryTags.contains('Healthy') || food.dietaryTags.contains('Fitness') || food.dietaryTags.contains('Low Calorie') || food.dietaryTags.contains('High Protein');
      }
      return food.category.toLowerCase().trim() == cleanCat;
    }).toList();
  }

  // 3. Diet filter (Any, Vegetarian, Vegan, Non-Vegetarian)
  if (diet != 'Any') {
    filtered = filtered.where((food) {
      if (diet == 'Vegetarian') return food.isVegetarian;
      if (diet == 'Vegan') return food.isVegan;
      if (diet == 'Non-Vegetarian') return !food.isVegetarian && !food.isVegan;
      return true;
    }).toList();
  }

  // 4. Meal filter (Any, Breakfast, Lunch, Dinner, Snack)
  if (meal != 'Any') {
    filtered = filtered.where((food) {
      final mLower = meal.toLowerCase();
      if (mLower == 'snack') {
        return food.mealTypes.contains('Snack') || food.mealTypes.contains('Snacks');
      }
      return food.mealTypes.any((mt) => mt.toLowerCase() == mLower);
    }).toList();
  }

  // 5. Cuisine filter (Any, Indian, International)
  if (cuisine != 'Any') {
    filtered = filtered.where((food) {
      if (cuisine == 'Indian') return food.isIndian;
      if (cuisine == 'International') return !food.isIndian;
      return true;
    }).toList();
  }

  // 6. Nutrition filters (Set of: High Protein, Low Calorie, Low Fat, Low Sugar, High Fiber)
  if (nutrition.isNotEmpty) {
    filtered = filtered.where((food) {
      return nutrition.every((nut) {
        if (nut == 'High Protein') return food.protein >= 10.0 || food.dietaryTags.contains('High Protein');
        if (nut == 'Low Calorie') return food.calories <= 150.0 || food.dietaryTags.contains('Low Calorie');
        if (nut == 'Low Fat') return food.fats <= 3.0 || food.dietaryTags.contains('Low Fat');
        if (nut == 'Low Sugar') return food.sugar <= 2.0 || food.dietaryTags.contains('Low Sugar');
        if (nut == 'High Fiber') return food.fiber >= 3.0 || food.dietaryTags.contains('High Fiber');
        return true;
      });
    }).toList();
  }

  return filtered;
});

// Custom Foods Notifier Provider
final customFoodsProvider = StateNotifierProvider<CustomFoodsNotifier, AsyncValue<List<FoodEntity>>>((ref) {
  final repo = ref.watch(foodRepositoryProvider);
  return CustomFoodsNotifier(repo, ref);
});

class CustomFoodsNotifier extends StateNotifier<AsyncValue<List<FoodEntity>>> {
  final FoodRepository _repository;
  final Ref _ref;

  CustomFoodsNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen(authStateStreamProvider, (prev, next) {
      load();
    }, fireImmediately: true);
  }

  Future<void> load() async {
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getCustomFoods();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<FoodEntity> addFood(FoodEntity food) async {
    final result = await _repository.addCustomFood(food);
    await load();
    _ref.read(foodRefreshTriggerProvider.notifier).state++;
    return result;
  }

  Future<void> updateFood(FoodEntity food) async {
    await _repository.updateCustomFood(food);
    await load();
    _ref.read(foodRefreshTriggerProvider.notifier).state++;
  }

  Future<void> deleteFood(String id) async {
    await _repository.deleteCustomFood(id);
    await load();
    _ref.read(foodRefreshTriggerProvider.notifier).state++;
  }
}

// Favorite Foods Notifier Provider
final favoriteFoodsProvider = StateNotifierProvider<FavoriteFoodsNotifier, AsyncValue<List<FoodEntity>>>((ref) {
  final repo = ref.watch(foodRepositoryProvider);
  return FavoriteFoodsNotifier(repo, ref);
});

class FavoriteFoodsNotifier extends StateNotifier<AsyncValue<List<FoodEntity>>> {
  final FoodRepository _repository;
  final Ref _ref;

  FavoriteFoodsNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen(authStateStreamProvider, (prev, next) {
      load();
    }, fireImmediately: true);
  }

  Future<void> load() async {
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getFavoriteFoods();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleFavorite(String id) async {
    await _repository.toggleFavorite(id);
    await load();
    _ref.read(foodRefreshTriggerProvider.notifier).state++;
    // Also reload custom foods to update their isFavorite status
    _ref.read(customFoodsProvider.notifier).load();
  }
}

// Recent Foods Notifier Provider
final recentFoodsProvider = StateNotifierProvider<RecentFoodsNotifier, AsyncValue<List<FoodEntity>>>((ref) {
  final repo = ref.watch(foodRepositoryProvider);
  return RecentFoodsNotifier(repo, ref);
});

class RecentFoodsNotifier extends StateNotifier<AsyncValue<List<FoodEntity>>> {
  final FoodRepository _repository;
  final Ref _ref;

  RecentFoodsNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen(authStateStreamProvider, (prev, next) {
      load();
    }, fireImmediately: true);
  }

  Future<void> load() async {
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getRecentFoods();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addRecent(FoodEntity food) async {
    await _repository.addRecentFood(food);
    await load();
  }
}
