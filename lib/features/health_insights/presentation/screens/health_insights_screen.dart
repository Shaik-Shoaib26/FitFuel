import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/utils/health_insights_engine.dart';

class HealthInsightsScreen extends ConsumerWidget {
  const HealthInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthAsync = ref.watch(healthStreamProvider);
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalized Health Insights'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: healthAsync.when(
          data: (healthRecords) {
            return nutritionAsync.when(
              data: (nutritionRecords) {
                final goals = goalsAsync.value;

                final todayStr = DateTime.now().toString().split(' ').first;
                final todayHealth = healthRecords.where((r) => r.date == todayStr).firstOrNull;
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

                final insights = HealthInsightsEngine.generateInsights(trendPoints);
                final suggestions = HealthInsightsEngine.generateActionSuggestions(summary);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Wellness Score Header card
                      _buildWellnessHeader(summary, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 2. Today's summary details card
                      _buildTodaySummaryCard(summary, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 3. 7-Day Trend Analysis
                      _build7DayTrendCard(trendPoints, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 4. Personalized Insights
                      _buildInsightsSection(insights, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 5. Daily Suggestions
                      _buildSuggestionsSection(suggestions, isDark),
                      const SizedBox(height: AppConstants.spaceLg),

                      // Disclaimer
                      Center(
                        child: Text(
                          '*Disclaimer: Rule-based health suggestions are approximate. Seek professional certified advice.*',
                          style: AppTypography.caption(isDark: isDark),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildErrorState('Error loading nutrition logs: $err'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _buildErrorState('Error loading health logs: $err'),
        ),
      ),
    );
  }

  Widget _buildWellnessHeader(DailyHealthSummary summary, bool isDark) {
    return GlassmorphicContainer(
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 65,
                height: 65,
                child: CircularProgressIndicator(
                  value: summary.wellnessScore / 100.0,
                  strokeWidth: 7,
                  backgroundColor: AppColors.darkTextMuted.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary500),
                ),
              ),
              Text(
                summary.wellnessScore.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Wellness Rank',
                  style: AppTypography.heading3(isDark: isDark),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Calculates metrics across hydration, exercises, habits completion, and daily logged meals.',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummaryCard(DailyHealthSummary summary, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s Summary', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceSm),
          _buildSummaryRow(Icons.local_fire_department_rounded, Colors.redAccent, 'Nutrition', '${summary.calories.toStringAsFixed(0)} kcal consumed'),
          _buildSummaryRow(Icons.water_drop_rounded, Colors.blueAccent, 'Hydration', '${summary.waterIntakeMl.toStringAsFixed(0)} / ${summary.waterTargetMl.toStringAsFixed(0)} ml'),
          _buildSummaryRow(Icons.directions_run_rounded, Colors.orangeAccent, 'Workout', '${summary.exerciseDurationMinutes} minutes logged'),
          _buildSummaryRow(Icons.check_box_rounded, AppColors.accentProtein, 'Habits', '${summary.completedHabitsCount} / ${summary.totalHabitsCount} completed'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, Color color, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _build7DayTrendCard(List<WellnessTrendPoint> trendPoints, bool isDark) {
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-Day Trend Analysis', style: AppTypography.heading3(isDark: isDark)),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trendPoints.map((point) {
              final dateLabel = point.date.substring(point.date.length - 2);
              return Column(
                children: [
                  Container(
                    height: (point.wellnessScore / 100.0 * 60.0).clamp(5.0, 60.0),
                    width: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(dateLabel, style: const TextStyle(fontSize: 9, color: AppColors.darkTextMuted)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          const Center(
            child: Text(
              'Wellness scores over last 7 days',
              style: TextStyle(fontSize: 9, color: AppColors.darkTextMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(List<HealthInsight> insights, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personalized Insights', style: AppTypography.heading3(isDark: isDark)),
        const SizedBox(height: AppConstants.spaceSm),
        if (insights.isEmpty)
          const GlassmorphicContainer(
            child: Text('No insights generated for your current trend data.', style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
          )
        else
          ...insights.map((insight) {
            final cardColor = insight.priority == 'High'
                ? Colors.redAccent.withValues(alpha: 0.1)
                : insight.priority == 'Medium'
                    ? Colors.orangeAccent.withValues(alpha: 0.1)
                    : Colors.blueAccent.withValues(alpha: 0.1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassmorphicContainer(
                child: Container(
                  color: cardColor,
                  padding: const EdgeInsets.all(AppConstants.spaceSm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insight.message,
                        style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSuggestionsSection(List<String> suggestions, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Actions', style: AppTypography.heading3(isDark: isDark)),
        const SizedBox(height: AppConstants.spaceSm),
        GlassmorphicContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: suggestions.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded, color: AppColors.primary500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String msg) {
    return GlassmorphicContainer(
      child: Text(msg, style: const TextStyle(color: AppColors.stateError)),
    );
  }
}
