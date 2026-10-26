import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';

class NutritionEstimateCard extends StatelessWidget {
  final FoodScanResult result;

  const NutritionEstimateCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      variant: FitFuelCardVariant.hero,
      color: isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceLg),
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Meal Nutrition',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.foods.length} food item${result.foods.length == 1 ? '' : 's'} identified',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLeafGreen,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  '${result.totalCalories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (result.hasIncompleteNutrition) ...[
            const SizedBox(height: AppConstants.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stateWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.stateWarning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.stateWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Partial estimate • Totals incomplete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : AppColors.stateWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spaceMd),

          // Macro Breakdown
          Row(
            children: [
              Expanded(
                child: _macroTile('Protein', '${result.totalProtein.toStringAsFixed(1)}g', AppColors.protein, isDark),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: _macroTile('Carbs', '${result.totalCarbs.toStringAsFixed(1)}g', AppColors.carbs, isDark),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: _macroTile('Fat', '${result.totalFats.toStringAsFixed(1)}g', AppColors.fat, isDark),
              ),
            ],
          ),

          // Secondary Nutrition ("More nutrition": Fiber, Sugar, Sodium)
          if (result.hasMoreNutrition) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Text(
              'More nutrition',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (result.totalFiber != null)
                  Expanded(
                    child: _secondaryTile(
                      'Fiber',
                      '${result.totalFiber!.toStringAsFixed(1)}g',
                      isDark,
                    ),
                  ),
                if (result.totalFiber != null &&
                    (result.totalSugar != null || result.totalSodium != null))
                  const SizedBox(width: AppConstants.spaceSm),
                if (result.totalSugar != null)
                  Expanded(
                    child: _secondaryTile(
                      'Sugar',
                      '${result.totalSugar!.toStringAsFixed(1)}g',
                      isDark,
                    ),
                  ),
                if (result.totalSugar != null && result.totalSodium != null)
                  const SizedBox(width: AppConstants.spaceSm),
                if (result.totalSodium != null)
                  Expanded(
                    child: _secondaryTile(
                      'Sodium',
                      '${result.totalSodium!.toStringAsFixed(0)}mg',
                      isDark,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppConstants.spaceMd),

          // Estimation notice
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white60,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryLeafGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.hasIncompleteNutrition
                        ? 'One or more items have incomplete nutrition. Totals reflect confirmed items only. Choose the correct food from FitFuel to complete.'
                        : (!result.hasAiEstimatedFoods && !result.hasUnmatchedFoods
                            ? "Nutrition is based on FitFuel's food database and your selected serving. Actual preparation may vary."
                            : 'Estimated from photo. Preparation methods, oils, and sauces may alter actual values.'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroTile(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryTile(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : Colors.white70,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
