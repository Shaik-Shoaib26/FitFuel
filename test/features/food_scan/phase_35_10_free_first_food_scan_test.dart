import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/fake_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_telemetry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-user-35-10';
  @override
  String get email => 'freefirst@fitfuel.app';
  @override
  String get displayName => 'Free First Tester';
}

class _FakeImagePickerService implements IFoodImagePickerService {
  String? nextPath = '/tmp/scan_meal_35_10.jpg';
  Uint8List? nextBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
  int pickCallCount = 0;

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    pickCallCount++;
    return nextPath;
  }

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async => nextBytes;
}

class _MockRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;
  List<RawDetectedFood> mockRawFoods = [];
  Exception? exceptionToThrow;
  Completer<List<RawDetectedFood>>? completer;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    if (completer != null) {
      return await completer!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockRawFoods;
  }

  @override
  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  }) async {
    return null;
  }
}

class _FakeNutritionRepository extends Fake implements INutritionRepository {
  final List<NutritionRecordEntity> loggedRecords = [];

  @override
  Future<void> addRecord(String uid, NutritionRecordEntity record) async {
    loggedRecords.add(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFoodVisionClassifier fakeClassifier;
  late _MockRemoteDataSource mockRemote;
  late _FakeImagePickerService fakePicker;
  late _FakeNutritionRepository fakeNutritionRepo;
  late List<FoodEntity> catalog;
  final List<FoodScanTelemetryEvent> telemetryEvents = [];
  final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

  setUp(() {
    fakeClassifier = FakeFoodVisionClassifier();
    mockRemote = _MockRemoteDataSource();
    fakePicker = _FakeImagePickerService();
    fakeNutritionRepo = _FakeNutritionRepository();
    catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    telemetryEvents.clear();
  });

  FoodScanRecognitionRouter createRouter({
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
  }) {
    return FoodScanRecognitionRouter(
      localClassifier: fakeClassifier,
      remoteDataSource: mockRemote,
      config: config,
      telemetrySink: telemetryEvents.add,
    );
  }

  FoodScanController createController({
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
  }) {
    final router = createRouter(config: config);
    final repo = FoodScanRepositoryImpl(
      remoteDataSource: mockRemote,
      router: router,
    );
    return FoodScanController(
      repository: repo,
      imagePickerService: fakePicker,
    );
  }

  Widget wrapScreen({
    required FoodScanRecognitionRouter router,
    bool isOffline = false,
    FoodScanRouterConfig? configOverride,
  }) {
    final repo = FoodScanRepositoryImpl(
      remoteDataSource: mockRemote,
      router: router,
    );
    return ProviderScope(
      overrides: [
        authStateStreamProvider.overrideWith((_) => Stream.value(_FakeUser())),
        networkStatusProvider.overrideWith(
          (_) => Stream.value(
              isOffline ? NetworkStatus.offline : NetworkStatus.online),
        ),
        foodImagePickerServiceProvider.overrideWithValue(fakePicker),
        foodVisionClassifierProvider.overrideWithValue(fakeClassifier),
        foodScanRemoteDatasourceProvider.overrideWithValue(mockRemote),
        foodScanRouterConfigProvider
            .overrideWithValue(configOverride ?? router.config),
        foodScanRecognitionRouterProvider.overrideWithValue(router),
        foodScanRepositoryProvider.overrideWithValue(repo),
        nutritionRepositoryProvider.overrideWithValue(fakeNutritionRepo),
      ],
      child: const MaterialApp(
        home: Scaffold(body: FoodScanScreen()),
      ),
    );
  }

  group('Phase 35.10 — Free-First Food Scan Core Routing & UX Tests', () {
    test(
        '58. TEST — AUTO LOCAL: Samosa (conf 0.94, margin 0.40, production enabled) auto-resolves with 0 Gemini calls',
        () async {
      final router = createRouter();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: mockRemote,
        router: router,
      );
      final controller = FoodScanController(
        repository: repo,
        imagePickerService: fakePicker,
      );

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.94,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.54, // margin = 0.94 - 0.54 = 0.40 >= 0.15
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/samosa.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(mockRemote.analyzeCallCount, equals(0));
      expect(fakeClassifier.classifyCallCount, equals(1));
      expect(router.autoLocalAccepted, equals(1));
      expect(controller.state, isA<FoodScanSuccess>());

      final success = controller.state as FoodScanSuccess;
      expect(
        success.result.recognitionSource,
        equals(FoodScanRecognitionSource.localModel),
      );
      expect(success.result.debugRoute, equals('route=auto_local'));
      expect(success.result.foods.first.matchedFood?.id,
          equals('predefined_samosa'));
      expect(telemetryEvents.last.route, equals('auto_local'));
    });

    test(
        '59. TEST — LOW CONFIDENCE SUGGESTIONS: Idli 0.54, Medu Vada 0.22, Uttapam 0.11 shows local suggestions with 0 Gemini calls',
        () async {
      final router = createRouter();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: mockRemote,
        router: router,
      );
      final controller = FoodScanController(
        repository: repo,
        imagePickerService: fakePicker,
      );

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.54,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.22,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_uttapam',
          foodName: 'Uttapam',
          confidence: 0.11, // Below 0.15 minimumSuggestionConfidence
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/idli_plate.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      // Zero Gemini calls initially!
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(fakeClassifier.classifyCallCount, equals(1));
      expect(router.localSuggestionShown, equals(1));
      expect(controller.state, isA<FoodScanSuggestions>());

      final suggestionState = controller.state as FoodScanSuggestions;
      expect(suggestionState.routeDecision, isA<LocalSuggestionsAvailable>());
      // Idli (0.54) and Medu Vada (0.22) >= 0.15 are shown; Uttapam (0.11 < 0.15) filtered out
      expect(suggestionState.suggestions.length, equals(2));
      expect(
          suggestionState.suggestions[0].foodId, equals('predefined_idli'));
      expect(suggestionState.suggestions[0].foodName, equals('Idli'));
      expect(suggestionState.suggestions[1].foodId,
          equals('predefined_medu_vada'));
      expect(suggestionState.suggestions[1].foodName, equals('Medu Vada'));
    });

    test(
        '60. TEST — USER CONFIRMS SUGGESTION: Tapping Idli resolves FitFuel database result with 0 Gemini calls',
        () async {
      final router = createRouter();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: mockRemote,
        router: router,
      );
      final controller = FoodScanController(
        repository: repo,
        imagePickerService: fakePicker,
      );

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.54,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.22,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/idli.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      expect(controller.state, isA<FoodScanSuggestions>());

      final suggestions = (controller.state as FoodScanSuggestions).suggestions;
      controller.confirmSuggestion(suggestions.first, catalog: catalog);

      expect(mockRemote.analyzeCallCount, equals(0));
      expect(router.localSuggestionConfirmed, equals(1));
      expect(controller.state, isA<FoodScanSuccess>());

      final result = (controller.state as FoodScanSuccess).result;
      expect(
        result.recognitionSource,
        equals(FoodScanRecognitionSource.localSuggestionConfirmed),
      );
      expect(result.debugRoute, equals('route=local_suggestion'));
      expect(result.foods.first.matchedFood?.id, equals('predefined_idli'));
      expect(result.foods.first.displayName, equals('Idli'));

      // Can log to Food Diary with 0 Gemini calls
      final logged = await controller.logToDiary('u1', fakeNutritionRepo);
      expect(logged, isTrue);
      expect(fakeNutritionRepo.loggedRecords.length, equals(1));
      expect(fakeNutritionRepo.loggedRecords.first.foodName, equals('Idli'));
      expect(mockRemote.analyzeCallCount, equals(0));
    });

    test(
        '61. TEST — USER CHOOSES AI: Tapping Analyze with AI invokes Gemini exactly once',
        () async {
      final router = createRouter();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: mockRemote,
        router: router,
      );
      final controller = FoodScanController(
        repository: repo,
        imagePickerService: fakePicker,
      );

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.54,
        ),
      ]);

      mockRemote.mockRawFoods = [
        const RawDetectedFood(
          name: 'Plain Dosa',
          confidence: 0.92,
          estimatedGrams: 120.0,
          unit: 'g',
        ),
      ];

      await controller.scanImageBytes(
        imagePath: '/tmp/plate.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      // Before user taps Analyze with AI: 0 Gemini calls
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(controller.state, isA<FoodScanSuggestions>());

      // User explicitly requests AI analysis
      await controller.analyzeWithAi(catalog: catalog);

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(router.geminiRequested, equals(1));
      expect(router.geminiSucceeded, equals(1));
      expect(controller.state, isA<FoodScanSuccess>());

      final result = (controller.state as FoodScanSuccess).result;
      expect(result.recognitionSource, equals(FoodScanRecognitionSource.gemini));
      expect(result.debugRoute, equals('route=gemini'));
    });

    testWidgets(
        '62. TEST — GEMINI QUOTA EXHAUSTED: Retains image, local suggestions visible, Search Foods available, no terminal blocked screen',
        (tester) async {
      final router = createRouter();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.54,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.25,
        ),
      ]);

      mockRemote.exceptionToThrow = FoodScanException(
        type: FoodScanFailureType.dailyQuotaReached,
        message:
            'AI analysis is unavailable until provider quota resets. You can still use local suggestions or search foods manually.',
        statusCode: 429,
      );

      await tester.pumpWidget(wrapScreen(router: router));
      await tester.pumpAndSettle();

      // 1. Scan photo -> shows local suggestions with 0 Gemini calls
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Possible matches'), findsOneWidget);
      expect(find.text('Idli'), findsOneWidget);
      expect(find.text('Medu Vada'), findsOneWidget);
      expect(mockRemote.analyzeCallCount, equals(0));

      // 2. Tap "Analyze with AI" -> fails with quota exhaustion
      await tester.ensureVisible(find.text('Analyze with AI'));
      await tester.tap(find.text('Analyze with AI'));
      await tester.pumpAndSettle();

      expect(mockRemote.analyzeCallCount, equals(1));
      expect(router.geminiQuotaFailure, equals(1));

      // 3. Verify non-blocking experience:
      expect(find.text("AI analysis isn't available right now."), findsOneWidget);
      expect(find.text("Today's scan limit has been reached"), findsNothing);
      expect(find.text('Your photo is saved.'), findsOneWidget);
      expect(find.text('Possible matches'), findsOneWidget);
      expect(find.text('Idli'), findsOneWidget);
      expect(find.text('Medu Vada'), findsOneWidget);
      expect(find.text('Search Foods'), findsOneWidget);
      expect(find.text('Try Another Photo'), findsOneWidget);

      // 4. User can still confirm local suggestion "Idli" and complete scan!
      await tester.ensureVisible(find.text('Idli'));
      await tester.tap(find.text('Idli'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
      expect(find.text('Add to Food Diary'), findsOneWidget);
    });

    testWidgets(
        '63. TEST — GEMINI 503: Returns to free assistance UI with Possible Matches, Search Foods, and Retry AI',
        (tester) async {
      final router = createRouter();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.50,
        ),
      ]);

      mockRemote.exceptionToThrow = FoodScanException(
        type: FoodScanFailureType.serviceUnavailable,
        message: 'Service overloaded',
        statusCode: 503,
      );

      await tester.pumpWidget(wrapScreen(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Analyze with AI'));
      await tester.tap(find.text('Analyze with AI'));
      await tester.pumpAndSettle();

      expect(router.geminiServiceFailure, equals(1));
      expect(find.text("AI analysis couldn't finish."), findsOneWidget);
      expect(find.text('Possible Matches'), findsOneWidget);
      expect(find.text('Possible matches'), findsOneWidget);
      expect(find.text('Idli'), findsOneWidget);
      expect(find.text('Search Foods'), findsOneWidget);
      expect(find.text('Retry AI'), findsOneWidget);
    });

    testWidgets(
        '64. TEST — OFFLINE: Suggestions and manual search work offline; AI button disabled with offline helper text',
        (tester) async {
      final router = createRouter();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_banana',
          foodName: 'Ripe Banana',
          confidence: 0.58,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_apple',
          foodName: 'Apple',
          confidence: 0.25,
        ),
      ]);

      await tester.pumpWidget(wrapScreen(router: router, isOffline: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Zero cloud calls
      expect(mockRemote.analyzeCallCount, equals(0));

      // Shows offline assistance copy, NOT "No internet — Food Scan unavailable"
      expect(find.text('Choose the closest match'), findsOneWidget);
      expect(
          find.text('AI analysis needs an internet connection.'), findsOneWidget);
      expect(find.text('Possible matches'), findsOneWidget);
      expect(find.text('Ripe Banana'), findsOneWidget);
      expect(find.text('Search Foods'), findsOneWidget);

      // User confirms Ripe Banana offline -> completes scan
      await tester.ensureVisible(find.text('Ripe Banana'));
      await tester.tap(find.text('Ripe Banana'));
      await tester.pumpAndSettle();

      expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
      expect(find.text('Ripe Banana'), findsOneWidget);
      expect(mockRemote.analyzeCallCount, equals(0));
    });

    testWidgets(
        '65. TEST — NO LOCAL SUGGESTIONS: All 50 predictions below minimumSuggestionConfidence shows no random guesses',
        (tester) async {
      final router = createRouter();

      // All predictions have confidence <= 0.08 (< 0.15 minimumSuggestionConfidence)
      fakeClassifier.setBelowMinimumSuggestions(maxConfidence: 0.08);

      await tester.pumpWidget(wrapScreen(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(mockRemote.analyzeCallCount, equals(0));
      // Random low-confidence guesses (Potato, Onion, Tomato) must NOT be shown
      expect(find.text('Potato'), findsNothing);
      expect(find.text('Onion'), findsNothing);
      expect(find.text('Tomato'), findsNothing);

      // Search Foods, Analyze with AI, and Try Another Photo are shown
      expect(find.text('Search Foods'), findsOneWidget);
      expect(find.text('Analyze with AI'), findsOneWidget);
      expect(find.text('Try Another Photo'), findsOneWidget);
    });

    testWidgets(
        '66. TEST — MIXED MEAL: Does not auto-log Top-1 single food; offers Add Foods Manually and Analyze with AI',
        (tester) async {
      final router = createRouter();

      fakeClassifier.setMixedMealSuspected(candidates: const [
        LocalFoodCandidate(
          foodId: 'predefined_dosa',
          foodName: 'Plain Dosa',
          confidence: 0.90, // Even with high top-1 confidence, mixed meal must NOT auto-accept!
        ),
        LocalFoodCandidate(
          foodId: 'predefined_sambar',
          foodName: 'Sambar',
          confidence: 0.45,
        ),
      ]);

      await tester.pumpWidget(wrapScreen(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(mockRemote.analyzeCallCount, equals(0));
      expect(router.autoLocalAccepted, equals(0));

      // Shows Mixed Meal decision UI
      expect(
          find.text('Multiple foods detected or suspected.'), findsOneWidget);
      expect(find.text('Add Foods Manually'), findsOneWidget);
      expect(find.text('Analyze with AI'), findsOneWidget);
    });

    test(
        '67. TEST — USER CONFIRMATION BEATS CLOUD: Delayed cloud response (Dosa) is ignored after user confirms Idli',
        () async {
      final controller = createController();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.55,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/meal.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      expect(controller.state, isA<FoodScanSuggestions>());

      // Start slow cloud request
      final cloudCompleter = Completer<List<RawDetectedFood>>();
      mockRemote.completer = cloudCompleter;
      final cloudFuture = controller.analyzeWithAi(catalog: catalog);
      expect(controller.state, isA<FoodScanAnalyzing>());

      // User confirms Idli before cloud responds
      controller.confirmSuggestion(
        const LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.55,
        ),
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      expect(
        (controller.state as FoodScanSuccess).result.foods.first.displayName,
        equals('Idli'),
      );

      // Now delayed cloud response returns Dosa
      cloudCompleter.complete([
        const RawDetectedFood(
          name: 'Plain Dosa',
          confidence: 0.96,
          estimatedGrams: 120.0,
          unit: 'g',
        ),
      ]);
      await cloudFuture;

      // User-confirmed Idli MUST win; delayed cloud Dosa is ignored!
      expect(controller.state, isA<FoodScanSuccess>());
      final finalResult = (controller.state as FoodScanSuccess).result;
      expect(finalResult.foods.first.displayName, equals('Idli'));
      expect(
        finalResult.recognitionSource,
        equals(FoodScanRecognitionSource.localSuggestionConfirmed),
      );
    });

    test(
        '68. TEST — REPEATED FREE SCANS: 100 mocked scans via auto-local and suggestion confirmation have no daily limit and 0 Gemini calls',
        () async {
      final router = createRouter();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: mockRemote,
        router: router,
      );
      final controller = FoodScanController(
        repository: repo,
        imagePickerService: fakePicker,
      );

      for (var i = 0; i < 100; i++) {
        if (i.isEven) {
          // 50 Auto-local scans (Samosa, confidence 0.94)
          fakeClassifier.setHighConfidenceMatch(
            foodId: 'predefined_samosa',
            foodName: 'Samosa',
            confidence: 0.94,
          );
          await controller.scanImageBytes(
            imagePath: '/tmp/samosa_$i.jpg',
            imageBytes: testBytes,
            catalog: catalog,
          );
          expect(controller.state, isA<FoodScanSuccess>());
        } else {
          // 50 Suggestion-confirmed scans (Idli, confidence 0.52)
          fakeClassifier.setTopKSuggestions(const [
            LocalFoodCandidate(
              foodId: 'predefined_idli',
              foodName: 'Idli',
              confidence: 0.52,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_dosa',
              foodName: 'Plain Dosa',
              confidence: 0.25,
            ),
          ]);
          await controller.scanImageBytes(
            imagePath: '/tmp/idli_$i.jpg',
            imageBytes: testBytes,
            catalog: catalog,
          );
          expect(controller.state, isA<FoodScanSuggestions>());
          final top =
              (controller.state as FoodScanSuggestions).suggestions.first;
          controller.confirmSuggestion(top, catalog: catalog);
          expect(controller.state, isA<FoodScanSuccess>());
        }
      }

      expect(router.totalScans, equals(100));
      expect(router.autoLocalAccepted, equals(50));
      expect(router.localSuggestionShown, equals(50));
      expect(router.localSuggestionConfirmed, equals(50));
      expect(router.geminiRequested, equals(0));
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(router.freeCompletionRate, equals(1.0));
      expect(router.autoLocalRate, equals(0.50));
      expect(router.suggestionConfirmedRate, equals(0.50));
      expect(router.geminiUsageRate, equals(0.0));
    });

    testWidgets(
        '69. TEST — 238 FOOD MANUAL SEARCH: Complete 238-food catalog is searchable from Scan, preserves photo on back-out, and returns DB nutrition',
        (tester) async {
      expect(PredefinedFoodData.foods.length, equals(238));
      final router = createRouter();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.50,
        ),
      ]);

      await tester.pumpWidget(wrapScreen(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Open Search Foods modal
      await tester.ensureVisible(find.text('Search Foods'));
      await tester.tap(find.text('Search Foods'));
      await tester.pumpAndSettle();

      expect(find.text('Select Database Food'), findsOneWidget);

      // Close modal (back out) -> verify photo and suggestion state are preserved!
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Your photo is saved.'), findsOneWidget);
      expect(find.text('Possible matches'), findsOneWidget);

      // Re-open Search Foods and search for "Rajma"
      await tester.ensureVisible(find.text('Search Foods'));
      await tester.tap(find.text('Search Foods'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Rajma');
      await tester.pumpAndSettle();

      final rajmaEntity =
          catalog.firstWhere((f) => f.id == 'predefined_rajma_curry');
      expect(find.text(rajmaEntity.name), findsWidgets);

      await tester.tap(find.text(rajmaEntity.name).first);
      await tester.pumpAndSettle();

      // Transitions to FoodScanSuccess with exact database nutrition & 0 Gemini calls
      expect(mockRemote.analyzeCallCount, equals(0));
      expect(router.manualSearchUsed, equals(1));
      expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
      expect(find.text(rajmaEntity.name), findsOneWidget);
      expect(
        find.text('${rajmaEntity.calories.toStringAsFixed(0)} kcal'),
        findsWidgets,
      );
    });

    test(
        '70. TEST — DATABASE-FIRST NUTRITION: Suggestion predefined_idli pulls exact macros and canonical serving from PredefinedFoodData',
        () async {
      final router = createRouter();
      final idliDb = catalog.firstWhere((f) => f.id == 'predefined_idli');

      final result = router.confirmSuggestion(
        candidate: const LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.48,
        ),
        foodCatalog: catalog,
        imagePath: '/tmp/idli.jpg',
        requestId: 'req_db_first',
      );

      expect(mockRemote.analyzeCallCount, equals(0));
      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      expect(food.isAiEstimated, isFalse);
      expect(food.aiEstimatedNutrition, isNull);
      expect(food.estimatedAmount, equals(idliDb.servingSize));
      expect(food.estimatedUnit, equals(idliDb.servingUnit));
      expect(food.scaledCalories, equals(idliDb.calories));
      expect(food.scaledProtein, equals(idliDb.protein));
      expect(food.scaledCarbs, equals(idliDb.carbohydrates));
      expect(food.scaledFats, equals(idliDb.fats));
    });

    test(
        '71. Top-K filtering removes duplicates, invalid IDs, below-minimum candidates, and uses canonical FitFuel names',
        () {
      final router = createRouter();

      const prediction = LocalFoodPrediction(
        foodId: 'predefined_idli',
        foodName: 'raw_idli_label',
        confidence: 0.65,
        topCandidates: [
          LocalFoodCandidate(
            foodId: 'predefined_idli',
            foodName: 'raw_idli_label',
            confidence: 0.65,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_idli', // Duplicate ID with lower confidence
            foodName: 'duplicate_idli',
            confidence: 0.40,
          ),
          LocalFoodCandidate(
            foodId: 'invalid_nonexistent_id', // Invalid catalog ID
            foodName: 'Fake Food',
            confidence: 0.80,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_banana',
            foodName: 'non_canonical_banana',
            confidence: 0.35,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_dosa',
            foodName: 'dosa_raw',
            confidence: 0.22,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_upma',
            foodName: 'Upma',
            confidence: 0.19, // 4th valid candidate (should be cut by Top-3 limit)
          ),
          LocalFoodCandidate(
            foodId: 'predefined_poha',
            foodName: 'Poha',
            confidence: 0.09, // Below 0.15 minimumSuggestionConfidence
          ),
        ],
      );

      final filtered =
          router.extractTopKSuggestions(prediction, foodCatalog: catalog);

      expect(filtered.length, equals(3));
      expect(filtered[0].foodId, equals('predefined_idli'));
      expect(filtered[0].foodName, equals('Idli'));
      expect(filtered[0].confidence, equals(0.65));
      expect(
        filtered[0].confidenceBand(),
        equals(SuggestionConfidenceBand.strong),
      );

      expect(filtered[1].foodId, equals('predefined_banana'));
      expect(filtered[1].foodName, equals('Ripe Banana')); // Canonical name!
      expect(filtered[1].confidence, equals(0.35));
      expect(
        filtered[1].confidenceBand(),
        equals(SuggestionConfidenceBand.moderate),
      );

      expect(filtered[2].foodId, equals('predefined_dosa'));
      expect(filtered[2].foodName, equals('Plain Dosa')); // Canonical name!
      expect(filtered[2].confidence, equals(0.22));
      expect(
        filtered[2].confidenceBand(),
        equals(SuggestionConfidenceBand.weak),
      );
    });

    test(
        '72. All 50 model classes can participate in suggestion mode while only 8 V5 classes can auto-resolve',
        () async {
      final router = createRouter();
      expect(kFitFuelV1SupportedFoodIds.length, equals(50));
      expect(kFitFuelV5ProductionEnabledFoodIds.length, equals(8));

      // Non-auto class (e.g. predefined_idli is in the 50 model classes, but NOT in the 8 auto classes)
      // Even at 0.92 confidence, it must NOT auto-resolve, and instead offer local suggestions!
      fakeClassifier.setHighConfidenceMatch(
        foodId: 'predefined_idli',
        foodName: 'Idli',
        confidence: 0.92,
      );

      final decision = await router.routeFreeFirst(
        imagePath: '/tmp/idli.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_50_class_suggestion',
      );

      expect(decision, isA<LocalSuggestionsAvailable>());
      expect(mockRemote.analyzeCallCount, equals(0));
      final suggestions = (decision as LocalSuggestionsAvailable).suggestions;
      expect(suggestions.first.foodId, equals('predefined_idli'));
    });

    test(
        '73. Do not mislabel non-Top-1 suggestion confirmation as Top-1 model accuracy in telemetry',
        () async {
      final router = createRouter();

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_dosa',
          foodName: 'Plain Dosa',
          confidence: 0.45,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_uttapam',
          foodName: 'Uttapam',
          confidence: 0.35,
        ),
      ]);

      final decision = await router.routeFreeFirst(
        imagePath: '/tmp/uttapam.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        requestId: 'req_uttapam',
      );
      expect(decision, isA<LocalSuggestionsAvailable>());

      // User selects Top-2 (Uttapam), NOT Top-1 (Dosa)
      final confirmed = router.confirmSuggestion(
        candidate: (decision as LocalSuggestionsAvailable).suggestions[1],
        foodCatalog: catalog,
        imagePath: '/tmp/uttapam.jpg',
        requestId: 'req_uttapam_confirm',
        top1FoodId: decision.prediction?.foodId,
      );

      expect(router.autoLocalAccepted, equals(0));
      expect(router.localSuggestionConfirmed, equals(1));
      expect(router.localSuggestionTop1Confirmed, equals(0));
      expect(
        confirmed.recognitionSource,
        equals(FoodScanRecognitionSource.localSuggestionConfirmed),
      );
    });
  });
}
