import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';

/// Compact previews only; the complete Health workspace lives on /health.
class HomeHealthSummary extends ConsumerWidget {
  const HomeHealthSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthStreamProvider);
    final nutrition = ref.watch(nutritionStreamProvider);
    final today = ref.watch(todayHealthRecordProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FitFuelSectionHeader(title: "Today's Health"),
        const SizedBox(height: AppConstants.spaceSmd),
        if (health.isLoading)
          const FitFuelCard(
            child: FitFuelLoadingState(
                label: 'Loading your health summary', indicatorSize: 20),
          )
        else if (health.hasError)
          FitFuelErrorState(
            error: health.error!,
            onRetry: () => ref.invalidate(healthStreamProvider),
          )
        else
          _HealthCard(
            waterIntakeMl: today?.waterIntakeMl ?? 0,
            waterTargetMl: (today == null || today.waterTargetMl <= 0)
                ? AppConstants.defaultWaterGoalMl.toDouble()
                : today.waterTargetMl,
            minutes: today?.exercises
                    .fold<int>(0, (sum, e) => sum + e.duration) ??
                0,
            habitsDone: today?.habits.values.where((v) => v).length ?? 0,
            habitsTotal: today?.habits.length ?? 0,
            wellness: WellnessCalculator.calculateScore(
              hasLoggedFoodToday: NutritionCalculator.filterByDay(
                      nutrition.value ?? [], DateTime.now())
                  .isNotEmpty,
              healthRecord: today,
            ),
          ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  final double waterIntakeMl;
  final double waterTargetMl;
  final int minutes;
  final int habitsDone;
  final int habitsTotal;
  final double wellness;
  const _HealthCard({
    required this.waterIntakeMl,
    required this.waterTargetMl,
    required this.minutes,
    required this.habitsDone,
    required this.habitsTotal,
    required this.wellness,
  });

  String get _water =>
      '${(waterIntakeMl / 1000).toStringAsFixed(1)} / ${(waterTargetMl / 1000).toStringAsFixed(1)} L';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = FitFuelSemanticColors.of(context);
    final waterProgress = waterTargetMl > 0
        ? (waterIntakeMl / waterTargetMl).clamp(0.0, 1.0)
        : 0.0;
    final habitsProgress =
        habitsTotal > 0 ? habitsDone / habitsTotal : 0.0;
    final metrics = <_HealthMetric>[
      _HealthMetric(
          icon: Icons.water_drop_outlined,
          color: semantic.hydration,
          label: 'Water',
          value: _water,
          progress: waterProgress),
      _HealthMetric(
          icon: Icons.directions_run_outlined,
          color: AppColors.exercise,
          label: 'Exercise',
          value: '$minutes min'),
      _HealthMetric(
          icon: Icons.check_circle_outline,
          color: AppColors.habits,
          label: 'Habits',
          value: habitsTotal == 0 ? '—' : '$habitsDone / $habitsTotal',
          progress: habitsProgress),
      _HealthMetric(
          icon: Icons.favorite_outline,
          color: theme.colorScheme.primary,
          label: 'Wellness',
          value: wellness.round().toString(),
          progress: (wellness / 100).clamp(0.0, 1.0)),
    ];
    return FitFuelCard(
      onTap: () => context.go('/health'),
      semanticsLabel: "Today's health summary",
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            const spacing = AppConstants.spaceSmd;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final metric in metrics)
                  SizedBox(width: tileWidth, child: metric),
              ],
            );
          }),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Flexible(
                child: Text(
                  'View health details',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final double? progress;
  const _HealthMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSmd),
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
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        color.withValues(alpha: .14), scheme.surface),
                    shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: AppConstants.space2Xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppConstants.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: color,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}
