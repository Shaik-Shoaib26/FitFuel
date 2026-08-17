import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_list_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/grocery_category_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';

class SmartGroceryEngine {
  /// Generates or updates a grocery list from a set of daily or weekly meal plans.
  static GroceryListEntity generateFromMealPlan({
    required String userId,
    required List<MealPlanEntity> mealPlans,
    required List<PantryItemEntity> pantryItems,
    required GroceryPreferencesEntity preferences,
    List<GroceryItemEntity> existingItems = const [],
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    final start = periodStart ?? DateTime.now();
    final end = periodEnd ?? start.add(const Duration(days: 7));

    // 1. Gather all planned food items from the meal plans
    final Map<String, _RawPlannedFood> consolidatedRaw = {};

    for (final plan in mealPlans) {
      for (final meal in plan.meals) {
        for (final plannedFood in meal.foods) {
          final food = plannedFood.food;
          // Generate a unique consolidation key (prefer foodId, fallback to lowercase name)
          final String key = (food.id.isNotEmpty) ? food.id : food.name.toLowerCase().trim();

          final double qty = plannedFood.servingQuantity;
          final String unit = plannedFood.unit;
          final double cals = plannedFood.calories;
          final double protein = plannedFood.protein;
          final double carbs = plannedFood.carbohydrates;
          final double fat = plannedFood.fat;

          if (consolidatedRaw.containsKey(key)) {
            final existing = consolidatedRaw[key]!;
            consolidatedRaw[key] = existing.copyWith(
              quantity: existing.quantity + qty,
              calories: existing.calories + cals,
              protein: existing.protein + protein,
              carbs: existing.carbs + carbs,
              fat: existing.fat + fat,
            );
          } else {
            consolidatedRaw[key] = _RawPlannedFood(
              foodId: food.id,
              foodName: food.name,
              category: food.category,
              quantity: qty,
              unit: unit,
              calories: cals,
              protein: protein,
              carbs: carbs,
              fat: fat,
              imageUrl: food.imageAsset,
            );
          }
        }
      }
    }

    // 2. Build grocery items, subtracting pantry quantities if enabled
    final List<GroceryItemEntity> finalItems = [];

    int itemCounter = 0;
    for (final entry in consolidatedRaw.entries) {
      final raw = entry.value;
      itemCounter++;

      // Find matching pantry item
      PantryItemEntity? pantryMatch;
      if (preferences.includePantryItems) {
        pantryMatch = pantryItems.where((p) {
          if (raw.foodId.isNotEmpty && p.foodId != null && p.foodId!.isNotEmpty) {
            return p.foodId == raw.foodId;
          }
          return p.foodName.toLowerCase().trim() == raw.foodName.toLowerCase().trim();
        }).firstOrNull;
      }

      double requiredQty = raw.quantity;
      String requiredUnit = raw.unit;
      String notes = '';

      if (pantryMatch != null) {
        final calc = calculateRequiredQuantity(
          requiredQty: raw.quantity,
          requiredUnit: raw.unit,
          pantryQty: pantryMatch.quantity,
          pantryUnit: pantryMatch.unit,
        );

        requiredQty = calc.quantity;
        requiredUnit = calc.unit;
        notes = calc.notes;
      }

      // Check if this item already exists in the previous list and is purchased
      final existingMatch = existingItems.where((item) {
        if (raw.foodId.isNotEmpty && item.foodId != null && item.foodId!.isNotEmpty) {
          return item.foodId == raw.foodId;
        }
        return item.foodName.toLowerCase().trim() == raw.foodName.toLowerCase().trim();
      }).firstOrNull;

      final bool isAlreadyPurchased = existingMatch?.isPurchased ?? false;
      final DateTime? purchasedAt = existingMatch?.purchasedAt;

      // Map food category to canonical category
      final canonicalCategory = GroceryCategoryEntity.fromFoodCategory(raw.category);

      // Perform unit normalization (e.g. 1000g -> 1kg)
      final normalized = normalizeUnit(requiredQty, requiredUnit);

      finalItems.add(GroceryItemEntity(
        id: existingMatch?.id ?? '${DateTime.now().microsecondsSinceEpoch}_item_$itemCounter',
        foodId: raw.foodId.isNotEmpty ? raw.foodId : null,
        foodName: raw.foodName,
        category: canonicalCategory,
        quantity: normalized.quantity,
        unit: normalized.unit,
        estimatedWeight: raw.quantity, // Preserve base planned weight
        estimatedCalories: raw.calories,
        estimatedProtein: raw.protein,
        estimatedCarbs: raw.carbs,
        estimatedFat: raw.fat,
        imageUrl: raw.imageUrl,
        isPurchased: isAlreadyPurchased,
        isPantryItem: pantryMatch != null && requiredQty == 0.0,
        addedAt: existingMatch?.addedAt ?? DateTime.now(),
        purchasedAt: purchasedAt,
        notes: notes.isNotEmpty ? notes : (existingMatch?.notes ?? ''),
      ));
    }

    // Keep any manually added custom grocery items that were not generated from the meal plan
    for (final existing in existingItems) {
      final existsInGenerated = finalItems.any((item) {
        if (existing.foodId != null && item.foodId != null) {
          return existing.foodId == item.foodId;
        }
        return existing.foodName.toLowerCase().trim() == item.foodName.toLowerCase().trim();
      });

      if (!existsInGenerated) {
        finalItems.add(existing);
      }
    }

    // Sum estimated stats for remaining/all items
    double totalCals = 0.0;
    double totalPro = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final item in finalItems) {
      totalCals += item.estimatedCalories;
      totalPro += item.estimatedProtein;
      totalCarb += item.estimatedCarbs;
      totalFat += item.estimatedFat;
    }

    final totalCount = finalItems.length;
    final purchasedCount = finalItems.where((i) => i.isPurchased).length;
    final remainingCount = totalCount - purchasedCount;

    return GroceryListEntity(
      id: '${DateTime.now().microsecondsSinceEpoch}_list',
      userId: userId,
      generatedAt: DateTime.now(),
      periodStart: start,
      periodEnd: end,
      items: finalItems,
      totalItems: totalCount,
      purchasedItems: purchasedCount,
      remainingItems: remainingCount,
      estimatedTotalCalories: totalCals,
      estimatedTotalProtein: totalPro,
      estimatedTotalCarbs: totalCarb,
      estimatedTotalFat: totalFat,
    );
  }

