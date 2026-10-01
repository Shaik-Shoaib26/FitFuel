import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';

/// Premium Healthy Swaps Section for Smart Eat
class SmartSwapCard extends StatelessWidget {
  final SmartFoodRecommendationEntity original;
  final List<SmartFoodRecommendationEntity> swaps;
  final Function(SmartFoodRecommendationEntity) onSelectSwap;

  const SmartSwapCard({
    super.key,
    required this.original,
    required this.swaps,
    required this.onSelectSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healthy Swaps',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        if (swaps.isEmpty)
          Text(
            'No compatible swaps found based on current macros.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: swaps.length,
              itemBuilder: (context, index) {
                final swap = swaps[index];
                final foodEntity = FoodEntity(
                  id: swap.foodId,
                  name: swap.foodName,
                  category: swap.category,
                  servingSize: swap.servingSize,
                  servingUnit: 'g',
                  calories: swap.calories,
                  protein: swap.protein,
                  carbohydrates: swap.carbs,
                  fats: swap.fat,
                  fiber: swap.fiber,
                  sugar: 0,
                  sodium: 0,
                  imageAsset: swap.imageUrl.isNotEmpty ? swap.imageUrl : null,
                  isFavorite: swap.isFavorite,
                );

                return Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: AppConstants.spaceSm),
                  child: FitFuelCard(
                    onTap: () => onSelectSwap(swap),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              FoodImageCard(
                                food: foodEntity,
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary500,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${swap.matchScore}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppConstants.spaceSm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                swap.foodName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${swap.calories.round()} kcal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    'P: ${swap.protein.round()}g',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.protein,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
