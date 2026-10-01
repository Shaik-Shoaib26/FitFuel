import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/app/app.dart';
import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/features/appearance/data/appearance_repository_impl.dart';
import 'package:fitfuel/features/appearance/domain/appearance_repository.dart';
import 'package:fitfuel/features/appearance/presentation/appearance_controller.dart';
import 'package:fitfuel/features/appearance/presentation/appearance_settings_card.dart';

class TestAppearanceRepository implements AppearanceRepository {
  AppearanceMode mode = AppearanceMode.light;
  bool fail = false;
  @override
  Future<AppearanceMode> load() async => mode;
  @override
  Future<void> save(AppearanceMode value) async {
    if (fail) throw StateError('Storage unavailable');
    mode = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App applies dark mode and follows system brightness',
      (tester) async {
    final repository = TestAppearanceRepository();
    final container = ProviderContainer(overrides: [
      appearanceRepositoryProvider.overrideWithValue(repository),
      routerProvider.overrideWithValue(GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
                  body: Text(Theme.of(context).brightness.name),
                )),
      ])),
    ]);
    addTearDown(container.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await container.read(appearanceControllerProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const FitFuelApp()));
    expect(find.text('light'), findsOneWidget);
    await container
        .read(appearanceControllerProvider.notifier)
        .setMode(AppearanceMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
    await container
        .read(appearanceControllerProvider.notifier)
        .setMode(AppearanceMode.system);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(find.text('light'), findsOneWidget);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
  });

  test('Missing and invalid preferences preserve the existing light default',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppearanceRepositoryImpl().load(), AppearanceMode.light);
    SharedPreferences.setMockInitialValues(
        {AppearanceRepositoryImpl.storageKey: 'invalid'});
    expect(await AppearanceRepositoryImpl().load(), AppearanceMode.light);
  });

  test('Every appearance choice survives a new repository instance', () async {
    SharedPreferences.setMockInitialValues({});
    for (final mode in AppearanceMode.values) {
      await AppearanceRepositoryImpl().save(mode);
      expect(await AppearanceRepositoryImpl().load(), mode);
    }
  });

  test('Failed writes preserve the active theme and can be retried', () async {
    final repository = TestAppearanceRepository();
    final container = ProviderContainer(overrides: [
      appearanceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(appearanceControllerProvider.future);
    final controller = container.read(appearanceControllerProvider.notifier);
    repository.fail = true;
    expect(await controller.setMode(AppearanceMode.dark), isFalse);
    expect(container.read(appearanceControllerProvider).value,
        AppearanceMode.light);
    repository.fail = false;
    expect(await controller.setMode(AppearanceMode.dark), isTrue);
    expect(container.read(appearanceControllerProvider).value,
        AppearanceMode.dark);
  });

  testWidgets('Appearance choices save at 320px with large text',
      (tester) async {
    final repository = TestAppearanceRepository();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [appearanceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsCard())),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(repository.mode, AppearanceMode.dark);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dark'))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
