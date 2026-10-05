import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/fitfuel_button.dart';

/// Reference-accurate Option A Empty State Card when no meal plan is active.
/// Shows healthy food composition imagery, inspiring title, description, and
/// primary "Create Meal Plan" and secondary "Smart Eat" CTAs.
class PlanEmptyState extends StatelessWidget {
  final VoidCallback onCreatePlanPressed;
  final VoidCallback onSmartEatPressed;

  const PlanEmptyState({
    super.key,
    required this.onCreatePlanPressed,
    required this.onSmartEatPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Hero Image
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/decorations/food_bowl_healthy.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: isDark
                        ? AppColors.darkPrimaryContainer
                        : AppColors.softSage,
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 48,
                      color: AppColors.primaryLeafGreen,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark ? AppColors.darkBgSurface : Colors.white)
                              .withValues(alpha: 0.8),
                          isDark ? AppColors.darkBgSurface : Colors.white,
                        ],
                        stops: const [0.3, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your meal plan',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Build a balanced day tailored around your calories, macros, and dietary preferences.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF657169),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FitFuelButton(
                        label: 'Create Meal Plan',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: onCreatePlanPressed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FitFuelButton(
                        label: 'Smart Eat',
                        type: FitFuelButtonType.secondary,
                        onPressed: onSmartEatPressed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
