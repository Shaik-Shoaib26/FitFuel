import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';

class MealPlanCalculator {
  /// Calculates macros for a food item given a specific serving quantity and unit
  static PlannedFoodEntity calculateFoodPortion(
      FoodEntity food, double targetServing, String unit) {
    // Assuming simple linear proportionality based on base servingSize
    final ratio = targetServing / food.servingSize;

    return PlannedFoodEntity(
      food: food,
      servingQuantity: targetServing,
      unit: unit,
      calories: food.calories * ratio,
      protein: food.protein * ratio,
      carbohydrates: food.carbohydrates * ratio,
      fat: food.fats * ratio,
      fiber: food.fiber * ratio,
    );
  }

  /// Recalculates total macros for a MealPlanEntity based on its constituent meals
  static MealPlanEntity recalculateMealPlan(MealPlanEntity plan) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    final updatedMeals = plan.meals.map((meal) {
      double mealCalories = 0;
      double mealProtein = 0;
      double mealCarbs = 0;
      double mealFat = 0;

      for (var pFood in meal.foods) {
        mealCalories += pFood.calories;
        mealProtein += pFood.protein;
        mealCarbs += pFood.carbohydrates;
        mealFat += pFood.fat;
      }

      totalCalories += mealCalories;
      totalProtein += mealProtein;
      totalCarbs += mealCarbs;
      totalFat += mealFat;

      return meal.copyWith(
        totalCalories: mealCalories,
        totalProtein: mealProtein,
        totalCarbs: mealCarbs,
        totalFat: mealFat,
      );
    }).toList();

    return plan.copyWith(
      plannedCalories: totalCalories,
      plannedProtein: totalProtein,
      plannedCarbs: totalCarbs,
      plannedFat: totalFat,
      meals: updatedMeals,
    );
  }
}
