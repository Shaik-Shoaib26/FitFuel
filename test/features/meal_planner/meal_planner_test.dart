import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/food/presentation/providers/food_providers.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/repositories/meal_plan_repository.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_distribution_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_plan_calculator.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/meal_planner/presentation/providers/meal_planner_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';

// Fake User implementation for testing auth stream
class FakeUser implements User {
  @override
  final String uid;
  @override
  final String email;

  FakeUser({required this.uid, required this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock MealPlanRepository implementation
class MockMealPlanRepository implements MealPlanRepository {
  final Map<String, MealPlanEntity> storage = {};
  bool saveCalled = false;
  bool deleteCalled = false;
  bool returnErrorOnGet = false;

  @override
  Future<MealPlanEntity?> getMealPlanForDate(String userId, DateTime date) async {
    if (returnErrorOnGet) {
      throw Exception('Database connection failed');
    }
    final key = '$userId-${date.year}-${date.month}-${date.day}';
    return storage[key];
  }

  @override
  Future<void> saveMealPlan(String userId, MealPlanEntity mealPlan) async {
    saveCalled = true;
    final key = '$userId-${mealPlan.date.year}-${mealPlan.date.month}-${mealPlan.date.day}';
    storage[key] = mealPlan;
  }

  @override
  Future<void> deleteMealPlan(String userId, String mealPlanId) async {
    deleteCalled = true;
    storage.removeWhere((k, v) => k.startsWith(userId) && v.id == mealPlanId);
  }
}

void main() {
  final testDate = DateTime(2026, 8, 14);

  final testProfile = UserProfileEntity(
    uid: 'user123',
    displayName: 'Shoaib',
    email: 'shoaib@test.com',
    gender: 'Male',
    age: 25,
    height: 180.0,
    weight: 75.0,
    activityLevel: 'Active',
    fitnessGoal: 'Lose Weight',
    dietaryPreference: 'Vegetarian',
    createdAt: testDate,
    updatedAt: testDate,
  );

  final testGoals = NutritionGoalsEntity(
    userId: 'user123',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 120.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 60.0,
    updatedAt: testDate,
  );

  final testFoods = [
    const FoodEntity(
      id: 'f1',
      name: 'Paneer Butter Masala',
      category: 'Indian',
      servingSize: 100,
      servingUnit: 'g',
      calories: 300,
      protein: 15,
      carbohydrates: 8,
      fats: 22,
      fiber: 1,
      sugar: 2,
      sodium: 400,
      isIndian: true,
      isVegetarian: true,
    ),
    const FoodEntity(
      id: 'f2',
      name: 'Oats Cooked',
      category: 'Breakfast',
      servingSize: 100,
      servingUnit: 'g',
      calories: 150,
      protein: 6,
      carbohydrates: 25,
      fats: 3,
      fiber: 4,
      sugar: 1,
      sodium: 10,
      isVegetarian: true,
    ),
    const FoodEntity(
      id: 'f3',
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
      isVegetarian: false,
    )
  ];

  group('Meal Plan Calculator Tests', () {
    test('calculateFoodPortion correctly scales macros and calories', () {
      final baseFood = testFoods[0]; // Paneer Butter Masala: 300kcal per 100g, P:15g, C:8g, F:22g
      final portion = MealPlanCalculator.calculateFoodPortion(baseFood, 150, 'g');

      expect(portion.calories, 450.0);
      expect(portion.protein, 22.5);
      expect(portion.carbohydrates, 12.0);
      expect(portion.fat, 33.0);
      expect(portion.servingQuantity, 150.0);
    });

    test('recalculateMealPlan accurately sums all planned meals', () {
      final plannedBreakfast = PlannedFoodEntity(
        food: testFoods[1],
        calories: 300,
        protein: 12,
        carbohydrates: 50,
        fat: 6,
        fiber: 8,
        servingQuantity: 200,
        unit: 'g',
      );

      final mealPlan = MealPlanEntity(
        id: '2026-08-14',
        date: testDate,
        targetCalories: 2000,
        targetProtein: 120,
        targetCarbs: 200,
        targetFat: 60,
        meals: [
          PlannedMealEntity(
            mealType: 'Breakfast',
            foods: [plannedBreakfast],
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
          )
        ],
      );

      final recalculated = MealPlanCalculator.recalculateMealPlan(mealPlan);
      expect(recalculated.meals[0].totalCalories, 300.0);
      expect(recalculated.meals[0].totalProtein, 12.0);
      expect(recalculated.plannedCalories, 300.0);
      expect(recalculated.plannedProtein, 12.0);
    });
  });

  group('Meal Distribution Engine Tests', () {
    test('generateDailyPlan correctly filters by dietaryPreference', () {
      final plan = MealDistributionEngine.generateDailyPlan(
        databaseFoods: testFoods,
        targetCalories: 2000,
        targetProtein: 120,
        targetCarbs: 200,
        targetFat: 60,
        dietaryPreference: 'Vegetarian',
        excludedFoodNames: [],
        favoriteFoodIds: [],
        recentFoodIds: [],
      );

      // Verify that no chicken breast is selected in any meal because the preference is Vegetarian
      for (var meal in plan) {
        for (var plannedFood in meal.foods) {
          expect(plannedFood.food.isVegetarian, isTrue);
          expect(plannedFood.food.name.toLowerCase().contains('chicken'), isFalse);
        }
      }
    });

    test('swapFood returns a nutritionally suitable replacement', () {
      final initialFood = PlannedFoodEntity(
        food: testFoods[0],
        calories: 300,
        protein: 15,
        carbohydrates: 8,
        fat: 22,
        fiber: 1,
        servingQuantity: 100,
        unit: 'g',
      );

      final replaced = MealDistributionEngine.swapFood(
        currentFood: initialFood,
        mealType: 'Lunch',
        databaseFoods: testFoods,
        dietaryPreference: 'Vegetarian',
        excludedFoodNames: [],
        currentlyUsedFoodIds: [],
      );

      // Should return a different food (Oats Cooked) since Paneer is excluded
      expect(replaced.food.id, 'f2');
    });
  });

  group('MealPlannerController Provider Tests', () {
    late MockMealPlanRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockMealPlanRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('Controller initializes with AsyncValue.loading when auth state is loading', () {
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final state = container.read(mealPlannerControllerProvider);
      expect(state, const AsyncValue<MealPlanEntity?>.loading());
    });

    test('Controller handles unauthenticated user cleanly', () async {
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      // Allow auth state stream to emit unauthenticated (null)
      await container.read(authStateStreamProvider.future).catchError((_) => null);

      final state = container.read(mealPlannerControllerProvider);
      expect(state.value, isNull);
      expect(state is AsyncData, isTrue);
    });

    test('Missing profile or nutrition goals correctly loads data as null for planners', () async {
      final fakeUser = FakeUser(uid: 'user123', email: 'shoaib@test.com');
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
          currentProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
          nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(null)),
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      // Trigger stream evaluations
      await container.read(authStateStreamProvider.future);

      final state = container.read(mealPlannerControllerProvider);
      expect(state.value, isNull);
    });

    test('Controller loads existing meal plan from database successfully', () async {
      final fakeUser = FakeUser(uid: 'user123', email: 'shoaib@test.com');
      final today = DateTime.now();
      final key = 'user123-${today.year}-${today.month}-${today.day}';
      
      final existingPlan = MealPlanEntity(
        id: 'existing_id',
        date: today,
        targetCalories: 2000,
        targetProtein: 120,
        targetCarbs: 200,
        targetFat: 60,
        meals: [],
      );
      mockRepo.storage[key] = existingPlan;

      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      await container.read(authStateStreamProvider.future);
      // Wait for loadTodayPlan to complete
      await container.read(mealPlannerControllerProvider.notifier).loadTodayPlan();

      final state = container.read(mealPlannerControllerProvider);
      expect(state.value, equals(existingPlan));
    });

    test('Empty food database throws Exception and transitions to error state', () async {
      final fakeUser = FakeUser(uid: 'user123', email: 'shoaib@test.com');
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
          currentProfileStreamProvider.overrideWith((ref) => Stream.value(testProfile)),
          nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(testGoals)),
          searchFoodsProvider.overrideWith((ref) => Future.value([])), // Empty list
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      await container.read(authStateStreamProvider.future);
      await container.read(currentProfileStreamProvider.future).catchError((_) => null);
      await container.read(nutritionGoalsStreamProvider.future).catchError((_) => null);
      await container.read(mealPlannerControllerProvider.notifier).generatePlan();

      final state = container.read(mealPlannerControllerProvider);
      expect(state is AsyncError, isTrue);
      expect(state.error.toString(), contains('No foods available for meal planning.'));
    });

    test('Database loading failure throws Exception and transitions to error state', () async {
      final fakeUser = FakeUser(uid: 'user123', email: 'shoaib@test.com');
      mockRepo.returnErrorOnGet = true;

      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
          mealPlanRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      await container.read(authStateStreamProvider.future);
      await container.read(mealPlannerControllerProvider.notifier).loadTodayPlan();

      final state = container.read(mealPlannerControllerProvider);
      expect(state is AsyncError, isTrue);
      expect(state.error.toString(), contains('Database connection failed'));
    });
  });

  group('Meal Planner Routing Tests', () {
    test('Router provider contains route for /meal-planner matching AppRoutes.mealPlan', () {
      final container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = container.read(routerProvider);
      final routes = router.configuration.routes;
      
      bool found = false;
      for (final route in routes) {
        if (route is GoRoute && route.path == '/meal-planner') {
          found = true;
          break;
        }
      }
      expect(found, isTrue);
      expect(AppRoutes.mealPlan, equals('/meal-planner'));
    });
  });
}
