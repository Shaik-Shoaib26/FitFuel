import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/nutrition/domain/entities/meal_type.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/adaptive_meal_planner_engine.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';

void main() {
  group('MealType Enum — Canonical Source of Truth', () {
    test('1. MealType enum has exactly 5 values', () {
      expect(MealType.values.length, equals(5));
    });

    test('2. MealType.displayNames returns exactly 5 unique meal types', () {
      final names = MealType.displayNames;
      expect(names.length, equals(5));
      expect(names.toSet().length, equals(5));
    });

    test('3. MealType.displayNames contains all required meal types', () {
      final names = MealType.displayNames;
      expect(names, contains('Breakfast'));
      expect(names, contains('Morning Snack'));
      expect(names, contains('Lunch'));
      expect(names, contains('Evening Snack'));
      expect(names, contains('Dinner'));
    });

    test('4. MealType.fromString parses Breakfast correctly', () {
      expect(MealType.fromString('Breakfast'), equals(MealType.breakfast));
    });

    test('5. MealType.fromString parses Morning Snack correctly', () {
      expect(MealType.fromString('Morning Snack'), equals(MealType.morningSnack));
    });

    test('6. MealType.fromString parses Lunch correctly', () {
      expect(MealType.fromString('Lunch'), equals(MealType.lunch));
    });

    test('7. MealType.fromString parses Evening Snack correctly', () {
      expect(MealType.fromString('Evening Snack'), equals(MealType.eveningSnack));
    });

    test('8. MealType.fromString parses Dinner correctly', () {
      expect(MealType.fromString('Dinner'), equals(MealType.dinner));
    });

    test('9. MealType.fromString handles legacy "Snack" value', () {
      expect(MealType.fromString('Snack'), equals(MealType.eveningSnack));
    });

    test('10. MealType.fromString is case-insensitive', () {
      expect(MealType.fromString('evening snack'), equals(MealType.eveningSnack));
      expect(MealType.fromString('MORNING SNACK'), equals(MealType.morningSnack));
      expect(MealType.fromString('breakfast'), equals(MealType.breakfast));
    });

    test('11. MealType.fromString returns fallback for unknown values', () {
      expect(MealType.fromString('Unknown'), equals(MealType.breakfast));
      expect(MealType.fromString(''), equals(MealType.breakfast));
    });

    test('12. MealType.normalize normalizes all valid meal type strings', () {
      expect(MealType.normalize('Breakfast'), equals('Breakfast'));
      expect(MealType.normalize('Morning Snack'), equals('Morning Snack'));
      expect(MealType.normalize('Lunch'), equals('Lunch'));
      expect(MealType.normalize('Evening Snack'), equals('Evening Snack'));
      expect(MealType.normalize('Dinner'), equals('Dinner'));
    });

    test('13. MealType.normalize converts legacy "Snack" to "Evening Snack"', () {
      expect(MealType.normalize('Snack'), equals('Evening Snack'));
    });

    test('14. MealType.normalize returns fallback for unknown values', () {
      expect(MealType.normalize('Brunch'), equals('Breakfast'));
    });

    test('15. MealType.isValid recognizes all 5 canonical types', () {
      expect(MealType.isValid('Breakfast'), isTrue);
      expect(MealType.isValid('Morning Snack'), isTrue);
      expect(MealType.isValid('Lunch'), isTrue);
      expect(MealType.isValid('Evening Snack'), isTrue);
      expect(MealType.isValid('Dinner'), isTrue);
    });

    test('16. MealType.isValid recognizes legacy "Snack"', () {
      expect(MealType.isValid('Snack'), isTrue);
    });

    test('17. MealType.isValid rejects unknown strings', () {
      expect(MealType.isValid('Brunch'), isFalse);
      expect(MealType.isValid(''), isFalse);
    });
  });

  group('Dropdown Value Validation — Regression Tests for Phase 27 Hotfix', () {
    test('18. Selected meal type "Evening Snack" exists in MealType.displayNames', () {
      // This is the EXACT scenario that caused the crash:
      // PlannedFoodCard passes "Evening Snack" to FoodFormSheet,
      // but the old 4-item list did not contain "Evening Snack".
      final displayNames = MealType.displayNames;
      expect(displayNames.contains('Evening Snack'), isTrue);
    });

    test('19. Selected meal type "Morning Snack" exists in MealType.displayNames', () {
      final displayNames = MealType.displayNames;
      expect(displayNames.contains('Morning Snack'), isTrue);
    });

    test('20. Every normalized meal type is present in displayNames exactly once', () {
      final displayNames = MealType.displayNames;
      for (final name in displayNames) {
        final count = displayNames.where((n) => n == name).length;
        expect(count, equals(1), reason: '$name appears $count times');
      }
    });

    test('21. Normalizing any planned meal type produces a value in displayNames', () {
      // These are the exact strings used by AdaptiveMealPlannerEngine
      final plannerMealTypes = [
        'Breakfast',
        'Morning Snack',
        'Lunch',
        'Evening Snack',
        'Dinner',
      ];
      final displayNames = MealType.displayNames;
      for (final type in plannerMealTypes) {
        final normalized = MealType.normalize(type);
        expect(displayNames.contains(normalized), isTrue,
            reason: 'Normalized "$type" → "$normalized" not found in displayNames');
      }
    });

    test('22. No duplicate meal type exists after adaptive plan generation', () {
      final testFoods = [
        const FoodEntity(
          id: 'idli_id',
          name: 'Idli',
          category: 'Breakfast',
          servingSize: 100,
          servingUnit: 'g',
          calories: 120,
          protein: 4,
          carbohydrates: 25,
          fats: 0.5,
          fiber: 2,
          sugar: 0,
          sodium: 100,
          isVegetarian: true,
          isIndian: true,
        ),
        const FoodEntity(
          id: 'dal_id',
          name: 'Dal Tadka',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 180,
          protein: 9,
          carbohydrates: 22,
          fats: 6,
          fiber: 5,
          sugar: 1,
          sodium: 350,
          isVegetarian: true,
          isIndian: true,
        ),
        const FoodEntity(
          id: 'paneer_id',
          name: 'Paneer Bhurji',
          category: 'Dinner',
          servingSize: 120,
          servingUnit: 'g',
          calories: 280,
          protein: 16,
          carbohydrates: 6,
          fats: 21,
          fiber: 2,
          sugar: 2,
          sodium: 400,
          isVegetarian: true,
          isIndian: true,
        ),
        const FoodEntity(
          id: 'almonds_id',
          name: 'Almonds',
          category: 'Snacks',
          servingSize: 30,
          servingUnit: 'g',
          calories: 170,
          protein: 6,
          carbohydrates: 6,
          fats: 15,
          fiber: 3.5,
          sugar: 1,
          sodium: 0,
          isVegetarian: true,
        ),
      ];

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      // Verify no duplicate meal types in the generated plan
      final mealTypes = plan.meals.map((m) => m.mealType).toList();
      expect(mealTypes.length, equals(mealTypes.toSet().length),
          reason: 'Duplicate meal types found: $mealTypes');
    });

    test('23. Regenerating the meal plan does not create duplicate meal slots', () {
      final testFoods = [
        const FoodEntity(
          id: 'idli_id',
          name: 'Idli',
          category: 'Breakfast',
          servingSize: 100,
          servingUnit: 'g',
          calories: 120,
          protein: 4,
          carbohydrates: 25,
          fats: 0.5,
          fiber: 2,
          sugar: 0,
          sodium: 100,
          isVegetarian: true,
          isIndian: true,
        ),
        const FoodEntity(
          id: 'dal_id',
          name: 'Dal Tadka',
          category: 'Lunch',
          servingSize: 150,
          servingUnit: 'g',
          calories: 180,
          protein: 9,
          carbohydrates: 22,
          fats: 6,
          fiber: 5,
          sugar: 1,
          sodium: 350,
          isVegetarian: true,
          isIndian: true,
        ),
      ];

      // Generate first plan
      final plan1 = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      // Generate second plan (simulating regeneration)
      final plan2 = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
        existingPlan: plan1,
      );

      // Verify no duplicate meal types in regenerated plan
      final mealTypes2 = plan2.meals.map((m) => m.mealType).toList();
      expect(mealTypes2.length, equals(mealTypes2.toSet().length),
          reason: 'Duplicate meal types after regeneration: $mealTypes2');
    });

    test('24. Every generated meal type is a valid MealType displayName', () {
      final testFoods = [
        const FoodEntity(
          id: 'idli_id',
          name: 'Idli',
          category: 'Breakfast',
          servingSize: 100,
          servingUnit: 'g',
          calories: 120,
          protein: 4,
          carbohydrates: 25,
          fats: 0.5,
          fiber: 2,
          sugar: 0,
          sodium: 100,
          isVegetarian: true,
          isIndian: true,
        ),
      ];

      final plan = AdaptiveMealPlannerEngine.generateAdaptiveMealPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 80,
        targetCarbs: 250,
        targetFat: 60,
        fitnessGoal: 'Maintain Weight',
        activityLevel: 'Active',
        dietaryPreference: 'Any',
      );

      final displayNames = MealType.displayNames;
      for (final meal in plan.meals) {
        expect(displayNames.contains(meal.mealType), isTrue,
            reason: '"${meal.mealType}" is not a valid MealType displayName');
      }
    });
  });
}
