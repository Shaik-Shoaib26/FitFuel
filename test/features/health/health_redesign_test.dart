import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/network/connectivity_service.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/theme/app_theme.dart';
import 'package:fitfuel/core/widgets/adaptive_page_layout.dart';

import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/health/domain/entities/exercise_entity.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/presentation/controllers/health_controller.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/health/presentation/screens/health_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockProgressRepository extends Mock implements IProgressRepository {}

/// Records health mutations instead of persisting them, so tests can assert the
/// existing controller paths are still wired to the redesigned UI.
class _RecordingHealthController extends HealthController {
  // The base constructor parameter is private, so a super parameter cannot be
  // expressed here.
  // ignore: use_super_parameters
  _RecordingHealthController(Ref ref) : super(ref);
  double? waterAdded;
  String? habitToggled;
  ExerciseEntity? exerciseAdded;

  @override
  Future<void> incrementWater(double ml) async {
    waterAdded = ml;
  }

  @override
  Future<void> toggleHabit(String habitName, bool completed) async {
    habitToggled = '$habitName:$completed';
  }

  @override
  Future<void> addExercise(ExerciseEntity exercise) async {
    exerciseAdded = exercise;
  }
}

late MockConnectivityService mockConnectivity;

String get _today => DateTime.now().toString().split(' ').first;

HealthRecordEntity _record({
  double water = 0,
  double target = 2500,
  List<ExerciseEntity> exercises = const [],
  Map<String, bool>? habits,
}) =>
    HealthRecordEntity(
      id: _today,
      date: _today,
      waterIntakeMl: water,
      waterTargetMl: target,
      exercises: exercises,
      habits: habits ??
          const {
            'Sleep 7-8h': false,
            '10k Steps': false,
            'Stretching': false,
          },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

NutritionGoalsEntity _goals() => NutritionGoalsEntity(
      userId: 'u',
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 150,
      carbsTargetGrams: 250,
      fatTargetGrams: 65,
      updatedAt: DateTime.now(),
    );

UserProfileEntity _profile() => UserProfileEntity(
      uid: 'u',
      email: 'a@b.com',
      weight: 78.5,
      fitnessGoal: 'Lose Weight',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

NutritionRecordEntity _nutritionRecord() => NutritionRecordEntity(
      id: 'n1',
      foodName: 'Oats',
      mealType: 'Breakfast',
      calories: 400,
      protein: 20,
      carbohydrates: 50,
      fats: 10,
      sugar: 5,
      servingSize: 1,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

List<WeightRecordEntity> _weights() => [
      WeightRecordEntity(
          id: 'w1',
          weight: 80.0,
          recordedAt: DateTime.now().subtract(const Duration(days: 6))),
      WeightRecordEntity(id: 'w2', weight: 78.5, recordedAt: DateTime.now()),
    ];

List<Override> _overrides({
  List<HealthRecordEntity>? health,
  Stream<List<HealthRecordEntity>>? healthStream,
  List<NutritionRecordEntity> nutrition = const [],
  List<WeightRecordEntity> weights = const [],
  Stream<List<WeightRecordEntity>>? weightStream,
  Override? controllerOverride,
}) =>
    [
      connectivityServiceProvider.overrideWithValue(mockConnectivity),
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentProfileStreamProvider
          .overrideWith((ref) => Stream.value(_profile())),
      nutritionStreamProvider.overrideWith((ref) => Stream.value(nutrition)),
      nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(_goals())),
      healthStreamProvider.overrideWith(
          (ref) => healthStream ?? Stream.value(health ?? const [])),
      weightHistoryStreamProvider
          .overrideWith((ref) => weightStream ?? Stream.value(weights)),
      progressRepositoryProvider.overrideWithValue(MockProgressRepository()),
      if (controllerOverride != null) controllerOverride,
    ];

Widget _host(Widget child, {double scale = 1.0, bool dark = false}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
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
  bool dark = false,
}) async {
  await tester.pumpWidget(ProviderScope(
      overrides: overrides, child: _host(child, scale: scale, dark: dark)));
  await _settle(tester);
}

void _sizeTo(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapAfterScrolling(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

GoRouter _healthRouter() => GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
            path: '/health',
            builder: (_, __) => const HealthScreen(),
            routes: [
              GoRoute(
                  path: 'weight',
                  builder: (_, __) =>
                      const Scaffold(body: Text('page:/health/weight'))),
            ]),
      ],
    );

