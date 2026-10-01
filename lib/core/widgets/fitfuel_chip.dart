import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Labeled status and selection; color never carries meaning on its own.
class FitFuelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected, isStatus;
  final ValueChanged<bool>? onSelected;
  const FitFuelChip(
      {super.key,
      required this.label,
      this.icon,
      this.color,
      this.isSelected = false,
      this.onSelected,
      this.isStatus = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (onSelected != null) {
      return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: onSelected,
          selectedColor: scheme.primaryContainer,
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface),
          avatar: icon == null ? null : Icon(icon, size: 18),
          materialTapTargetSize: MaterialTapTargetSize.padded);
    }
    final accent = color ?? scheme.primary;
    return DecoratedBox(
        decoration: BoxDecoration(
            color: accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            border: Border.all(color: scheme.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null || isStatus) ...[
                Icon(icon ?? Icons.info_outline, size: 16, color: accent),
                const SizedBox(width: 4)
              ],
              Flexible(
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onSurface))),
            ])));
  }
}
