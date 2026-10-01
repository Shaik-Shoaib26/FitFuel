import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitfuel/app/navigation/feature_action_navigation.dart';
import 'package:fitfuel/core/network/connectivity_service.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/theme/app_theme.dart';
import 'package:fitfuel/core/widgets/adaptive_page_layout.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';

import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fitfuel/features/dashboard/presentation/widgets/home_quick_actions.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/insights/domain/entities/action_recommendation_entity.dart';
import 'package:fitfuel/features/insights/domain/entities/daily_focus_entity.dart';
import 'package:fitfuel/features/insights/domain/entities/health_insight_entity.dart';
import 'package:fitfuel/features/insights/presentation/providers/insights_providers.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/reminders/domain/entities/daily_routine_entity.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';

import '../ui/navigation_architecture_test.dart' as navigation;

class MockConnectivityService extends Mock implements ConnectivityService {}

class _StubMealPlanner extends MealPlannerController {
  // ignore: use_super_parameters
  _StubMealPlanner(Ref ref, MealPlanEntity? plan) : super(ref) {
    state = AsyncValue.data(plan);
  }

  @override
  Future<void> loadTodayPlan() async {}

  @override
  Future<void> adaptPlanToLogs(List<NutritionRecordEntity> todayLogsList) async {}
}

late MockConnectivityService mockConnectivity;

NutritionRecordEntity _record({
  double calories = 0,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  String mealType = 'Breakfast',
}) =>
    NutritionRecordEntity(
      id: 'r-${mealType.toLowerCase()}',
      foodName: 'Sample meal',
      mealType: mealType,
      calories: calories,
      protein: protein,
      carbohydrates: carbs,
      fats: fat,
      sugar: 5,
      servingSize: 1,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

NutritionGoalsEntity _goals({
  int calories = 2000,
  double protein = 150,
  double carbs = 250,
  double fat = 65,
}) =>
    NutritionGoalsEntity(
      userId: 'u',
      dailyCalorieTarget: calories,
      proteinTargetGrams: protein,
      carbsTargetGrams: carbs,
      fatTargetGrams: fat,
      updatedAt: DateTime.now(),
    );

DailyFocusEntity _focus() => const DailyFocusEntity(
      title: 'Stay on top of hydration',
      description: "You're at 1.4L of your 2.5L goal.",
      category: InsightCategory.hydration,
      priority: InsightPriority.medium,
      recommendedActions: [
        ActionRecommendationEntity(
          id: 'focus-hydration',
          title: 'Add Water',
          description: 'Log a glass of water',
          actionType: InsightActionType.logWater,
          route: '/health?section=hydration&action=add',
          priority: InsightPriority.medium,
        )
      ],
    );

HealthRecordEntity _todayRecord() => HealthRecordEntity(
      id: '2026-09-20',
      date: DateTime.now().toString().split(' ').first,
      waterIntakeMl: 1400,
      waterTargetMl: 2500,
      exercises: const [
        ExerciseEntity(activity: 'Run', duration: 32, caloriesBurned: 300)
      ],
      habits: const {
        'Sleep 7-8h': true,
        '10k Steps': true,
        'Stretching': false,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

MealPlanEntity _planWithLunch() {
  final food = PredefinedFoodData.foods.first.toEntity();
  final plannedFood = PlannedFoodEntity(
    food: food,
    servingQuantity: 1,
    unit: 'bowl',
    calories: 520,
    protein: 35,
    carbohydrates: 60,
    fat: 12,
    fiber: 5,
  );
  final meal = PlannedMealEntity(
    mealType: 'Lunch',
    foods: [plannedFood],
    totalCalories: 520,
    totalProtein: 35,
    totalCarbs: 60,
    totalFat: 12,
  );
  return MealPlanEntity(
    id: 'plan',
    date: DateTime.now(),
    targetCalories: 2000,
    targetProtein: 150,
    targetCarbs: 250,
    targetFat: 65,
    meals: [meal],
    plannedCalories: 520,
    plannedProtein: 35,
    plannedCarbs: 60,
    plannedFat: 12,
  );
}

List<Override> _overrides({
  List<NutritionRecordEntity> records = const [],
  NutritionGoalsEntity? goals,
  AsyncValue<dynamic> focus = const AsyncValue.loading(),
  HealthRecordEntity? today,
  Override? authOverride,
  Override? plannerOverride,
}) =>
    [
      connectivityServiceProvider.overrideWithValue(mockConnectivity),
      authOverride ??
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      nutritionStreamProvider.overrideWith((ref) => Stream.value(records)),
      nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(goals)),
      healthStreamProvider
          .overrideWith((ref) => Stream.value(today == null ? [] : [today])),
      todayHealthRecordProvider.overrideWithValue(today),
      dailyRoutineProvider.overrideWithValue(const DailyRoutineEntity(
        date: '',
        routineItems: [],
        completedItems: [],
        pendingItems: [],
        completionPercentage: 0,
        totalReminders: 0,
        completedReminders: 0,
      )),
      dailyFocusProvider.overrideWithValue(focus),
      if (plannerOverride != null) plannerOverride,
    ];

Widget _host(Widget child, {double scale = 1.0}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData.fromView(
                WidgetsBinding.instance.platformDispatcher.views.first)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  double scale = 1.0,
}) async {
  await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: _host(child, scale: scale)));
  await _settle(tester);
}

