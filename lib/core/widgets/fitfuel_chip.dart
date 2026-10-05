import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Labeled status and selection; color never carries meaning on its own.
/// Fresh Green Chip Design:
/// Selected: #DCF5E5 background, #0F7D38 foreground
/// Unselected: #F3F6F4 background, #657169 foreground
/// Radius: 14 px
class FitFuelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected, isStatus;
  final ValueChanged<bool>? onSelected;

  const FitFuelChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.isSelected = false,
    this.onSelected,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (onSelected != null) {
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: isDark ? scheme.primaryContainer : const Color(0xFFDCF5E5),
        backgroundColor: isDark ? scheme.surface : const Color(0xFFF3F6F4),
        labelStyle: TextStyle(
          color: isSelected
              ? (isDark ? scheme.onPrimaryContainer : AppColors.primaryLeafGreen)
              : (isDark ? scheme.onSurface : const Color(0xFF657169)),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? scheme.onPrimaryContainer : AppColors.primaryLeafGreen)
                    : (isDark ? scheme.onSurfaceVariant : const Color(0xFF657169)),
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusControl),
          side: BorderSide(
            color: isSelected
                ? (isDark ? scheme.primary : const Color(0xFFBCE3CB))
                : (isDark ? scheme.outlineVariant : const Color(0xFFE5ECE7)),
            width: 1,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );
    }

    final accent = color ?? (isDark ? scheme.primary : AppColors.primaryLeafGreen);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isStatus
            ? (isDark ? accent.withValues(alpha: .14) : const Color(0xFFF3F6F4))
            : (isSelected
                ? (isDark ? scheme.primaryContainer : const Color(0xFFDCF5E5))
                : (isDark ? scheme.surface : const Color(0xFFF3F6F4))),
        borderRadius: BorderRadius.circular(AppConstants.radiusControl),
        border: Border.all(
          color: isDark ? scheme.outlineVariant : const Color(0xFFE5ECE7),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null || isStatus) ...[
              Icon(icon ?? Icons.info_outline, size: 15, color: accent),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? scheme.onSurface : const Color(0xFF17231D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
