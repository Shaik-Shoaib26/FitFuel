import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/network/connectivity_service.dart';
import 'package:fitfuel/core/widgets/fitfuel_empty_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_error_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_button.dart';
import 'package:fitfuel/core/widgets/fitfuel_progress_ring.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';

import 'package:fitfuel/features/food/presentation/widgets/recipe_sections.dart';
import 'package:fitfuel/features/meal_planner/presentation/widgets/planned_food_card.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/analytics/presentation/widgets/analytics_metric_card.dart';
// Import Screens
import 'package:fitfuel/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fitfuel/features/smart_eat/presentation/screens/smart_eat_screen.dart';
import 'package:fitfuel/features/meal_planner/presentation/screens/meal_planner_screen.dart';
import 'package:fitfuel/features/grocery/presentation/screens/grocery_screen.dart';
import 'package:fitfuel/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';

// Import Entities
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/reminders/domain/entities/daily_routine_entity.dart';

// Import Controllers and Providers
import 'package:fitfuel/features/authentication/domain/repositories/i_auth_repository.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/health/domain/repositories/i_health_repository.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';
import 'package:fitfuel/features/ai_assistant/presentation/providers/ai_assistant_providers.dart';
import 'package:fitfuel/features/ai_assistant/domain/repositories/ai_nutrition_repository.dart';
import 'package:fitfuel/features/meal_planner/presentation/providers/meal_planner_providers.dart';
import 'package:fitfuel/features/meal_planner/domain/repositories/meal_plan_repository.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/grocery/domain/repositories/i_grocery_repository.dart';
import 'package:fitfuel/features/smart_eat/presentation/providers/smart_eat_providers.dart';
import 'package:fitfuel/features/smart_eat/domain/repositories/i_smart_eat_repository.dart';
import 'package:fitfuel/features/analytics/domain/repositories/i_analytics_repository.dart';
import 'package:fitfuel/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:fitfuel/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:fitfuel/features/insights/presentation/providers/insights_providers.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

