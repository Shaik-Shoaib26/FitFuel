import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// One surface primitive for passive summaries and keyboard-accessible actions.
class FitFuelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding, margin;
  final double borderRadius, elevation;
  final Color? color;
  final BorderSide? border;
  final VoidCallback? onTap;
  final bool isInteractive, selected;
  final String? semanticsLabel;
  const FitFuelCard(
      {super.key,
      required this.child,
      this.padding,
      this.margin,
      this.borderRadius = AppConstants.radiusCard,
      this.color,
      this.border,
      this.onTap,
      this.elevation = AppConstants.elevationCard,
      this.isInteractive = false,
      this.selected = false,
      this.semanticsLabel});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Semantics(
        label: semanticsLabel,
        button: onTap != null,
        selected: selected ? true : null,
        child: Material(
          color: color ?? (selected ? colors.primaryContainer : colors.surface),
          elevation: elevation,
          shadowColor: Colors.black.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: border ??
                  BorderSide(
                      color:
                          selected ? colors.primary : colors.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              canRequestFocus: onTap != null,
              borderRadius: radius,
              child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: onTap != null ? 48 : 0),
                  child: Padding(
                      padding:
                          padding ?? const EdgeInsets.all(AppConstants.spaceMd),
                      child: child))),
        ),
      ),
    );
  }
}
