import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';

/// Premium Top Recommendation Hero for Smart Eat
class SmartEatHeroCard extends StatelessWidget {
  final SmartFoodRecommendationEntity recommendation;
  final VoidCallback onLogMeal;
  final VoidCallback onSwap;
  final VoidCallback onAddToMealPlan;
  final VoidCallback onViewRecipe;

  const SmartEatHeroCard({
    super.key,
    required this.recommendation,
    required this.onLogMeal,
    required this.onSwap,
    required this.onAddToMealPlan,
    required this.onViewRecipe,
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

    final primaryReason = recommendation.reasons.isNotEmpty
        ? recommendation.reasons.first.description
        : 'Fits your remaining daily calorie and protein goals.';

    return FitFuelCard(
      padding: EdgeInsets.zero,
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Food Photography
          Stack(
            children: [
              FoodImageCard(
                food: foodEntity,
                aspectRatio: 16 / 9,
                borderRadius: 0,
                semanticDescription: 'Photo of ${recommendation.foodName}',
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppConstants.spaceSm,
                right: AppConstants.spaceSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceSm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Text(
                    '${recommendation.matchScore}% Match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: AppConstants.spaceSm,
                left: AppConstants.spaceMd,
                right: AppConstants.spaceMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.foodName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recommendation.category} • ${recommendation.servingSize.round()}g serving',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Macro Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMacroStat(
                      context,
                      '${recommendation.calories.round()}',
                      'kcal',
                      AppColors.calories,
                      isDark,
                    ),
                    _buildMacroStat(
                      context,
                      '${recommendation.protein.round()}g',
                      'Protein',
                      AppColors.protein,
                      isDark,
                    ),
                    _buildMacroStat(
                      context,
                      '${recommendation.carbs.round()}g',
                      'Carbs',
                      AppColors.carbs,
                      isDark,
                    ),
                    _buildMacroStat(
                      context,
                      '${recommendation.fat.round()}g',
                      'Fat',
                      AppColors.fat,
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Recommendation reason
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgSurface
                        : AppColors.primary500.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorderSubtle
                          : AppColors.primary500.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary500,
                        size: 16,
                      ),
                      const SizedBox(width: AppConstants.spaceSm),
                      Expanded(
                        child: Text(
                          primaryReason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Action buttons
                Wrap(
                  spacing: AppConstants.spaceSm,
                  runSpacing: AppConstants.spaceSm,
                  children: [
                    FitFuelButton(
                      label: 'Log Meal',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: onLogMeal,
                    ),
                    OutlinedButton.icon(
                      onPressed: onSwap,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Swap'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, AppConstants.minTouchTargetSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusControl),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onAddToMealPlan,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: const Text('Add to Plan'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, AppConstants.minTouchTargetSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusControl),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onViewRecipe,
                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                      label: const Text('Recipe'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary500,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(
    BuildContext context,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
