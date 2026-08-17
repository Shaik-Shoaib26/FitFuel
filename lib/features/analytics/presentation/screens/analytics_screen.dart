import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../domain/utils/analytics_insight_engine.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsControllerProvider);
    final controller = ref.read(analyticsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Analytics'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          AnalyticsRangeSelector(
            selectedRange: state.range,
            onRangeChanged: (newRange) => controller.changeRange(newRange),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.analytics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading analytics: $err'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => controller.loadAnalytics(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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

                // Generated Insights
                final insights = AnalyticsInsightEngine.generateInsights(
                  dataPoints: dataPoints,
                  summary: summary,
                  previousSummary: previous,
                );

                // Focus Area
                final focusArea = AnalyticsInsightEngine.detectFocusArea(summary, dataPoints);

                // Best Day
                final bestDay = AnalyticsInsightEngine.calculateBestDay(dataPoints);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnalyticsSummaryCard(summary: summary),
                      const SizedBox(height: 16),

                      // Focus Area & Best Day
                      _buildFocusAndBestDayRow(context, focusArea, bestDay),
                      const SizedBox(height: 16),

                      // Goal Adherence
                      _buildSectionTitle(context, 'Goal Adherence'),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
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
                              ),
                              _buildAdherenceRow(
                                context,
                                'Protein',
                                summary.proteinAdherencePercentage,
                                '${summary.averageProtein.toStringAsFixed(1)}g',
                                summary.trends['nutrition'] ?? 'Stable',
                              ),
                              _buildAdherenceRow(
                                context,
                                'Water',
                                summary.hydrationAdherencePercentage,
                                '${summary.averageWater.toStringAsFixed(1)} ml',
                                summary.trends['hydration'] ?? 'Stable',
                              ),
                              _buildAdherenceRow(
                                context,
                                'Exercise',
                                summary.exerciseConsistencyPercentage,
                                '${summary.averageWorkoutMinutes.toStringAsFixed(0)}m avg',
                                summary.trends['exercise'] ?? 'Stable',
                              ),
                              _buildAdherenceRow(
                                context,
                                'Habits',
                                summary.habitConsistencyPercentage,
                                '${summary.habitConsistencyPercentage.toStringAsFixed(0)}%',
                                summary.trends['habits'] ?? 'Stable',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Smart Insights
                      if (insights.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Smart Insights'),
                        ...insights.map((ins) => AnalyticsInsightCard(insight: ins)),
                        const SizedBox(height: 16),
                      ],

                      // Nutrition Trend
                      _buildSectionTitle(context, 'Nutrition Analytics'),
                      AnalyticsMetricCard(
                        title: 'Caloric Intake',
                        value: '${summary.averageCalories.toStringAsFixed(0)} kcal / day',
                        subtitle: 'Protein: ${summary.averageProtein.toStringAsFixed(1)}g avg | Carbs: ${summary.averageCarbs.toStringAsFixed(1)}g avg | Fat: ${summary.averageFat.toStringAsFixed(1)}g avg',
                        trend: summary.trends['nutrition'] ?? 'Stable',
                        icon: Icons.restaurant,
                        color: Colors.green,
                        details: [
                          NutritionTrendChart(dataPoints: dataPoints),
                          const SizedBox(height: 8),
                          _buildDetailRow(context, 'Calorie Adherence', '${summary.calorieAdherencePercentage.toStringAsFixed(0)}% of days'),
                          _buildDetailRow(context, 'Protein Adherence', '${summary.proteinAdherencePercentage.toStringAsFixed(0)}% of days'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Hydration Trend
                      _buildSectionTitle(context, 'Hydration Analytics'),
                      AnalyticsMetricCard(
                        title: 'Water Logged',
                        value: '${(summary.averageWater / 1000.0).toStringAsFixed(2)} L / day',
                        trend: summary.trends['hydration'] ?? 'Stable',
                        icon: Icons.local_drink,
                        color: Colors.blue,
                        details: [
                          HydrationTrendChart(dataPoints: dataPoints),
                          const SizedBox(height: 8),
                          _buildDetailRow(context, 'Water Target Adherence', '${summary.hydrationAdherencePercentage.toStringAsFixed(0)}% of days'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Exercise Trend
                      _buildSectionTitle(context, 'Exercise Analytics'),
                      AnalyticsMetricCard(
                        title: 'Physical Activity',
                        value: '${summary.averageWorkoutMinutes.toStringAsFixed(1)} min / day',
                        trend: summary.trends['exercise'] ?? 'Stable',
                        icon: Icons.fitness_center,
                        color: Colors.orange,
                        details: [
                          ExerciseTrendChart(dataPoints: dataPoints),
                          const SizedBox(height: 8),
                          _buildDetailRow(context, 'Exercise Consistency', '${summary.exerciseConsistencyPercentage.toStringAsFixed(0)}% of days active'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Wellness Trend
                      _buildSectionTitle(context, 'Wellness Analytics'),
                      AnalyticsMetricCard(
                        title: 'Wellness Index',
                        value: '${summary.averageWellness.toStringAsFixed(1)} / 100',
                        trend: summary.trends['wellness'] ?? 'Stable',
                        icon: Icons.spa,
                        color: Colors.teal,
                        details: [
                          WellnessTrendChart(dataPoints: dataPoints),
                          const SizedBox(height: 8),
                          _buildDetailRow(context, 'Peak Wellness Score', summary.bestWellnessScore.toStringAsFixed(0)),
                          _buildDetailRow(context, 'Lowest Wellness Score', summary.lowestWellnessScore.toStringAsFixed(0)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Weight Trend
                      _buildSectionTitle(context, 'Weight Analytics'),
                      AnalyticsMetricCard(
                        title: 'Weight History',
                        value: summary.currentWeight != null
                            ? '${summary.currentWeight!.toStringAsFixed(1)} kg'
                            : 'No weight logged',
                        trend: summary.trends['weight'] ?? 'Stable',
                        icon: Icons.monitor_weight_outlined,
                        color: Colors.purple,
                        details: [
                          WeightTrendChart(dataPoints: dataPoints),
                          const SizedBox(height: 8),
                          _buildDetailRow(context, 'Starting Weight', summary.startingWeight != null ? '${summary.startingWeight!.toStringAsFixed(1)} kg' : '—'),
                          _buildDetailRow(context, 'Total Change', summary.weightChange != null ? '${summary.weightChange! > 0 ? '+' : ''}${summary.weightChange!.toStringAsFixed(1)} kg (${summary.weightChangePercentage!.toStringAsFixed(1)}%)' : '—'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Period Comparison
                      _buildSectionTitle(context, 'Period Comparison'),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compared to previous ${state.range} period',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildComparisonRow(
                                context,
                                'Wellness Score',
                                summary.averageWellness,
                                previous?.averageWellness,
                                format: (val) => val.toStringAsFixed(1),
                                suffix: ' pts',
                              ),
                              _buildComparisonRow(
                                context,
                                'Daily Calories',
                                summary.averageCalories,
                                previous?.averageCalories,
                                format: (val) => val.toStringAsFixed(0),
                                suffix: ' kcal',
                              ),
                              _buildComparisonRow(
                                context,
                                'Daily Water',
                                summary.averageWater,
                                previous?.averageWater,
                                format: (val) => (val / 1000.0).toStringAsFixed(2),
                                suffix: ' L',
                              ),
                              _buildComparisonRow(
                                context,
                                'Workout Minutes',
                                summary.averageWorkoutMinutes,
                                previous?.averageWorkoutMinutes,
                                format: (val) => val.toStringAsFixed(0),
                                suffix: ' mins',
                              ),
                              _buildComparisonRow(
                                context,
                                'Habit Completion',
                                summary.habitConsistencyPercentage,
                                previous?.habitConsistencyPercentage,
                                format: (val) => '${val.toStringAsFixed(0)}%',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
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
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.trending_flat;
    if (trend == 'Improving') {
      trendColor = Colors.green;
      trendIcon = Icons.arrow_upward;
    } else if (trend == 'Declining') {
      trendColor = Colors.red;
      trendIcon = Icons.arrow_downward;
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
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(actualAndTarget, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100.0,
                minHeight: 8,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weak Category Focus Area Card
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Focus Area',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    focusArea.category,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    focusArea.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Action: ${focusArea.recommendedAction}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Best Day Card
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Best Day',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (bestDay != null) ...[
                    Text(
                      DateFormat('EEEE, MMM d').format(bestDay.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score: ${bestDay.score.toStringAsFixed(0)}/100',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: bestDay.whatWentWell.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '✓ $item',
                            style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const Text('No days logged yet.', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String label,
    double current,
    double? previous, {
    required String Function(double) format,
    String suffix = '',
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (previous == null || previous == 0.0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text('— (Insufficient Data)', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[400])),
          ],
        ),
      );
    }

    final diff = current - previous;
    final double diffPercent = previous > 0 ? (diff / previous) * 100 : 0.0;

    String diffText = '';
    Color color = Colors.grey;
    IconData icon = Icons.trending_flat;

    // Interpretation logic: larger is better for all metrics listed
    if (diff > 0.01) {
      diffText = '+${diffPercent.toStringAsFixed(1)}%';
      color = Colors.green;
      icon = Icons.arrow_upward;
    } else if (diff < -0.01) {
      diffText = '${diffPercent.toStringAsFixed(1)}%';
      color = Colors.red;
      icon = Icons.arrow_downward;
    } else {
      diffText = 'Stable';
      color = Colors.blue;
      icon = Icons.trending_flat;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                '${format(current)}$suffix vs ${format(previous)}$suffix',
                style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 10, color: color),
                    const SizedBox(width: 2),
                    Text(
                      diffText,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
