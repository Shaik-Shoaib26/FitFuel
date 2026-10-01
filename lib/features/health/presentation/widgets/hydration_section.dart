import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_chip.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';

/// Hydration is the page's hero metric: one ring, one plain-language remaining
/// amount, and immediate quick-add actions. Every value shown comes from the
/// existing health record; nothing is recalculated here beyond formatting.
class HydrationSection extends StatelessWidget {
  final double intakeMl, targetMl;
  final VoidCallback onAdd250, onAdd500, onAddCustom;

  const HydrationSection({
    super.key,
    required this.intakeMl,
    required this.targetMl,
    required this.onAdd250,
    required this.onAdd500,
    required this.onAddCustom,
  });

  /// Shared litre formatting so every hydrated value on Health reads alike.
  static String formatLitres(double ml) => (ml / 1000).toStringAsFixed(1);

  double get _progress {
    if (targetMl <= 0) return 0;
    final value = intakeMl / targetMl;
    return value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
  }

  bool get _hasTarget => targetMl > 0;
  bool get _reached => _hasTarget && intakeMl >= targetMl;
  double get _remaining =>
      _hasTarget && intakeMl < targetMl ? targetMl - intakeMl : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = FitFuelSemanticColors.of(context);
    final accent = semantic.hydration;

    final ring = FitFuelProgressRing(
      value: _progress,
      size: 148,
      strokeWidth: 14,
      centerTitle: '${formatLitres(intakeMl)} L',
      centerSubtitle:
          _hasTarget ? 'of ${formatLitres(targetMl)} L' : 'target not set',
      progressColor: accent,
      backgroundColor: Color.alphaBlend(
          accent.withValues(alpha: .14), scheme.surface),
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppConstants.spaceSm,
          runSpacing: AppConstants.space2Xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _hasTarget
                  ? '${formatLitres(_remaining)} L remaining'
                  : 'No daily target set',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (_reached)
              FitFuelChip(
                label: (intakeMl - targetMl) > 0 ? 'Over target' : 'Goal met',
                icon: Icons.check_circle_outline,
                color: semantic.success,
                isStatus: true,
              ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceXs),
        Text(
          _hasTarget
              ? '${formatLitres(intakeMl)} L logged of ${formatLitres(targetMl)} L daily target.'
              : 'Set a daily target to track hydration progress.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        Row(
          children: [
            Expanded(
              child: FitFuelButton(
                label: '+250 ml',
                icon: Icons.water_drop_outlined,
                type: FitFuelButtonType.secondary,
                onPressed: onAdd250,
                semanticsLabel: 'Log 250 millilitres of water',
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: FitFuelButton(
                label: '+500 ml',
                icon: Icons.water_drop_outlined,
                type: FitFuelButtonType.secondary,
                onPressed: onAdd500,
                semanticsLabel: 'Log 500 millilitres of water',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceSm),
        Align(
          alignment: Alignment.centerLeft,
          child: FitFuelButton(
            label: 'Custom amount',
            icon: Icons.edit_outlined,
            type: FitFuelButtonType.ghost,
            onPressed: onAddCustom,
            semanticsLabel: 'Log a custom amount of water',
          ),
        ),
      ],
    );

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Hydration progress',
      child: LayoutBuilder(builder: (context, constraints) {
        // Narrow columns stack so the ring and the actions both stay readable.
        final stacked = constraints.maxWidth < 520;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ring),
              const SizedBox(height: AppConstants.spaceLg),
              summary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: AppConstants.spaceXl),
            Expanded(child: summary),
          ],
        );
      }),
    );
  }
}
