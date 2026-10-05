import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/food_asset_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_food_card.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/food_entity.dart';
import '../providers/food_providers.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final String? view;
  const FoodSearchScreen({super.key, this.view});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
    'Indian',
    'Vegetarian',
    'High Protein',
    'Low Carb',
    'Low Sugar',
    'Fruits',
    'Drinks',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(foodSearchQueryProvider);
    // Sync state if text changes
    _searchController.addListener(() {
      ref.read(foodSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(foodSearchQueryProvider.notifier).state = '';
    ref.read(foodCategoryFilterProvider.notifier).state = null;
    ref.read(foodDietFilterProvider.notifier).state = 'Any';
    ref.read(foodMealFilterProvider.notifier).state = 'Any';
    ref.read(foodCuisineFilterProvider.notifier).state = 'Any';
    ref.read(foodNutritionFiltersProvider.notifier).state = const {};
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final scheme = Theme.of(context).colorScheme;
            final text = Theme.of(context).textTheme;
            final activeDiet = ref.watch(foodDietFilterProvider);
            final activeMeal = ref.watch(foodMealFilterProvider);
            final activeCuisine = ref.watch(foodCuisineFilterProvider);
            final activeNutrition = ref.watch(foodNutritionFiltersProvider);

            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.radiusDialog),
                  topRight: Radius.circular(AppConstants.radiusDialog),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Advanced Filters', style: text.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: AppConstants.spaceSm),

                    // Diet Section
                    Text('Dietary Preference',
                        style: text.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Vegetarian', 'Vegan', 'Non-Vegetarian']
                          .map((diet) {
                        final isSelected = activeDiet == diet;
                        return ChoiceChip(
                          label: Text(diet),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodDietFilterProvider.notifier).state =
                                diet;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Meal Suitability Section
                    Text('Meal Suitability',
                        style: text.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Breakfast', 'Lunch', 'Dinner', 'Snack']
                          .map((meal) {
                        final isSelected = activeMeal == meal;
                        return ChoiceChip(
                          label: Text(meal),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodMealFilterProvider.notifier).state =
                                meal;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Cuisine Section
                    Text('Cuisine',
                        style: text.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          ['Any', 'Indian', 'International'].map((cuisine) {
                        final isSelected = activeCuisine == cuisine;
                        return ChoiceChip(
                          label: Text(cuisine),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodCuisineFilterProvider.notifier).state =
                                cuisine;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Nutrition Section
                    Text('Nutrition Targets',
                        style: text.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        'High Protein',
                        'Low Calorie',
                        'Low Fat',
                        'Low Sugar',
                        'High Fiber'
                      ].map((nut) {
                        final isSelected = activeNutrition.contains(nut);
                        return FilterChip(
                          label: Text(nut),
                          selected: isSelected,
                          onSelected: (selected) {
                            final current = Set<String>.from(activeNutrition);
                            if (selected) {
                              current.add(nut);
                            } else {
                              current.remove(nut);
                            }
                            ref
                                .read(foodNutritionFiltersProvider.notifier)
                                .state = current;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Apply Filters'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final pageBackground = isDark ? null : scheme.surfaceContainerLow;

    final searchQuery = ref.watch(foodSearchQueryProvider);
    final selectedCategory = ref.watch(foodCategoryFilterProvider);

    final dietFilter = ref.watch(foodDietFilterProvider);
    final mealFilter = ref.watch(foodMealFilterProvider);
    final cuisineFilter = ref.watch(foodCuisineFilterProvider);
    final nutritionFilters = ref.watch(foodNutritionFiltersProvider);

    final isAnyFilterActive = dietFilter != 'Any' ||
        mealFilter != 'Any' ||
        cuisineFilter != 'Any' ||
        nutritionFilters.isNotEmpty;
    final isSearching = searchQuery.trim().isNotEmpty ||
        (selectedCategory != null && selectedCategory.toLowerCase() != 'all') ||
        isAnyFilterActive;

    final searchResultsAsync = ref.watch(searchFoodsProvider);
    final recentFoodsAsync = ref.watch(recentFoodsProvider);
    final favoriteFoodsAsync = ref.watch(favoriteFoodsProvider);
    final recommendedFoodsAsync = ref.watch(recommendedFoodsProvider);
    final selectedView = switch (widget.view) {
      'favorites' || 'recent' || 'custom' || 'recipes' => widget.view,
      _ => null,
    };
    final viewFoods = switch (selectedView) {
      'favorites' => favoriteFoodsAsync,
      'recent' => recentFoodsAsync,
      'custom' => ref.watch(customFoodsProvider),
      _ => searchResultsAsync,
    };

    return Scaffold(
      appBar: FitFuelAppBar(
        title: Text(switch (selectedView) {
          'favorites' => 'Favorite Foods',
          'recent' => 'Recent Foods',
          'custom' => 'Custom Foods',
          'recipes' => 'Recipes',
          _ => 'Food Library'
        }),
      ),
      backgroundColor: pageBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/nutrition/custom/new');
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Custom Food'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar & Filter Buttons Row
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMd,
                  vertical: AppConstants.spaceSm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search foods by name or category...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => context.push('/nutrition/scan'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'Scan Food with AI',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _showFilterBottomSheet,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: isAnyFilterActive ? scheme.primary : null,
                    ),
                    tooltip: 'Advanced Filters',
                  ),
                ],
              ),
            ),

            // Horizontal Category Selector
            SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceSm),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = selectedCategory == cat ||
                      (selectedCategory == null && cat == 'All');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        ref.read(foodCategoryFilterProvider.notifier).state =
                            selected ? cat : null;
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),

            // Scrollable Content
            Expanded(
              child: selectedView != null
                  ? viewFoods.when(
                      data: (foods) => _buildResponsiveResults(
                          foods.where((food) {
                            final matchesQuery = food.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase());
                            final hasRecipe =
                                (food.instructions?.isNotEmpty ?? false) ||
                                    (food.recipe?.isNotEmpty ?? false) ||
                                    FoodAssetRepository.instance
                                            .getRecipe(food.id) !=
                                        null;
                            final matchesFilters = !isSearching ||
                                (searchResultsAsync.valueOrNull?.any(
                                        (candidate) =>
                                            candidate.id == food.id) ??
                                    false);
                            return matchesQuery &&
                                matchesFilters &&
                                (selectedView != 'recipes' || hasRecipe);
                          }).toList(),
                          isDark,
                          selectedView),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => FitFuelErrorState(
                        error: error,
                        onRetry: () {
                          if (selectedView == 'favorites') {
                            ref.read(favoriteFoodsProvider.notifier).load();
                          } else if (selectedView == 'recent') {
                            ref.read(recentFoodsProvider.notifier).load();
                          } else if (selectedView == 'custom') {
                            ref.read(customFoodsProvider.notifier).load();
                          }
                        },
                      ),
                    )
                  : isSearching
                      ? searchResultsAsync.when(
                          data: (foods) =>
                              _buildResponsiveResults(foods, isDark, null),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => FitFuelErrorState(
                            error: err,
                            onRetry: () => ref.invalidate(searchFoodsProvider),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            // Refresh all states
                            ref
                                .read(foodRefreshTriggerProvider.notifier)
                                .state++;
                            ref.read(recentFoodsProvider.notifier).load();
                            ref.read(favoriteFoodsProvider.notifier).load();
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppConstants.spaceMd),
                            child: AdaptivePageLayout(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. Recommended
                                  const FitFuelSectionHeader(
                                    title: 'Smart Recommendations',
                                    subtitle: 'Based on your goals',
                                  ),
                                  const SizedBox(height: AppConstants.spaceSmd),
                                  recommendedFoodsAsync.when(
                                    data: (foods) =>
                                        _buildHorizontalFoodList(foods, isDark),
                                    loading: () => const SizedBox(
                                        height: 140,
                                        child: Center(
                                            child: CircularProgressIndicator())),
                                    error: (err, _) => FitFuelErrorState(
                                      error: err,
                                      onRetry: () => ref.invalidate(recommendedFoodsProvider),
                                    ),
                                  ),
                                  const SizedBox(height: AppConstants.spaceLg),

                                  // 2. Favorites
                                  FitFuelSectionHeader(
                                    title: 'Favorite Foods',
                                    actionLabel: 'See all',
                                    onActionPressed: () => context.go('/nutrition/search?view=favorites'),
                                  ),
                                  const SizedBox(height: AppConstants.spaceSmd),
                                  favoriteFoodsAsync.when(
                                    data: (foods) => _buildHorizontalFoodList(
                                        foods, isDark,
                                        emptyText: 'No favorites added yet. Tap the heart icon on any food to save it.'),
                                    loading: () => const SizedBox(
                                        height: 140,
                                        child: Center(
                                            child: CircularProgressIndicator())),
                                    error: (err, _) => FitFuelErrorState(
                                      error: err,
                                      onRetry: () => ref.read(favoriteFoodsProvider.notifier).load(),
                                    ),
                                  ),
                                  const SizedBox(height: AppConstants.spaceLg),

                                  // 3. Recents
                                  FitFuelSectionHeader(
                                    title: 'Recently Logged',
                                    actionLabel: 'See all',
                                    onActionPressed: () => context.go('/nutrition/search?view=recent'),
                                  ),
                                  const SizedBox(height: AppConstants.spaceSmd),
                                  recentFoodsAsync.when(
                                    data: (foods) =>
                                        _buildRecentVerticalList(foods, isDark),
                                    loading: () => const Center(
                                        child: CircularProgressIndicator()),
                                    error: (err, _) => FitFuelErrorState(
                                      error: err,
                                      onRetry: () => ref.read(recentFoodsProvider.notifier).load(),
                                    ),
                                  ),
                                  const SizedBox(height: 80), // spacer for FAB
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalFoodList(List<FoodEntity> foods, bool isDark,
      {String emptyText = 'No recommendations available.'}) {
    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
        child: Text(
          emptyText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final semantic = FitFuelSemanticColors.of(context);

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length > 5 ? 5 : foods.length, // Limit to top 5
        itemBuilder: (context, index) {
          final food = foods[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppConstants.spaceSmd),
            child: FitFuelCard(
              onTap: () {
                context.push(
                    '/nutrition/food/${Uri.encodeComponent(food.id)}${widget.view == 'recipes' ? '?section=recipe' : ''}');
              },
              isInteractive: true,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 156,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FoodImageCard(
                      food: food,
                      width: 156,
                      height: 80,
                      borderRadius: AppConstants.radiusCard,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.spaceSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${food.calories.toStringAsFixed(0)} kcal',
                                style: text.bodySmall?.copyWith(
                                  color: semantic.calories,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (food.isFavorite)
                                Icon(Icons.favorite_rounded,
                                    size: 14, color: scheme.error),
                            ],
                          ),
                          Text(
                            '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentVerticalList(List<FoodEntity> foods, bool isDark) {
    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
        child: Text(
          'Log some foods to see them here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    final semantic = FitFuelSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: foods.length > 5 ? 5 : foods.length, // Top 5 recents
      itemBuilder: (context, index) {
        final food = foods[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spaceSm),
          child: FitFuelCard(
            onTap: () {
              context.push(
                  '/nutrition/food/${Uri.encodeComponent(food.id)}${widget.view == 'recipes' ? '?section=recipe' : ''}');
            },
            isInteractive: true,
            padding: const EdgeInsets.all(AppConstants.spaceSmd),
            child: Row(
              children: [
                FoodImageCard(
                    food: food, width: 48, height: 48, borderRadius: AppConstants.radiusSm),
                const SizedBox(width: AppConstants.spaceSmd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          '${food.category} · ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
                          style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spaceSm),
                Text(
                  '${food.calories.toStringAsFixed(0)} kcal',
                  style: text.titleSmall?.copyWith(
                    color: semantic.calories,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveResults(List<FoodEntity> foods, bool isDark, String? selectedView) {
    if (foods.isEmpty) {
      final emptyTitle = switch (selectedView) {
        'favorites' => 'No favorites yet',
        'recent' => 'No recent foods',
        'custom' => 'No custom foods',
        'recipes' => 'No recipes found',
        _ => 'No results found',
      };
      final emptyDesc = switch (selectedView) {
        'favorites' => 'Tap the heart icon on any food to save it as a favorite.',
        'recent' => 'Foods you log will appear here for quick access.',
        'custom' => 'Create your own foods with exact nutrition info.',
        _ => 'Try adjusting your search or filters to find more foods.',
      };
      return FitFuelEmptyState(
        icon: switch (selectedView) {
          'favorites' => Icons.favorite_border_rounded,
          'recent' => Icons.history_rounded,
          'custom' => Icons.edit_note_rounded,
          _ => Icons.search_off_rounded,
        },
        title: emptyTitle,
        description: emptyDesc,
        actionLabel: selectedView == 'custom' ? 'Create Custom Food' : null,
        onActionPressed: selectedView == 'custom'
            ? () => context.push('/nutrition/custom/new')
            : null,
      );
    }

    final authUserUid = ref.watch(authStateStreamProvider).value?.uid;

    // Responsive: use grid on wider screens
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 600
              ? 2
              : 1;

      if (crossAxisCount == 1) {
        // Single column list — most compact for mobile
        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spaceSmd),
              child: FitFuelFoodCard(
                food: food,
                isFavorite: food.isFavorite,
                onTap: () {
                  context.push(
                      '/nutrition/food/${Uri.encodeComponent(food.id)}${widget.view == 'recipes' ? '?section=recipe' : ''}');
                },
                onFavoriteTap: () {
                  ref.read(favoriteFoodsProvider.notifier).toggleFavorite(food.id);
                },
                onAddTap: authUserUid == null
                    ? null
                    : () {
                        final record = NutritionRecordEntity(
                          id: '',
                          foodName: food.name,
                          mealType: 'Snack',
                          calories: food.calories,
                          protein: food.protein,
                          carbohydrates: food.carbohydrates,
                          fats: food.fats,
                          sugar: food.sugar,
                          servingSize: food.servingSize,
                          consumedAt: DateTime.now(),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => FoodFormSheet(
                              uid: authUserUid, existingRecord: record),
                        );
                      },
              ),
            );
          },
        );
      }

      final media = MediaQuery.of(context);
      final double cardExtent = media.textScaler.scale(16) > 19.2 ? 305 : 260;

      // Multi-column grid for tablet/desktop
      return GridView.builder(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          crossAxisSpacing: AppConstants.spaceMd,
          mainAxisSpacing: AppConstants.spaceMd,
          mainAxisExtent: cardExtent,
        ),
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final food = foods[index];
          return FitFuelFoodCard(
            food: food,
            isFavorite: food.isFavorite,
            onTap: () {
              context.push(
                  '/nutrition/food/${Uri.encodeComponent(food.id)}${widget.view == 'recipes' ? '?section=recipe' : ''}');
            },
            onFavoriteTap: () {
              ref.read(favoriteFoodsProvider.notifier).toggleFavorite(food.id);
            },
            onAddTap: authUserUid == null
                ? null
                : () {
                    final record = NutritionRecordEntity(
                      id: '',
                      foodName: food.name,
                      mealType: 'Snack',
                      calories: food.calories,
                      protein: food.protein,
                      carbohydrates: food.carbohydrates,
                      fats: food.fats,
                      sugar: food.sugar,
                      servingSize: food.servingSize,
                      consumedAt: DateTime.now(),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => FoodFormSheet(
                          uid: authUserUid, existingRecord: record),
                    );
                  },
          );
        },
      );
    });
  }
}
