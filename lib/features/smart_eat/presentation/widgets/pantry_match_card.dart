import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';

/// Premium Pantry Match / Synergy Card
class PantryMatchCard extends StatelessWidget {
  final SmartFoodRecommendationEntity recommendation;
  final List<PantryItemEntity> pantryItems;
  final VoidCallback onCookThis;

  const PantryMatchCard({
    super.key,
    required this.recommendation,
    required this.pantryItems,
    required this.onCookThis,
  });

  @override
  Widget build(BuildContext context) {
    // Find matching ingredients
    final matchedIngredients = <String>[];
    final foodNameLower = recommendation.foodName.toLowerCase();

    for (final item in pantryItems) {
      final pName = item.foodName.toLowerCase().trim();
      if (pName.isNotEmpty &&
          (foodNameLower.contains(pName) || pName.contains(foodNameLower))) {
        matchedIngredients.add(item.foodName);
      }
    }

    if (matchedIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: const BorderSide(
        color: AppColors.primary500,
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.kitchen_rounded,
                color: AppColors.primary500,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'Use What You Already Have',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            'Uses ${matchedIngredients.length} ingredients from your kitchen pantry:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matchedIngredients.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.primary500,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ing,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          FitFuelButton(
            label: 'Cook This Meal',
            icon: Icons.cookie_outlined,
            onPressed: onCookThis,
          ),
        ],
      ),
    );
  }
}
