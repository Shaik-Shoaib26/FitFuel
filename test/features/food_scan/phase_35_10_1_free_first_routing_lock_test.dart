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
  String get uid => 'test-user-35-10-1';
  @override
  String get email => 'routinglock@fitfuel.app';
  @override
  String get displayName => 'Routing Lock Tester';
}

class _FakeImagePickerService implements IFoodImagePickerService {
  String? nextPath = '/tmp/scan_meal_35_10_1.jpg';
  Uint8List? nextBytes = Uint8List.fromList([11, 22, 33, 44, 55]);
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

  FoodScanRepositoryImpl createRepository({
    FoodScanRecognitionRouter? router,
  }) {
    return FoodScanRepositoryImpl(
      remoteDataSource: mockRemote,
      router: router ?? createRouter(),
    );
  }

  FoodScanController createController({
    FoodScanRecognitionRouter? router,
  }) {
    final repo = createRepository(router: router);
    return FoodScanController(
      repository: repo,
      imagePickerService: fakePicker,
    );
  }

  group('Phase 35.10.1 — Normal Scan Never Calls Gemini Automatically', () {
    test('Test 1 — Auto-local Samosa (0.91 conf, 0.87 margin): cloudCalls = 0, route = auto_local', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.91,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.04,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/samosa_auto.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      final success = controller.state as FoodScanSuccess;
      expect(success.result.recognitionSource, FoodScanRecognitionSource.localModel);
      expect(success.result.foods.single.matchedFood?.id, 'predefined_samosa');
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(router.geminiRequested, 0);
      expect(router.cloudCallsThisScan, 0);
      expect(router.debugAiLogs, isEmpty);
      expect(
        router.debugRouteLogs.single,
        allOf([
          contains('route=auto_local model=fitfuel_food_v5'),
          contains('top1=predefined_samosa'),
          contains('confidence=0.910 margin=0.870'),
          contains('cloud_calls=0'),
        ]),
      );

      final logged = await controller.logToDiary('user-1', fakeNutritionRepo);
      expect(logged, isTrue);
      expect(fakeNutritionRepo.loggedRecords.length, 1);
      expect(mockRemote.analyzeCallCount, 0);
    });

    test('Test 2 — Local Suggestion Samosa (0.68 conf): stops at Top-3 suggestions with cloudCalls = 0', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.68,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.19,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_dosa',
          foodName: 'Plain Dosa',
          confidence: 0.16,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/samosa_uncertain.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final suggestionsState = controller.state as FoodScanSuggestions;
      expect(suggestionsState.suggestions.length, 3);
      expect(suggestionsState.suggestions.first.foodId, 'predefined_samosa');
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(router.geminiRequested, 0);
      expect(router.cloudCallsThisScan, 0);
      expect(router.debugAiLogs, isEmpty);
      expect(
        router.debugRouteLogs.single,
        allOf([
          contains('route=local_suggestion model=fitfuel_food_v5'),
          contains('top1=predefined_samosa confidence=0.680'),
          contains('candidates=3 top3=predefined_samosa:0.68,predefined_medu_vada:0.19,predefined_dosa:0.16 cloud_calls=0'),
        ]),
      );

      // User confirms suggestion -> logs to diary with 0 Gemini calls
      controller.confirmSuggestion(suggestionsState.suggestions.first, catalog: catalog);
      expect(controller.state, isA<FoodScanSuccess>());
      final logged = await controller.logToDiary('user-1', fakeNutritionRepo);
      expect(logged, isTrue);
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
    });

