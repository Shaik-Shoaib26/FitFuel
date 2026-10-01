import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_card.dart';

/// "Today's Health" overview: four scannable metrics in one surface. Tapping a
/// metric focuses the matching section further down the page (the overview owns
/// no state of its own).
class HealthOverviewSection extends StatelessWidget {
  final String waterValue;
  final double waterProgress;
  final int exerciseMinutes;
  final int habitsDone, habitsTotal;
  final double wellnessScore;
  final ValueChanged<String> onSelectSection;

  const HealthOverviewSection({
    super.key,
    required this.waterValue,
    required this.waterProgress,
    required this.exerciseMinutes,
    required this.habitsDone,
    required this.habitsTotal,
    required this.wellnessScore,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = FitFuelSemanticColors.of(context);
    final habitsProgress = habitsTotal > 0 ? habitsDone / habitsTotal : 0.0;
    final wellnessProgress =
        (wellnessScore / 100).isFinite ? (wellnessScore / 100).clamp(0.0, 1.0) : 0.0;

    final metrics = <_OverviewMetric>[
      _OverviewMetric(
        section: 'hydration',
        icon: Icons.water_drop_outlined,
        color: semantic.hydration,
        label: 'Water',
        value: waterValue,
        progress: waterProgress,
      ),
      _OverviewMetric(
        section: 'exercise',
        icon: Icons.directions_run_outlined,
        color: AppColors.exercise,
        label: 'Exercise',
        value: '$exerciseMinutes min',
      ),
      _OverviewMetric(
        section: 'habits',
        icon: Icons.check_circle_outline,
        color: AppColors.habits,
        label: 'Habits',
        value: habitsTotal == 0 ? '—' : '$habitsDone / $habitsTotal',
        progress: habitsProgress,
      ),
      _OverviewMetric(
        section: 'wellness',
        icon: Icons.favorite_outline,
        color: theme.colorScheme.primary,
        label: 'Wellness',
        value: wellnessScore.round().toString(),
        progress: wellnessProgress,
      ),
    ];

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: "Today's health overview",
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        const spacing = AppConstants.spaceSmd;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                child: _OverviewTile(
                  metric: metric,
                  onTap: () => onSelectSection(metric.section),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _OverviewMetric {
  final String section, label, value;
  final IconData icon;
  final Color color;
  final double? progress;
  const _OverviewMetric({
    required this.section,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.progress,
  });
}

class _OverviewTile extends StatelessWidget {
  final _OverviewMetric metric;
  final VoidCallback onTap;
  const _OverviewTile({required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = metric.progress == null
        ? null
        : '${(metric.progress! * 100).round()} percent';
    return Semantics(
      button: true,
      label: '${metric.label}: ${metric.value}',
      value: percent,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(
            metric.color.withValues(alpha: .08), scheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceSmd),
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
                                metric.color.withValues(alpha: .16),
                                scheme.surface),
                            shape: BoxShape.circle),
                        child:
                            Icon(metric.icon, size: 15, color: metric.color),
                      ),
                      const SizedBox(width: AppConstants.space2Xs),
                      Expanded(
                        child: Text(
                          metric.label,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  Text(
                    metric.value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  if (metric.progress != null)
                    // Progress is announced by the tile's own semantics node.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: metric.progress,
                        minHeight: 4,
                        color: metric.color,
                        backgroundColor: scheme.outlineVariant,
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
