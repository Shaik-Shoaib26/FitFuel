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
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_35_10_3';
  @override
  String get email => 'test@fitfuel.app';
  @override
  String get displayName => 'Test User';
}

class _StubClassifier implements FoodVisionClassifier {
  LocalFoodPrediction nextPrediction;
  int classifyCalls = 0;

  _StubClassifier(this.nextPrediction);

  @override
  bool get isAvailable => nextPrediction.isModelAvailable;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    classifyCalls++;
    return nextPrediction;
  }

  @override
  void dispose() {}
}

class _SpyRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;
  List<RawDetectedFood> nextResponse;

  _SpyRemoteDataSource({
    this.nextResponse = const [
      RawDetectedFood(
        name: 'Creamy Penne Pasta',
        confidence: 0.91,
        estimatedGrams: 220.0,
        unit: 'g',
        estimatedNutrition: EstimatedNutrition(
          calories: 390.0,
          protein: 12.0,
          carbs: 52.0,
          fat: 14.0,
        ),
      ),
    ],
  });

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    return nextResponse;
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

class _StubImagePickerService implements IFoodImagePickerService {
  final Uint8List sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    return 'mock_scan_photo.jpg';
  }

  @override
  Future<Uint8List?> getImageBytes(String path) async {
    return sampleBytes;
  }
}

class _FakeNutritionRepo extends Fake implements INutritionRepository {
  final List<NutritionRecordEntity> loggedRecords = [];

