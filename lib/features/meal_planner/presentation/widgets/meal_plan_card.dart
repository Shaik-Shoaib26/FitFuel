import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/planned_meal_entity.dart';
import '../controllers/meal_planner_controller.dart';
import 'planned_food_card.dart';

/// Premium Card for a specific planned meal slot (e.g. Breakfast, Lunch, Dinner)
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color getMealTypeColor(String type) {
      return switch (type.toLowerCase()) {
        'breakfast' => AppColors.primary500,
        'lunch' => AppColors.calories,
        'dinner' => AppColors.fat,
        'morning snack' => AppColors.accentCarbs,
        'evening snack' => AppColors.secondary500,
        _ => AppColors.secondary500,
      };
    }

    final mealColor = getMealTypeColor(meal.mealType);

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceSm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: mealColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  meal.mealType.toUpperCase(),
                  style: TextStyle(
                    color: mealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(mealPlannerControllerProvider.notifier)
                      .regenerateMeal(meal);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Regenerate'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),

          // Meal Macro Summary Line
          Wrap(
            spacing: AppConstants.spaceSm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${meal.totalCalories.round()} kcal',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'P: ${meal.totalProtein.round()}g',
                style: const TextStyle(
                  color: AppColors.protein,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'C: ${meal.totalCarbs.round()}g',
                style: const TextStyle(
                  color: AppColors.carbs,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'F: ${meal.totalFat.round()}g',
                style: const TextStyle(
                  color: AppColors.fat,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
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
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Text(
                'No foods planned for this meal.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
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
