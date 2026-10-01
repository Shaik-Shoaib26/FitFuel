import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Consumer-style greeting with clear hierarchy: greeting > date > supportive
/// line. Name comes from the authenticated profile; a neutral greeting is used
/// when no name is available.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String initialsFor(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    if (parts.length == 1) return first.toUpperCase();
    return (first + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileStreamProvider);
    final entity = profile.value;
    final name = entity?.displayName?.trim();
    final now = DateTime.now();
    final greeting = greetingFor(now);
    final title =
        (name == null || name.isEmpty) ? greeting : '$greeting, $name';
    final dateLabel = DateFormat('EEEE, d MMMM').format(now);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatar = _ProfileAction(initials: initialsFor(name));

    // Brand-forward supportive line: dot + short human sentence.
    final supportLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              color: scheme.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppConstants.spaceSm),
        Flexible(
          child: Text(
            "Here's how your day is going.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppConstants.space2Xs),
              Text(
                dateLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppConstants.space2Xs),
              supportLine,
            ],
          ),
        ),
        const SizedBox(width: AppConstants.spaceSmd),
        avatar,
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final String initials;
  const _ProfileAction({required this.initials});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: scheme.primaryContainer,
      child: initials.isEmpty
          ? Icon(Icons.person_outline, color: scheme.onPrimaryContainer)
          : Text(
              initials,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
    );
    return Semantics(
      button: true,
      label: 'Profile and settings',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Profile and settings',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => GoRouter.maybeOf(context)?.push('/profile'),
          child: SizedBox(
            width: AppConstants.minTouchTargetSize,
            height: AppConstants.minTouchTargetSize,
            child: Center(child: avatar),
          ),
        ),
      ),
    );
  }
}
