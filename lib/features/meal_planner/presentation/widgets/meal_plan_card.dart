import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/meal_planner/presentation/widgets/planned_food_card.dart';

class MealPlanCard extends ConsumerWidget {
  final PlannedMealEntity meal;
  final Function(PlannedFoodEntity) onSwap;
  final Function(PlannedFoodEntity, double) onScale;

  const MealPlanCard({
    super.key,
    required this.meal,
    required this.onSwap,
    required this.onScale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                meal.mealType.toUpperCase(),
                style: AppTypography.heading3(isDark: isDark).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(mealPlannerControllerProvider.notifier).regenerateMeal(meal);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          
          // Meal Summary
          Row(
            children: [
              Text(
                '${meal.totalCalories.toStringAsFixed(0)} kcal',
                style: AppTypography.bodyLarge(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Text(
                'P: ${meal.totalProtein.toStringAsFixed(1)}g',
                style: AppTypography.bodyMedium(isDark: isDark).copyWith(color: AppColors.protein),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'C: ${meal.totalCarbs.toStringAsFixed(1)}g',
                style: AppTypography.bodyMedium(isDark: isDark).copyWith(color: AppColors.carbs),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'F: ${meal.totalFat.toStringAsFixed(1)}g',
                style: AppTypography.bodyMedium(isDark: isDark).copyWith(color: AppColors.fat),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          
          if (meal.foods.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  width: 1,
                ),
              ),
              child: Text(
                'No foods planned for this meal.',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),
            )
          else
            ...meal.foods.map((food) => PlannedFoodCard(
                  plannedFood: food,
                  mealType: meal.mealType,
                  onSwap: () => onSwap(food),
                  onScale: (scale) => onScale(food, scale),
                )),
        ],
      ),
    );
  }
}
