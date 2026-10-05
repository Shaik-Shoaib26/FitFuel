import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/progress_summary_entity.dart';
import '../../domain/entities/weight_record_entity.dart';

/// Weight Progress Card matching Option A:
/// - Header: "Weight Progress" + "View all >"
/// - Stat pill at top-right: "56.0 kg" and "-2.5 kg ↓"
/// - Line chart with emerald green curve, soft gradient area, and date axis
/// - Graceful empty state when insufficient data (< 2 entries)
class WeightProgressCard extends StatelessWidget {
  final ProgressSummaryEntity summary;
  final List<WeightRecordEntity> weightHistory;
  final int selectedDays;

  const WeightProgressCard({
    super.key,
    required this.summary,
    required this.weightHistory,
    required this.selectedDays,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter and sort history for the selected range or recent entries
    final cutoff = DateTime.now().subtract(Duration(days: selectedDays + 1));
    var sorted = List<WeightRecordEntity>.from(weightHistory)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    var rangeRecords = sorted.where((r) => r.recordedAt.isAfter(cutoff)).toList();
    // If range has fewer than 2 records but total history has at least 2, show the most recent records
    final displayRecords = rangeRecords.length >= 2
        ? rangeRecords
        : (sorted.length >= 2 ? sorted.sublist((sorted.length - 7).clamp(0, sorted.length)) : rangeRecords);

    final bool hasEnoughData = displayRecords.length >= 2;

    // Calculate weight change from display records
    final double currentWeight = displayRecords.isNotEmpty
        ? displayRecords.last.weight
        : summary.currentWeight;
    final double startWeight = displayRecords.isNotEmpty
        ? displayRecords.first.weight
        : summary.startingWeight;
    final double delta = hasEnoughData ? (currentWeight - startWeight) : summary.weightChange;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Expanded(
              child: Text(
                'Weight Progress',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryText,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
                onTap: () => context.push('/health/weight'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLeafGreen,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasEnoughData)
            _buildEmptyState(context, isDark)
          else ...[
            // Top Stat Pill Row
            Align(
              alignment: Alignment.centerRight,
              child: _buildStatPill(currentWeight, delta, isDark),
            ),
            const SizedBox(height: 14),

            // Minimal Line Chart
            SizedBox(
              height: 160,
              child: _buildLineChart(displayRecords, isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(double weight, double delta, bool isDark) {
    final isNegative = delta < 0;
    final isPositive = delta > 0;
    final signStr = isPositive ? '+' : '';
    final arrowStr = isNegative ? '↓' : (isPositive ? '↑' : '');
    final deltaText = '$signStr${delta.toStringAsFixed(1)} kg $arrowStr'.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryLeafGreen.withValues(alpha: 0.12)
            : const Color(0xFFEAF8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${weight.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryText,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            deltaText,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F7D38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<WeightRecordEntity> records, bool isDark) {
    final spots = <FlSpot>[];
    double minY = records.first.weight;
    double maxY = records.first.weight;

    for (int i = 0; i < records.length; i++) {
      final w = records[i].weight;
      if (w < minY) minY = w;
      if (w > maxY) maxY = w;
      spots.add(FlSpot(i.toDouble(), w));
    }

    final double yRange = maxY - minY;
    final double yPadding = yRange > 0 ? (yRange * 0.25).clamp(1.0, 5.0) : 2.0;
    minY = (minY - yPadding).floorToDouble();
    maxY = (maxY + yPadding).ceilToDouble();

    final dateFormat = DateFormat('MMM d');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (records.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 3).clamp(1.0, 10.0),
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ((maxY - minY) / 3).clamp(1.0, 10.0),
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (records.length / 5).clamp(1.0, 10.0).floorToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= records.length) {
                  return const SizedBox.shrink();
                }
                final date = records[index].recordedAt;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dateFormat.format(date),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    ),
                  ),
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
            curveSmoothness: 0.3,
            color: const Color(0xFF22C55E),
            barWidth: 2.8,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isLast = index == records.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 4.5 : 3.5,
                  color: const Color(0xFF22C55E),
                  strokeWidth: isLast ? 2.5 : 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.18),
                  const Color(0xFF22C55E).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index >= 0 && index < records.length
                    ? dateFormat.format(records[index].recordedAt)
                    : '';
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg\n$date',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryLeafGreen.withValues(alpha: 0.15) : AppColors.softSage,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monitor_weight_outlined,
              size: 28,
              color: AppColors.primaryLeafGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Not enough weight data yet',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log at least 2 weight entries to visualize your progress curve over time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => context.push('/health/weight'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Log Weight'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLeafGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
