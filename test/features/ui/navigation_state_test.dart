import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:fitfuel/features/analytics/domain/repositories/i_analytics_repository.dart';
import 'package:fitfuel/features/health/presentation/providers/health_providers.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitfuel/features/grocery/presentation/providers/grocery_providers.dart';
import 'package:fitfuel/features/grocery/domain/entities/grocery_list_entity.dart';

class TestUser extends Fake implements User {
  @override
  final String uid;
  TestUser(this.uid);
}

class AnalyticsRepository extends Mock implements IAnalyticsRepository {}

List<String> paths(List<RouteBase> routes, [String parent = '']) {
  final result = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      final path =
          route.path.startsWith('/') ? route.path : '$parent/${route.path}';
      result.add(path);
      result.addAll(paths(route.routes, path));
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        result.addAll(paths(branch.routes));
      }
    }
  }
  return result;
}

void main() {
  test('production routes expose canonical deep links and legacy aliases',
      () async {
    final container = ProviderContainer(overrides: [
      authStateStreamProvider.overrideWith((_) => Stream.value(null))
    ]);
    addTearDown(container.dispose);
    await container.read(authStateStreamProvider.future);
    final router = container.read(routerProvider);
    final registered = paths(router.configuration.routes);
    for (final path in [
      '/home',
      '/health',
      '/health/weight',
      '/nutrition',
      '/nutrition/log',
      '/nutrition/log/:recordId/edit',
      '/nutrition/search',
      '/nutrition/food/:id',
      '/nutrition/custom/new',
      '/nutrition/custom/:id/edit',
      '/plan',
      '/plan/meals',
      '/plan/smart-eat',
      '/plan/grocery',
      '/plan/grocery/pantry',
      '/plan/routine',
      '/progress',
      '/progress/analytics',
      '/progress/weekly-report',
      '/progress/insights',
      '/ai',
      '/profile',
      '/settings',
      '/settings/account',
      '/dashboard',
      '/meal-planner',
      '/food-details'
    ]) {
      expect(registered, contains(path), reason: path);
    }
  });

  test('router stays stable for same UID and resets for account switching',
      () async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    final container = ProviderContainer(
        overrides: [authStateStreamProvider.overrideWith((_) => auth.stream)]);
    addTearDown(container.dispose);
    container.read(authStateStreamProvider);
    auth.add(TestUser('account-a'));
    await container.read(authStateStreamProvider.future);
    final first = container.read(routerProvider);
    auth.add(TestUser('account-a'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(routerProvider), same(first));
    auth.add(TestUser('account-b'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(routerProvider), isNot(same(first)));
    final second = container.read(routerProvider);
    auth.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(routerProvider), isNot(same(second)));
  });

  test('analytics data refresh preserves controller identity and chosen range',
      () async {
    final health = StreamController<List<Never>>();
    addTearDown(health.close);
    final repository = AnalyticsRepository();
    // A failed fetch also must retain the user-selected range.
    when(() => repository.getAnalytics(
            uid: any(named: 'uid'),
            range: any(named: 'range'),
            today: any(named: 'today')))
        .thenAnswer((_) => Future.error(StateError('fixture unavailable')));
    final container = ProviderContainer(overrides: [
      authStateStreamProvider
          .overrideWith((_) => Stream.value(TestUser('account-a'))),
      analyticsRepositoryProvider.overrideWithValue(repository),
      nutritionStreamProvider.overrideWith((_) => Stream.value([])),
      healthStreamProvider.overrideWith((_) => health.stream),
      weightHistoryStreamProvider.overrideWith((_) => Stream.value([])),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateStreamProvider.future);
    final controller = container.read(analyticsControllerProvider.notifier);
    controller.changeRange('90D');
    health.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(analyticsControllerProvider.notifier), same(controller));
    expect(container.read(analyticsControllerProvider).range, '90D');
  });

  test('grocery refresh retains selected list until it disappears', () async {
    final lists = StreamController<List<GroceryListEntity>>();
    addTearDown(lists.close);
    final now = DateTime(2026, 9, 1);
    GroceryListEntity list(String id) => GroceryListEntity(
        id: id,
        userId: 'a',
        generatedAt: now,
        periodStart: now,
        periodEnd: now,
        items: [],
        totalItems: 0,
        purchasedItems: 0,
        remainingItems: 0);
    final container = ProviderContainer(overrides: [
      authStateStreamProvider.overrideWith((_) => Stream.value(TestUser('a'))),
      groceryListsProvider.overrideWith((_) => lists.stream),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateStreamProvider.future);
    container.read(selectedListIdProvider);
    lists.add([list('one'), list('two')]);
    await Future<void>.delayed(Duration.zero);
    container.read(selectedListIdProvider.notifier).state = 'two';
    lists.add([list('one'), list('two')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(selectedListIdProvider), 'two');
    lists.add([list('one')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(selectedListIdProvider), 'one');
  });
}
