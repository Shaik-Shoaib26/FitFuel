import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/analytics/domain/entities/health_analytics_entity.dart';
import 'package:fitfuel/features/analytics/domain/repositories/i_analytics_repository.dart';
import 'package:fitfuel/features/analytics/domain/utils/health_analytics_calculator.dart';
import 'package:fitfuel/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:fitfuel/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/health_insights/presentation/screens/health_insights_screen.dart';
import 'package:fitfuel/features/insights/domain/entities/daily_focus_entity.dart';
import 'package:fitfuel/features/insights/domain/entities/health_insight_entity.dart';
import 'package:fitfuel/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:fitfuel/features/insights/presentation/providers/insights_providers.dart';
import 'package:fitfuel/features/insights/presentation/screens/insights_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/screens/history_screen.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/progress/domain/entities/weight_record_entity.dart';
import 'package:fitfuel/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitfuel/features/progress/presentation/screens/progress_screen.dart';
import 'package:fitfuel/features/weekly_report/presentation/screens/weekly_report_screen.dart';

class _FakeAuthUser extends Fake implements User {
  @override
  String get uid => 'test_user_35_3g';
}

class _MockAnalyticsRepository extends Fake implements IAnalyticsRepository {
  @override
  Future<HealthAnalyticsEntity> getAnalytics({
    required String uid,
    required String range,
    required DateTime today,
  }) async {
    return HealthAnalyticsCalculator.calculate(
      range: range,
      today: today,
      nutritionRecords: [],
      healthRecords: [],
      weightHistory: [],
      profile: null,
      goals: null,
    );
  }
}

class _MockInsightsRepository extends Fake implements IInsightsRepository {
  @override
  Future<List<HealthInsightEntity>> getInsights({
    required String uid,
    required DateTime today,
  }) async => [];

  @override
  Future<DailyFocusEntity> getDailyFocus({
    required String uid,
    required DateTime today,
  }) async {
    return const DailyFocusEntity(
      title: 'Hydration Target',
      description: 'Drink 500ml water before afternoon workout.',
      category: InsightCategory.hydration,
      priority: InsightPriority.high,
      recommendedActions: [],
    );
  }
}

class _MockProgressRepository extends Fake implements IProgressRepository {
  @override
  Future<void> addWeight(String uid, double weight, DateTime recordedAt) async {}

  @override
  Future<List<WeightRecordEntity>> getWeightHistory(String uid) async => [];

  @override
  Stream<List<WeightRecordEntity>> streamWeightHistory(String uid) =>
      Stream.value([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeUser = _FakeAuthUser();

  final now = DateTime.now();
  final lastWeekDate = now.subtract(const Duration(days: 7));

  final testRecords = [
    NutritionRecordEntity(
      id: 'n1',
      foodName: 'Oatmeal with Almonds',
      mealType: 'Breakfast',
      calories: 350,
      protein: 12,
      carbohydrates: 45,
      fats: 8,
      sugar: 4,
      servingSize: 100,
      consumedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    NutritionRecordEntity(
      id: 'n2',
      foodName: 'Chicken Salad',
      mealType: 'Lunch',
      calories: 500,
      protein: 40,
      carbohydrates: 20,
      fats: 15,
      sugar: 2,
      servingSize: 200,
      consumedAt: lastWeekDate,
      createdAt: lastWeekDate,
      updatedAt: lastWeekDate,
    ),
  ];

  final testWeight = WeightRecordEntity(
    id: 'w1',
    weight: 75.5,
    recordedAt: DateTime.now(),
  );

  final testGoals = NutritionGoalsEntity(
    userId: 'test_user_35_3g',
    dailyCalorieTarget: 2200,
    proteinTargetGrams: 140,
    carbsTargetGrams: 220,
    fatTargetGrams: 65,
    updatedAt: DateTime.now(),
  );

  const testFocus = DailyFocusEntity(
    title: 'Hydration Target',
    description: 'Drink 500ml water before afternoon workout.',
    category: InsightCategory.hydration,
    priority: InsightPriority.high,
    recommendedActions: [],
  );

  Widget createTestWidget({
    required Widget child,
    required double width,
    required double textScale,
    required bool isDark,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        authStateStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
        nutritionStreamProvider.overrideWith((ref) => Stream.value(testRecords)),
        nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(testGoals)),
        weightHistoryStreamProvider.overrideWith((ref) => Stream.value([testWeight])),
        healthStreamProvider.overrideWith((ref) => Stream.value([])),
        currentProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
        progressRepositoryProvider.overrideWithValue(_MockProgressRepository()),
        analyticsRepositoryProvider.overrideWithValue(_MockAnalyticsRepository()),
        insightsRepositoryProvider.overrideWithValue(_MockInsightsRepository()),
        dailyFocusProvider.overrideWithValue(const AsyncValue.data(testFocus)),
        priorityInsightsProvider.overrideWithValue(const AsyncValue.data([])),
        recommendedActionsProvider.overrideWithValue(const AsyncValue.data([])),
        ...overrides,
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 900,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Phase 35.3G Progress Overview Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 1.4]) {
        testWidgets('Progress screen renders at $width px scale $scale without overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(createTestWidget(
            child: const ProgressScreen(),
            width: width,
            textScale: scale,
            isDark: false,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Progress'), findsOneWidget);
          expect(find.text('Nutrition Streak'), findsOneWidget);
          expect(find.text('Health Analytics'), findsOneWidget);
          expect(find.text('Weekly Health Report'), findsOneWidget);
          expect(find.text('Smart Health Insights'), findsOneWidget);
        });
      }
    }
  });

  group('Phase 35.3G Analytics Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('Analytics screen renders at $width px without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(
          child: const AnalyticsScreen(),
          width: width,
          textScale: 1.0,
          isDark: false,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Health Analytics'), findsOneWidget);
      });
    }
  });

  group('Phase 35.3G Nutrition Analytics Tests', () {
    testWidgets('Nutrition Analytics renders history and goal comparison',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        child: const HistoryScreen(),
        width: 390,
        textScale: 1.0,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nutrition Analytics'), findsOneWidget);
      expect(find.text('Calories History'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
    });
  });

  group('Phase 35.3G Weekly Report Tests', () {
    testWidgets('Weekly Report screen renders score header and WoW panel',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        child: const WeeklyReportScreen(),
        width: 390,
        textScale: 1.0,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly Health Report'), findsOneWidget);
      expect(find.text('Health Score'), findsNWidgets(2));
      expect(find.text('Week-over-Week Comparison'), findsOneWidget);
    });
  });

  group('Phase 35.3G Insights & Health Insights Tests', () {
    testWidgets('Insights screen renders Today Focus and filters', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        child: const InsightsScreen(),
        width: 390,
        textScale: 1.0,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smart Health Insights'), findsOneWidget);
      expect(find.text("TODAY'S FOCUS"), findsOneWidget);
    });

    testWidgets('Health Insights screen renders wellness index and telemetry',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        child: const HealthInsightsScreen(),
        width: 390,
        textScale: 1.0,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Personalized Health Insights'), findsOneWidget);
      expect(find.text("Today's Wellness Index"), findsOneWidget);
      expect(find.text("Today's Telemetry"), findsOneWidget);
    });
  });
}
