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

  // New conceptual fields for Phase 31.1
  final String? dietType;
  final String? cuisine;
  final List<String>? ingredients;
  final String? recipe;
  final List<String>? instructions;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  final int? servings;
  final String? difficulty;
  final List<String>? tags;

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
    this.dietType,
    this.cuisine,
    this.ingredients,
    this.recipe,
    this.instructions,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.servings,
    this.difficulty,
    this.tags,
  });

  // Getters/Aliases for Phase 31.1 convenience
  String get foodId => id;
  String? get imageUrl => imageAsset;
  double get carbs => carbohydrates;
  double get fat => fats;
  String get dietTypeVal => dietType ?? (isVegan ? 'vegan' : (isVegetarian ? 'vegetarian' : 'nonVegetarian'));
  String get cuisineVal => cuisine ?? (isIndian ? 'Indian' : 'Western');
  List<String> get tagsVal => tags ?? dietaryTags;

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
    String? dietType,
    String? cuisine,
    List<String>? ingredients,
    String? recipe,
    List<String>? instructions,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? totalTimeMinutes,
    int? servings,
    String? difficulty,
    List<String>? tags,
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
      dietType: dietType ?? this.dietType,
      cuisine: cuisine ?? this.cuisine,
      ingredients: ingredients ?? this.ingredients,
      recipe: recipe ?? this.recipe,
      instructions: instructions ?? this.instructions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
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
          isVegan == other.isVegan &&
          dietType == other.dietType &&
          cuisine == other.cuisine &&
          ingredients == other.ingredients &&
          recipe == other.recipe &&
          instructions == other.instructions &&
          prepTimeMinutes == other.prepTimeMinutes &&
          cookTimeMinutes == other.cookTimeMinutes &&
          totalTimeMinutes == other.totalTimeMinutes &&
          servings == other.servings &&
          difficulty == other.difficulty &&
          tags == other.tags;

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
      isVegan.hashCode ^
      dietType.hashCode ^
      cuisine.hashCode ^
      ingredients.hashCode ^
      recipe.hashCode ^
      instructions.hashCode ^
      prepTimeMinutes.hashCode ^
      cookTimeMinutes.hashCode ^
      totalTimeMinutes.hashCode ^
      servings.hashCode ^
      difficulty.hashCode ^
      tags.hashCode;
}
