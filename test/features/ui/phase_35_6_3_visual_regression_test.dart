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
import 'package:fitfuel/core/widgets/fitfuel_identity.dart';
import 'package:fitfuel/app/navigation/app_shell.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/health/presentation/screens/health_screen.dart';
import 'package:fitfuel/features/health/presentation/widgets/health_editorial_hero.dart';
import 'package:fitfuel/features/health/presentation/widgets/health_today_grid.dart';
import 'package:fitfuel/features/health/presentation/widgets/hydration_editorial_card.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';

class _MockConnectivityService extends Mock implements ConnectivityService {}
class _MockProgressRepository extends Mock implements IProgressRepository {}

String get _todayDate => DateTime.now().toString().split(' ').first;

HealthRecordEntity _sampleRecord({
  double water = 1250,
  double target = 2500,
  List<ExerciseEntity> exercises = const [
    ExerciseEntity(activity: 'Morning Run', duration: 30, caloriesBurned: 240),
  ],
  Map<String, bool>? habits,
}) =>
    HealthRecordEntity(
      id: _todayDate,
      date: _todayDate,
      waterIntakeMl: water,
      waterTargetMl: target,
      exercises: exercises,
      habits: habits ??
          const {
            'Sleep 7-8h': true,
            '10k Steps': false,
            'Stretching': true,
          },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

UserProfileEntity _sampleProfile() => UserProfileEntity(
      uid: 'qa-user-123',
      email: 'user@fitfuel.app',
      displayName: 'Shoaib',
      weight: 75.0,
      fitnessGoal: 'Stay Fit',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

List<Override> _createOverrides({
  HealthRecordEntity? record,
  _MockConnectivityService? mockConn,
}) {
  final conn = mockConn ?? _MockConnectivityService();
  when(() => conn.onStatusChanged).thenAnswer((_) => Stream.value(NetworkStatus.online));
  when(() => conn.currentStatus).thenAnswer((_) => Future.value(NetworkStatus.online));

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
    authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
    currentProfileStreamProvider.overrideWith((ref) => Stream.value(_sampleProfile())),
    nutritionStreamProvider.overrideWith((ref) => Stream.value(const <NutritionRecordEntity>[])),
    nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(NutritionGoalsEntity(
          userId: 'qa-user-123',
          dailyCalorieTarget: 2000,
          proteinTargetGrams: 150,
          carbsTargetGrams: 250,
          fatTargetGrams: 65,
          updatedAt: DateTime.now(),
        ))),
    healthStreamProvider.overrideWith((ref) => Stream.value([record ?? _sampleRecord()])),
    weightHistoryStreamProvider.overrideWith((ref) => Stream.value(const <WeightRecordEntity>[])),
    progressRepositoryProvider.overrideWithValue(_MockProgressRepository()),
  ];
}

