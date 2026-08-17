import 'grocery_item_entity.dart';

class GroceryListEntity {
  final String id;
  final String userId;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<GroceryItemEntity> items;
  final int totalItems;
  final int purchasedItems;
  final int remainingItems;
  final double estimatedTotalCalories;
  final double estimatedTotalProtein;
  final double estimatedTotalCarbs;
  final double estimatedTotalFat;

  const GroceryListEntity({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.items,
    required this.totalItems,
    required this.purchasedItems,
    required this.remainingItems,
    this.estimatedTotalCalories = 0.0,
    this.estimatedTotalProtein = 0.0,
    this.estimatedTotalCarbs = 0.0,
    this.estimatedTotalFat = 0.0,
  });

  double get completionPercentage {
    if (totalItems == 0) return 100.0;
    final pct = (purchasedItems / totalItems) * 100.0;
    return double.parse(pct.toStringAsFixed(1));
  }

  int get remainingCount => items.where((i) => !i.isPurchased).length;
  int get purchasedCount => items.where((i) => i.isPurchased).length;
  
  int get categoryCount {
    final Set<String> cats = items.map((i) => i.category).toSet();
    return cats.length;
  }

  GroceryListEntity copyWith({
    String? id,
    String? userId,
    DateTime? generatedAt,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<GroceryItemEntity>? items,
    int? totalItems,
    int? purchasedItems,
    int? remainingItems,
    double? estimatedTotalCalories,
    double? estimatedTotalProtein,
    double? estimatedTotalCarbs,
    double? estimatedTotalFat,
  }) {
    return GroceryListEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      generatedAt: generatedAt ?? this.generatedAt,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      purchasedItems: purchasedItems ?? this.purchasedItems,
      remainingItems: remainingItems ?? this.remainingItems,
      estimatedTotalCalories: estimatedTotalCalories ?? this.estimatedTotalCalories,
      estimatedTotalProtein: estimatedTotalProtein ?? this.estimatedTotalProtein,
      estimatedTotalCarbs: estimatedTotalCarbs ?? this.estimatedTotalCarbs,
      estimatedTotalFat: estimatedTotalFat ?? this.estimatedTotalFat,
    );
  }
}
