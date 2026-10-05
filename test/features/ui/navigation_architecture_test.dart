import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/app/navigation/app_destinations.dart';
import 'package:fitfuel/app/navigation/app_shell.dart';
import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:fitfuel/app/navigation/feature_action_navigation.dart';

class DraftPage extends StatefulWidget {
  final String title;
  const DraftPage(this.title, {super.key});
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final draft = TextEditingController();
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: FitFuelAppBar(title: Text(widget.title)),
        body: ListView(children: [
          TextField(key: ValueKey('draft-${widget.title}'), controller: draft),
          TextButton(
              onPressed: () => context.go(
                  '${appDestinations.firstWhere((d) => d.label == widget.title).path}/detail'),
              child: const Text('Open detail')),
        ]),
      );
}

GoRouter fixtureRouter({String initial = '/home'}) => GoRouter(
      initialLocation: initial,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final destination in appDestinations)
              StatefulShellBranch(routes: [
                GoRoute(
                  path: destination.path,
                  builder: (_, __) => DraftPage(destination.label),
                  routes: [
                    GoRoute(
                        path: 'detail',
                        builder: (_, __) => const Scaffold(
                            appBar: FitFuelAppBar(title: Text('Detail')),
                            body: Text('Child page')))
                  ],
                )
              ]),
          ],
        ),
        GoRoute(
            path: '/profile',
            builder: (_, __) =>
                const Scaffold(appBar: FitFuelAppBar(title: Text('Profile')))),
        GoRoute(
            path: '/settings',
            builder: (_, __) =>
                const Scaffold(appBar: FitFuelAppBar(title: Text('Settings')))),
      ],
    );

void main() {
  test('legacy destinations preserve query parameters', () {
    for (final entry in legacyRouteMap.entries) {
      expect(canonicalLocation('${entry.key}?prompt=hello'),
          '${entry.value}?prompt=hello');
    }
    expect(canonicalLocation('https://example.com'), '/home');
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('adaptive shell at $width with 1.4 text scaling',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = fixtureRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width < 600) {
        expect(find.byType(NavigationDestination), findsNWidgets(5));
      } else if (width < 1024) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.text('AI Coach'), findsOneWidget);
      }
    });
  }

  testWidgets('branch drafts and child stacks survive tab changes and resizing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = fixtureRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('draft-Home')), 'Retained draft');
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home/detail');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Retained draft'), findsOneWidget);
    for (final width in [768.0, 1440.0, 320.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(find.text('Retained draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('direct child link has parent back; AI returns to prior branch',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = fixtureRouter(initial: '/plan/detail');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/plan');
    await tester.tap(find.byTooltip('Ask AI'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Return to previous page'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/plan');
  });
}
