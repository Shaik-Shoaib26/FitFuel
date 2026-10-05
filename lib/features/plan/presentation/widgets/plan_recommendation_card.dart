import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../smart_eat/domain/entities/smart_food_recommendation_entity.dart';

/// Reference-accurate Option A "Today's Recommendations" section.
/// Displays a food thumbnail, category tag, dish name, calorie/protein summary, and navigation to Smart Eat.
class PlanRecommendationCard extends StatelessWidget {
  final SmartFoodRecommendationEntity? recommendation;
  final VoidCallback? onSeeAllPressed;
  final VoidCallback? onTap;

  const PlanRecommendationCard({
    super.key,
    this.recommendation,
    this.onSeeAllPressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rec = recommendation;
    final categoryText = rec != null && rec.tags.isNotEmpty
        ? rec.tags.first
        : (rec?.category.isNotEmpty == true ? rec!.category : 'High Protein Pick');
    final foodName = rec?.foodName ?? 'Healthy Protein Bowl';
    final calories = rec?.calories.round() ?? 450;
    final protein = rec?.protein.round() ?? 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Today\'s Recommendations',
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
              label: 'See all recommendations',
              child: InkWell(
                onTap: onSeeAllPressed ?? () => context.go('/plan/smart-eat'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
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
        const SizedBox(height: 12),

        // Recommendation Item Card
        Semantics(
          button: true,
          label: 'Recommended food: $foodName, $calories calories, $protein grams of protein',
          child: Material(
            color: isDark ? AppColors.darkBgSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap ?? () => context.go('/plan/smart-eat'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Food Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: FoodImageCard(
                          food: rec?.foodName ?? 'Healthy Bowl',
                          borderRadius: 12,
                          fit: BoxFit.cover,
                          semanticDescription: 'Photo of $foodName',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Food Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            foodName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$calories kcal • ${protein}g protein',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF657169),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8A968F),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
