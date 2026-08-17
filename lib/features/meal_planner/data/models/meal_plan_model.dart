import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/data/models/planned_meal_model.dart';

class MealPlanModel {
  final String id;
  final DateTime date;
  
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;

  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;

  final double plannedCalories;
  final double plannedProtein;
  final double plannedCarbs;
  final double plannedFat;

  final List<PlannedMealModel> meals;
  
  final DateTime? generatedAt;
  final String? personalizationReason;

  const MealPlanModel({
    required this.id,
    required this.date,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    this.consumedCalories = 0,
    this.consumedProtein = 0,
    this.consumedCarbs = 0,
    this.consumedFat = 0,
    this.plannedCalories = 0,
    this.plannedProtein = 0,
    this.plannedCarbs = 0,
    this.plannedFat = 0,
    this.meals = const [],
    this.generatedAt,
    this.personalizationReason,
  });

  factory MealPlanModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MealPlanModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory MealPlanModel.fromMap(Map<String, dynamic> data, String id) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final mealsList = (data['meals'] as List<dynamic>?) ?? [];

    return MealPlanModel(
      id: id,
      date: parseDateTime(data['date']) ?? DateTime.now(),
      targetCalories: parseDouble(data['targetCalories']),
      targetProtein: parseDouble(data['targetProtein']),
      targetCarbs: parseDouble(data['targetCarbs']),
      targetFat: parseDouble(data['targetFat']),
      consumedCalories: parseDouble(data['consumedCalories']),
      consumedProtein: parseDouble(data['consumedProtein']),
      consumedCarbs: parseDouble(data['consumedCarbs']),
      consumedFat: parseDouble(data['consumedFat']),
      plannedCalories: parseDouble(data['plannedCalories']),
      plannedProtein: parseDouble(data['plannedProtein']),
      plannedCarbs: parseDouble(data['plannedCarbs']),
      plannedFat: parseDouble(data['plannedFat']),
      meals: mealsList.map((e) => PlannedMealModel.fromMap(Map<String, dynamic>.from(e))).toList(),
      generatedAt: parseDateTime(data['generatedAt']),
      personalizationReason: data['personalizationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'consumedCalories': consumedCalories,
      'consumedProtein': consumedProtein,
      'consumedCarbs': consumedCarbs,
      'consumedFat': consumedFat,
      'plannedCalories': plannedCalories,
      'plannedProtein': plannedProtein,
      'plannedCarbs': plannedCarbs,
      'plannedFat': plannedFat,
      'meals': meals.map((e) => e.toMap()).toList(),
      'generatedAt': generatedAt != null ? Timestamp.fromDate(generatedAt!) : null,
      'personalizationReason': personalizationReason,
    };
  }

  factory MealPlanModel.fromEntity(MealPlanEntity entity) {
    return MealPlanModel(
      id: entity.id,
      date: entity.date,
      targetCalories: entity.targetCalories,
      targetProtein: entity.targetProtein,
      targetCarbs: entity.targetCarbs,
      targetFat: entity.targetFat,
      consumedCalories: entity.consumedCalories,
      consumedProtein: entity.consumedProtein,
      consumedCarbs: entity.consumedCarbs,
      consumedFat: entity.consumedFat,
      plannedCalories: entity.plannedCalories,
      plannedProtein: entity.plannedProtein,
      plannedCarbs: entity.plannedCarbs,
      plannedFat: entity.plannedFat,
      meals: entity.meals.map((e) => PlannedMealModel.fromEntity(e)).toList(),
      generatedAt: entity.generatedAt,
      personalizationReason: entity.personalizationReason,
    );
  }

  MealPlanEntity toEntity() {
    return MealPlanEntity(
      id: id,
      date: date,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      consumedCalories: consumedCalories,
      consumedProtein: consumedProtein,
      consumedCarbs: consumedCarbs,
      consumedFat: consumedFat,
      plannedCalories: plannedCalories,
      plannedProtein: plannedProtein,
      plannedCarbs: plannedCarbs,
      plannedFat: plannedFat,
      meals: meals.map((e) => e.toEntity()).toList(),
      generatedAt: generatedAt,
      personalizationReason: personalizationReason,
    );
  }
}
