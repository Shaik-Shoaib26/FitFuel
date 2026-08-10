import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/edit_goals_sheet.dart';
import '../../../../app/config/routes.dart';
import 'package:go_router/go_router.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/domain/utils/recommendation_engine.dart';
import '../../../nutrition/domain/utils/nutrition_insights_engine.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showFoodForm(BuildContext context, String uid, {NutritionRecordEntity? record}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodFormSheet(uid: uid, existingRecord: record),
    );
  }

  void _showEditGoalsForm(BuildContext context, String uid, {NutritionGoalsEntity? goals}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditGoalsSheet(uid: uid, existingGoals: goals),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentProfileStreamProvider);
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);
    final authUiState = ref.watch(authControllerProvider);
    final isAuthLoading = authUiState is AuthUiStateLoading;

    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitFuel Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu_rounded),
            tooltip: 'Personalized Meal Planner',
            onPressed: () => context.push(AppRoutes.mealPlan),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Nutrition Analytics',
            onPressed: () => context.push(AppRoutes.history),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: isAuthLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentProfileStreamProvider);
            ref.invalidate(nutritionStreamProvider);
            ref.invalidate(nutritionGoalsStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Profile Header Card
                profileAsync.when(
                  data: (profile) {
                    final displayName = (profile?.displayName != null && profile!.displayName!.isNotEmpty)
                        ? profile.displayName!
                        : (authUser?.displayName ?? 'FitFuel User');
                    final email = profile?.email ?? authUser?.email ?? 'No email provided';
                    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

                    return GlassmorphicContainer(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary100,
                            child: Text(
                              initial,
                              style: AppTypography.heading2(isDark: false),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTypography.heading2(isDark: isDark),
                                ),
                                Text(
                                  email,
                                  style: AppTypography.bodySmall(isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const GlassmorphicContainer(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => GlassmorphicContainer(
                    child: Text(
                      'Error loading profile: $error',
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(color: AppColors.stateError),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // 2. Daily Intake Macro Panel
                nutritionAsync.when(
                  data: (records) {
                    final todayRecords = NutritionCalculator.filterByDay(records, DateTime.now());

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 3. Nutrition Goals Panel (with progress bars)
                        goalsAsync.when(
                          data: (goals) {
                            final stats = NutritionCalculator.calculateProgress(
                              dailyRecords: todayRecords,
                              goals: goals,
                            );

                            final calorieGoal = goals?.dailyCalorieTarget ?? 2000;
                            final proteinGoal = goals?.proteinTargetGrams ?? 150.0;
                            final carbsGoal = goals?.carbsTargetGrams ?? 200.0;
                            final fatGoal = goals?.fatTargetGrams ?? 65.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Intake panel
                                GlassmorphicContainer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Daily Intake Summary',
                                        style: AppTypography.heading3(isDark: isDark),
                                      ),
                                      const SizedBox(height: AppConstants.spaceMd),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            children: [
                                              Text(
                                                stats.totalCalories.toStringAsFixed(0),
                                                style: AppTypography.displayMedium(isDark: isDark).copyWith(
                                                  color: isDark ? AppColors.primary400 : AppColors.primary500,
                                                ),
                                              ),
                                              Text('Calories', style: AppTypography.caption(isDark: isDark)),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                '${stats.totalProtein.toStringAsFixed(1)}g',
                                                style: AppTypography.heading2(isDark: isDark).copyWith(
                                                  color: AppColors.accentProtein,
                                                ),
                                              ),
                                              Text('Protein', style: AppTypography.caption(isDark: isDark)),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                '${stats.totalCarbs.toStringAsFixed(1)}g',
                                                style: AppTypography.heading2(isDark: isDark).copyWith(
                                                  color: AppColors.accentCarbs,
                                                ),
                                              ),
                                              Text('Carbs', style: AppTypography.caption(isDark: isDark)),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                '${stats.totalFats.toStringAsFixed(1)}g',
                                                style: AppTypography.heading2(isDark: isDark).copyWith(
                                                  color: AppColors.accentFats,
                                                ),
                                              ),
                                              Text('Fats', style: AppTypography.caption(isDark: isDark)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spaceMd),

                                GlassmorphicContainer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Goals Progress',
                                            style: AppTypography.heading3(isDark: isDark),
                                          ),
                                          if (authUser != null)
                                            IconButton(
                                              icon: const Icon(Icons.edit_note_rounded),
                                              tooltip: 'Edit Goals',
                                              onPressed: () => _showEditGoalsForm(context, authUser.uid, goals: goals),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppConstants.spaceSm),

                                      // Calories Progress
                                      _buildProgressRow(
                                        label: 'Calories',
                                        consumed: stats.totalCalories,
                                        goal: calorieGoal.toDouble(),
                                        progress: stats.calorieProgress,
                                        unit: 'kcal',
                                        color: isDark ? AppColors.primary400 : AppColors.primary500,
                                      ),
                                      const SizedBox(height: AppConstants.spaceMd),

                                      // Protein Progress
                                      _buildProgressRow(
                                        label: 'Protein',
                                        consumed: stats.totalProtein,
                                        goal: proteinGoal,
                                        progress: stats.proteinProgress,
                                        unit: 'g',
                                        color: AppColors.accentProtein,
                                      ),
                                      const SizedBox(height: AppConstants.spaceMd),

                                      // Carbs Progress
                                      _buildProgressRow(
                                        label: 'Carbohydrates',
                                        consumed: stats.totalCarbs,
                                        goal: carbsGoal,
                                        progress: stats.carbsProgress,
                                        unit: 'g',
                                        color: AppColors.accentCarbs,
                                      ),
                                      const SizedBox(height: AppConstants.spaceMd),

                                      // Fats Progress
                                      _buildProgressRow(
                                        label: 'Fats',
                                        consumed: stats.totalFats,
                                        goal: fatGoal,
                                        progress: stats.fatProgress,
                                        unit: 'g',
                                        color: AppColors.accentFats,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spaceMd),
                                _buildSmartNutritionCard(context, todayRecords, goals, isDark, authUser?.uid),
                                const SizedBox(height: AppConstants.spaceMd),
                                _buildCompactInsightsCard(context, records, goals, isDark),
                              ],
                            );
                          },
                          loading: () => const GlassmorphicContainer(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, _) => GlassmorphicContainer(
                            child: Text(
                              'Error loading nutrition goals: $error',
                              style: AppTypography.bodySmall(isDark: isDark).copyWith(color: AppColors.stateError),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const GlassmorphicContainer(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Container(),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // 4. Log Food Header & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nutrition Logs',
                      style: AppTypography.heading2(isDark: isDark),
                    ),
                    if (authUser != null)
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Food'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.primary400 : AppColors.primary500,
                        ),
                        onPressed: () => _showFoodForm(context, authUser.uid),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),

                // 5. Logged Nutrition Records List
                nutritionAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return GlassmorphicContainer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 48,
                                color: AppColors.darkTextMuted,
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              Text(
                                'No food logged today.',
                                style: AppTypography.bodyMedium(isDark: isDark),
                              ),
                              Text(
                                'Tap "Add Food" to log your first item.',
                                style: AppTypography.caption(isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: records.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppConstants.spaceSm),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spaceMd,
                              vertical: AppConstants.spaceXs,
                            ),
                            title: Text(
                              record.foodName,
                              style: AppTypography.heading3(isDark: isDark),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Meal: ${record.mealType}  ·  Serving: ${record.servingSize.toStringAsFixed(0)}g  ·  ${dateFormat.format(record.consumedAt)}',
                                  style: AppTypography.caption(isDark: isDark),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildMiniMacroChip('P: ${record.protein.toStringAsFixed(0)}g', AppColors.accentProtein),
                                    const SizedBox(width: 6),
                                    _buildMiniMacroChip('C: ${record.carbohydrates.toStringAsFixed(0)}g', AppColors.accentCarbs),
                                    const SizedBox(width: 6),
                                    _buildMiniMacroChip('F: ${record.fats.toStringAsFixed(0)}g', AppColors.accentFats),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${record.calories.toStringAsFixed(0)} kcal',
                                  style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceXs),
                                PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (authUser == null) return;
                                    if (action == 'edit') {
                                      _showFoodForm(context, authUser.uid, record: record);
                                    } else if (action == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Log'),
                                          content: const Text('Are you sure you want to delete this food log?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref
                                            .read(nutritionControllerProvider.notifier)
                                            .deleteRecord(authUser.uid, record.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.spaceLg),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => GlassmorphicContainer(
                    child: Text(
                      'Error loading nutrition logs: $error',
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(color: AppColors.stateError),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),

                // 6. Explicit Sign Out button at the bottom
                FitFuelButton(
                  label: 'Sign Out',
                  type: FitFuelButtonType.secondary,
                  onPressed: isAuthLoading
                      ? null
                      : () async {
                          await ref.read(authControllerProvider.notifier).signOut();
                        },
                  isLoading: isAuthLoading,
                  icon: Icons.logout_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required double consumed,
    required double goal,
    required double progress,
    required String unit,
    required Color color,
  }) {
    final percent = (progress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              '${consumed.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit ($percent%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMacroChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildSmartNutritionCard(
    BuildContext context,
    List<NutritionRecordEntity> dailyRecords,
    NutritionGoalsEntity? goals,
    bool isDark,
    String? uid,
  ) {
    final result = RecommendationEngine.getRecommendations(
      dailyRecords: dailyRecords,
      goals: goals,
    );

    String renderRemaining(double value, bool isExceeded, String unit) {
      if (isExceeded) {
        return 'Goal exceeded';
      }
      return '${value.toStringAsFixed(0)} $unit';
    }

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: AppColors.primary500),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'Smart Nutrition',
                style: AppTypography.heading3(isDark: isDark),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),

          // Remaining status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRemainingMacroCol(
                'Calories',
                renderRemaining(result.remainingCalories, result.isCalorieExceeded, 'kcal'),
                result.isCalorieExceeded ? AppColors.stateError : (isDark ? AppColors.primary400 : AppColors.primary500),
              ),
              _buildRemainingMacroCol(
                'Protein',
                renderRemaining(result.remainingProtein, result.isProteinExceeded, 'g'),
                result.isProteinExceeded ? AppColors.stateError : AppColors.accentProtein,
              ),
              _buildRemainingMacroCol(
                'Carbs',
                renderRemaining(result.remainingCarbs, result.isCarbsExceeded, 'g'),
                result.isCarbsExceeded ? AppColors.stateError : AppColors.accentCarbs,
              ),
              _buildRemainingMacroCol(
                'Fats',
                renderRemaining(result.remainingFats, result.isFatExceeded, 'g'),
                result.isFatExceeded ? AppColors.stateError : AppColors.accentFats,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),

          // Insight Box
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary500.withValues(alpha: 0.1)
                  : AppColors.primary500.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(
                color: AppColors.primary500.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.insightMessage,
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),

          // Food suggestions section
          Text(
            'Recommended Foods',
            style: AppTypography.bodyMedium(isDark: isDark).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),

          if (result.suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No suggestions matching your macro needs right now.',
                style: AppTypography.caption(isDark: isDark),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.suggestions.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.spaceSm),
              itemBuilder: (context, index) {
                final suggestion = result.suggestions[index];
                final food = suggestion.food;
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceMd,
                      vertical: AppConstants.spaceXs,
                    ),
                    title: Text(
                      food.name,
                      style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${food.calories.toStringAsFixed(0)} kcal  ·  P: ${food.protein.toStringAsFixed(0)}g  ·  C: ${food.carbohydrates.toStringAsFixed(0)}g  ·  F: ${food.fats.toStringAsFixed(0)}g',
                          style: AppTypography.caption(isDark: isDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.reason,
                          style: AppTypography.caption(isDark: isDark).copyWith(
                            color: isDark ? AppColors.primary400 : AppColors.primary500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary500),
                      tooltip: 'Log this food suggestion',
                      onPressed: uid == null
                          ? null
                          : () {
                              final suggestionEntity = NutritionRecordEntity(
                                id: '',
                                foodName: food.name,
                                mealType: 'Snack',
                                calories: food.calories,
                                protein: food.protein,
                                carbohydrates: food.carbohydrates,
                                fats: food.fats,
                                sugar: food.sugar,
                                servingSize: food.servingSize,
                                consumedAt: DateTime.now(),
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              _showFoodForm(context, uid, record: suggestionEntity);
                            },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRemainingMacroCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: value == 'Goal exceeded' ? 10 : 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.darkTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInsightsCard(
    BuildContext context,
    List<NutritionRecordEntity> records,
    NutritionGoalsEntity? goals,
    bool isDark,
  ) {
    final result = NutritionInsightsEngine.analyzeHistory(
      records: records,
      goals: goals,
    );

    final String keyInsightTitle = result.insights.isNotEmpty
        ? result.insights.first.title
        : 'Steady Progress';
    final String keyInsightDesc = result.insights.isNotEmpty
        ? result.insights.first.description
        : 'Keep logging meals to unlock personalized trends.';

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, color: AppColors.primary500),
                  const SizedBox(width: AppConstants.spaceSm),
                  Text(
                    'Nutrition Insights',
                    style: AppTypography.heading3(isDark: isDark),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.insights),
                child: const Text('View Insights'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            keyInsightTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            keyInsightDesc,
            style: AppTypography.caption(isDark: isDark),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Consistency Score:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${result.consistencyScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.primary400 : AppColors.primary500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
