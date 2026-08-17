import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Centralized FitFuel White / Light Wellness Card Component
class FitFuelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final BorderSide? border;
  final VoidCallback? onTap;
  final double elevation;

  const FitFuelCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppConstants.radiusLg,
    this.color,
    this.border,
    this.onTap,
    this.elevation = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.fromBorderSide(
          border ??
              BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 1,
              ),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha((elevation * 3).toInt().clamp(0, 255)),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: cardContent,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: cardContent,
    );
  }
}
