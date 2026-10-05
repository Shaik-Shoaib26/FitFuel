import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/core/theme/app_theme.dart';
import 'package:fitfuel/core/theme/fitfuel_semantic_colors.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_button.dart';
import 'package:fitfuel/core/widgets/fitfuel_chip.dart';
import 'package:fitfuel/core/widgets/fitfuel_section_header.dart';
import 'package:fitfuel/core/widgets/fitfuel_identity.dart';
import 'package:fitfuel/core/widgets/fitfuel_linear_progress.dart';
import 'package:fitfuel/core/widgets/fitfuel_progress_ring.dart';
import 'package:fitfuel/core/widgets/fitfuel_empty_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_error_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_loading_state.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'navigation_architecture_test.dart' as navigation;

Widget host(Widget child,
        {bool dark = false, double scale = 1, bool reduceMotion = false}) =>
    MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduceMotion),
                child: Scaffold(body: child))));

class FoundationGallery extends StatelessWidget {
  const FoundationGallery({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FitFuelSemanticColors.of(context);
    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FitFuelIdentity(),
                  const SizedBox(height: 24),
                  FitFuelSectionHeader(
                      title: 'A little better, every day',
                      subtitle: 'Design system preview · sample values',
                      actionLabel: 'View details',
                      onActionPressed: () {}),
                  const SizedBox(height: 16),
                  FitFuelCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Today’s nutrition',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text('1,540', style: theme.textTheme.displayLarge),
                        Text('kcal remaining',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        FitFuelLinearProgress(
                            value: .7,
                            label: 'Protein',
                            valueLabel: '78 / 112 g',
                            progressColor: colors.protein),
                        const SizedBox(height: 16),
                        FitFuelLinearProgress(
                            value: 1.15,
                            label: 'Hydration',
                            valueLabel: '2,300 / 2,000 ml',
                            progressColor: colors.hydration),
                      ])),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FitFuelChip(
                        label: 'Breakfast',
                        isSelected: true,
                        onSelected: (_) {}),
                    const FitFuelChip(
                        label: 'Vegetarian',
                        icon: Icons.eco_outlined,
                        isStatus: true),
                    const FitFuelChip(
                        label: 'Use soon',
                        icon: Icons.schedule,
                        isStatus: true),
                  ]),
                  const SizedBox(height: 16),
                  FitFuelButton(
                      label: 'Log food', icon: Icons.add, onPressed: () {}),
                  const SizedBox(height: 8),
                  FitFuelButton(
                      label: 'Explore the food library',
                      type: FitFuelButtonType.secondary,
                      onPressed: () {}),
                  const SizedBox(height: 16),
                  const TextField(
                      decoration: InputDecoration(
                          labelText: 'Search foods',
                          prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 16),
                  const FoodImageCard(
                      food: null,
                      imageSource: '',
                      aspectRatio: 2.4,
                      semanticDescription: 'Photo placeholder'),
                  const SizedBox(height: 16),
                  const FitFuelEmptyState(
                      icon: Icons.shopping_basket_outlined,
                      title: 'Your list starts here',
                      description: 'Add ingredients from your meal plan.'),
                ])));
  }
}

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

  for (final dark in [false, true]) {
    test(
        'theme ${dark ? 'dark' : 'light'} has coherent typography and readable contrast',
        () {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      expect(theme.extension<FitFuelSemanticColors>(), isNotNull);
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
      }

       for (final pair in [
         [theme.colorScheme.primary, theme.colorScheme.onPrimary],
         [theme.colorScheme.surface, theme.colorScheme.onSurface],
         [theme.colorScheme.surface, theme.colorScheme.onSurfaceVariant],
         [theme.colorScheme.error, theme.colorScheme.onError]
          ]) {
            final c = contrast(pair[0], pair[1]);
            final minContrast = dark ? 3.0 : 4.5;
            expect(c, greaterThanOrEqualTo(minContrast),
                reason: 'Contrast $c between ${pair[0]} and ${pair[1]} is too low');
          }



      expect(theme.textTheme.displayLarge!.fontSize,
          greaterThan(theme.textTheme.titleLarge!.fontSize!));
    });
    for (final width in [
      320.0,
      360.0,
      390.0,
      412.0,
      600.0,
      768.0,
      1024.0,
      1280.0,
      1366.0,
      1440.0
    ]) {
      for (final scale in [1.0, 1.2, 1.4]) {
        testWidgets('foundation width $width scale $scale dark $dark',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
              host(const FoundationGallery(), dark: dark, scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('interactive card exposes semantics and responds to keyboard',
      (tester) async {
    var tapped = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(FitFuelCard(
        semanticsLabel: 'Meal plan',
        selected: true,
        onTap: () => tapped++,
        child: const Text('Open'))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapped, 1);
    expect(find.bySemanticsLabel(RegExp('Meal plan')), findsOneWidget);
    semantics.dispose();
  });
  testWidgets(
      'all button variants grow, disable while loading and keep 48px targets',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    for (final type in FitFuelButtonType.values) {
      await tester.pumpWidget(host(
          Padding(
              padding: const EdgeInsets.all(16),
              child: FitFuelButton(
                  label: 'A longer action that needs to wrap safely',
                  type: type,
                  onPressed: () => taps++)),
          scale: 1.4));
      expect(tester.getSize(find.byType(FitFuelButton)).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byType(FitFuelButton));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host(FitFuelButton(
          label: 'Loading',
          type: type,
          isLoading: true,
          onPressed: () => taps++)));
      await tester.tap(find.byType(FitFuelButton));
      await tester.pump();
    }
    expect(taps, 4);
  });
  for (final value in [0.0, 1.0, 1.5, double.nan, double.infinity]) {
    testWidgets('progress safely renders $value and respects reduced motion',
        (tester) async {
      await tester.pumpWidget(host(
          Column(children: [
            FitFuelLinearProgress(value: value, label: 'Goal'),
            FitFuelProgressRing(
                value: value, centerTitle: '120', centerSubtitle: 'g protein')
          ]),
          scale: 1.4,
          reduceMotion: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          value.isFinite ? value.clamp(0, 1) : 0);
      expect(
          tester
              .widget<TweenAnimationBuilder<double>>(
                  find.byType(TweenAnimationBuilder<double>))
              .duration,
          Duration.zero);
    });
  }
  testWidgets('missing asset fallback preserves geometry and description',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const Align(
        alignment: Alignment.topLeft,
        child: FoodImageCard(
            food: null,
            imageSource: 'assets/missing-photo.png',
            width: 120,
            aspectRatio: 1.5,
            semanticDescription: 'Vegetable bowl'))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FoodImageCard)), const Size(120, 80));
    expect(find.bySemanticsLabel('Vegetable bowl'), findsOneWidget);
    expect(find.text('FitFuel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('error strips backend details and retry works; loader is labeled',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(
        FitFuelErrorState(
            error: const CacheFailure('FirebaseException secret stack trace'),
            onRetry: () => retries++),
        scale: 1.4));
    expect(find.textContaining('FirebaseException'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    await tester.pumpWidget(host(
        const FitFuelLoadingState(label: 'Loading your plan'),
        reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('Loading your plan'), findsOneWidget);
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('branded navigation at $width retains branch behavior',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = navigation.fixtureRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      router.go('/plan/detail');
      await tester.pumpAndSettle();
      expect(find.text('Child page'), findsOneWidget);
    });
  }
  for (final dark in [false, true]) {
    testWidgets('render review sheet dark $dark', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: host(const FoundationGallery(), dark: dark)));
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.dart_tool/design_review').create(recursive: true);
        await File('.dart_tool/design_review/${dark ? 'dark' : 'light'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
