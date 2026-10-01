import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../meal_planner/domain/entities/planned_meal_entity.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Premium Plan Hub — Planning command center connecting Meal Planner, Smart Eat,
/// Recipes, Grocery, Pantry, and Daily Routine.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final planState = ref.watch(mealPlannerControllerProvider);
    final nutritionRecords =
        ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    final networkStatus =
        ref.watch(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    final today = DateTime.now();
    final todayLogs =
        NutritionCalculator.filterByDay(nutritionRecords, today);

    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Plan')),
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            if (isOffline) return;
            await ref
                .read(mealPlannerControllerProvider.notifier)
                .loadTodayPlan();
          },
          child: SingleChildScrollView(
            key: const PageStorageKey('plan-scroll'),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            physics: const AlwaysScrollableScrollPhysics(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;

                final mainColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPlanHero(
                      context,
                      ref,
                      planState,
                      todayLogs,
                      goals?.dailyCalorieTarget ?? 2000,
                      isDark,
                      isOffline,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),
                    _buildPrimaryWorkspaces(context, isDark, planState.valueOrNull),
                  ],
                );

                final sideColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRecipeDiscoveryCard(context, isDark),
                    const SizedBox(height: AppConstants.spaceLg),
                    _buildSupportingToolsSection(
                      context,
                      isDark,
                    ),
                  ],
                );

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: mainColumn),
                      const SizedBox(width: AppConstants.spaceLg),
                      Expanded(flex: 8, child: sideColumn),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      mainColumn,
                      const SizedBox(height: AppConstants.spaceLg),
                      sideColumn,
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanHero(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<MealPlanEntity?> planState,
    List<NutritionRecordEntity> todayLogs,
    int dailyCalorieTarget,
    bool isDark,
    bool isOffline,
  ) {
    final theme = Theme.of(context);

    if (isOffline) {
      return FitFuelCard(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.stateWarning),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Offline Mode',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to the internet to load or generate your daily meal plan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return planState.when(
      loading: () => const FitFuelCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
          child: FitFuelLoadingState(
            label: 'Loading today\'s meal plan...',
            indicatorSize: 24,
          ),
        ),
      ),
      error: (err, _) => FitFuelCard(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.stateError),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              'Plan Unavailable',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Could not load your plan. Please try again.',
              style: theme.textTheme.bodyMedium,
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
      ),
      data: (plan) {
        if (plan == null) {
          return _buildNoPlanHeroCard(context, ref, isDark);
        }

        // Find next uncompleted meal in the plan
        final completedMealTypes = todayLogs
            .map((r) => r.mealType.toLowerCase())
            .toSet();
        PlannedMealEntity? nextMeal;
        for (final m in plan.meals) {
          if (!completedMealTypes.contains(m.mealType.toLowerCase())) {
            nextMeal = m;
            break;
          }
        }

        return _buildActivePlanHeroCard(
          context,
          ref,
          plan,
          nextMeal,
          isDark,
        );
      },
    );
  }

  Widget _buildNoPlanHeroCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    color: AppColors.primary500, size: 24),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Plan Ready to Create',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get tailored meals built around your calories and macros.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceLg),
          Row(
            children: [
              Expanded(
                child: FitFuelButton(
                  label: 'Generate Meal Plan',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () {
                    ref
                        .read(mealPlannerControllerProvider.notifier)
                        .generatePlan();
                    context.go('/plan/meals');
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              OutlinedButton(
                onPressed: () => context.go('/plan/smart-eat'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppConstants.minTouchTargetSize),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                  ),
                ),
                child: const Text('Smart Eat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlanHeroCard(
    BuildContext context,
    WidgetRef ref,
    MealPlanEntity plan,
    PlannedMealEntity? nextMeal,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final leadFood = nextMeal?.foods.firstOrNull?.food;
    final dishName = leadFood?.name ?? (nextMeal != null ? '${nextMeal.mealType} plan' : 'All meals logged');

    return FitFuelCard(
      padding: EdgeInsets.zero,
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.primary100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leadFood != null)
            Stack(
              children: [
                FoodImageCard(
                  food: leadFood,
                  aspectRatio: 21 / 9,
                  borderRadius: 0,
                  semanticDescription: 'Photo of $dishName',
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppConstants.spaceSm,
                  left: AppConstants.spaceSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceSm,
                      vertical: AppConstants.space2Xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: Text(
                      'NEXT: ${nextMeal?.mealType.toUpperCase() ?? "MEAL"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: AppConstants.spaceSm,
                  left: AppConstants.spaceMd,
                  right: AppConstants.spaceMd,
                  child: Text(
                    dishName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          Padding(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Plan Status',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${plan.meals.length} meals planned • ${plan.plannedCalories.round()} kcal total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceSm,
                        vertical: AppConstants.space2Xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        '${(plan.targetCalories - plan.plannedCalories).abs().round()} kcal ${plan.plannedCalories > plan.targetCalories ? "over" : "buffer"}',
                        style: const TextStyle(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Wrap(
                  spacing: AppConstants.spaceXs,
                  runSpacing: AppConstants.spaceXs,
                  children: [
                    _buildMacroPill('Protein', '${plan.plannedProtein.round()}g', AppColors.protein, isDark),
                    _buildMacroPill('Carbs', '${plan.plannedCarbs.round()}g', AppColors.carbs, isDark),
                    _buildMacroPill('Fat', '${plan.plannedFat.round()}g', AppColors.fat, isDark),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: FitFuelButton(
                        label: 'View Meal Plan',
                        icon: Icons.restaurant_menu_rounded,
                        onPressed: () => context.go('/plan/meals'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/plan/smart-eat'),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Smart Eat'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppConstants.minTouchTargetSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                        ),
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
  }

  Widget _buildMacroPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceSm,
        vertical: AppConstants.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryWorkspaces(
    BuildContext context,
    bool isDark,
    MealPlanEntity? plan,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FitFuelSectionHeader(
          title: 'Planning Workspaces',
          subtitle: 'Choose meals, get recommendations, and view balanced recipes.',
        ),
        const SizedBox(height: AppConstants.spaceMd),
        _buildWorkspaceCard(
          context: context,
          title: 'Meal Planner',
          description: plan != null
              ? '${plan.meals.length} meals scheduled • ${plan.plannedCalories.round()} kcal planned today.'
              : 'Structure your daily meal slots, swap foods, and adjust portion sizes.',
          icon: Icons.restaurant_menu_rounded,
          badgeText: plan != null ? 'Active Plan' : 'Customizable',
          badgeColor: AppColors.primary500,
          onTap: () => context.go('/plan/meals'),
          isDark: isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildWorkspaceCard(
          context: context,
          title: 'Smart Eat',
          description:
              'Find food recommendations tailored to close your protein, calorie, and macro gaps.',
          icon: Icons.auto_awesome_rounded,
          badgeText: 'AI Powered',
          badgeColor: AppColors.ai,
          onTap: () => context.go('/plan/smart-eat'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildWorkspaceCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return FitFuelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppConstants.spaceXs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceSm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildRecipeDiscoveryCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return FitFuelCard(
      onTap: () => context.go('/nutrition/search?view=recipes'),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      border: BorderSide(
        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentCarbs.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentCarbs,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipe Library',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore nutritious recipes with prep times and ingredients.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Step-by-step methods with scalable portions for easy cooking.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportingToolsSection(
    BuildContext context,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FitFuelSectionHeader(
          title: 'Supporting Tools',
          subtitle: 'Manage kitchen ingredients and your schedule.',
        ),
        const SizedBox(height: AppConstants.spaceMd),
        _buildSupportingToolTile(
          context: context,
          title: 'Grocery List',
          subtitle: 'Auto-generate shopping items from your meal plan.',
          icon: Icons.shopping_basket_outlined,
          onTap: () => context.go('/plan/grocery'),
          isDark: isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildSupportingToolTile(
          context: context,
          title: 'Pantry Stock',
          subtitle: 'Track foods already in your kitchen for Smart Eat matching.',
          icon: Icons.kitchen_outlined,
          onTap: () => context.go('/plan/grocery/pantry'),
          isDark: isDark,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        _buildSupportingToolTile(
          context: context,
          title: 'Daily Routine',
          subtitle: 'Hydration and meal timing reminders.',
          icon: Icons.checklist_rounded,
          onTap: () => context.go('/plan/routine'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSupportingToolTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return FitFuelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary500, size: 22),
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
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
        ],
      ),
    );
  }
}
