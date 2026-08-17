import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/features/meal_planner/data/datasources/meal_plan_datasource.dart';
import 'package:fitfuel/features/meal_planner/data/repositories/meal_plan_repository_impl.dart';
import 'package:fitfuel/features/meal_planner/domain/repositories/meal_plan_repository.dart';

final mealPlanDataSourceProvider = Provider<MealPlanDataSource>((ref) {
  return MealPlanRemoteDataSource(FirebaseFirestore.instance);
});

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  final dataSource = ref.watch(mealPlanDataSourceProvider);
  return MealPlanRepositoryImpl(dataSource);
});
