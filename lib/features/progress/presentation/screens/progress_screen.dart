import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/edit_goals_sheet.dart';
import '../../domain/entities/progress_summary_entity.dart';
import '../../domain/utils/progress_calculator.dart';
import '../controllers/progress_controller.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final TextEditingController _weightInputController = TextEditingController();

  @override
  void dispose() {
    _weightInputController.dispose();
    super.dispose();
  }

  void _submitWeight(String uid) async {
    final text = _weightInputController.text.trim();
    if (text.isEmpty) return;
    final double? weightVal = double.tryParse(text);
    if (weightVal == null || weightVal <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in kg.')),
      );
      return;
    }

    final success = await ref.read(progressControllerProvider.notifier).logWeight(uid, weightVal);
    if (mounted) {
      if (success) {
        _weightInputController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight logged successfully!')),
        );
      } else {
        final state = ref.read(progressControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log weight: ${state.saveError ?? 'Unknown error'}')),
        );
      }
    }
  }

  void _showEditProfileForm(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditGoalsSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: AppBar(
        title: const Text('Progress Center'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Update Profile',
            onPressed: () => _showEditProfileForm(context, authUser.uid),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time Range Filters selector
            _buildTimeRangeSelector(ref, range, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Streak Status card
            _buildStreakCard(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Wellness Score Trend Section
            _buildWellnessSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Nutrition Adherence Section
            _buildNutritionSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Hydration Section
            _buildHydrationSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Exercise Section
            _buildExerciseSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Habits Section
            _buildHabitsSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Weight History & Graph Section
            _buildWeightSection(authUser.uid, summary, weightHistory, isDark),
            const SizedBox(height: AppConstants.spaceMd),

            // Milestones & Achievements Section
            _buildAchievementsSection(summary, isDark),
            const SizedBox(height: AppConstants.spaceXl),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(WidgetRef ref, int activeRange, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBorderSubtle,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
                  color: isSelected ? AppColors.primary500 : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  '$days Days',
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStreakCard(ProgressSummaryEntity summary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.secondary500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 48),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrition Streak',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${summary.currentStreak} Days Current',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Text(
              'Max: ${summary.longestStreak} days',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Wellness Rating Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(trendIcon, color: trendColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        summary.wellnessTrend,
                        style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                    Colors.orange,
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
      ),
    );
  }

  Widget _buildNutritionSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.nutritionDaysLogged == 0) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceMd),
          child: Text('No nutrition data yet.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nutrition Goal Adherence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            _buildProgressBar('Calories Adherence', summary.avgCalories, summary.calorieTarget, 'kcal', AppColors.primary500),
            const SizedBox(height: AppConstants.spaceSm),
            _buildProgressBar('Protein consistency', summary.avgProtein, summary.proteinTarget, 'g', Colors.teal),
            const SizedBox(height: AppConstants.spaceSm),
            _buildProgressBar('Carbohydrates', summary.avgCarbs, summary.carbsTarget, 'g', Colors.orange),
            const SizedBox(height: AppConstants.spaceSm),
            _buildProgressBar('Fat', summary.avgFats, summary.fatsTarget, 'g', Colors.red),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              children: [
                Expanded(child: _buildMetricTile('Days Logged', '${summary.nutritionDaysLogged}', AppColors.primary500, isDark)),
                Expanded(child: _buildMetricTile('Days Missed', '${summary.nutritionDaysMissed}', isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, isDark)),
                Expanded(child: _buildMetricTile('Calorie Consistency', '${summary.calorieConsistencyPercent.toStringAsFixed(0)}%', Colors.teal, isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHydrationSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.waterDaysMet == 0 && summary.avgWater == 0.0) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceMd),
          child: Text('No hydration data yet.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hydration Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            _buildProgressBar('Daily Water Intake', summary.avgWater, summary.waterTarget, 'ml', Colors.blue),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              children: [
                Expanded(child: _buildMetricTile('Avg Daily Water', '${summary.avgWater.toStringAsFixed(0)} ml', Colors.blue, isDark)),
                Expanded(child: _buildMetricTile('Target Reached', '${summary.waterDaysMet} days', AppColors.stateSuccess, isDark)),
                Expanded(child: _buildMetricTile('Consistency', '${summary.waterConsistencyPercent.toStringAsFixed(0)}%', Colors.cyan, isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.exerciseActiveDays == 0) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceMd),
          child: Text('No workouts logged yet.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Workout & Exercise consistency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              children: [
                Expanded(child: _buildMetricTile('Active Days', '${summary.exerciseActiveDays}', Colors.red, isDark)),
                Expanded(child: _buildMetricTile('Total Workout Mins', '${summary.exerciseTotalMinutes} min', Colors.orange, isDark)),
                Expanded(child: _buildMetricTile('Calories Burned', '${summary.exerciseTotalCaloriesBurned.toStringAsFixed(0)} kcal', Colors.amber, isDark)),
              ],
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Row(
              children: [
                Expanded(child: _buildMetricTile('Avg Duration', '${summary.exerciseAvgDuration.toStringAsFixed(1)} min', Colors.redAccent, isDark)),
                Expanded(child: _buildMetricTile('Workout Frequency', '${summary.exerciseConsistencyPercent.toStringAsFixed(0)}%', Colors.pink, isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsSection(ProgressSummaryEntity summary, bool isDark) {
    if (summary.habitsSuccessfulDays == 0 && summary.habitsAvgCompletionRate == 0.0) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceMd),
          child: Text('No habits checklist items yet.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }

    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Habit consistency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              children: [
                Expanded(child: _buildMetricTile('Avg Completion Rate', '${summary.habitsAvgCompletionRate.toStringAsFixed(0)}%', Colors.green, isDark)),
                Expanded(child: _buildMetricTile('Successful Days', '${summary.habitsSuccessfulDays} days', AppColors.stateSuccess, isDark)),
                Expanded(child: _buildMetricTile('Habit Consistency', '${summary.habitsConsistencyPercent.toStringAsFixed(0)}%', Colors.teal, isDark)),
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
                      Text('Most Consistent Habit', style: TextStyle(fontSize: 11, color: mutedColor)),
                      Text(
                        summary.habitsMostConsistent,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.stateSuccess),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Least Consistent Habit', style: TextStyle(fontSize: 11, color: mutedColor)),
                      Text(
                        summary.habitsLeastConsistent,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.stateError),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection(String uid, ProgressSummaryEntity summary, List<dynamic> weightHistory, bool isDark) {
    final Color changeColor = summary.weightChange <= 0 ? AppColors.stateSuccess : AppColors.stateError;
    final prefix = summary.weightChange > 0 ? '+' : '';
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Body Weight Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppConstants.spaceMd),
            
            // Log weight input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightInputController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Log today\'s weight (kg)',
                      hintText: 'e.g. 75.5',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                ElevatedButton(
                  onPressed: () => _submitWeight(uid),
                  child: const Text('Log'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceMd),

            if (weightHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Add your first weight measurement to start tracking progress.', style: TextStyle(fontStyle: FontStyle.italic)),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: _buildMetricTile('Starting Weight', '${summary.startingWeight.toStringAsFixed(1)} kg', mutedColor, isDark)),
                  Expanded(child: _buildMetricTile('Current Weight', '${summary.currentWeight.toStringAsFixed(1)} kg', AppColors.primary500, isDark)),
                  Expanded(
                    child: _buildMetricTile(
                      'Total Change',
                      '$prefix${summary.weightChange.toStringAsFixed(1)} kg ($prefix${summary.weightChangePercent.toStringAsFixed(1)}%)',
                      changeColor,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Text(
                'Fitness Goal: ${summary.weightGoalDirection}',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              
              // fl_chart trend lines
              if (weightHistory.length >= 2) ...[
                const Text('Weight Trend Line', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppConstants.spaceSm),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)),
                      lineBarsData: [
                        LineChartBarData(
                          spots: () {
                            final List<FlSpot> spots = [];
                            final list = List<dynamic>.from(weightHistory)
                              ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
                            for (int i = 0; i < list.length; i++) {
                              spots.add(FlSpot(i.toDouble(), list[i].weight.toDouble()));
                            }
                            return spots;
                          }(),
                          isCurved: true,
                          color: AppColors.primary500,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(ProgressSummaryEntity summary, bool isDark) {
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones & Achievements',
          style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        ...summary.milestones.map((ms) {
          return Card(
            elevation: ms.isUnlocked ? 2 : 1,
            color: isDark
                ? AppColors.darkBgSurface
                : (ms.isUnlocked ? AppColors.lightBgSurface : AppColors.lightBgBase),
            margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              side: BorderSide(
                color: ms.isUnlocked
                    ? AppColors.achievement.withAlpha(80)
                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                width: ms.isUnlocked ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceMd),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ms.isUnlocked ? AppColors.achievement.withAlpha(25) : mutedColor.withAlpha(15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ms.isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                      color: ms.isUnlocked ? AppColors.achievement : mutedColor,
                      size: 28,
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
                            Text(
                              ms.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: ms.isUnlocked
                                    ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                                    : mutedColor,
                              ),
                            ),
                            if (ms.isUnlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.achievement.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'UNLOCKED',
                                  style: TextStyle(color: AppColors.achievement, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ms.description,
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ms.progressPercent,
                                  minHeight: 6,
                                  backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBorderSubtle,
                                  color: ms.isUnlocked ? AppColors.achievement : mutedColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spaceMd),
                            Text(
                              ms.progressText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ms.isUnlocked ? AppColors.achievement : mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgressBar(String title, double current, double target, String unit, Color barColor) {
    final double fraction = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final percent = fraction * 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit (${percent.toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.lightBorderSubtle,
            color: barColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor, bool isDark) {
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: mutedColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
