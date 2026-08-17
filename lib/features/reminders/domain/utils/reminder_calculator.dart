import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';

class ReminderCalculator {
  static bool isHydrationComplete(HealthRecordEntity? todayHealth) {
    if (todayHealth == null) return false;
    return todayHealth.waterIntakeMl >= todayHealth.waterTargetMl;
  }

  static bool isMealLogged(List<NutritionRecordEntity> todayNutrition, String mealType) {
    final normalized = mealType.toLowerCase().trim();
    return todayNutrition.any((r) {
      final type = r.mealType.toLowerCase().trim();
      if (normalized == 'snack') {
        return type == 'snack' || type == 'snacks';
      }
      return type == normalized;
    });
  }

  static bool isExerciseComplete(HealthRecordEntity? todayHealth) {
    if (todayHealth == null) return false;
    return todayHealth.exercises.isNotEmpty;
  }

  static bool isHabitsComplete(HealthRecordEntity? todayHealth) {
    if (todayHealth == null) return false;
    if (todayHealth.habits.isEmpty) return true;
    return todayHealth.habits.values.every((v) => v);
  }

  static int incompleteHabitsCount(HealthRecordEntity? todayHealth) {
    if (todayHealth == null) return 0;
    return todayHealth.habits.values.where((v) => !v).length;
  }

  static bool isWeightLoggedRecently(List<WeightRecordEntity> weightHistory, {DateTime? referenceDate}) {
    if (weightHistory.isEmpty) return false;
    final now = referenceDate ?? DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);
    
    final sorted = List<WeightRecordEntity>.from(weightHistory)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latest = sorted.first.recordedAt;
    final latestMidnight = DateTime(latest.year, latest.month, latest.day);
    
    final diff = nowMidnight.difference(latestMidnight).inDays;
    return diff < 7;
  }

  static bool isWeeklyReviewAvailable(
      List<NutritionRecordEntity> nutritionHistory,
      List<HealthRecordEntity> healthHistory,
      List<WeightRecordEntity> weightHistory,
      {DateTime? referenceDate}) {
    final today = referenceDate ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 7));
    final dateStrings = List.generate(7, (i) => start.add(Duration(days: i)).toString().split(' ').first);

    final hasNutrition = nutritionHistory.any((r) => dateStrings.contains(r.consumedAt.toString().split(' ').first));
    final hasHealth = healthHistory.any((h) => dateStrings.contains(h.date));
    final hasWeight = weightHistory.any((w) => dateStrings.contains(w.recordedAt.toString().split(' ').first));

    return hasNutrition || hasHealth || hasWeight;
  }
}
