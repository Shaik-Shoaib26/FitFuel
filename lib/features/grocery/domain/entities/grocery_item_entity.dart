class GroceryItemEntity {
  final String id;
  final String? foodId;
  final String foodName;
  final String category;
  final double quantity;
  final String unit;
  final double estimatedWeight; // in grams
  final double estimatedCalories;
  final double estimatedProtein;
  final double estimatedCarbs;
  final double estimatedFat;
  final String? imageUrl;
  final bool isPurchased;
  final bool isPantryItem;
  final DateTime addedAt;
  final DateTime? purchasedAt;
  final String? notes;

  const GroceryItemEntity({
    required this.id,
    this.foodId,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    this.estimatedWeight = 0.0,
    this.estimatedCalories = 0.0,
    this.estimatedProtein = 0.0,
    this.estimatedCarbs = 0.0,
    this.estimatedFat = 0.0,
    this.imageUrl,
    this.isPurchased = false,
    this.isPantryItem = false,
    required this.addedAt,
    this.purchasedAt,
    this.notes,
  });

  GroceryItemEntity copyWith({
    String? id,
    String? foodId,
    String? foodName,
    String? category,
    double? quantity,
    String? unit,
    double? estimatedWeight,
    double? estimatedCalories,
    double? estimatedProtein,
    double? estimatedCarbs,
    double? estimatedFat,
    String? imageUrl,
    bool? isPurchased,
    bool? isPantryItem,
    DateTime? addedAt,
    DateTime? purchasedAt,
    String? notes,
  }) {
    return GroceryItemEntity(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedWeight: estimatedWeight ?? this.estimatedWeight,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      estimatedProtein: estimatedProtein ?? this.estimatedProtein,
      estimatedCarbs: estimatedCarbs ?? this.estimatedCarbs,
      estimatedFat: estimatedFat ?? this.estimatedFat,
      imageUrl: imageUrl ?? this.imageUrl,
      isPurchased: isPurchased ?? this.isPurchased,
      isPantryItem: isPantryItem ?? this.isPantryItem,
      addedAt: addedAt ?? this.addedAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      notes: notes ?? this.notes,
    );
  }
}
