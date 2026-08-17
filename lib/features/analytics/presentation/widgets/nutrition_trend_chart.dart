import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/analytics_data_point_entity.dart';
import 'package:intl/intl.dart';

class NutritionTrendChart extends StatelessWidget {
  final List<AnalyticsDataPointEntity> dataPoints;

  const NutritionTrendChart({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (dataPoints.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No nutrition data available.')),
      );
    }

    final List<FlSpot> spotsActual = [];
    final List<FlSpot> spotsTarget = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      spotsActual.add(FlSpot(i.toDouble(), dp.calories));
      spotsTarget.add(FlSpot(i.toDouble(), dp.calorieTarget));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, top: 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (dataPoints.length / 5).clamp(1.0, 365.0),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < dataPoints.length) {
                    final date = dataPoints[idx].date;
                    return Text(
                      DateFormat('MM/dd').format(date),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotsActual,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: dataPoints.length <= 10),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withValues(alpha: 0.1),
              ),
            ),
            LineChartBarData(
              spots: spotsTarget,
              isCurved: false,
              color: Colors.orange,
              barWidth: 1.5,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
