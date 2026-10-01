import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';

/// Wellness surfaces the score the app already computes plus the four inputs it
/// is built from. Nothing here diagnoses or predicts anything.
class WellnessSection extends StatelessWidget {
  final double score;
  final String hydrationValue, activityValue, habitsValue, nutritionValue;
  final VoidCallback onViewInsights;

  const WellnessSection({
    super.key,
    required this.score,
    required this.hydrationValue,
    required this.activityValue,
    required this.habitsValue,
    required this.nutritionValue,
    required this.onViewInsights,
  });

  double get _progress {
    final value = score / 100;
    return value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = FitFuelSemanticColors.of(context);

    final ring = FitFuelProgressRing(
      value: _progress,
      size: 138,
      strokeWidth: 14,
      centerTitle: score.isFinite ? score.round().toString() : '—',
      centerSubtitle: 'of 100',
      progressColor: scheme.primary,
      backgroundColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: .14), scheme.surface),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Daily Wellness Score',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppConstants.space2Xs),
        Text(
          "Built from today's logged foods, hydration progress, exercise and completed habits.",
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppConstants.spaceSmd),
        _InputRow(
          icon: Icons.restaurant_outlined,
          color: semantic.calories,
          label: 'Food logged',
          value: nutritionValue,
        ),
        _InputRow(
          icon: Icons.water_drop_outlined,
          color: semantic.hydration,
          label: 'Hydration',
          value: hydrationValue,
        ),
        _InputRow(
          icon: Icons.directions_run_outlined,
          color: AppColors.exercise,
          label: 'Activity',
          value: activityValue,
        ),
        _InputRow(
          icon: Icons.check_circle_outline,
          color: AppColors.habits,
          label: 'Habits',
          value: habitsValue,
        ),
        const SizedBox(height: AppConstants.spaceXs),
        FitFuelButton(
          label: 'View health insights',
          type: FitFuelButtonType.ghost,
          icon: Icons.insights_outlined,
          onPressed: onViewInsights,
          semanticsLabel: 'View health insights',
        ),
      ],
    );

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Daily wellness score ${score.round()} out of 100',
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ring),
              const SizedBox(height: AppConstants.spaceLg),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: AppConstants.spaceXl),
            Expanded(child: details),
          ],
        );
      }),
    );
  }
}

class _InputRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _InputRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconBox = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
          color: Color.alphaBlend(
              color.withValues(alpha: .14), scheme.surface),
          shape: BoxShape.circle),
      child: Icon(icon, size: 13, color: color),
    );
    final labelText = Text(
      label,
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: scheme.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final valueText = Text(
      value,
      style:
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.space2Xs),
        child: LayoutBuilder(builder: (context, constraints) {
          // A large text scale or a narrow column cannot fit label and value on
          // one line, so the value moves below the label instead of clipping.
          final stacked = constraints.maxWidth < 200 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  iconBox,
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(child: labelText),
                ]),
                const SizedBox(height: AppConstants.space2Xs),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Align(alignment: Alignment.centerLeft, child: valueText),
                ),
              ],
            );
          }
          return Row(
            children: [
              iconBox,
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(child: labelText),
              const SizedBox(width: AppConstants.spaceSm),
              Flexible(child: valueText),
            ],
          );
        }),
      ),
    );
  }
}
