import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';

/// Premium Metric Card for Analytics Screen
class AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String trend; // 'Improving', 'Stable', 'Declining', 'Insufficient'
  final List<Widget> details;
  final IconData icon;
  final Color color;

  const AnalyticsMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.trend,
    required this.details,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _buildTrendBadge(context),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Divider(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ...details,
        ],
      ),
    );
  }

  Widget _buildTrendBadge(BuildContext context) {
    Color badgeColor = Colors.grey;
    IconData trendIcon = Icons.remove;
    String text = trend;

    switch (trend) {
      case 'Improving':
        badgeColor = AppColors.stateSuccess;
        trendIcon = Icons.trending_up;
        break;
      case 'Declining':
        badgeColor = AppColors.stateError;
        trendIcon = Icons.trending_down;
        break;
      case 'Stable':
        badgeColor = AppColors.primary500;
        trendIcon = Icons.trending_flat;
        break;
      case 'Insufficient':
      default:
        badgeColor = Colors.grey;
        trendIcon = Icons.info_outline;
        text = 'No Data';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
