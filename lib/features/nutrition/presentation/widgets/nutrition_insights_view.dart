import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/utils/recommendation_engine.dart';

/// Clean editorial view for the "Insights" tab in Option B.
class NutritionInsightsView extends StatelessWidget {
  final List<NutritionRecordEntity> records;
  final NutritionGoalsEntity? goals;
  final VoidCallback onLogFood;

  const NutritionInsightsView({
    super.key,
    required this.records,
    required this.goals,
    required this.onLogFood,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final recommendations = RecommendationEngine.getRecommendations(
      dailyRecords: records,
      goals: goals,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Focus Summary Card
        Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLeafGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.primaryLeafGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nutrition Insight',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recommendations.insightMessage,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Suggestions
        if (recommendations.suggestions.isNotEmpty) ...[
          Text(
            'Recommended Foods',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          for (final suggestion in recommendations.suggestions) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primaryLeafGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.food.name,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.primaryText,
                          ),
                        ),
                        Text(
                          suggestion.reason,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${suggestion.food.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLeafGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
