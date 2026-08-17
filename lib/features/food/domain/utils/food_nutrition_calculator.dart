import '../entities/food_entity.dart';

class FoodNutritionCalculator {
  static FoodEntity calculateScaled({
    required FoodEntity food,
    required double selectedServingSize,
  }) {
    if (selectedServingSize <= 0 || food.servingSize <= 0) {
      return food.copyWith(
        servingSize: selectedServingSize < 0 ? 0.0 : selectedServingSize,
        calories: 0.0,
        protein: 0.0,
        carbohydrates: 0.0,
        fats: 0.0,
        fiber: 0.0,
        sugar: 0.0,
        sodium: 0.0,
      );
    }

    final double scale = selectedServingSize / food.servingSize;
    return food.copyWith(
      servingSize: selectedServingSize,
      calories: food.calories * scale,
      protein: food.protein * scale,
      carbohydrates: food.carbohydrates * scale,
      fats: food.fats * scale,
      fiber: food.fiber * scale,
      sugar: food.sugar * scale,
      sodium: food.sodium * scale,
    );
  }
}
