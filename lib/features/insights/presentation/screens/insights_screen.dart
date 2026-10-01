import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../domain/entities/health_insight_entity.dart';
import '../providers/insights_providers.dart';
import '../widgets/action_recommendation_card.dart';
import '../widgets/daily_focus_card.dart';
import '../widgets/insight_card.dart';

/// Premium Smart Health Insights Screen — AI priority alerts, daily focus,
/// recommended actions, and categorized health interpretations.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(insightsControllerProvider);
    final priorityAsync = ref.watch(priorityInsightsProvider);
    final actionsAsync = ref.watch(recommendedActionsProvider);

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Smart Health Insights'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Daily Health Insights',
            icon: const Icon(Icons.favorite_outline_rounded),
            onPressed: () => context.go('/progress/insights/health'),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(insightsControllerProvider.notifier).loadInsights(),
          child: state.insights.when(
            data: (insights) {
              return state.dailyFocus.when(
                data: (dailyFocus) {
                  final filteredInsights =
                      _filterInsights(insights, state.filter);
                  final positiveInsights = insights
                      .where((i) => i.category == InsightCategory.positive)
                      .toList();

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppConstants.spaceMd),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 950;

                        final leftColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Today's Focus Section
                            DailyFocusCard(dailyFocus: dailyFocus),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 2. Priority Alerts (Top active deficits)
                            priorityAsync.when(
                              data: (priorityList) {
                                if (priorityList.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FitFuelSectionHeader(
                                      title: 'Priority Alerts',
                                      subtitle:
                                          'Areas needing immediate nutrition or habit support.',
                                    ),
                                    const SizedBox(height: AppConstants.spaceSm),
                                    ...priorityList
                                        .map((i) => InsightCard(insight: i)),
                                    const SizedBox(
                                        height: AppConstants.spaceMd),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: FitFuelLoadingState(
                                    label: 'Loading priority alerts...',
                                    indicatorSize: 18,
                                  ),
                                ),
                              ),
                              error: (err, _) => FitFuelErrorState(
                                error: err,
                                messageOverride: 'Error loading priority alerts.',
                                onRetry: () => ref.refresh(priorityInsightsProvider),
                              ),
                            ),

                            // 3. Action Recommendations
                            actionsAsync.when(
                              data: (actions) {
                                if (actions.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FitFuelSectionHeader(
                                      title: 'Recommended Actions',
                                      subtitle:
                                          'Direct actions to hit your targets.',
                                    ),
                                    const SizedBox(height: AppConstants.spaceSm),
                                    ...actions.map((a) =>
                                        ActionRecommendationCard(
                                            recommendation: a)),
                                    const SizedBox(
                                        height: AppConstants.spaceMd),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: FitFuelLoadingState(
                                    label: 'Loading actions...',
                                    indicatorSize: 18,
                                  ),
                                ),
                              ),
                              error: (err, _) => FitFuelErrorState(
                                error: err,
                                messageOverride: 'Error loading actions.',
                                onRetry: () => ref.refresh(recommendedActionsProvider),
                              ),
                            ),
                          ],
                        );

                        final rightColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Filter chips
                            _buildFilterRow(
                                context, ref, state.filter, isDark),
                            const SizedBox(height: AppConstants.spaceMd),

                            // Filtered Insights List
                            const FitFuelSectionHeader(
                              title: 'Detailed Health Interpretation',
                              subtitle:
                                  'Nutritional balance, workouts, and wellness.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            if (filteredInsights.isEmpty)
                              const Center(
                                child: FitFuelEmptyState(
                                  icon: Icons.lightbulb_outline_rounded,
                                  title: 'No Insights for this Category',
                                  description:
                                      'Log more meals, hydration, and habits to unlock detailed pattern recognition.',
                                ),
                              )
                            else
                              ...filteredInsights
                                  .map((i) => InsightCard(insight: i)),
                            const SizedBox(height: AppConstants.spaceMd),

                            // Positive Progress
                            if (positiveInsights.isNotEmpty) ...[
                              const FitFuelSectionHeader(
                                title: 'Positive Progress & Wins',
                                subtitle:
                                    'Milestones and consistent healthy habits.',
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              ...positiveInsights
                                  .map((i) => InsightCard(insight: i)),
                            ],
                          ],
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 10, child: leftColumn),
                              const SizedBox(width: AppConstants.spaceLg),
                              Expanded(flex: 11, child: rightColumn),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              leftColumn,
                              const SizedBox(height: AppConstants.spaceMd),
                              rightColumn,
                            ],
                          );
                        }
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: FitFuelLoadingState(label: 'Loading daily focus...'),
                ),
                error: (err, _) => FitFuelErrorState(
                  error: err,
                  messageOverride: 'Error loading daily focus.',
                  onRetry: () =>
                      ref.read(insightsControllerProvider.notifier).loadInsights(),
                ),
              );
            },
            loading: () => const Center(
              child: FitFuelLoadingState(label: 'Loading smart insights...'),
            ),
            error: (err, _) => FitFuelErrorState(
              error: err,
              messageOverride: 'Error loading smart insights.',
              onRetry: () =>
                  ref.read(insightsControllerProvider.notifier).loadInsights(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(
      BuildContext context, WidgetRef ref, String activeFilter, bool isDark) {
    final filters = ['All', 'Nutrition', 'Fitness', 'Wellness', 'Progress'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(insightsControllerProvider.notifier).changeFilter(f);
                }
              },
              selectedColor: AppColors.primary500.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary500 : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary500 : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<HealthInsightEntity> _filterInsights(
      List<HealthInsightEntity> list, String filter) {
    if (filter == 'All') {
      return list.where((i) => i.category != InsightCategory.positive).toList();
    }

    return list.where((i) {
      if (i.category == InsightCategory.positive) return false;
      switch (filter) {
        case 'Nutrition':
          return i.category == InsightCategory.nutrition;
        case 'Fitness':
          return i.category == InsightCategory.exercise ||
              i.category == InsightCategory.habits;
        case 'Wellness':
          return i.category == InsightCategory.wellness ||
              i.category == InsightCategory.hydration;
        case 'Progress':
          return i.category == InsightCategory.progress ||
              i.category == InsightCategory.weight;
        default:
          return true;
      }
    }).toList();
  }
}
