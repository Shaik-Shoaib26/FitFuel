import 'package:flutter/material.dart';

/// Drawing is clamped; labels and semantics retain the supplied progress.
class FitFuelLinearProgress extends StatelessWidget {
  final double value, height;
  final String label;
  final String? valueLabel;
  final Color? progressColor, backgroundColor;
  const FitFuelLinearProgress(
      {super.key,
      required this.value,
      required this.label,
      this.valueLabel,
      this.progressColor,
      this.backgroundColor,
      this.height = 8});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary =
        value.isFinite ? '${(value * 100).toStringAsFixed(0)}%' : 'Unavailable';
    return Semantics(
        label: label,
        value: valueLabel ?? summary,
        excludeSemantics: true,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 12, runSpacing: 4, children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(valueLabel ?? summary,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600))
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: value.isFinite ? value.clamp(0, 1) : 0,
                  minHeight: height,
                  borderRadius: BorderRadius.circular(4),
                  color: progressColor ?? colors.primary,
                  backgroundColor: backgroundColor ?? colors.outlineVariant),
            ]));
  }
}
