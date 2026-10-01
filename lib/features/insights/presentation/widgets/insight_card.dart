import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/health_insight_entity.dart';

/// Premium Insight Card Component
class InsightCard extends StatelessWidget {
  final HealthInsightEntity insight;

  const InsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon = Icons.lightbulb_outline_rounded;
    Color color = AppColors.ai;

    switch (insight.category) {
      case InsightCategory.hydration:
        icon = Icons.water_drop_rounded;
        color = AppColors.hydration;
        break;
      case InsightCategory.nutrition:
        icon = Icons.restaurant_rounded;
        color = AppColors.protein;
        break;
      case InsightCategory.exercise:
        icon = Icons.fitness_center_rounded;
        color = AppColors.calories;
        break;
      case InsightCategory.habits:
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.primary500;
        break;
      case InsightCategory.wellness:
        icon = Icons.favorite_rounded;
        color = AppColors.fat;
        break;
      case InsightCategory.weight:
        icon = Icons.monitor_weight_outlined;
        color = AppColors.achievement;
        break;
      case InsightCategory.positive:
        icon = Icons.check_circle_rounded;
        color = AppColors.stateSuccess;
        break;
      default:
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
                if (insight.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    insight.recommendation,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
