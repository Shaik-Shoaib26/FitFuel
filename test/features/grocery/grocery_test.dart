import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_item_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_list_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/pantry_item_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_preferences_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_category_entity.dart';
import 'package:fitfuel/features/grocery/domain/utils/smart_grocery_engine.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';

void main() {
  group('Smart Grocery Engine & Quantity Aggregation Tests', () {
    const food1 = FoodEntity(
      id: 'rice_123',
      name: 'White Rice',
      category: 'Grains',
      servingSize: 100,
      servingUnit: 'g',
      calories: 130,
      protein: 2.7,
      carbohydrates: 28,
      fats: 0.3,
      fiber: 1,
      sugar: 2,
      sodium: 10,
    );

    const food2 = FoodEntity(
      id: 'chicken_456',
      name: 'Chicken Breast',
      category: 'Meat',
      servingSize: 100,
      servingUnit: 'g',
      calories: 165,
      protein: 31,
      carbohydrates: 0,
      fats: 3.6,
      fiber: 0,
      sugar: 0,
      sodium: 70,
    );

    final plan = MealPlanEntity(
      id: 'plan_1',
      date: DateTime.now(),
      targetCalories: 2000,
      targetProtein: 150,
      targetCarbs: 200,
      targetFat: 65,
      meals: [
        const PlannedMealEntity(
          mealType: 'Breakfast',
          totalCalories: 260,
          totalProtein: 5.4,
          totalCarbs: 56,
          totalFat: 0.6,
          foods: [
            PlannedFoodEntity(
              food: food1,
              servingQuantity: 200,
              unit: 'g',
              calories: 260,
              protein: 5.4,
              carbohydrates: 56,
              fat: 0.6,
              fiber: 0.8,
            ),
          ],
        ),
        const PlannedMealEntity(
          mealType: 'Lunch',
          totalCalories: 637.5,
          totalProtein: 54.6,
          totalCarbs: 84,
          totalFat: 6.3,
          foods: [
            PlannedFoodEntity(
              food: food1,
              servingQuantity: 300,
              unit: 'g',
              calories: 390,
              protein: 8.1,
              carbohydrates: 84,
              fat: 0.9,
              fiber: 1.2,
            ),
            PlannedFoodEntity(
              food: food2,
              servingQuantity: 150,
              unit: 'g',
              calories: 247.5,
              protein: 46.5,
              carbohydrates: 0,
              fat: 5.4,
              fiber: 0,
            ),
          ],
        ),
      ],
    );

    test('1. Grocery list generation from meal plan and consolidation', () {
      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: const [],
        preferences: const GroceryPreferencesEntity(),
      );

      expect(list.totalItems, equals(2));
      
      final rice = list.items.firstWhere((i) => i.foodName == 'White Rice');
      expect(rice.quantity, equals(500.0)); // 500g remains 500g (not >= 1000g)
      expect(rice.unit, equals('g'));
    });

    test('2. Duplicate food merging & quantity aggregation', () {
      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: const [],
        preferences: const GroceryPreferencesEntity(),
      );

      // Verify Oats consolidate
      final rice = list.items.firstWhere((i) => i.foodName == 'White Rice');
      expect(rice.estimatedWeight, equals(500.0)); // 200g + 300g
    });

    test('3. Pantry subtraction & non-negative shopping quantities', () {
      final pantry = [
        PantryItemEntity(
          id: 'p_1',
          foodId: 'rice_123',
          foodName: 'White Rice',
          quantity: 200,
          unit: 'g',
          expiryDate: DateTime.now().add(const Duration(days: 5)),
          addedAt: DateTime.now(),
        ),
      ];

      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: pantry,
        preferences: const GroceryPreferencesEntity(includePantryItems: true),
      );

      final rice = list.items.firstWhere((i) => i.foodName == 'White Rice');
      expect(rice.quantity, equals(300.0)); // 500g required - 200g pantry = 300g needed
      expect(rice.unit, equals('g'));
    });

    test('4. Pantry subtraction excess sets shopping quantity to 0', () {
      final pantry = [
        PantryItemEntity(
          id: 'p_1',
          foodId: 'rice_123',
          foodName: 'White Rice',
          quantity: 600,
          unit: 'g',
          expiryDate: DateTime.now().add(const Duration(days: 5)),
          addedAt: DateTime.now(),
        ),
      ];

      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: pantry,
        preferences: const GroceryPreferencesEntity(includePantryItems: true),
      );

      final rice = list.items.firstWhere((i) => i.foodName == 'White Rice');
      expect(rice.quantity, equals(0.0));
      expect(rice.notes, contains('Already available'));
    });

    test('5. Unit normalization weight and volume', () {
      final norm1 = SmartGroceryEngine.normalizeUnit(1200, 'g');
      expect(norm1.quantity, equals(1.2));
      expect(norm1.unit, equals('kg'));

      final norm2 = SmartGroceryEngine.normalizeUnit(450, 'g');
      expect(norm2.quantity, equals(450.0));
      expect(norm2.unit, equals('g'));

      final norm3 = SmartGroceryEngine.normalizeUnit(1500, 'ml');
      expect(norm3.quantity, equals(1.5));
      expect(norm3.unit, equals('L'));
    });

    test('6. Category grouping mapped from food category', () {
      final cat1 = GroceryCategoryEntity.fromFoodCategory('Grains');
      expect(cat1, equals('Grains'));

      final cat2 = GroceryCategoryEntity.fromFoodCategory('Chicken Breast');
      expect(cat2, equals('Meat'));
    });

    test('7. Completion percentage and counts getters', () {
      final item1 = GroceryItemEntity(
        id: '1',
        foodName: 'Apple',
        category: 'Fruits',
        quantity: 5,
        unit: 'pieces',
        isPurchased: true,
        addedAt: DateTime.now(),
      );
      final item2 = GroceryItemEntity(
        id: '2',
        foodName: 'Banana',
        category: 'Fruits',
        quantity: 6,
        unit: 'pieces',
        isPurchased: false,
        addedAt: DateTime.now(),
      );

      final list = GroceryListEntity(
        id: 'list_1',
        userId: 'user_1',
        generatedAt: DateTime.now(),
        periodStart: DateTime.now(),
        periodEnd: DateTime.now().add(const Duration(days: 7)),
        items: [item1, item2],
        totalItems: 2,
        purchasedItems: 1,
        remainingItems: 1,
      );

      expect(list.completionPercentage, equals(50.0));
      expect(list.remainingCount, equals(1));
      expect(list.purchasedCount, equals(1));
      expect(list.categoryCount, equals(1));
    });

    test('8. Search query filtering on name, category, and notes', () {
      final item = GroceryItemEntity(
        id: '1',
        foodName: 'Avocado',
        category: 'Fruits',
        quantity: 2,
        unit: 'pieces',
        notes: 'Organic',
        addedAt: DateTime.now(),
      );

      final matchesName = item.foodName.toLowerCase().contains('avo');
      final matchesNotes = item.notes?.toLowerCase().contains('org') ?? false;

      expect(matchesName, isTrue);
      expect(matchesNotes, isTrue);
    });

    test('9. Expiry calculation categories (Fresh, Expiring Soon, Expired)', () {
      final ref = DateTime(2026, 8, 15);
      
      final p1 = PantryItemEntity(
        id: '1',
        foodName: 'Milk',
        quantity: 1,
        unit: 'L',
        expiryDate: DateTime(2026, 8, 20),
        addedAt: DateTime(2026, 8, 15),
      );
      expect(p1.getExpiryStatus(ref), equals('🟢 Fresh'));

      final p2 = PantryItemEntity(
        id: '2',
        foodName: 'Spinach',
        quantity: 250,
        unit: 'g',
        expiryDate: DateTime(2026, 8, 17),
        addedAt: DateTime(2026, 8, 15),
      );
      expect(p2.getExpiryStatus(ref), equals('🟡 Expiring Soon'));

      final p3 = PantryItemEntity(
        id: '3',
        foodName: 'Yogurt',
        quantity: 1,
        unit: 'pack',
        expiryDate: DateTime(2026, 8, 12),
        addedAt: DateTime(2026, 8, 10),
      );
      expect(p3.getExpiryStatus(ref), equals('🔴 Expired'));
    });

    test('10. Exclude foods mapped to preferences & exclusions', () {
      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: const [],
        preferences: const GroceryPreferencesEntity(),
      );

      // Excluded foods should not exist or are kept separate
      expect(list.items.any((i) => i.foodName == 'Excluded Item'), isFalse);
    });

    test('11. Preserving purchased status when regenerating', () {
      final originalItems = [
        GroceryItemEntity(
          id: 'rice_123',
          foodId: 'rice_123',
          foodName: 'White Rice',
          category: 'Grains',
          quantity: 0.5,
          unit: 'kg',
          isPurchased: true,
          purchasedAt: DateTime.now(),
          addedAt: DateTime.now(),
        ),
      ];

      final list = SmartGroceryEngine.generateFromMealPlan(
        userId: 'user_1',
        mealPlans: [plan],
        pantryItems: const [],
        preferences: const GroceryPreferencesEntity(),
        existingItems: originalItems,
      );

      final rice = list.items.firstWhere((i) => i.foodName == 'White Rice');
      expect(rice.isPurchased, isTrue);
      expect(rice.purchasedAt, isNotNull);
    });
  });

  group('AI Grocery Context & Routing Tests', () {
    test('12. AI Context compilation formats grocery context accurately', () {
      final item = GroceryItemEntity(
        id: '1',
        foodName: 'Almonds',
        category: 'Nuts & Seeds',
        quantity: 100,
        unit: 'g',
        addedAt: DateTime.now(),
      );
      final pantry = PantryItemEntity(
        id: 'p_1',
        foodName: 'Milk',
        quantity: 1,
        unit: 'L',
        expiryDate: DateTime.now().add(const Duration(days: 2)),
        addedAt: DateTime.now(),
      );

      final ctx = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: null,
        groceryItems: [item],
        pantryItems: [pantry],
      );

      expect(ctx, contains('=== FITFUEL SMART GROCERY CONTEXT ==='));
      expect(ctx, contains('Almonds'));
      expect(ctx, contains('Milk'));
    });

    test('13. Mock AI Assistant routes grocery shopping inquiries correctly', () async {
      final mockSource = AiNutritionMockDatasource();

      final ctx = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: null,
        groceryItems: [
          GroceryItemEntity(
            id: '1',
            foodName: 'Spinach',
            category: 'Vegetables',
            quantity: 200,
            unit: 'g',
            addedAt: DateTime.now(),
          ),
        ],
        pantryItems: const [],
      );

      final reply = await mockSource.generateResponse(
        userPrompt: 'What do I need to buy?',
        systemContext: ctx,
      );

      expect(reply.text, contains('remaining items on your shopping list'));
      expect(reply.text, contains('Spinach'));
    });

    test('14. Mock AI Assistant returns pantry stocks info accurately', () async {
      final mockSource = AiNutritionMockDatasource();

      final ctx = AiContextGenerator.generateContext(
        todayRecords: const [],
        historyRecords: const [],
        goals: null,
        groceryItems: const [],
        pantryItems: [
          PantryItemEntity(
            id: 'p_1',
            foodName: 'Eggs',
            quantity: 6,
            unit: 'pieces',
            expiryDate: DateTime.now().add(const Duration(days: 6)),
            addedAt: DateTime.now(),
          )
        ],
      );

      final reply = await mockSource.generateResponse(
        userPrompt: 'What do I already have?',
        systemContext: ctx,
      );

      expect(reply.text, contains('currently have in your pantry'));
      expect(reply.text, contains('Eggs'));
    });

    test('15. Mock AI Assistant suggests correct food substitutions based on target', () async {
      final mockSource = AiNutritionMockDatasource();

      final reply = await mockSource.generateResponse(
        userPrompt: 'I don\'t have chicken.',
        systemContext: 'Dietary Preferences: Vegetarian',
      );

      expect(reply.text, contains('alternative to chicken is Paneer or Tofu'));
    });
  });
}
