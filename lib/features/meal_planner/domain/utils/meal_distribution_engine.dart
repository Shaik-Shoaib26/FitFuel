import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_recommendation_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_plan_calculator.dart';

class MealDistributionEngine {
  /// Distributes calories and macros for a full day meal plan
  static List<PlannedMealEntity> generateDailyPlan({
    required List<FoodEntity> databaseFoods,
    required double targetCalories,
    required double targetProtein,
    required double targetCarbs,
    required double targetFat,
    required String dietaryPreference,
    required List<String> excludedFoodNames,
    required List<String> favoriteFoodIds,
    required List<String> recentFoodIds,
  }) {
    // Basic Distribution: Breakfast 25%, Morning Snack 10%, Lunch 30%, Evening Snack 10%, Dinner 25%
    final distributions = [
      {'meal': 'Breakfast', 'calRatio': 0.25, 'proRatio': 0.25},
      {'meal': 'Morning Snack', 'calRatio': 0.10, 'proRatio': 0.10},
      {'meal': 'Lunch', 'calRatio': 0.30, 'proRatio': 0.30},
      {'meal': 'Evening Snack', 'calRatio': 0.10, 'proRatio': 0.10},
      {'meal': 'Dinner', 'calRatio': 0.25, 'proRatio': 0.25},
    ];

    List<PlannedMealEntity> plannedMeals = [];
    List<String> usedFoodIds = [];

    for (var dist in distributions) {
      final mealType = dist['meal'] as String;
      final calRatio = dist['calRatio'] as double;
      final proRatio = dist['proRatio'] as double;

      final mealCalTarget = targetCalories * calRatio;
      final mealProTarget = targetProtein * proRatio;

      final recommendations = FoodRecommendationEngine.recommend(
        foods: databaseFoods.where((f) => !usedFoodIds.contains(f.id)).toList(),
        mealType: mealType,
        remainingCalories: mealCalTarget,
        proteinDeficit: mealProTarget,
        dietaryPreference: dietaryPreference,
        excludedFoodNames: excludedFoodNames,
        favoriteFoodIds: favoriteFoodIds,
        recentFoodIds: recentFoodIds,
      );

      List<PlannedFoodEntity> selectedFoods = [];
      double currentMealCals = 0.0;
      
      // Select 1-3 foods for this meal
      int count = 0;
      for (var food in recommendations) {
        if (currentMealCals >= mealCalTarget * 0.9 || count >= 3) break;
        
        // Calculate appropriate portion
        double remainingForMeal = mealCalTarget - currentMealCals;
        double ratio = (remainingForMeal / food.calories).clamp(0.5, 2.5); // Prevent tiny or huge portions
        
        // If portion is getting too small and we already have food, skip
        if (ratio < 0.5 && count > 0) continue;
        
        double targetServing = food.servingSize * ratio;
        final plannedFood = MealPlanCalculator.calculateFoodPortion(food, targetServing, food.servingUnit);
        
        selectedFoods.add(plannedFood);
        usedFoodIds.add(food.id);
        currentMealCals += plannedFood.calories;
        count++;
      }

      // If we somehow found zero foods, try to get at least one even if it breaks some rules (fallback)
      if (selectedFoods.isEmpty && databaseFoods.isNotEmpty) {
         final fallbackFood = databaseFoods.first;
         final plannedFood = MealPlanCalculator.calculateFoodPortion(fallbackFood, fallbackFood.servingSize, fallbackFood.servingUnit);
         selectedFoods.add(plannedFood);
      }

      // Calculate totals for the meal
      double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
      for (var pf in selectedFoods) {
        totalCal += pf.calories;
        totalPro += pf.protein;
        totalCarb += pf.carbohydrates;
        totalFat += pf.fat;
      }

      plannedMeals.add(PlannedMealEntity(
        mealType: mealType,
        foods: selectedFoods,
        totalCalories: totalCal,
        totalProtein: totalPro,
        totalCarbs: totalCarb,
        totalFat: totalFat,
      ));
    }

    return plannedMeals;
  }

  /// Regenerates a single meal
  static PlannedMealEntity regenerateMeal({
    required PlannedMealEntity currentMeal,
    required List<FoodEntity> databaseFoods,
    required double targetCalories,
    required double targetProtein,
    required String dietaryPreference,
    required List<String> excludedFoodNames,
    required List<String> usedFoodIdsInOtherMeals,
  }) {
    List<String> toExclude = List.from(excludedFoodNames);
    // Also exclude foods currently in this meal to ensure we get something new
    toExclude.addAll(currentMeal.foods.map((pf) => pf.food.name));

    final availableFoods = databaseFoods.where((f) => !usedFoodIdsInOtherMeals.contains(f.id)).toList();

    final recommendations = FoodRecommendationEngine.recommend(
        foods: availableFoods,
        mealType: currentMeal.mealType,
        remainingCalories: targetCalories,
        proteinDeficit: targetProtein,
        dietaryPreference: dietaryPreference,
        excludedFoodNames: toExclude,
        favoriteFoodIds: [],
        recentFoodIds: [],
    );

    List<PlannedFoodEntity> selectedFoods = [];
    double currentMealCals = 0.0;
    
    int count = 0;
    for (var food in recommendations) {
      if (currentMealCals >= targetCalories * 0.9 || count >= 3) break;
      
      double remainingForMeal = targetCalories - currentMealCals;
      double ratio = (remainingForMeal / food.calories).clamp(0.5, 2.5);
      
      if (ratio < 0.5 && count > 0) continue;
      
      double targetServing = food.servingSize * ratio;
      final plannedFood = MealPlanCalculator.calculateFoodPortion(food, targetServing, food.servingUnit);
      
      selectedFoods.add(plannedFood);
      currentMealCals += plannedFood.calories;
      count++;
    }

    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    for (var pf in selectedFoods) {
      totalCal += pf.calories;
      totalPro += pf.protein;
      totalCarb += pf.carbohydrates;
      totalFat += pf.fat;
    }

    return currentMeal.copyWith(
      foods: selectedFoods,
      totalCalories: totalCal,
      totalProtein: totalPro,
      totalCarbs: totalCarb,
      totalFat: totalFat,
    );
  }

  /// Swaps a specific food item
  static PlannedFoodEntity swapFood({
    required PlannedFoodEntity currentFood,
    required String mealType,
    required List<FoodEntity> databaseFoods,
    required String dietaryPreference,
    required List<String> excludedFoodNames,
    required List<String> currentlyUsedFoodIds,
  }) {
    List<String> toExclude = List.from(excludedFoodNames);
    toExclude.add(currentFood.food.name);

    final availableFoods = databaseFoods.where((f) => !currentlyUsedFoodIds.contains(f.id)).toList();

    final recommendations = FoodRecommendationEngine.recommend(
        foods: availableFoods,
        mealType: mealType,
        remainingCalories: currentFood.calories,
        proteinDeficit: currentFood.protein,
        dietaryPreference: dietaryPreference,
        excludedFoodNames: toExclude,
        favoriteFoodIds: [],
        recentFoodIds: [],
    );

    if (recommendations.isNotEmpty) {
      final newFood = recommendations.first;
      // Aim for similar calories
      double ratio = (currentFood.calories / newFood.calories).clamp(0.5, 2.5);
      double targetServing = newFood.servingSize * ratio;
      
      return MealPlanCalculator.calculateFoodPortion(newFood, targetServing, newFood.servingUnit);
    }
    
    // If no replacement found, return original
    return currentFood;
  }
}
