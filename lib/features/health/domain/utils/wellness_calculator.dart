import '../entities/health_record_entity.dart';

class WellnessCalculator {
  /// Computes a Daily Wellness Score from 0 to 100
  static double calculateScore({
    required bool hasLoggedFoodToday,
    required HealthRecordEntity? healthRecord,
  }) {
    double nutritionPoints = hasLoggedFoodToday ? 25.0 : 0.0;

    if (healthRecord == null) {
      return nutritionPoints; // Return base points if no health logs exist yet
    }

    // Hydration: 25% (progress vs target)
    double hydrationPoints = 0.0;
    if (healthRecord.waterTargetMl > 0) {
      final ratio = healthRecord.waterIntakeMl / healthRecord.waterTargetMl;
      hydrationPoints = (ratio * 25.0).clamp(0.0, 25.0);
    }

    // Exercise: 25% (30 minutes target)
    double exercisePoints = 0.0;
    int totalMinutes = 0;
    for (final ex in healthRecord.exercises) {
      totalMinutes += ex.duration;
    }
    if (totalMinutes > 0) {
      final ratio = totalMinutes / 30.0;
      exercisePoints = (ratio * 25.0).clamp(0.0, 25.0);
    }

    // Habits: 25% (completed vs total)
    double habitPoints = 0.0;
    if (healthRecord.habits.isNotEmpty) {
      int completed = 0;
      healthRecord.habits.forEach((_, value) {
        if (value) completed++;
      });
      final ratio = completed / healthRecord.habits.length;
      habitPoints = ratio * 25.0;
    }

    return (nutritionPoints + hydrationPoints + exercisePoints + habitPoints).clamp(0.0, 100.0);
  }

  /// Filters list of health records by specific calendar date yyyy-MM-dd
  static HealthRecordEntity? filterByDate(List<HealthRecordEntity> records, String dateStr) {
    try {
      return records.firstWhere((r) => r.date == dateStr);
    } catch (_) {
      return null;
    }
  }
}
