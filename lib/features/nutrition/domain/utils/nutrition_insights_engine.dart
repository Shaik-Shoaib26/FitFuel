import '../../domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import './analytics_aggregator.dart';

class IntelligenceInsight {
  final String title;
  final String description;
  final String action;
  final bool isPositive;

  const IntelligenceInsight({
    required this.title,
    required this.description,
    required this.action,
    required this.isPositive,
  });
}

enum TrendDirection {
  improving,
  declining,
  stable,
}

class MetricTrend {
  final String metricName;
  final TrendDirection direction;
  final double changePercentage;

  const MetricTrend({
    required this.metricName,
    required this.direction,
    required this.changePercentage,
  });
}

class IntelligenceResult {
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFats;
  final double goalAchievementPercent;
  final int loggedDaysCount;
  final double consistencyScore;
  final List<MetricTrend> trends;
  final List<IntelligenceInsight> insights;

  const IntelligenceResult({
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFats,
    required this.goalAchievementPercent,
    required this.loggedDaysCount,
    required this.consistencyScore,
    required this.trends,
    required this.insights,
  });
}

class NutritionInsightsEngine {
  /// Analyzes the user's logs and goals to output advanced nutrition metrics
  static IntelligenceResult analyzeHistory({
    required List<NutritionRecordEntity> records,
    required NutritionGoalsEntity? goals,
    int daysCount = 7,
  }) {
    final dailyLogs = AnalyticsAggregator.aggregateByDay(records, daysCount: daysCount);
    final double goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double goalPro = goals?.proteinTargetGrams ?? 150.0;
    final double goalCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double goalFats = goals?.fatTargetGrams ?? 65.0;

    int activeLoggedDays = 0;
    double sumCals = 0;
    double sumPro = 0;
    double sumCarbs = 0;
    double sumFats = 0;

    for (final day in dailyLogs) {
      if (day.totalCalories > 0) {
        activeLoggedDays++;
        sumCals += day.totalCalories;
        sumPro += day.totalProtein;
        sumCarbs += day.totalCarbs;
        sumFats += day.totalFats;
      }
    }

    final double avgCals = activeLoggedDays > 0 ? sumCals / activeLoggedDays : 0.0;
    final double avgPro = activeLoggedDays > 0 ? sumPro / activeLoggedDays : 0.0;
    final double avgCarbs = activeLoggedDays > 0 ? sumCarbs / activeLoggedDays : 0.0;
    final double avgFats = activeLoggedDays > 0 ? sumFats / activeLoggedDays : 0.0;

    // Consistency score = percentage of logged days out of total requested timeframe days
    final double consistencyScore = (activeLoggedDays / daysCount) * 100.0;

    // Goal achievement rate (Calories)
    final double achievementPercent = goalCals > 0 ? (avgCals / goalCals) * 100.0 : 0.0;

    // Trend Analysis (Last 3 days vs Previous 4 days)
    final trends = _calculateTrends(dailyLogs, goalCals, goalPro, goalCarbs, goalFats);

    // Insight generation
    final insights = _generateInsights(
      avgCals: avgCals,
      avgPro: avgPro,
      avgCarbs: avgCarbs,
      avgFats: avgFats,
      goalCals: goalCals,
      goalPro: goalPro,
      goalCarbs: goalCarbs,
      goalFats: goalFats,
      consistencyScore: consistencyScore,
      activeLoggedDays: activeLoggedDays,
      goals: goals,
    );

    return IntelligenceResult(
      avgCalories: avgCals,
      avgProtein: avgPro,
      avgCarbs: avgCarbs,
      avgFats: avgFats,
      goalAchievementPercent: achievementPercent,
      loggedDaysCount: activeLoggedDays,
      consistencyScore: consistencyScore,
      trends: trends,
      insights: insights,
    );
  }

  static List<MetricTrend> _calculateTrends(
    List<DailyAggregate> aggregates,
    double goalCals,
    double goalPro,
    double goalCarbs,
    double goalFats,
  ) {
    if (aggregates.length < 7) {
      return const [
        MetricTrend(metricName: 'Calories', direction: TrendDirection.stable, changePercentage: 0.0),
        MetricTrend(metricName: 'Protein', direction: TrendDirection.stable, changePercentage: 0.0),
        MetricTrend(metricName: 'Carbohydrates', direction: TrendDirection.stable, changePercentage: 0.0),
        MetricTrend(metricName: 'Fats', direction: TrendDirection.stable, changePercentage: 0.0),
      ];
    }

    // Split: last 3 aggregates vs previous 4
    final last3 = aggregates.sublist(aggregates.length - 3);
    final prev4 = aggregates.sublist(0, aggregates.length - 3);

    double avgLast3Cal = last3.map((a) => a.totalCalories).reduce((a, b) => a + b) / 3;
    double avgPrev4Cal = prev4.map((a) => a.totalCalories).reduce((a, b) => a + b) / 4;

    double avgLast3Pro = last3.map((a) => a.totalProtein).reduce((a, b) => a + b) / 3;
    double avgPrev4Pro = prev4.map((a) => a.totalProtein).reduce((a, b) => a + b) / 4;

    double avgLast3Carb = last3.map((a) => a.totalCarbs).reduce((a, b) => a + b) / 3;
    double avgPrev4Carb = prev4.map((a) => a.totalCarbs).reduce((a, b) => a + b) / 4;

    double avgLast3Fat = last3.map((a) => a.totalFats).reduce((a, b) => a + b) / 3;
    double avgPrev4Fat = prev4.map((a) => a.totalFats).reduce((a, b) => a + b) / 4;

    return [
      _evalTrend('Calories', avgLast3Cal, avgPrev4Cal, goalCals),
      _evalTrend('Protein', avgLast3Pro, avgPrev4Pro, goalPro),
      _evalTrend('Carbohydrates', avgLast3Carb, avgPrev4Carb, goalCarbs),
      _evalTrend('Fats', avgLast3Fat, avgPrev4Fat, goalFats),
    ];
  }

