import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';
import '../../domain/entities/meal_plan_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';

/// Premium Meal Macro & Calorie Summary for Meal Planner
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    final remainingCalories =
        (plan.targetCalories - progress.totalCalories).clamp(0.0, double.infinity);
    final remainingProtein =
        (plan.targetProtein - progress.totalProtein).clamp(0.0, double.infinity);
    final remainingCarbs =
        (plan.targetCarbs - progress.totalCarbs).clamp(0.0, double.infinity);
    final remainingFat =
        (plan.targetFat - progress.totalFats).clamp(0.0, double.infinity);

    final isOverPlanned = plan.plannedCalories > plan.targetCalories;
    final diffCalories = (plan.plannedCalories - plan.targetCalories).abs();

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppConstants.spaceSm,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Plan Calorie Balance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceSm,
                  vertical: AppConstants.space2Xs,
                ),
                decoration: BoxDecoration(
                  color: isOverPlanned
                      ? AppColors.stateError.withValues(alpha: 0.12)
                      : AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  '${diffCalories.round()} kcal ${isOverPlanned ? "over target" : "remaining buffer"}',
                  style: TextStyle(
                    color: isOverPlanned ? AppColors.stateError : AppColors.primary500,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceLg),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppConstants.spaceMd,
            runSpacing: AppConstants.spaceMd,
            children: [
              _buildMetricColumn(
                context: context,
                label: 'Daily Target',
                value: plan.targetCalories.round().toString(),
                unit: 'kcal',
                isDark: isDark,
              ),
              FitFuelProgressRing(
                value: progress.calorieProgress,
                size: 136,
                strokeWidth: 10,
                progressColor: isOverPlanned ? AppColors.stateError : AppColors.primary500,
                backgroundColor: isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.primary500.withValues(alpha: 0.12),
                centerTitle: remainingCalories.round().toString(),
                centerSubtitle: 'kcal left',
              ),
              _buildMetricColumn(
                context: context,
                label: 'Consumed',
                value: progress.totalCalories.round().toString(),
                unit: 'kcal',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceLg),
          Divider(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          LayoutBuilder(
            builder: (context, constraints) {
              final isHighScale = media.textScaler.scale(16) > 19.2;
              final isNarrow = constraints.maxWidth < (isHighScale ? 560 : 420);
              if (isNarrow) {
                return Column(
                  children: [
                    _buildMacroProgressTile(
                      context: context,
                      label: 'Protein',
                      consumed: progress.totalProtein,
                      planned: plan.plannedProtein,
                      target: plan.targetProtein,
                      remaining: remainingProtein,
                      color: AppColors.protein,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildMacroProgressTile(
                      context: context,
                      label: 'Carbs',
                      consumed: progress.totalCarbs,
                      planned: plan.plannedCarbs,
                      target: plan.targetCarbs,
                      remaining: remainingCarbs,
                      color: AppColors.carbs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildMacroProgressTile(
                      context: context,
                      label: 'Fat',
                      consumed: progress.totalFats,
                      planned: plan.plannedFat,
                      target: plan.targetFat,
                      remaining: remainingFat,
                      color: AppColors.fat,
                      isDark: isDark,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildMacroProgressTile(
                      context: context,
                      label: 'Protein',
                      consumed: progress.totalProtein,
                      planned: plan.plannedProtein,
                      target: plan.targetProtein,
                      remaining: remainingProtein,
                      color: AppColors.protein,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child: _buildMacroProgressTile(
                      context: context,
                      label: 'Carbs',
                      consumed: progress.totalCarbs,
                      planned: plan.plannedCarbs,
                      target: plan.targetCarbs,
                      remaining: remainingCarbs,
                      color: AppColors.carbs,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child: _buildMacroProgressTile(
                      context: context,
                      label: 'Fat',
                      consumed: progress.totalFats,
                      planned: plan.plannedFat,
                      target: plan.targetFat,
                      remaining: remainingFat,
                      color: AppColors.fat,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroProgressTile({
    required BuildContext context,
    required String label,
    required double consumed,
    required double planned,
    required double target,
    required double remaining,
    required Color color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final double fraction = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceSm,
        vertical: AppConstants.spaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '${planned.round()}g',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${remaining.round()}g left',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
