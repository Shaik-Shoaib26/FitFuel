import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/app_colors.dart';

/// Available surface variants for card hierarchy.
enum FitFuelCardVariant { base, raised, tonal, hero }

/// One surface primitive for passive summaries and keyboard-accessible actions.
/// Designed for Phase 35.6 Fresh Green: #FFFFFF pure white cards, 20px radius, 1px #E5ECE7 border, subtle elevation.
class FitFuelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding, margin;
  final double borderRadius, elevation;
  final Color? color;
  final BorderSide? border;
  final VoidCallback? onTap;
  final bool isInteractive, selected;
  final String? semanticsLabel;
  final FitFuelCardVariant variant;

  const FitFuelCard({
    super.key,
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
    this.semanticsLabel,
    this.variant = FitFuelCardVariant.base,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    Color surfaceColor;
    BorderSide borderSide;

    if (color != null) {
      surfaceColor = color!;
      borderSide = border ??
          BorderSide(
              color: isDark
                  ? AppColors.darkBorderSubtle
                  : const Color(0xFFE5ECE7));
    } else {
      switch (variant) {
        case FitFuelCardVariant.hero:
          surfaceColor =
              isDark ? AppColors.darkPrimaryContainer : AppColors.softSage;
          borderSide = border ??
              BorderSide(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : const Color(0xFFCDE2D3),
                  width: 1.0);
          break;
        case FitFuelCardVariant.tonal:
          surfaceColor =
              isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF1F8F3);
          borderSide = border ??
              BorderSide(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : const Color(0xFFE5ECE7));
          break;
        case FitFuelCardVariant.raised:
          surfaceColor =
              isDark ? AppColors.darkBgSurface : AppColors.primarySurface;
          borderSide = border ??
              BorderSide(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : const Color(0xFFE5ECE7));
          break;
        case FitFuelCardVariant.base:
          surfaceColor = isDark ? colors.surface : AppColors.pureWhite;
          borderSide = border ??
              BorderSide(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : const Color(0xFFE5ECE7));
          break;
      }
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Semantics(
        label: semanticsLabel,
        button: onTap != null,
        selected: selected ? true : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: surfaceColor,
            elevation: elevation,
            shadowColor: Colors.black.withValues(alpha: .04),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: borderSide,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              canRequestFocus: onTap != null,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: onTap != null ? 48 : 0),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AppConstants.spaceMd),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
