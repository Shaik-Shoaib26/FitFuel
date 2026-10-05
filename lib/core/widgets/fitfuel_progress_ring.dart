import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class FitFuelProgressRing extends StatelessWidget {
  final double value, size, strokeWidth;
  final String centerTitle, centerSubtitle;
  final String? detailSubtitle;
  final Widget? topIcon;
  final Color? progressColor, backgroundColor;

  const FitFuelProgressRing({
    super.key,
    required this.value,
    this.size = 140,
    this.strokeWidth = 10,
    required this.centerTitle,
    required this.centerSubtitle,
    this.detailSubtitle,
    this.topIcon,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: 'Progress ring: $centerTitle $centerSubtitle',
      value: value.isFinite
          ? '${(value * 100).toStringAsFixed(0)}%'
          : 'Unavailable',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = constraints.hasBoundedWidth
              ? math.min(size, constraints.maxWidth)
              : size;
          final outside = media.textScaler.scale(16) > 19.2 || diameter < 120;
          final labels = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (topIcon != null) ...[
                topIcon!,
                const SizedBox(height: 2),
              ],
              Text(
                centerTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  height: 1.1,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
                ),
              ),
              if (centerSubtitle.isNotEmpty)
                Text(
                  centerSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (detailSubtitle != null && detailSubtitle!.isNotEmpty)
                Text(
                  detailSubtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
            ],
          );
          final ring = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: media.disableAnimations
                ? Duration.zero
                : const Duration(
                    milliseconds: AppConstants.animationDurationStandardMs),
            curve: Curves.easeOut,
            builder: (_, progress, __) => SizedBox(
              width: diameter,
              height: diameter,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: strokeWidth,
                color: progressColor ??
                    (isDark ? theme.colorScheme.primary : AppColors.primaryLeafGreen),
                backgroundColor: backgroundColor ??
                    (isDark
                        ? theme.colorScheme.outlineVariant
                        : const Color(0xFFE1EFE5)),
                strokeCap: StrokeCap.round,
              ),
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ring,
                  if (!outside)
                    SizedBox(
                      width: math.max(0, diameter - strokeWidth * 2 - 16),
                      child: labels,
                    ),
                ],
              ),
              if (outside) ...[const SizedBox(height: 12), labels],
            ],
          );
        },
      ),
    );
  }
}
