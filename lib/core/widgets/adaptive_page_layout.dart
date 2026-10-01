import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'fitfuel_card.dart';

/// Centers content without double-padding existing scroll views.
/// New pages can explicitly opt into [pagePadding] and [safeArea].
class AdaptivePageLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;
  const AdaptivePageLayout(
      {super.key,
      required this.child,
      this.maxWidth,
      this.padding,
      this.safeArea = false});
  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.all(
      MediaQuery.sizeOf(context).width < AppConstants.breakpointMobile
          ? AppConstants.spaceMd
          : AppConstants.spaceLg);
  @override
  Widget build(BuildContext context) {
    final content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxWidth ?? AppConstants.maxContentWidthDesktop),
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child)));
    return safeArea ? SafeArea(child: content) : content;
  }
}

class DestinationCard extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final VoidCallback onTap;
  const DestinationCard(
      {super.key,
      required this.title,
      required this.description,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) => FitFuelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ]));
}

class DestinationGrid extends StatelessWidget {
  final List<Widget> children;
  const DestinationGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 2 : 1;
        return Wrap(
            spacing: AppConstants.spaceMd,
            runSpacing: AppConstants.spaceSmd,
            children: [
              for (final child in children)
                SizedBox(
                    width: (constraints.maxWidth -
                            (columns - 1) * AppConstants.spaceMd) /
                        columns,
                    child: child),
            ]);
      });
}
