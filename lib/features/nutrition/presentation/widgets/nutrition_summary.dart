import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/nutrition_calculator.dart';
import '../providers/nutrition_providers.dart';
import 'nutrition_summary_card.dart';

/// Shared read-only summary; updated for Option B to render NutritionSummaryCard.
class NutritionSummary extends ConsumerWidget {
  const NutritionSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(nutritionStreamProvider);
    final goals = ref.watch(nutritionGoalsStreamProvider);

    return records.when(
      loading: () => const FitFuelCard(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => FitFuelErrorState(
        error: error,
        onRetry: () => ref.invalidate(nutritionStreamProvider),
      ),
      data: (items) {
        final today = NutritionCalculator.filterByDay(items, DateTime.now());
        final totals = NutritionCalculator.calculateProgress(
          dailyRecords: today,
          goals: goals.value,
        );

        final target = (goals.value?.dailyCalorieTarget ?? 2282).toDouble();
        final pTarget = (goals.value?.proteinTargetGrams ?? 112).toDouble();
        final cTarget = (goals.value?.carbsTargetGrams ?? 316).toDouble();
        final fTarget = (goals.value?.fatTargetGrams ?? 63).toDouble();

        return NutritionSummaryCard(
          totalCalories: totals.totalCalories,
          calorieTarget: target,
          totalProtein: totals.totalProtein,
          proteinTarget: pTarget,
          totalCarbs: totals.totalCarbs,
          carbsTarget: cTarget,
          totalFat: totals.totalFats,
          fatTarget: fTarget,
          onViewDetails: () => context.push('/settings/goals'),
        );
      },
    );
  }
}
