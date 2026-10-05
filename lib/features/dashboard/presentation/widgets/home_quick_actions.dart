import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';

class _HomeQuickAction {
  final String label;
  final String semantics;
  final IconData icon;
  final String route;
  final Color Function(BuildContext) color;
  const _HomeQuickAction({
    required this.label,
    required this.semantics,
    required this.icon,
    required this.route,
    required this.color,
  });
}

const _actions = <_HomeQuickAction>[
  _HomeQuickAction(
    label: 'Log Food',
    semantics: 'Log food',
    icon: Icons.restaurant_outlined,
    route: '/nutrition/log',
    color: _leafColor,
  ),
  _HomeQuickAction(
    label: 'Scan Meal',
    semantics: 'Scan meal with AI',
    icon: Icons.camera_alt_outlined,
    route: '/nutrition/scan',
    color: _leafColor,
  ),
  _HomeQuickAction(
    label: 'Recipes',
    semantics: 'Explore healthy recipes',
    icon: Icons.menu_book_outlined,
    route: '/plan',
    color: _leafColor,
  ),
  _HomeQuickAction(
    label: 'Goals',
    semantics: 'Manage health goals',
    icon: Icons.flag_outlined,
    route: '/settings/goals',
    color: _leafColor,
  ),
  _HomeQuickAction(
    label: 'Add Water',
    semantics: 'Add water',
    icon: Icons.water_drop_outlined,
    route: '/health?section=hydration&action=add',
    color: _hydrationColor,
  ),
  _HomeQuickAction(
    label: 'Exercise',
    semantics: 'Log exercise',
    icon: Icons.directions_run_outlined,
    route: '/health?section=exercise&action=add',
    color: _exerciseColor,
  ),
  _HomeQuickAction(
    label: 'Ask AI',
    semantics: 'Ask AI coach',
    icon: Icons.auto_awesome_outlined,
    route: '/ai',
    color: _aiColor,
  ),
];

Color _leafColor(BuildContext context) => AppColors.primaryLeafGreen;
Color _hydrationColor(BuildContext context) =>
    FitFuelSemanticColors.of(context).hydration;
Color _exerciseColor(BuildContext context) => AppColors.exercise;
Color _aiColor(BuildContext context) => AppColors.primaryLeafGreen;

/// Compact Quick Actions designed for Fresh Green:
/// Soft rounded tiles, no giant cards, clean semantic / green icons.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FitFuelSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: AppConstants.spaceSmd),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 4
              : (constraints.maxWidth >= 380 ? 4 : 2);
          const spacing = 10.0;
          final tileWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in _actions)
                SizedBox(
                  width: tileWidth,
                  child: _QuickActionTile(action: action),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _HomeQuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = action.color(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: action.semantics,
      excludeSemantics: true,
      child: Material(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusControl),
          side: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE5ECE7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(action.route),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, size: 18, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
