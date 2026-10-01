import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

/// Compact Health header. Page title carries the hierarchy; the supporting line
/// is derived only from values the Health data already exposes (never advice
/// or inferred conditions).
class HealthHeader extends StatelessWidget {
  /// Contextual line built by the caller from real health data.
  final String contextMessage;

  const HealthHeader({super.key, required this.contextMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Your wellness today',
            style: theme.textTheme.headlineLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: AppConstants.space2Xs),
        Text(
          'Your daily wellness at a glance.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppConstants.spaceSmd),
        // Contextual status strip: brand dot + one sentence of real data.
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceSmd,
              vertical: AppConstants.spaceSm),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                scheme.primary.withValues(alpha: .07), scheme.surface),
            borderRadius: BorderRadius.circular(AppConstants.radiusControl),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: scheme.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  contextMessage,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
