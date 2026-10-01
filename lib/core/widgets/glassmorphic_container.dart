import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'fitfuel_card.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 0.0,
    this.opacity = 1.0,
    this.borderRadius = AppConstants.radiusLg,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // Legacy call sites inherit calm surfaces; explicit glass remains available.
    if (blur == 0 && opacity == 1) {
      return FitFuelCard(
          padding: padding,
          margin: margin,
          borderRadius: borderRadius,
          child: child);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBgSurface.withValues(alpha: opacity)
                  : AppColors.lightBgSurface.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorderSubtle.withValues(alpha: 0.5)
                    : AppColors.lightBorderSubtle.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
