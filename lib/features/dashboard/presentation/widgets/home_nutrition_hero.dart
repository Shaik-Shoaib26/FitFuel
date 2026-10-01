import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';

/// The Home hero. Read-only summary built from the canonical nutrition stream
/// and goals; no calculation is duplicated or altered here.
///
/// Visual design: a dominant tonal surface (soft emerald wash → surface)
/// carrying a large calorie ring, consumed/target tiles and macro progress.
class HomeNutritionHero extends ConsumerWidget {
  const HomeNutritionHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(nutritionStreamProvider);
    final goals = ref.watch(nutritionGoalsStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelSectionHeader(
          title: "Today's Nutrition",
          actionLabel: 'Diary',
          onActionPressed: () => context.go('/nutrition'),
        ),
        const SizedBox(height: AppConstants.spaceSmd),
        if (records.isLoading || goals.isLoading)
          const _HeroSurface(
            child: FitFuelLoadingState(
                label: "Loading today's nutrition", indicatorSize: 20),
          )
        else if (records.hasError)
          FitFuelErrorState(
            error: records.error!,
            onRetry: () => ref.invalidate(nutritionStreamProvider),
          )
        else
          _HeroCard(
            totals: NutritionCalculator.calculateProgress(
              dailyRecords:
                  NutritionCalculator.filterByDay(records.value ?? [], DateTime.now()),
              goals: goals.value,
            ),
            goals: goals.value,
            goalsFailed: goals.hasError,
            onRetryGoals: () => ref.invalidate(nutritionGoalsStreamProvider),
            empty: (records.value ?? []).isEmpty,
          ),
      ],
    );
  }
}

/// Shared hero surface: subtle emerald tonal gradient, soft border and one
/// step of elevation so it reads above the tinted page canvas.
class _HeroSurface extends StatelessWidget {
  final Widget child;
  const _HeroSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? scheme.primaryContainer : scheme.primaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: .45), scheme.surface),
            scheme.surface,
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: .25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .30 : .06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  final NutritionProgressData totals;
  final NutritionGoalsEntity? goals;
  final bool goalsFailed;
  final VoidCallback onRetryGoals;
  final bool empty;
  const _HeroCard({
    required this.totals,
    required this.goals,
    required this.goalsFailed,
    required this.onRetryGoals,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = FitFuelSemanticColors.of(context);
    final target = goals?.dailyCalorieTarget;
    final hasTarget = target != null && target > 0;
    final consumed = totals.totalCalories;
    final remaining = hasTarget ? target - consumed : null;

    final String centerTitle;
    final String centerSubtitle;
    if (remaining == null) {
      centerTitle = _format(consumed);
      centerSubtitle = 'kcal logged';
    } else if (remaining < 0) {
      centerTitle = _format(-remaining);
      centerSubtitle = 'kcal over';
    } else {
      centerTitle = _format(remaining);
      centerSubtitle = 'kcal left';
    }
    final ringValue = hasTarget ? consumed / target : 0.0;

    // Overshoot keeps the ring full and shifts to error emphasis.
    final overTarget = remaining != null && remaining < 0;
    final ringColor = overTarget ? scheme.error : scheme.primary;

    final ring = FitFuelProgressRing(
      value: ringValue,
      size: 208,
      strokeWidth: 18,
      centerTitle: centerTitle,
      centerSubtitle: centerSubtitle,
      progressColor: ringColor,
      backgroundColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: .12), scheme.surface),
    );

    final stats = Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Consumed',
            value: _format(consumed),
            unit: 'kcal',
            icon: Icons.local_fire_department_outlined,
            color: semantic.calories,
          ),
        ),
        const SizedBox(width: AppConstants.spaceSmd),
        Expanded(
          child: _StatTile(
            label: 'Target',
            value: hasTarget ? _format(target.toDouble()) : 'Not set',
            unit: hasTarget ? 'kcal' : null,
            icon: Icons.flag_outlined,
            color: scheme.primary,
          ),
        ),
      ],
    );

    return _HeroSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              // Stack the ring above the stat tiles when the column is too
              // narrow for side-by-side metrics to breathe (desktop support
              // columns and scaled text).
              final narrow = constraints.maxWidth < 520 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ring),
                    const SizedBox(height: AppConstants.spaceLg),
                    stats,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ring,
                  const SizedBox(width: AppConstants.space2Xl),
                  Expanded(child: stats),
                ],
              );
            }),
            const SizedBox(height: AppConstants.spaceLg),
            Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: .7)),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MacroTile(
                    label: 'Protein',
                    valueLabel: _macroValue(
                        totals.totalProtein, goals?.proteinTargetGrams),
                    progress: _macroProgress(
                        totals.totalProtein, goals?.proteinTargetGrams),
                    color: semantic.protein,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceSmd),
                Expanded(
                  child: _MacroTile(
                    label: 'Carbs',
                    valueLabel: _macroValue(
                        totals.totalCarbs, goals?.carbsTargetGrams),
                    progress: _macroProgress(
                        totals.totalCarbs, goals?.carbsTargetGrams),
                    color: semantic.carbohydrates,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceSmd),
                Expanded(
                  child: _MacroTile(
                    label: 'Fat',
                    valueLabel:
                        _macroValue(totals.totalFats, goals?.fatTargetGrams),
                    progress:
                        _macroProgress(totals.totalFats, goals?.fatTargetGrams),
                    color: semantic.fat,
                  ),
                ),
              ],
            ),
            if (empty) ...[
              const SizedBox(height: AppConstants.spaceMd),
              Text('Nothing logged yet.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppConstants.spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.go('/nutrition/log'),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Log your first meal'),
                ),
              ),
            ] else if (!hasTarget) ...[
              const SizedBox(height: AppConstants.spaceMd),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/goals'),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Set nutrition targets'),
                ),
              ),
            ],
            if (goalsFailed)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onRetryGoals,
                  child: const Text('Retry nutrition targets'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _format(num value) =>
      NumberFormat('#,##0').format(value.round());

  static double _macroProgress(double amount, double? target) {
    if (target == null || target <= 0) return 0.0;
    final value = amount / target;
    return value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
  }

  static String _macroValue(double amount, double? target) => target == null
      ? '${_format(amount)} g'
      : '${_format(amount)} / ${_format(target)} g';
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSmd),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .08), scheme.surface),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppConstants.space2Xs),
              Flexible(
                child: Text(label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space2Xs),
          Text.rich(
            TextSpan(
              text: value,
              style: theme.textTheme.displaySmall,
              children: [
                if (unit != null)
                  TextSpan(
                    text: '  $unit',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double progress;
  final Color color;
  const _MacroTile({
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSmd),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Flexible(
                child: Text(label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space2Xs),
          // 8% dot inset (10px) so the metric aligns with the label text.
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(valueLabel,
                style: theme.textTheme.displaySmall, maxLines: 1),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}
