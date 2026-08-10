import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/nutrition_insights_engine.dart';
import '../providers/nutrition_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Intelligence'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
          child: nutritionAsync.when(
            data: (records) {
              return goalsAsync.when(
                data: (goals) {
                  final result = NutritionInsightsEngine.analyzeHistory(
                    records: records,
                    goals: goals,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Weekly summary metrics
                      _buildWeeklySummaryCard(result, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 2. Trend indicators
                      _buildTrendsCard(result.trends, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 3. Smart actions & Insights
                      Text(
                        'Insights & Smart Actions',
                        style: AppTypography.heading2(isDark: isDark),
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      if (result.insights.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
                          child: Center(
                            child: Text(
                              'Not enough daily logs to generate insights.',
                              style: AppTypography.caption(isDark: isDark),
                            ),
                          ),
                        )
                      else
                        ...result.insights.map((insight) => _buildInsightTile(insight, isDark)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => GlassmorphicContainer(
                  child: Text(
                    'Error loading goals: $error',
                    style: const TextStyle(color: AppColors.stateError),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => GlassmorphicContainer(
              child: Text(
                'Error loading nutrition logs: $error',
                style: const TextStyle(color: AppColors.stateError),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard(IntelligenceResult result, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Summary', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryCol('Avg Calories', '${result.avgCalories.toStringAsFixed(0)} kcal', isDark ? AppColors.primary400 : AppColors.primary500),
              _buildSummaryCol('Logged Days', '${result.loggedDaysCount} / 7 days', Colors.orangeAccent),
              _buildSummaryCol('Consistency', '${result.consistencyScore.toStringAsFixed(0)}%', AppColors.accentProtein),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
        ),
      ],
    );
  }

  Widget _buildTrendsCard(List<MetricTrend> trends, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trends (Last 3 days vs Prev 4)', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceMd),
          ...trends.map((t) => _buildTrendRow(t, isDark)),
        ],
      ),
    );
  }

  Widget _buildTrendRow(MetricTrend trend, bool isDark) {
    IconData icon;
    Color color;
    String status;

    switch (trend.direction) {
      case TrendDirection.improving:
        icon = Icons.trending_up_rounded;
        color = Colors.greenAccent;
        status = 'Improving towards target';
        break;
      case TrendDirection.declining:
        icon = Icons.trending_down_rounded;
        color = Colors.redAccent;
        status = 'Moving away from target';
        break;
      case TrendDirection.stable:
        icon = Icons.trending_flat_rounded;
        color = Colors.grey;
        status = 'Stable';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(trend.metricName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Row(
            children: [
              Text(
                '${trend.changePercentage.toStringAsFixed(0)}%  ·  $status',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: color, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTile(IntelligenceInsight insight, bool isDark) {
    final color = insight.isPositive ? AppColors.primary500 : Colors.orangeAccent;
    final icon = insight.isPositive ? Icons.check_circle_outline_rounded : Icons.lightbulb_outline_rounded;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              insight.description,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Action: ${insight.action}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? color : color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
