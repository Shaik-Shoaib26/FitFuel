import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/food_form_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      sugar: (plannedFood.food.sugar / plannedFood.food.servingSize) * plannedFood.servingQuantity,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: SizedBox(
              width: 64,
              height: 64,
              child: FoodImageCard(
                food: plannedFood.food,
                width: 64,
                height: 64,
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
                  style: AppTypography.bodyLarge(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plannedFood.servingQuantity.toStringAsFixed(0)} ${plannedFood.unit} • ${plannedFood.calories.toStringAsFixed(0)} kcal',
                  style: AppTypography.caption(isDark: isDark),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMacroBadge('P: ${plannedFood.protein.toStringAsFixed(1)}g', AppColors.protein),
                    const SizedBox(width: 8),
                    _buildMacroBadge('C: ${plannedFood.carbohydrates.toStringAsFixed(1)}g', AppColors.carbs),
                    const SizedBox(width: 8),
                    _buildMacroBadge('F: ${plannedFood.fat.toStringAsFixed(1)}g', AppColors.fat),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary500),
                tooltip: 'Add to Food Log',
                onPressed: () => _addToFoodLog(context),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: AppColors.primary500),
                tooltip: 'Swap Food',
                onPressed: onSwap,
              ),
              if (onScale != null)
                PopupMenuButton<double>(
                  icon: const Icon(Icons.edit, color: AppColors.primary500),
                  tooltip: 'Adjust Portion',
                  onSelected: onScale,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5 serving')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0 serving')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5 servings')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0 servings')),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
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
