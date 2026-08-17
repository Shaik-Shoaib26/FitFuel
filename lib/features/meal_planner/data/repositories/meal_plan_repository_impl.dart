import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/repositories/meal_plan_repository.dart';
import 'package:fitfuel/features/meal_planner/data/datasources/meal_plan_datasource.dart';
import 'package:fitfuel/features/meal_planner/data/models/meal_plan_model.dart';

class MealPlanRepositoryImpl implements MealPlanRepository {
  final MealPlanDataSource _dataSource;

  MealPlanRepositoryImpl(this._dataSource);

  @override
  Future<MealPlanEntity?> getMealPlanForDate(String userId, DateTime date) async {
    final model = await _dataSource.getMealPlanForDate(userId, date);
    return model?.toEntity();
  }

  @override
  Future<void> saveMealPlan(String userId, MealPlanEntity mealPlan) async {
    final model = MealPlanModel.fromEntity(mealPlan);
    await _dataSource.saveMealPlan(userId, model);
  }

  @override
  Future<void> deleteMealPlan(String userId, String mealPlanId) async {
    await _dataSource.deleteMealPlan(userId, mealPlanId);
  }
}
