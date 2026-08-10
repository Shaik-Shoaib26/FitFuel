class NutritionRecordEntity {
  final String id;
  final String foodName;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double sugar;
  final double servingSize;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionRecordEntity({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.sugar,
    required this.servingSize,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  NutritionRecordEntity copyWith({
    String? id,
    String? foodName,
    String? mealType,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    double? sugar,
    double? servingSize,
    DateTime? consumedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NutritionRecordEntity(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fats: fats ?? this.fats,
      sugar: sugar ?? this.sugar,
      servingSize: servingSize ?? this.servingSize,
      consumedAt: consumedAt ?? this.consumedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionRecordEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          foodName == other.foodName &&
          mealType == other.mealType &&
          calories == other.calories &&
          protein == other.protein &&
          carbohydrates == other.carbohydrates &&
          fats == other.fats &&
          sugar == other.sugar &&
          servingSize == other.servingSize &&
          consumedAt == other.consumedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      foodName.hashCode ^
      mealType.hashCode ^
      calories.hashCode ^
      protein.hashCode ^
      carbohydrates.hashCode ^
      fats.hashCode ^
      sugar.hashCode ^
      servingSize.hashCode ^
      consumedAt.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
