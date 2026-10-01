import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_progress_ring.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/presentation/widgets/meal_macro_summary.dart';
import 'package:fitfuel/features/nutrition/domain/utils/nutrition_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPlan = MealPlanEntity(
    id: 'test_plan',
    date: DateTime.now(),
    targetCalories: 2282,
    plannedCalories: 2299,
    targetProtein: 112,
    plannedProtein: 280,
    targetCarbs: 316,
    plannedCarbs: 94,
    targetFat: 63,
    plannedFat: 88,
    meals: const [],
  );

  const testProgress = NutritionProgressData(
    totalCalories: 500,
    totalProtein: 45,
    totalCarbs: 60,
    totalFats: 15,
    calorieProgress: 500 / 2282,
    proteinProgress: 45 / 112,
    carbsProgress: 60 / 316,
    fatProgress: 15 / 63,
  );

  const testFood = FoodEntity(
    id: 'predefined_masala_dosa',
    name: 'Masala Dosa',
    category: 'Breakfast',
    servingSize: 150,
    servingUnit: 'g',
    calories: 320,
    protein: 8,
    carbohydrates: 48,
    fats: 12,
    fiber: 3,
    sugar: 2,
    sodium: 400,
    isVegetarian: true,
    isVegan: false,
    dietaryTags: ['Indian', 'Vegetarian'],
  );

  Widget createSummaryWidget({
    required double width,
    required double textScale,
    required bool isDark,
  }) {
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: MealMacroSummary(
                plan: testPlan,
                progress: testProgress,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget createFoodCardGridWidget({
    required double width,
    required double textScale,
    required bool isDark,
  }) {
    final double cardExtent = textScale > 1.2 ? 305 : 260;
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: 1000,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardExtent,
              ),
              itemCount: 8,
              itemBuilder: (context, index) => FitFuelFoodCard(
                food: testFood,
                onTap: () {},
                onAddTap: () {},
                onFavoriteTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Phase 35.3E.1 Visual Correction Tests — Meal Macro Summary', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 1.2, 1.4]) {
        testWidgets('Summary renders at $width px scale $scale without overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(createSummaryWidget(
            width: width,
            textScale: scale,
            isDark: false,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(FitFuelProgressRing), findsOneWidget);
          expect(find.text('Plan Calorie Balance'), findsOneWidget);
          expect(find.text('Daily Target'), findsOneWidget);
          expect(find.text('Consumed'), findsOneWidget);
        });
      }
    }

    testWidgets('Calorie ring displays clean center hierarchy and no overlap',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSummaryWidget(
        width: 1024,
        textScale: 1.0,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Ring center hierarchy: 1782 kcal left (2282 - 500 = 1782)
      expect(find.text('1782'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);

      // Status chip outside ring shows buffer or over target
      expect(find.textContaining('over target'), findsOneWidget);
    });
  });

  group('Phase 35.3E.1 Visual Correction Tests — Recipe & Food Card Grid', () {
    for (final width in [600.0, 768.0, 1024.0, 1280.0, 1440.0]) {
      testWidgets('Food grid at $width px has compact non-stretching card heights',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createFoodCardGridWidget(
          width: width,
          textScale: 1.0,
          isDark: false,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final foodCards = find.byType(FitFuelFoodCard);
        expect(foodCards, findsWidgets);

        // Verify each card height is bounded to compact extent (approx 260px, not 500-700px!)
        final firstCardSize = tester.getSize(foodCards.first);
        expect(firstCardSize.height, equals(260.0));
      });
    }

    testWidgets('Food card handles 1.4 text scaling without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createFoodCardGridWidget(
        width: 1024,
        textScale: 1.4,
        isDark: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final foodCards = find.byType(FitFuelFoodCard);
      expect(foodCards, findsWidgets);

      final firstCardSize = tester.getSize(foodCards.first);
      expect(firstCardSize.height, equals(305.0));
    });
  });
}
