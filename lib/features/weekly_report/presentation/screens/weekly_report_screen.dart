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
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../domain/entities/weekly_report_entity.dart';
import '../../domain/utils/weekly_report_calculator.dart';
import '../controllers/weekly_report_controller.dart';

/// Premium Weekly Health Report Screen — Holistic 7-day review, week-over-week
/// comparison, category breakdowns, action plan, and AI health coaching.
class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool hasData = currentReport.nutritionDaysLogged > 0 ||
        currentReport.avgWater > 0 ||
        currentReport.exerciseActiveDays > 0 ||
        currentReport.habitsSuccessfulDays > 0 ||
        currentReport.wellnessAvgScore > 0;

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Weekly Health Report'),
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
              // Segment view mode selector
              _buildViewSelector(ref, viewMode, isDark),
              const SizedBox(height: AppConstants.spaceMd),

              if (!hasData) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: FitFuelCard(
                      padding: const EdgeInsets.all(AppConstants.spaceLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: Icon(
                              Icons.summarize_outlined,
                              size: 32,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceMd),
                          Text(
                            'Keep Logging to Unlock Your Report',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          Text(
                            'Your personalized weekly report will calculate your health score and trends once you log meals, hydration, workouts, and habits.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 950;

                    final leftColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Weekly Health Score Header Card
                        _buildHeaderCard(currentReport, comparisonReport, isDark),
                        const SizedBox(height: AppConstants.spaceMd),

                        // Week-over-Week Comparison Panel
                        const FitFuelSectionHeader(
                          title: 'Week-over-Week Comparison',
                          subtitle:
                              'Truthful metric changes compared to previous cycle.',
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        _buildWowComparisonPanel(
                            currentReport, comparisonReport, isDark),
                        const SizedBox(height: AppConstants.spaceMd),

                        // Strongest and Weakest Areas
                        const FitFuelSectionHeader(
                          title: 'Highlights & Coaching Focus',
                          subtitle:
                              'Recognizing wins and targeted areas for improvement.',
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        _buildStrengthsAndWeaknesses(currentReport, isDark),
                        const SizedBox(height: AppConstants.spaceMd),

                        // AI Coach prompt chips
                        _buildAiCoachPanel(context, isDark),
                      ],
                    );

                    final rightColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Expanding Category Reports
                        const FitFuelSectionHeader(
                          title: 'Category Performance',
                          subtitle:
                              'Tap any category to expand detailed breakdown.',
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        _buildCategoryDetails(currentReport, isDark),
                        const SizedBox(height: AppConstants.spaceMd),

                        // Weekly Insights Panel
                        if (currentReport.insights.isNotEmpty) ...[
                          const FitFuelSectionHeader(
                            title: 'Weekly Insights',
                            subtitle:
                                'Automated observations from your weekly log.',
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          _buildInsightsPanel(currentReport, isDark),
                          const SizedBox(height: AppConstants.spaceMd),
                        ],

                        // Action plan for next week
                        if (currentReport.actionPlan.isNotEmpty) ...[
                          const FitFuelSectionHeader(
                            title: 'Next Week Action Plan',
                            subtitle:
                                'Actions designed to strengthen your focus areas.',
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          _buildActionPlanPanel(currentReport, isDark),
                          const SizedBox(height: AppConstants.spaceMd),
                        ],

                        // Milestones unlocked this week
                        if (currentReport.unlockedMilestones.isNotEmpty) ...[
                          const FitFuelSectionHeader(
                            title: 'Milestones Unlocked',
                            subtitle: 'Badges earned during this week.',
                          ),
                          const SizedBox(height: AppConstants.spaceSm),
                          _buildMilestonesPanel(currentReport, isDark),
                        ],
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewSelector(WidgetRef ref, String activeView, bool isDark) {
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
        children: [
          _buildSelectorTab(ref, 'completed', 'Completed Week',
              activeView == 'completed', isDark),
          _buildSelectorTab(ref, 'preview', 'Current Week Preview',
              activeView == 'preview', isDark),
          _buildSelectorTab(ref, 'previous', 'Previous Week',
              activeView == 'previous', isDark),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(WidgetRef ref, String viewKey, String label,
      bool isSelected, bool isDark) {
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
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      WeeklyReportEntity current, WeeklyReportEntity previous, bool isDark) {
    final double scoreDiff = current.healthScore - previous.healthScore;
    final String trendText;
    final Color trendColor;
    final IconData trendIcon;

    if (previous.healthScore == 0.0) {
      trendText = 'Initial weekly assessment';
      trendColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      trendIcon = Icons.remove;
    } else if (scoreDiff > 0.0) {
      trendText = '+${scoreDiff.toStringAsFixed(1)} pts vs last week';
      trendColor = AppColors.stateSuccess;
      trendIcon = Icons.trending_up_rounded;
    } else if (scoreDiff < 0.0) {
      trendText = '${scoreDiff.toStringAsFixed(1)} pts vs last week';
      trendColor = AppColors.stateError;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendText = 'Stable vs last week';
      trendColor = AppColors.primary500;
      trendIcon = Icons.trending_flat_rounded;
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceAround,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppConstants.spaceMd,
            runSpacing: AppConstants.spaceMd,
            children: [
              // Health Score Circle
              Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary500, width: 4),
                      color: AppColors.primary500.withValues(alpha: 0.08),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          current.healthScore.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary500,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Health Score',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              // Streaks & Achievements Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.calories, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Streak: ${current.nutritionStreak} days',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: AppColors.achievement, size: 18),
                      Text(
                        'Achievements: ${current.unlockedMilestones.length} unlocked',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(trendIcon, color: trendColor, size: 18),
                      Text(
                        trendText,
                        style: TextStyle(
                          color: trendColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildWowComparisonPanel(
      WeeklyReportEntity current, WeeklyReportEntity previous, bool isDark) {
    String getWoWSymbol(double curr, double prev) {
      if (prev == 0.0) return '—';
      if (curr > prev) return '↑ Improved';
      if (curr < prev) return '↓ Declined';
      return '→ Stable';
    }

    Color getWoWColor(double curr, double prev) {
      if (prev == 0.0) {
        return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      }
      if (curr == prev) return AppColors.primary500;
      return (curr > prev) ? AppColors.stateSuccess : AppColors.stateError;
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWowRow(
            'Health Score',
            '${current.healthScore}',
            '${previous.healthScore}',
            getWoWSymbol(current.healthScore, previous.healthScore),
            getWoWColor(current.healthScore, previous.healthScore),
            isDark,
          ),
          _buildWowRow(
            'Avg Calories',
            '${current.avgCalories.toStringAsFixed(0)} kcal',
            '${previous.avgCalories.toStringAsFixed(0)} kcal',
            getWoWSymbol(current.avgCalories, previous.avgCalories),
            getWoWColor(current.avgCalories, previous.avgCalories),
            isDark,
          ),
          _buildWowRow(
            'Avg Protein',
            '${current.avgProtein.toStringAsFixed(1)} g',
            '${previous.avgProtein.toStringAsFixed(1)} g',
            getWoWSymbol(current.avgProtein, previous.avgProtein),
            getWoWColor(current.avgProtein, previous.avgProtein),
            isDark,
          ),
          _buildWowRow(
            'Hydration',
            '${current.avgWater.toStringAsFixed(0)} ml',
            '${previous.avgWater.toStringAsFixed(0)} ml',
            getWoWSymbol(current.avgWater, previous.avgWater),
            getWoWColor(current.avgWater, previous.avgWater),
            isDark,
          ),
          _buildWowRow(
            'Workout Mins',
            '${current.exerciseTotalMinutes} min',
            '${previous.exerciseTotalMinutes} min',
            getWoWSymbol(current.exerciseTotalMinutes.toDouble(),
                previous.exerciseTotalMinutes.toDouble()),
            getWoWColor(current.exerciseTotalMinutes.toDouble(),
                previous.exerciseTotalMinutes.toDouble()),
            isDark,
          ),
          _buildWowRow(
            'Habits Completion',
            '${current.habitsAvgCompletionPercent.toStringAsFixed(0)}%',
            '${previous.habitsAvgCompletionPercent.toStringAsFixed(0)}%',
            getWoWSymbol(current.habitsAvgCompletionPercent,
                previous.habitsAvgCompletionPercent),
            getWoWColor(current.habitsAvgCompletionPercent,
                previous.habitsAvgCompletionPercent),
            isDark,
          ),
          _buildWowRow(
            'Wellness Score',
            current.wellnessAvgScore.toStringAsFixed(0),
            previous.wellnessAvgScore.toStringAsFixed(0),
            getWoWSymbol(current.wellnessAvgScore, previous.wellnessAvgScore),
            getWoWColor(current.wellnessAvgScore, previous.wellnessAvgScore),
            isDark,
          ),
          _buildWowRow(
            'Weight Logged',
            '${current.currentWeight.toStringAsFixed(1)} kg',
            '${previous.currentWeight.toStringAsFixed(1)} kg',
            getWoWSymbol(current.currentWeight, previous.currentWeight),
            AppColors.primary500,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildWowRow(String label, String currVal, String prevVal,
      String indicator, Color trendColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currVal vs $prevVal',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                indicator,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: trendColor,
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
          FitFuelCard(
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            border: const BorderSide(color: AppColors.stateSuccess, width: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.thumb_up_alt_rounded,
                    color: AppColors.stateSuccess, size: 20),
                const SizedBox(width: AppConstants.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strongest Area: ${report.strongestArea}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.stateSuccess,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.strongestAreaDescription,
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
          ),
        const SizedBox(height: AppConstants.spaceSm),
        if (report.weakestArea != 'N/A')
          FitFuelCard(
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            border: const BorderSide(color: AppColors.calories, width: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.calories, size: 20),
                const SizedBox(width: AppConstants.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area to Improve: ${report.weakestArea}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.calories,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.weakestAreaDescription,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coach Suggestion: ${report.weakestAreaSuggestion}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary500,
                        ),
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
          AppColors.protein,
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
          AppColors.hydration,
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
          AppColors.calories,
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
          AppColors.primary500,
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
          AppColors.fat,
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
          AppColors.ai,
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

  Widget _buildCategoryCard(String title, IconData icon, Color color,
      List<String> details, bool isDark) {
    return FitFuelCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details.map((detail) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail,
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
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsPanel(WeeklyReportEntity report, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...report.insights.map((ins) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.ai, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ins,
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

  Widget _buildActionPlanPanel(WeeklyReportEntity report, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...report.actionPlan.map((action) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank_rounded,
                      color: AppColors.primary500, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
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

  Widget _buildMilestonesPanel(WeeklyReportEntity report, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: report.unlockedMilestones.map((ms) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.achievement.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    color: AppColors.achievement, size: 14),
                const SizedBox(width: 4),
                Text(
                  ms,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: const BorderSide(color: AppColors.ai, width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.ai, size: 22),
              SizedBox(width: 8),
              Text(
                'AI Health Coach',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ask Gemini for personalized coaching based on your weekly performance:',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((prompt) {
              return InkWell(
                onTap: () {
                  context.go('/ai?prompt=${Uri.encodeComponent(prompt)}');
                },
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ai.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.ai.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ai,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
