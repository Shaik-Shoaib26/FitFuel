import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/authentication/domain/repositories/i_auth_repository.dart';
import 'package:fitfuel/features/authentication/presentation/screens/login_screen.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/grocery/presentation/screens/grocery_screen.dart';
import 'package:fitfuel/features/plan/presentation/screens/plan_screen.dart';

class SignedInUser extends Fake implements User {
  @override
  String get uid => 'navigation-fixture';
}

class UnusedAuthRepository extends Fake implements IAuthRepository {}

void main() {
  testWidgets(
      'protected deep link survives sign-in and sign-out removes private pages',
      (tester) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    final container = ProviderContainer(overrides: [
      authStateStreamProvider.overrideWith((_) => auth.stream),
      authRepositoryProvider.overrideWithValue(UnusedAuthRepository()),
      networkStatusProvider
          .overrideWith((_) => Stream.value(NetworkStatus.online)),
    ]);
    addTearDown(container.dispose);
    container.read(routerProvider).go('/plan?source=link');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (_, ref, __) =>
                MaterialApp.router(routerConfig: ref.watch(routerProvider)))));
    await tester.pump();
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    auth.add(SignedInUser());
    await tester.pumpAndSettle();
    expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        '/plan?source=link');
    expect(find.byType(PlanScreen), findsOneWidget);
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(PlanScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets(
        'production Health, Nutrition and Plan routes at $width and 1.4x',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final container = ProviderContainer(overrides: [
        authStateStreamProvider
            .overrideWith((_) => Stream.value(SignedInUser())),
        networkStatusProvider
            .overrideWith((_) => Stream.value(NetworkStatus.online)),
        nutritionStreamProvider.overrideWith((_) => Stream.value([
              NutritionRecordEntity(
                  id: 'logged-food',
                  foodName: 'A long food name with a large serving',
                  mealType: 'Breakfast',
                  calories: 600,
                  protein: 25,
                  carbohydrates: 55,
                  fats: 20,
                  sugar: 5,
                  servingSize: 300,
                  consumedAt: now,
                  createdAt: now,
                  updatedAt: now),
            ])),
        nutritionGoalsStreamProvider.overrideWith((_) => Stream.value(null)),
        currentProfileStreamProvider.overrideWith((_) => Stream.value(null)),
        healthStreamProvider.overrideWith((_) => Stream.value([])),
        // Health surfaces the weight entry point, so the weight stream is part
        // of its fixture just like it is for the Weight page.
        weightHistoryStreamProvider.overrideWith((_) => Stream.value([])),
        currentGroceryListProvider
            .overrideWithValue(const AsyncValue.data(null)),
        pantryProvider.overrideWith((_) => Stream.value([])),
        groceryPreferencesProvider.overrideWith((_) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateStreamProvider.future);
      final router = container.read(routerProvider)..go('/plan');
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.4)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScreen), findsOneWidget);
      for (final route in [
        '/health',
        '/nutrition',
        '/plan/grocery/pantry',
        '/plan/grocery'
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        expect(router.routeInformationProvider.value.uri.path, route);
      }
      final groceryState = tester.state(find.byType(GroceryScreen));
      await tester.tap(find.text('Pantry Stock'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path,
          '/plan/grocery/pantry');
      expect(tester.state(find.byType(GroceryScreen)), same(groceryState));
      // The platform delivers browser history changes through route information.
      await router.routeInformationProvider.didPushRouteInformation(
          RouteInformation(uri: Uri.parse('/plan/grocery')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/plan/grocery');
      expect(tester.state(find.byType(GroceryScreen)), same(groceryState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
