import '../entities/food_entity.dart';

/// Centralized category and meal-type normalization helper for FitFuel Food Search.
/// Normalizes harmless variations (e.g. Fruits/Fruit, Snacks/Snack) and handles
/// both meal types (via [FoodEntity.mealTypes]) and food categories (via [FoodEntity.category]).
class FoodCategoryNormalizer {
  /// Primary UI filter chips in canonical presentation order.
  static const List<String> primaryFilters = [
    'All',
    'Breakfast',
    'Lunch',
    'Snacks',
    'Dinner',
    'Fruits',
    'Vegetables',
    'Protein',
    'Dairy',
    'Grains',
    'Beverages',
    'Desserts',
  ];

  /// Checks if [food] matches the given [filterName] (case-insensitive).
  ///
  /// Returns `true` if [filterName] is `null` or `'All'`.
  static bool matchesFilter(FoodEntity food, String? filterName) {
    if (filterName == null) return true;
    final clean = filterName.toLowerCase().trim();
    if (clean.isEmpty || clean == 'all') return true;

    // 1. Meal type matching (inspects mealTypes metadata and category)
    if (clean == 'breakfast') {
      return food.mealTypes.any((m) => m.toLowerCase().trim() == 'breakfast') ||
          food.category.toLowerCase().trim() == 'breakfast';
    }
    if (clean == 'lunch') {
      return food.mealTypes.any((m) => m.toLowerCase().trim() == 'lunch') ||
          food.category.toLowerCase().trim() == 'lunch';
    }
    if (clean == 'dinner') {
      return food.mealTypes.any((m) => m.toLowerCase().trim() == 'dinner') ||
          food.category.toLowerCase().trim() == 'dinner';
    }
    if (clean == 'snacks' || clean == 'snack') {
      return food.mealTypes.any((m) {
            final t = m.toLowerCase().trim();
            return t == 'snacks' || t == 'snack';
          }) ||
          food.category.toLowerCase().trim() == 'snacks' ||
          food.category.toLowerCase().trim() == 'snack';
    }

    // 2. Category matching with harmless plural/singular normalization
    final foodCat = food.category.toLowerCase().trim();
    if (clean == 'fruits' || clean == 'fruit') {
      return foodCat == 'fruits' || foodCat == 'fruit';
    }
    if (clean == 'vegetables' || clean == 'vegetable') {
      return foodCat == 'vegetables' || foodCat == 'vegetable';
    }
    if (clean == 'beverages' || clean == 'beverage') {
      return foodCat == 'beverages' || foodCat == 'beverage';
    }
    if (clean == 'desserts' || clean == 'dessert') {
      return foodCat == 'desserts' || foodCat == 'dessert';
    }
    if (clean == 'grains' || clean == 'grain') {
      return foodCat == 'grains' || foodCat == 'grain';
    }
    if (clean == 'protein') {
      return foodCat == 'protein';
    }
    if (clean == 'dairy') {
      return foodCat == 'dairy';
    }
    if (clean == 'nuts & seeds' || clean == 'nuts' || clean == 'seeds') {
      return foodCat == 'nuts & seeds';
    }
    if (clean == 'legumes' || clean == 'legume') {
      return foodCat == 'legumes' || foodCat == 'legume';
    }

    // 3. Dietary & regional preferences
    if (clean == 'indian') return food.isIndian;
    if (clean == 'healthy / fitness' ||
        clean == 'healthy' ||
        clean == 'fitness') {
      return food.dietaryTags.contains('Healthy') ||
          food.dietaryTags.contains('Fitness') ||
          food.dietaryTags.contains('Low Calorie') ||
          food.dietaryTags.contains('High Protein');
    }

    // 4. Exact fallback
    return foodCat == clean;
  }
}
