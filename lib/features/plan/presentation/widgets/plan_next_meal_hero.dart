import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../domain/utils/next_meal_selector.dart';

/// Reference-accurate Option A Next Meal Hero Card.
/// Dynamically renders the next upcoming meal with full-bleed food photography,
/// dark gradient overlay, "NEXT: <SLOT>" chip, meal title, scheduled time, and calories.
class PlanNextMealHero extends StatelessWidget {
  final NextMealSelection selection;
  final VoidCallback? onTap;

  const PlanNextMealHero({
    super.key,
    required this.selection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meal = selection.meal;
    final leadFood = meal?.foods.firstOrNull?.food;
    final dishName = leadFood?.name ??
        (meal != null ? '${meal.mealType} Plan' : 'Today\'s Meal');

    return Semantics(
      button: true,
      label: 'Next meal: ${selection.mealSlot}, $dishName at ${selection.scheduledTime}, ${selection.calories.round()} calories',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Container(
          key: ValueKey('hero_${selection.mealSlot}_${selection.isNextDay}_${dishName}_${selection.calories}'),
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF17231D),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Food Photography
              if (leadFood != null)
                FoodImageCard(
                  food: leadFood,
                  aspectRatio: null,
                  borderRadius: 0,
                  fit: BoxFit.cover,
                  semanticDescription: 'Photo of $dishName',
                )
              else
                Image.asset(
                  'assets/decorations/food_bowl_healthy.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF1E2D24),
                  ),
                ),

              // Gradient Overlay (concentrated towards bottom & left)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Content Over Image
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top-Left Slot Chip
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLeafGreen,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          selection.displaySlot,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                    // Lower-Left Meal Details
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dishName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFFDDEFE3),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              selection.scheduledTime,
                              style: const TextStyle(
                                color: Color(0xFFFAFBF7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 15,
                              color: Color(0xFFFF8A34),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${selection.calories.round()} kcal',
                              style: const TextStyle(
                                color: Color(0xFFFAFBF7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tappable Ink Overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