  static MetricTrend _evalTrend(String name, double last, double prev, double goal) {
    if (prev == 0) {
      return MetricTrend(metricName: name, direction: TrendDirection.stable, changePercentage: 0.0);
    }

    final double changePercent = ((last - prev) / prev) * 100.0;

    // Stable within 5% variation
    if (changePercent.abs() < 5.0) {
      return MetricTrend(metricName: name, direction: TrendDirection.stable, changePercentage: changePercent.abs());
    }

    final double prevDist = (prev - goal).abs();
    final double lastDist = (last - goal).abs();

    // Improving if last average is closer to goal target than previous
    final direction = lastDist < prevDist ? TrendDirection.improving : TrendDirection.declining;

    return MetricTrend(
      metricName: name,
      direction: direction,
      changePercentage: changePercent.abs(),
    );
  }

  static List<IntelligenceInsight> _generateInsights({
    required double avgCals,
    required double avgPro,
    required double avgCarbs,
    required double avgFats,
    required double goalCals,
    required double goalPro,
    required double goalCarbs,
    required double goalFats,
    required double consistencyScore,
    required int activeLoggedDays,
    required NutritionGoalsEntity? goals,
  }) {
    final List<IntelligenceInsight> list = [];

    if (goals == null) {
      list.add(const IntelligenceInsight(
        title: 'Configure Daily Targets',
        description: 'Set your nutrition goals in profile parameters to receive metrics insights.',
        action: 'Tap edit goals card to configure.',
        isPositive: false,
      ));
      return list;
    }

    if (activeLoggedDays < 2) {
      list.add(const IntelligenceInsight(
        title: 'Insufficient Data',
        description: 'Log food intake for at least 2 days to unlock history consistency reports.',
        action: 'Log meals today and tomorrow to view results.',
        isPositive: false,
      ));
      return list;
    }

    // Calorie Insights
    if (avgCals < goalCals * 0.9) {
      list.add(const IntelligenceInsight(
        title: 'Consistently below calorie target',
        description: 'Your average calorie intake is significantly lower than your goal.',
        action: 'Consider adding calorie-dense foods like whole oats or salmon.',
        isPositive: false,
      ));
    } else if (avgCals > goalCals * 1.1) {
      list.add(const IntelligenceInsight(
        title: 'Consistently above calorie target',
        description: 'Your daily average calorie consumption is exceeding your daily limits.',
        action: 'Review portion sizes in your recent meals.',
        isPositive: false,
      ));
    }

    // Protein Insights
    if (avgPro < goalPro * 0.9) {
      list.add(const IntelligenceInsight(
        title: 'Protein frequently below target',
        description: 'Average protein intake falls short of target on most logged days.',
        action: 'Consider adding a protein-rich food (Greek yogurt, chicken, or eggs) to your next meal.',
        isPositive: false,
      ));
    } else if (avgPro >= goalPro * 0.95) {
      list.add(const IntelligenceInsight(
        title: 'Protein target frequently achieved',
        description: 'Excellent protein consistency! You are regularly hitting targets.',
        action: 'Maintain your current high-protein meal selections.',
        isPositive: true,
      ));
    }

    // Carbohydrate & Fat Insights
    if (avgCarbs >= goalCarbs * 0.9 && avgCarbs <= goalCarbs * 1.1) {
      list.add(const IntelligenceInsight(
        title: 'Carbohydrate target frequently achieved',
        description: 'Your carbohydrate intake matches target constraints closely.',
        action: 'Continue balancing your daily carb choices.',
        isPositive: true,
      ));
    }
    if (avgFats > goalFats * 1.05) {
      list.add(const IntelligenceInsight(
        title: 'Fat frequently above target',
        description: 'Fat averages are trending higher than targets.',
        action: 'Try opting for leaner cooking options or portion sizes.',
        isPositive: false,
      ));
    }

    // Consistency Insights
    if (consistencyScore >= 80.0) {
      list.add(const IntelligenceInsight(
        title: 'Strong nutrition consistency',
        description: 'Fantastic work logging your foods regularly this week!',
        action: 'Keep log inputs up to protect your habits.',
        isPositive: true,
      ));
    } else if (consistencyScore < 50.0) {
      list.add(const IntelligenceInsight(
        title: 'Missing nutrition logs',
        description: 'You are missing logging metrics for several days.',
        action: 'Set reminders to record breakfasts and dinners daily.',
        isPositive: false,
      ));
    }

    return list;
  }
}