  @override
  Future<void> addRecord(
    String userId,
    NutritionRecordEntity record,
  ) async {
    loggedRecords.add(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> fullCatalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final Uint8List dummyBytes = Uint8List.fromList([10, 20, 30, 40]);

  Widget buildHarness({
    required FoodScanController controller,
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
    NetworkStatus networkStatus = NetworkStatus.online,
    INutritionRepository? nutritionRepo,
  }) {
    return ProviderScope(
      overrides: [
        foodScanControllerProvider.overrideWith((ref) => controller),
        foodScanRouterConfigProvider.overrideWithValue(config),
        networkStatusProvider.overrideWith(
          (ref) => Stream.value(networkStatus),
        ),
        authStateStreamProvider.overrideWith(
          (ref) => Stream.value(_FakeUser()),
        ),
        if (nutritionRepo != null)
          nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
      ],
      child: const MaterialApp(
        home: FoodScanScreen(),
      ),
    );
  }

  group('PHASE 35.10.3 — OOV Safety + Confirmed Nutrition UI Tests', () {
    testWidgets(
      'Test 1 — Pasta OOV case: Pineapple 0.22 + Grilled Chicken Breast 0.18 + Medu Vada 0.14 suppresses misleading suggestions and shows No reliable local match found with cloudCalls == 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Real-device observed OOV case for Creamy Penne Pasta
        const pastaOovPrediction = LocalFoodPrediction(
          foodId: 'predefined_pineapple',
          foodName: 'Pineapple',
          confidence: 0.22,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_pineapple',
              foodName: 'Pineapple',
              confidence: 0.22,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_grilled_chicken_breast',
              foodName: 'Grilled Chicken Breast',
              confidence: 0.18,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_medu_vada',
              foodName: 'Medu Vada',
              confidence: 0.14,
            ),
          ],
          inferenceDurationMs: 18,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(pastaOovPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );

        // Verify centralized reliability check directly
        expect(
          router.isReliableSuggestionSet(
            pastaOovPrediction,
            foodCatalog: fullCatalog,
          ),
          isFalse,
        );

        // Also verify cross-category conflict even if Top-1 is 0.48 and Top-2 is 0.28
        const higherScoreCrossCategoryOov = LocalFoodPrediction(
          foodId: 'predefined_pineapple',
          foodName: 'Pineapple',
          confidence: 0.48,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_pineapple',
              foodName: 'Pineapple',
              confidence: 0.48,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_grilled_chicken_breast',
              foodName: 'Grilled Chicken Breast',
              confidence: 0.28,
            ),
          ],
          inferenceDurationMs: 18,
          isModelAvailable: true,
        );
        final crossCatEval = router.evaluateSuggestionReliability(
          higherScoreCrossCategoryOov,
          foodCatalog: fullCatalog,
        );
        expect(crossCatEval.isReliable, isFalse);
        expect(crossCatEval.reason, 'unrelated_candidate_categories');

        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Route decision and telemetry checks
        final currentState = controller.state as FoodScanSuggestions;
        expect(currentState.routeDecision, isA<NoReliableLocalMatch>());
        expect(currentState.hasSuggestions, isFalse);
        expect(router.unreliableSuggestionSuppressed, 1);
        expect(router.noReliableLocalMatch, 1);
        expect(router.reliableSuggestionShown, 0);
        expect(
          router.lastSafetyLog,
          contains('reliableSuggestions=false'),
        );
        expect(
          router.lastRouteLog,
          contains('route=no_reliable_local_match'),
        );
        expect(router.lastRouteLog, contains('cloud_calls=0'));

        // UI does NOT show Pineapple or Grilled Chicken Breast
        expect(find.text('Pineapple'), findsNothing);
        expect(find.text('Grilled Chicken Breast'), findsNothing);
        expect(find.text('Possible matches'), findsNothing);

        // UI shows No reliable local match found + actions
        expect(find.text('No reliable local match found'), findsOneWidget);
        expect(
          find.text(
            'Search FitFuel foods or use AI analysis if you want a second opinion.',
          ),
          findsOneWidget,
        );
        expect(find.text('Search Foods'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsOneWidget);
        expect(find.text('Try Another Photo'), findsOneWidget);

        // Cloud calls remain strictly 0
        expect(spyRemote.analyzeCallCount, 0);
        expect(controller.cloudCallsThisScan, 0);
      },
    );

    testWidgets(
      'Test 2 — Good Samosa suggestion case: Samosa 0.72 + Medu Vada 0.16 shows Samosa suggestion, and confirming removes all Low Confidence warnings and displays Confirmed by you with cloudCalls == 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const samosaPrediction = LocalFoodPrediction(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.72,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_samosa',
              foodName: 'Samosa',
              confidence: 0.72,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_medu_vada',
              foodName: 'Medu Vada',
              confidence: 0.16,
            ),
          ],
          inferenceDurationMs: 17,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(samosaPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(router.reliableSuggestionShown, 1);
        expect(
          router.lastSafetyLog,
          contains('reliableSuggestions=true'),
        );
        expect(find.text('Possible matches'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);

        // User taps Samosa suggestion
        await tester.tap(find.byKey(const Key('suggestion_predefined_samosa')));
        await tester.pumpAndSettle();

        // Result screen shows "Confirmed by you"
        expect(find.text('Confirmed by you'), findsOneWidget);
        expect(find.text('Database Match'), findsOneWidget);
        expect(find.text('Change Food'), findsOneWidget);

        // Result screen does NOT show Low Confidence or Needs Confirmation
        expect(find.text('Low Confidence'), findsNothing);
        expect(find.text('Needs Confirmation'), findsNothing);
        expect(find.text("We're not confident about this food."), findsNothing);
        expect(find.text('Search Food'), findsNothing);

        // Trusted database nutrition notice and More nutrition section shown
        expect(
          find.text(
            "Nutrition is based on FitFuel's food database and your selected serving. Actual preparation may vary.",
          ),
          findsOneWidget,
        );
        expect(find.text('More nutrition'), findsOneWidget);
        expect(find.text('Fiber'), findsOneWidget);
        expect(find.text('Sugar'), findsOneWidget);
        expect(find.text('Sodium'), findsOneWidget);

        expect(spyRemote.analyzeCallCount, 0);
        expect(router.suggestionConfirmed, 1);
      },
    );

