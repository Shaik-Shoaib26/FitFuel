import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_linear_progress.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/nutrition_calculator.dart';
import '../providers/nutrition_providers.dart';

/// Shared read-only summary; Home and the diary never own separate totals.
class NutritionSummary extends ConsumerWidget {
  const NutritionSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(nutritionStreamProvider);
    final goals = ref.watch(nutritionGoalsStreamProvider);
    return records.when(
      loading: () => const FitFuelCard(
          child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()))),
      error: (error, _) => FitFuelErrorState(
          error: error, onRetry: () => ref.invalidate(nutritionStreamProvider)),
      data: (items) {
        final today = NutritionCalculator.filterByDay(items, DateTime.now());
        final totals = NutritionCalculator.calculateProgress(
            dailyRecords: today, goals: goals.value);
        final target = goals.value?.dailyCalorieTarget;
        final semantic = FitFuelSemanticColors.of(context);
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;

        // Calorie state
        final consumed = totals.totalCalories;
        final hasTarget = target != null && target > 0;
        final remaining = hasTarget ? target - consumed : 0.0;
        final isOverTarget = hasTarget && consumed > target;
        final progressValue =
            hasTarget ? (consumed / target).clamp(0.0, 1.0) : 0.0;
        final progressColor = isOverTarget
            ? scheme.error
            : consumed == 0
                ? scheme.outlineVariant
                : scheme.primary;

        // Center ring labels
        final centerTitle = hasTarget
            ? (isOverTarget
                ? '+${(consumed - target).toStringAsFixed(0)}'
                : remaining.toStringAsFixed(0))
            : consumed.toStringAsFixed(0);
        final centerSubtitle =
            hasTarget ? (isOverTarget ? 'over' : 'remaining') : 'kcal';

        return FitFuelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Today's Nutrition",
                            style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          hasTarget
                              ? '${consumed.toStringAsFixed(0)} of $target kcal'
                              : '${consumed.toStringAsFixed(0)} kcal logged',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (goals.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceLg),

              // Calorie ring — centered on mobile, left-aligned on desktop
              Center(
                child: FitFuelProgressRing(
                  value: progressValue,
                  size: 160,
                  strokeWidth: 12,
                  progressColor: progressColor,
                  centerTitle: centerTitle,
                  centerSubtitle: centerSubtitle,
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),

              // Macro progress bars
              _MacroBar(
                label: 'Protein',
                current: totals.totalProtein,
                target: goals.value?.proteinTargetGrams,
                progress: totals.proteinProgress,
                color: semantic.protein,
              ),
              const SizedBox(height: AppConstants.spaceSmd),
              _MacroBar(
                label: 'Carbs',
                current: totals.totalCarbs,
                target: goals.value?.carbsTargetGrams,
                progress: totals.carbsProgress,
                color: semantic.carbohydrates,
              ),
              const SizedBox(height: AppConstants.spaceSmd),
              _MacroBar(
                label: 'Fat',
                current: totals.totalFats,
                target: goals.value?.fatTargetGrams,
                progress: totals.fatProgress,
                color: semantic.fat,
              ),

              // Set targets prompt
              if (!goals.isLoading && !goals.hasError && !hasTarget) ...[
                const SizedBox(height: AppConstants.spaceMd),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/settings/goals'),
                    icon: const Icon(Icons.track_changes_rounded, size: 18),
                    label: const Text('Set nutrition targets'),
                  ),
                ),
              ],

              // Retry targets
              if (goals.hasError) ...[
                const SizedBox(height: AppConstants.spaceSm),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(nutritionGoalsStreamProvider),
                    child: const Text('Retry nutrition targets'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double? target;
  final double progress;
  final Color color;
  const _MacroBar({
    required this.label,
    required this.current,
    this.target,
    required this.progress,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final valueLabel = target != null
        ? '${current.toStringAsFixed(0)}g / ${target!.toStringAsFixed(0)}g'
        : '${current.toStringAsFixed(0)}g';
    return FitFuelLinearProgress(
      label: label,
      value: progress,
      valueLabel: valueLabel,
      progressColor: color,
      height: 6,
    );
  }
}
