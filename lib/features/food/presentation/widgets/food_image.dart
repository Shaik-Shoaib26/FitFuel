import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/food_entity.dart';

class FoodImage extends StatelessWidget {
  final FoodEntity food;
  final double? width;
  final double? height;
  final double borderRadius;

  const FoodImage({
    super.key,
    required this.food,
    this.width,
    this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = food.imageAsset;

    Widget buildPlaceholder() {
      final category = food.category.toLowerCase();
      Color bgColor;
      IconData icon;

      if (category.contains('fruit')) {
        bgColor = Colors.red[100]!;
        icon = Icons.eco_rounded;
      } else if (category.contains('vegetable')) {
        bgColor = Colors.green[100]!;
        icon = Icons.spa_rounded;
      } else if (category.contains('breakfast')) {
        bgColor = Colors.orange[100]!;
        icon = Icons.breakfast_dining_rounded;
      } else if (category.contains('lunch') || category.contains('dinner')) {
        bgColor = Colors.deepOrange[100]!;
        icon = Icons.dinner_dining_rounded;
      } else if (category.contains('snack')) {
        bgColor = Colors.amber[100]!;
        icon = Icons.fastfood_rounded;
      } else if (category.contains('dairy')) {
        bgColor = Colors.blue[100]!;
        icon = Icons.water_drop_rounded;
      } else if (category.contains('protein')) {
        bgColor = Colors.red[200]!;
        icon = Icons.kebab_dining_rounded;
      } else if (category.contains('beverage')) {
        bgColor = Colors.teal[100]!;
        icon = Icons.local_cafe_rounded;
      } else if (category.contains('dessert')) {
        bgColor = Colors.pink[100]!;
        icon = Icons.icecream_rounded;
      } else if (category.contains('grain')) {
        bgColor = Colors.brown[100]!;
        icon = Icons.grass_rounded;
      } else if (category.contains('legume')) {
        bgColor = Colors.yellow[200]!;
        icon = Icons.lens_blur_rounded;
      } else if (category.contains('nuts') || category.contains('seeds')) {
        bgColor = Colors.brown[200]!;
        icon = Icons.grain_rounded;
      } else {
        bgColor = AppColors.primary500.withAlpha(20);
        icon = Icons.restaurant_rounded;
      }

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          icon,
          size: (height != null) ? height! * 0.4 : 24,
          color: AppColors.primary500,
        ),
      );
    }

    if (imagePath == null || imagePath.trim().isEmpty) {
      return buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return buildPlaceholder();
        },
      ),
    );
  }
}
