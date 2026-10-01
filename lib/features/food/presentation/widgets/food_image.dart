import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../domain/entities/food_entity.dart';

/// Compatibility entry point; the shared photo renderer owns presentation.
class FoodImage extends StatelessWidget {
  final FoodEntity food;
  final double? width, height, aspectRatio;
  final double borderRadius;
  const FoodImage(
      {super.key,
      required this.food,
      this.width,
      this.height,
      this.aspectRatio,
      this.borderRadius = AppConstants.radiusImage});
  @override
  Widget build(BuildContext context) => FoodImageCard(
      food: food,
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      borderRadius: borderRadius);
}
