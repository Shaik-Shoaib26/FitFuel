import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_destinations.dart';
import 'app_shell.dart';

class FitFuelAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final double? elevation;
  final bool? centerTitle;
  const FitFuelAppBar(
      {super.key,
      this.title,
      this.leading,
      this.actions,
      this.bottom,
      this.backgroundColor,
      this.elevation,
      this.centerTitle});
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final path = router?.routeInformationProvider.value.uri.path;
    final root = appDestinations.any((d) => d.path == path);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final isAi = path == '/ai';
    return AppBar(
      title: title,
      centerTitle: false,
      backgroundColor: backgroundColor,
      elevation: elevation,
      bottom: bottom,
      automaticallyImplyLeading: false,
      leading: router == null
          ? leading
          : root && !isAi
              ? null
              : IconButton(
                  tooltip: isAi ? 'Return to previous page' : 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (isAi && AppShellScope.maybeOf(context) != null) {
                      AppShellScope.maybeOf(context)!.returnFromAi();
                    } else if (router.canPop()) {
                      router.pop();
                    } else {
                      router.go(parentLocation(path ?? '/home'));
                    }
                  },
                ),
      actions: [
        ...?actions,
        if (router != null && compact && !isAi)
          IconButton(
              tooltip: 'Ask AI',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => router.go('/ai')),
        if (router != null && compact && path != '/profile' && !isAi)
          IconButton(
              tooltip: 'Profile and settings',
              icon: const Icon(Icons.person_outline),
              onPressed: () => router.push('/profile')),
      ],
    );
  }
}
