import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'qa-test-user-scan';
  @override
  String get email => 'qa.scan@fitfuel.app';
  @override
  String get displayName => 'Scan QA User';
}

class _FakeFoodImagePickerService implements IFoodImagePickerService {
  @override
  Future<String?> pickImage(FoodImagePickSource source) async => '/tmp/test_food.jpg';

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async =>
      Uint8List.fromList([10, 20, 30]);
}

class _FakeFoodScanRepository implements IFoodScanRepository {
  @override
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
  }) async {
    return FoodScanResult(
      id: 'scan_ui_test',
      imagePath: imagePath,
      foods: const [
        DetectedFoodCandidate(
          id: 'c1',
          detectedName: 'Idli Sambar',
          confidence: 0.92,
          estimatedAmount: 150.0,
          matchedFood: FoodEntity(
            id: 'predefined_idli',
            name: 'Idli',
            category: 'Breakfast',
            servingSize: 100.0,
            servingUnit: 'g',
            calories: 120.0,
            protein: 3.2,
            carbohydrates: 25.5,
            fats: 0.4,
            fiber: 1.2,
            sugar: 0.1,
            sodium: 140.0,
          ),
        ),
      ],
      overallConfidence: 0.92,
      scannedAt: DateTime.now(),
    );
  }
}

Widget _wrapScanScreen({
  double width = 390,
  double textScale = 1.0,
  bool isDark = false,
  bool isOffline = false,
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((_) => Stream.value(_FakeUser())),
      networkStatusProvider.overrideWith(
        (_) => Stream.value(isOffline ? NetworkStatus.offline : NetworkStatus.online),
      ),
      foodImagePickerServiceProvider.overrideWithValue(_FakeFoodImagePickerService()),
      foodScanRepositoryProvider.overrideWithValue(_FakeFoodScanRepository()),
    ],
    child: MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: const FoodScanScreen(),
      ),
    ),
  );
}

void main() {
  group('Phase 35.5 — FoodScanScreen Widget & Responsive Layout Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      testWidgets('Initial scan screen renders at $width px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapScanScreen(width: width));
        await tester.pump();

        expect(find.text('Scan Food'), findsOneWidget);
        expect(find.text('Scan Your Meal'), findsOneWidget);
        expect(find.text('Take Photo'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsOneWidget);
        expect(find.text('Privacy & Estimation Notice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Handles 1.4x text scaling without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScanScreen(width: 390, textScale: 1.4));
      await tester.pump();

      expect(find.text('Scan Your Meal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScanScreen(width: 1024, isDark: true));
      await tester.pump();

      expect(find.text('Scan Your Meal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Displays offline banner when network is disconnected', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScanScreen(width: 390, isOffline: true));
      await tester.pump();

      expect(find.text('Food scanning requires an internet connection.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Take Photo transitions to analyzing then success result', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapScanScreen(width: 390));
      await tester.pump();

      // Tap Take Photo button
      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expect analysis result state
      expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
      expect(find.text('Identified Food Items'), findsOneWidget);
      expect(find.text('Idli'), findsOneWidget);
      expect(find.text('Add to Food Diary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
