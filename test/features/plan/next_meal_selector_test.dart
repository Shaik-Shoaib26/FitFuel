import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/plan/domain/utils/next_meal_selector.dart';
import 'package:fitfuel/features/reminders/domain/entities/reminder_settings_entity.dart';

void main() {
  group('Phase 35.6.5 — NextMealSelector Tests', () {
    late FoodEntity breakfastFood;
    late FoodEntity morningSnackFood;
    late FoodEntity lunchFood;
    late FoodEntity afternoonSnackFood;
    late FoodEntity eveningSnackFood;
    late FoodEntity dinnerFood;

    late PlannedMealEntity breakfastMeal;
    late PlannedMealEntity morningSnackMeal;
    late PlannedMealEntity lunchMeal;
    late PlannedMealEntity afternoonSnackMeal;
    late PlannedMealEntity eveningSnackMeal;
    late PlannedMealEntity dinnerMeal;

    late MealPlanEntity standardPlan;
    late MealPlanEntity threeMealPlan;
    late MealPlanEntity sixMealPlan;

    final baseDate = DateTime(2026, 10, 5);

    setUp(() {
      breakfastFood = const FoodEntity(
        id: 'food_oatmeal',
        name: 'Oatmeal with Blueberries',
        category: 'breakfast',
        calories: 450,
        protein: 15,
        carbohydrates: 70,
        fats: 10,
        fiber: 8,
        sugar: 6,
        sodium: 120,
        servingSize: 250,
        servingUnit: 'bowl',
      );

      morningSnackFood = const FoodEntity(
        id: 'food_smoothie',
        name: 'Berry Protein Smoothie',
        category: 'beverages',
        calories: 320,
        protein: 24,
        carbohydrates: 38,
        fats: 6,
        fiber: 5,
        sugar: 12,
        sodium: 80,
        servingSize: 300,
        servingUnit: 'glass',
      );

      lunchFood = const FoodEntity(
        id: 'food_chicken_quinoa',
        name: 'Chicken Quinoa Bowl',
        category: 'lunch',
        calories: 550,
        protein: 42,
        carbohydrates: 52,
        fats: 16,
        fiber: 6,
        sugar: 4,
        sodium: 350,
        servingSize: 350,
        servingUnit: 'bowl',
      );

      afternoonSnackFood = const FoodEntity(
        id: 'food_trail_mix',
        name: 'Almond & Dried Fruit Trail Mix',
        category: 'snacks',
        calories: 180,
        protein: 6,
        carbohydrates: 20,
        fats: 9,
        fiber: 3,
        sugar: 12,
        sodium: 45,
        servingSize: 50,
        servingUnit: 'handful',
      );

      eveningSnackFood = const FoodEntity(
        id: 'food_greek_yogurt',
        name: 'Greek Yogurt & Almonds',
        category: 'snacks',
        calories: 220,
        protein: 18,
        carbohydrates: 12,
        fats: 10,
        fiber: 3,
        sugar: 5,
        sodium: 60,
        servingSize: 150,
        servingUnit: 'cup',
      );

      dinnerFood = const FoodEntity(
        id: 'food_salmon',
        name: 'Grilled Salmon with Asparagus',
        category: 'dinner',
        calories: 520,
        protein: 44,
        carbohydrates: 18,
        fats: 26,
        fiber: 5,
        sugar: 2,
        sodium: 400,
        servingSize: 300,
        servingUnit: 'plate',
      );

      breakfastMeal = PlannedMealEntity(
        mealType: 'Breakfast',
        foods: [
          PlannedFoodEntity(
            food: breakfastFood,
            servingQuantity: 1,
            unit: 'bowl',
            calories: 450,
            protein: 15,
            carbohydrates: 70,
            fat: 10,
            fiber: 8,
          ),
        ],
        totalCalories: 450,
        totalProtein: 15,
        totalCarbs: 70,
        totalFat: 10,
      );

      morningSnackMeal = PlannedMealEntity(
        mealType: 'Morning Snack',
        foods: [
          PlannedFoodEntity(
            food: morningSnackFood,
            servingQuantity: 1,
            unit: 'glass',
            calories: 320,
            protein: 24,
            carbohydrates: 38,
            fat: 6,
            fiber: 5,
          ),
        ],
        totalCalories: 320,
        totalProtein: 24,
        totalCarbs: 38,
        totalFat: 6,
      );

      lunchMeal = PlannedMealEntity(
        mealType: 'Lunch',
        foods: [
          PlannedFoodEntity(
            food: lunchFood,
            servingQuantity: 1,
            unit: 'bowl',
            calories: 550,
            protein: 42,
            carbohydrates: 52,
            fat: 16,
            fiber: 6,
          ),
        ],
        totalCalories: 550,
        totalProtein: 42,
        totalCarbs: 52,
        totalFat: 16,
      );

      afternoonSnackMeal = PlannedMealEntity(
        mealType: 'Afternoon Snack',
        foods: [
          PlannedFoodEntity(
            food: afternoonSnackFood,
            servingQuantity: 1,
            unit: 'handful',
            calories: 180,
            protein: 6,
            carbohydrates: 20,
            fat: 9,
            fiber: 3,
          ),
        ],
        totalCalories: 180,
        totalProtein: 6,
        totalCarbs: 20,
        totalFat: 9,
      );

      eveningSnackMeal = PlannedMealEntity(
        mealType: 'Evening Snack',
        foods: [
          PlannedFoodEntity(
            food: eveningSnackFood,
            servingQuantity: 1,
            unit: 'cup',
            calories: 220,
            protein: 18,
            carbohydrates: 12,
            fat: 10,
            fiber: 3,
          ),
        ],
        totalCalories: 220,
        totalProtein: 18,
        totalCarbs: 12,
        totalFat: 10,
      );

      dinnerMeal = PlannedMealEntity(
        mealType: 'Dinner',
        foods: [
          PlannedFoodEntity(
            food: dinnerFood,
            servingQuantity: 1,
            unit: 'plate',
            calories: 520,
            protein: 44,
            carbohydrates: 18,
            fat: 26,
            fiber: 5,
          ),
        ],
        totalCalories: 520,
        totalProtein: 44,
        totalCarbs: 18,
        totalFat: 26,
      );

      standardPlan = MealPlanEntity(
        id: 'plan_std_1',
        date: baseDate,
        targetCalories: 2060,
        targetProtein: 143,
        targetCarbs: 190,
        targetFat: 68,
        plannedCalories: 2060,
        plannedProtein: 143,
        plannedCarbs: 190,
        plannedFat: 68,
        meals: [
          breakfastMeal,
          morningSnackMeal,
          lunchMeal,
          eveningSnackMeal,
          dinnerMeal,
        ],
      );

      sixMealPlan = MealPlanEntity(
        id: 'plan_six_1',
        date: baseDate,
        targetCalories: 2240,
        targetProtein: 149,
        targetCarbs: 210,
        targetFat: 77,
        plannedCalories: 2240,
        plannedProtein: 149,
        plannedCarbs: 210,
        plannedFat: 77,
        meals: [
          breakfastMeal,
          morningSnackMeal,
          lunchMeal,
          afternoonSnackMeal,
          eveningSnackMeal,
          dinnerMeal,
        ],
      );

      threeMealPlan = MealPlanEntity(
        id: 'plan_three_1',
        date: baseDate,
        targetCalories: 1520,
        targetProtein: 101,
        targetCarbs: 140,
        targetFat: 52,
        plannedCalories: 1520,
        plannedProtein: 101,
        plannedCarbs: 140,
        plannedFat: 52,
        meals: [
          breakfastMeal,
          lunchMeal,
          dinnerMeal,
        ],
      );
    });

    // 1. before breakfast → Breakfast
    test('1. before breakfast -> selects Breakfast', () {
      final now = DateTime(2026, 10, 5, 7, 30);
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Breakfast');
      expect(selection.displaySlot, 'NEXT: BREAKFAST');
      expect(selection.scheduledTime, '8:00 AM');
      expect(selection.calories, 450);
      expect(selection.isNextDay, false);
      expect(selection.statusFor(breakfastMeal), MealStatus.current);
      expect(selection.statusFor(morningSnackMeal), MealStatus.upcoming);
    });

    // 2. after breakfast → Morning Snack
    test('2. after breakfast -> selects Morning Snack', () {
      final now = DateTime(2026, 10, 5, 9, 0); // Breakfast at 8:00 passed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Morning Snack');
      expect(selection.displaySlot, 'NEXT: MORNING SNACK');
      expect(selection.scheduledTime, '10:30 AM');
      expect(selection.calories, 320);
      expect(selection.isNextDay, false);
      expect(selection.statusFor(breakfastMeal), MealStatus.missed);
      expect(selection.statusFor(morningSnackMeal), MealStatus.current);
    });

    // 3. after morning snack → Lunch
    test('3. after morning snack -> selects Lunch', () {
      final now = DateTime(2026, 10, 5, 11, 0); // Morning snack at 10:30 passed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Lunch');
      expect(selection.displaySlot, 'NEXT: LUNCH');
      expect(selection.scheduledTime, '1:00 PM');
      expect(selection.calories, 550);
      expect(selection.statusFor(lunchMeal), MealStatus.current);
    });

    // 4. after lunch → Evening Snack
    test('4. after lunch -> selects Evening Snack', () {
      final now = DateTime(2026, 10, 5, 14, 0); // Lunch at 13:00 passed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Evening Snack');
      expect(selection.displaySlot, 'NEXT: EVENING SNACK');
      expect(selection.scheduledTime, '5:30 PM');
      expect(selection.calories, 220);
      expect(selection.statusFor(eveningSnackMeal), MealStatus.current);
    });

    // 5. after evening snack → Dinner
    test('5. after evening snack -> selects Dinner', () {
      final now = DateTime(2026, 10, 5, 18, 30); // Evening snack at 17:30 passed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Dinner');
      expect(selection.displaySlot, 'NEXT: DINNER');
      expect(selection.scheduledTime, '8:00 PM');
      expect(selection.calories, 520);
      expect(selection.statusFor(dinnerMeal), MealStatus.current);
    });

    // 6. after dinner → next day's Breakfast
    test('6. after dinner -> moves to next day Breakfast', () {
      final now = DateTime(2026, 10, 5, 21, 30); // Dinner at 20:00 passed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Breakfast');
      expect(selection.displaySlot, 'NEXT: BREAKFAST');
      expect(selection.scheduledTime, '8:00 AM');
      expect(selection.calories, 450);
      expect(selection.isNextDay, true);
    });

    // 7. completed future/current meal is skipped appropriately
    test('7. completed future/current meal is skipped appropriately', () {
      final now = DateTime(2026, 10, 5, 7, 30);
      final breakfastLog = NutritionRecordEntity(
        id: 'rec_b1',
        foodName: 'Oatmeal with Blueberries',
        mealType: 'Breakfast',
        calories: 450,
        protein: 15,
        carbohydrates: 70,
        fats: 10,
        sugar: 6,
        servingSize: 250,
        consumedAt: DateTime(2026, 10, 5, 7, 25),
        createdAt: DateTime(2026, 10, 5, 7, 25),
        updatedAt: DateTime(2026, 10, 5, 7, 25),
      );

      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: [breakfastLog],
        now: now,
      );

      // Breakfast is completed early, so it skips to Morning Snack
      expect(selection.meal?.mealType, 'Morning Snack');
      expect(selection.displaySlot, 'NEXT: MORNING SNACK');
      expect(selection.statusFor(breakfastMeal), MealStatus.completed);
      expect(selection.statusFor(morningSnackMeal), MealStatus.current);
      expect(selection.completedCount, 1);
    });

    // 8. no plan → empty-plan state
    test('8. no plan -> empty-plan state', () {
      final now = DateTime(2026, 10, 5, 12, 0);
      final selection = NextMealSelector.determineNextMeal(
        plan: null,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal, isNull);
      expect(selection.mealSlot, isEmpty);
      expect(selection.displaySlot, isEmpty);
      expect(selection.totalCount, 0);
      expect(selection.completedCount, 0);
    });

    // 9. only three meals in plan → respects available meals
    test('9. only three meals in plan -> respects available meals without phantom snacks', () {
      final now = DateTime(2026, 10, 5, 9, 30); // After breakfast, before lunch
      final selection = NextMealSelector.determineNextMeal(
        plan: threeMealPlan,
        loggedToday: const [],
        now: now,
      );

      // In a 3-meal plan, after breakfast it must jump directly to Lunch (no morning snack)
      expect(selection.meal?.mealType, 'Lunch');
      expect(selection.displaySlot, 'NEXT: LUNCH');
      expect(selection.totalCount, 3);
    });

    // 10. custom meal times → timestamp ordering wins
    test('10. custom meal times -> timestamp ordering wins over canonical names', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final customTimes = {
        'Dinner': '11:00', // Dinner moved early
        'Lunch': '15:00',  // Lunch moved late
      };

      final selection = NextMealSelector.determineNextMeal(
        plan: threeMealPlan,
        loggedToday: const [],
        now: now,
        customMealTimes: customTimes,
      );

      // At 10:00, Dinner at 11:00 is next because 11:00 is earlier than Lunch at 15:00!
      expect(selection.meal?.mealType, 'Dinner');
      expect(selection.displaySlot, 'NEXT: DINNER');
      expect(selection.scheduledTime, '11:00 AM');
    });

    // 11. missed meal does not automatically become completed
    test('11. missed meal does not automatically become completed in checklist or counts', () {
      final now = DateTime(2026, 10, 5, 15, 0); // 3 PM: Breakfast & Lunch missed
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [], // nothing logged!
        now: now,
      );

      expect(selection.statusFor(breakfastMeal), MealStatus.missed);
      expect(selection.statusFor(morningSnackMeal), MealStatus.missed);
      expect(selection.statusFor(lunchMeal), MealStatus.missed);
      expect(selection.statusFor(eveningSnackMeal), MealStatus.current);
      expect(selection.completedCount, 0); // Not completed!
      expect(selection.isAllCompleted, false);
    });

    // 12. next-meal image matches selected meal
    test('12. next-meal image matches selected meal food entity', () {
      final now = DateTime(2026, 10, 5, 9, 0);
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );

      final leadFood = selection.meal?.foods.first.food;
      expect(leadFood?.name, 'Berry Protein Smoothie');
      final imageUri = FoodImageResolver.resolve(leadFood);
      expect(imageUri, isNotEmpty);
      expect(imageUri, contains('unsplash.com'));
    });

    // 13. plan swap immediately updates hero
    test('13. plan swap immediately updates hero meal details', () {
      final now = DateTime(2026, 10, 5, 7, 30);
      final selection1 = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
      );
      expect(selection1.meal?.foods.first.food.name, 'Oatmeal with Blueberries');

      // Swap breakfast food with Greek Yogurt
      final swappedBreakfast = breakfastMeal.copyWith(
        foods: [
          PlannedFoodEntity(
            food: eveningSnackFood,
            servingQuantity: 1,
            unit: 'cup',
            calories: 220,
            protein: 18,
            carbohydrates: 12,
            fat: 10,
            fiber: 3,
          )
        ],
        totalCalories: 220,
      );

      final swappedPlan = standardPlan.copyWith(
        meals: [
          swappedBreakfast,
          morningSnackMeal,
          lunchMeal,
          eveningSnackMeal,
          dinnerMeal,
        ],
      );

      final selection2 = NextMealSelector.determineNextMeal(
        plan: swappedPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection2.meal?.foods.first.food.name, 'Greek Yogurt & Almonds');
      expect(selection2.calories, 220);
    });

    // 14. day rollover updates hero
    test('14. day rollover correctly updates hero from next-day to current-day', () {
      // Late night Oct 5th: 23:55 (after dinner)
      final lateNight = DateTime(2026, 10, 5, 23, 55);
      final lateSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: lateNight,
      );
      expect(lateSelection.isNextDay, true);
      expect(lateSelection.meal?.mealType, 'Breakfast');

      // Next morning Oct 6th: 00:05 (past midnight)
      final nextMorning = DateTime(2026, 10, 6, 0, 5);
      final morningSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: nextMorning,
      );
      expect(morningSelection.isNextDay, false);
      expect(morningSelection.meal?.mealType, 'Breakfast');
    });

    // 15. app resume recalculates next meal based on updated time
    test('15. time advancement (e.g. app resume) recalculates next meal', () {
      // Time when app opened: 10:00 AM (Morning Snack)
      final timeAtOpen = DateTime(2026, 10, 5, 10, 0);
      final selectionAtOpen = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: timeAtOpen,
      );
      expect(selectionAtOpen.meal?.mealType, 'Morning Snack');

      // App resumed at 13:30 (Lunch has passed, Evening Snack is next)
      final timeAtResume = DateTime(2026, 10, 5, 13, 30);
      final selectionAtResume = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: timeAtResume,
      );
      expect(selectionAtResume.meal?.mealType, 'Evening Snack');
    });

    // Bonus test: Reminder settings integration
    test('Respects ReminderSettingsEntity times when passed', () {
      const settings = ReminderSettingsEntity(
        breakfastTime: '06:30',
        lunchTime: '12:00',
        dinnerTime: '19:00',
        snackTime: '15:00',
      );

      final now = DateTime(2026, 10, 5, 6, 0);
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: now,
        reminderSettings: settings,
      );

      expect(selection.scheduledTime, '6:30 AM');
    });

    // ============================================================
    // Phase 35.6.5A — Dedicated Sequencing Tests
    // ============================================================

    test('35.6.5A-3: Lunch -> Afternoon Snack when that slot exists in plan', () {
      final now = DateTime(2026, 10, 5, 14, 0); // 2:00 PM (Lunch passed at 13:00)
      final selection = NextMealSelector.determineNextMeal(
        plan: sixMealPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Afternoon Snack');
      expect(selection.displaySlot, 'NEXT: AFTERNOON SNACK');
      expect(selection.scheduledTime, '4:00 PM');
      expect(selection.calories, 180);
      expect(selection.statusFor(afternoonSnackMeal), MealStatus.current);
    });

    test('35.6.5A-4: Afternoon Snack -> Evening Snack in 6-meal plan', () {
      final now = DateTime(2026, 10, 5, 16, 30); // 4:30 PM (Afternoon snack passed at 16:00)
      final selection = NextMealSelector.determineNextMeal(
        plan: sixMealPlan,
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Evening Snack');
      expect(selection.displaySlot, 'NEXT: EVENING SNACK');
      expect(selection.scheduledTime, '5:30 PM');
      expect(selection.calories, 220);
      expect(selection.statusFor(eveningSnackMeal), MealStatus.current);
    });

    test('35.6.5A-5: Lunch -> Evening Snack when no Afternoon Snack exists in 5-meal plan', () {
      final now = DateTime(2026, 10, 5, 14, 0); // 2:00 PM (Lunch passed at 13:00)
      final selection = NextMealSelector.determineNextMeal(
        plan: standardPlan, // 5-meal plan: Breakfast, Morning Snack, Lunch, Evening Snack, Dinner
        loggedToday: const [],
        now: now,
      );

      expect(selection.meal?.mealType, 'Evening Snack');
      expect(selection.displaySlot, 'NEXT: EVENING SNACK');
      expect(selection.scheduledTime, '5:30 PM');
      expect(selection.statusFor(eveningSnackMeal), MealStatus.current);
    });

    test('35.6.5A-10: Home and Plan return exactly the same next meal', () {
      final now = DateTime(2026, 10, 5, 14, 30); // After lunch
      final loggedToday = <NutritionRecordEntity>[];

      // Evaluation as executed on Plan screen
      final planSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: loggedToday,
        now: now,
      );

      // Evaluation as executed on Home screen
      final homeSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: loggedToday,
        now: now,
      );

      expect(homeSelection.meal?.mealType, planSelection.meal?.mealType);
      expect(homeSelection.meal?.mealType, 'Evening Snack');
      expect(homeSelection.meal?.foods.first.food.name, planSelection.meal?.foods.first.food.name);
      expect(homeSelection.scheduledTime, planSelection.scheduledTime);
      expect(homeSelection.calories, planSelection.calories);
    });

    test('35.6.5A-11: next-meal image changes with selected meal (Lunch -> Evening Snack)', () {
      // 1. Time at Lunch (12:30 PM)
      final lunchTime = DateTime(2026, 10, 5, 12, 30);
      final lunchSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: lunchTime,
      );
      final lunchFoodItem = lunchSelection.meal?.foods.first.food;
      final lunchImageUrl = FoodImageResolver.resolve(lunchFoodItem);
      expect(lunchSelection.meal?.mealType, 'Lunch');
      expect(lunchFoodItem?.name, 'Chicken Quinoa Bowl');

      // 2. Time at Evening Snack (3:30 PM)
      final snackTime = DateTime(2026, 10, 5, 15, 30);
      final snackSelection = NextMealSelector.determineNextMeal(
        plan: standardPlan,
        loggedToday: const [],
        now: snackTime,
      );
      final snackFoodItem = snackSelection.meal?.foods.first.food;
      final snackImageUrl = FoodImageResolver.resolve(snackFoodItem);
      expect(snackSelection.meal?.mealType, 'Evening Snack');
      expect(snackFoodItem?.name, 'Greek Yogurt & Almonds');

      // Food photograph must update and NOT retain Lunch photograph!
      expect(lunchImageUrl, isNot(equals(snackImageUrl)));
      expect(lunchSelection.mealSlot, isNot(equals(snackSelection.mealSlot)));
      expect(lunchSelection.calories, isNot(equals(snackSelection.calories)));
    });

    test('35.6.5A-Fallback: sortByCanonicalOrder strictly follows canonical order and skips absent snacks', () {
      // 6-meal plan unordered
      final unordered6 = [
        dinnerMeal,
        lunchMeal,
        afternoonSnackMeal,
        breakfastMeal,
        eveningSnackMeal,
        morningSnackMeal,
      ];
      final sorted6 = NextMealSelector.sortByCanonicalOrder(unordered6);
      expect(sorted6.map((m) => m.mealType).toList(), [
        'Breakfast',
        'Morning Snack',
        'Lunch',
        'Afternoon Snack',
        'Evening Snack',
        'Dinner',
      ]);

      // 5-meal plan unordered (skips afternoon snack naturally)
      final unordered5 = [
        dinnerMeal,
        eveningSnackMeal,
        lunchMeal,
        breakfastMeal,
        morningSnackMeal,
      ];
      final sorted5 = NextMealSelector.sortByCanonicalOrder(unordered5);
      expect(sorted5.map((m) => m.mealType).toList(), [
        'Breakfast',
        'Morning Snack',
        'Lunch',
        'Evening Snack',
        'Dinner',
      ]);

      // 3-meal plan unordered (skips all snacks naturally)
      final unordered3 = [
        dinnerMeal,
        breakfastMeal,
        lunchMeal,
      ];
      final sorted3 = NextMealSelector.sortByCanonicalOrder(unordered3);
      expect(sorted3.map((m) => m.mealType).toList(), [
        'Breakfast',
        'Lunch',
        'Dinner',
      ]);
    });
  });
}
