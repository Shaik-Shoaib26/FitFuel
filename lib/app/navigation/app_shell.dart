import '../../core/widgets/fitfuel_identity.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_destinations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class AppShellScope extends InheritedWidget {
  final VoidCallback returnFromAi;
  const AppShellScope(
      {super.key, required this.returnFromAi, required super.child});
  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  @override
  bool updateShouldNotify(AppShellScope oldWidget) => false;
}

/// The navigation shell remains at the same element position when resized.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _lastMainBranch = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppConstants.breakpointMobile;
    final expanded = width >= AppConstants.breakpointTablet;
    final shell = widget.navigationShell;
    final selected = shell.currentIndex;
    if (selected < 5) _lastMainBranch = selected;
    final aiOnMobile = compact && selected == 5;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primary400 : AppColors.primary500;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return AppShellScope(
      returnFromAi: () => shell.goBranch(_lastMainBranch),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Row(children: [
          if (!compact && !expanded)
            SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: selected,
                        onDestinationSelected: shell.goBranch,
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                            padding: EdgeInsets.all(12),
                            child: FitFuelIdentity(compact: true)),
                        destinations: [
                          for (final destination in appDestinations)
                            NavigationRailDestination(
                                icon: Icon(destination.icon),
                                label: Text(destination.label)),
                        ],
                        trailing: Column(children: [
                          IconButton(
                              tooltip: 'Profile',
                              onPressed: () => context.push('/profile'),
                              icon: const Icon(Icons.person_outline)),
                          IconButton(
                              tooltip: 'Settings',
                              onPressed: () => context.push('/settings'),
                              icon: const Icon(Icons.settings_outlined)),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ),
          if (expanded)
            SafeArea(
                child: SizedBox(
              width: expanded ? 224 : 112,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: FitFuelIdentity(),
                ),
                Expanded(
                    child: SingleChildScrollView(
                        child: Column(children: [
                  for (var i = 0; i < appDestinations.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Semantics(
                          selected: selected == i,
                          child: Material(
                            color: selected == i
                                ? (isDark
                                    ? AppColors.darkPrimaryContainer
                                    : AppColors.primaryContainer)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                            child: InkWell(
                              key: ValueKey('nav-${appDestinations[i].label}'),
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMd),
                              onTap: () => shell.goBranch(i),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: expanded
                                    ? Row(children: [
                                        Icon(
                                          appDestinations[i].icon,
                                          color: selected == i
                                              ? primaryColor
                                              : textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(
                                          appDestinations[i].label,
                                          style: TextStyle(
                                            color: selected == i
                                                ? textPrimary
                                                : textSecondary,
                                            fontWeight: selected == i
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            fontSize: 14,
                                          ),
                                        )),
                                      ])
                                    : Column(children: [
                                        Icon(
                                          appDestinations[i].icon,
                                          color: selected == i
                                              ? primaryColor
                                              : textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(appDestinations[i].label,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: selected == i
                                                  ? textPrimary
                                                  : textSecondary,
                                              fontSize: 11,
                                              fontWeight: selected == i
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            )),
                                      ]),
                              ),
                            ),
                          )),
                    ),
                ]))),
                const Divider(),
                TextButton.icon(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Profile')),
                TextButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Settings')),
                const SizedBox(height: 12),
              ]),
            )),
          Expanded(key: const ValueKey('branch-workspace'), child: shell),
        ]),
        bottomNavigationBar: compact && !aiOnMobile
            ? NavigationBar(
                key: const ValueKey('primary-navigation'),
                selectedIndex: selected,
                onDestinationSelected: (index) => shell.goBranch(index),
                destinations: [
                  for (final destination in appDestinations.take(5))
                    NavigationDestination(
                        icon: Icon(destination.icon), label: destination.label),
                ],
              )
            : null,
      ),
    );
  }
}

