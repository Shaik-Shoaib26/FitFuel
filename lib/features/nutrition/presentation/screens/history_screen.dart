import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/analytics_aggregator.dart';
import '../providers/nutrition_providers.dart';

/// Premium Nutrition Analytics Screen — Calorie intake history, average vs goal
/// comparisons, and macro insights over time.
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
      appBar: FitFuelAppBar(
        title: const Text('Nutrition Analytics'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
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
                    return const Center(
                      child: FitFuelEmptyState(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'No Nutrition Logs Found',
                        description:
                            'Log meals in your food diary to populate caloric and macronutrient trend analytics.',
                      ),
                    );
                  }

                  final dailyLogs = AnalyticsAggregator.aggregateByDay(
                    records,
                    daysCount: _selectedDaysRange,
                  );

                  return goalsAsync.when(
                    data: (goals) {
                      final summary = AnalyticsAggregator.getHistorySummary(
                          dailyLogs, goals);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 950;

                          final chartSection = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const FitFuelSectionHeader(
                                title: 'Caloric Intake History',
                                subtitle:
                                    'Daily calorie consumption over selected timeframe.',
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              _buildChartSection(dailyLogs, goals, isDark),
                            ],
                          );

                          final comparisonSection = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const FitFuelSectionHeader(
                                title: 'Averages vs Goal Targets',
                                subtitle:
                                    'Truthful daily average intake compared against targets.',
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              _buildComparisonCard(summary, goals, isDark),
                              const SizedBox(height: AppConstants.spaceMd),
                              if (summary.insights.isNotEmpty) ...[
                                const FitFuelSectionHeader(
                                  title: 'Nutrition Insights',
                                  subtitle:
                                      'Observations on your macronutrient balance.',
                                ),
                                const SizedBox(height: AppConstants.spaceSm),
                                _buildInsightsCard(summary.insights, isDark),
                              ],
                            ],
                          );

                          if (isDesktop) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 11, child: chartSection),
                                const SizedBox(width: AppConstants.spaceLg),
                                Expanded(flex: 9, child: comparisonSection),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                chartSection,
                                const SizedBox(height: AppConstants.spaceMd),
                                comparisonSection,
                              ],
                            );
                          }
                        },
                      );
                    },
                    loading: () => const Center(
                      child: FitFuelLoadingState(label: 'Loading goals...'),
                    ),
                    error: (err, _) => FitFuelErrorState(
                      error: err,
                      messageOverride: 'Unable to load nutrition goals.',
                      onRetry: () => ref.refresh(nutritionGoalsStreamProvider),
                    ),
                  );
                },
                loading: () => const Center(
                  child:
                      FitFuelLoadingState(label: 'Loading nutrition history...'),
                ),
                error: (err, _) => FitFuelErrorState(
                  error: err,
                  messageOverride: 'Unable to load nutrition logs.',
                  onRetry: () => ref.refresh(nutritionStreamProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeFilterSelector(bool isDark) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color:
                isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRangeOption(1, 'Today', isDark),
            _buildRangeOption(7, '7 Days', isDark),
            _buildRangeOption(30, '30 Days', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeOption(int days, String label, bool isDark) {
    final isSelected = _selectedDaysRange == days;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDaysRange = days;
        });
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(
      List<DailyAggregate> dailyLogs, NutritionGoalsEntity? goals, bool isDark) {
    final limit = dailyLogs.length;
    final List<BarChartGroupData> barGroups = [];
    final targetCal = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;

    double maxVal = targetCal;
    for (int i = 0; i < limit; i++) {
      final value = dailyLogs[i].totalCalories;
      if (value > maxVal) maxVal = value;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: value > targetCal
                  ? AppColors.calories
                  : AppColors.primary500,
              width: _selectedDaysRange == 30 ? 6 : 14,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: targetCal,
                color: isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.primary500.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      );
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppConstants.spaceSm,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Calories History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Logged',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorderSubtle
                              : AppColors.primary500.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Target (${targetCal.round()} kcal)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: _selectedDaysRange < 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= limit) {
                          return const SizedBox.shrink();
                        }
                        final date = dailyLogs[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            DateFormat('dd').format(date),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildComparisonCard(
      HistorySummary summary, NutritionGoalsEntity? goals, bool isDark) {
    final calorieGoal = goals?.dailyCalorieTarget ?? 2000;
    final proteinGoal = goals?.proteinTargetGrams ?? 150.0;
    final carbsGoal = goals?.carbsTargetGrams ?? 200.0;
    final fatGoal = goals?.fatTargetGrams ?? 65.0;

    final double diffCal = summary.avgCalories - calorieGoal;
    final double diffPro = summary.avgProtein - proteinGoal;
    final double diffCarb = summary.avgCarbs - carbsGoal;
    final double diffFat = summary.avgFats - fatGoal;

    final double pctCal =
        calorieGoal > 0 ? (summary.avgCalories / calorieGoal) * 100 : 0.0;
    final double pctPro =
        proteinGoal > 0 ? (summary.avgProtein / proteinGoal) * 100 : 0.0;
    final double pctCarb =
        carbsGoal > 0 ? (summary.avgCarbs / carbsGoal) * 100 : 0.0;
    final double pctFat =
        fatGoal > 0 ? (summary.avgFats / fatGoal) * 100 : 0.0;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonRow(
            'Calories',
            summary.avgCalories,
            calorieGoal.toDouble(),
            diffCal,
            pctCal,
            'kcal',
            AppColors.primary500,
            isDark,
          ),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow(
            'Protein',
            summary.avgProtein,
            proteinGoal,
            diffPro,
            pctPro,
            'g',
            AppColors.protein,
            isDark,
          ),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow(
            'Carbohydrates',
            summary.avgCarbs,
            carbsGoal,
            diffCarb,
            pctCarb,
            'g',
            AppColors.carbs,
            isDark,
          ),
          const Divider(height: AppConstants.spaceMd),
          _buildComparisonRow(
            'Fats',
            summary.avgFats,
            fatGoal,
            diffFat,
            pctFat,
            'g',
            AppColors.fat,
            isDark,
          ),
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
    bool isDark,
  ) {
    final sign = diff > 0 ? '+' : '';
    final colorDiff = diff > 0 ? AppColors.stateError : AppColors.stateSuccess;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              '${actual.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: AppConstants.spaceSm,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'Achieved: ${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Diff: $sign${diff.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 11,
                color: colorDiff,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (actual / (goal > 0 ? goal : 1.0)).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: isDark
                ? AppColors.darkBorderSubtle
                : color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsCard(List<String> insights, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.primary500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
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
