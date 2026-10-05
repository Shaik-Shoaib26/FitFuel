import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';

/// Premium Secondary Recommendation Card for Smart Eat
class RecommendationCard extends StatelessWidget {
  final SmartFoodRecommendationEntity recommendation;
  final VoidCallback onTap;
  final VoidCallback onLog;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onTap,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final foodEntity = FoodEntity(
      id: recommendation.foodId,
      name: recommendation.foodName,
      category: recommendation.category,
      servingSize: recommendation.servingSize,
      servingUnit: 'g',
      calories: recommendation.calories,
      protein: recommendation.protein,
      carbohydrates: recommendation.carbs,
      fats: recommendation.fat,
      fiber: recommendation.fiber,
      sugar: 0,
      sodium: 0,
      imageAsset: recommendation.imageUrl.isNotEmpty ? recommendation.imageUrl : null,
      isFavorite: recommendation.isFavorite,
    );

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: SizedBox(
              width: 76,
              height: 76,
              child: FoodImageCard(
                food: foodEntity,
                width: 76,
                height: 76,
                borderRadius: AppConstants.radiusSm,
                semanticDescription: 'Photo of ${recommendation.foodName}',
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceMd),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.foodName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.softSage,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        '${recommendation.matchScore}%',
                        style: const TextStyle(
                          color: AppColors.primaryLeafGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${recommendation.category} • ${recommendation.servingSize.round()}g • ${recommendation.estimatedPreparationMinutes}m prep',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),

                // Macros tags
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildMacroTag('${recommendation.calories.round()} kcal', AppColors.calories),
                    _buildMacroTag('P: ${recommendation.protein.round()}g', AppColors.protein),
                    _buildMacroTag('C: ${recommendation.carbs.round()}g', AppColors.carbs),
                    _buildMacroTag('F: ${recommendation.fat.round()}g', AppColors.fat),
                  ],
                ),
              ],
            ),
          ),

          // Log Action Button
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary500,
              size: 24,
            ),
            tooltip: 'Log ${recommendation.foodName}',
            visualDensity: VisualDensity.compact,
            onPressed: onLog,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
