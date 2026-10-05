import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/health/presentation/screens/health_screen.dart';
import 'package:fitfuel/features/insights/domain/entities/daily_focus_entity.dart';
import 'package:fitfuel/features/insights/domain/entities/health_insight_entity.dart';
import 'package:fitfuel/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:fitfuel/features/insights/presentation/providers/insights_providers.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/controllers/meal_planner_controller.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:fitfuel/features/plan/presentation/screens/plan_screen.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitfuel/features/progress/presentation/screens/progress_screen.dart';
import 'package:fitfuel/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'qa-fixture-user';
  @override
  String get email => 'qa.user@fitfuel.app';
  @override
  String get displayName => 'FitFuel QA User';
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
    title: 'Daily Wellness Focus',
    description: 'Stay hydrated and hit your protein target today.',
    category: InsightCategory.wellness,
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

Widget _wrapScreen(Widget screen, {double width = 390, double textScale = 1.0, bool isDark = false}) {
  final now = DateTime.now();
  final profile = UserProfileEntity(
    uid: 'qa-fixture-user',
    email: 'qa.user@fitfuel.app',
    displayName: 'FitFuel QA User',
    age: 30,
    gender: 'female',
    height: 168,
    weight: 62,
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
          foodName: 'Oatmeal with Blueberries and Almond Butter',
          mealType: 'Breakfast',
          calories: 380,
          protein: 14,
          carbohydrates: 54,
          fats: 12,
          sugar: 4,
          servingSize: 200,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ])),
      nutritionGoalsStreamProvider.overrideWith((_) => Stream.value(null)),
      healthStreamProvider.overrideWith((_) => Stream.value([])),
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
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: screen,
      ),
    ),
  );
}

void main() {
  group('Phase 35.3J — Full Application Visual Consistency & Release QA', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('DashboardScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const DashboardScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('HealthScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const HealthScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(HealthScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('NutritionScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const NutritionScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(NutritionScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlanScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const PlanScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(PlanScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProgressScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const ProgressScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(ProgressScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProfileScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const ProfileScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SettingsScreen renders cleanly at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScreen(const SettingsScreen(), width: width));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Major screens handle 1.4x text scaling without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScreen(const DashboardScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const HealthScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const NutritionScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const PlanScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const ProgressScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const ProfileScreen(), width: 390, textScale: 1.4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Major screens render cleanly in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScreen(const DashboardScreen(), width: 1024, isDark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const HealthScreen(), width: 1024, isDark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const NutritionScreen(), width: 1024, isDark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const PlanScreen(), width: 1024, isDark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrapScreen(const ProgressScreen(), width: 1024, isDark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
