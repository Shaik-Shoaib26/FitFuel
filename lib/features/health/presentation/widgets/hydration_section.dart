import 'package:flutter/material.dart';
import 'hydration_editorial_card.dart';

/// Hydration is the page's hero metric: one ring, one plain-language remaining
/// amount, and immediate quick-add actions.
/// Redesigned for Phase 35.6.3 Editorial Wellness, delegating to [HydrationEditorialCard].
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

  @override
  Widget build(BuildContext context) {
    return HydrationEditorialCard(
      intakeMl: intakeMl,
      targetMl: targetMl,
      onAdd250: onAdd250,
      onAdd500: onAdd500,
      onAddCustom: onAddCustom,
    );
  }
}
