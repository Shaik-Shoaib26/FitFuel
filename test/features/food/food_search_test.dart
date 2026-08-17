import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';

void main() {
  group('Food Search Engine Tests', () {
    final testFoods = [
      const FoodEntity(
        id: '1',
        name: 'Chicken Breast',
        category: 'Protein',
        servingSize: 100,
        servingUnit: 'g',
        calories: 165,
        protein: 31,
        carbohydrates: 0,
        fats: 3.6,
        fiber: 0,
        sugar: 0,
        sodium: 74,
      ),
      const FoodEntity(
        id: '2',
        name: 'Brown Rice',
        category: 'Grains',
        servingSize: 100,
        servingUnit: 'g',
        calories: 111,
        protein: 2.6,
        carbohydrates: 23,
        fats: 0.9,
        fiber: 1.8,
        sugar: 0.4,
        sodium: 5,
      ),
      const FoodEntity(
        id: '3',
        name: 'Apple',
        category: 'Fruits',
        servingSize: 100,
        servingUnit: 'g',
        calories: 52,
        protein: 0.3,
        carbohydrates: 14,
        fats: 0.2,
        fiber: 2.4,
        sugar: 10,
        sodium: 1,
      ),
      const FoodEntity(
        id: '4',
        name: 'Chicken Curry',
        category: 'Lunch',
        servingSize: 200,
        servingUnit: 'g',
        calories: 300,
        protein: 24,
        carbohydrates: 12,
        fats: 16,
        fiber: 2,
        sugar: 1,
        sodium: 450,
      ),
    ];

    test('Exact food matching', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: 'Apple');
      expect(results.length, 1);
      expect(results.first.id, '3');
    });

    test('Prefix matching', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: 'chick');
      expect(results.length, 2);
      expect(results[0].name, 'Chicken Breast'); // Starts with query, should rank higher
      expect(results[1].name, 'Chicken Curry');
    });

    test('Partial matching', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: 'rice');
      expect(results.length, 1);
      expect(results.first.name, 'Brown Rice');
    });

    test('Category matching', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: 'grains');
      expect(results.length, 1);
      expect(results.first.name, 'Brown Rice');
    });

    test('Case-insensitive search', () {
      final results1 = FoodSearchEngine.search(foods: testFoods, query: 'brown rice');
      final results2 = FoodSearchEngine.search(foods: testFoods, query: 'BROWN RICE');
      expect(results1.length, 1);
      expect(results2.length, 1);
      expect(results1.first.id, results2.first.id);
    });

    test('Empty search', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: '   ');
      expect(results, isEmpty);
    });

    test('Ranking order', () {
      final results = FoodSearchEngine.search(foods: testFoods, query: 'chicken breast');
      expect(results.first.name, 'Chicken Breast'); // Exact match highest
    });
  });
}
