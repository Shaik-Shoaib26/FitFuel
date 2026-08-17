class FoodEntity {
  final String id;
  final String name;
  final String category;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double fiber;
  final double sugar;
  final double sodium;
  final bool isCustom;
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Expanded fields for Phase 23.1
  final String? imageAsset;
  final List<String> dietaryTags;
  final List<String> mealTypes;
  final bool isIndian;
  final bool isVegetarian;
  final bool isVegan;

  const FoodEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    this.isCustom = false,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
    this.imageAsset,
    this.dietaryTags = const [],
    this.mealTypes = const [],
    this.isIndian = false,
    this.isVegetarian = false,
    this.isVegan = false,
  });

  FoodEntity copyWith({
    String? id,
    String? name,
    String? category,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    double? fiber,
    double? sugar,
    double? sodium,
    bool? isCustom,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageAsset,
    List<String>? dietaryTags,
    List<String>? mealTypes,
    bool? isIndian,
    bool? isVegetarian,
    bool? isVegan,
  }) {
    return FoodEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageAsset: imageAsset ?? this.imageAsset,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      mealTypes: mealTypes ?? this.mealTypes,
      isIndian: isIndian ?? this.isIndian,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          servingSize == other.servingSize &&
          servingUnit == other.servingUnit &&
          calories == other.calories &&
          protein == other.protein &&
          carbohydrates == other.carbohydrates &&
          fats == other.fats &&
          fiber == other.fiber &&
          sugar == other.sugar &&
          sodium == other.sodium &&
          isCustom == other.isCustom &&
          isFavorite == other.isFavorite &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          imageAsset == other.imageAsset &&
          dietaryTags == other.dietaryTags &&
          mealTypes == other.mealTypes &&
          isIndian == other.isIndian &&
          isVegetarian == other.isVegetarian &&
          isVegan == other.isVegan;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      category.hashCode ^
      servingSize.hashCode ^
      servingUnit.hashCode ^
      calories.hashCode ^
      protein.hashCode ^
      carbohydrates.hashCode ^
      fats.hashCode ^
      fiber.hashCode ^
      sugar.hashCode ^
      sodium.hashCode ^
      isCustom.hashCode ^
      isFavorite.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      imageAsset.hashCode ^
      dietaryTags.hashCode ^
      mealTypes.hashCode ^
      isIndian.hashCode ^
      isVegetarian.hashCode ^
      isVegan.hashCode;
}
