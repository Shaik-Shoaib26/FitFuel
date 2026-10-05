import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/widgets/fitfuel_identity.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fitfuel/features/dashboard/presentation/widgets/home_header.dart';
import 'package:fitfuel/features/health/domain/entities/health_record_entity.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/insights/domain/entities/daily_focus_entity.dart';
import 'package:fitfuel/features/insights/domain/entities/health_insight_entity.dart';
import 'package:fitfuel/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:fitfuel/features/insights/presentation/providers/insights_providers.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'qa-test-user';
  @override
  String get email => 'user@fitfuel.app';
  @override
  String get displayName => 'Shoaib';
}

class _FakeProgressRepository extends Fake implements IProgressRepository {
  @override
  Stream<List<WeightRecordEntity>> streamWeightHistory(String uid) =>
      Stream.value([]);
}

class _FakeInsightsRepository extends Fake implements IInsightsRepository {
  @override
  Future<List<HealthInsightEntity>> getInsights({
    required String uid,
    required DateTime today,
  }) async => [];

  @override
  Future<DailyFocusEntity> getDailyFocus({
    required String uid,
    required DateTime today,
  }) async => const DailyFocusEntity(
    title: 'Improve hydration',
    description: 'You\'re 1000 ml below today\'s target.',
    category: InsightCategory.hydration,
    priority: InsightPriority.medium,
    recommendedActions: [],
  );
}

class _FakeMealPlannerController extends StateNotifier<AsyncValue<MealPlanEntity?>>
    implements MealPlannerController {
  _FakeMealPlannerController() : super(const AsyncValue.data(null));

  @override
  Future<void> loadTodayPlan() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapHome({
  double width = 390,
  double textScale = 1.0,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final now = DateTime.now();
  final profile = UserProfileEntity(
    uid: 'qa-test-user',
    email: 'user@fitfuel.app',
    displayName: 'Shoaib',
    age: 26,
    gender: 'male',
    height: 175,
    weight: 70,
    activityLevel: 'moderate',
    fitnessGoal: 'maintain',
    dietaryPreference: 'none',
    createdAt: now,
    updatedAt: now,
  );

  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((_) => Stream.value(_FakeUser())),
      networkStatusProvider.overrideWith((_) => Stream.value(NetworkStatus.online)),
      currentProfileStreamProvider.overrideWith((_) => Stream.value(profile)),
      nutritionStreamProvider.overrideWith((_) => Stream.value([
        NutritionRecordEntity(
          id: 'rec-1',
          foodName: 'Grilled Chicken Bowl',
          mealType: 'Lunch',
          calories: 603,
          protein: 28,
          carbohydrates: 88,
          fats: 16,
          sugar: 4,
          servingSize: 350,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ])),
      nutritionGoalsStreamProvider.overrideWith((_) => Stream.value(null)),
      healthStreamProvider.overrideWith((_) => Stream.value([
        HealthRecordEntity(
          id: 'health-1',
          date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          waterIntakeMl: 1500,
          waterTargetMl: 2500,
          exercises: const [],
          habits: const {},
          createdAt: now,
          updatedAt: now,
        ),
      ])),
      weightHistoryStreamProvider.overrideWith((_) => Stream.value([])),
      insightsRepositoryProvider.overrideWithValue(_FakeInsightsRepository()),
      dailyFocusProvider.overrideWithValue(const AsyncValue.data(null)),
      priorityInsightsProvider.overrideWithValue(const AsyncValue.data([])),
      recommendedActionsProvider.overrideWithValue(const AsyncValue.data([])),
      mealPlannerControllerProvider.overrideWith((ref) => _FakeMealPlannerController()),
      groceryListsProvider.overrideWith((ref) => Stream.value([])),
      currentGroceryListProvider.overrideWithValue(const AsyncValue.data(null)),
      remindersSettingsStreamProvider.overrideWith((ref) => Stream.value(null)),
      progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 920),
          textScaler: TextScaler.linear(textScale),
          padding: padding,
        ),
        child: const DashboardScreen(),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 35.6.2 Visual Regression — Safe Area & Date Positioning', () {
    testWidgets('Date text is strictly below SafeArea top status-bar inset', (tester) async {
      const double statusBarHeight = 48.0;
      await tester.pumpWidget(_wrapHome(
        width: 390,
        padding: const EdgeInsets.only(top: statusBarHeight),
      ));
      await _settle(tester);

      // Find the date text widget
      final dateFinder = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data != null) {
          final text = widget.data!;
          return text.contains('Monday') ||
              text.contains('Tuesday') ||
              text.contains('Wednesday') ||
              text.contains('Thursday') ||
              text.contains('Friday') ||
              text.contains('Saturday') ||
              text.contains('Sunday');
        }
        return false;
      });

      expect(dateFinder, findsOneWidget, reason: 'Date text must be present on Home');

      final dateTopDy = tester.getTopLeft(dateFinder).dy;
      // Date must be strictly BELOW status bar inset (48.0)
      expect(
        dateTopDy,
        greaterThan(statusBarHeight + 10.0),
        reason: 'Date text (at y=$dateTopDy) must not overlap or touch the status bar (inset=$statusBarHeight)',
      );
    });
  });

  group('Phase 35.6.2 Visual Regression — Brand Mark & Splash', () {
    testWidgets('Brand mark renders organic single leaf with painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FitFuelBrandMark(size: 64)),
        ),
      );
      await _settle(tester);

      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FitFuelOrganicLeafPainter),
        findsOneWidget,
      );
    });

    testWidgets('Splash identity renders reference layout with clean leaf and wordmark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FitFuelSplashIdentity()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FitFuelBrandMark), findsOneWidget);
      expect(find.text('FitFuel'), findsOneWidget);
      expect(find.text('Better Food. Brighter You.'), findsOneWidget);
    });
  });

  group('Phase 35.6.2 Visual Regression — Responsive Home Viewports', () {
    final viewports = [
      {'name': 'small mobile', 'width': 320.0, 'scale': 1.0},
      {'name': 'normal mobile', 'width': 390.0, 'scale': 1.0},
      {'name': 'large mobile', 'width': 430.0, 'scale': 1.0},
      {'name': 'accessibility scale 1.4x', 'width': 390.0, 'scale': 1.4},
    ];

    for (final vp in viewports) {
      testWidgets('DashboardScreen renders cleanly at ${vp['name']} without overflow', (tester) async {
        await tester.pumpWidget(_wrapHome(
          width: vp['width'] as double,
          textScale: vp['scale'] as double,
          padding: const EdgeInsets.only(top: 24),
        ));
        await _settle(tester);

        // 1. Brand Header
        expect(find.byType(HomeHeader), findsOneWidget);
        expect(find.text('FitFuel'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

        // 2. Section Headers
        expect(find.text("Today's Nutrition"), findsOneWidget);
        expect(find.text("Today's Focus"), findsOneWidget);
        expect(find.text('Up Next'), findsOneWidget);

        // 3. Nutrition Metrics
        expect(find.text('Consumed'), findsOneWidget);
        expect(find.text('Target'), findsOneWidget);
        expect(find.text('Protein'), findsOneWidget);
        expect(find.text('Carbs'), findsOneWidget);
        expect(find.text('Fat'), findsOneWidget);

        // 4. Focus Card & Up Next Card
        expect(find.text('Log Water'), findsOneWidget);
        expect(find.text('Create Meal Plan'), findsOneWidget);

        // No overflow errors
        expect(tester.takeException(), isNull);
      });
    }
  });
}