    test('Test 3 — Unknown Food (Biryani, max conf < 0.15): stops at manual search + optional AI, cloudCalls = 0', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_steamed_rice',
          foodName: 'Steamed White Rice',
          confidence: 0.11,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_poha',
          foodName: 'Poha',
          confidence: 0.08,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/biryani.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final state = controller.state as FoodScanSuggestions;
      expect(state.suggestions, isEmpty);
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(
        router.debugRouteLogs.single,
        allOf([
          contains('route=no_reliable_local_match model=fitfuel_food_v5'),
          contains('top1=predefined_steamed_rice confidence=0.110'),
          contains('candidates=0'),
          contains('cloud_calls=0'),
        ]),
      );

      // User selects Chicken Biryani manually from the 238-food catalog
      final biryani = catalog.firstWhere((f) => f.id == 'predefined_chicken_biryani');
      controller.selectManualFood(biryani);
      expect(controller.state, isA<FoodScanSuccess>());

      final logged = await controller.logToDiary('user-1', fakeNutritionRepo);
      expect(logged, isTrue);
      expect(mockRemote.analyzeCallCount, 0);
    });

    test('Test 4 — Mixed Meal (Thali): stops at mixed-meal decision with cloudCalls = 0', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(
        const [
          LocalFoodCandidate(
            foodId: 'predefined_dal_tadka',
            foodName: 'Dal Tadka',
            confidence: 0.52,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_chapati',
            foodName: 'Chapati / Roti',
            confidence: 0.44,
          ),
        ],
        isMixedMealSuspected: true,
      );

      await controller.scanImageBytes(
        imagePath: '/tmp/thali.jpg',
        imageBytes: testBytes,
        catalog: catalog,
        isMixedMealSuspected: true,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final state = controller.state as FoodScanSuggestions;
      expect(state.isMixedMealSuspected, isTrue);
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(
        router.debugRouteLogs.single,
        allOf([
          contains('route=mixed_manual model=fitfuel_food_v5'),
          contains('candidates=2'),
          contains('cloud_calls=0'),
        ]),
      );

      // User adds multiple components manually (Dal + Chapati) and logs to diary with 0 cloud calls
      final dal = catalog.firstWhere((f) => f.id == 'predefined_dal_tadka');
      final chapati = catalog.firstWhere((f) => f.id == 'predefined_chapati');
      controller.addComponent(dal);
      controller.addComponent(chapati);
      expect(controller.state, isA<FoodScanSuccess>());
      expect((controller.state as FoodScanSuccess).result.foods.length, 2);

      final logged = await controller.logToDiary('user-1', fakeNutritionRepo);
      expect(logged, isTrue);
      expect(fakeNutritionRepo.loggedRecords.length, 2);
      expect(mockRemote.analyzeCallCount, 0);
    });

    test('Test 5 — Non-Food Image (Laptop): stops at low-confidence suggestions/manual view, cloudCalls = 0', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_whole_wheat_bread',
          foodName: 'Whole Wheat Bread',
          confidence: 0.05,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/laptop.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final state = controller.state as FoodScanSuggestions;
      expect(state.suggestions, isEmpty);
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(fakeNutritionRepo.loggedRecords, isEmpty);
    });

    test('Test 6 — Local Model Unavailable / Failure: does NOT automatically call Gemini (cloudCalls = 0)', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setModelUnavailable();

      await controller.scanImageBytes(
        imagePath: '/tmp/model_unavailable.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuggestions>());
      final state = controller.state as FoodScanSuggestions;
      expect(state.isLocalModelUnavailable, isTrue);
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(router.geminiRequested, 0);
      expect(
        router.debugRouteLogs.single,
        allOf([
          contains('route=no_local_match model=none'),
          contains('cloud_calls=0'),
        ]),
      );
    });

    test('Test 7 — Offline Mode (Samosa auto-local, Banana suggestion, Biryani manual): 0 network calls, all log to diary', () async {
      final router = createRouter();
      final controller = createController(router: router);

      // 7a. Samosa auto-local offline
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.93,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.03,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/offline_samosa.jpg',
        imageBytes: testBytes,
        catalog: catalog,
        isOffline: true,
      );
      expect(controller.state, isA<FoodScanSuccess>());
      expect(await controller.logToDiary('user-1', fakeNutritionRepo), isTrue);

      // 7b. Banana suggestion offline
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_banana',
          foodName: 'Banana',
          confidence: 0.64,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_mango',
          foodName: 'Mango',
          confidence: 0.21,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/offline_banana.jpg',
        imageBytes: testBytes,
        catalog: catalog,
        isOffline: true,
      );
      expect(controller.state, isA<FoodScanSuggestions>());
      final bananaSuggestions = (controller.state as FoodScanSuggestions).suggestions;
      controller.confirmSuggestion(bananaSuggestions.first, catalog: catalog);
      expect(controller.state, isA<FoodScanSuccess>());
      expect(await controller.logToDiary('user-1', fakeNutritionRepo), isTrue);

      // 7c. Biryani manual offline
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_steamed_rice',
          foodName: 'Steamed White Rice',
          confidence: 0.10,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/offline_biryani.jpg',
        imageBytes: testBytes,
        catalog: catalog,
        isOffline: true,
      );
      expect(controller.state, isA<FoodScanSuggestions>());
      final biryani = catalog.firstWhere((f) => f.id == 'predefined_chicken_biryani');
      controller.selectManualFood(biryani);
      expect(controller.state, isA<FoodScanSuccess>());
      expect(await controller.logToDiary('user-1', fakeNutritionRepo), isTrue);

      expect(mockRemote.analyzeCallCount, 0);
      expect(fakeNutritionRepo.loggedRecords.length, 3);
    });
  });

  group('Phase 35.10.1 — Explicit AI Button, Retry Lock & Error Recovery', () {
    test('Test 8 — Explicit "Analyze with AI" button calls Gemini with userRequested=true and cloudCalls=1', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.55,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/idli.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );

      // Before tapping "Analyze with AI": 0 cloud calls
      expect(mockRemote.analyzeCallCount, 0);
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);

      mockRemote.mockRawFoods = const [
        RawDetectedFood(
          name: 'Idli',
          estimatedGrams: 120,
          confidence: 0.90,
          estimatedNutrition: EstimatedNutrition(
            calories: 156,
            protein: 5.0,
            carbs: 32.0,
            fat: 0.8,
          ),
        ),
      ];

      // User explicitly taps "Analyze with AI"
      await controller.analyzeWithAi(catalog: catalog, isOffline: false);

      expect(mockRemote.analyzeCallCount, 1);
      expect(controller.cloudCallsThisScan, 1);
      expect(controller.userRequestedAi, isTrue);
      expect(controller.state, isA<FoodScanSuccess>());
      expect(
        router.debugAiLogs.single,
        contains('userRequested=true model=gemini-3.8-flash fallbackModel=gemini-3.5-flash attempt=1'),
      );
      expect(
        router.debugRouteLogs.last,
        contains('route=gemini reason=user_requested_ai cloud_calls=1'),
      );
    });

    test('Test 9 — Generic retryScan() NEVER calls Gemini even after an AI failure; only retryAi() calls Gemini', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.58,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/idli_retry.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      expect(mockRemote.analyzeCallCount, 0);

      // Explicit AI call fails with 503 serviceUnavailable
      mockRemote.exceptionToThrow = FoodScanException(
        type: FoodScanFailureType.serviceUnavailable,
        message: 'Gemini temporarily unavailable',
        statusCode: 503,
      );
      await controller.analyzeWithAi(catalog: catalog, isOffline: false);
      expect(mockRemote.analyzeCallCount, 1);
      expect(controller.state, isA<FoodScanSuggestions>());
      expect((controller.state as FoodScanSuggestions).hasAiFailure, isTrue);

      // Now call generic retryScan() — must re-run local free-first scan and NOT call Gemini!
      await controller.retryScan();
      expect(mockRemote.analyzeCallCount, 1); // unchanged!
      expect(controller.cloudCallsThisScan, 0);
      expect(controller.userRequestedAi, isFalse);
      expect(controller.state, isA<FoodScanSuggestions>());
      expect((controller.state as FoodScanSuggestions).hasAiFailure, isFalse);

      // Now call explicit retryAi() — must call Gemini
      mockRemote.exceptionToThrow = null;
      mockRemote.mockRawFoods = const [
        RawDetectedFood(
          name: 'Idli',
          estimatedGrams: 120,
          confidence: 0.91,
        ),
      ];
      await controller.retryAi(catalog: catalog, isOffline: false);
      expect(mockRemote.analyzeCallCount, 2);
      expect(controller.cloudCallsThisScan, 1);
      expect(controller.userRequestedAi, isTrue);
      expect(controller.state, isA<FoodScanSuccess>());
    });

    test('Test 10 — Quota Exhausted (429) & 503/Timeout After Explicit AI return to free-first suggestions UI', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.62,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_dosa',
          foodName: 'Plain Dosa',
          confidence: 0.24,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/paneer.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      expect(mockRemote.analyzeCallCount, 0);

      // Simulate 429 daily quota exhausted on explicit AI tap
      mockRemote.exceptionToThrow = FoodScanException(
        type: FoodScanFailureType.dailyQuotaReached,
        message: 'Daily quota exhausted',
        statusCode: 429,
      );

      await controller.analyzeWithAi(catalog: catalog, isOffline: false);
      expect(mockRemote.analyzeCallCount, 1);
      expect(controller.state, isA<FoodScanSuggestions>());

      final stateAfterQuota = controller.state as FoodScanSuggestions;
      expect(stateAfterQuota.isQuotaExhausted, isTrue);
      expect(stateAfterQuota.imagePath, '/tmp/paneer.jpg');
      expect(stateAfterQuota.suggestions.length, 2);
      expect(stateAfterQuota.suggestions.first.foodId, 'predefined_idli');

      // User can still confirm the retained local suggestion and log to diary with 0 additional cloud calls
      controller.confirmSuggestion(stateAfterQuota.suggestions.first, catalog: catalog);
      expect(controller.state, isA<FoodScanSuccess>());
      expect(await controller.logToDiary('user-1', fakeNutritionRepo), isTrue);
      expect(mockRemote.analyzeCallCount, 1);
    });
  });

  group('Phase 35.10.1 — Guard Against Accidental Cloud Invocation & Telemetry Integrity', () {
    test('Test 11 — Legacy repository.scanFoodImage(...) is locked to free-first local routing and never calls Gemini', () async {
      final router = createRouter();
      final repo = createRepository(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_poha',
          foodName: 'Poha',
          confidence: 0.51,
        ),
      ]);

      final result = await repo.scanFoodImage(
        imagePath: '/tmp/legacy_poha.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
      );

      // Even when called through legacy scanFoodImage, cloud calls must be 0
      expect(mockRemote.analyzeCallCount, 0);
      expect(router.geminiRequested, 0);
      expect(result.foods, isEmpty);
      expect(result.localCandidates.first.foodId, 'predefined_poha');
    });

    test('Test 12 — Router emits ASSERT warning if analyzeWithCloud is called with userRequestedAi=false', () async {
      final router = createRouter();
      mockRemote.mockRawFoods = const [
        RawDetectedFood(
          name: 'Dosa',
          estimatedGrams: 120,
          confidence: 0.88,
        ),
      ];

      await router.analyzeWithCloud(
        requestId: 'req_unrequested_cloud',
        imagePath: '/tmp/unrequested_cloud.jpg',
        imageBytes: testBytes,
        foodCatalog: catalog,
        userRequestedAi: false,
      );

      expect(
        router.debugAssertionWarnings.single,
        contains('ASSERT: Automatic Gemini invocation is forbidden in free-first mode'),
      );
      expect(
        router.debugAiLogs.last,
        contains('userRequested=false'),
      );
    });

    test('Test 13 — User confirmation cancels/ignores stale in-flight cloud response', () async {
      final router = createRouter();
      final controller = createController(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_dosa',
          foodName: 'Masala Dosa',
          confidence: 0.72,
        ),
      ]);

      await controller.scanImageBytes(
        imagePath: '/tmp/dosa_race.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      final suggestion = (controller.state as FoodScanSuggestions).suggestions.first;

      // Start an explicit AI call that hangs on a Completer
      final cloudCompleter = Completer<List<RawDetectedFood>>();
      mockRemote.completer = cloudCompleter;
      final aiFuture = controller.analyzeWithAi(catalog: catalog, isOffline: false);

      // Before cloud completes, user confirms the local suggestion
      controller.confirmSuggestion(suggestion, catalog: catalog);
      expect(controller.state, isA<FoodScanSuccess>());
      expect(
        (controller.state as FoodScanSuccess).result.foods.single.matchedFood?.id,
        'predefined_dosa',
      );

      // Now complete the stale cloud response with a different food
      cloudCompleter.complete(const [
        RawDetectedFood(
          name: 'Pizza',
          estimatedGrams: 250,
          confidence: 0.95,
        ),
      ]);
      await aiFuture;

      // State must still be the user's confirmed Masala Dosa, NOT overwritten by stale cloud response
      expect(controller.state, isA<FoodScanSuccess>());
      expect(
        (controller.state as FoodScanSuccess).result.foods.single.matchedFood?.id,
        'predefined_dosa',
      );
    });

    test('Test 14 — Completion Telemetry: one completion route per scan, no double counting', () async {
      final router = createRouter();
      final controller = createController(router: router);

      // Scan 1: Auto-local Samosa
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.92,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.04,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/scan1.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      expect(router.autoLocalCompleted, 1);
      expect(router.totalCompletedScans, 1);

      // Scan 2: Suggestion confirmed first, then user changes mind to manual food on the same scan
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.65,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/scan2.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      final idliSuggestion = (controller.state as FoodScanSuggestions).suggestions.first;
      controller.confirmSuggestion(idliSuggestion, catalog: catalog);
      // Confirming a second time on same scan must not double count
      controller.confirmSuggestion(idliSuggestion, catalog: catalog);
      expect(router.suggestionConfirmedCompleted, 1);
      expect(router.totalCompletedScans, 2);

      // Switching the same scan (scan_2) to a manual food updates scan_2's route from suggestionConfirmed -> manualConfirmed
      final dosa = catalog.firstWhere((f) => f.id == 'predefined_dosa');
      controller.selectManualFood(dosa);
      expect(router.suggestionConfirmedCompleted, 0);
      expect(router.manualConfirmedCompleted, 1);
      expect(router.freeCompletedScans, 2);
      expect(router.totalCompletedScans, 2);
      expect(router.freeCompletionRate, 1.0);

      // Scan 3: Explicit Gemini completion
      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_poha',
          foodName: 'Poha',
          confidence: 0.45,
        ),
      ]);
      await controller.scanImageBytes(
        imagePath: '/tmp/scan3.jpg',
        imageBytes: testBytes,
        catalog: catalog,
      );
      mockRemote.mockRawFoods = const [
        RawDetectedFood(
          name: 'Poha',
          estimatedGrams: 150,
          confidence: 0.89,
        ),
      ];
      await controller.analyzeWithAi(catalog: catalog, isOffline: false);

      expect(router.autoLocalCompleted, 1);
      expect(router.suggestionConfirmedCompleted, 0);
      expect(router.manualConfirmedCompleted, 1);
      expect(router.geminiCompleted, 1);
      expect(router.freeCompletedScans, 2);
      expect(router.totalCompletedScans, 3);
      expect(router.freeCompletionRate, closeTo(2 / 3, 1e-6));
    });

    testWidgets('Test 15 — Widget UI: Normal scan shows suggestions + Search Foods + Analyze with AI with 0 cloud calls', (tester) async {
      final router = createRouter();
      final repo = createRepository(router: router);

      fakeClassifier.setTopKSuggestions(const [
        LocalFoodCandidate(
          foodId: 'predefined_idli',
          foodName: 'Idli',
          confidence: 0.64,
        ),
        LocalFoodCandidate(
          foodId: 'predefined_medu_vada',
          foodName: 'Medu Vada',
          confidence: 0.22,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith((_) => Stream.value(_FakeUser())),
            networkStatusProvider.overrideWith(
              (_) => Stream.value(NetworkStatus.online),
            ),
            foodImagePickerServiceProvider.overrideWithValue(fakePicker),
            foodVisionClassifierProvider.overrideWithValue(fakeClassifier),
            foodScanRemoteDatasourceProvider.overrideWithValue(mockRemote),
            foodScanRouterConfigProvider.overrideWithValue(router.config),
            foodScanRecognitionRouterProvider.overrideWithValue(router),
            foodScanRepositoryProvider.overrideWithValue(repo),
            nutritionRepositoryProvider.overrideWithValue(fakeNutritionRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FoodScanScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Take Photo button
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Verify Free-First Suggestions UI is shown and 0 Gemini calls occurred
      expect(find.text('Search Foods'), findsOneWidget);
      expect(find.text('Analyze with AI'), findsOneWidget);
      expect(find.text('Try Another Photo'), findsOneWidget);
      expect(mockRemote.analyzeCallCount, 0);
    });
  });
}
