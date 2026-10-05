import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

enum FitFuelButtonType { primary, secondary, ghost, destructive }

/// FitFuel button design aligned with Phase 35.6 Fresh Green specs:
/// Primary: #0F7D38 green, white text, 50-54px height, 16px radius
/// Secondary: #EEF7F1 soft green surface, #0F7D38 text
/// Ghost: #0F7D38 text, 48px touch target
class FitFuelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FitFuelButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final String? semanticsLabel;

  const FitFuelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = FitFuelButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final callback = isLoading ? null : onPressed;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: AppConstants.spaceSm),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppConstants.spaceSm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusButton),
    );

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 50)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
      shape: WidgetStatePropertyAll(buttonShape),
      elevation: const WidgetStatePropertyAll(0),
    );

    final button = switch (type) {
      FitFuelButtonType.primary => ElevatedButton(
          onPressed: callback,
          style: style.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .12)
                    : (isDark ? colors.primary : AppColors.primaryLeafGreen)),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .38)
                    : Colors.white),
          ),
          child: content,
        ),
      FitFuelButtonType.secondary => OutlinedButton(
          onPressed: callback,
          style: style.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? Colors.transparent
                    : (isDark ? colors.surface : const Color(0xFFEEF7F1))),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .38)
                    : (isDark ? colors.primary : AppColors.primaryLeafGreen)),
            side: WidgetStateProperty.all(
              BorderSide(
                color: isDark
                    ? colors.outline
                    : const Color(0xFFD6EADB),
                width: 1,
              ),
            ),
          ),
          child: content,
        ),
      FitFuelButtonType.ghost => TextButton(
          onPressed: callback,
          style: style.copyWith(
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .38)
                    : (isDark ? colors.primary : AppColors.primaryLeafGreen)),
          ),
          child: content,
        ),
      FitFuelButtonType.destructive => FilledButton(
          onPressed: callback,
          style: style.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .12)
                    : colors.error),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(alpha: .38)
                    : colors.onError),
          ),
          child: content,
        ),
    };

    return Semantics(
      label: semanticsLabel ?? label,
      value: isLoading ? 'Loading' : null,
      button: true,
      enabled: callback != null,
      excludeSemantics: true,
      onTap: callback,
      child: SizedBox(
        width: width ??
            (type == FitFuelButtonType.ghost ? null : double.infinity),
        child: button,
      ),
    );
  }
}
