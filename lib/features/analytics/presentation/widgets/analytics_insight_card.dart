import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/utils/analytics_insight_engine.dart';

/// Premium Insight Card inside Analytics Screen
class AnalyticsInsightCard extends StatelessWidget {
  final AnalyticsInsight insight;

  const AnalyticsInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon = Icons.lightbulb_outline;
    Color color = AppColors.ai;

    switch (insight.type) {
      case 'hydration':
        icon = Icons.water_drop_rounded;
        color = AppColors.hydration;
        break;
      case 'nutrition':
        icon = Icons.restaurant_rounded;
        color = AppColors.protein;
        break;
      case 'exercise':
        icon = Icons.fitness_center_rounded;
        color = AppColors.calories;
        break;
      case 'wellness':
        icon = Icons.favorite_rounded;
        color = AppColors.fat;
        break;
      case 'weight':
        icon = Icons.monitor_weight_outlined;
        color = AppColors.primary500;
        break;
      case 'correlation':
        icon = Icons.auto_awesome_rounded;
        color = AppColors.ai;
        break;
    }

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