GoRouter _navRouter(Widget home) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => home),
        for (final path in const [
          '/nutrition',
          '/nutrition/log',
          '/health',
          '/ai',
          '/plan',
          '/plan/meals',
          '/progress',
          '/progress/insights',
          '/profile',
        ])
          GoRoute(
              path: path,
              builder: (_, state) =>
                  Scaffold(body: Text('page:${state.uri.path}'))),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in ['PlusJakartaSans', 'Outfit']) {
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(
          await File('assets/fonts/$family.ttf').readAsBytes())));
      await loader.load();
    }
  });

  setUp(() {
    mockConnectivity = MockConnectivityService();
    when(() => mockConnectivity.onStatusChanged)
        .thenAnswer((_) => Stream.value(NetworkStatus.online));
    when(() => mockConnectivity.currentStatus)
        .thenAnswer((_) => Future.value(NetworkStatus.online));
  });

  group('Phase 35.3B — Home redesign', () {
    testWidgets('1. Home renders with normal data', (tester) async {
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(
          records: [
            _record(calories: 580, protein: 78, carbs: 180, fat: 42),
          ],
          goals: _goals(),
          focus: AsyncData<dynamic>(_focus()),
          today: _todayRecord(),
        ),
      );
      expect(find.text("Today's Nutrition"), findsOneWidget);
      expect(find.text("Today's Focus"), findsOneWidget);
      expect(find.text('Up Next'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text("Today's Health"), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      expect(find.text('Stay on top of hydration'), findsOneWidget);
      expect(find.text('1.4 / 2.5 L'), findsOneWidget);
      expect(find.text('32 min'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Home renders with no nutrition logs', (tester) async {
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(goals: _goals()),
      );
      expect(find.text('Nothing logged yet.'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Home handles no next meal', (tester) async {
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(goals: _goals()),
      );
      expect(find.text('No meals planned yet'), findsOneWidget);
      expect(find.text('Create Meal Plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Macro progress does not crash over target', (tester) async {
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(
          records: [
            _record(calories: 2500, protein: 220, carbs: 400, fat: 100),
          ],
          goals: _goals(),
          focus: AsyncData<dynamic>(_focus()),
        ),
      );
      expect(find.text('kcal over'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Zero target does not divide by zero', (tester) async {
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(
          records: [_record(calories: 100, protein: 10)],
          goals: _goals(calories: 0, protein: 0, carbs: 0, fat: 0),
        ),
      );
      expect(find.text('Not set'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Quick actions navigate correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _navRouter(const DashboardScreen());
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(goals: _goals()),
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await _settle(tester);

      Future<void> tapAndExpect(String label, String path) async {
        await tester.tap(find.descendant(
            of: find.byType(HomeQuickActions), matching: find.text(label)));
        await _settle(tester);
        expect(router.routeInformationProvider.value.uri.path, path);
        router.go('/home');
        await _settle(tester);
      }

      await tapAndExpect('Log Food', '/nutrition/log');
      await tapAndExpect('Add Water', '/health');
      await tapAndExpect('Exercise', '/health');
      await tapAndExpect('Ask AI', '/ai');
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      ['7. 320px', Size(320, 640)],
      ['7b. 360px', Size(360, 780)],
      ['7c. 412px', Size(412, 892)],
      ['8. 390px', Size(390, 844)],
      ['9. 768px', Size(768, 1024)],
    ]) {
      testWidgets('${size[0]} layout has no overflow', (tester) async {
        tester.view.physicalSize = size[1] as Size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(
          tester,
          const DashboardScreen(),
          overrides: _overrides(
            records: [_record(calories: 580, protein: 78)],
            goals: _goals(),
            focus: AsyncData<dynamic>(_focus()),
            today: _todayRecord(),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('10. 1440px layout remains constrained', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(goals: _goals(), focus: AsyncData<dynamic>(_focus())),
      );
      final content =
          tester.getSize(find.byKey(const ValueKey('home-content')));
      expect(content.width, lessThanOrEqualTo(1200));
      expect(find.byType(AdaptivePageLayout), findsOneWidget);
      // Desktop composition: the deliberate two-column layout is present.
      expect(find.byKey(const ValueKey('home-desktop-columns')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10b. 1024px viewport uses desktop two-column composition',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(goals: _goals(), focus: AsyncData<dynamic>(_focus())),
      );
      expect(find.byKey(const ValueKey('home-desktop-columns')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10c. 768px stays single column', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(goals: _goals(), focus: AsyncData<dynamic>(_focus())),
      );
      expect(find.byKey(const ValueKey('home-desktop-columns')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10d. Dark theme renders the full Home hierarchy',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            records: [
              _record(calories: 580, protein: 78, carbs: 180, fat: 42),
            ],
            goals: _goals(),
            focus: AsyncData<dynamic>(_focus()),
            today: _todayRecord(),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text("Today's Nutrition"), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      expect(find.text('Stay on top of hydration'), findsOneWidget);
      expect(find.text('1.4 / 2.5 L'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. Text scaling 1.4 works', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        const DashboardScreen(),
        scale: 1.4,
        overrides: _overrides(
          records: [_record(calories: 580, protein: 78, carbs: 180, fat: 42)],
          goals: _goals(),
          focus: AsyncData<dynamic>(_focus()),
          today: _todayRecord(),
        ),
      );
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12a. Food image failure uses the branded fallback',
        (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: FoodImageCard(
              food: null,
              imageSource: '',
              width: 160,
              aspectRatio: 1.5,
              semanticDescription: 'Dish photo',
            ),
          ),
        ),
      );
      expect(find.text('FitFuel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12b. Next meal renders photography from the existing plan',
        (tester) async {
      final authController = StreamController<User?>();
      addTearDown(authController.close);
      await _pump(
        tester,
        const DashboardScreen(),
        overrides: _overrides(
          goals: _goals(),
          authOverride: authStateStreamProvider
              .overrideWith((ref) => authController.stream),
          plannerOverride: mealPlannerControllerProvider
              .overrideWith((ref) => _StubMealPlanner(ref, _planWithLunch())),
        ),
      );
      expect(find.byType(FoodImageCard), findsOneWidget);
      expect(find.text('Lunch'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. Existing navigation remains functional', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = navigation.fixtureRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(canonicalLocation('/dashboard'), '/home');
      expect(tester.takeException(), isNull);
    });
  });
}
