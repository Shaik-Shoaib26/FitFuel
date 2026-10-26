import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Reference-accurate Option A Quick Actions for the Plan Dashboard.
/// Renders 5 compact cards: AI Plan, Add Meal, Recipes, Search Foods,
/// and Preferences. Uses Wrap so actions reflow gracefully across
/// breakpoints without squeezing text.
class PlanQuickActions extends StatelessWidget {
  const PlanQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionCard(
              context: context,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF8B5CF6),
              bgColor:
                  const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
              label: 'AI Plan',
              onTap: () => context.go('/plan/meals'),
              isDark: isDark,
            ),
            _buildActionCard(
              context: context,
              icon: Icons.add_rounded,
              iconColor: AppColors.primaryLeafGreen,
              bgColor: AppColors.primaryLeafGreen
                  .withValues(alpha: isDark ? 0.2 : 0.1),
              label: 'Add Meal',
              onTap: () => context.go('/nutrition/log'),
              isDark: isDark,
            ),
            _buildActionCard(
              context: context,
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFFF2B84B),
              bgColor: const Color(0xFFF2B84B)
                  .withValues(alpha: isDark ? 0.2 : 0.12),
              label: 'Recipes',
              onTap: () => context.go('/nutrition/search?view=recipes'),
              isDark: isDark,
            ),
            _buildActionCard(
              context: context,
              icon: Icons.search_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFF2563EB)
                  .withValues(alpha: isDark ? 0.2 : 0.1),
              label: 'Search Foods',
              onTap: () => context.go('/nutrition/search?view=all'),
              isDark: isDark,
            ),
            _buildActionCard(
              context: context,
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF075E48),
              bgColor:
                  const Color(0xFF075E48).withValues(alpha: isDark ? 0.2 : 0.1),
              label: 'Preferences',
              onTap: () => context.go('/settings/preferences'),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    // Responsive width: aim for ~5 per row on wide screens, gracefully
    // wrap to 2 rows on phones without compressing the label.
    final double cardWidth =
        ((MediaQuery.of(context).size.width - 16 * 2 - 10 * 4) / 5)
            .clamp(72.0, 160.0)
            .toDouble();

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: isDark ? AppColors.darkBgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: cardWidth,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
