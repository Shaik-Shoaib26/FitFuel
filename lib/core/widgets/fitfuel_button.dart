import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum FitFuelButtonType { primary, secondary, ghost, destructive }

class FitFuelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FitFuelButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final String? semanticsLabel;
  const FitFuelButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.type = FitFuelButtonType.primary,
      this.isLoading = false,
      this.icon,
      this.width,
      this.semanticsLabel});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final callback = isLoading ? null : onPressed;
    final content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppConstants.spaceSm),
          ] else if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppConstants.spaceSm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ]);
    final style = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusButton))));
    final button = switch (type) {
      FitFuelButtonType.primary =>
        ElevatedButton(onPressed: callback, style: style, child: content),
      FitFuelButtonType.secondary =>
        OutlinedButton(onPressed: callback, style: style, child: content),
      FitFuelButtonType.ghost =>
        TextButton(onPressed: callback, style: style, child: content),
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
                      : colors.onError)),
          child: content),
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
            child: button));
  }
}