  /// Calculates shopping quantity subtracting pantry stock.
  static QuantityResult calculateRequiredQuantity({
    required double requiredQty,
    required String requiredUnit,
    required double pantryQty,
    required String pantryUnit,
  }) {
    final String reqUnitLower = requiredUnit.toLowerCase().trim();
    final String panUnitLower = pantryUnit.toLowerCase().trim();

    // Check compatibility and convert both to base units for clean math
    final double reqBase = _toBaseUnit(requiredQty, reqUnitLower);
    final double panBase = _toBaseUnit(pantryQty, panUnitLower);

    final bool isCompatible = _areUnitsCompatible(reqUnitLower, panUnitLower);

    if (!isCompatible) {
      // Return planned quantity directly if units are incompatible
      return QuantityResult(
        quantity: requiredQty,
        unit: requiredUnit,
        notes: 'Pantry has $pantryQty $pantryUnit (unit mismatch)',
      );
    }

    final double diffBase = reqBase - panBase;

    if (diffBase <= 0.0) {
      return QuantityResult(
        quantity: 0.0,
        unit: requiredUnit,
        notes: 'Already available ($pantryQty $pantryUnit in pantry)',
      );
    }

    // Convert back from base unit to required unit
    final double finalQty = _fromBaseUnit(diffBase, reqUnitLower);

    return QuantityResult(
      quantity: finalQty,
      unit: requiredUnit,
      notes: '$pantryQty $pantryUnit subtracted from required quantity',
    );
  }

  /// Normalizes units where possible (e.g. 1200 g -> 1.2 kg)
  static QuantityResult normalizeUnit(double quantity, String unit) {
    final u = unit.toLowerCase().trim();
    if (u == 'g' && quantity >= 1000.0) {
      return QuantityResult(
        quantity: double.parse((quantity / 1000.0).toStringAsFixed(2)),
        unit: 'kg',
      );
    }
    if (u == 'ml' && quantity >= 1000.0) {
      return QuantityResult(
        quantity: double.parse((quantity / 1000.0).toStringAsFixed(2)),
        unit: 'L',
      );
    }
    return QuantityResult(quantity: quantity, unit: unit);
  }

  static double _toBaseUnit(double qty, String unit) {
    switch (unit) {
      case 'kg':
        return qty * 1000.0;
      case 'l':
        return qty * 1000.0;
      default:
        return qty;
    }
  }

  static double _fromBaseUnit(double baseQty, String unit) {
    switch (unit) {
      case 'kg':
        return baseQty / 1000.0;
      case 'l':
        return baseQty / 1000.0;
      default:
        return baseQty;
    }
  }

  static bool _areUnitsCompatible(String u1, String u2) {
    final Set<String> weightUnits = {'g', 'kg'};
    final Set<String> volumeUnits = {'ml', 'l'};

    if (weightUnits.contains(u1) && weightUnits.contains(u2)) return true;
    if (volumeUnits.contains(u1) && volumeUnits.contains(u2)) return true;
    return u1 == u2; // pieces, cups, tbsp, etc. must match exactly
  }
}

class _RawPlannedFood {
  final String foodId;
  final String foodName;
  final String category;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl;

  const _RawPlannedFood({
    required this.foodId,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
  });

  _RawPlannedFood copyWith({
    double? quantity,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return _RawPlannedFood(
      foodId: foodId,
      foodName: foodName,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      imageUrl: imageUrl,
    );
  }
}

class QuantityResult {
  final double quantity;
  final String unit;
  final String notes;

  const QuantityResult({
    required this.quantity,
    required this.unit,
    this.notes = '',
  });
}
