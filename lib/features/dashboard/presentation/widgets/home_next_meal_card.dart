import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../../app/navigation/feature_action_navigation.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../meal_planner/domain/entities/planned_meal_entity.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/domain/utils/nutrition_calculator.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../reminders/domain/entities/reminder_entity.dart';
import '../../../reminders/domain/entities/reminder_settings_entity.dart';
import '../../../plan/domain/utils/next_meal_selector.dart';
import '../../../reminders/presentation/providers/reminders_providers.dart';

/// The most useful next item: the first planned meal that has not been logged.
/// Reuses the canonical meal planner, nutrition and routine providers.
class HomeNextMealCard extends ConsumerWidget {
  const HomeNextMealCard({super.key});

  PlannedMealEntity? _nextMeal(
    MealPlanEntity? plan,
    List<NutritionRecordEntity> loggedToday,
    ReminderSettingsEntity? reminderSettings,
  ) {
    if (plan == null) return null;
    final selection = NextMealSelector.determineNextMeal(
      plan: plan,
      loggedToday: loggedToday,
      now: DateTime.now(),
      reminderSettings: reminderSettings,
    );
    return selection.meal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(mealPlannerControllerProvider);
    final logs = ref.watch(nutritionStreamProvider);
    final routine = ref.watch(dailyRoutineProvider);
    final reminderSettings =
        ref.watch(remindersSettingsStreamProvider).valueOrNull;
    final task = routine.nextReminder;
    final loggedToday =
        NutritionCalculator.filterByDay(logs.value ?? [], DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelSectionHeader(
          title: 'Up Next',
          actionLabel: 'View Meal Plan >',
          onActionPressed: () => context.go('/plan/meals'),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        if (planAsync.isLoading)
          const FitFuelCard(
            child: FitFuelLoadingState(
                label: 'Loading your meal plan', indicatorSize: 20),
          )
        else if (planAsync.hasError)
          FitFuelErrorState(
            error: planAsync.error!,
            onRetry: () =>
                ref.read(mealPlannerControllerProvider.notifier).loadTodayPlan(),
          )
        else
          _buildPlan(_nextMeal(planAsync.value, loggedToday, reminderSettings)),
        if (task != null) ...[
          const SizedBox(height: AppConstants.spaceSmd),
          _NextRoutineRow(task: task, routine: routine),
        ],
      ],
    );
  }

  Widget _buildPlan(PlannedMealEntity? meal) {
    if (meal == null) return const _NoMealCard();
    return _MealCard(meal: meal);
  }
}

class _MealCard extends StatelessWidget {
  final PlannedMealEntity meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lead = meal.foods.isEmpty ? null : meal.foods.first.food;
    final dishName = lead?.name ?? '${meal.mealType} plan';
    final extra = meal.foods.length - 1;
    return FitFuelCard(
      padding: EdgeInsets.zero,
      elevation: AppConstants.elevationOverlay,
      semanticsLabel: 'Next meal: ${meal.mealType}, $dishName',
      onTap: () => context.go('/plan/meals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              FoodImageCard(
                food: lead,
                imageSource: null,
                aspectRatio: 16 / 9,
                borderRadius: 0,
                semanticDescription:
                    lead == null ? 'Meal photograph' : 'Photo of $dishName',
              ),
              // Scrim for legibility of overlaid chips on photography.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .45),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: .25),
                      ],
                      stops: const [0, .35, .6, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppConstants.spaceSmd,
                left: AppConstants.spaceSmd,
                right: AppConstants.spaceSmd,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceSm,
                          vertical: AppConstants.space2Xs),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_mealIcon(meal.mealType),
                              size: 14, color: Colors.white),
                          const SizedBox(width: AppConstants.space2Xs),
                          Text(
                            meal.mealType,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceSm,
                          vertical: AppConstants.space2Xs),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        '${meal.totalCalories.round()} kcal',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dishName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Icon(Icons.local_fire_department_outlined,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppConstants.space2Xs),
                    Text('${meal.totalCalories.round()} kcal',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(width: AppConstants.spaceMd),
                    Icon(Icons.fitness_center_outlined,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppConstants.space2Xs),
                    Text('${meal.totalProtein.round()}g protein',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (extra > 0) ...[
                      const SizedBox(width: AppConstants.spaceMd),
                      Flexible(
                        child: Text(
                          '+$extra more item${extra == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSmd),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'View Meal Plan',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _mealIcon(String mealType) {
    final t = mealType.toLowerCase();
    if (t.contains('break')) return Icons.wb_twilight_outlined;
    if (t.contains('lunch')) return Icons.wb_sunny_outlined;
    if (t.contains('dinner')) return Icons.nightlight_outlined;
    return Icons.restaurant_outlined;
  }
}

class _NoMealCard extends StatelessWidget {
  const _NoMealCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Realistic Healthy Food Bowl Photo (Right side, partly cropped)
            Positioned(
              bottom: -15,
              right: -15,
              child: IgnorePointer(
                child: SizedBox(
                  width: 145,
                  height: 145,
                  child: Image.asset(
                    'assets/decorations/food_bowl_healthy.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkPrimaryContainer
                              : AppColors.softSage,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 22,
                            color: AppColors.primaryLeafGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No meals planned yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.primaryText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Create a plan to see your next meal here.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/plan/meals'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLeafGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Meal Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextRoutineRow extends StatelessWidget {
  final ReminderEntity task;
  final DailyRoutineEntity routine;
  const _NextRoutineRow({required this.task, required this.routine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusControl),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.go(reminderLocation(task)),
        borderRadius: BorderRadius.circular(AppConstants.radiusControl),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppConstants.minTouchTargetSize),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceSm, vertical: AppConstants.spaceSm),
            child: Row(
              children: [
                Icon(Icons.checklist_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: AppConstants.spaceSm),
                Expanded(
                  child: Text(
                    '${routine.nextReminder?.scheduledTime ?? ''} · ${task.title}'
                        .trim(),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
