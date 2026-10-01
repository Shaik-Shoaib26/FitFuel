import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../health/presentation/widgets/weight_panel.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/progress_summary_entity.dart';
import '../../domain/utils/progress_calculator.dart';
import '../controllers/progress_controller.dart';

/// Premium Progress Command Center Screen — Tracking weight change, habit streaks,
/// adherence snapshots, and exploration gateways.
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

    // Calculate Summary stats
    final summary = ProgressCalculator.calculateSummary(
      nutritionHistory: nutritionHistory,
      healthHistory: healthHistory,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      daysCount: range,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Progress'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Edit goals',
            onPressed: () => context.push('/settings/goals'),
          ),
        ],
      ),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 950;

              if (isDesktop) {
                // Desktop: Two-column layout with better composition
                final leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page Subtitle
                    Text(
                      'Track your health transformations, habit consistency, and milestones over time.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Time Range Filter Selector
                    _buildTimeRangeSelector(ref, range, isDark),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Weight History & Graph Section
                    WeightPanel(
                      uid: authUser.uid,
                      summary: summary,
                      history: weightHistory,
                      showEntry: false,
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Milestones & Achievements Section
                    _buildAchievementsSection(summary, isDark),
                  ],
                );

                final rightColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Compact Streak Card
                    _buildCompactStreakCard(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Deep Exploration Section
                    const FitFuelSectionHeader(
                      title: 'Deep Exploration',
                      subtitle: 'Detailed analytics, reports, and insights.',
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildFeatureTile(
                      context: context,
                      title: 'Health Analytics',
                      subtitle: 'Interactive charts and trends',
                      icon: Icons.bar_chart_rounded,
                      color: AppColors.primary500,
                      onTap: () => context.go('/progress/analytics'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildFeatureTile(
                      context: context,
                      title: 'Weekly Health Report',
                      subtitle: '7-day review and trends',
                      icon: Icons.summarize_outlined,
                      color: AppColors.calories,
                      onTap: () => context.go('/progress/weekly-report'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildFeatureTile(
                      context: context,
                      title: 'Smart Health Insights',
                      subtitle: 'AI alerts and actions',
                      icon: Icons.lightbulb_outline_rounded,
                      color: AppColors.ai,
                      onTap: () => context.go('/progress/insights'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Habit & Goal Adherence
                    const FitFuelSectionHeader(
                      title: 'Habit & Goal Adherence',
                      subtitle: 'Consistency across all health metrics.',
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildWellnessSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildNutritionSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildHydrationSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildExerciseSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildHabitsSection(summary, isDark),
                  ],
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: leftColumn),
                    const SizedBox(width: AppConstants.spaceLg),
                    Expanded(flex: 9, child: rightColumn),
                  ],
                );
              } else {
                // Mobile: Single column with original order
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page Subtitle
                    Text(
                      'Track your health transformations, habit consistency, and milestones over time.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Time Range Filter Selector
                    _buildTimeRangeSelector(ref, range, isDark),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Compact Streak Card
                    _buildCompactStreakCard(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Deep Exploration
                    const FitFuelSectionHeader(
                      title: 'Deep Exploration',
                      subtitle: 'Detailed analytics, reports, and insights.',
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildNavigationTile(
                      context: context,
                      title: 'Health Analytics',
                      subtitle: 'Interactive charts and multi-metric trend analysis.',
                      icon: Icons.bar_chart_rounded,
                      color: AppColors.primary500,
                      onTap: () => context.go('/progress/analytics'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildNavigationTile(
                      context: context,
                      title: 'Weekly Health Report',
                      subtitle: 'Comprehensive 7-day review and week-over-week performance.',
                      icon: Icons.summarize_outlined,
                      color: AppColors.calories,
                      onTap: () => context.go('/progress/weekly-report'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildNavigationTile(
                      context: context,
                      title: 'Smart Health Insights',
                      subtitle: 'AI priority alerts, daily focus, and recommended actions.',
                      icon: Icons.lightbulb_outline_rounded,
                      color: AppColors.ai,
                      onTap: () => context.go('/progress/insights'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Weight History & Graph Section
                    WeightPanel(
                      uid: authUser.uid,
                      summary: summary,
                      history: weightHistory,
                      showEntry: false,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Milestones & Achievements Section
                    _buildAchievementsSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Habit & Goal Adherence
                    const FitFuelSectionHeader(
                      title: 'Habit & Goal Adherence',
                      subtitle: 'Consistency scores across nutrition, hydration, and workouts.',
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    _buildWellnessSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),
                    _buildNutritionSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),
                    _buildHydrationSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),
                    _buildExerciseSection(summary, isDark),
                    const SizedBox(height: AppConstants.spaceMd),
                    _buildHabitsSection(summary, isDark),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(WidgetRef ref, int activeRange, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [7, 30, 90].map((days) {
          final isSelected = days == activeRange;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(progressControllerProvider.notifier).setRange(days);
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary500
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  '$days Days',
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
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactStreakCard(ProgressSummaryEntity summary, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary500,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.calories,
              size: 22,
            ),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nutrition Streak',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.currentStreak} days',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Max: ${summary.longestStreak}',
            style: const TextStyle(
              color: AppColors.primary500,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return FitFuelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
               ],
             ),
           ),
           Icon(
             Icons.chevron_right_rounded,
             size: 16,
             color: isDark
                 ? AppColors.darkTextSecondary
                 : AppColors.lightTextSecondary,
           ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return FitFuelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildWellnessSection(ProgressSummaryEntity summary, bool isDark) {
    final Color trendColor;
    final IconData trendIcon;
    switch (summary.wellnessTrend.toLowerCase()) {
      case 'improving':
        trendColor = AppColors.stateSuccess;
        trendIcon = Icons.trending_up_rounded;
        break;
      case 'declining':
        trendColor = AppColors.stateError;
        trendIcon = Icons.trending_down_rounded;
        break;
      case 'stable':
      default:
        trendColor = AppColors.primary500;
        trendIcon = Icons.trending_flat_rounded;
        break;
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
                'Wellness Rating Trend',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, color: trendColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      summary.wellnessTrend,
                      style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Average Wellness',
                  '${summary.wellnessAvgScore.toStringAsFixed(0)}/100',
                  AppColors.calories,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Best Score',
                  '${summary.wellnessBestScore.toStringAsFixed(0)}/100',
                  AppColors.stateSuccess,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Lowest Score',
                  '${summary.wellnessLowestScore.toStringAsFixed(0)}/100',
                  AppColors.stateError,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.nutritionDaysLogged == 0) {
      return const FitFuelCard(
        padding: EdgeInsets.all(AppConstants.spaceMd),
        child: Text(
          'No nutrition data yet.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutrition Goal Adherence',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          _buildProgressBar('Calories Adherence', summary.avgCalories,
              summary.calorieTarget, 'kcal', AppColors.primary500, isDark),
          const SizedBox(height: AppConstants.spaceSm),
          _buildProgressBar('Protein Consistency', summary.avgProtein,
              summary.proteinTarget, 'g', AppColors.protein, isDark),
          const SizedBox(height: AppConstants.spaceSm),
          _buildProgressBar('Carbohydrates', summary.avgCarbs,
              summary.carbsTarget, 'g', AppColors.carbs, isDark),
          const SizedBox(height: AppConstants.spaceSm),
          _buildProgressBar('Fat', summary.avgFats, summary.fatsTarget, 'g',
              AppColors.fat, isDark),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Days Logged',
                  '${summary.nutritionDaysLogged}',
                  AppColors.primary500,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Days Missed',
                  '${summary.nutritionDaysMissed}',
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Calorie Consistency',
                  '${summary.calorieConsistencyPercent.toStringAsFixed(0)}%',
                  AppColors.protein,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.waterDaysMet == 0 && summary.avgWater == 0.0) {
      return const FitFuelCard(
        padding: EdgeInsets.all(AppConstants.spaceMd),
        child: Text(
          'No hydration data yet.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hydration Progress',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          _buildProgressBar('Daily Water Intake', summary.avgWater,
              summary.waterTarget, 'ml', AppColors.hydration, isDark),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Avg Daily Water',
                  '${summary.avgWater.toStringAsFixed(0)} ml',
                  AppColors.hydration,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Target Reached',
                  '${summary.waterDaysMet} days',
                  AppColors.stateSuccess,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Consistency',
                  '${summary.waterConsistencyPercent.toStringAsFixed(0)}%',
                  AppColors.hydration,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.exerciseActiveDays == 0) {
      return const FitFuelCard(
        padding: EdgeInsets.all(AppConstants.spaceMd),
        child: Text(
          'No workouts logged yet.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout & Exercise Consistency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Active Days',
                  '${summary.exerciseActiveDays}',
                  AppColors.calories,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Total Workout Mins',
                  '${summary.exerciseTotalMinutes} min',
                  AppColors.carbs,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Calories Burned',
                  '${summary.exerciseTotalCaloriesBurned.toStringAsFixed(0)} kcal',
                  AppColors.fat,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Avg Duration',
                  '${summary.exerciseAvgDuration.toStringAsFixed(1)} min',
                  AppColors.calories,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Workout Frequency',
                  '${summary.exerciseConsistencyPercent.toStringAsFixed(0)}%',
                  AppColors.protein,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.habitsSuccessfulDays == 0 &&
        summary.habitsAvgCompletionRate == 0.0) {
      return const FitFuelCard(
        padding: EdgeInsets.all(AppConstants.spaceMd),
        child: Text(
          'No habits checklist items yet.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Habit Consistency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Avg Completion Rate',
                  '${summary.habitsAvgCompletionRate.toStringAsFixed(0)}%',
                  AppColors.stateSuccess,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Successful Days',
                  '${summary.habitsSuccessfulDays} days',
                  AppColors.stateSuccess,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Habit Consistency',
                  '${summary.habitsConsistencyPercent.toStringAsFixed(0)}%',
                  AppColors.protein,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Most Consistent Habit',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      summary.habitsMostConsistent,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.stateSuccess,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Least Consistent Habit',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      summary.habitsLeastConsistent,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.stateError,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildAchievementsSection(ProgressSummaryEntity summary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FitFuelSectionHeader(
          title: 'Milestones & Achievements',
          subtitle: 'Badges and fitness targets unlocked on your journey.',
        ),
        const SizedBox(height: AppConstants.spaceSm),
        ...summary.milestones.map((ms) {
          return FitFuelCard(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            border: BorderSide(
              color: ms.isUnlocked
                  ? AppColors.achievement.withValues(alpha: 0.4)
                  : (isDark
                      ? AppColors.darkBorderSubtle
                      : AppColors.lightBorderSubtle),
              width: ms.isUnlocked ? 1.5 : 1,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ms.isUnlocked
                        ? AppColors.achievement.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.darkBgSurface
                            : AppColors.lightBgSurface),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ms.isUnlocked
                        ? Icons.emoji_events_rounded
                        : Icons.lock_outline_rounded,
                    color: ms.isUnlocked
                        ? AppColors.achievement
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ms.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: ms.isUnlocked
                                    ? (isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary)
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ms.isUnlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.achievement
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'UNLOCKED',
                                style: TextStyle(
                                  color: AppColors.achievement,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ms.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ms.progressPercent.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: isDark
                                    ? AppColors.darkBorderSubtle
                                    : AppColors.lightBorderSubtle,
                                color: ms.isUnlocked
                                    ? AppColors.achievement
                                    : AppColors.primary500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceMd),
                          Text(
                            ms.progressText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: ms.isUnlocked
                                  ? AppColors.achievement
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgressBar(
    String title,
    double current,
    double target,
    String unit,
    Color barColor,
    bool isDark,
  ) {
    final double fraction =
        target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final percent = target > 0 ? (current / target) * 100.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppConstants.spaceSm,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit (${percent.toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: isDark
                ? AppColors.darkBorderSubtle
                : barColor.withValues(alpha: 0.12),
            color: barColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color valueColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
