import '../../domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';

class DailyAggregate {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  const DailyAggregate({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });
}

class HistorySummary {
  final List<DailyAggregate> dailyLogs;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFats;
  final List<String> insights;

  const HistorySummary({
    required this.dailyLogs,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFats,
    required this.insights,
  });
}

class AnalyticsAggregator {
  /// Aggregates list of records by calendar date
  static List<DailyAggregate> aggregateByDay(List<NutritionRecordEntity> records, {int daysCount = 30}) {
    final now = DateTime.now();
    final Map<String, List<NutritionRecordEntity>> grouped = {};

    // Group existing logs
    for (final r in records) {
      final key = _dateKey(r.consumedAt);
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final List<DailyAggregate> aggregates = [];

    // Ensure we create entries for all days within daysCount, even if empty
    for (int i = 0; i < daysCount; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final dayRecords = grouped[key] ?? [];

      double cals = 0;
      double pro = 0;
      double carbs = 0;
      double fats = 0;

      for (final r in dayRecords) {
        cals += r.calories;
        pro += r.protein;
        carbs += r.carbohydrates;
        fats += r.fats;
      }

      aggregates.add(DailyAggregate(
        date: date,
        totalCalories: cals,
        totalProtein: pro,
        totalCarbs: carbs,
        totalFats: fats,
      ));
    }

    // Sort chronologically (oldest to newest)
    return aggregates.reversed.toList();
  }

  /// Calculates summary statistics and returns rule-based insights
  static HistorySummary getHistorySummary(List<DailyAggregate> aggregates, NutritionGoalsEntity? goals) {
    if (aggregates.isEmpty) {
      return const HistorySummary(
        dailyLogs: [],
        avgCalories: 0,
        avgProtein: 0,
        avgCarbs: 0,
        avgFats: 0,
        insights: ['No logged data to analyze.'],
      );
    }

    double sumCals = 0;
    double sumPro = 0;
    double sumCarbs = 0;
    double sumFats = 0;

    // Filter out completely empty days for averages so we don't skew the insight logic
    final activeDays = aggregates.where((d) => d.totalCalories > 0).toList();

    for (final d in aggregates) {
      sumCals += d.totalCalories;
      sumPro += d.totalProtein;
      sumCarbs += d.totalCarbs;
      sumFats += d.totalFats;
    }

    final int divisor = activeDays.isNotEmpty ? activeDays.length : 1;
    final avgCals = sumCals / divisor;
    final avgPro = sumPro / divisor;
    final avgCarbs = sumCarbs / divisor;
    final avgFats = sumFats / divisor;

    final calTarget = goals?.dailyCalorieTarget ?? 2000;
    final proTarget = goals?.proteinTargetGrams ?? 150.0;

    final List<String> insights = [];

    // Rule-based insights
    if (goals == null) {
      insights.add('Configure your goals targets to unlock comparative insights.');
    } else {
      // 1. Calories check
      if (avgCals > calTarget + 50) {
        insights.add('You exceeded your calorie goal on average.');
      } else if (avgCals < calTarget * 0.9) {
        insights.add('You are consistently below your calorie goal.');
      } else if (avgCals >= calTarget * 0.9 && avgCals <= calTarget * 1.1) {
        insights.add('Your intake is close to your target.');
      }

      // 2. Protein check
      if (avgPro < proTarget * 0.95) {
        insights.add('Protein intake is below your target.');
      } else {
        insights.add('You hit your protein goal target successfully!');
      }
    }

    return HistorySummary(
      dailyLogs: aggregates,
      avgCalories: avgCals,
      avgProtein: avgPro,
      avgCarbs: avgCarbs,
      avgFats: avgFats,
      insights: insights,
    );
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
