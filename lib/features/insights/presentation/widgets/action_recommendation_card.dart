import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/feature_action_navigation.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/action_recommendation_entity.dart';
import '../../domain/entities/health_insight_entity.dart';

/// Premium Action Recommendation Card for Insights Screen
class ActionRecommendationCard extends StatelessWidget {
  final ActionRecommendationEntity recommendation;

  const ActionRecommendationCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color = AppColors.primary500;

    switch (recommendation.actionType) {
      case InsightActionType.logWater:
        color = AppColors.hydration;
        break;
      case InsightActionType.findProteinFoods:
        color = AppColors.protein;
        break;
      case InsightActionType.viewMealPlan:
        color = AppColors.primary500;
        break;
      case InsightActionType.openGrocery:
        color = AppColors.calories;
        break;
      case InsightActionType.viewProgress:
        color = AppColors.ai;
        break;
      case InsightActionType.openWeeklyReport:
        color = AppColors.fat;
        break;
      case InsightActionType.openDailyRoutine:
        color = AppColors.primary500;
        break;
      case InsightActionType.openAnalytics:
        color = AppColors.achievement;
        break;
      default:
        break;
    }

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(Icons.bolt_rounded, color: color, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recommendation.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          ElevatedButton(
            onPressed: () {
              context.go(insightLocation(recommendation));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text('Go', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
