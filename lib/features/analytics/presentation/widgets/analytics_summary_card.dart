import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/analytics_summary_entity.dart';

/// Premium Summary Card for Analytics Screen
class AnalyticsSummaryCard extends StatelessWidget {
  final AnalyticsSummaryEntity summary;

  const AnalyticsSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Consistency',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.overallConsistencyPercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMd,
                  vertical: AppConstants.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.calories,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streak',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${summary.currentLoggingStreak} Days',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Divider(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Wrap(
            spacing: AppConstants.spaceSm,
            runSpacing: AppConstants.spaceSm,
            children: [
              _buildStatTile(
                context,
                'Active Days',
                '${summary.activeLoggingDays}',
                Icons.calendar_today_outlined,
                AppColors.primary500,
                isDark,
              ),
              _buildStatTile(
                context,
                'Longest Streak',
                '${summary.longestLoggingStreak}D',
                Icons.star_outline_rounded,
                AppColors.achievement,
                isDark,
              ),
              _buildStatTile(
                context,
                'Weight Shift',
                summary.weightChange != null
                    ? '${summary.weightChange! > 0 ? '+' : ''}${summary.weightChange!.toStringAsFixed(1)} kg'
                    : '—',
                Icons.monitor_weight_outlined,
                AppColors.protein,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
