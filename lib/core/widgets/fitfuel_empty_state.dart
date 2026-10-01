import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'fitfuel_button.dart';

class FitFuelEmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final String? actionLabel, secondaryActionLabel;
  final VoidCallback? onActionPressed, onSecondaryActionPressed;
  const FitFuelEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.actionLabel,
      this.onActionPressed,
      this.secondaryActionLabel,
      this.onSecondaryActionPressed});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
        child: SingleChildScrollView(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spaceLg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon,
                              size: 24,
                              color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 16),
                      Semantics(
                          header: true,
                          child: Text(title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge)),
                      const SizedBox(height: 8),
                      Text(description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium),
                      if (actionLabel != null && onActionPressed != null) ...[
                        const SizedBox(height: 20),
                        FitFuelButton(
                            label: actionLabel!, onPressed: onActionPressed)
                      ],
                      if (secondaryActionLabel != null &&
                          onSecondaryActionPressed != null)
                        FitFuelButton(
                            label: secondaryActionLabel!,
                            onPressed: onSecondaryActionPressed,
                            type: FitFuelButtonType.ghost),
                    ])))));
  }
}
