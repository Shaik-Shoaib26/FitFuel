import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../domain/entities/planned_meal_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';

/// Premium Food Row/Card inside a Planned Meal
class PlannedFoodCard extends StatelessWidget {
  final PlannedFoodEntity plannedFood;
  final String mealType;
  final VoidCallback onSwap;
  final Function(double)? onScale;

  const PlannedFoodCard({
    super.key,
    required this.plannedFood,
    required this.mealType,
    required this.onSwap,
    this.onScale,
  });

  void _addToFoodLog(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final dummyRecord = NutritionRecordEntity(
      id: '',
      foodName: plannedFood.food.name,
      mealType: mealType,
      calories: plannedFood.calories,
      protein: plannedFood.protein,
      carbohydrates: plannedFood.carbohydrates,
      fats: plannedFood.fat,
      sugar: (plannedFood.food.sugar / (plannedFood.food.servingSize > 0 ? plannedFood.food.servingSize : 1)) *
          plannedFood.servingQuantity,
      servingSize: plannedFood.servingQuantity,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodFormSheet(
        uid: uid,
        existingRecord: dummyRecord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: SizedBox(
              width: 76,
              height: 76,
              child: FoodImageCard(
                food: plannedFood.food,
                width: 76,
                height: 76,
                borderRadius: AppConstants.radiusSm,
                semanticDescription: 'Photo of ${plannedFood.food.name}',
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceMd),

          // Food Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plannedFood.food.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${plannedFood.servingQuantity.round()} ${plannedFood.unit} • ${plannedFood.calories.round()} kcal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildMacroBadge('P: ${plannedFood.protein.round()}g', AppColors.protein),
                    _buildMacroBadge('C: ${plannedFood.carbohydrates.round()}g', AppColors.carbs),
                    _buildMacroBadge('F: ${plannedFood.fat.round()}g', AppColors.fat),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary500, size: 22),
                tooltip: 'Log Food',
                visualDensity: VisualDensity.compact,
                onPressed: () => _addToFoodLog(context),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.primary500, size: 22),
                tooltip: 'Swap Alternative',
                visualDensity: VisualDensity.compact,
                onPressed: onSwap,
              ),
              if (onScale != null)
                PopupMenuButton<double>(
                  icon: const Icon(Icons.tune_rounded,
                      color: AppColors.primary500, size: 20),
                  tooltip: 'Adjust Portion',
                  padding: EdgeInsets.zero,
                  onSelected: onScale,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x Portion')),
                    const PopupMenuItem(value: 0.75, child: Text('0.75x Portion')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x Portion')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x Portion')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x Portion')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0x Portion')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
