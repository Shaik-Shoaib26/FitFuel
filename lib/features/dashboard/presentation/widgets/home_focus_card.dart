import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../../app/navigation/feature_action_navigation.dart';
import '../../../insights/domain/entities/daily_focus_entity.dart';
import '../../../insights/domain/entities/health_insight_entity.dart';
import '../../../insights/presentation/providers/insights_providers.dart';

/// One primary focus from the existing insights system. The full insights
/// workspace stays on its canonical page.
class HomeFocusCard extends ConsumerWidget {
  const HomeFocusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(dailyFocusProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelSectionHeader(
          title: "Today's Focus",
          actionLabel: 'View insights',
          onActionPressed: () => context.go('/progress/insights'),
        ),
        const SizedBox(height: AppConstants.spaceSmd),
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
            if (value is! DailyFocusEntity) {
              return const _FocusEmpty();
            }
            return _FocusBody(focus: value);
          },
        ),
      ],
    );
  }
}

class _FocusBody extends StatelessWidget {
  final DailyFocusEntity focus;
  const _FocusBody({required this.focus});

  Color _accent(BuildContext context) => switch (focus.priority) {
        InsightPriority.critical => Theme.of(context).colorScheme.error,
        InsightPriority.high => FitFuelSemanticColors.of(context).warning,
        _ => Theme.of(context).colorScheme.primary,
      };

  IconData get _icon => switch (focus.category) {
        InsightCategory.hydration => Icons.water_drop_outlined,
        InsightCategory.exercise => Icons.directions_run_outlined,
        InsightCategory.habits => Icons.check_circle_outline,
        InsightCategory.weight => Icons.monitor_weight_outlined,
        InsightCategory.progress => Icons.trending_up,
        InsightCategory.wellness => Icons.favorite_outline,
        _ => Icons.lightbulb_outline,
      };

  String get _purposeLine => switch (focus.category) {
        InsightCategory.hydration =>
          'Small sips add up. One log now keeps your day on target.',
        InsightCategory.exercise =>
          'A short session now protects your momentum for the week.',
        InsightCategory.habits =>
          'Consistency beats intensity. Check off one more habit today.',
        InsightCategory.weight =>
          'A quick check-in keeps your weekly trend honest.',
        InsightCategory.progress =>
          'See how far you have come since last week.',
        InsightCategory.wellness => 'A minute for yourself is worth it.',
        _ => 'A small step now makes the rest of the day easier.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(context);
    final action = focus.recommendedActions.isEmpty
        ? null
        : focus.recommendedActions.first;
    return FitFuelCard(
      color: Color.alphaBlend(accent.withValues(alpha: .07), scheme.surface),
      border: BorderSide(color: accent.withValues(alpha: .30)),
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: "Today's focus: ${focus.title}",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    shape: BoxShape.circle),
                child: Icon(_icon, color: accent),
              ),
              const SizedBox(width: AppConstants.spaceSmd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focus.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppConstants.space2Xs),
                    Text(
                      focus.description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            _purposeLine,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Wrap(
              spacing: AppConstants.spaceSm,
              runSpacing: AppConstants.spaceSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(insightLocation(action)),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(action.title),
                ),
                TextButton(
                  onPressed: () => context.go('/progress/insights'),
                  child: const Text('View insights'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusEmpty extends StatelessWidget {
  const _FocusEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log your day to build your focus.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spaceSmd),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/progress/insights'),
              child: const Text('Open insights'),
            ),
          ),
        ],
      ),
    );
  }
}