    testWidgets(
      'Test 2B — Sub-0.60 Samosa suggestion confirmed by user NEVER shows Low Confidence warning',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Even when raw model confidence was 0.52 (< 0.60), user confirmation overrides model uncertainty!
        const samosaSub60Prediction = LocalFoodPrediction(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.52,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_samosa',
              foodName: 'Samosa',
              confidence: 0.52,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_medu_vada',
              foodName: 'Medu Vada',
              confidence: 0.18,
            ),
          ],
          inferenceDurationMs: 17,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(samosaSub60Prediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('suggestion_predefined_samosa')));
        await tester.pumpAndSettle();

        final successState = controller.state as FoodScanSuccess;
        expect(successState.result.foods.first.isConfirmedByUser, isTrue);
        expect(successState.result.foods.first.isLowConfidence, isFalse);
        expect(successState.result.isLowConfidence, isFalse);

        expect(find.text('Confirmed by you'), findsOneWidget);
        expect(find.text('Low Confidence'), findsNothing);
        expect(find.text('Needs Confirmation'), findsNothing);
        expect(find.text("We're not confident about this food."), findsNothing);
        expect(spyRemote.analyzeCallCount, 0);
      },
    );

    testWidgets(
      'Test 3 — Manual Pasta search case: User selects Pasta manually, sees Confirmed by you, trusted database nutrition + More nutrition, no Low Confidence warning, cloudCalls == 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const pastaOovPrediction = LocalFoodPrediction(
          foodId: 'predefined_pineapple',
          foodName: 'Pineapple',
          confidence: 0.22,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_pineapple',
              foodName: 'Pineapple',
              confidence: 0.22,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_grilled_chicken_breast',
              foodName: 'Grilled Chicken Breast',
              confidence: 0.18,
            ),
          ],
          inferenceDurationMs: 18,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(pastaOovPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('No reliable local match found'), findsOneWidget);

        // User taps Search Foods and searches for Pasta
        await tester.tap(find.text('Search Foods'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Standard Pasta');
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('catalog_food_predefined_standard_pasta')),
        );
        await tester.pumpAndSettle();

        // Result screen shows Standard Pasta (Cooked) & "Confirmed by you"
        expect(find.text('Standard Pasta (Cooked)'), findsOneWidget);
        expect(find.text('Confirmed by you'), findsOneWidget);
        expect(find.text('Database Match'), findsOneWidget);

        // No Low Confidence warnings
        expect(find.text('Low Confidence'), findsNothing);
        expect(find.text('Needs Confirmation'), findsNothing);
        expect(find.text("We're not confident about this food."), findsNothing);

        // Database nutrition shown (131 kcal, P 5.0g, C 27.8g, F 0.6g, Fiber 1.2g, Sugar 0.5g, Sodium 2mg)
        expect(find.text('131 kcal'), findsWidgets);
        expect(find.text('5.0g'), findsOneWidget);
        expect(find.text('27.8g'), findsOneWidget);
        expect(find.text('0.6g'), findsOneWidget);
        expect(find.text('More nutrition'), findsOneWidget);
        expect(find.text('1.2g'), findsOneWidget);
        expect(find.text('0.5g'), findsOneWidget);
        expect(find.text('2mg'), findsOneWidget);

        expect(spyRemote.analyzeCallCount, 0);
        expect(router.manualConfirmed, 1);
      },
    );

    testWidgets(
      'Test 4 — Auto-local Medu Vada (0.93): Result screen shows Recognized on your device and cloudCalls == 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const meduVadaAuto = LocalFoodPrediction(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.93,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_medu_vada',
              foodName: 'Medu Vada',
              confidence: 0.93,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_idli',
              foodName: 'Idli',
              confidence: 0.03,
            ),
          ],
          inferenceDurationMs: 15,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(meduVadaAuto);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('Recognized on your device'), findsOneWidget);
        expect(find.text('Medu Vada'), findsOneWidget);
        expect(find.text('More nutrition'), findsOneWidget);
        expect(spyRemote.analyzeCallCount, 0);
      },
    );

    testWidgets(
      'Test 5 — Explicit Analyze with AI: Tapping Analyze with AI sets cloudCalls == 1 and result shows Identified with AI',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const pastaOovPrediction = LocalFoodPrediction(
          foodId: 'predefined_pineapple',
          foodName: 'Pineapple',
          confidence: 0.22,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_pineapple',
              foodName: 'Pineapple',
              confidence: 0.22,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_grilled_chicken_breast',
              foodName: 'Grilled Chicken Breast',
              confidence: 0.18,
            ),
          ],
          inferenceDurationMs: 18,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(pastaOovPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(spyRemote.analyzeCallCount, 0);
        expect(find.text('No reliable local match found'), findsOneWidget);

        // User explicitly taps Analyze with AI
        await tester.tap(find.text('Analyze with AI'));
        await tester.pumpAndSettle();

        expect(spyRemote.analyzeCallCount, 1);
        expect(find.text('Identified with AI'), findsOneWidget);
        expect(find.textContaining('Creamy Penne Pasta'), findsOneWidget);
      },
    );

    testWidgets(
      'Test 6 — Serving scaling: Changing portion size scales calories, protein, carbs, fat, fiber, sugar, and sodium proportionally',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const samosaPrediction = LocalFoodPrediction(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.72,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_samosa',
              foodName: 'Samosa',
              confidence: 0.72,
            ),
          ],
          inferenceDurationMs: 16,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(samosaPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final fakeNutritionRepo = _FakeNutritionRepo();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(
          buildHarness(
            controller: controller,
            nutritionRepo: fakeNutritionRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Select Whole Grain Pasta manually (100g base: 124 kcal, P 5.3g, C 26.5g, F 0.8g, fiber 3.2g, sugar 0.5g, sodium 2.0mg)
        final wholeGrainPasta = fullCatalog.firstWhere(
          (f) => f.id == 'predefined_whole_grain_pasta',
        );
        controller.selectManualFood(wholeGrainPasta);
        await tester.pumpAndSettle();

        final initialResult = (controller.state as FoodScanSuccess).result;
        expect(initialResult.totalCalories, closeTo(124.0, 0.01));
        expect(initialResult.totalProtein, closeTo(5.3, 0.01));
        expect(initialResult.totalCarbs, closeTo(26.5, 0.01));
        expect(initialResult.totalFats, closeTo(0.8, 0.01));
        expect(initialResult.totalFiber, closeTo(3.2, 0.01));
        expect(initialResult.totalSugar, closeTo(0.5, 0.01));
        expect(initialResult.totalSodium, closeTo(2.0, 0.01));

        // Double the serving size to 200g
        controller.updatePortion(0, 200.0);
        await tester.pumpAndSettle();

        final doubledResult = (controller.state as FoodScanSuccess).result;
        expect(doubledResult.totalCalories, closeTo(248.0, 0.01));
        expect(doubledResult.totalProtein, closeTo(10.6, 0.01));
        expect(doubledResult.totalCarbs, closeTo(53.0, 0.01));
        expect(doubledResult.totalFats, closeTo(1.6, 0.01));
        expect(doubledResult.totalFiber, closeTo(6.4, 0.01));
        expect(doubledResult.totalSugar, closeTo(1.0, 0.01));
        expect(doubledResult.totalSodium, closeTo(4.0, 0.01));

        // UI reflects scaled values
        expect(find.text('248 kcal'), findsWidgets);
        expect(find.text('10.6g'), findsOneWidget);
        expect(find.text('53.0g'), findsOneWidget);
        expect(find.text('1.6g'), findsOneWidget);
        expect(find.text('6.4g'), findsOneWidget);
        expect(find.text('1.0g'), findsOneWidget);
        expect(find.text('4mg'), findsOneWidget);

        // Log to diary and verify scaled sugar is persisted
        final logged = await controller.logToDiary(
          'test_uid_35_10_3',
          fakeNutritionRepo,
        );
        expect(logged, isTrue);
        expect(fakeNutritionRepo.loggedRecords.length, 1);
        expect(fakeNutritionRepo.loggedRecords.first.calories, closeTo(248.0, 0.01));
        expect(fakeNutritionRepo.loggedRecords.first.sugar, closeTo(1.0, 0.01));
      },
    );

    testWidgets(
      'Test 7 — Null nutrient handling: AI-estimated food with null fiber/sugar/sodium hides More nutrition and never invents 0g',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const pastaOovPrediction = LocalFoodPrediction(
          foodId: 'predefined_pineapple',
          foodName: 'Pineapple',
          confidence: 0.22,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_pineapple',
              foodName: 'Pineapple',
              confidence: 0.22,
            ),
          ],
          inferenceDurationMs: 18,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(pastaOovPrediction);
        final spyRemote = _SpyRemoteDataSource(
          nextResponse: const [
            RawDetectedFood(
              name: 'Truffle Lobster Risotto',
              confidence: 0.88,
              estimatedGrams: 240.0,
              unit: 'g',
              estimatedNutrition: EstimatedNutrition(
                calories: 440.0,
                protein: 19.0,
                carbs: 48.0,
                fat: 18.0,
              ),
            ),
          ],
        );
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Tap Analyze with AI -> returns AI-estimated "Truffle Lobster Risotto" (no matchedFood in catalog)
        await tester.tap(find.text('Analyze with AI'));
        await tester.pumpAndSettle();

        final result = (controller.state as FoodScanSuccess).result;
        final candidate = result.foods.first;
        expect(candidate.matchedFood, isNull);
        expect(candidate.isAiEstimated, isTrue);
        expect(candidate.fiber, isNull);
        expect(candidate.sugar, isNull);
        expect(candidate.sodium, isNull);
        expect(result.totalFiber, isNull);
        expect(result.totalSugar, isNull);
        expect(result.totalSodium, isNull);
        expect(result.hasMoreNutrition, isFalse);

        // UI hides "More nutrition" section and does NOT invent 0g for Fiber/Sugar/Sodium
        expect(find.text('More nutrition'), findsNothing);
        expect(find.text('Fiber'), findsNothing);
        expect(find.text('Sugar'), findsNothing);
        expect(find.text('Sodium'), findsNothing);
      },
    );

    testWidgets(
      'Test 8 — Offline flow: Local scan, OOV safety, and manual search / suggestion confirmation complete offline with cloudCalls == 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Coherent Indian breakfast neighborhood offline
        const idliDosaPrediction = LocalFoodPrediction(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.44,
          topCandidates: [
            LocalFoodCandidate(
              foodId: 'predefined_idli',
              foodName: 'Idli',
              confidence: 0.44,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_dosa',
              foodName: 'Plain Dosa',
              confidence: 0.31,
            ),
            LocalFoodCandidate(
              foodId: 'predefined_upma',
              foodName: 'Rava Upma',
              confidence: 0.16,
            ),
          ],
          inferenceDurationMs: 19,
          isModelAvailable: true,
        );

        final classifier = _StubClassifier(idliDosaPrediction);
        final spyRemote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: classifier,
          remoteDataSource: spyRemote,
          config: kDefaultFoodScanRouterConfig,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        );
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: _StubImagePickerService(),
        );

        await tester.pumpWidget(
          buildHarness(
            controller: controller,
            networkStatus: NetworkStatus.offline,
          ),
        );
        await tester.pumpAndSettle();

        await controller.scanImageBytes(
          imagePath: 'offline_idli.jpg',
          imageBytes: dummyBytes,
          catalog: fullCatalog,
          isOffline: true,
        );
        await tester.pumpAndSettle();

        // Coherent neighborhood passes reliability gate
        expect(
          router.lastSafetyLog,
          contains('reliableSuggestions=true reason=coherent_food_neighborhood'),
        );
        expect(find.text('Possible matches'), findsOneWidget);
        expect(find.text('Idli'), findsOneWidget);

        // Confirm Idli offline
        await tester.tap(find.byKey(const Key('suggestion_predefined_idli')));
        await tester.pumpAndSettle();

        expect(find.text('Confirmed by you'), findsOneWidget);
        expect(find.text('Low Confidence'), findsNothing);
        expect(find.text('More nutrition'), findsOneWidget);
        expect(spyRemote.analyzeCallCount, 0);
      },
    );
  });
}
