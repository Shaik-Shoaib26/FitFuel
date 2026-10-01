import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:go_router/go_router.dart';

class DashboardMealPlanCard extends ConsumerWidget {
  const DashboardMealPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planState = ref.watch(mealPlannerControllerProvider);
    final nutritionRecords = ref.watch(nutritionStreamProvider).value ?? [];
    final networkStatus = ref.watch(networkStatusProvider).value ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      border: const BorderSide(color: AppColors.primary, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEAL PLAN',
                style: AppTypography.caption(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.primary500,
                ),
              ),
              const Icon(Icons.restaurant_menu, color: AppColors.primary500),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          
          if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 36),
                  const SizedBox(height: AppConstants.spaceSm),
                  Text(
                    'Internet connection required to load Meal Plan.',
                    style: AppTypography.bodyMedium(isDark: isDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  Text(
                    'Reconnect to view your latest meal plan.',
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spaceMd),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            planState.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppConstants.spaceMd),
                    Text('Loading daily routine plan...'),
                  ],
                ),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
                child: Column(
                  children: [
                    const Text('Meal plan unavailable', style: TextStyle(color: AppColors.stateError)),
                    const SizedBox(height: AppConstants.spaceSm),
                    TextButton(
                      onPressed: () => ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (plan) {
                if (plan == null) {
                  return Column(
                    children: [
                      Text('No plan generated for today.', style: AppTypography.bodyMedium(isDark: isDark)),
                      const SizedBox(height: AppConstants.spaceMd),
                      ElevatedButton(
                        onPressed: () => context.go(AppRoutes.mealPlan),
                        child: const Text('Create Plan'),
                      ),
                    ],
                  );
                }

                // Compute completed meal types based on today's logs
                final today = DateTime.now();
                final todayLogs = nutritionRecords.where((r) {
                  return r.consumedAt.year == today.year &&
                      r.consumedAt.month == today.month &&
                      r.consumedAt.day == today.day;
                }).toList();
                final completedMealTypes = todayLogs.map((l) => l.mealType.toLowerCase()).toSet();

                // Find next uncompleted meal
                PlannedMealEntity? nextMealEntity;
                for (final meal in plan.meals) {
                  if (!completedMealTypes.contains(meal.mealType.toLowerCase())) {
                    nextMealEntity = meal;
                    break;
                  }
                }

                if (nextMealEntity == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎉 All meals logged today!', style: AppTypography.bodyLarge(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppConstants.spaceMd),
                      OutlinedButton(
                        onPressed: () => context.go(AppRoutes.mealPlan),
                        child: const Text('View Meal Plan'),
                      ),
                    ],
                  );
                }

                final foodNamesText = nextMealEntity.foods.map((f) => f.food.name).join(', ');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Meal: ${nextMealEntity.mealType}', style: AppTypography.bodyLarge(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (foodNamesText.isNotEmpty) ...[
                      Text(foodNamesText, style: AppTypography.bodyMedium(isDark: isDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                    ],
                    Text('${nextMealEntity.totalCalories.toStringAsFixed(0)} kcal • P: ${nextMealEntity.totalProtein.toStringAsFixed(1)}g', style: AppTypography.caption(isDark: isDark)),
                    const SizedBox(height: AppConstants.spaceMd),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.mealPlan),
                      child: const Text('View Meal Plan'),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
