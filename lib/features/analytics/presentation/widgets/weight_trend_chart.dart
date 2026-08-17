import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/analytics_data_point_entity.dart';
import 'package:intl/intl.dart';

class WeightTrendChart extends StatelessWidget {
  final List<AnalyticsDataPointEntity> dataPoints;

  const WeightTrendChart({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<FlSpot> spots = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      if (dp.weight != null) {
        spots.add(FlSpot(i.toDouble(), dp.weight!));
      }
    }

    if (spots.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No weight records logged in this period.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
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
                    '${value.toStringAsFixed(1)}k',
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
              isCurved: spots.length > 1,
              color: Colors.purple,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: spots.length == 1 || dataPoints.length <= 15),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.purple.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
