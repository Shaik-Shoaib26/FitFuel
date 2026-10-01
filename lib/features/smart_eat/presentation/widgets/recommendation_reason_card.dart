import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';

/// Premium Match Score Breakdown Card
class RecommendationReasonCard extends StatelessWidget {
  final SmartFoodRecommendationEntity recommendation;

  const RecommendationReasonCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Match Score Breakdown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${recommendation.matchScore}% Match',
                style: const TextStyle(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Divider(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ...recommendation.reasons.map((reason) {
            final contribution = reason.scoreContribution;
            final isPositive = contribution >= 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spaceSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPositive
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: isPositive ? AppColors.stateSuccess : AppColors.stateError,
                    size: 16,
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          reason.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Text(
                    '${isPositive ? '+' : ''}$contribution',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPositive ? AppColors.stateSuccess : AppColors.stateError,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
