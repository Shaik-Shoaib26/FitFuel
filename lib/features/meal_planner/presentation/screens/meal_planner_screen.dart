import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_button.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/meal_planner/presentation/widgets/meal_macro_summary.dart';
import 'package:fitfuel/features/meal_planner/presentation/widgets/meal_plan_card.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_calculator.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:go_router/go_router.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';
import '../../../grocery/domain/entities/grocery_preferences_entity.dart';

class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  void _showSwapBottomSheet(
    BuildContext context,
    WidgetRef ref,
    PlannedMealEntity meal,
    PlannedFoodEntity foodToSwap,
  ) async {
    final notifier = ref.read(mealPlannerControllerProvider.notifier);
    final alternatives = await notifier.getSwapAlternatives(meal, foodToSwap);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Swap ${foodToSwap.food.name}',
                    style: AppTypography.heading3(isDark: isDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (alternatives.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No suitable alternatives found.',
                        style: AppTypography.bodyMedium(isDark: isDark),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: alternatives.length,
                        itemBuilder: (context, index) {
                          final alt = alternatives[index];
                          return ListTile(
                            leading: const Icon(Icons.restaurant, color: AppColors.primary500),
                            title: Text(alt.food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${alt.servingQuantity.toStringAsFixed(0)} ${alt.unit} • ${alt.calories.toStringAsFixed(0)} kcal • P: ${alt.protein.toStringAsFixed(1)}g'),
                            trailing: const Icon(Icons.swap_horiz, color: AppColors.primary500),
                            onTap: () {
                              notifier.replaceFoodInMeal(meal, foodToSwap, alt);
                              Navigator.pop(context);
                            },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final planState = ref.watch(mealPlannerControllerProvider);
    final nutritionRecords = ref.watch(nutritionStreamProvider).value ?? [];
    final goals = ref.watch(nutritionGoalsStreamProvider).value;
    final profile = ref.watch(currentProfileStreamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Meal Plan'),
      ),
      body: planState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(AppConstants.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.stateError),
              const SizedBox(height: AppConstants.spaceLg),
              Text(
                'Unable to generate your meal plan.',
                style: AppTypography.heading2(isDark: isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                style: AppTypography.bodyMedium(isDark: isDark).copyWith(color: AppColors.stateError),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceXl),
              FitFuelButton(
                label: 'Try Again',
                onPressed: () {
                  ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan();
                },
              ),
            ],
          ),
        ),
        data: (plan) {
          if (profile == null || !profile.isProfileComplete || goals == null) {
            return _buildEmptyProfileState(context, isDark);
          }

          if (plan == null) {
            return _buildNoPlanState(context, ref, isDark);
          }

          final today = DateTime.now();
          final dailyRecords = NutritionCalculator.filterByDay(nutritionRecords, today);
          final progress = NutritionCalculator.calculateProgress(
            dailyRecords: dailyRecords,
            goals: goals,
          );

          return RefreshIndicator(
            onRefresh: () => ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan(),
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              children: [
                Text(
                  'Today\'s Meal Plan',
                  style: AppTypography.heading1(isDark: isDark),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                MealMacroSummary(plan: plan, progress: progress),
                const SizedBox(height: AppConstants.spaceLg),
                _buildPlannedProgressSummary(plan, isDark),
                const SizedBox(height: AppConstants.spaceXl),
                ...plan.meals.map((meal) => MealPlanCard(
                      meal: meal,
                      onSwap: (food) => _showSwapBottomSheet(context, ref, meal, food),
                      onScale: (food, scale) => ref
                          .read(mealPlannerControllerProvider.notifier)
                          .updateServingMultiplier(meal, food, scale),
                    )),
                const SizedBox(height: AppConstants.spaceXl),
                FitFuelButton(
                  label: 'Regenerate Plan',
                  onPressed: () {
                    ref.read(mealPlannerControllerProvider.notifier).generatePlan();
                  },
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: FitFuelButton(
                        label: 'Add to Grocery List',
                        icon: Icons.add_shopping_cart,
                        onPressed: () {
                          final pantry = ref.read(pantryProvider).value ?? [];
                          final prefs = ref.read(groceryPreferencesProvider).value ?? const GroceryPreferencesEntity();
                          ref.read(groceryControllerProvider.notifier).generateGroceryList(
                            mealPlans: [plan],
                            pantryItems: pantry,
                            preferences: prefs,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Today\'s meal plan added to grocery list!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: FitFuelButton(
                        label: 'Generate Weekly List',
                        icon: Icons.date_range,
                        onPressed: () {
                          final pantry = ref.read(pantryProvider).value ?? [];
                          final prefs = ref.read(groceryPreferencesProvider).value ?? const GroceryPreferencesEntity();
                          // Simulating weekly lists by duplicating current plan or scaling
                          ref.read(groceryControllerProvider.notifier).generateGroceryList(
                            mealPlans: [plan],
                            pantryItems: pantry,
                            preferences: prefs,
                            periodEnd: DateTime.now().add(const Duration(days: 7)),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Weekly grocery list generated!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceXl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlannedProgressSummary(MealPlanEntity plan, bool isDark) {
    final calPercent = plan.targetCalories > 0 ? (plan.plannedCalories / plan.targetCalories).clamp(0.0, 2.0) : 0.0;
    final proPercent = plan.targetProtein > 0 ? (plan.plannedProtein / plan.targetProtein).clamp(0.0, 2.0) : 0.0;
    final carbPercent = plan.targetCarbs > 0 ? (plan.plannedCarbs / plan.targetCarbs).clamp(0.0, 2.0) : 0.0;
    final fatPercent = plan.targetFat > 0 ? (plan.plannedFat / plan.targetFat).clamp(0.0, 2.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planned vs Target Summary',
            style: AppTypography.bodyLarge(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPlannedRow('Calories', '${plan.plannedCalories.toStringAsFixed(0)} / ${plan.targetCalories.toStringAsFixed(0)} kcal', calPercent, AppColors.primary500, isDark),
          const SizedBox(height: 10),
          _buildPlannedRow('Protein', '${plan.plannedProtein.toStringAsFixed(0)} / ${plan.targetProtein.toStringAsFixed(0)} g', proPercent, AppColors.protein, isDark),
          const SizedBox(height: 10),
          _buildPlannedRow('Carbs', '${plan.plannedCarbs.toStringAsFixed(0)} / ${plan.targetCarbs.toStringAsFixed(0)} g', carbPercent, AppColors.carbs, isDark),
          const SizedBox(height: 10),
          _buildPlannedRow('Fat', '${plan.plannedFat.toStringAsFixed(0)} / ${plan.targetFat.toStringAsFixed(0)} g', fatPercent, AppColors.fat, isDark),
          
          if (plan.plannedCalories > plan.targetCalories) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.stateError.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.stateError, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Planned calories exceed your daily target.',
                      style: AppTypography.caption(isDark: isDark).copyWith(color: AppColors.stateError),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (plan.plannedProtein < plan.targetProtein - 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.stateWarning.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.stateWarning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Protein is slightly below your target.',
                      style: AppTypography.caption(isDark: isDark).copyWith(color: AppColors.stateWarning),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildPlannedRow(String label, String valueText, double percent, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium(isDark: isDark)),
            Text(valueText, style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProfileState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.assignment_ind_outlined, size: 64, color: AppColors.primary500),
          const SizedBox(height: AppConstants.spaceLg),
          Text(
            'Complete Profile Required',
            style: AppTypography.heading2(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Complete your health profile to create a personalized meal plan.',
            style: AppTypography.bodyLarge(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceXl),
          FitFuelButton(
            label: 'Complete Profile',
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlanState(BuildContext context, WidgetRef ref, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.restaurant_menu_rounded, size: 64, color: AppColors.primary500),
          const SizedBox(height: AppConstants.spaceLg),
          Text(
            'No Meal Plan for Today',
            style: AppTypography.heading2(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Generate a personalized meal plan based on your nutrition goals and preferences.',
            style: AppTypography.bodyLarge(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceXl),
          FitFuelButton(
            label: 'Generate Meal Plan',
            onPressed: () {
              ref.read(mealPlannerControllerProvider.notifier).generatePlan();
            },
          ),
        ],
      ),
    );
  }
}
