import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/nutrition_gap_entity.dart';

/// Premium Remaining Daily Targets Card for Smart Eat
class NutritionGapCard extends StatelessWidget {
  final NutritionGapEntity gap;

  const NutritionGapCard({
    super.key,
    required this.gap,
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
                'Remaining Daily Targets',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.track_changes_rounded,
                color: AppColors.primary500,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Divider(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          _buildGapRow(
            context,
            label: 'Calories',
            remaining: gap.remainingCalories,
            unit: 'kcal',
            hasDeficit: gap.calorieDeficit,
            isExcess: gap.calorieExcess,
            color: AppColors.calories,
            isDark: isDark,
          ),
          _buildGapRow(
            context,
            label: 'Protein',
            remaining: gap.remainingProtein,
            unit: 'g',
            hasDeficit: gap.proteinDeficit,
            isExcess: gap.remainingProtein < 0,
            color: AppColors.protein,
            isDark: isDark,
          ),
          _buildGapRow(
            context,
            label: 'Carbohydrates',
            remaining: gap.remainingCarbs,
            unit: 'g',
            hasDeficit: gap.remainingCarbs > 40,
            isExcess: gap.remainingCarbs < 0,
            color: AppColors.carbs,
            isDark: isDark,
          ),
          _buildGapRow(
            context,
            label: 'Fats',
            remaining: gap.remainingFat,
            unit: 'g',
            hasDeficit: gap.remainingFat > 15,
            isExcess: gap.remainingFat < 0,
            color: AppColors.fat,
            isDark: isDark,
          ),
          _buildGapRow(
            context,
            label: 'Fiber',
            remaining: gap.remainingFiber,
            unit: 'g',
            hasDeficit: gap.fiberDeficit,
            isExcess: gap.remainingFiber < 0,
            color: AppColors.primary500,
            isDark: isDark,
          ),
          _buildGapRow(
            context,
            label: 'Hydration',
            remaining: gap.remainingWater,
            unit: 'ml',
            hasDeficit: gap.hydrationDeficit,
            isExcess: gap.remainingWater < 0,
            color: AppColors.hydration,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildGapRow(
    BuildContext context, {
    required String label,
    required double remaining,
    required String unit,
    required bool hasDeficit,
    required bool isExcess,
    required Color color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    String valueText;
    Color statusColor;

    if (isExcess) {
      valueText = 'Met (${remaining.abs().round()} $unit over)';
      statusColor = AppColors.stateSuccess;
    } else if (hasDeficit) {
      valueText = '${remaining.round()} $unit left';
      statusColor = AppColors.primary500;
    } else {
      valueText = '${remaining.round()} $unit left';
      statusColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    final double progressFraction = isExcess
        ? 1.0
        : (remaining > 0 ? (1.0 - (remaining / 100.0).clamp(0.0, 1.0)) : 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
