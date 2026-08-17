import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/food/presentation/providers/food_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/ai_assistant/presentation/providers/ai_assistant_providers.dart';
import 'package:fitfuel/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:fitfuel/features/food/domain/utils/food_recommendation_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/adaptive_meal_planner_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_distribution_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_plan_calculator.dart';
import 'package:fitfuel/features/meal_planner/presentation/providers/meal_planner_providers.dart';

final mealPlannerControllerProvider = StateNotifierProvider<MealPlannerController, AsyncValue<MealPlanEntity?>>((ref) {
  return MealPlannerController(ref);
});

class MealPlannerController extends StateNotifier<AsyncValue<MealPlanEntity?>> {
  final Ref _ref;

  MealPlannerController(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen(authStateStreamProvider, (prev, next) {
      next.when(
        data: (user) {
          if (user != null) {
            loadTodayPlan();
          } else {
            state = const AsyncValue.data(null);
          }
        },
        loading: () {
          state = const AsyncValue.loading();
        },
        error: (err, stack) {
          state = AsyncValue.error(err, stack);
        },
      );
    }, fireImmediately: true);

    // Listen for food log updates to recalculate targets in real-time
    _ref.listen<AsyncValue<List<NutritionRecordEntity>>>(nutritionStreamProvider, (prev, next) {
      next.whenData((records) {
        final today = DateTime.now();
        final todayLogsList = records.where((r) {
          return r.consumedAt.year == today.year &&
              r.consumedAt.month == today.month &&
              r.consumedAt.day == today.day;
        }).toList();
        adaptPlanToLogs(todayLogsList);
      });
    });
  }

  List<String> _getExclusionsFromChat() {
    final aiState = _ref.read(aiAssistantControllerProvider);
    final messages = aiState.messages;
    
    final Set<String> excludedFoods = {};
    final triggers = ['no', 'avoid', 'cannot eat', 'don\'t want', 'rather than', 'exclude', 'without', 'cannot prefer'];
    final foodsList = ['chicken', 'eggs', 'yogurt', 'dal', 'paneer', 'oats', 'banana', 'rice', 'milk', 'vegetables', 'fish', 'meat', 'tofu', 'roti', 'chapati', 'dosa', 'idli', 'upma', 'poha'];
    
    for (final msg in messages) {
      if (msg.sender == MessageSender.user) {
        final tLower = msg.text.toLowerCase();
        for (final trigger in triggers) {
          if (tLower.contains(trigger)) {
            for (final food in foodsList) {
              if (tLower.contains(food)) {
                excludedFoods.add(food);
              }
            }
          }
        }
      }
    }
    return excludedFoods.toList();
  }

