import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_typography.dart';

enum FitFuelButtonType { primary, secondary, ghost }

class FitFuelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FitFuelButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const FitFuelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = FitFuelButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case FitFuelButtonType.primary:
        return SizedBox(
          width: width ?? double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primary400 : AppColors.primary500,
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20),
                        const SizedBox(width: AppConstants.spaceSm),
                      ],
                      Text(label, style: AppTypography.buttonLabel(isDark: isDark)),
                    ],
                  ),
          ),
        );
      case FitFuelButtonType.secondary:
        return SizedBox(
          width: width ?? double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              side: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            child: Text(label, style: AppTypography.bodyMedium(isDark: isDark)),
          ),
        );
      case FitFuelButtonType.ghost:
        return TextButton(
          onPressed: onPressed,
          child: Text(
            label,
            style: AppTypography.bodyMedium(isDark: isDark).copyWith(
              color: isDark ? AppColors.primary400 : AppColors.primary500,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}
