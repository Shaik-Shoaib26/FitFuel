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
    color: _primaryColor,
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

Color _primaryColor(BuildContext context) => Theme.of(context).colorScheme.primary;
Color _hydrationColor(BuildContext context) =>
    FitFuelSemanticColors.of(context).hydration;
Color _exerciseColor(BuildContext context) => AppColors.exercise;
Color _aiColor(BuildContext context) => AppColors.ai;

/// Four primary quick actions. Each reuses an existing route and action.
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
          // Desktop support column (~35-40% width) reads best as a 2x2 grid;
          // wide unconstrained canvases may use a single row of four.
          final columns = constraints.maxWidth >= 720 ? 4 : 2;
          const spacing = AppConstants.spaceSmd;
          final tileWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in _actions)
                SizedBox(
                    width: tileWidth, child: _QuickActionTile(action: action)),
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
    final scheme = theme.colorScheme;
    final accent = action.color(context);
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: action.semantics,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(action.route),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceSmd,
                  vertical: AppConstants.spaceMd),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Color.alphaBlend(
                            accent.withValues(alpha: .14), scheme.surface),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: accent.withValues(alpha: .25))),
                    child: Icon(action.icon, size: 22, color: accent),
                  ),
                  const SizedBox(height: AppConstants.spaceSmd),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Non-color affordance: chevron reinforces interactivity.
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: isDark
                        ? scheme.onSurfaceVariant.withValues(alpha: .6)
                        : scheme.onSurfaceVariant,
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
