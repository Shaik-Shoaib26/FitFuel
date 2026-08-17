import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_progress_ring.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../health/domain/utils/wellness_calculator.dart';
import '../../../health/presentation/controllers/health_controller.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/domain/utils/recommendation_engine.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/edit_goals_sheet.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../widgets/dashboard_meal_plan_card.dart';
import '../widgets/dashboard_routine_card.dart';
import '../widgets/dashboard_grocery_card.dart';
import '../widgets/dashboard_analytics_card.dart';
import '../../../insights/presentation/widgets/dashboard_insights_card.dart';

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

    final healthRecords = ref.watch(healthStreamProvider).value ?? [];
    final weightRecords = ref.watch(weightHistoryStreamProvider).value ?? [];
    final healthRecord = ref.watch(todayHealthRecordProvider);

    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary500.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primary500, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'FitFuel',
              style: AppTypography.heading1(isDark: isDark).copyWith(fontSize: 20),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppColors.primary500),
            tooltip: 'My Health Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_rounded, color: AppColors.ai),
            tooltip: 'Ask FitFuel AI',
            onPressed: () => context.push(AppRoutes.aiAssistant),
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
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER: Greeting & Profile Section
                profileAsync.when(
                  data: (profile) {
                    final displayName = (profile?.displayName != null && profile!.displayName!.isNotEmpty)
                        ? profile.displayName!
                        : (authUser?.displayName ?? 'FitFuel User');

                    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
                    final fitnessGoal = profile?.fitnessGoal ?? 'Maintain Weight';

                    // Streak count
                    int streakCount = 0;
                    final nutritionList = nutritionAsync.value ?? [];
                    if (nutritionList.isNotEmpty) {
                      final summary = ProgressCalculator.calculateSummary(
                        nutritionHistory: nutritionList,
                        healthHistory: healthRecords,
                        weightHistory: weightRecords,
                        goals: goalsAsync.value,
                        profile: profile,
                        daysCount: 7,
                      );
                      streakCount = summary.currentStreak;
                    }

                    // Time-based greeting
                    final hour = DateTime.now().hour;
                    String greeting = 'Hello';
                    if (hour < 12) {
                      greeting = 'Good morning';
                    } else if (hour < 17) {
                      greeting = 'Good afternoon';
                    } else {
                      greeting = 'Good evening';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.profile),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primary100,
                              child: Text(
                                initial,
                                style: AppTypography.heading2(isDark: false).copyWith(
                                  color: AppColors.primary500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting, $displayName 👋',
                                  style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Let's make today a healthy one.",
                                  style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (streakCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.calories.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.calories.withAlpha(50)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, color: AppColors.calories, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$streakCount Days',
                                        style: const TextStyle(color: AppColors.calories, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: authUser == null
                                    ? null
                                    : () => _showEditGoalsForm(context, authUser.uid, goals: goalsAsync.value),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary500.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary500.withAlpha(50)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        fitnessGoal,
                                        style: const TextStyle(color: AppColors.primary500, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_rounded, size: 8, color: AppColors.primary500),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Container(),
                ),

                // 2. HERO CALORIE CARD & MACROS
                nutritionAsync.when(
                  data: (records) {
                    final todayRecords = NutritionCalculator.filterByDay(records, DateTime.now());

                    return goalsAsync.when(
                      data: (goals) {
                        final stats = NutritionCalculator.calculateProgress(
                          dailyRecords: todayRecords,
                          goals: goals,
                        );

                        final calorieGoal = goals?.dailyCalorieTarget ?? 2000;
                        final proteinGoal = goals?.proteinTargetGrams ?? 150.0;
                        final carbsGoal = goals?.carbsTargetGrams ?? 200.0;
                        final fatGoal = goals?.fatTargetGrams ?? 65.0;

                        final remainingCalories = calorieGoal - stats.totalCalories;
                        final calorieProgress = calorieGoal > 0 ? (stats.totalCalories / calorieGoal).clamp(0.0, 1.0) : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Hero Calorie Card
                            FitFuelCard(
                              padding: const EdgeInsets.all(AppConstants.spaceLg),
                              child: Row(
                                children: [
                                  FitFuelProgressRing(
                                    value: calorieProgress,
                                    size: 120,
                                    strokeWidth: 10,
                                    centerTitle: stats.totalCalories.toStringAsFixed(0),
                                    centerSubtitle: 'consumed',
                                    progressColor: remainingCalories >= 0 ? AppColors.calories : AppColors.error,
                                  ),
                                  const SizedBox(width: AppConstants.spaceLg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Calories Remaining',
                                          style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${remainingCalories.toStringAsFixed(0)} kcal',
                                          style: AppTypography.displayLarge(isDark: isDark).copyWith(
                                            color: remainingCalories >= 0 ? AppColors.calories : AppColors.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 26,
                                          ),
                                        ),
                                        const SizedBox(height: AppConstants.spaceSm),
                                        Text(
                                          'Goal: ${calorieGoal.toStringAsFixed(0)} kcal',
                                          style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceMd),

                            // Macro Section (3 Compact Cards)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMacroTile(
                                    'Protein',
                                    stats.totalProtein,
                                    proteinGoal,
                                    Icons.egg_alt_rounded,
                                    AppColors.protein,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceSm),
                                Expanded(
                                  child: _buildMacroTile(
                                    'Carbs',
                                    stats.totalCarbs,
                                    carbsGoal,
                                    Icons.grain_rounded,
                                    AppColors.carbs,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceSm),
                                Expanded(
                                  child: _buildMacroTile(
                                    'Fat',
                                    stats.totalFats,
                                    fatGoal,
                                    Icons.opacity_rounded,
                                    AppColors.fat,
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 3. HYDRATION CARD
                            _buildHydrationCard(context, ref, healthRecord, isDark),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 4. WELLNESS SCORE CARD
                            _buildWellnessScoreCard(context, ref, todayRecords, isDark),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 5. AI COACH CARD
                            _buildAiCoachCard(context, isDark),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 6. QUICK ACTIONS
                            if (authUser != null) ...[
                              _buildQuickActions(context, authUser.uid, isDark),
                              const SizedBox(height: AppConstants.spaceMd),
                            ],

                            const DashboardRoutineCard(),
                            const SizedBox(height: AppConstants.spaceMd),

                            // NEW: MEAL PLAN CARD
                            const DashboardMealPlanCard(),
                            const SizedBox(height: AppConstants.spaceMd),

                            // NEW: GROCERY CARD
                            const DashboardGroceryCard(),
                            const SizedBox(height: AppConstants.spaceMd),

                            // NEW: ANALYTICS CARD
                            const DashboardAnalyticsCard(),
                            const SizedBox(height: AppConstants.spaceMd),

                            // NEW: INSIGHTS CARD
                            const DashboardInsightsCard(),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 7. SMART NUTRITION & RECOMMENDED FOODS
                            _buildSmartNutritionCard(context, todayRecords, goals, isDark, authUser?.uid),
                            const SizedBox(height: AppConstants.spaceMd),

                            // 8. TODAY'S FOOD LOGS LIST
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Today's Food Logs",
                                  style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                                ),
                                if (authUser != null)
                                  TextButton.icon(
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                    label: const Text('Log Food', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _showFoodForm(context, authUser.uid),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceSm),
                            _buildLogsList(context, ref, todayRecords, authUser?.uid, isDark, dateFormat),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Container(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Container(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroTile(String label, double consumed, double target, IconData icon, Color color, bool isDark) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toStringAsFixed(0);

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${consumed.toStringAsFixed(0)}g / ${target.toStringAsFixed(0)}g',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: color.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percent%',
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationCard(BuildContext context, WidgetRef ref, HealthRecordEntity? record, bool isDark) {
    final todayStr = DateTime.now().toString().split(' ').first;
    final activeRecord = record ?? HealthRecordEntity.empty(todayStr);
    final intake = activeRecord.waterIntakeMl;
    final target = activeRecord.waterTargetMl > 0 ? activeRecord.waterTargetMl : 2000.0;
    final progress = (intake / target).clamp(0.0, 1.0);
    final percentText = (progress * 100).toStringAsFixed(0);

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppColors.hydration, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Hydration',
                    style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 15),
                  ),
                ],
              ),
              Text(
                '${intake.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} ml',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.hydration),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.hydration.withAlpha(20),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.hydration),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percentText% of target',
              style: const TextStyle(fontSize: 10, color: AppColors.hydration, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(healthControllerProvider.notifier).incrementWater(250.0);
                  },
                  icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.hydration),
                  label: const Text('+250 ml', style: TextStyle(fontSize: 11, color: AppColors.hydration)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.hydration, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(healthControllerProvider.notifier).incrementWater(500.0);
                  },
                  icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.hydration),
                  label: const Text('+500 ml', style: TextStyle(fontSize: 11, color: AppColors.hydration)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.hydration, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessScoreCard(BuildContext context, WidgetRef ref, List<NutritionRecordEntity> todayRecords, bool isDark) {
    final healthRecord = ref.watch(todayHealthRecordProvider);
    final bool hasLoggedFood = todayRecords.isNotEmpty;

    final double score = WellnessCalculator.calculateScore(
      hasLoggedFoodToday: hasLoggedFood,
      healthRecord: healthRecord,
    );

    int totalMins = 0;
    if (healthRecord != null) {
      for (final ex in healthRecord.exercises) {
        totalMins += ex.duration;
      }
    }

    int completedHabits = 0;
    int totalHabits = healthRecord?.habits.length ?? 3;
    if (healthRecord != null) {
      healthRecord.habits.forEach((_, value) {
        if (value) completedHabits++;
      });
    }

    final waterIntake = healthRecord?.waterIntakeMl ?? 0.0;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Wellness Score',
                    style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 15),
                  ),
                ],
              ),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.error.withAlpha(20),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary500),
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularStatusItem('Nutrition', hasLoggedFood ? '✓' : '○', hasLoggedFood),
              _buildCircularStatusItem('Water', waterIntake > 0 ? '●' : '○', waterIntake > 0),
              _buildCircularStatusItem('Exercise', totalMins > 0 ? '✓' : '○', totalMins > 0),
              _buildCircularStatusItem('Habits', completedHabits == totalHabits ? '✓' : '○', completedHabits > 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularStatusItem(String label, String statusSymbol, bool isActive) {
    final color = isActive ? AppColors.primary500 : Colors.grey;
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(20),
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            statusSymbol,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAiCoachCard(BuildContext context, bool isDark) {
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      color: isDark ? AppColors.darkBgSurface : AppColors.primary50.withAlpha(80),
      border: const BorderSide(color: AppColors.ai, width: 1.5),
      onTap: () => context.push(AppRoutes.aiAssistant),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.ai.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppColors.ai, size: 26),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '🤖 FitFuel AI',
                      style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 15, color: AppColors.ai),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.ai.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Coach',
                        style: TextStyle(color: AppColors.ai, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your personal nutrition coach. Ask me what to eat or build a healthier routine.',
                  style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask FitFuel AI →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ai),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String uid, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionPill(context, 'Log Food', Icons.restaurant_menu_rounded, AppColors.calories, () => _showFoodForm(context, uid)),
            _buildActionPill(context, 'Water', Icons.water_drop_rounded, AppColors.hydration, () => context.push(AppRoutes.health)),
            _buildActionPill(context, 'Exercise', Icons.directions_run_rounded, AppColors.exercise, () => context.push(AppRoutes.health)),
            _buildActionPill(context, 'Progress', Icons.bar_chart_rounded, AppColors.carbs, () => context.push(AppRoutes.progress)),
            _buildActionPill(context, 'Meal Plan', Icons.restaurant_rounded, AppColors.primary500, () => context.push(AppRoutes.mealPlan)),
            _buildActionPill(context, 'AI Coach', Icons.smart_toy_rounded, AppColors.ai, () => context.push(AppRoutes.aiAssistant)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionPill(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: FitFuelCard(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
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

    return FitFuelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: AppColors.primary500),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'Smart Nutrition Insights',
                style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.primary100),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.insightMessage,
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(
    BuildContext context,
    WidgetRef ref,
    List<NutritionRecordEntity> records,
    String? uid,
    bool isDark,
    DateFormat dateFormat,
  ) {
    if (records.isEmpty) {
      return FitFuelCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.restaurant_menu_rounded, size: 36, color: Colors.grey),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'No foods logged today.',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ],
            ),
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
        return FitFuelCard(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.foodName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.mealType} · ${record.servingSize.toStringAsFixed(0)}g · ${dateFormat.format(record.consumedAt)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${record.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.calories),
              ),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (uid == null) return;
                  if (action == 'edit') {
                    _showFoodForm(context, uid, record: record);
                  } else if (action == 'delete') {
                    await ref.read(nutritionControllerProvider.notifier).deleteRecord(uid, record.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
