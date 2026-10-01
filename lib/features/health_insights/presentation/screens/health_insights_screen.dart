import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/health_insights_engine.dart';

/// Premium Personalized Health Insights Screen — Wellness ranking, today's
/// telemetry summary, 7-day trend analysis, and actionable health suggestions.
class HealthInsightsScreen extends ConsumerWidget {
  const HealthInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final healthAsync = ref.watch(healthStreamProvider);
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Personalized Health Insights'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: AdaptivePageLayout(
        child: healthAsync.when(
          data: (healthRecords) {
            return nutritionAsync.when(
              data: (nutritionRecords) {
                final goals = goalsAsync.valueOrNull;

                final todayStr = DateTime.now().toString().split(' ').first;
                final todayHealth =
                    healthRecords.where((r) => r.date == todayStr).firstOrNull;
                final todayNutrition = nutritionRecords.where((r) {
                  return r.consumedAt.toString().split(' ').first == todayStr;
                }).toList();

                // Compute aggregates
                final summary = HealthInsightsEngine.generateTodaySummary(
                  todayNutrition: todayNutrition,
                  todayHealth: todayHealth,
                  goals: goals,
                );

                final trendPoints = HealthInsightsEngine.generate7DayTrend(
                  nutritionHistory: nutritionRecords,
                  healthHistory: healthRecords,
                );

                final insights =
                    HealthInsightsEngine.generateInsights(trendPoints);
                final suggestions =
                    HealthInsightsEngine.generateActionSuggestions(summary);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 950;

                      final leftColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Wellness Score Header card
                          _buildWellnessHeader(summary, isDark),
                          const SizedBox(height: AppConstants.spaceMd),

                          // 2. Today's summary details card
                          const FitFuelSectionHeader(
                            title: "Today's Telemetry",
                            subtitle:
                                'Current metrics for nutrition, water, workouts, and habits.',
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          _buildTodaySummaryCard(summary, isDark),
                          const SizedBox(height: AppConstants.spaceMd),

                          // 3. 7-Day Trend Analysis
                          const FitFuelSectionHeader(
                            title: '7-Day Trend Analysis',
                            subtitle:
                                'Wellness scores calculated over the last 7 days.',
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          _build7DayTrendCard(trendPoints, isDark),
                        ],
                      );

                      final rightColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 4. Personalized Insights
                          if (insights.isNotEmpty) ...[
                            const FitFuelSectionHeader(
                              title: 'Personalized Observations',
                              subtitle:
                                  'Automated observations derived from your 7-day trend.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            _buildInsightsSection(insights, isDark),
                            const SizedBox(height: AppConstants.spaceMd),
                          ],

                          // 5. Daily Suggestions
                          if (suggestions.isNotEmpty) ...[
                            const FitFuelSectionHeader(
                              title: 'Daily Suggested Actions',
                              subtitle:
                                  'Healthy actions to raise your wellness index today.',
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            _buildSuggestionsSection(suggestions, isDark),
                            const SizedBox(height: AppConstants.spaceMd),
                          ],

                          // Disclaimer
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppConstants.spaceSm),
                              child: Text(
                                '*Disclaimer: Rule-based health suggestions are approximate. Seek professional certified medical advice for medical decisions.*',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
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
                child: FitFuelLoadingState(label: 'Loading nutrition logs...'),
              ),
              error: (err, _) => FitFuelErrorState(
                error: err,
                messageOverride: 'Error loading nutrition logs.',
                onRetry: () => ref.refresh(nutritionStreamProvider),
              ),
            );
          },
          loading: () => const Center(
            child: FitFuelLoadingState(label: 'Loading health telemetry...'),
          ),
          error: (err, _) => FitFuelErrorState(
            error: err,
            messageOverride: 'Error loading health logs.',
            onRetry: () => ref.refresh(healthStreamProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildWellnessHeader(DailyHealthSummary summary, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: (summary.wellnessScore / 100.0).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: isDark
                      ? AppColors.darkBorderSubtle
                      : AppColors.primary500.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary500),
                ),
              ),
              Text(
                summary.wellnessScore.toStringAsFixed(0),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Wellness Index",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Calculates multi-dimensional consistency across hydration, workout duration, habits, and caloric balance.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummaryCard(DailyHealthSummary summary, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            Icons.restaurant_rounded,
            AppColors.protein,
            'Nutrition',
            '${summary.calories.toStringAsFixed(0)} kcal consumed',
            isDark,
          ),
          const Divider(height: 12),
          _buildSummaryRow(
            Icons.water_drop_rounded,
            AppColors.hydration,
            'Hydration',
            '${summary.waterIntakeMl.toStringAsFixed(0)} / ${summary.waterTargetMl.toStringAsFixed(0)} ml',
            isDark,
          ),
          const Divider(height: 12),
          _buildSummaryRow(
            Icons.fitness_center_rounded,
            AppColors.calories,
            'Workout',
            '${summary.exerciseDurationMinutes} minutes logged',
            isDark,
          ),
          const Divider(height: 12),
          _buildSummaryRow(
            Icons.check_circle_outline_rounded,
            AppColors.primary500,
            'Habits',
            '${summary.completedHabitsCount} / ${summary.totalHabitsCount} completed',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    Color color,
    String title,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build7DayTrendCard(List<WellnessTrendPoint> trendPoints, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trendPoints.map((point) {
              final dateLabel = point.date.length >= 2
                  ? point.date.substring(point.date.length - 2)
                  : point.date;
              final barHeight =
                  (point.wellnessScore / 100.0 * 60.0).clamp(6.0, 60.0);

              return Column(
                children: [
                  Text(
                    point.wellnessScore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight,
                    width: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(List<HealthInsight> insights, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights.map((insight) {
        final cardColor = insight.priority == 'High'
            ? AppColors.stateError
            : insight.priority == 'Medium'
                ? AppColors.calories
                : AppColors.primary500;

        return FitFuelCard(
          margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
          padding: const EdgeInsets.all(AppConstants.spaceSm),
          border: BorderSide(color: cardColor.withValues(alpha: 0.3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      insight.priority.toUpperCase(),
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                insight.message,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuggestionsSection(List<String> suggestions, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: suggestions.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primary500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s,
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
        }).toList(),
      ),
    );
  }
}
