import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class FitFuelSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle, actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? actionWidget;
  const FitFuelSectionHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.actionLabel,
      this.onActionPressed,
      this.actionWidget});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: text.titleLarge)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: text.bodyMedium)
          ],
        ]);
    final action = actionWidget ??
        (actionLabel != null && onActionPressed != null
            ? TextButton(onPressed: onActionPressed, child: Text(actionLabel!))
            : null);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 480 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading,
              if (action != null) ...[const SizedBox(height: 4), action]
            ]);
      }
      return Row(children: [
        Expanded(child: heading),
        if (action != null) ...[
          const SizedBox(width: AppConstants.spaceMd),
          Flexible(child: action)
        ]
      ]);
    });
  }
}
