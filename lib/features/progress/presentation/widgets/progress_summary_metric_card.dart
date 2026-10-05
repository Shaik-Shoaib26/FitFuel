import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/progress_summary_entity.dart';

/// Top 3 Summary Metrics row matching Option A:
/// 1. Nutrition Streak (orange flame, X days)
/// 2. Water Avg per day (blue drop, X.X L)
/// 3. Activity Avg per day (orange runner, X min)
class ProgressSummaryMetricsRow extends StatelessWidget {
  final ProgressSummaryEntity summary;

  const ProgressSummaryMetricsRow({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final waterLiters = (summary.avgWater / 1000.0).toStringAsFixed(1);
    final activityMins = summary.exerciseAvgDuration.round();

    return LayoutBuilder(
      builder: (context, constraints) {
        // If width is extremely narrow (< 320px), stack into a column or 2-row
        if (constraints.maxWidth < 320) {
          return Column(
            children: [
              _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFF2F9F4),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFE2F0E6),
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                iconBgColor: const Color(0xFFFFEDD5),
                title: 'Nutrition Streak',
                value: '${summary.currentStreak} days',
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFF0F7FF),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFDEECFB),
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBgColor: const Color(0xFFDBEAFE),
                title: 'Water Avg per day',
                value: '$waterLiters L',
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFFFF6F0),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFFDE8DB),
                icon: Icons.directions_run_rounded,
                iconColor: const Color(0xFFF97316),
                iconBgColor: const Color(0xFFFFEDD5),
                title: 'Activity Avg per day',
                value: '$activityMins min',
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFF2F9F4),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFE2F0E6),
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                iconBgColor: const Color(0xFFFFEDD5),
                title: 'Nutrition Streak',
                value: '${summary.currentStreak} days',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFF0F7FF),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFDEECFB),
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBgColor: const Color(0xFFDBEAFE),
                title: 'Water Avg per day',
                value: '$waterLiters L',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                bgColor: isDark ? AppColors.darkBgSurface : const Color(0xFFFFF6F0),
                borderColor: isDark ? AppColors.darkBorder : const Color(0xFFFDE8DB),
                icon: Icons.directions_run_rounded,
                iconColor: const Color(0xFFF97316),
                iconBgColor: const Color(0xFFFB923C).withValues(alpha: 0.2),
                title: 'Activity Avg per day',
                value: '$activityMins min',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.primaryText,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
