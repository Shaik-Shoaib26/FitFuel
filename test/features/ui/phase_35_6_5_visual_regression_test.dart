import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitfuel/core/network/connectivity_service.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/theme/app_theme.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/plan/presentation/screens/plan_screen.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_empty_state.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_macro_summary.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_next_meal_hero.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_progress_card.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_quick_actions.dart';
import 'package:fitfuel/features/plan/presentation/widgets/plan_recommendation_card.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/reminders/domain/entities/reminder_settings_entity.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';
import 'package:fitfuel/features/smart_eat/domain/entities/smart_food_recommendation_entity.dart';
import 'package:fitfuel/features/smart_eat/domain/enums/recommendation_priority.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/features/smart_eat/presentation/providers/smart_eat_providers.dart';

class _MockConnectivityService extends Mock implements ConnectivityService {}

class _MockUser extends Mock implements User {
  @override
  String get uid => 'user_qa_123';
}

class _StubMealPlannerController extends MealPlannerController {
  final MealPlanEntity? _plan;

  _StubMealPlannerController(super.ref, this._plan) {
    state = AsyncValue.data(_plan);
  }

  @override
  Future<void> loadTodayPlan() async {
    state = AsyncValue.data(_plan);
  }

  @override
  Future<void> generatePlan() async {}
}

UserProfileEntity _mockProfile() => UserProfileEntity(
      uid: 'user_qa_123',
      email: 'qa@fitfuel.app',
      displayName: 'Shoaib',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

NutritionGoalsEntity _mockGoals() => NutritionGoalsEntity(
      userId: 'user_qa_123',
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 140,
      carbsTargetGrams: 220,
      fatTargetGrams: 60,
      updatedAt: DateTime.now(),
    );

FoodEntity _sampleFood({
  required String id,
  required String name,
  required String category,
  required double calories,
  required double protein,
  required double carbs,
  required double fats,
}) {
  return FoodEntity(
    id: id,
    name: name,
    category: category,
    calories: calories,
    protein: protein,
    carbohydrates: carbs,
    fats: fats,
    fiber: 5,
    sugar: 4,
    sodium: 120,
    servingSize: 200,
    servingUnit: 'portion',
  );
}

MealPlanEntity _sampleMealPlan() {
  final f1 = _sampleFood(
    id: 'f_oatmeal',
    name: 'Oatmeal with Berries',
    category: 'breakfast',
    calories: 450,
    protein: 15,
    carbs: 70,
    fats: 10,
  );
  final f2 = _sampleFood(
    id: 'f_smoothie',
    name: 'Berry Protein Smoothie',
    category: 'beverages',
    calories: 320,
    protein: 24,
    carbs: 38,
    fats: 6,
  );
  final f3 = _sampleFood(
    id: 'f_chicken_bowl',
    name: 'Chicken Quinoa Bowl',
    category: 'lunch',
    calories: 550,
    protein: 42,
    carbs: 52,
    fats: 16,
  );
  final f4 = _sampleFood(
    id: 'f_greek_yogurt',
    name: 'Greek Yogurt & Almonds',
    category: 'snacks',
    calories: 220,
    protein: 18,
    carbs: 12,
    fats: 10,
  );
  final f5 = _sampleFood(
    id: 'f_salmon_plate',
    name: 'Grilled Salmon Bowl',
    category: 'dinner',
    calories: 520,
    protein: 44,
    carbs: 18,
    fats: 26,
  );

  return MealPlanEntity(
    id: 'plan_active_1',
    date: DateTime(2026, 10, 5),
    targetCalories: 2060,
    targetProtein: 143,
    targetCarbs: 190,
    targetFat: 68,
    plannedCalories: 2060,
    plannedProtein: 143,
    plannedCarbs: 190,
    plannedFat: 68,
    meals: [
      PlannedMealEntity(
        mealType: 'Breakfast',
        foods: [PlannedFoodEntity(food: f1, servingQuantity: 1, unit: 'bowl', calories: 450, protein: 15, carbohydrates: 70, fat: 10, fiber: 5)],
        totalCalories: 450,
        totalProtein: 15,
        totalCarbs: 70,
        totalFat: 10,
      ),
      PlannedMealEntity(
        mealType: 'Morning Snack',
        foods: [PlannedFoodEntity(food: f2, servingQuantity: 1, unit: 'glass', calories: 320, protein: 24, carbohydrates: 38, fat: 6, fiber: 5)],
        totalCalories: 320,
        totalProtein: 24,
        totalCarbs: 38,
        totalFat: 6,
      ),
      PlannedMealEntity(
        mealType: 'Lunch',
        foods: [PlannedFoodEntity(food: f3, servingQuantity: 1, unit: 'bowl', calories: 550, protein: 42, carbohydrates: 52, fat: 16, fiber: 5)],
        totalCalories: 550,
        totalProtein: 42,
        totalCarbs: 52,
        totalFat: 16,
      ),
      PlannedMealEntity(
        mealType: 'Evening Snack',
        foods: [PlannedFoodEntity(food: f4, servingQuantity: 1, unit: 'cup', calories: 220, protein: 18, carbohydrates: 12, fat: 10, fiber: 3)],
        totalCalories: 220,
        totalProtein: 18,
        totalCarbs: 12,
        totalFat: 10,
      ),
      PlannedMealEntity(
        mealType: 'Dinner',
        foods: [PlannedFoodEntity(food: f5, servingQuantity: 1, unit: 'plate', calories: 520, protein: 44, carbohydrates: 18, fat: 26, fiber: 5)],
        totalCalories: 520,
        totalProtein: 44,
        totalCarbs: 18,
        totalFat: 26,
      ),
    ],
  );
}

SmartFoodRecommendationEntity _sampleRecommendation() {
  return const SmartFoodRecommendationEntity(
    id: 'rec_1',
    foodId: 'food_chicken_quinoa',
    foodName: 'Chicken Quinoa Bowl',
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    category: 'Lunch',
    servingSize: 350,
    calories: 450,
    protein: 35,
    carbs: 42,
    fat: 14,
    fiber: 6,
    matchScore: 95,
    priority: RecommendationPriority.high,
    reasons: [],
    tags: ['High Protein Lunch'],
    pantryAvailable: true,
    groceryAvailable: true,
    recentlyConsumed: false,
    isFavorite: false,
    estimatedPreparationMinutes: 15,
  );
}

List<Override> _createOverrides({
  MealPlanEntity? plan,
  List<NutritionRecordEntity> logs = const [],
  SmartFoodRecommendationEntity? recommendation,
}) {
  final conn = _MockConnectivityService();
  when(() => conn.onStatusChanged).thenAnswer((_) => Stream.value(NetworkStatus.online));
  when(() => conn.currentStatus).thenAnswer((_) => Future.value(NetworkStatus.online));

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
    authStateStreamProvider.overrideWith((ref) => Stream.value(_MockUser())),
    currentProfileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile())),
    nutritionStreamProvider.overrideWith((ref) => Stream.value(logs)),
    nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(_mockGoals())),
    remindersSettingsStreamProvider.overrideWith((ref) => Stream.value(const ReminderSettingsEntity())),
    smartEatTopRecommendationProvider.overrideWith((ref) => AsyncValue.data(recommendation)),
    mealPlannerControllerProvider.overrideWith((ref) => _StubMealPlannerController(ref, plan)),
  ];
}

