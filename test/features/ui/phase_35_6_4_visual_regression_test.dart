import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitfuel/core/network/connectivity_service.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/theme/app_theme.dart';
import 'package:fitfuel/app/navigation/app_shell.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/nutrition_editorial_hero.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/nutrition_segmented_tabs.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/nutrition_date_selector.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/nutrition_summary_card.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/nutrition_quick_actions.dart';
import 'package:fitfuel/features/nutrition/presentation/widgets/food_diary_section.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';

class _MockConnectivityService extends Mock implements ConnectivityService {}
class _MockProgressRepository extends Mock implements IProgressRepository {}

UserProfileEntity _mockProfile() => UserProfileEntity(
      uid: 'qa-user-456',
      email: 'qa@fitfuel.app',
      displayName: 'Shoaib',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

NutritionGoalsEntity _mockGoals() => NutritionGoalsEntity(
      userId: 'qa-user-456',
      dailyCalorieTarget: 2282,
      proteinTargetGrams: 112,
      carbsTargetGrams: 316,
      fatTargetGrams: 63,
      updatedAt: DateTime.now(),
    );

NutritionRecordEntity _sampleFoodRecord() => NutritionRecordEntity(
      id: 'food_1',
      foodName: 'Grilled Chicken Salad',
      mealType: 'Lunch',
      calories: 420,
      protein: 38,
      carbohydrates: 18,
      fats: 12,
      sugar: 4,
      servingSize: 250,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

List<Override> _createOverrides({
  List<NutritionRecordEntity> nutritionRecords = const [],
  NutritionGoalsEntity? goals,
  _MockConnectivityService? mockConn,
}) {
  final conn = mockConn ?? _MockConnectivityService();
  when(() => conn.onStatusChanged).thenAnswer((_) => Stream.value(NetworkStatus.online));
  when(() => conn.currentStatus).thenAnswer((_) => Future.value(NetworkStatus.online));

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
    authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
    currentProfileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile())),
    nutritionStreamProvider.overrideWith((ref) => Stream.value(nutritionRecords)),
    nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(goals ?? _mockGoals())),
    healthStreamProvider.overrideWith((ref) => Stream.value(const <HealthRecordEntity>[])),
    weightHistoryStreamProvider.overrideWith((ref) => Stream.value(const <WeightRecordEntity>[])),
    progressRepositoryProvider.overrideWithValue(_MockProgressRepository()),
  ];
}

Widget _wrapNutritionApp({
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
        loader.addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
        await loader.load();
      }
    }
  });

  group('Phase 35.6.4 — Section 46 Nutrition Visual Regression Tests', () {
    testWidgets('1. Nutrition title and app bar actions render', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Food Diary / Macros / Insights tabs render', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionSegmentedTabs), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NutritionSegmentedTabs),
          matching: find.text('Food Diary'),
        ),
        findsOneWidget,
      );
      expect(find.text('Macros'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3 & 4. Editorial hero renders and contains "Fuel a healthier you"', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionEditorialHero), findsOneWidget);
      expect(find.textContaining('Fuel a'), findsWidgets);
      expect(find.textContaining('healthier you'), findsWidgets);
      expect(find.textContaining('Nutritious choices.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Date selector renders with navigation controls', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionDateSelector), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsWidgets);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.textContaining('Today,'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6, 7, 8, 9, 10. Today\'s Nutrition card, Calorie ring, Protein, Carbs, Fat render', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      // Card & Header
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(find.text("Today's Nutrition"), findsOneWidget);
      expect(find.textContaining('View details'), findsOneWidget);
      expect(find.textContaining('0 of 2282 kcal'), findsOneWidget);

      // 7. Calorie Ring
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('2282'), findsOneWidget);
      expect(find.text('kcal remaining'), findsOneWidget);

      // 8, 9, 10. Macro Metrics
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('0 / 112 g'), findsOneWidget);

      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('0 / 316 g'), findsOneWidget);

      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('0 / 63 g'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('11, 12, 13, 14. Quick actions render (Log Food, Scan Meal, Recipes, Goals)', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionQuickActions), findsOneWidget);
      expect(find.text('Log Food'), findsWidgets);
      expect(find.text('Scan Meal'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);

      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
      expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.track_changes_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('15 & 16. Food Diary empty-state renders with "Nothing logged yet" and "Add Food" CTA', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(nutritionRecords: const []),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(FoodDiarySection), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FoodDiarySection),
          matching: find.text('Food Diary'),
        ),
        findsOneWidget,
      );
      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(find.textContaining('Start with your first meal to see your nutrition progress.'), findsOneWidget);
      expect(find.text('Add Food'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. Populated Food Diary renders meal groups when records exist', (tester) async {
      _setViewport(tester, const Size(390, 844));
      final record = _sampleFoodRecord();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(nutritionRecords: [record]),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(FoodDiarySection), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Grilled Chicken Salad'), findsOneWidget);
      expect(find.textContaining('420 kcal'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('18. 320 px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(320, 640));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionEditorialHero), findsOneWidget);
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(find.byType(NutritionQuickActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('19. 390 px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionEditorialHero), findsOneWidget);
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(find.byType(NutritionQuickActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('20. 430 px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(430, 932));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _wrapNutritionApp(child: const NutritionScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionEditorialHero), findsOneWidget);
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(find.byType(NutritionQuickActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('21. 320 px screen with 1.4x text scale and populated records has no overflow', (tester) async {
      _setViewport(tester, const Size(320, 640));
      final record = _sampleFoodRecord();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(nutritionRecords: [record]),
          child: _wrapNutritionApp(child: const NutritionScreen(), textScale: 1.4),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(NutritionEditorialHero), findsOneWidget);
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(find.byType(NutritionQuickActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('22. Nutrition bottom nav remains selected correctly', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final router = GoRouter(
        initialLocation: '/nutrition',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AppShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/health', builder: (_, __) => const Scaffold(body: Text('Health Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/nutrition', builder: (_, __) => const NutritionScreen()),
              ]),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await _settlePump(tester);

      // Verify Nutrition screen is showing
      expect(find.byType(NutritionScreen), findsOneWidget);

      // Verify NavigationBar has destination index 2 selected
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);
      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.selectedIndex, equals(2));
    });
  });
}
