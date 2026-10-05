import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
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
/// Reference-accurate implementation for Phase 35.6.2:
/// Large white card (24px radius, 1px #DDE7DF border, soft shadow),
/// Left: Large calorie ring (#DDEFE3 track, #0F7D38 progress, flame icon,
///       1,679 kcal left, of 2,282 kcal)
/// Right: Stacked metric cards (Consumed with orange flame, Target with green flag, right chevrons)
/// Bottom: 3 equal macro cards (Protein green, Carbs amber, Fat orange)
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
          actionLabel: 'View diary >',
          onActionPressed: () => context.go('/nutrition'),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        if (records.isLoading || goals.isLoading)
          const FitFuelCard(
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
              dailyRecords: NutritionCalculator.filterByDay(
                  records.value ?? [], DateTime.now()),
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
    final isDark = theme.brightness == Brightness.dark;

    final target = goals?.dailyCalorieTarget;
    final hasTarget = target != null && target > 0;
    final consumed = totals.totalCalories;
    final remaining = hasTarget ? target - consumed : null;

    final String centerTitle = _format(remaining ?? consumed);
    final String premiumLabel;
    if (remaining == null) {
      premiumLabel = 'kcal logged';
    } else if (remaining < 0) {
      premiumLabel = 'kcal over';
    } else {
      premiumLabel = 'kcal left';
    }

    final ringValue = hasTarget ? consumed / target : 0.0;
    final overTarget = remaining != null && remaining < 0;
    final ringColor = overTarget
        ? scheme.error
        : (isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen);

    final ring = FitFuelProgressRing(
      value: ringValue,
      size: 138,
      strokeWidth: 11,
      centerTitle: centerTitle,
      centerSubtitle: premiumLabel,
      detailSubtitle: hasTarget ? 'of ${_format(target)} kcal' : null,
      topIcon: const Icon(
        Icons.local_fire_department_rounded,
        size: 18,
        color: AppColors.calories,
      ),
      progressColor: ringColor,
      backgroundColor: isDark
          ? const Color(0xFF1E3A2B)
          : AppColors.paleGreenTrack,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isRow = constraints.maxWidth >= 290;
            if (isRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ring,
                  const SizedBox(width: AppConstants.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatTile(
                          label: 'Consumed',
                          value: _format(consumed),
                          unit: 'kcal',
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.fatOrange,
                          onTap: () => context.go('/nutrition'),
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        _StatTile(
                          label: 'Target',
                          value: hasTarget ? _format(target.toDouble()) : 'Not set',
                          unit: hasTarget ? 'kcal' : null,
                          icon: Icons.flag_rounded,
                          color: AppColors.primaryLeafGreen,
                          onTap: () => context.push('/settings/goals'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Center(child: ring),
                const SizedBox(height: AppConstants.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Consumed',
                        value: _format(consumed),
                        unit: 'kcal',
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.fatOrange,
                        onTap: () => context.go('/nutrition'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: _StatTile(
                        label: 'Target',
                        value: hasTarget ? _format(target.toDouble()) : 'Not set',
                        unit: hasTarget ? 'kcal' : null,
                        icon: Icons.flag_rounded,
                        color: AppColors.primaryLeafGreen,
                        onTap: () => context.push('/settings/goals'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: AppConstants.spaceMd),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE5ECE7),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          // Semantic Macros Row: Protein, Carbs, Fat
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
                  color: AppColors.proteinGreen, // #35C88A
                  icon: Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: _MacroTile(
                  label: 'Carbs',
                  valueLabel:
                      _macroValue(totals.totalCarbs, goals?.carbsTargetGrams),
                  progress: _macroProgress(
                      totals.totalCarbs, goals?.carbsTargetGrams),
                  color: AppColors.carbsAmber, // #F2B84B
                  icon: Icons.grain_rounded,
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: _MacroTile(
                  label: 'Fat',
                  valueLabel:
                      _macroValue(totals.totalFats, goals?.fatTargetGrams),
                  progress:
                      _macroProgress(totals.totalFats, goals?.fatTargetGrams),
                  color: AppColors.fatOrange, // #F5A623
                  icon: Icons.opacity_rounded,
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
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : const Color(0xFFFAFBF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 17, color: color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      unit != null ? '$value $unit' : value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white38 : AppColors.disabledMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double progress;
  final Color color;
  final IconData icon;

  const _MacroTile({
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFFAFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: color,
              backgroundColor: isDark
                  ? Colors.white10
                  : const Color(0xFFE5ECE7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valueLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
