import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';

class MealPlanEntity {
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

  final List<PlannedMealEntity> meals;
  
  final DateTime? generatedAt;
  final String? personalizationReason;

  const MealPlanEntity({
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

  PlannedMealEntity? get breakfast =>
      meals.where((m) => m.mealType.toLowerCase() == 'breakfast').firstOrNull;

  PlannedMealEntity? get morningSnack =>
      meals.where((m) => m.mealType.toLowerCase() == 'morning snack' || m.mealType.toLowerCase() == 'morning_snack').firstOrNull;

  PlannedMealEntity? get lunch =>
      meals.where((m) => m.mealType.toLowerCase() == 'lunch').firstOrNull;

  PlannedMealEntity? get eveningSnack =>
      meals.where((m) => m.mealType.toLowerCase() == 'evening snack' || m.mealType.toLowerCase() == 'evening_snack').firstOrNull;

  PlannedMealEntity? get dinner =>
      meals.where((m) => m.mealType.toLowerCase() == 'dinner').firstOrNull;

  double get totalCalories => plannedCalories;
  double get totalProtein => plannedProtein;
  double get totalCarbs => plannedCarbs;
  double get totalFat => plannedFat;
  double get totalFiber => meals.fold(0.0, (sum, m) => sum + m.foods.fold(0.0, (fSum, f) => fSum + f.fiber));

  double get calorieDifference => totalCalories - targetCalories;
  double get proteinDifference => totalProtein - targetProtein;

  MealPlanEntity copyWith({
    String? id,
    DateTime? date,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    double? consumedCalories,
    double? consumedProtein,
    double? consumedCarbs,
    double? consumedFat,
    double? plannedCalories,
    double? plannedProtein,
    double? plannedCarbs,
    double? plannedFat,
    List<PlannedMealEntity>? meals,
    DateTime? generatedAt,
    String? personalizationReason,
  }) {
    return MealPlanEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      consumedCalories: consumedCalories ?? this.consumedCalories,
      consumedProtein: consumedProtein ?? this.consumedProtein,
      consumedCarbs: consumedCarbs ?? this.consumedCarbs,
      consumedFat: consumedFat ?? this.consumedFat,
      plannedCalories: plannedCalories ?? this.plannedCalories,
      plannedProtein: plannedProtein ?? this.plannedProtein,
      plannedCarbs: plannedCarbs ?? this.plannedCarbs,
      plannedFat: plannedFat ?? this.plannedFat,
      meals: meals ?? this.meals,
      generatedAt: generatedAt ?? this.generatedAt,
      personalizationReason: personalizationReason ?? this.personalizationReason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          targetCalories == other.targetCalories &&
          targetProtein == other.targetProtein &&
          targetCarbs == other.targetCarbs &&
          targetFat == other.targetFat &&
          consumedCalories == other.consumedCalories &&
          consumedProtein == other.consumedProtein &&
          consumedCarbs == other.consumedCarbs &&
          consumedFat == other.consumedFat &&
          plannedCalories == other.plannedCalories &&
          plannedProtein == other.plannedProtein &&
          plannedCarbs == other.plannedCarbs &&
          plannedFat == other.plannedFat &&
          meals == other.meals &&
          generatedAt == other.generatedAt &&
          personalizationReason == other.personalizationReason;

  @override
  int get hashCode =>
      id.hashCode ^
      date.year.hashCode ^
      date.month.hashCode ^
      date.day.hashCode ^
      targetCalories.hashCode ^
      targetProtein.hashCode ^
      targetCarbs.hashCode ^
      targetFat.hashCode ^
      consumedCalories.hashCode ^
      consumedProtein.hashCode ^
      consumedCarbs.hashCode ^
      consumedFat.hashCode ^
      plannedCalories.hashCode ^
      plannedProtein.hashCode ^
      plannedCarbs.hashCode ^
      plannedFat.hashCode ^
      meals.hashCode ^
      generatedAt.hashCode ^
      personalizationReason.hashCode;
}
