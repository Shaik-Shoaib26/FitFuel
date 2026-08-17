import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_typography.dart';
import '../../features/food/domain/entities/food_entity.dart';
import 'food_image_resolver.dart';

/// Centralized Premium Food Card Component
class FitFuelFoodCard extends StatelessWidget {
  final FoodEntity food;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;

  const FitFuelFoodCard({
    super.key,
    required this.food,
    this.onTap,
    this.onAddTap,
    this.onFavoriteTap,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Badges array
    List<Widget> badges = [];
    if (food.isIndian) {
      badges.add(_buildBadge('Indian', AppColors.calories));
    }
    if (food.isVegan) {
      badges.add(_buildBadge('Vegan', AppColors.success));
    } else if (food.isVegetarian) {
      badges.add(_buildBadge('Veg', AppColors.success));
    } else {
      badges.add(_buildBadge('Non-Veg', AppColors.error));
    }

    for (final tag in food.dietaryTags.take(1)) {
      badges.add(_buildBadge(tag, AppColors.carbs));
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(12),
      color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        side: BorderSide(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Image with Favorite overlay button
            Stack(
              children: [
                FoodImageCard(
                  food: food,
                  width: double.infinity,
                  height: 120,
                  borderRadius: AppConstants.radiusLg,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark ? Colors.black54 : Colors.white.withAlpha(220),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? AppColors.error : AppColors.lightTextSecondary,
                        size: 18,
                      ),
                      onPressed: onFavoriteTap,
                    ),
                  ),
                ),
              ],
            ),

            // Card Body Details
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading3(isDark: isDark).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  if (badges.isNotEmpty) ...[
                    Wrap(spacing: 4, runSpacing: 4, children: badges),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${food.calories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          color: AppColors.calories,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${food.protein.toStringAsFixed(0)}g protein',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (onAddTap != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onAddTap,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('+ Add to Log', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.primary400 : AppColors.primary500,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