GoRouter _healthRouterWithAddAction() => GoRouter(
      initialLocation: '/health?section=exercise&action=add',
      routes: [
        GoRoute(
            path: '/health',
            builder: (_, state) => HealthScreen(
                section: state.uri.queryParameters['section'],
                action: state.uri.queryParameters['action'])),
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

  group('Phase 35.3C — Health redesign', () {
    testWidgets('1. renders the full Health hierarchy with normal data',
        (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(
          health: [
            _record(
              water: 1500,
              exercises: const [
                ExerciseEntity(
                    activity: 'Run', duration: 32, caloriesBurned: 300)
              ],
              habits: const {
                'Sleep 7-8h': true,
                '10k Steps': true,
                'Stretching': false
              },
            )
          ],
          nutrition: [_nutritionRecord()],
          weights: _weights(),
        ),
      );
      expect(find.text('Your wellness today'), findsOneWidget);
      expect(find.text('Your daily wellness at a glance.'), findsOneWidget);
      expect(find.text("Today's Health"), findsOneWidget);
      expect(find.text('Hydration'), findsWidgets);
      expect(find.text('Activity'), findsWidgets);
      expect(find.text('Habits'), findsWidgets);
      expect(find.text('Wellness'), findsWidgets);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('1.5 / 2.5 L'), findsWidgets);
      expect(find.text('32 min'), findsWidgets);
      expect(find.text('2 / 3'), findsWidgets);
      expect(find.text('1.0 L remaining'), findsOneWidget);
      expect(find.text('Completed today'), findsOneWidget);
      expect(find.text('Daily Wellness Score'), findsOneWidget);
      expect(find.text('Logged today'), findsOneWidget);
      expect(find.text('View weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. hydration zero state', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()]));
      expect(find.text('0.0 L'), findsOneWidget);
      expect(find.text('2.5 L remaining'), findsOneWidget);
      expect(find.text('0.0 / 2.5 L'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. hydration target reached', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record(water: 2500, target: 2500)]));
      expect(find.text('Goal met'), findsOneWidget);
      expect(find.text('0.0 L remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3b. hydration over target', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record(water: 3000, target: 2500)]));
      expect(find.text('Over target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. hydration without a target does not crash', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record(water: 500, target: 0)]));
      expect(find.text('No daily target set'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. no exercise shows the activity empty state', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()]));
      expect(find.text('No exercise logged today'), findsOneWidget);
      expect(find.text('Log activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. habits empty state', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record(habits: const {})]));
      expect(find.text('No habits configured yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6b. habits partial completion', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(health: [
          _record(habits: const {'Sleep 7-8h': true, '10k Steps': false})
        ]),
      );
      expect(find.text('1 / 2'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. wellness without logged food', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()]));
      expect(find.text('Not logged yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7b. wellness with logged food', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides:
              _overrides(health: [_record()], nutrition: [_nutritionRecord()]));
      expect(find.text('Logged today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. weight empty state', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()]));
      expect(find.text('No weight history yet'), findsOneWidget);
      expect(find.text('Add weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8b. weight available state', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()], weights: _weights()));
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('78.5 kg'), findsWidgets);
      expect(find.text('Fitness goal: Lose Weight'), findsOneWidget);
      expect(find.text('View weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8c. failed weight stream offers retry, not an empty state',
        (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(
          health: [_record()],
          weightStream: Stream<List<WeightRecordEntity>>.error(
              ServerException(message: 'boom')),
        ),
      );
      expect(find.text('No weight history yet'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. loading state is lightweight and labelled', (tester) async {
      _sizeTo(tester, const Size(390, 900));
      final completer = Completer<List<HealthRecordEntity>>();
      addTearDown(() => completer.complete(const []));
      await _pump(
        tester,
        const HealthScreen(),
        overrides:
            _overrides(healthStream: Stream.fromFuture(completer.future)),
      );
      expect(find.text('Loading your health data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. error state hides backend details and offers retry',
        (tester) async {
      _sizeTo(tester, const Size(390, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(
            healthStream: Stream<List<HealthRecordEntity>>.error(
                ServerException(message: 'boom'))),
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Instance of'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. section query with action=add opens the exercise dialog',
        (tester) async {
      _sizeTo(tester, const Size(900, 1000));
      final router = _healthRouterWithAddAction();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(health: [_record()]),
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await _settle(tester);
      expect(find.text('Log Workout Activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12. quick add and habit toggle keep using the controller',
        (tester) async {
      _sizeTo(tester, const Size(390, 1400));
      _RecordingHealthController? recorder;
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(
          health: [_record(water: 500)],
          controllerOverride: healthControllerProvider.overrideWith((ref) {
            recorder = _RecordingHealthController(ref);
            return recorder!;
          }),
        ),
      );
      // The controller is created lazily on first use, i.e. when the quick add
      // is tapped.
      await _tapAfterScrolling(tester, find.text('+250 ml'));
      expect(recorder, isNotNull);
      expect(recorder!.waterAdded, 250.0);

      await _tapAfterScrolling(tester, find.text('+500 ml'));
      expect(recorder!.waterAdded, 500.0);

      await _tapAfterScrolling(tester, find.byType(Checkbox).first);
      expect(recorder!.habitToggled, 'Sleep 7-8h:true');
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. weight entry point keeps its canonical route',
        (tester) async {
      _sizeTo(tester, const Size(390, 1400));
      final router = _healthRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(health: [_record()], weights: _weights()),
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await _settle(tester);

      await _tapAfterScrolling(tester, find.text('View weight'));
      expect(router.routeInformationProvider.value.uri.path, '/health/weight');
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      ['14. 320px', Size(320, 720)],
      ['14b. 390px', Size(390, 844)],
      ['14c. 412px', Size(412, 892)],
      ['14d. 768px', Size(768, 1024)],
    ]) {
      testWidgets('${size[0]} layout has no overflow', (tester) async {
        _sizeTo(tester, size[1] as Size);
        await _pump(
          tester,
          const HealthScreen(),
          overrides: _overrides(
            health: [
              _record(
                water: 1500,
                exercises: const [
                  ExerciseEntity(
                      activity: 'Run', duration: 32, caloriesBurned: 300)
                ],
                habits: const {'Sleep 7-8h': true},
              )
            ],
            nutrition: [_nutritionRecord()],
            weights: _weights(),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('15. 1024px uses the desktop composition', (tester) async {
      _sizeTo(tester, const Size(1024, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(health: [_record(water: 1500)], weights: _weights()),
      );
      expect(
          find.byKey(const ValueKey('health-desktop-columns')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('16. 768px stays single column', (tester) async {
      _sizeTo(tester, const Size(768, 1024));
      await _pump(tester, const HealthScreen(),
          overrides: _overrides(health: [_record()]));
      expect(
          find.byKey(const ValueKey('health-desktop-columns')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. 1440px keeps content constrained', (tester) async {
      _sizeTo(tester, const Size(1440, 900));
      await _pump(
        tester,
        const HealthScreen(),
        overrides: _overrides(health: [_record(water: 1500)], weights: _weights()),
      );
      expect(
          find.byKey(const ValueKey('health-desktop-columns')), findsOneWidget);
      expect(find.byType(AdaptivePageLayout), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('18. dark theme renders the full Health hierarchy',
        (tester) async {
      _sizeTo(tester, const Size(1024, 900));
      await _pump(
        tester,
        const HealthScreen(),
        dark: true,
        overrides: _overrides(
          health: [
            _record(
              water: 1500,
              exercises: const [
                ExerciseEntity(
                    activity: 'Run', duration: 32, caloriesBurned: 300)
              ],
            )
          ],
          nutrition: [_nutritionRecord()],
          weights: _weights(),
        ),
      );
      expect(find.text('Hydration'), findsWidgets);
      expect(find.text('1.0 L remaining'), findsOneWidget);
      expect(find.text('Daily Wellness Score'), findsOneWidget);
      expect(find.text('View weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('19. text scale 1.4 has no overflow', (tester) async {
      _sizeTo(tester, const Size(360, 1400));
      await _pump(
        tester,
        const HealthScreen(),
        scale: 1.4,
        overrides: _overrides(
          health: [
            _record(
              water: 1500,
              exercises: const [
                ExerciseEntity(
                    activity: 'Run', duration: 32, caloriesBurned: 300)
              ],
            )
          ],
          nutrition: [_nutritionRecord()],
          weights: _weights(),
        ),
      );
      expect(find.text('Hydration'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
