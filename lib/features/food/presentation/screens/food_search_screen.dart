import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_food_card.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../nutrition/presentation/widgets/food_form_sheet.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/food_entity.dart';
import '../providers/food_providers.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final activeDiet = ref.watch(foodDietFilterProvider);
            final activeMeal = ref.watch(foodMealFilterProvider);
            final activeCuisine = ref.watch(foodCuisineFilterProvider);
            final activeNutrition = ref.watch(foodNutritionFiltersProvider);

            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.radiusLg),
                  topRight: Radius.circular(AppConstants.radiusLg),
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
                        Text(
                          'Advanced Filters',
                          style: AppTypography.heading2(isDark: isDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: AppConstants.spaceSm),

                    // Diet Section
                    Text('Dietary Preference', style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Vegetarian', 'Vegan', 'Non-Vegetarian'].map((diet) {
                        final isSelected = activeDiet == diet;
                        return ChoiceChip(
                          label: Text(diet),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodDietFilterProvider.notifier).state = diet;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Meal Suitability Section
                    Text('Meal Suitability', style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Breakfast', 'Lunch', 'Dinner', 'Snack'].map((meal) {
                        final isSelected = activeMeal == meal;
                        return ChoiceChip(
                          label: Text(meal),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodMealFilterProvider.notifier).state = meal;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Cuisine Section
                    Text('Cuisine', style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Indian', 'International'].map((cuisine) {
                        final isSelected = activeCuisine == cuisine;
                        return ChoiceChip(
                          label: Text(cuisine),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(foodCuisineFilterProvider.notifier).state = cuisine;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),

                    // Nutrition Section
                    Text('Nutrition Targets', style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ['High Protein', 'Low Calorie', 'Low Fat', 'Low Sugar', 'High Fiber'].map((nut) {
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
                            ref.read(foodNutritionFiltersProvider.notifier).state = current;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: Colors.white,
                      ),
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

    final searchQuery = ref.watch(foodSearchQueryProvider);
    final selectedCategory = ref.watch(foodCategoryFilterProvider);

    final dietFilter = ref.watch(foodDietFilterProvider);
    final mealFilter = ref.watch(foodMealFilterProvider);
    final cuisineFilter = ref.watch(foodCuisineFilterProvider);
    final nutritionFilters = ref.watch(foodNutritionFiltersProvider);

    final isAnyFilterActive = dietFilter != 'Any' || mealFilter != 'Any' || cuisineFilter != 'Any' || nutritionFilters.isNotEmpty;
    final isSearching = searchQuery.trim().isNotEmpty || (selectedCategory != null && selectedCategory.toLowerCase() != 'all') || isAnyFilterActive;

    final searchResultsAsync = ref.watch(searchFoodsProvider);
    final recentFoodsAsync = ref.watch(recentFoodsProvider);
    final favoriteFoodsAsync = ref.watch(favoriteFoodsProvider);
    final recommendedFoodsAsync = ref.watch(recommendedFoodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Database'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/custom-food');
        },
        backgroundColor: AppColors.primary500,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Custom Food', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar & Filter Buttons Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
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
                    onPressed: _showFilterBottomSheet,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: isAnyFilterActive ? AppColors.primary500 : null,
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
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = selectedCategory == cat || (selectedCategory == null && cat == 'All');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        ref.read(foodCategoryFilterProvider.notifier).state = selected ? cat : null;
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),

            // Scrollable Content
            Expanded(
              child: isSearching
                  ? searchResultsAsync.when(
                      data: (foods) => _buildSearchResultsList(foods, isDark),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        // Refresh all states
                        ref.read(foodRefreshTriggerProvider.notifier).state++;
                        ref.read(recentFoodsProvider.notifier).load();
                        ref.read(favoriteFoodsProvider.notifier).load();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppConstants.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Recommended
                            _buildSectionHeader('Smart Recommendations', isDark),
                            recommendedFoodsAsync.when(
                              data: (foods) => _buildHorizontalFoodList(foods, isDark),
                              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                              error: (err, _) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Failed to load recommendations: $err'),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceLg),

                            // 2. Favorites
                            _buildSectionHeader('Favorite Foods', isDark),
                            favoriteFoodsAsync.when(
                              data: (foods) => _buildHorizontalFoodList(foods, isDark, emptyText: 'No favorites added yet.'),
                              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                              error: (err, _) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Failed to load favorites: $err'),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceLg),

                            // 3. Recents
                            _buildSectionHeader('Recently Logged', isDark),
                            recentFoodsAsync.when(
                              data: (foods) => _buildRecentVerticalList(foods, isDark),
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Failed to load recents: $err'),
                              ),
                            ),
                            const SizedBox(height: 80), // spacer for FAB
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceSm, left: 4),
      child: Text(
        title,
        style: AppTypography.heading3(isDark: isDark),
      ),
    );
  }

  Widget _buildHorizontalFoodList(List<FoodEntity> foods, bool isDark, {String emptyText = 'No recommendations available.'}) {
    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceMd),
        child: Text(
          emptyText,
          style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length > 5 ? 5 : foods.length, // Limit to top 5
        itemBuilder: (context, index) {
          final food = foods[index];
          return Card(
            elevation: 1,
            color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
            margin: const EdgeInsets.only(right: AppConstants.spaceMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              onTap: () {
                context.push('/food-details', extra: food);
              },
              child: Container(
                width: 160,
                padding: const EdgeInsets.all(AppConstants.spaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FoodImageCard(food: food, width: 36, height: 36, borderRadius: 4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${food.servingSize.toStringAsFixed(0)}${food.servingUnit}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${food.calories.toStringAsFixed(0)} kcal',
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (food.isFavorite)
                          const Icon(Icons.favorite_rounded, size: 14, color: AppColors.stateError),
                      ],
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
          style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: foods.length > 5 ? 5 : foods.length, // Top 5 recents
      itemBuilder: (context, index) {
        final food = foods[index];
        return Card(
          elevation: 1,
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
          child: ListTile(
            onTap: () {
              context.push('/food-details', extra: food);
            },
            leading: FoodImageCard(food: food, width: 40, height: 40, borderRadius: 4),
            title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${food.category} • ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${food.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList(List<FoodEntity> foods, bool isDark) {
    if (foods.isEmpty) {
      return const Center(
        child: Text(
          'No foods match your search query.',
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    final authUserUid = ref.watch(authStateStreamProvider).value?.uid;

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spaceSm),
          child: FitFuelFoodCard(
            food: food,
            isFavorite: food.isFavorite,
            onTap: () {
              context.push('/food-details', extra: food);
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
                      builder: (context) => FoodFormSheet(uid: authUserUid, existingRecord: record),
                    );
                  },
          ),
        );
      },
    );
  }
}
