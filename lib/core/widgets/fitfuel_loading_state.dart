import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_typography.dart';

/// FitFuel Lightweight Loading State
/// Avoids giant CircularProgressIndicator widgets floating in large empty screens.
/// Uses an appropriately sized indicator with optional label.
class FitFuelLoadingState extends StatelessWidget {
  final String? label;
  final double indicatorSize;

  const FitFuelLoadingState({
    super.key,
    this.label,
    this.indicatorSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Semantics(
          label: label ?? 'Loading',
          excludeSemantics: true,
          liveRegion: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: indicatorSize,
                height: indicatorSize,
                child: MediaQuery.of(context).disableAnimations
                    ? const Icon(Icons.hourglass_empty)
                    : CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark
                            ? AppColors.primary400
                            : AppColors.primary500,
                      ),
              ),
              if (label != null) ...[
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  label!,
                  style: AppTypography.secondaryBody(isDark: isDark),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
