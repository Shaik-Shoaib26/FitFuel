import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Centralized Smooth Animated Radial/Circular Progress Indicator
class FitFuelProgressRing extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final String centerTitle;
  final String centerSubtitle;
  final Color? progressColor;
  final Color? backgroundColor;

  const FitFuelProgressRing({
    super.key,
    required this.value,
    this.size = 140,
    this.strokeWidth = 10,
    required this.centerTitle,
    required this.centerSubtitle,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = progressColor ?? (isDark ? AppColors.primary400 : AppColors.primary500);
    final bg = backgroundColor ?? (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle);
    final clampedVal = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: clampedVal),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: animValue,
                strokeWidth: strokeWidth,
                backgroundColor: bg,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTitle,
                  style: AppTypography.displayMedium(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.2,
                  ),
                ),
                if (centerSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    centerSubtitle,
                    style: TextStyle(
                      fontSize: size * 0.08,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
