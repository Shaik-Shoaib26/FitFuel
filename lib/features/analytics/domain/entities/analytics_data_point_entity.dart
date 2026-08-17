class AnalyticsDataPointEntity {
  final DateTime date;
  final double calories;
  final double calorieTarget;
  final double protein;
  final double proteinTarget;
  final double carbs;
  final double carbsTarget;
  final double fat;
  final double fatTarget;
  final double water;
  final double waterTarget;
  final double workoutMinutes;
  final double workoutCalories;
  final double habitCompletionRate;
  final double wellnessScore;
  final double? weight;
  final bool nutritionLogged;
  final bool waterLogged;
  final bool exerciseLogged;
  final bool habitsLogged;

  const AnalyticsDataPointEntity({
    required this.date,
    required this.calories,
    required this.calorieTarget,
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbsTarget,
    required this.fat,
    required this.fatTarget,
    required this.water,
    required this.waterTarget,
    required this.workoutMinutes,
    required this.workoutCalories,
    required this.habitCompletionRate,
    required this.wellnessScore,
    this.weight,
    required this.nutritionLogged,
    required this.waterLogged,
    required this.exerciseLogged,
    required this.habitsLogged,
  });
}
