import 'package:flutter/material.dart';
import 'health_editorial_hero.dart';

/// HealthHeader renders the editorial wellness hero and tip bar (Phase 35.6.3).
/// Matches Option C approved reference, delegating to [HealthEditorialHero].
class HealthHeader extends StatelessWidget {
  /// Contextual line built by the caller from real health data.
  final String contextMessage;
  final VoidCallback? onTipTap;

  const HealthHeader({
    super.key,
    required this.contextMessage,
    this.onTipTap,
  });

  @override
  Widget build(BuildContext context) {
    return HealthEditorialHero(
      contextMessage: contextMessage,
      onTipTap: onTipTap,
    );
  }
}
