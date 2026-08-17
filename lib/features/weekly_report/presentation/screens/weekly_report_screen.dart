import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../controllers/weekly_report_controller.dart';
import '../../domain/utils/weekly_report_calculator.dart';
import '../../domain/entities/weekly_report_entity.dart';

class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateStreamProvider).value;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication required.')),
      );
    }

    // Force streams to stay alive/watched
    final nutritionHistory = ref.watch(nutritionStreamProvider).value ?? [];
    final healthHistory = ref.watch(healthStreamProvider).value ?? [];
    final weightHistory = ref.watch(weightHistoryStreamProvider).value ?? [];
    final goals = ref.watch(nutritionGoalsStreamProvider).value;
    final profile = ref.watch(currentProfileStreamProvider).value;

    final reportState = ref.watch(weeklyReportControllerProvider);
    final viewMode = reportState.selectedView; // 'completed' | 'previous' | 'preview'

    // Calculate current report based on selection
    final currentReport = WeeklyReportCalculator.calculateReport(
      nutritionHistory: nutritionHistory,
      healthHistory: healthHistory,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      period: viewMode,
    );

    // Get comparison report
    final String compPeriod = viewMode == 'preview' ? 'completed' : 'previous';
    final comparisonReport = WeeklyReportCalculator.calculateReport(
      nutritionHistory: nutritionHistory,
      healthHistory: healthHistory,
      weightHistory: weightHistory,
      goals: goals,
      profile: profile,
      period: compPeriod,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if the user has logged anything at all to prevent empty screens
    final bool hasData = currentReport.nutritionDaysLogged > 0 ||
        currentReport.avgWater > 0 ||
        currentReport.exerciseActiveDays > 0 ||
        currentReport.habitsSuccessfulDays > 0 ||
        currentReport.wellnessAvgScore > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: AppBar(
        title: const Text('Weekly Health Report'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segment view mode selector
            _buildViewSelector(ref, viewMode, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            if (!hasData) ...[
              _buildEmptyStateCard(isDark),
            ] else ...[
              // Weekly Health Score Header Card
              _buildHeaderCard(currentReport, comparisonReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Week-over-Week Comparison Panel
              _buildWowComparisonPanel(currentReport, comparisonReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Strongest and Weakest Areas
              _buildStrengthsAndWeaknesses(currentReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Expanding Category Reports
              _buildCategoryDetails(currentReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Weekly Insights Panel
              _buildInsightsPanel(currentReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Action plan for next week
              _buildActionPlanPanel(currentReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // Milestones unlocked this week
              _buildMilestonesPanel(currentReport, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              // AI Coach prompt chips
              _buildAiCoachPanel(context, isDark),
              const SizedBox(height: AppConstants.spaceXl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewSelector(WidgetRef ref, String activeView, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBorderSubtle,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSelectorTab(ref, 'completed', 'Completed Week', activeView == 'completed', isDark),
          _buildSelectorTab(ref, 'preview', 'Current Week Preview', activeView == 'preview', isDark),
          _buildSelectorTab(ref, 'previous', 'Previous Week', activeView == 'previous', isDark),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(WidgetRef ref, String viewKey, String label, bool isSelected, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(weeklyReportControllerProvider.notifier).setView(viewKey);
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary500 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          children: [
            const Icon(Icons.insights_rounded, size: 64, color: AppColors.stateWarning),
            const SizedBox(height: AppConstants.spaceMd),
            const Text(
              'Keep logging to unlock your weekly health report.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Once you log meals, hydration targets, and wellness metrics, your personalized Smart Report will calculate your health score and trends.',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(WeeklyReportEntity current, WeeklyReportEntity previous, bool isDark) {
    final double scoreDiff = current.healthScore - previous.healthScore;
    final String trendText;
    final Color trendColor;
    final IconData trendIcon;

    if (previous.healthScore == 0.0) {
      trendText = 'Not enough previous data for comparison';
      trendColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      trendIcon = Icons.remove;
    } else if (scoreDiff > 0.0) {
      trendText = '${scoreDiff.toStringAsFixed(1)} points from last week';
      trendColor = AppColors.stateSuccess;
      trendIcon = Icons.trending_up_rounded;
    } else if (scoreDiff < 0.0) {
      trendText = '${scoreDiff.abs().toStringAsFixed(1)} points from last week';
      trendColor = AppColors.stateError;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendText = 'Stable from last week';
      trendColor = AppColors.primary500;
      trendIcon = Icons.trending_flat_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkBgSurface, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.darkBorderSubtle),
      ),
      child: Column(
        children: [
          const Text(
            'Your Week in FitFuel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Health Score Circle
              Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary500, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          current.healthScore.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          '/100',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Health Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              // Streaks & Achievements Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Streak: ${current.nutritionStreak} days',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Achievements: ${current.unlockedMilestones.length} unlocked',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(trendIcon, color: trendColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        trendText,
                        style: TextStyle(color: trendColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWowComparisonPanel(WeeklyReportEntity current, WeeklyReportEntity previous, bool isDark) {
    String getWoWSymbol(double curr, double prev) {
      if (prev == 0.0) return '—';
      if (curr > prev) return '↑ Improved';
      if (curr < prev) return '↓ Declined';
      return '→ Stable';
    }

    Color getWoWColor(double curr, double prev, {bool lowerIsBetter = false}) {
      if (prev == 0.0) return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      if (curr == prev) return AppColors.primary500;
      return (curr > prev)
          ? (lowerIsBetter ? AppColors.stateError : AppColors.stateSuccess)
          : (lowerIsBetter ? AppColors.stateSuccess : AppColors.stateError);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Week-over-Week Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            _buildWowRow('Health Score', '${current.healthScore}', '${previous.healthScore}', getWoWSymbol(current.healthScore, previous.healthScore), getWoWColor(current.healthScore, previous.healthScore)),
            _buildWowRow('Avg Calories', '${current.avgCalories.toStringAsFixed(0)} kcal', '${previous.avgCalories.toStringAsFixed(0)} kcal', getWoWSymbol(current.avgCalories, previous.avgCalories), getWoWColor(current.avgCalories, previous.avgCalories)),
            _buildWowRow('Avg Protein', '${current.avgProtein.toStringAsFixed(1)} g', '${previous.avgProtein.toStringAsFixed(1)} g', getWoWSymbol(current.avgProtein, previous.avgProtein), getWoWColor(current.avgProtein, previous.avgProtein)),
            _buildWowRow('Hydration', '${current.avgWater.toStringAsFixed(0)} ml', '${previous.avgWater.toStringAsFixed(0)} ml', getWoWSymbol(current.avgWater, previous.avgWater), getWoWColor(current.avgWater, previous.avgWater)),
            _buildWowRow('Workout Mins', '${current.exerciseTotalMinutes} min', '${previous.exerciseTotalMinutes} min', getWoWSymbol(current.exerciseTotalMinutes.toDouble(), previous.exerciseTotalMinutes.toDouble()), getWoWColor(current.exerciseTotalMinutes.toDouble(), previous.exerciseTotalMinutes.toDouble())),
            _buildWowRow('Habits Completion', '${current.habitsAvgCompletionPercent.toStringAsFixed(0)}%', '${previous.habitsAvgCompletionPercent.toStringAsFixed(0)}%', getWoWSymbol(current.habitsAvgCompletionPercent, previous.habitsAvgCompletionPercent), getWoWColor(current.habitsAvgCompletionPercent, previous.habitsAvgCompletionPercent)),
            _buildWowRow('Wellness Score', current.wellnessAvgScore.toStringAsFixed(0), previous.wellnessAvgScore.toStringAsFixed(0), getWoWSymbol(current.wellnessAvgScore, previous.wellnessAvgScore), getWoWColor(current.wellnessAvgScore, previous.wellnessAvgScore)),
            _buildWowRow('Weight Logged', '${current.currentWeight.toStringAsFixed(1)} kg', '${previous.currentWeight.toStringAsFixed(1)} kg', getWoWSymbol(current.currentWeight, previous.currentWeight), AppColors.primary500),
          ],
        ),
      ),
    );
  }

  Widget _buildWowRow(String label, String currVal, String prevVal, String indicator, Color trendColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text('$currVal vs $prevVal', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(
                width: 80,
                alignment: Alignment.centerRight,
                child: Text(
                  indicator,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: trendColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsAndWeaknesses(WeeklyReportEntity report, bool isDark) {
    return Column(
      children: [
        if (report.strongestArea != 'N/A')
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.stateSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.stateSuccess.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.thumb_up_alt_rounded, color: AppColors.stateSuccess, size: 24),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strongest Health Area: ${report.strongestArea}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.stateSuccess),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.strongestAreaDescription,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppConstants.spaceMd),
        if (report.weakestArea != 'N/A')
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.stateWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.stateWarning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.stateWarning, size: 24),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area to Improve: ${report.weakestArea}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.stateWarning),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.weakestAreaDescription,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coach Suggestion: ${report.weakestAreaSuggestion}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryDetails(WeeklyReportEntity report, bool isDark) {
    return Column(
      children: [
        _buildCategoryCard(
          'Nutrition Report',
          Icons.restaurant_rounded,
          AppColors.accentProtein,
          [
            'Average Daily Calories: ${report.avgCalories.toStringAsFixed(0)} kcal',
            'Calorie Target Adherence: ${report.calorieAdherencePercent.toStringAsFixed(0)}%',
            'Average Protein: ${report.avgProtein.toStringAsFixed(1)} g',
            'Protein Target Adherence: ${report.proteinAdherencePercent.toStringAsFixed(0)}%',
            'Averages: Carbs ${report.avgCarbs.toStringAsFixed(1)}g | Fats ${report.avgFats.toStringAsFixed(1)}g',
            'Logging Days: ${report.nutritionDaysLogged} / 7 days',
            'Nutrition Status: ${report.nutritionStatus}',
          ],
          isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildCategoryCard(
          'Hydration Report',
          Icons.water_drop_rounded,
          Colors.blue,
          [
            'Average Water Intake: ${report.avgWater.toStringAsFixed(0)} ml',
            'Water Intake Target: ${report.waterTarget.toStringAsFixed(0)} ml',
            'Hydration Adherence: ${report.hydrationAdherencePercent.toStringAsFixed(0)}%',
            'Target Achieved: ${report.waterDaysMet} / 7 days',
            'Hydration Status: ${report.hydrationStatus}',
          ],
          isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildCategoryCard(
          'Exercise Report',
          Icons.fitness_center_rounded,
          Colors.red,
          [
            'Active Days: ${report.exerciseActiveDays} / 7 days',
            'Total Workout Minutes: ${report.exerciseTotalMinutes} min',
            'Average Session Duration: ${report.exerciseAvgDuration.toStringAsFixed(1)} min',
            'Total Calories Burned: ${report.exerciseCaloriesBurned.toStringAsFixed(0)} kcal',
            'Workout Consistency: ${report.exerciseConsistencyPercent.toStringAsFixed(0)}%',
          ],
          isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildCategoryCard(
          'Habits Report',
          Icons.check_box_outlined,
          Colors.green,
          [
            'Averages Completion Rate: ${report.habitsAvgCompletionPercent.toStringAsFixed(0)}%',
            'Successful Habit Days (>=80%): ${report.habitsSuccessfulDays} days',
            'Best Completed Habit: ${report.habitsBestName}',
            'Habit Needing Most Attention: ${report.habitsAttentionName}',
            'Habit Consistency: ${report.habitsConsistencyPercent.toStringAsFixed(0)}%',
          ],
          isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildCategoryCard(
          'Wellness Report',
          Icons.favorite_rounded,
          Colors.orange,
          [
            'Average Wellness Rating: ${report.wellnessAvgScore.toStringAsFixed(0)}/100',
            'Best Wellness Rating: ${report.wellnessBestScore.toStringAsFixed(0)}/100',
            'Lowest Wellness Rating: ${report.wellnessLowestScore.toStringAsFixed(0)}/100',
            'Wellness Trend: ${report.wellnessTrend}',
          ],
          isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildCategoryCard(
          'Weight Report',
          Icons.scale_rounded,
          Colors.teal,
          [
            'Starting Weight: ${report.startingWeight.toStringAsFixed(1)} kg',
            'Current Weight: ${report.currentWeight.toStringAsFixed(1)} kg',
            'Weekly Weight Change: ${report.weightChange > 0 ? '+' : ''}${report.weightChange.toStringAsFixed(1)} kg (${report.weightChangePercent > 0 ? '+' : ''}${report.weightChangePercent.toStringAsFixed(1)}%)',
            'Fitness Goal Direction: ${report.weightGoalDirection}',
          ],
          isDark,
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, List<String> details, bool isDark) {
    return ExpansionTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.map((detail) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsPanel(WeeklyReportEntity report, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            if (report.insights.isEmpty)
              const Text('No insights generated for this period.', style: TextStyle(fontStyle: FontStyle.italic))
            else
              ...report.insights.map((ins) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.stateWarning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ins,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPlanPanel(WeeklyReportEntity report, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Next Week Action Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Actions focused on improving your weakest category (${report.weakestArea}):',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: AppConstants.spaceMd),
            ...report.actionPlan.map((action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outline_blank_rounded, color: AppColors.primary500, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesPanel(WeeklyReportEntity report, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Achievements Highlight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            if (report.unlockedMilestones.isEmpty)
              const Text('No milestones unlocked this week.', style: TextStyle(fontStyle: FontStyle.italic))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: report.unlockedMilestones.map((ms) {
                  return Chip(
                    avatar: const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                    label: Text(ms, style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.primary500.withValues(alpha: 0.15),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCoachPanel(BuildContext context, bool isDark) {
    final chips = [
      'How was my week?',
      'What did I do well?',
      'What should I improve?',
      'Why did my score change?',
      'Plan my next week',
    ];

    return Card(
      elevation: 2,
      color: isDark ? AppColors.darkBgSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology_rounded, color: AppColors.primary500, size: 24),
                SizedBox(width: 8),
                Text('AI Health Coach', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Select a prompt to ask Gemini for personalized health coaching:',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppConstants.spaceMd),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((prompt) {
                return GestureDetector(
                  onTap: () {
                    // Navigate to AI Assistant with prefilled prompt query parameter
                    context.push('/ai-assistant?prompt=${Uri.encodeComponent(prompt)}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.primary500.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: Text(
                      prompt,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary500),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