Widget _wrapPlanApp({
  required Widget child,
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settlePump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in ['PlusJakartaSans', 'Outfit']) {
      final file = File('assets/fonts/$family.ttf');
      if (file.existsSync()) {
        final loader = FontLoader(family);
        loader.addFont(rootBundle.load('assets/fonts/$family.ttf'));
        await loader.load();
      }
    }
  });

  group('Phase 35.6.5 — Option A Modern & Minimal Plan Dashboard Visual Tests', () {
    testWidgets('1. Plan dashboard renders all Option A components faithfully', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final plan = _sampleMealPlan();
      final rec = _sampleRecommendation();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(plan: plan, recommendation: rec),
          child: _wrapPlanApp(child: const PlanScreen()),
        ),
      );
      await _settlePump(tester);

      expect(tester.takeException(), isNull);

      // App Bar
      expect(find.text('Plan'), findsOneWidget);

      // Hero Card
      expect(find.byType(PlanNextMealHero), findsOneWidget);
      expect(find.byType(PlanProgressCard), findsOneWidget);
      expect(find.byType(PlanMacroSummary), findsOneWidget);
      expect(find.text('View Full Meal Plan'), findsOneWidget);
      expect(find.byType(PlanQuickActions), findsOneWidget);
      expect(find.byType(PlanRecommendationCard), findsOneWidget);

      // Content inside Quick Actions
      expect(find.text('AI Plan'), findsOneWidget);
      expect(find.text('Add Meal'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);

      // Content inside Macro Summary
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);

      // Content inside Progress Card
      expect(find.text('Today\'s Plan Progress'), findsOneWidget);
      expect(find.text('View plan'), findsOneWidget);
    });

    testWidgets('2. Zero overflow across 320, 360, 390, 430 px and 800px tablet', (tester) async {
      final viewports = [
        const Size(320, 640),
        const Size(360, 780),
        const Size(390, 844),
        const Size(430, 932),
        const Size(800, 1200),
      ];

      final plan = _sampleMealPlan();
      final rec = _sampleRecommendation();

      for (final size in viewports) {
        _setViewport(tester, size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _createOverrides(plan: plan, recommendation: rec),
            child: _wrapPlanApp(child: const PlanScreen()),
          ),
        );
        await _settlePump(tester);

        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow occurred at viewport $size',
        );
      }
    });

    testWidgets('3. Large text scaling 1.4x renders cleanly without clipping', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final plan = _sampleMealPlan();
      final rec = _sampleRecommendation();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(plan: plan, recommendation: rec),
          child: _wrapPlanApp(
            textScale: 1.4,
            child: const PlanScreen(),
          ),
        ),
      );
      await _settlePump(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('View Full Meal Plan'), findsOneWidget);
    });

    testWidgets('4. Empty plan state renders polished CTA and supporting sections', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final rec = _sampleRecommendation();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(plan: null, recommendation: rec),
          child: _wrapPlanApp(child: const PlanScreen()),
        ),
      );
      await _settlePump(tester);

      expect(tester.takeException(), isNull);

      // Empty State Card
      expect(find.byType(PlanEmptyState), findsOneWidget);
      expect(find.text('Create your meal plan'), findsOneWidget);
      expect(find.text('Create Meal Plan'), findsOneWidget);
      expect(find.text('Smart Eat'), findsOneWidget);

      // Quick Actions and Recommendations still available
      expect(find.byType(PlanQuickActions), findsOneWidget);
      expect(find.byType(PlanRecommendationCard), findsOneWidget);
    });

    testWidgets('5. Dark theme renders with harmonious dark palette', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final plan = _sampleMealPlan();
      final rec = _sampleRecommendation();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(plan: plan, recommendation: rec),
          child: _wrapPlanApp(
            brightness: Brightness.dark,
            child: const PlanScreen(),
          ),
        ),
      );
      await _settlePump(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanNextMealHero), findsOneWidget);
      expect(find.byType(PlanProgressCard), findsOneWidget);
    });
  });
}
