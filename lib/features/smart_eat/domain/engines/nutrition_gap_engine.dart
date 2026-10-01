import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../entities/nutrition_gap_entity.dart';

class NutritionGapEngine {
  static NutritionGapEntity calculate({
    required UserProfileEntity? profile,
    required NutritionGoalsEntity? goals,
    required List<NutritionRecordEntity> todayRecords,
    required HealthRecordEntity? todayHealth,
  }) {
    final calorieTarget = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final proteinTarget = goals?.proteinTargetGrams ?? 100.0;
    final carbsTarget = goals?.carbsTargetGrams ?? 200.0;
    final fatTarget = goals?.fatTargetGrams ?? 65.0;
    const fiberTarget = 30.0; // standard fiber target
    final waterTarget = todayHealth?.waterTargetMl ?? 2000.0;

    double loggedCalories = 0.0;
    double loggedProtein = 0.0;
    double loggedCarbs = 0.0;
    double loggedFat = 0.0;
    double loggedFiber = 0.0;

    for (final r in todayRecords) {
      loggedCalories += r.calories;
      loggedProtein += r.protein;
      loggedCarbs += r.carbohydrates;
      loggedFat += r.fats;
    }

    final loggedWater = todayHealth?.waterIntakeMl ?? 0.0;

    final remainingCalories = calorieTarget - loggedCalories;
    final remainingProtein = proteinTarget - loggedProtein;
    final remainingCarbs = carbsTarget - loggedCarbs;
    final remainingFat = fatTarget - loggedFat;
    final remainingFiber = fiberTarget - loggedFiber;
    final remainingWater = waterTarget - loggedWater;

    final proteinDeficit = remainingProtein > (proteinTarget * 0.2);
    final calorieDeficit = remainingCalories > (calorieTarget * 0.2);
    final calorieExcess = remainingCalories < 0;
    final fiberDeficit = remainingFiber > 5.0;
    final hydrationDeficit = remainingWater > 500.0;

    return NutritionGapEntity(
      remainingCalories: remainingCalories,
      remainingProtein: remainingProtein,
      remainingCarbs: remainingCarbs,
      remainingFat: remainingFat,
      remainingFiber: remainingFiber,
      remainingWater: remainingWater,
      proteinDeficit: proteinDeficit,
      calorieDeficit: calorieDeficit,
      calorieExcess: calorieExcess,
      fiberDeficit: fiberDeficit,
      hydrationDeficit: hydrationDeficit,
    );
  }
}
