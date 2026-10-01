import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/feature_action_navigation.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/daily_focus_entity.dart';
import '../../domain/entities/health_insight_entity.dart';

/// Premium Daily Focus Card for Insights Screen
class DailyFocusCard extends StatelessWidget {
  final DailyFocusEntity dailyFocus;

  const DailyFocusCard({
    super.key,
    required this.dailyFocus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon = Icons.star_rounded;
    Color color = AppColors.ai;

    switch (dailyFocus.category) {
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
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: BorderSide(color: color, width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                "TODAY'S FOCUS",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            dailyFocus.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dailyFocus.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          if (dailyFocus.recommendedActions.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Wrap(
              spacing: AppConstants.spaceSm,
              runSpacing: AppConstants.spaceSm,
              children: dailyFocus.recommendedActions.map((action) {
                return FitFuelButton(
                  onPressed: () {
                    context.go(insightLocation(action));
                  },
                  icon: Icons.arrow_forward_rounded,
                  label: action.title,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
