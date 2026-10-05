import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class FitFuelSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle, actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? actionWidget;

  const FitFuelSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
              letterSpacing: -0.3,
            ) ?? TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
            ),
          ),
        ],
      ],
    );

    final action = actionWidget ??
        (actionLabel != null && onActionPressed != null
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: TextButton(
                  onPressed: onActionPressed,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isDark ? AppColors.primary300 : AppColors.primaryLeafGreen,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
              )
            : null);

    if (action == null) {
      return heading;
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            heading,
            action,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heading),
          const SizedBox(width: AppConstants.spaceSm),
          Flexible(fit: FlexFit.loose, child: action),
        ],
      );
    });
  }
}
