import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/food_entity.dart';
import '../../data/repositories/food_asset_repository.dart';

/// Recipe quantities describe the original recipe, independently of log portions.
class RecipeSections extends StatelessWidget {
  final FoodEntity food;
  const RecipeSections({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    final assetRecipe = FoodAssetRepository.instance.getRecipe(food.id);
    final ingredients = (food.ingredients?.isNotEmpty ?? false)
        ? food.ingredients!
        : assetRecipe?.ingredients
                .map((item) => '${item.baseAmount} ${item.unit} ${item.name}')
                .toList() ??
            const <String>[];
    final steps = (food.instructions?.isNotEmpty ?? false)
        ? food.instructions!
        : assetRecipe?.instructions ?? const <String>[];
    if (ingredients.isEmpty && steps.isEmpty && (food.recipe ?? '').isEmpty) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final servings = food.servings ?? assetRecipe?.baseServings;
    final prepTime = food.prepTimeMinutes ?? assetRecipe?.prepTimeMinutes;
    final cookTime = food.cookTimeMinutes ?? assetRecipe?.cookTimeMinutes;
    final difficulty = food.difficulty ?? assetRecipe?.difficulty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recipe header card
          FitFuelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: AppConstants.spaceSm),
                    Text('Recipe', style: text.titleLarge),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSmd),
                // Recipe metadata chips
                Wrap(spacing: AppConstants.spaceSm, runSpacing: AppConstants.spaceSm, children: [
                  if (servings != null)
                    _RecipeChip(
                        icon: Icons.people_outline_rounded,
                        label: 'Makes $servings servings'),
                  if (prepTime != null)
                    _RecipeChip(
                        icon: Icons.timer_outlined,
                        label: 'Prep $prepTime min'),
                  if (cookTime != null)
                    _RecipeChip(
                        icon: Icons.whatshot_outlined,
                        label: 'Cook $cookTime min'),
                  if (difficulty != null)
                    _RecipeChip(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: difficulty),
                ]),
                const SizedBox(height: AppConstants.spaceSmd),
                Text(
                    'Recipe quantities stay fixed when you adjust your food log portion.',
                    style: text.bodySmall),
              ],
            ),
          ),

          // Ingredients
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceMd),
            FitFuelCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppConstants.spaceMd, AppConstants.spaceMd,
                        AppConstants.spaceMd, AppConstants.spaceSm),
                    child: Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: AppConstants.spaceSm),
                        Expanded(child: Text('Ingredients', style: text.titleSmall)),
                        const SizedBox(width: AppConstants.spaceSm),
                        Text('${ingredients.length} items',
                            style: text.bodySmall),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  for (int i = 0; i < ingredients.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: AppConstants.spaceMd,
                          color: scheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceMd,
                          vertical: AppConstants.spaceSmd),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceSmd),
                          Expanded(
                            child: Text(ingredients[i],
                                style: text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Instructions
          if (steps.isNotEmpty || (food.recipe ?? '').isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceMd),
            FitFuelCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppConstants.spaceMd, AppConstants.spaceMd,
                        AppConstants.spaceMd, AppConstants.spaceSm),
                    child: Row(
                      children: [
                        Icon(Icons.format_list_numbered_rounded,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: AppConstants.spaceSm),
                        Text('Method', style: text.titleSmall),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  if (steps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.spaceMd),
                      child: Text(food.recipe!, style: text.bodyMedium),
                    ),
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: AppConstants.spaceMd,
                          color: scheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceMd,
                          vertical: AppConstants.spaceSmd),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}.',
                                style: text.labelMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceSmd),
                          Expanded(
                              child: Text(steps[i],
                                  style: text.bodyMedium)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RecipeChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}
