import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// 4 Compact Quick Action buttons for Nutrition Screen (Option B):
/// Log Food, Scan Meal, Recipes, Goals.
class NutritionQuickActions extends StatelessWidget {
  final VoidCallback onLogFood;
  final VoidCallback onScanMeal;
  final VoidCallback onRecipes;
  final VoidCallback onGoals;

  const NutritionQuickActions({
    super.key,
    required this.onLogFood,
    required this.onScanMeal,
    required this.onRecipes,
    required this.onGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Log Food',
            icon: Icons.restaurant_rounded,
            onTap: onLogFood,
            semanticsLabel: 'Log food item',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            label: 'Scan Meal',
            icon: Icons.photo_camera_rounded,
            onTap: onScanMeal,
            semanticsLabel: 'Scan meal with camera',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            label: 'Recipes',
            icon: Icons.soup_kitchen_rounded,
            onTap: onRecipes,
            semanticsLabel: 'View recipes',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            label: 'Goals',
            icon: Icons.track_changes_rounded,
            onTap: onGoals,
            semanticsLabel: 'Adjust nutrition goals',
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
            width: 1,
          ),
        ),
        elevation: isDark ? 0 : 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.03),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: AppColors.primaryLeafGreen,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
