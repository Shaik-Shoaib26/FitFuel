import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/fitfuel_empty_state.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_item_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_list_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_preferences_entity.dart';
import 'package:fitfuel/features/grocery/domain/entities/pantry_item_entity.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/grocery/presentation/screens/grocery_screen.dart';
import 'package:fitfuel/features/reminders/domain/entities/daily_routine_entity.dart';
import 'package:fitfuel/features/reminders/domain/entities/reminder_entity.dart';
import 'package:fitfuel/features/reminders/presentation/providers/reminders_providers.dart';
import 'package:fitfuel/features/reminders/presentation/screens/daily_routine_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testGroceryItem1 = GroceryItemEntity(
    id: 'g1',
    foodName: 'Rolled Oats',
    category: 'Grains',
    quantity: 500,
    unit: 'g',
    addedAt: DateTime.now(),
    isPurchased: false,
  );

  final testGroceryItem2 = GroceryItemEntity(
    id: 'g2',
    foodName: 'Greek Yogurt',
    category: 'Dairy',
    quantity: 400,
    unit: 'g',
    addedAt: DateTime.now(),
    isPurchased: true,
  );

  final testGroceryList = GroceryListEntity(
    id: 'list_1',
    userId: 'user_123',
    generatedAt: DateTime.now(),
    periodStart: DateTime.now(),
    periodEnd: DateTime.now().add(const Duration(days: 7)),
    items: [testGroceryItem1, testGroceryItem2],
    totalItems: 2,
    purchasedItems: 1,
    remainingItems: 1,
  );

  final testPantryItem = PantryItemEntity(
    id: 'p1',
    foodName: 'Brown Rice',
    quantity: 1000,
    unit: 'g',
    expiryDate: DateTime.now().add(const Duration(days: 30)),
    addedAt: DateTime.now(),
  );

  const testReminder1 = ReminderEntity(
    id: 'r1',
    title: 'Hydration Check 💧',
    description: 'Drink 500ml water',
    type: ReminderType.hydration,
    scheduledTime: '14:00',
    actionRoute: '/health',
    completed: false,
  );

  const testReminder2 = ReminderEntity(
    id: 'r2',
    title: 'Lunch Time 🥗',
    description: 'Grilled Chicken Salad',
    type: ReminderType.lunch,
    scheduledTime: '13:00',
    actionRoute: '/nutrition',
    completed: true,
  );

  const testRoutine = DailyRoutineEntity(
    date: '2026-09-29',
    totalReminders: 2,
    completedReminders: 1,
    completionPercentage: 50.0,
    nextReminder: testReminder1,
    routineItems: [testReminder1, testReminder2],
    completedItems: [testReminder2],
    pendingItems: [testReminder1],
  );

  Widget createGroceryApp({
    required int initialTab,
    required double width,
    required double textScale,
    required bool isDark,
    GroceryListEntity? list,
    List<PantryItemEntity>? pantry,
  }) {
    return ProviderScope(
      overrides: [
        currentGroceryListProvider.overrideWithValue(AsyncValue.data(list)),
        groceryListsProvider.overrideWith((ref) => Stream.value(list != null ? [list] : [])),
        pantryProvider.overrideWith((ref) => Stream.value(pantry ?? [])),
        groceryPreferencesProvider
            .overrideWith((ref) => Stream.value(const GroceryPreferencesEntity())),
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
              child: GroceryScreen(initialTab: initialTab),
            ),
          ),
        ),
      ),
    );
  }

  Widget createRoutineApp({
    required double width,
    required double textScale,
    required bool isDark,
    required DailyRoutineEntity routine,
  }) {
    return ProviderScope(
      overrides: [
        dailyRoutineProvider.overrideWithValue(routine),
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
              child: const DailyRoutineScreen(),
            ),
          ),
        ),
      ),
    );
  }

  group('Phase 35.3F Grocery & Pantry Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('Grocery screen renders at $width px without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createGroceryApp(
          initialTab: 0,
          width: width,
          textScale: 1.0,
          isDark: false,
          list: testGroceryList,
          pantry: [testPantryItem],
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Shopping Checklist'), findsOneWidget);
        expect(find.text('Rolled Oats'), findsOneWidget);
        expect(find.text('Greek Yogurt'), findsOneWidget);
      });

      testWidgets('Pantry tab renders at $width px without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createGroceryApp(
          initialTab: 1,
          width: width,
          textScale: 1.0,
          isDark: false,
          list: testGroceryList,
          pantry: [testPantryItem],
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Pantry Inventory'), findsOneWidget);
        expect(find.text('Brown Rice'), findsOneWidget);
      });
    }

    testWidgets('Grocery empty state displays actionable CTA', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createGroceryApp(
        initialTab: 0,
        width: 390,
        textScale: 1.0,
        isDark: false,
        list: null,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FitFuelEmptyState), findsOneWidget);
      expect(find.text('No Active Shopping List'), findsOneWidget);
      expect(find.text('Generate List from Meal Plan'), findsOneWidget);
    });

    testWidgets('Pantry empty state displays actionable CTA', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createGroceryApp(
        initialTab: 1,
        width: 390,
        textScale: 1.0,
        isDark: false,
        list: testGroceryList,
        pantry: const [],
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FitFuelEmptyState), findsOneWidget);
      expect(find.text('Your Pantry is Empty'), findsOneWidget);
      expect(find.text('Add Pantry Item'), findsWidgets);
    });
  });

  group('Phase 35.3F Daily Routine Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 1.4]) {
        testWidgets(
            'Daily Routine renders at $width px scale $scale without overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(createRoutineApp(
            width: width,
            textScale: scale,
            isDark: false,
            routine: testRoutine,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Daily Routine'), findsOneWidget);
          expect(find.text("Today's Progress"), findsOneWidget);
          expect(find.text('Smart Check-in'), findsOneWidget);
          expect(find.text('Daily Checklist'), findsOneWidget);
        });
      }
    }

    testWidgets('Daily Routine empty state renders cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const emptyRoutine = DailyRoutineEntity(
        date: '2026-09-29',
        totalReminders: 0,
        completedReminders: 0,
        completionPercentage: 100.0,
        routineItems: [],
        completedItems: [],
        pendingItems: [],
      );

      await tester.pumpWidget(createRoutineApp(
        width: 390,
        textScale: 1.0,
        isDark: false,
        routine: emptyRoutine,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FitFuelEmptyState), findsOneWidget);
      expect(find.text('No Routine Configured'), findsOneWidget);
      expect(find.text('Configure Reminders'), findsOneWidget);
    });
  });
}
