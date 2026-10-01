import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../domain/utils/analytics_insight_engine.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_empty_state.dart';
import '../widgets/analytics_insight_card.dart';
import '../widgets/analytics_metric_card.dart';
import '../widgets/analytics_range_selector.dart';
import '../widgets/analytics_summary_card.dart';
import '../widgets/exercise_trend_chart.dart';
import '../widgets/goal_adherence_chart.dart';
import '../widgets/hydration_trend_chart.dart';
import '../widgets/nutrition_trend_chart.dart';
import '../widgets/weight_trend_chart.dart';
import '../widgets/wellness_trend_chart.dart';

/// Premium Health Analytics Screen — Multi-metric trends, charts, focus areas,
/// and period comparisons.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsControllerProvider);
    final controller = ref.read(analyticsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Health Analytics'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Nutrition Analytics',
            icon: const Icon(Icons.restaurant_outlined),
            onPressed: () => context.go('/progress/analytics/nutrition'),
          ),
        ],
      ),
      body: AdaptivePageLayout(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppConstants.spaceSm,
                bottom: AppConstants.spaceSm,
              ),
              child: AnalyticsRangeSelector(
                selectedRange: state.range,
                onRangeChanged: (newRange) => controller.changeRange(newRange),
              ),
            ),
            Expanded(
              child: state.analytics.when(
                loading: () => const Center(
                  child: FitFuelLoadingState(label: 'Loading analytics data...'),
                ),
                error: (err, st) => FitFuelErrorState(
                  error: err.toString(),
                  onRetry: () => controller.loadAnalytics(),
                ),
                data: (entity) {
                  if (entity.summary.activeLoggingDays == 0) {
                    return const SingleChildScrollView(
                      child: AnalyticsEmptyState(),
                    );
                  }

                  final summary = entity.summary;
                  final previous = entity.previousSummary;
                  final dataPoints = entity.dataPoints;

                  final insights = AnalyticsInsightEngine.generateInsights(
                    dataPoints: dataPoints,
                    summary: summary,
                    previousSummary: previous,
                  );

                  final focusArea = AnalyticsInsightEngine.detectFocusArea(
                      summary, dataPoints);

                  final bestDay =
                      AnalyticsInsightEngine.calculateBestDay(dataPoints);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppConstants.spaceMd),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 950;

                        final leftColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnalyticsSummaryCard(summary: summary),
                            const SizedBox(height: AppConstants.spaceMd),
                            _buildFocusAndBestDayRow(
                                context, focusArea, bestDay, isDark),
                            const SizedBox(height: AppConstants.spaceMd),
                            const FitFuelSectionHeader(
                              title: 'Goal Adherence',
                              subtitle:
                                  'Daily target achievement rate across categories.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            _buildGoalAdherenceCard(
                                context, summary, isDark),
                            const SizedBox(height: AppConstants.spaceMd),
                            const FitFuelSectionHeader(
                              title: 'Nutrition & Calorie Trends',
                              subtitle:
                                  'Caloric intake vs target line over time.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            AnalyticsMetricCard(
                              title: 'Caloric Intake',
                              value:
                                  '${summary.averageCalories.toStringAsFixed(0)} kcal / day',
                              subtitle:
                                  'P: ${summary.averageProtein.toStringAsFixed(1)}g | C: ${summary.averageCarbs.toStringAsFixed(1)}g | F: ${summary.averageFat.toStringAsFixed(1)}g',
                              trend: summary.trends['nutrition'] ?? 'Stable',
                              icon: Icons.restaurant_rounded,
                              color: AppColors.protein,
                              details: [
                                NutritionTrendChart(dataPoints: dataPoints),
                                const SizedBox(height: 8),
                                _buildDetailRow(context, 'Calorie Adherence',
                                    '${summary.calorieAdherencePercentage.toStringAsFixed(0)}% of days', isDark),
                                _buildDetailRow(context, 'Protein Adherence',
                                    '${summary.proteinAdherencePercentage.toStringAsFixed(0)}% of days', isDark),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            const FitFuelSectionHeader(
                              title: 'Hydration Trends',
                              subtitle: 'Daily water intake consistency.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            AnalyticsMetricCard(
                              title: 'Water Logged',
                              value:
                                  '${(summary.averageWater / 1000.0).toStringAsFixed(2)} L / day',
                              trend: summary.trends['hydration'] ?? 'Stable',
                              icon: Icons.water_drop_rounded,
                              color: AppColors.hydration,
                              details: [
                                HydrationTrendChart(dataPoints: dataPoints),
                                const SizedBox(height: 8),
                                _buildDetailRow(context, 'Water Target Adherence',
                                    '${summary.hydrationAdherencePercentage.toStringAsFixed(0)}% of days', isDark),
                              ],
                            ),
                          ],
                        );

                        final rightColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (insights.isNotEmpty) ...[
                              const FitFuelSectionHeader(
                                title: 'Smart Insights',
                                subtitle:
                                    'Observations generated from your logging patterns.',
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              ...insights.map(
                                  (ins) => AnalyticsInsightCard(insight: ins)),
                              const SizedBox(height: AppConstants.spaceMd),
                            ],
                            const FitFuelSectionHeader(
                              title: 'Activity & Wellness Trends',
                              subtitle: 'Workout frequency and wellness rating.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            AnalyticsMetricCard(
                              title: 'Physical Activity',
                              value:
                                  '${summary.averageWorkoutMinutes.toStringAsFixed(1)} min / day',
                              trend: summary.trends['exercise'] ?? 'Stable',
                              icon: Icons.fitness_center_rounded,
                              color: AppColors.calories,
                              details: [
                                ExerciseTrendChart(dataPoints: dataPoints),
                                const SizedBox(height: 8),
                                _buildDetailRow(context, 'Exercise Consistency',
                                    '${summary.exerciseConsistencyPercentage.toStringAsFixed(0)}% of days active', isDark),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            AnalyticsMetricCard(
                              title: 'Wellness Index',
                              value:
                                  '${summary.averageWellness.toStringAsFixed(1)} / 100',
                              trend: summary.trends['wellness'] ?? 'Stable',
                              icon: Icons.spa_rounded,
                              color: AppColors.fat,
                              details: [
                                WellnessTrendChart(dataPoints: dataPoints),
                                const SizedBox(height: 8),
                                _buildDetailRow(context, 'Peak Wellness Score',
                                    summary.bestWellnessScore.toStringAsFixed(0), isDark),
                                _buildDetailRow(context, 'Lowest Wellness Score',
                                    summary.lowestWellnessScore.toStringAsFixed(0), isDark),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            AnalyticsMetricCard(
                              title: 'Weight History',
                              value: summary.currentWeight != null
                                  ? '${summary.currentWeight!.toStringAsFixed(1)} kg'
                                  : 'No weight logged',
                              trend: summary.trends['weight'] ?? 'Stable',
                              icon: Icons.monitor_weight_outlined,
                              color: AppColors.primary500,
                              details: [
                                WeightTrendChart(dataPoints: dataPoints),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                    context,
                                    'Starting Weight',
                                    summary.startingWeight != null
                                        ? '${summary.startingWeight!.toStringAsFixed(1)} kg'
                                        : '—',
                                    isDark),
                                _buildDetailRow(
                                    context,
                                    'Total Change',
                                    summary.weightChange != null
                                        ? '${summary.weightChange! > 0 ? '+' : ''}${summary.weightChange!.toStringAsFixed(1)} kg (${summary.weightChangePercentage!.toStringAsFixed(1)}%)'
                                        : '—',
                                    isDark),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            FitFuelSectionHeader(
                              title: 'Period Comparison',
                              subtitle:
                                  'Comparing against the previous ${state.range} period.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            _buildPeriodComparisonCard(
                                context, summary, previous, state.range, isDark),
                          ],
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: leftColumn),
                              const SizedBox(width: AppConstants.spaceLg),
                              Expanded(flex: 9, child: rightColumn),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalAdherenceCard(
      BuildContext context, dynamic summary, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        children: [
          GoalAdherenceChart(summary: summary),
          const SizedBox(height: 12),
          _buildAdherenceRow(
            context,
            'Calories',
            summary.calorieAdherencePercentage,
            '${summary.averageCalories.toStringAsFixed(0)} kcal',
            summary.trends['nutrition'] ?? 'Stable',
            AppColors.primary500,
            isDark,
          ),
          _buildAdherenceRow(
            context,
            'Protein',
            summary.proteinAdherencePercentage,
            '${summary.averageProtein.toStringAsFixed(1)}g',
            summary.trends['nutrition'] ?? 'Stable',
            AppColors.protein,
            isDark,
          ),
          _buildAdherenceRow(
            context,
            'Water',
            summary.hydrationAdherencePercentage,
            '${summary.averageWater.toStringAsFixed(1)} ml',
            summary.trends['hydration'] ?? 'Stable',
            AppColors.hydration,
            isDark,
          ),
          _buildAdherenceRow(
            context,
            'Exercise',
            summary.exerciseConsistencyPercentage,
            '${summary.averageWorkoutMinutes.toStringAsFixed(0)}m avg',
            summary.trends['exercise'] ?? 'Stable',
            AppColors.calories,
            isDark,
          ),
          _buildAdherenceRow(
            context,
            'Habits',
            summary.habitConsistencyPercentage,
            '${summary.habitConsistencyPercentage.toStringAsFixed(0)}%',
            summary.trends['habits'] ?? 'Stable',
            AppColors.fat,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodComparisonCard(BuildContext context, dynamic summary,
      dynamic previous, String range, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonRow(
            context,
            'Wellness Score',
            summary.averageWellness,
            previous?.averageWellness,
            format: (val) => val.toStringAsFixed(1),
            suffix: ' pts',
            isDark: isDark,
          ),
          _buildComparisonRow(
            context,
            'Daily Calories',
            summary.averageCalories,
            previous?.averageCalories,
            format: (val) => val.toStringAsFixed(0),
            suffix: ' kcal',
            isDark: isDark,
          ),
          _buildComparisonRow(
            context,
            'Daily Water',
            summary.averageWater,
            previous?.averageWater,
            format: (val) => (val / 1000.0).toStringAsFixed(2),
            suffix: ' L',
            isDark: isDark,
          ),
          _buildComparisonRow(
            context,
            'Workout Minutes',
            summary.averageWorkoutMinutes,
            previous?.averageWorkoutMinutes,
            format: (val) => val.toStringAsFixed(0),
            suffix: ' mins',
            isDark: isDark,
          ),
          _buildComparisonRow(
            context,
            'Habit Completion',
            summary.habitConsistencyPercentage,
            previous?.habitConsistencyPercentage,
            format: (val) => '${val.toStringAsFixed(0)}%',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceRow(
    BuildContext context,
    String title,
    double percent,
    String actualAndTarget,
    String trend,
    Color color,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.trending_flat;
    if (trend == 'Improving') {
      trendColor = AppColors.stateSuccess;
      trendIcon = Icons.arrow_upward_rounded;
    } else if (trend == 'Declining') {
      trendColor = AppColors.stateError;
      trendIcon = Icons.arrow_downward_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  actualAndTarget,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (percent / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkBorderSubtle
                    : color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(trendIcon, size: 14, color: trendColor),
        ],
      ),
    );
  }

  Widget _buildFocusAndBestDayRow(
    BuildContext context,
    FocusArea focusArea,
    BestDayInfo? bestDay,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        final focusWidget = FitFuelCard(
          padding: const EdgeInsets.all(AppConstants.spaceSm),
          border: const BorderSide(color: AppColors.calories, width: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.calories, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Focus Area',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.calories,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                focusArea.category,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focusArea.reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Action: ${focusArea.recommendedAction}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );

        final bestDayWidget = FitFuelCard(
          padding: const EdgeInsets.all(AppConstants.spaceSm),
          border: const BorderSide(color: AppColors.stateSuccess, width: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.stateSuccess, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Best Day',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.stateSuccess,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (bestDay != null) ...[
                Text(
                  DateFormat('EEEE, MMM d').format(bestDay.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Score: ${bestDay.score.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.stateSuccess,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: bestDay.whatWentWell.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.stateSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✓ $item',
                        style: const TextStyle(
                          color: AppColors.stateSuccess,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                const Text(
                  'No days logged yet.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11),
                ),
              ],
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              focusWidget,
              const SizedBox(height: AppConstants.spaceSm),
              bestDayWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: focusWidget),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(child: bestDayWidget),
          ],
        );
      },
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String label,
    double current,
    double? previous, {
    required String Function(double) format,
    String suffix = '',
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    if (previous == null || previous == 0.0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '— (Insufficient Data)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    final diff = current - previous;
    final double diffPercent = previous > 0 ? (diff / previous) * 100 : 0.0;

    String diffText = '';
    Color color = Colors.grey;
    IconData icon = Icons.trending_flat;

    if (diff > 0.01) {
      diffText = '+${diffPercent.toStringAsFixed(1)}%';
      color = AppColors.stateSuccess;
      icon = Icons.arrow_upward_rounded;
    } else if (diff < -0.01) {
      diffText = '${diffPercent.toStringAsFixed(1)}%';
      color = AppColors.stateError;
      icon = Icons.arrow_downward_rounded;
    } else {
      diffText = 'Stable';
      color = AppColors.primary500;
      icon = Icons.trending_flat_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Row(
            children: [
              Text(
                '${format(current)}$suffix vs ${format(previous)}$suffix',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 10, color: color),
                    const SizedBox(width: 2),
                    Text(
                      diffText,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
