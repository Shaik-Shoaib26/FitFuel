import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/progress_calculator.dart';
import '../controllers/progress_controller.dart';
import '../widgets/progress_milestones_section.dart';
import '../widgets/progress_deep_exploration.dart';
import '../widgets/progress_insight_card.dart';
import '../widgets/progress_range_selector.dart';
import '../widgets/progress_summary_metric_card.dart';
import '../widgets/weight_progress_card.dart';
import '../widgets/wellness_score_card.dart';

/// FITFUEL — PHASE 35.6.6
/// Reference-Accurate Modern & Minimal Progress Dashboard (Option A visual target)
///
/// Features:
/// 1. App bar with left title "Progress", settings/filter action, AI action, and profile.
/// 2. Intro subtitle: "Track your health journey and see your progress over time."
/// 3. Segmented Time Range Selector (7 Days | 30 Days | 90 Days) driving live calculations.
/// 4. Top 3 Summary Metrics: Nutrition Streak, Water Avg per day, Activity Avg per day.
/// 5. Overall Wellness Score Card: Circular score ring (leaf, score, "of 100") + 4 category progress bars.
/// 6. Weight Progress Section: Stat pill, minimal emerald line chart with soft gradient, date axis.
/// 7. Key Insights Section: Soft mint container with lightbulb icon and concise insight.
/// 8. Milestones & Achievements: Real unlocked badges and in-progress achievement targets.
/// 9. Deep Exploration: Gateway rows to Health Analytics, Weekly Report, and Smart Health Insights.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateStreamProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication required.')),
      );
    }

    final nutritionHistory =
        ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
    final healthHistory =
        ref.watch(healthStreamProvider).valueOrNull ?? const [];
    final weightHistory =
        ref.watch(weightHistoryStreamProvider).valueOrNull ?? const [];
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    final profile = ref.watch(currentProfileStreamProvider).valueOrNull;

    final progressState = ref.watch(progressControllerProvider);
    final range = progressState.selectedRange;

    // Calculate Summary stats live from active data and selected range
    final summary = ProgressCalculator.calculateSummary(
      nutritionHistory: nutritionHistory,
      healthHistory: healthHistory,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      daysCount: range,
    );

    // Watch health insights for key insights display
    final insightsState = ref.watch(insightsControllerProvider);
    final insightsList = insightsState.insights.valueOrNull;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.warmOffWhite,
      appBar: FitFuelAppBar(
        backgroundColor: isDark ? AppColors.darkBgBase : AppColors.warmOffWhite,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Progress',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryText,
              letterSpacing: -0.4,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Settings / Goals',
            onPressed: () => context.push('/settings/goals'),
          ),
        ],
      ),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                // Wide Screen / Tablet / Desktop: 2-Column Layout
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Core Metrics & Charts
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildIntroHeader(isDark),
                          const SizedBox(height: 16),
                          ProgressRangeSelector(
                            selectedDays: range,
                            onRangeSelected: (days) => ref
                                .read(progressControllerProvider.notifier)
                                .setRange(days),
                          ),
                          const SizedBox(height: 16),
                          ProgressSummaryMetricsRow(summary: summary),
                          const SizedBox(height: 16),
                          WellnessScoreCard(summary: summary),
                          const SizedBox(height: 16),
                          WeightProgressCard(
                            summary: summary,
                            weightHistory: weightHistory,
                            selectedDays: range,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Column: Insights, Milestones & Deep Exploration
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProgressInsightCard(
                            summary: summary,
                            insights: insightsList,
                          ),
                          const SizedBox(height: 20),
                          ProgressMilestonesSection(
                            milestones: summary.milestones,
                          ),
                          const SizedBox(height: 20),
                          const ProgressDeepExploration(),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Mobile / Standard Layout (Option A single-column vertical flow)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroHeader(isDark),
                  const SizedBox(height: 14),

                  // 1. Segmented Time Range Selector
                  ProgressRangeSelector(
                    selectedDays: range,
                    onRangeSelected: (days) => ref
                        .read(progressControllerProvider.notifier)
                        .setRange(days),
                  ),
                  const SizedBox(height: 14),

                  // 2. Top 3 Summary Metrics
                  ProgressSummaryMetricsRow(summary: summary),
                  const SizedBox(height: 16),

                  // 3. Overall Wellness Score Card
                  WellnessScoreCard(summary: summary),
                  const SizedBox(height: 16),

                  // 4. Weight Progress Card
                  WeightProgressCard(
                    summary: summary,
                    weightHistory: weightHistory,
                    selectedDays: range,
                  ),
                  const SizedBox(height: 16),

                  // 5. Key Insights Card
                  ProgressInsightCard(
                    summary: summary,
                    insights: insightsList,
                  ),
                  const SizedBox(height: 20),

                  // 6. Milestones & Achievements
                  ProgressMilestonesSection(
                    milestones: summary.milestones,
                  ),
                  const SizedBox(height: 20),

                  // 7. Deep Exploration
                  const ProgressDeepExploration(),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntroHeader(bool isDark) {
    return Text(
      'Track your health journey and see your progress over time.',
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
        height: 1.35,
      ),
    );
  }
}
