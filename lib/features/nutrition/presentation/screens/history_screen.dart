import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../domain/utils/analytics_aggregator.dart';
import '../providers/nutrition_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedDaysRange = 7; // Default to last 7 days

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Analytics'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Range Filter Selector
              _buildRangeFilterSelector(isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Fetch logs and calculate stats
              nutritionAsync.when(
                data: (records) {
                  if (records.isEmpty) {
                    return GlassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
                        child: Column(
                          children: [
                            const Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.darkTextMuted),
                            const SizedBox(height: AppConstants.spaceSm),
                            Text('No logging records found.', style: AppTypography.bodyMedium(isDark: isDark)),
                            Text('Log meals to populate analytics.', style: AppTypography.caption(isDark: isDark)),
                          ],
                        ),
                      ),
                    );
                  }

                  final dailyLogs = AnalyticsAggregator.aggregateByDay(records, daysCount: _selectedDaysRange);

                  return goalsAsync.when(
                    data: (goals) {
                      final summary = AnalyticsAggregator.getHistorySummary(dailyLogs, goals);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Chart
                          _buildChartSection(dailyLogs, isDark),
                          const SizedBox(height: AppConstants.spaceMd),

                          // 2. Goal vs Actual Compare Card
                          _buildComparisonCard(summary, goals, isDark),
                          const SizedBox(height: AppConstants.spaceMd),

                          // 3. Insights
                          _buildInsightsCard(summary.insights, isDark),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => GlassmorphicContainer(
                      child: Text('Error loading goals: $err', style: const TextStyle(color: AppColors.stateError)),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => GlassmorphicContainer(
                  child: Text('Error loading history: $err', style: const TextStyle(color: AppColors.stateError)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeFilterSelector(bool isDark) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment<int>(value: 1, label: Text('Today')),
        ButtonSegment<int>(value: 7, label: Text('7 Days')),
        ButtonSegment<int>(value: 30, label: Text('30 Days')),
      ],
      selected: {_selectedDaysRange},
      onSelectionChanged: (set) {
        setState(() {
          _selectedDaysRange = set.first;
        });
      },
    );
  }

  Widget _buildChartSection(List<DailyAggregate> dailyLogs, bool isDark) {
    final limit = dailyLogs.length;
    final List<BarChartGroupData> barGroups = [];

    double maxVal = 1000;
    for (int i = 0; i < limit; i++) {
      final value = dailyLogs[i].totalCalories;
      if (value > maxVal) maxVal = value;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: isDark ? AppColors.primary400 : AppColors.primary500,
              width: _selectedDaysRange == 30 ? 6 : 14,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calorie Intake History', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceLg),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: _selectedDaysRange < 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= limit) return const SizedBox.shrink();
                        final date = dailyLogs[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            DateFormat('dd').format(date),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(HistorySummary summary, NutritionGoalsEntity? goals, bool isDark) {
    final calorieGoal = goals?.dailyCalorieTarget ?? 2000;
    final proteinGoal = goals?.proteinTargetGrams ?? 150.0;
    final carbsGoal = goals?.carbsTargetGrams ?? 200.0;
    final fatGoal = goals?.fatTargetGrams ?? 65.0;

    final double diffCal = summary.avgCalories - calorieGoal;
    final double diffPro = summary.avgProtein - proteinGoal;
    final double diffCarb = summary.avgCarbs - carbsGoal;
    final double diffFat = summary.avgFats - fatGoal;

    final double pctCal = calorieGoal > 0 ? (summary.avgCalories / calorieGoal) * 100 : 0.0;
    final double pctPro = proteinGoal > 0 ? (summary.avgProtein / proteinGoal) * 100 : 0.0;
    final double pctCarb = carbsGoal > 0 ? (summary.avgCarbs / carbsGoal) * 100 : 0.0;
    final double pctFat = fatGoal > 0 ? (summary.avgFats / fatGoal) * 100 : 0.0;

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Averages vs Goals targets', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceMd),
          _buildComparisonRow('Calories', summary.avgCalories, calorieGoal.toDouble(), diffCal, pctCal, 'kcal', isDark ? AppColors.primary400 : AppColors.primary500),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow('Protein', summary.avgProtein, proteinGoal, diffPro, pctPro, 'g', AppColors.accentProtein),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow('Carbohydrates', summary.avgCarbs, carbsGoal, diffCarb, pctCarb, 'g', AppColors.accentCarbs),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow('Fats', summary.avgFats, fatGoal, diffFat, pctFat, 'g', AppColors.accentFats),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    double actual,
    double goal,
    double diff,
    double percentage,
    String unit,
    Color color,
  ) {
    final sign = diff > 0 ? '+' : '';
    final colorDiff = diff > 0 ? Colors.redAccent : Colors.greenAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${actual.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achieved: ${percentage.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
            Text(
              'Diff: $sign${diff.toStringAsFixed(0)} $unit',
              style: TextStyle(fontSize: 12, color: colorDiff, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsCard(List<String> insights, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary500),
              const SizedBox(width: AppConstants.spaceSm),
              Text('Smart Insights', style: AppTypography.heading3(isDark: isDark)),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.primary400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
