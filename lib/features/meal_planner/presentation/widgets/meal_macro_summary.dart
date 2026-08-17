import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_calculator.dart';
import 'package:fitfuel/core/widgets/fitfuel_progress_ring.dart';

class MealMacroSummary extends StatelessWidget {
  final MealPlanEntity plan;
  final NutritionProgressData progress;

  const MealMacroSummary({
    super.key,
    required this.plan,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final remainingCalories = (plan.targetCalories - progress.totalCalories).clamp(0.0, double.infinity);
    final remainingProtein = (plan.targetProtein - progress.totalProtein).clamp(0.0, double.infinity);
    final remainingCarbs = (plan.targetCarbs - progress.totalCarbs).clamp(0.0, double.infinity);
    final remainingFat = (plan.targetFat - progress.totalFats).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn('Target', plan.targetCalories.toStringAsFixed(0), 'kcal', isDark),
              SizedBox(
                height: 100,
                width: 100,
                child: FitFuelProgressRing(
                  value: progress.calorieProgress,
                  size: 100,
                  strokeWidth: 8,
                  progressColor: AppColors.primary500,
                  backgroundColor: AppColors.primary500.withAlpha(20),
                  centerTitle: remainingCalories.toStringAsFixed(0),
                  centerSubtitle: 'Left',
                ),
              ),
              _buildMetricColumn('Consumed', progress.totalCalories.toStringAsFixed(0), 'kcal', isDark),
            ],
          ),
          const SizedBox(height: AppConstants.spaceLg),
          const Divider(),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroProgress('Protein', progress.totalProtein, plan.targetProtein, remainingProtein, AppColors.protein, isDark),
              _buildMacroProgress('Carbs', progress.totalCarbs, plan.targetCarbs, remainingCarbs, AppColors.carbs, isDark),
              _buildMacroProgress('Fat', progress.totalFats, plan.targetFat, remainingFat, AppColors.fat, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, String unit, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.caption(isDark: isDark),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.heading3(isDark: isDark),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: AppTypography.caption(isDark: isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroProgress(String label, double consumed, double target, double remaining, Color color, bool isDark) {
    double percent = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0;
    
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: color.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${remaining.toStringAsFixed(0)}g left',
          style: AppTypography.caption(isDark: isDark).copyWith(color: color),
        ),
      ],
    );
  }
}
