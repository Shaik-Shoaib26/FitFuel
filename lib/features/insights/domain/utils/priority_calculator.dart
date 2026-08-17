import '../entities/health_insight_entity.dart';

class PriorityCalculator {
  static InsightPriority calculateProteinPriority(double current, double target) {
    if (target <= 0) return InsightPriority.positive;
    final ratio = current / target;
    if (ratio < 0.40) return InsightPriority.high;
    if (ratio < 0.70) return InsightPriority.medium;
    if (ratio < 0.90) return InsightPriority.low;
    return InsightPriority.positive;
  }

  static InsightPriority calculateCaloriePriority(double current, double target) {
    if (target <= 0) return InsightPriority.positive;
    final ratio = current / target;
    if (ratio > 1.20) return InsightPriority.high;
    if (ratio < 0.80) return InsightPriority.medium;
    if (ratio < 0.95 || ratio > 1.05) return InsightPriority.low;
    return InsightPriority.positive;
  }

  static InsightPriority calculateHydrationPriority(double current, double target) {
    final deficit = target - current;
    if (deficit <= 0) return InsightPriority.positive;
    if (deficit > 1000) return InsightPriority.high;
    if (deficit > 500) return InsightPriority.medium;
    return InsightPriority.low;
  }

  static InsightPriority calculateExercisePriority(int currentActiveDays, int targetActiveDays) {
    if (targetActiveDays <= 0) return InsightPriority.positive;
    if (currentActiveDays >= targetActiveDays) return InsightPriority.positive;
    if (currentActiveDays == 0) return InsightPriority.high;
    return InsightPriority.medium;
  }

  static InsightPriority calculateHabitPriority(double completionRate) {
    if (completionRate < 0.50) return InsightPriority.high;
    if (completionRate < 0.80) return InsightPriority.medium;
    return InsightPriority.positive;
  }

  static InsightPriority calculateWellnessPriority(String trend) {
    final tLower = trend.toLowerCase();
    if (tLower.contains('declin')) return InsightPriority.high;
    if (tLower.contains('improv')) return InsightPriority.positive;
    return InsightPriority.low;
  }

  static InsightPriority calculateWeightPriority(double change, String fitnessGoal) {
    final goalLower = fitnessGoal.toLowerCase();
    if (goalLower.contains('lose')) {
      if (change < -0.1) return InsightPriority.positive;
      if (change > 0.5) return InsightPriority.medium;
      return InsightPriority.low;
    } else if (goalLower.contains('gain')) {
      if (change > 0.1) return InsightPriority.positive;
      if (change < -0.5) return InsightPriority.medium;
      return InsightPriority.low;
    }
    return InsightPriority.low;
  }
}