  Future<void> adaptPlanToLogs(List<NutritionRecordEntity> todayLogsList) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;
    
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) return;
    
    final goals = _ref.read(nutritionGoalsStreamProvider).value;
    final profile = _ref.read(currentProfileStreamProvider).value;
    if (goals == null || profile == null) return;
    
    try {
      final availableFoods = await _ref.read(searchFoodsProvider.future);
      final favoriteFoods = _ref.read(favoriteFoodsProvider).value ?? [];
      final recentFoods = _ref.read(recentFoodsProvider).value ?? [];
      final chatExclusions = _getExclusionsFromChat();

      final updatedPlan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: availableFoods,
        targetCalories: goals.dailyCalorieTarget.toDouble(),
        targetProtein: goals.proteinTargetGrams,
        targetCarbs: goals.carbsTargetGrams,
        targetFat: goals.fatTargetGrams,
        fitnessGoal: profile.fitnessGoal ?? 'Maintain Weight',
        activityLevel: profile.activityLevel ?? 'Moderately Active',
        dietaryPreference: profile.dietaryPreference ?? 'Any',
        excludedFoodNames: chatExclusions,
        favoriteFoodIds: favoriteFoods.map((f) => f.id).toList(),
        recentFoodIds: recentFoods.map((f) => f.id).toList(),
        todayLogs: todayLogsList,
        existingPlan: currentPlan,
      );

      state = AsyncValue.data(updatedPlan);
      await _ref.read(mealPlanRepositoryProvider).saveMealPlan(authUser.uid, updatedPlan);
    } catch (_) {}
  }

  Future<void> loadTodayPlan() async {
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(mealPlanRepositoryProvider);
      final today = DateTime.now();
      
      final plan = await repository.getMealPlanForDate(authUser.uid, today);
      state = AsyncValue.data(plan);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> generatePlan() async {
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) return;

    state = const AsyncValue.loading();
    try {
      final goals = _ref.read(nutritionGoalsStreamProvider).value;
      final profile = _ref.read(currentProfileStreamProvider).value;
      
      if (goals == null || profile == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final availableFoods = await _ref.read(searchFoodsProvider.future);
      if (availableFoods.isEmpty) {
        throw Exception('No foods available for meal planning.');
      }

      final favoriteFoods = _ref.read(favoriteFoodsProvider).value ?? [];
      final recentFoods = _ref.read(recentFoodsProvider).value ?? [];

      final today = DateTime.now();
      final todayLogsList = _ref.read(nutritionStreamProvider).value ?? [];
      final dailyLogs = todayLogsList.where((r) {
        return r.consumedAt.year == today.year &&
            r.consumedAt.month == today.month &&
            r.consumedAt.day == today.day;
      }).toList();

      final chatExclusions = _getExclusionsFromChat();

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: availableFoods,
        targetCalories: goals.dailyCalorieTarget.toDouble(),
        targetProtein: goals.proteinTargetGrams,
        targetCarbs: goals.carbsTargetGrams,
        targetFat: goals.fatTargetGrams,
        fitnessGoal: profile.fitnessGoal ?? 'Maintain Weight',
        activityLevel: profile.activityLevel ?? 'Moderately Active',
        dietaryPreference: profile.dietaryPreference ?? 'Any',
        excludedFoodNames: chatExclusions,
        favoriteFoodIds: favoriteFoods.map((f) => f.id).toList(),
        recentFoodIds: recentFoods.map((f) => f.id).toList(),
        todayLogs: dailyLogs,
      );

      final repository = _ref.read(mealPlanRepositoryProvider);
      await repository.saveMealPlan(authUser.uid, plan);

      state = AsyncValue.data(plan);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> regenerateMeal(PlannedMealEntity meal) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) return;

    final goals = _ref.read(nutritionGoalsStreamProvider).value;
    final profile = _ref.read(currentProfileStreamProvider).value;
    if (goals == null || profile == null) return;

    try {
      final availableFoods = await _ref.read(searchFoodsProvider.future);
      final chatExclusions = _getExclusionsFromChat();
      
      final filteredFoods = AdaptiveMealPlannerEngine.filterFoodsByDiet(availableFoods, profile.dietaryPreference ?? 'Any');
      
      List<String> usedInOtherMeals = [];
      for (var m in currentPlan.meals) {
        if (m.mealType != meal.mealType) {
          usedInOtherMeals.addAll(m.foods.map((f) => f.food.id));
        }
      }

      final List<String> currentFoodsExclusions = List.from(chatExclusions);
      currentFoodsExclusions.addAll(meal.foods.map((f) => f.food.name));

      final newMeal = MealDistributionEngine.regenerateMeal(
        currentMeal: meal,
        databaseFoods: filteredFoods,
        targetCalories: meal.totalCalories,
        targetProtein: meal.totalProtein,
        dietaryPreference: profile.dietaryPreference ?? 'Any',
        excludedFoodNames: currentFoodsExclusions,
        usedFoodIdsInOtherMeals: usedInOtherMeals,
      );

      final newMeals = currentPlan.meals.map((m) => m.mealType == meal.mealType ? newMeal : m).toList();
      var updatedPlan = currentPlan.copyWith(meals: newMeals);
      updatedPlan = MealPlanCalculator.recalculateMealPlan(updatedPlan);

      state = AsyncValue.data(updatedPlan);
      await _ref.read(mealPlanRepositoryProvider).saveMealPlan(authUser.uid, updatedPlan);
    } catch (e) {
      // Revert/ignore on error
    }
  }

  Future<List<PlannedFoodEntity>> getSwapAlternatives(
    PlannedMealEntity meal,
    PlannedFoodEntity foodToSwap,
  ) async {
    final currentPlan = state.value;
    if (currentPlan == null) return [];
    
    final profile = _ref.read(currentProfileStreamProvider).value;
    if (profile == null) return [];

    try {
      final availableFoods = await _ref.read(searchFoodsProvider.future);
      final chatExclusions = _getExclusionsFromChat();
      
      final filteredFoods = AdaptiveMealPlannerEngine.filterFoodsByDiet(availableFoods, profile.dietaryPreference ?? 'Any');
      
      List<String> currentlyUsedFoodIds = [];
      for (var m in currentPlan.meals) {
        currentlyUsedFoodIds.addAll(m.foods.map((f) => f.food.id));
      }

      final List<String> finalExclusions = List.from(chatExclusions);
      finalExclusions.add(foodToSwap.food.name);

      final recommendations = FoodRecommendationEngine.recommend(
        foods: filteredFoods.where((f) => !currentlyUsedFoodIds.contains(f.id)).toList(),
        mealType: meal.mealType,
        remainingCalories: foodToSwap.calories,
        proteinDeficit: foodToSwap.protein,
        dietaryPreference: profile.dietaryPreference ?? 'Any',
        excludedFoodNames: finalExclusions,
        favoriteFoodIds: [],
        recentFoodIds: [],
      );

      final List<PlannedFoodEntity> alternatives = [];
      for (final newFood in recommendations.take(5)) {
        double ratio = (foodToSwap.calories / newFood.calories).clamp(0.5, 2.5);
        double targetServing = newFood.servingSize * ratio;
        alternatives.add(MealPlanCalculator.calculateFoodPortion(newFood, targetServing, newFood.servingUnit));
      }
      return alternatives;
    } catch (_) {
      return [];
    }
  }

  Future<void> replaceFoodInMeal(
    PlannedMealEntity meal,
    PlannedFoodEntity oldFood,
    PlannedFoodEntity newFood,
  ) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) return;

    final updatedFoods = meal.foods.map((f) => f == oldFood ? newFood : f).toList();
    
    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    for (var pf in updatedFoods) {
      totalCal += pf.calories;
      totalPro += pf.protein;
      totalCarb += pf.carbohydrates;
      totalFat += pf.fat;
    }

    final updatedMeal = meal.copyWith(
      foods: updatedFoods,
      totalCalories: totalCal,
      totalProtein: totalPro,
      totalCarbs: totalCarb,
      totalFat: totalFat,
    );

    final newMeals = currentPlan.meals.map((m) => m.mealType == meal.mealType ? updatedMeal : m).toList();
    var updatedPlan = currentPlan.copyWith(meals: newMeals);
    updatedPlan = MealPlanCalculator.recalculateMealPlan(updatedPlan);

    state = AsyncValue.data(updatedPlan);
    await _ref.read(mealPlanRepositoryProvider).saveMealPlan(authUser.uid, updatedPlan);
  }

  Future<void> updateServingMultiplier(
    PlannedMealEntity meal,
    PlannedFoodEntity foodItem,
    double servingMultiplier,
  ) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;
    final authUser = _ref.read(authStateStreamProvider).value;
    if (authUser == null) return;

    final targetServing = foodItem.food.servingSize * servingMultiplier;
    final updatedFood = MealPlanCalculator.calculateFoodPortion(foodItem.food, targetServing, foodItem.unit);

    final updatedFoods = meal.foods.map((f) => f.food.id == foodItem.food.id ? updatedFood : f).toList();
    
    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    for (var pf in updatedFoods) {
      totalCal += pf.calories;
      totalPro += pf.protein;
      totalCarb += pf.carbohydrates;
      totalFat += pf.fat;
    }

    final updatedMeal = meal.copyWith(
      foods: updatedFoods,
      totalCalories: totalCal,
      totalProtein: totalPro,
      totalCarbs: totalCarb,
      totalFat: totalFat,
    );

    final newMeals = currentPlan.meals.map((m) => m.mealType == meal.mealType ? updatedMeal : m).toList();
    var updatedPlan = currentPlan.copyWith(meals: newMeals);
    updatedPlan = MealPlanCalculator.recalculateMealPlan(updatedPlan);

    state = AsyncValue.data(updatedPlan);
    await _ref.read(mealPlanRepositoryProvider).saveMealPlan(authUser.uid, updatedPlan);
  }

  Future<void> swapFood(PlannedMealEntity meal, PlannedFoodEntity foodToSwap) async {
    // Backward compatibility swapFood fallback which automatically replaces
    final alternatives = await getSwapAlternatives(meal, foodToSwap);
    if (alternatives.isNotEmpty) {
      await replaceFoodInMeal(meal, foodToSwap, alternatives.first);
    }
  }
}