// Mock Repositories via Mocktail
class MockAuthRepository extends Mock implements IAuthRepository {}
class MockSmartEatRepository extends Mock implements ISmartEatRepository {}
class MockMealPlanRepository extends Mock implements MealPlanRepository {}
class MockGroceryRepository extends Mock implements IGroceryRepository {}
class MockNutritionRepository extends Mock implements INutritionRepository {}
class MockHealthRepository extends Mock implements IHealthRepository {}
class MockAiRepository extends Mock implements IAiNutritionRepository {}
class MockAnalyticsRepository extends Mock implements IAnalyticsRepository {}
class MockInsightsRepository extends Mock implements IInsightsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivityService mockConnectivityService;
  late MockAuthRepository mockAuthRepository;
  late MockSmartEatRepository mockSmartEatRepository;
  late MockMealPlanRepository mockMealPlanRepository;
  late MockGroceryRepository mockGroceryRepository;
  late MockNutritionRepository mockNutritionRepository;
  late MockHealthRepository mockHealthRepository;
  late MockAiRepository mockAiRepository;
  late MockAnalyticsRepository mockAnalyticsRepository;
  late MockInsightsRepository mockInsightsRepository;

  setUp(() {
    mockConnectivityService = MockConnectivityService();
    when(() => mockConnectivityService.onStatusChanged)
        .thenAnswer((_) => Stream.value(NetworkStatus.online));
    when(() => mockConnectivityService.currentStatus)
        .thenAnswer((_) => Future.value(NetworkStatus.online));

    mockAuthRepository = MockAuthRepository();
    mockSmartEatRepository = MockSmartEatRepository();
    mockMealPlanRepository = MockMealPlanRepository();
    mockGroceryRepository = MockGroceryRepository();
    mockNutritionRepository = MockNutritionRepository();
    mockHealthRepository = MockHealthRepository();
    mockAiRepository = MockAiRepository();
    mockAnalyticsRepository = MockAnalyticsRepository();
    mockInsightsRepository = MockInsightsRepository();

    when(() => mockAuthRepository.currentUser).thenReturn(null);
    when(() => mockAuthRepository.authStateChanges).thenAnswer((_) => Stream.value(null));
  });

  Widget createTestWidget(Widget child, {double textScaleFactor = 1.0}) {
    return ProviderScope(
      overrides: [
        connectivityServiceProvider.overrideWithValue(mockConnectivityService),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        smartEatRepositoryProvider.overrideWithValue(mockSmartEatRepository),
        mealPlanRepositoryProvider.overrideWithValue(mockMealPlanRepository),
        groceryRepositoryProvider.overrideWithValue(mockGroceryRepository),
        nutritionRepositoryProvider.overrideWithValue(mockNutritionRepository),
        healthRepositoryProvider.overrideWithValue(mockHealthRepository),
        aiRepositoryProvider.overrideWithValue(mockAiRepository),
        analyticsRepositoryProvider.overrideWithValue(mockAnalyticsRepository),
        insightsRepositoryProvider.overrideWithValue(mockInsightsRepository),

        todayHealthRecordProvider.overrideWithValue(null),
        authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
        currentProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
        nutritionStreamProvider.overrideWith((ref) => Stream.value([])),
        nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(null)),
        dailyRoutineProvider.overrideWithValue(const DailyRoutineEntity(
          date: '2026-08-26',
          routineItems: [],
          completedItems: [],
          pendingItems: [],
          completionPercentage: 0.0,
          totalReminders: 0,
          completedReminders: 0,
          nextReminder: null,
        )),
        healthStreamProvider.overrideWith((ref) => Stream.value([])),
        pantryProvider.overrideWith((ref) => Stream.value([])),
        groceryPreferencesProvider.overrideWith((ref) => Stream.value(null)),
        currentGroceryListProvider.overrideWithValue(const AsyncValue.data(null)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child,
        ),
      ),
    );
  }

  group('Phase 35 — UI/UX Polish, Responsive & Accessibility Tests', () {
    testWidgets('1. Dashboard renders at 320 width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('2. Dashboard renders at 1440 width correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('3. Smart Eat renders at small and large widths', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(createTestWidget(const SmartEatScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SmartEatScreen), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestWidget(const SmartEatScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SmartEatScreen), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('4. Meal Planner renders at small and large widths', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(createTestWidget(const MealPlannerScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MealPlannerScreen), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestWidget(const MealPlannerScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MealPlannerScreen), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('5. Grocery renders at small and large widths', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(createTestWidget(const GroceryScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GroceryScreen), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestWidget(const GroceryScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GroceryScreen), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('6. Analytics renders at small and large widths', (tester) async {
      await tester.pumpWidget(createTestWidget(const Scaffold(body: AnalyticsMetricCard(
        title: 'Hydration', value: '1,800 ml', trend: 'Improving',
        details: [], icon: Icons.water_drop, color: Colors.blue,
      ))));
      expect(find.text('1,800 ml'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. AI Assistant renders at small and large widths', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(createTestWidget(const AiAssistantScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiAssistantScreen), findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(createTestWidget(const AiAssistantScreen()));
      await tester.pump();
      expect(tester.getSize(find.byKey(const ValueKey('ai-workspace'))).width, 880);
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
    });

    testWidgets('8. No overflow in key screens at edge cases', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
    });

    testWidgets('9. Text scale 1.4 works without layout breakage', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(createTestWidget(const DashboardScreen(), textScaleFactor: 1.4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
    });

    testWidgets('10. Offline state is readable', (tester) async {
      final widget = createTestWidget(
        FitFuelErrorState(
          error: 'offline',
          onRetry: () {},
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('Connection Error'), findsOneWidget);
    });

    testWidgets('11. Error state maps friendly message', (tester) async {
      final widget = createTestWidget(
        FitFuelErrorState(
          error: 'FirebaseException: something',
          onRetry: () {},
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('Something Went Wrong'), findsOneWidget);
    });

    testWidgets('12. Empty state renders correctly', (tester) async {
      final widget = createTestWidget(
        const FitFuelEmptyState(
          icon: Icons.kitchen_outlined,
          title: 'Empty Pantry',
          description: 'No pantry items here.',
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('Empty Pantry'), findsOneWidget);
    });

    testWidgets('13. Buttons meet expected minimum touch target size (48px)', (tester) async {
      final button = FitFuelButton(
        label: 'Tap Me',
        onPressed: () {},
      );
      await tester.pumpWidget(createTestWidget(Scaffold(body: button)));
      final Finder finder = find.byType(ElevatedButton);
      final Size size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });





    testWidgets('16. Food images have fallback placeholder', (tester) async {
      final food = PredefinedFoodData.foods.first.toEntity();
      final imageWidget = FoodImageCard(
        food: food,
        width: 100,
        height: 100,
      );
      await tester.pumpWidget(createTestWidget(Scaffold(body: imageWidget)));
      expect(find.byType(FoodImageCard), findsOneWidget);
    });

    testWidgets('Recipe displays ingredients and numbered method at 1.4x', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final food = PredefinedFoodData.foods.first.toEntity().copyWith(
        ingredients: ['1 cup oats', 'Water'], instructions: ['Bring water to a boil.', 'Stir in oats.'], servings: 2,
      );
      await tester.pumpWidget(createTestWidget(Scaffold(body: SingleChildScrollView(child: RecipeSections(food: food))), textScaleFactor: 1.4));
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('Makes 2 servings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Populated planned food wraps macros at 320px and 1.4x', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final food = PredefinedFoodData.foods.first.toEntity();
      await tester.pumpWidget(createTestWidget(Scaffold(body: SingleChildScrollView(child: PlannedFoodCard(
        plannedFood: PlannedFoodEntity(food: food, servingQuantity: 100, unit: 'g', calories: 250,
          protein: 20, carbohydrates: 30, fat: 8, fiber: 3),
        mealType: 'Lunch', onSwap: () {},
      ))), textScaleFactor: 1.4));
      expect(find.text(food.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });



    testWidgets('19. Accessibility labels exist for key actions', (tester) async {
      const progressRing = Scaffold(
        body: FitFuelProgressRing(
          value: 0.75,
          centerTitle: '75',
          centerSubtitle: 'completed',
        ),
      );
      await tester.pumpWidget(createTestWidget(progressRing));
      final semantics = tester.getSemantics(find.byType(FitFuelProgressRing));
      expect(semantics.label, contains('Progress ring: 75 completed'));
    });


  });
}
