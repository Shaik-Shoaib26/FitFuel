import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/analytics_summary_entity.dart';

class GoalAdherenceChart extends StatelessWidget {
  final AnalyticsSummaryEntity summary;

  const GoalAdherenceChart({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double caloriesVal = summary.calorieAdherencePercentage;
    final double proteinVal = summary.proteinAdherencePercentage;
    final double hydrationVal = summary.hydrationAdherencePercentage;
    final double exerciseVal = summary.exerciseConsistencyPercentage;
    final double habitsVal = summary.habitConsistencyPercentage;

    final categories = ['Calories', 'Protein', 'Water', 'Exercise', 'Habits'];
    final values = [caloriesVal, proteinVal, hydrationVal, exerciseVal, habitsVal];
    final colors = [Colors.green, Colors.teal, Colors.blue, Colors.orange, Colors.purple];

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, top: 12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < categories.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        categories[idx],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(categories.length, (idx) {
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: values[idx],
                  color: colors[idx],
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: colors[idx].withValues(alpha: 0.1),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
