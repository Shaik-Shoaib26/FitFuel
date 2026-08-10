import '../../domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';

class NutritionProgressData {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final double calorieProgress;
  final double proteinProgress;
  final double carbsProgress;
  final double fatProgress;

  const NutritionProgressData({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.calorieProgress,
    required this.proteinProgress,
    required this.carbsProgress,
    required this.fatProgress,
  });
}

class NutritionCalculator {
  /// Filters records that occurred on the same day as [targetDate]
  static List<NutritionRecordEntity> filterByDay(List<NutritionRecordEntity> records, DateTime targetDate) {
    return records.where((r) {
      return r.consumedAt.year == targetDate.year &&
          r.consumedAt.month == targetDate.month &&
          r.consumedAt.day == targetDate.day;
    }).toList();
  }

  /// Calculates progress statistics based on filtered daily records and nutrition goals
  static NutritionProgressData calculateProgress({
    required List<NutritionRecordEntity> dailyRecords,
    required NutritionGoalsEntity? goals,
  }) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFats = 0;

    for (final r in dailyRecords) {
      totalCalories += r.calories;
      totalProtein += r.protein;
      totalCarbs += r.carbohydrates;
      totalFats += r.fats;
    }

    final calorieGoal = goals?.dailyCalorieTarget ?? 2000;
    final proteinGoal = goals?.proteinTargetGrams ?? 150.0;
    final carbsGoal = goals?.carbsTargetGrams ?? 200.0;
    final fatGoal = goals?.fatTargetGrams ?? 65.0;

    final calorieProgress = calorieGoal > 0 ? (totalCalories / calorieGoal).clamp(0.0, 1.0) : 0.0;
    final proteinProgress = proteinGoal > 0 ? (totalProtein / proteinGoal).clamp(0.0, 1.0) : 0.0;
    final carbsProgress = carbsGoal > 0 ? (totalCarbs / carbsGoal).clamp(0.0, 1.0) : 0.0;
    final fatProgress = fatGoal > 0 ? (totalFats / fatGoal).clamp(0.0, 1.0) : 0.0;

    return NutritionProgressData(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFats: totalFats,
      calorieProgress: calorieProgress,
      proteinProgress: proteinProgress,
      carbsProgress: carbsProgress,
      fatProgress: fatProgress,
    );
  }
}
