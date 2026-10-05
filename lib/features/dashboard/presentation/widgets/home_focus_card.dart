import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../insights/domain/entities/daily_focus_entity.dart';
import '../../../insights/domain/entities/health_insight_entity.dart';
import '../../../insights/presentation/providers/insights_providers.dart';

/// Reference-accurate Today's Focus Card for FitFuel Phase 35.6.2.
/// Background: Warm cream/peach (#FFF8F0), 24px radius, subtle orange border.
/// Left: Large circular pale-orange hydration icon
/// Center: "Improve hydration", dynamic live ml deficit, supporting line
/// Actions: Green primary button "+ Log Water", secondary "View insights >"
/// Right: Bundled realistic clear glass of water with subtle mint leaves.
class HomeFocusCard extends ConsumerWidget {
  const HomeFocusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(dailyFocusProvider);
    final health = ref.watch(todayHealthRecordProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelSectionHeader(
          title: "Today's Focus",
          actionLabel: 'View insights >',
          onActionPressed: () => context.go('/progress/insights'),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        focus.when(
          loading: () => const FitFuelCard(
            child: FitFuelLoadingState(
                label: 'Preparing your focus', indicatorSize: 20),
          ),
          error: (error, _) => FitFuelErrorState(
            error: error,
            onRetry: () => ref
                .read(insightsControllerProvider.notifier)
                .loadInsights(),
          ),
          data: (value) {
            final dailyFocus = value is DailyFocusEntity ? value : null;
            return _FocusCardBody(
              focus: dailyFocus,
              waterIntake: health?.waterIntakeMl ?? 0.0,
              waterTarget: health?.waterTargetMl ?? 2500.0,
            );
          },
        ),
      ],
    );
  }
}

class _FocusCardBody extends StatelessWidget {
  final DailyFocusEntity? focus;
  final double waterIntake;
  final double waterTarget;

  const _FocusCardBody({
    required this.focus,
    required this.waterIntake,
    required this.waterTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isHydration =
        focus == null || focus!.category == InsightCategory.hydration;

    final remainingWater = (waterTarget - waterIntake).clamp(0.0, waterTarget);
    final remainingMl = remainingWater.round();

    final String title = focus?.title ??
        (isHydration ? 'Improve hydration' : 'Daily wellness focus');

    final String subtitle = isHydration
        ? (remainingMl > 0
            ? "You're $remainingMl ml below today's target."
            : "You've met today's hydration target (${waterTarget.round()} ml)!")
        : (focus?.description ??
            'Stay on track with your healthy daily goals.');

    const String purposeLine =
        'Small sips add up. One log now keeps your day on target.';

    final cardBg = isDark
        ? AppColors.darkBgSurface
        : const Color(0xFFFFF8F0); // Warm cream / peach
    final borderColor = isDark
        ? AppColors.darkBorderSubtle
        : const Color(0xFFF5A623).withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Realistic Clear Glass with Leaves (Aligned to bottom-right, non-interactive)
            if (isHydration)
              Positioned(
                bottom: -8,
                right: -8,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      'assets/decorations/hydration_glass.webp',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

            // Main Content Area
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large circular pale-orange hydration icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFECD6), // Soft warm peach circle
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.water_drop_rounded,
                            size: 24,
                            color: AppColors.hydrationOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.primaryText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.secondaryText,
                                fontSize: 14,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    purposeLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.secondaryText,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bottom Actions: Primary green button + Secondary View insights
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/health?section=hydration&action=log'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Log Water',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLeafGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/progress/insights'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryLeafGreen,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('View insights >'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
