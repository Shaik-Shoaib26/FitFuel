import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/repositories/food_repository.dart';

class MockFoodRepository implements FoodRepository {
  final List<FoodEntity> customFoods = [];
  bool addCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<FoodEntity> addCustomFood(FoodEntity food) async {
    addCalled = true;
    customFoods.add(food);
    return food;
  }

  @override
  Future<void> updateCustomFood(FoodEntity food) async {
    updateCalled = true;
    final index = customFoods.indexWhere((f) => f.id == food.id);
    if (index != -1) {
      customFoods[index] = food;
    }
  }

  @override
  Future<void> deleteCustomFood(String id) async {
    deleteCalled = true;
    customFoods.removeWhere((f) => f.id == id);
  }

  @override
  Future<List<FoodEntity>> getCustomFoods() async => customFoods;

  @override
  Future<List<FoodEntity>> getFavoriteFoods() async => [];

  @override
  Future<FoodEntity?> getFoodById(String id) async => null;

  @override
  Future<List<FoodEntity>> getFoodsByCategory(String category) async => [];

  @override
  Future<List<FoodEntity>> getRecentFoods() async => [];

  @override
  Future<List<FoodEntity>> searchFoods(String query) async => [];

  @override
  Future<void> toggleFavorite(String id) async {}

  @override
  Future<void> addRecentFood(FoodEntity food) async {}
}

void main() {
  group('Custom Food Tests', () {
    late MockFoodRepository mockRepo;

    setUp(() {
      mockRepo = MockFoodRepository();
    });

    const validFood = FoodEntity(
      id: 'c_1',
      name: 'Avocado Toast',
      category: 'Breakfast',
      servingSize: 150,
      servingUnit: 'g',
      calories: 250,
      protein: 6.5,
      carbohydrates: 24.0,
      fats: 14.2,
      fiber: 4.5,
      sugar: 1.2,
      sodium: 320,
      isCustom: true,
    );

    test('Valid custom food validation rules', () {
      expect(validFood.name.isNotEmpty, isTrue);
      expect(validFood.servingSize > 0, isTrue);
      expect(validFood.calories >= 0, isTrue);
      expect(validFood.protein >= 0, isTrue);
      expect(validFood.carbohydrates >= 0, isTrue);
      expect(validFood.fats >= 0, isTrue);
      expect(validFood.fiber >= 0, isTrue);
      expect(validFood.sugar >= 0, isTrue);
      expect(validFood.sodium >= 0, isTrue);
    });

    test('Invalid properties validation check', () {
      const invalidNameFood = FoodEntity(
        id: 'c_2',
        name: '',
        category: 'Breakfast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 100,
        protein: 5,
        carbohydrates: 5,
        fats: 5,
        fiber: 0,
        sugar: 0,
        sodium: 0,
      );

      const invalidServingFood = FoodEntity(
        id: 'c_3',
        name: 'Bad Serving',
        category: 'Breakfast',
        servingSize: 0,
        servingUnit: 'g',
        calories: 100,
        protein: 5,
        carbohydrates: 5,
        fats: 5,
        fiber: 0,
        sugar: 0,
        sodium: 0,
      );

      const negativeCaloriesFood = FoodEntity(
        id: 'c_4',
        name: 'Negative Cal',
        category: 'Breakfast',
        servingSize: 100,
        servingUnit: 'g',
        calories: -50,
        protein: 5,
        carbohydrates: 5,
        fats: 5,
        fiber: 0,
        sugar: 0,
        sodium: 0,
      );

      expect(invalidNameFood.name.isEmpty, isTrue);
      expect(invalidServingFood.servingSize <= 0, isTrue);
      expect(negativeCaloriesFood.calories < 0, isTrue);
    });

    test('Add custom food via repository', () async {
      final result = await mockRepo.addCustomFood(validFood);
      expect(result.id, 'c_1');
      expect(result.name, 'Avocado Toast');
      expect(mockRepo.addCalled, isTrue);
    });

    test('Update custom food via repository', () async {
      await mockRepo.updateCustomFood(validFood);
      expect(mockRepo.updateCalled, isTrue);
    });

    test('Delete custom food via repository', () async {
      await mockRepo.deleteCustomFood('c_1');
      expect(mockRepo.deleteCalled, isTrue);
    });
  });
}
