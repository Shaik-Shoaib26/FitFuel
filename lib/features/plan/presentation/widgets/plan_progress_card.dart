import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../meal_planner/domain/entities/planned_meal_entity.dart';
import '../../domain/utils/next_meal_selector.dart';

/// Reference-accurate Option A "Today's Plan Progress" Card.
/// Displays circular progress ring (completed/total meals) and a compact meal checklist
/// highlighting the current/next meal in soft mint (#E6F4EA).
class PlanProgressCard extends StatelessWidget {
  final List<PlannedMealEntity> meals;
  final NextMealSelection selection;
  final VoidCallback? onViewPlanPressed;

  const PlanProgressCard({
    super.key,
    required this.meals,
    required this.selection,
    this.onViewPlanPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final completedCount = selection.completedCount;
    final totalCount = selection.totalCount > 0 ? selection.totalCount : meals.length;
    final progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Today\'s Plan Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'View meal plan',
                child: InkWell(
                  onTap: onViewPlanPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View plan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ring + Meal List Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 280;

              final ring = SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? AppColors.darkPrimaryContainer
                            : const Color(0xFFDDEFE3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen,
                        ),
                        strokeWidth: 6.5,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$completedCount / $totalCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF17231D),
                          ),
                        ),
                        Text(
                          'meals',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF657169),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final mealList = Column(
                children: meals.map((meal) {
                  final status = selection.statusFor(meal);
                  return _buildMealRow(context, meal, status, isDark);
                }).toList(),
              );

              if (isVeryCompact) {
                return Column(
                  children: [
                    Center(child: ring),
                    const SizedBox(height: 16),
                    mealList,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ring,
                  const SizedBox(width: 18),
                  Expanded(child: mealList),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(
    BuildContext context,
    PlannedMealEntity meal,
    MealStatus status,
    bool isDark,
  ) {
    final isCurrent = status == MealStatus.current;
    final isCompleted = status == MealStatus.completed;
    final isMissed = status == MealStatus.missed;

    Color rowBg = Colors.transparent;
    if (isCurrent) {
      rowBg = isDark
          ? AppColors.darkPrimaryContainer.withValues(alpha: 0.5)
          : const Color(0xFFE6F4EA);
    }

    Widget iconWidget;
    if (isCompleted) {
      iconWidget = const Icon(
        Icons.check_circle_rounded,
        size: 16,
        color: AppColors.primaryLeafGreen,
      );
    } else if (isCurrent) {
      iconWidget = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen,
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          size: 10,
          color: Colors.white,
        ),
      );
    } else {
      iconWidget = Icon(
        Icons.radio_button_unchecked_rounded,
        size: 16,
        color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA0ABA3),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      padding: EdgeInsets.symmetric(
        horizontal: isCurrent ? 8 : 4,
        vertical: isCurrent ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meal.mealType,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                color: isCurrent
                    ? (isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen)
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : (isMissed ? const Color(0xFF8A968F) : const Color(0xFF17231D))),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCurrent
                ? '${meal.totalCalories.round()} kcal'
                : (isCompleted
                    ? '${meal.totalCalories.round()} kcal'
                    : (isMissed ? 'Missed' : '${meal.totalCalories.round()} kcal')),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? (isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen)
                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF657169)),
            ),
          ),
        ],
      ),
    );
  }
}
