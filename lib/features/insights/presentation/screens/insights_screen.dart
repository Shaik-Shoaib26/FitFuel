import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/entities/health_insight_entity.dart';
import '../providers/insights_providers.dart';
import '../widgets/daily_focus_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/action_recommendation_card.dart';

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
      appBar: AppBar(
        title: const Text('Smart Health Insights'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(insightsControllerProvider.notifier).loadInsights(),
          child: state.insights.when(
            data: (insights) {
              return state.dailyFocus.when(
                data: (dailyFocus) {
                  // Apply active filters
                  final filteredInsights = _filterInsights(insights, state.filter);
                  final positiveInsights = insights.where((i) => i.category == InsightCategory.positive).toList();

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppConstants.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Today's Focus Section
                        DailyFocusCard(dailyFocus: dailyFocus),
                        const SizedBox(height: AppConstants.spaceLg),

                        // Filter chips
                        _buildFilterRow(context, ref, state.filter, isDark),
                        const SizedBox(height: AppConstants.spaceLg),

                        // 2. Priority Insights (Top 3 active deficits)
                        priorityAsync.when(
                          data: (priorityList) {
                            if (priorityList.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Priority Alerts',
                                  style: AppTypography.heading3(isDark: isDark),
                                ),
                                const SizedBox(height: AppConstants.spaceSm),
                                ...priorityList.map((i) => InsightCard(insight: i)),
                                const SizedBox(height: AppConstants.spaceLg),
                              ],
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error: $err'),
                        ),

                        // 3. Filtered Insights List
                        Text(
                          'Detailed Health Interpretation',
                          style: AppTypography.heading3(isDark: isDark),
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        if (filteredInsights.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No detailed insights for this category.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredInsights.map((i) => InsightCard(insight: i)),
                        const SizedBox(height: AppConstants.spaceLg),

                        // 4. Action Recommendations
                        actionsAsync.when(
                          data: (actions) {
                            if (actions.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recommended Actions',
                                  style: AppTypography.heading3(isDark: isDark),
                                ),
                                const SizedBox(height: AppConstants.spaceSm),
                                ...actions.map((a) => ActionRecommendationCard(recommendation: a)),
                                const SizedBox(height: AppConstants.spaceLg),
                              ],
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error: $err'),
                        ),

                        // 5. Positive Progress
                        if (positiveInsights.isNotEmpty) ...[
                          Text(
                            'Positive Progress & Milestones',
                            style: AppTypography.heading3(isDark: isDark),
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          ...positiveInsights.map((i) => InsightCard(insight: i)),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading Focus: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading Insights: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, WidgetRef ref, String activeFilter, bool isDark) {
    final filters = ['All', 'Nutrition', 'Fitness', 'Wellness', 'Progress'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(insightsControllerProvider.notifier).changeFilter(f);
                }
              },
              selectedColor: AppColors.primary500,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<HealthInsightEntity> _filterInsights(List<HealthInsightEntity> list, String filter) {
    if (filter == 'All') return list.where((i) => i.category != InsightCategory.positive).toList();

    return list.where((i) {
      if (i.category == InsightCategory.positive) return false;
      switch (filter) {
        case 'Nutrition':
          return i.category == InsightCategory.nutrition;
        case 'Fitness':
          return i.category == InsightCategory.exercise || i.category == InsightCategory.habits;
        case 'Wellness':
          return i.category == InsightCategory.wellness || i.category == InsightCategory.hydration;
        case 'Progress':
          return i.category == InsightCategory.progress || i.category == InsightCategory.weight;
        default:
          return true;
      }
    }).toList();
  }
}
