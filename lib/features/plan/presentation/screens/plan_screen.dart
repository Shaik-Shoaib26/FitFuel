import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reminders/presentation/providers/reminders_providers.dart';
import '../../../smart_eat/presentation/providers/smart_eat_providers.dart';
import '../../domain/utils/next_meal_selector.dart';
import '../widgets/plan_empty_state.dart';
import '../widgets/plan_macro_summary.dart';
import '../widgets/plan_next_meal_hero.dart';
import '../widgets/plan_progress_card.dart';
import '../widgets/plan_quick_actions.dart';
import '../widgets/plan_recommendation_card.dart';

/// Reference-accurate Option A — Modern & Minimal Plan Dashboard.
/// Features a dynamic Next-Meal Hero connected to real active meal plan,
/// circular Today's Plan Progress card, macro summary, primary View Full Meal Plan CTA,
/// quick actions, and Smart Eat recommendations.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with WidgetsBindingObserver {
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _now = DateTime.now();
      });
      ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final planState = ref.watch(mealPlannerControllerProvider);
    final nutritionRecords =
        ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    final reminderSettings =
        ref.watch(remindersSettingsStreamProvider).valueOrNull;
    final topRecommendation =
        ref.watch(smartEatTopRecommendationProvider).valueOrNull;

    final networkStatus =
        ref.watch(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    final todayLogs =
        NutritionCalculator.filterByDay(nutritionRecords, _now);

    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Plan')),
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            if (isOffline) return;
            setState(() {
              _now = DateTime.now();
            });
            await ref
                .read(mealPlannerControllerProvider.notifier)
                .loadTodayPlan();
          },
          child: SingleChildScrollView(
            key: const PageStorageKey('plan-scroll'),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            child: planState.when(
              loading: () => _buildLoadingSkeleton(isDark),
              error: (err, _) => _buildErrorCard(context, ref, isDark),
              data: (plan) {
                if (plan == null || plan.meals.isEmpty) {
                  return _buildEmptyStateContent(
                    context,
                    ref,
                    topRecommendation,
                    isDark,
                  );
                }

                // Pure deterministic next-meal selection
                final selection = NextMealSelector.determineNextMeal(
                  plan: plan,
                  loggedToday: todayLogs,
                  now: _now,
                  reminderSettings: reminderSettings,
                );

                final orderedMeals = NextMealSelector.sortMeals(
                  plan.meals,
                  date: _now,
                  reminderSettings: reminderSettings,
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;

                    if (isDesktop) {
                      return _buildDesktopLayout(
                        context: context,
                        plan: plan,
                        selection: selection,
                        orderedMeals: orderedMeals,
                        goalsTargetCalories: goals?.dailyCalorieTarget ?? 2000,
                        topRecommendation: topRecommendation,
                        isDark: isDark,
                      );
                    }

                    return _buildMobileLayout(
                      context: context,
                      plan: plan,
                      selection: selection,
                      orderedMeals: orderedMeals,
                      goalsTargetCalories: goals?.dailyCalorieTarget ?? 2000,
                      topRecommendation: topRecommendation,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required MealPlanEntity plan,
    required NextMealSelection selection,
    required List<dynamic> orderedMeals,
    required int goalsTargetCalories,
    required dynamic topRecommendation,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Dynamic Next-Meal Hero
        PlanNextMealHero(
          selection: selection,
          onTap: () => context.go('/plan/meals'),
        ),
        const SizedBox(height: 16),

        // 2. Today's Plan Progress Card
        PlanProgressCard(
          meals: plan.meals,
          selection: selection,
          onViewPlanPressed: () => context.go('/plan/meals'),
        ),
        const SizedBox(height: 14),

        // 3. Daily Macro Summary
        PlanMacroSummary(
          plannedProtein: plan.plannedProtein,
          targetProtein: plan.targetProtein > 0 ? plan.targetProtein : 140,
          plannedCarbs: plan.plannedCarbs,
          targetCarbs: plan.targetCarbs > 0 ? plan.targetCarbs : 220,
          plannedFat: plan.plannedFat,
          targetFat: plan.targetFat > 0 ? plan.targetFat : 60,
        ),
        const SizedBox(height: 16),

        // 4. Primary View Full Meal Plan CTA
        SizedBox(
          height: 52,
          child: FitFuelButton(
            label: 'View Full Meal Plan',
            icon: Icons.restaurant_menu_rounded,
            onPressed: () => context.go('/plan/meals'),
          ),
        ),
        const SizedBox(height: 22),

        // 5. Quick Actions
        const PlanQuickActions(),
        const SizedBox(height: 22),

        // 6. Today's Recommendations
        PlanRecommendationCard(
          recommendation: topRecommendation,
          onSeeAllPressed: () => context.go('/plan/smart-eat'),
          onTap: () => context.go('/plan/smart-eat'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDesktopLayout({
    required BuildContext context,
    required MealPlanEntity plan,
    required NextMealSelection selection,
    required List<dynamic> orderedMeals,
    required int goalsTargetCalories,
    required dynamic topRecommendation,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Hero + Progress + CTA)
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanNextMealHero(
                selection: selection,
                onTap: () => context.go('/plan/meals'),
              ),
              const SizedBox(height: 16),
              PlanProgressCard(
                meals: plan.meals,
                selection: selection,
                onViewPlanPressed: () => context.go('/plan/meals'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FitFuelButton(
                  label: 'View Full Meal Plan',
                  icon: Icons.restaurant_menu_rounded,
                  onPressed: () => context.go('/plan/meals'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),

        // Right Column (Macros + Quick Actions + Recommendations)
        Expanded(
          flex: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanMacroSummary(
                plannedProtein: plan.plannedProtein,
                targetProtein: plan.targetProtein > 0 ? plan.targetProtein : 140,
                plannedCarbs: plan.plannedCarbs,
                targetCarbs: plan.targetCarbs > 0 ? plan.targetCarbs : 220,
                plannedFat: plan.plannedFat,
                targetFat: plan.targetFat > 0 ? plan.targetFat : 60,
              ),
              const SizedBox(height: 20),
              const PlanQuickActions(),
              const SizedBox(height: 20),
              PlanRecommendationCard(
                recommendation: topRecommendation,
                onSeeAllPressed: () => context.go('/plan/smart-eat'),
                onTap: () => context.go('/plan/smart-eat'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateContent(
    BuildContext context,
    WidgetRef ref,
    dynamic topRecommendation,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanEmptyState(
          onCreatePlanPressed: () {
            ref.read(mealPlannerControllerProvider.notifier).generatePlan();
            context.go('/plan/meals');
          },
          onSmartEatPressed: () => context.go('/plan/smart-eat'),
        ),
        const SizedBox(height: 22),
        const PlanQuickActions(),
        const SizedBox(height: 22),
        PlanRecommendationCard(
          recommendation: topRecommendation,
          onSeeAllPressed: () => context.go('/plan/smart-eat'),
          onTap: () => context.go('/plan/smart-eat'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSurface : const Color(0xFFEFF4F0),
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: const FitFuelLoadingState(
            label: 'Loading today\'s meal plan...',
            indicatorSize: 24,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSurface : const Color(0xFFEFF4F0),
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref, bool isDark) {
    final theme = Theme.of(context);
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.stateError,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            'Couldn\'t load your meal plan',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          FitFuelButton(
            label: 'Retry',
            onPressed: () => ref
                .read(mealPlannerControllerProvider.notifier)
                .loadTodayPlan(),
          ),
        ],
      ),
    );
  }
}
