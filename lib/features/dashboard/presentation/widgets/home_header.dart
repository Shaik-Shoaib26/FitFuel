import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_identity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Reference-accurate Home Header for FitFuel Phase 35.6.2.
/// Top area:
///   LEFT: FitFuel brand mark (36px) + deep green FitFuel wordmark
///   RIGHT: Notification icon + Profile avatar
/// Botanical decoration:
///   Upper-right subtle green leaves layer (behind content, IgnorePointer)
/// Below header (28px gap):
///   Date (e.g. Sunday, 4 October) in #657169
///   Greeting (e.g. Good evening 🌿) in #17231D (32px w700)
///   Subtitle ("Small steps. Big changes.") in #657169
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
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
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
    final greetingText = (name == null || name.isEmpty)
        ? greeting
        : '$greeting,\n$name';
    final dateLabel = DateFormat('EEEE, d MMMM').format(now);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. DECORATIVE BOTANICAL LEAF ACCENT (Upper Right, Behind Content)
        Positioned(
          top: -16,
          right: -16,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.18 : 0.32,
              child: SizedBox(
                width: 190,
                height: 190,
                child: Image.asset(
                  'assets/decorations/botanical_home_top_right.webp',
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),

        // 2. MAIN HEADER CONTENT
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar: Brand Identity (Left) & Actions (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand Mark + Wordmark
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const FitFuelBrandMark(size: 36),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'FitFuel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.white
                                : AppColors.deepBrandGreen,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Notification & Profile Circle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Reminders & Notifications',
                      onPressed: () => context.push('/reminders'),
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: isDark ? Colors.white70 : AppColors.secondaryText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ProfileAction(initials: initialsFor(name)),
                  ],
                ),
              ],
            ),

            // Deliberate 28px vertical gap to date & greeting
            const SizedBox(height: 28),

            // Date: #657169, 15px, w500
            Text(
              dateLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 5),

            // Greeting: 32px w700 with botanical leaf
            Semantics(
              header: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      greetingText,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.primaryText,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primaryLeafGreen,
                    size: 26,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // Subtitle: "Small steps. Big changes.", 16px w400 #657169
            Text(
              'Small steps. Big changes.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final String initials;
  const _ProfileAction({required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatar = CircleAvatar(
      radius: 19,
      backgroundColor: isDark
          ? AppColors.darkPrimaryContainer
          : AppColors.softSage,
      child: initials.isEmpty
          ? const Icon(Icons.person_rounded,
              color: AppColors.primaryLeafGreen, size: 20)
          : Text(
              initials,
              style: const TextStyle(
                color: AppColors.primaryLeafGreen,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
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