Widget _buildTestApp({
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
      child: Scaffold(body: child),
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

  group('Phase 35.6.3 — Section 49 Visual & Functional Regression Tests', () {
    testWidgets('1 & 2. Health hero renders and contains "Your wellness"', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(HealthEditorialHero), findsOneWidget);
      expect(find.textContaining('Your wellness'), findsWidgets);
      expect(find.textContaining('Small habits. A healthier,'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3, 4, 5, 6, 7. Today\'s Health renders with asymmetric cards (Water, Exercise, Habits, Wellness)', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      // Section Header
      expect(find.text("Today's Health"), findsOneWidget);
      expect(find.textContaining('View details'), findsOneWidget);

      // Asymmetric Grid
      expect(find.byType(HealthTodayGrid), findsOneWidget);

      // 4. Large Water Card
      expect(find.text('Water'), findsWidgets);
      expect(find.textContaining('Stay hydrated'), findsOneWidget);
      expect(find.textContaining('1.3 / 2.5 L'), findsWidgets);

      // 5. Exercise Card
      expect(find.text('Exercise'), findsWidgets);
      expect(find.text('30 min'), findsWidgets);

      // 6. Habits Card
      expect(find.text('Habits'), findsWidgets);
      expect(find.text('2 / 3'), findsWidgets);

      // 7. Wellness Card
      expect(find.text('Wellness'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8, 9, 10. Hydration section renders with quick-add actions (+250 ml, +500 ml)', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      // 8. Hydration section & card
      expect(find.byType(HydrationEditorialCard), findsOneWidget);
      expect(find.text('Hydration'), findsWidgets);
      expect(find.textContaining('Daily target'), findsWidgets);

      // 9 & 10. Quick Actions
      expect(find.text('+250 ml'), findsOneWidget);
      expect(find.text('+500 ml'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Log custom water amount'), findsOneWidget);
      expect(find.textContaining('remaining'), findsWidgets);
      expect(find.textContaining("You've logged"), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('11. 320px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(320, 640));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(HealthEditorialHero), findsOneWidget);
      expect(find.byType(HealthTodayGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12. 390px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(HealthEditorialHero), findsOneWidget);
      expect(find.byType(HealthTodayGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. 430px screen has no overflow', (tester) async {
      _setViewport(tester, const Size(430, 932));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen()),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(HealthEditorialHero), findsOneWidget);
      expect(find.byType(HealthTodayGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('14. 1.4x text scale has no overflow', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _createOverrides(),
          child: _buildTestApp(child: const HealthScreen(), textScale: 1.4),
        ),
      );
      await _settlePump(tester);

      expect(find.byType(HealthEditorialHero), findsOneWidget);
      expect(find.byType(HealthTodayGrid), findsOneWidget);
      expect(find.text('+250 ml'), findsOneWidget);
      expect(find.text('+500 ml'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('15. Health bottom nav remains selected correctly', (tester) async {
      _setViewport(tester, const Size(390, 844));

      final router = GoRouter(
        initialLocation: '/health',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AppShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/health', builder: (_, __) => const HealthScreen()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/nutrition', builder: (_, __) => const Scaffold(body: Text('Nutrition Page'))),
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

      // Verify Health screen is showing
      expect(find.byType(HealthScreen), findsOneWidget);

      // Verify NavigationBar has destination index 1 selected
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);
      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.selectedIndex, equals(1));
    });
  });

  group('Phase 35.6.3 — Section 50 Icon Regression Tests', () {
    testWidgets('FitFuelBrandMark renders ONE broad white botanical leaf via FitFuelOrganicLeafPainter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FitFuelBrandMark(size: 64),
          ),
        ),
      );
      await _settlePump(tester);

      // Verify the painter is FitFuelOrganicLeafPainter
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is FitFuelOrganicLeafPainter,
        ),
        findsOneWidget,
      );
    });

    test('Old small/square leaf painter classes do not exist in the codebase', () {
      final identityFile = File('lib/core/widgets/fitfuel_identity.dart');
      expect(identityFile.existsSync(), isTrue);
      final content = identityFile.readAsStringSync();

      expect(content.contains('class FitFuelOrganicLeafPainter'), isTrue);
      expect(content.contains('class FitFuelLeafPainter'), isFalse);
    });

    test('Brand mark asset fitfuel_leaf_icon.png exists and is non-empty', () {
      final brandAsset = File('assets/branding/fitfuel_leaf_icon.png');
      expect(brandAsset.existsSync(), isTrue);
      expect(brandAsset.lengthSync(), greaterThan(1000));
    });

    test('All 5 Health decorative assets exist with valid size', () {
      final assets = [
        'assets/decorations/health_lemon_water.webp',
        'assets/decorations/health_hydration_branch.webp',
        'assets/decorations/health_zen_stones.webp',
        'assets/decorations/health_sneaker.webp',
        'assets/decorations/health_habits_leaf.webp',
      ];
      for (final assetPath in assets) {
        final f = File(assetPath);
        expect(f.existsSync(), isTrue, reason: 'Asset $assetPath must exist');
        expect(f.lengthSync(), greaterThan(1000), reason: 'Asset $assetPath must be valid file');
      }
    });
  });
}
