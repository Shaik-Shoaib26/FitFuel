import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/analytics_data_point_entity.dart';
import 'package:intl/intl.dart';

class ExerciseTrendChart extends StatelessWidget {
  final List<AnalyticsDataPointEntity> dataPoints;

  const ExerciseTrendChart({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (dataPoints.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No exercise data available.')),
      );
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      spots.add(FlSpot(i.toDouble(), dp.workoutMinutes));
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
                    '${value.toInt()}m',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: dataPoints.length <= 10),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
