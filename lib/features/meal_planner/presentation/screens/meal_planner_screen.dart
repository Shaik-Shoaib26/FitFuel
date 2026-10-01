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
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../grocery/domain/entities/grocery_preferences_entity.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/meal_plan_entity.dart';
import '../../domain/entities/planned_meal_entity.dart';
import '../controllers/meal_planner_controller.dart';
import '../widgets/meal_macro_summary.dart';
import '../widgets/meal_plan_card.dart';

/// Premium Meal Planner Screen — Daily meal slots, food swaps, portion adjustments,
/// and grocery integration.
class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  void _showSwapBottomSheet(
    BuildContext context,
    WidgetRef ref,
    PlannedMealEntity meal,
    PlannedFoodEntity foodToSwap,
  ) async {
    final networkStatus =
        ref.read(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection is required for this action.'),
          backgroundColor: AppColors.stateError,
        ),
      );
      return;
    }
    final notifier = ref.read(mealPlannerControllerProvider.notifier);
    final alternatives = await notifier.getSwapAlternatives(meal, foodToSwap);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLg),
              ),
            ),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Swap ${foodToSwap.food.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  Text(
                    'Select a balanced alternative matching ${meal.mealType}:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceMd),
                  if (alternatives.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spaceXl,
                      ),
                      child: Text(
                        'No matching alternatives found for this meal type.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: alternatives.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppConstants.spaceSm),
                        itemBuilder: (context, index) {
                          final alt = alternatives[index];
                          return FitFuelCard(
                            onTap: () {
                              notifier.replaceFoodInMeal(
                                  meal, foodToSwap, alt);
                              Navigator.pop(context);
                            },
                            padding: const EdgeInsets.all(AppConstants.spaceSm),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusSm),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: FoodImageCard(
                                      food: alt.food,
                                      width: 56,
                                      height: 56,
                                      borderRadius: AppConstants.radiusSm,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alt.food.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${alt.servingQuantity.round()} ${alt.unit} • ${alt.calories.round()} kcal • P: ${alt.protein.round()}g',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: AppColors.primary500,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final planState = ref.watch(mealPlannerControllerProvider);
    final nutritionRecords =
        ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    final profile = ref.watch(currentProfileStreamProvider).valueOrNull;
    final networkStatus =
        ref.watch(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    bool checkOnline() {
      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internet connection is required for this action.'),
            backgroundColor: AppColors.stateError,
          ),
        );
        return false;
      }
      return true;
    }

    return Scaffold(
      appBar: const FitFuelAppBar(
        title: Text('Today\'s Meal Plan'),
      ),
      body: AdaptivePageLayout(
        child: isOffline
            ? FitFuelErrorState(
                error: 'offline',
                messageOverride:
                    'Internet connection required to load Meal Plan.',
                onRetry: () {
                  ref
                      .read(mealPlannerControllerProvider.notifier)
                      .loadTodayPlan();
                },
              )
            : planState.when(
                loading: () => const Center(
                  child: FitFuelLoadingState(
                    label: 'Loading today\'s meal plan...',
                  ),
                ),
                error: (err, stack) => FitFuelErrorState(
                  error: err,
                  messageOverride:
                      'Unable to load your meal plan. ${err.toString().replaceAll('Exception: ', '')}',
                  onRetry: () {
                    ref
                        .read(mealPlannerControllerProvider.notifier)
                        .loadTodayPlan();
                  },
                ),
                data: (plan) {
                  if (profile == null ||
                      !profile.isProfileComplete ||
                      goals == null) {
                    return _buildEmptyProfileState(context);
                  }

                  if (plan == null) {
                    return _buildNoPlanState(context, ref);
                  }

                  final today = DateTime.now();
                  final dailyRecords =
                      NutritionCalculator.filterByDay(nutritionRecords, today);
                  final progress = NutritionCalculator.calculateProgress(
                    dailyRecords: dailyRecords,
                    goals: goals,
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      if (!checkOnline()) return;
                      await ref
                          .read(mealPlannerControllerProvider.notifier)
                          .loadTodayPlan();
                    },
                    child: SingleChildScrollView(
                      key: const PageStorageKey('meal-planner-scroll'),
                      padding: const EdgeInsets.all(AppConstants.spaceMd),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MealMacroSummary(plan: plan, progress: progress),
                          const SizedBox(height: AppConstants.spaceMd),
                          _buildPlannedProgressSummary(
                              context, plan, isDark),
                          const SizedBox(height: AppConstants.spaceLg),
                          LayoutBuilder(builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth >= 900 ? 2 : 1;
                            if (columns == 1) {
                              return Column(
                                children: plan.meals
                                    .map((meal) => MealPlanCard(
                                          meal: meal,
                                          onSwap: (food) =>
                                              _showSwapBottomSheet(
                                                  context, ref, meal, food),
                                          onScale: (food, scale) => ref
                                              .read(
                                                  mealPlannerControllerProvider
                                                      .notifier)
                                              .updateServingMultiplier(
                                                  meal, food, scale),
                                        ))
                                    .toList(),
                              );
                            }

                            final leftCol = <Widget>[];
                            final rightCol = <Widget>[];
                            for (int i = 0; i < plan.meals.length; i++) {
                              final meal = plan.meals[i];
                              final card = MealPlanCard(
                                meal: meal,
                                onSwap: (food) => _showSwapBottomSheet(
                                    context, ref, meal, food),
                                onScale: (food, scale) => ref
                                    .read(mealPlannerControllerProvider
                                        .notifier)
                                    .updateServingMultiplier(
                                        meal, food, scale),
                              );
                              if (i.isEven) {
                                leftCol.add(card);
                              } else {
                                rightCol.add(card);
                              }
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(children: leftCol)),
                                const SizedBox(
                                    width: AppConstants.spaceMd),
                                Expanded(
                                    child: Column(children: rightCol)),
                              ],
                            );
                          }),
                          const SizedBox(height: AppConstants.spaceLg),
                          _buildActionButtonsSection(
                              context, ref, plan, checkOnline),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPlannedProgressSummary(
    BuildContext context,
    MealPlanEntity plan,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final calPercent = plan.targetCalories > 0
        ? (plan.plannedCalories / plan.targetCalories).clamp(0.0, 2.0)
        : 0.0;
    final proPercent = plan.targetProtein > 0
        ? (plan.plannedProtein / plan.targetProtein).clamp(0.0, 2.0)
        : 0.0;
    final carbPercent = plan.targetCarbs > 0
        ? (plan.plannedCarbs / plan.targetCarbs).clamp(0.0, 2.0)
        : 0.0;
    final fatPercent = plan.targetFat > 0
        ? (plan.plannedFat / plan.targetFat).clamp(0.0, 2.0)
        : 0.0;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planned vs Target Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          _buildPlannedRow(
            context,
            'Calories',
            '${plan.plannedCalories.round()} / ${plan.targetCalories.round()} kcal',
            calPercent,
            AppColors.primary500,
            isDark,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          _buildPlannedRow(
            context,
            'Protein',
            '${plan.plannedProtein.round()} / ${plan.targetProtein.round()} g',
            proPercent,
            AppColors.protein,
            isDark,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          _buildPlannedRow(
            context,
            'Carbs',
            '${plan.plannedCarbs.round()} / ${plan.targetCarbs.round()} g',
            carbPercent,
            AppColors.carbs,
            isDark,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          _buildPlannedRow(
            context,
            'Fat',
            '${plan.plannedFat.round()} / ${plan.targetFat.round()} g',
            fatPercent,
            AppColors.fat,
            isDark,
          ),
          if (plan.plannedCalories > plan.targetCalories) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.stateError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.stateError, size: 18),
                  SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child: Text(
                      'Planned calories slightly exceed your daily target.',
                      style: TextStyle(
                        color: AppColors.stateError,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannedRow(
    BuildContext context,
    String label,
    String valueText,
    double percent,
    Color color,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection(
    BuildContext context,
    WidgetRef ref,
    MealPlanEntity plan,
    bool Function() checkOnline,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelButton(
          label: 'Get Smart Recommendation',
          icon: Icons.auto_awesome_rounded,
          onPressed: () => context.go('/plan/smart-eat'),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Regenerate Plan'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppConstants.minTouchTargetSize),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusControl),
            ),
          ),
          onPressed: () {
            if (!checkOnline()) return;
            ref.read(mealPlannerControllerProvider.notifier).generatePlan();
          },
        ),
        const SizedBox(height: AppConstants.spaceSm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shopping_basket_outlined, size: 18),
                label: const Text('Add to Grocery'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppConstants.minTouchTargetSize),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                  ),
                ),
                onPressed: () {
                  if (!checkOnline()) return;
                  final pantry =
                      ref.read(pantryProvider).valueOrNull ?? const [];
                  final prefs = ref.read(groceryPreferencesProvider).valueOrNull ??
                      const GroceryPreferencesEntity();
                  ref
                      .read(groceryControllerProvider.notifier)
                      .generateGroceryList(
                        mealPlans: [plan],
                        pantryItems: pantry,
                        preferences: prefs,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Plan ingredients added to grocery list!'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Weekly List'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppConstants.minTouchTargetSize),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                  ),
                ),
                onPressed: () {
                  if (!checkOnline()) return;
                  final pantry =
                      ref.read(pantryProvider).valueOrNull ?? const [];
                  final prefs = ref.read(groceryPreferencesProvider).valueOrNull ??
                      const GroceryPreferencesEntity();
                  ref
                      .read(groceryControllerProvider.notifier)
                      .generateGroceryList(
                        mealPlans: [plan],
                        pantryItems: pantry,
                        preferences: prefs,
                        periodEnd:
                            DateTime.now().add(const Duration(days: 7)),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Weekly grocery list generated!'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceXl),
      ],
    );
  }

  Widget _buildEmptyProfileState(BuildContext context) {
    return Center(
      child: FitFuelEmptyState(
        icon: Icons.assignment_ind_outlined,
        title: 'Complete Profile Required',
        description:
            'Set up your health profile and calorie targets to unlock personalized meal plans.',
        actionLabel: 'Complete Profile',
        onActionPressed: () => context.go('/profile'),
      ),
    );
  }

  Widget _buildNoPlanState(BuildContext context, WidgetRef ref) {
    return Center(
      child: FitFuelEmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: 'No Meal Plan for Today',
        description:
            'Generate a personalized plan structured around your calories, macros, and dietary preferences.',
        actionLabel: 'Generate Meal Plan',
        onActionPressed: () {
          ref.read(mealPlannerControllerProvider.notifier).generatePlan();
        },
      ),
    );
  }
}
