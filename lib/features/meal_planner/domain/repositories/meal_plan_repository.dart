import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';

abstract class MealPlanRepository {
  /// Gets a meal plan for a specific date, if it exists
  Future<MealPlanEntity?> getMealPlanForDate(String userId, DateTime date);

  /// Saves or updates a meal plan
  Future<void> saveMealPlan(String userId, MealPlanEntity mealPlan);

  /// Deletes a meal plan
  Future<void> deleteMealPlan(String userId, String mealPlanId);
}
