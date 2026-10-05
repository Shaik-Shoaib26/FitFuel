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
/// Redesigned for Phase 35.6 Fresh Green:
/// Mobile: White bottom bar, subtle top border, 68-76px height, active #0F7D38, inactive #8A958D, soft mint container.
/// Tablet/Desktop: White sidebar, 1px #E5ECE7 right border, selected #E6F4EA / #0F7D38, unselected #657169.
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

    final railColor = isDark ? AppColors.darkNavBg : AppColors.pureWhite;
    final borderColor = isDark ? AppColors.darkBorderSubtle : const Color(0xFFE5ECE7);

    return AppShellScope(
      returnFromAi: () => shell.goBranch(_lastMainBranch),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBgBase : AppColors.appCanvas,
        body: Row(children: [
          if (!compact && !expanded)
            SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: railColor,
                  border: Border(right: BorderSide(color: borderColor, width: 1)),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: selected,
                          backgroundColor: Colors.transparent,
                          onDestinationSelected: shell.goBranch,
                          labelType: NavigationRailLabelType.all,
                          indicatorColor: isDark
                              ? AppColors.darkPrimaryContainer
                              : AppColors.softSage,
                          selectedIconTheme: const IconThemeData(
                              color: AppColors.primaryLeafGreen),
                          unselectedIconTheme: IconThemeData(
                              color: isDark ? Colors.white60 : const Color(0xFF8A958D)),
                          selectedLabelTextStyle: const TextStyle(
                            color: AppColors.primaryLeafGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF657169),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
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
                                icon: Icon(Icons.person_outline,
                                    color: isDark ? Colors.white70 : AppColors.secondaryText)),
                            IconButton(
                                tooltip: 'Settings',
                                onPressed: () => context.push('/settings'),
                                icon: Icon(Icons.settings_outlined,
                                    color: isDark ? Colors.white70 : AppColors.secondaryText)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          if (expanded)
            Container(
              decoration: BoxDecoration(
                color: railColor,
                border: Border(right: BorderSide(color: borderColor, width: 1)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: expanded ? 224 : 112,
                  child: Column(children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: FitFuelIdentity(),
                    ),
                    Expanded(
                        child: SingleChildScrollView(
                            child: Column(children: [
                      for (var i = 0; i < appDestinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Semantics(
                              selected: selected == i,
                              child: Material(
                                color: isDark
                                    ? (selected == i ? AppColors.darkNavSelectedBg : Colors.transparent)
                                    : (selected == i ? AppColors.softSage : Colors.transparent),
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMd),
                                child: InkWell(
                                  key: ValueKey('nav-${appDestinations[i].label}'),
                                  borderRadius:
                                      BorderRadius.circular(AppConstants.radiusMd),
                                  onTap: () => shell.goBranch(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(children: [
                                      Icon(
                                        appDestinations[i].icon,
                                        color: isDark
                                            ? (selected == i
                                                ? AppColors.primary300
                                                : AppColors.darkNavText)
                                            : (selected == i
                                                ? AppColors.primaryLeafGreen
                                                : const Color(0xFF657169)),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: Text(
                                        appDestinations[i].label,
                                        style: TextStyle(
                                          color: isDark
                                              ? (selected == i
                                                  ? Colors.white
                                                  : AppColors.darkNavText)
                                              : (selected == i
                                                  ? AppColors.primaryLeafGreen
                                                  : const Color(0xFF657169)),
                                          fontWeight: selected == i
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      )),
                                    ]),
                                  ),
                                ),
                              )),
                        ),
                    ]))),
                    Divider(color: borderColor, height: 1),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(children: [
                          ListTile(
                              leading: Icon(Icons.person_outline,
                                  color: isDark ? Colors.white70 : const Color(0xFF657169)),
                              title: const Text('Profile'),
                              onTap: () => context.push('/profile'),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                              tileColor: isDark ? Colors.transparent : Colors.transparent,
                              titleTextStyle: TextStyle(
                                  color: isDark ? Colors.white70 : AppColors.primaryText,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14)),
                          ListTile(
                              leading: Icon(Icons.settings_outlined,
                                  color: isDark ? Colors.white70 : const Color(0xFF657169)),
                              title: const Text('Settings'),
                              onTap: () => context.push('/settings'),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                              tileColor: isDark ? Colors.transparent : Colors.transparent,
                              titleTextStyle: TextStyle(
                                  color: isDark ? Colors.white70 : AppColors.primaryText,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14)),
                        ])),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ),

          Expanded(key: const ValueKey('branch-workspace'), child: shell),
        ]),
        bottomNavigationBar: compact && !aiOnMobile
            ? Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkNavBg : AppColors.pureWhite,
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 70,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    indicatorColor: isDark
                        ? AppColors.darkPrimaryContainer
                        : AppColors.softSage,
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    iconTheme: WidgetStateProperty.resolveWith((states) =>
                        IconThemeData(
                          color: states.contains(WidgetState.selected)
                              ? (isDark ? AppColors.primary300 : AppColors.primaryLeafGreen)
                              : (isDark ? Colors.white60 : const Color(0xFF8A958D)),
                          size: 24,
                        )),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                        TextStyle(
                          color: states.contains(WidgetState.selected)
                              ? (isDark ? AppColors.primary300 : AppColors.primaryLeafGreen)
                              : (isDark ? Colors.white60 : const Color(0xFF8A958D)),
                          fontSize: 12,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                  ),
                  child: NavigationBar(
                    key: const ValueKey('primary-navigation'),
                    selectedIndex: selected,
                    onDestinationSelected: (index) => shell.goBranch(index),
                    destinations: [
                      for (final destination in appDestinations.take(5))
                        NavigationDestination(
                            icon: Icon(destination.icon), label: destination.label),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
