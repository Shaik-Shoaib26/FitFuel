import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/fake_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_telemetry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-user-35-10-2';
  @override
  String get email => 'freescanui@fitfuel.app';
  @override
  String get displayName => 'Free Scan UI Tester';
}

class _FakeImagePickerService implements IFoodImagePickerService {
  String? nextPath = '/tmp/scan_meal_35_10_2.jpg';
  Uint8List? nextBytes = Uint8List.fromList([11, 22, 33, 44, 55]);
  int cameraPickCount = 0;
  int galleryPickCount = 0;

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    if (source == FoodImagePickSource.camera) {
      cameraPickCount++;
    } else {
      galleryPickCount++;
    }
    return nextPath;
  }

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async => nextBytes;
}

class _DelayedClassifier implements FoodVisionClassifier {
  final Completer<LocalFoodPrediction> completer =
      Completer<LocalFoodPrediction>();
  int classifyCallCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) {
    classifyCallCount++;
    return completer.future;
  }

  @override
  void dispose() {}
}

class _MockRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;
  List<RawDetectedFood> mockRawFoods = [];
  Exception? exceptionToThrow;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
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
  final List<FoodScanTelemetryEvent> telemetryEvents = [];

  setUp(() {
    fakeClassifier = FakeFoodVisionClassifier();
    mockRemote = _MockRemoteDataSource();
    fakePicker = _FakeImagePickerService();
    fakeNutritionRepo = _FakeNutritionRepository();
    telemetryEvents.clear();
  });

  FoodScanRecognitionRouter createRouter({
    FoodVisionClassifier? classifier,
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
  }) {
    return FoodScanRecognitionRouter(
      localClassifier: classifier ?? fakeClassifier,
      remoteDataSource: mockRemote,
      config: config,
      telemetrySink: telemetryEvents.add,
    );
  }

  Widget buildTestApp({
    required FoodScanRecognitionRouter router,
    bool isOffline = false,
  }) {
    final repo = FoodScanRepositoryImpl(
      remoteDataSource: mockRemote,
      router: router,
    );
    return ProviderScope(
      overrides: [
        foodScanRepositoryProvider.overrideWithValue(repo),
        foodImagePickerServiceProvider.overrideWithValue(fakePicker),
        foodScanControllerProvider.overrideWith(
          (ref) => FoodScanController(
            repository: repo,
            imagePickerService: fakePicker,
          ),
        ),
        authStateStreamProvider.overrideWith(
          (ref) => Stream.value(_FakeUser()),
        ),
        networkStatusProvider.overrideWith(
          (ref) => Stream.value(
            isOffline ? NetworkStatus.offline : NetworkStatus.online,
          ),
        ),
        nutritionRepositoryProvider.overrideWithValue(fakeNutritionRepo),
      ],
      child: const MaterialApp(
        home: FoodScanScreen(),
      ),
    );
  }

  group('Phase 35.10.2 — Free Scan UI & Local Suggestion Visibility Fix', () {
    testWidgets(
      '1. Main screen copy shows Scan Your Food, on-device first description, Free • On-device label, and updated Privacy Notice',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        // Main screen hero copy
        expect(find.text('Scan Your Food'), findsOneWidget);
        expect(find.text('Scan Your Meal'), findsNothing);
        expect(
          find.text(
            'Take a photo and FitFuel will scan it on your device first.\nNo internet or AI quota is required for local scanning.',
          ),
          findsOneWidget,
        );

        // Free • On-device label
        expect(find.text('Free • On-device'), findsOneWidget);

        // Primary buttons
        expect(find.text('Take Photo'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsOneWidget);

        // Updated Privacy Notice
        expect(find.text('Privacy & Estimation Notice'), findsOneWidget);
        expect(
          find.text(
            'Food photos are analyzed on your device first. Your photo is only sent to the online AI service if you choose \'Analyze with AI\'. Nutrition values come from FitFuel\'s food database.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Take Photo button starts local model, shows "Scanning on your device...", and does NOT start Gemini',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final delayedClassifier = _DelayedClassifier();
        final router = createRouter(classifier: delayedClassifier);

        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pump();

        // Temporary analyzing status must say "Scanning on your device..."
        expect(find.text('Scanning on your device...'), findsOneWidget);
        expect(delayedClassifier.classifyCallCount, 1);
        expect(fakePicker.cameraPickCount, 1);
        expect(mockRemote.analyzeCallCount, 0);

        // Complete local prediction with auto-local Samosa (0.978 conf)
        delayedClassifier.completer.complete(
          const LocalFoodPrediction(
            foodId: 'predefined_samosa',
            foodName: 'Samosa',
            confidence: 0.978,
            topCandidates: [
              LocalFoodCandidate(
                foodId: 'predefined_samosa',
                foodName: 'Samosa',
                confidence: 0.978,
              ),
              LocalFoodCandidate(
                foodId: 'predefined_pineapple',
                foodName: 'Pineapple',
                confidence: 0.009,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Auto-local success badge "Recognized on your device"
        expect(find.text('Recognized on your device'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);
        expect(mockRemote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);
        expect(
          router.debugRouteLogs.single,
          allOf([
            contains('route=auto_local model=fitfuel_food_v5'),
            contains('top1=predefined_samosa'),
            contains('confidence=0.978 margin=0.969'),
            contains('cloud_calls=0'),
          ]),
        );
      },
    );

    testWidgets(
      '3. Choose from Gallery button starts local model and does NOT start Gemini',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
        fakeClassifier.setTopKSuggestions(const [
          LocalFoodCandidate(
            foodId: 'predefined_samosa',
            foodName: 'Samosa',
            confidence: 0.94,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_medu_vada',
            foodName: 'Medu Vada',
            confidence: 0.03,
          ),
        ]);

        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        expect(fakePicker.galleryPickCount, 1);
        expect(mockRemote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);
        expect(find.text('Recognized on your device'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Local Top-3 suggestions are visible with Possible matches, candidate buttons, Not here?, Search Foods, Analyze with AI, and Try Another Photo',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
        fakeClassifier.setTopKSuggestions(const [
          LocalFoodCandidate(
            foodId: 'predefined_samosa',
            foodName: 'Samosa',
            confidence: 0.72,
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

        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(mockRemote.analyzeCallCount, 0);
        expect(find.text('Possible matches'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);
        expect(find.text('Medu Vada'), findsOneWidget);
        expect(find.text('Plain Dosa'), findsOneWidget);
        expect(find.text('Not here?'), findsOneWidget);
        expect(find.text('Search Foods'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsOneWidget);
        expect(find.text('Try Another Photo'), findsOneWidget);
        expect(find.text('No reliable local match found'), findsNothing);

        // Confirming Samosa completes food log with 0 Gemini calls
        await tester.tap(find.text('Samosa'));
        await tester.pumpAndSettle();

        expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);
        expect(find.text('Add to Food Diary'), findsOneWidget);
        expect(mockRemote.analyzeCallCount, 0);
      },
    );

    testWidgets(
      '5. No-candidate state (< 0.15) shows "No reliable local match found" and does NOT show "Choose the closest food."',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
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

        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(mockRemote.analyzeCallCount, 0);
        expect(find.text('No reliable local match found'), findsOneWidget);
        expect(find.text('Choose the closest food.'), findsNothing);
        expect(find.text('Possible matches'), findsNothing);
        expect(find.text('Search Foods'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsOneWidget);
        expect(find.text('Try Another Photo'), findsOneWidget);
        expect(
          router.debugRouteLogs.single,
          allOf([
            contains('route=no_reliable_local_match model=fitfuel_food_v5'),
            contains('top1=predefined_steamed_rice confidence=0.110'),
            contains('candidates=0'),
            contains('cloud_calls=0'),
          ]),
        );
      },
    );

    testWidgets(
      '6. Analyze with AI button requires explicit tap and logs route=gemini reason=user_requested_ai',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
        fakeClassifier.setTopKSuggestions(const [
          LocalFoodCandidate(
            foodId: 'predefined_idli',
            foodName: 'Idli',
            confidence: 0.54,
          ),
        ]);
        mockRemote.mockRawFoods = const [
          RawDetectedFood(
            name: 'Plain Dosa',
            estimatedGrams: 120,
            confidence: 0.91,
          ),
        ];

        await tester.pumpWidget(buildTestApp(router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Before tapping Analyze with AI: 0 cloud calls
        expect(mockRemote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);

        // Explicit tap on Analyze with AI
        await tester.ensureVisible(find.text('Analyze with AI'));
        await tester.tap(find.text('Analyze with AI'));
        await tester.pumpAndSettle();

        expect(mockRemote.analyzeCallCount, 1);
        expect(router.cloudCallsThisScan, 1);
        expect(
          router.debugRouteLogs.last,
          contains('route=gemini reason=user_requested_ai cloud_calls=1'),
        );
        expect(find.text('Plain Dosa'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Offline local scan works end-to-end with 0 cloud calls',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createRouter();
        fakeClassifier.setTopKSuggestions(const [
          LocalFoodCandidate(
            foodId: 'predefined_samosa',
            foodName: 'Samosa',
            confidence: 0.96,
          ),
          LocalFoodCandidate(
            foodId: 'predefined_medu_vada',
            foodName: 'Medu Vada',
            confidence: 0.02,
          ),
        ]);

        await tester.pumpWidget(buildTestApp(router: router, isOffline: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(mockRemote.analyzeCallCount, 0);
        expect(find.text('Recognized on your device'), findsOneWidget);
        expect(find.text('Samosa'), findsOneWidget);

        await tester.ensureVisible(find.text('Add to Food Diary'));
        await tester.tap(find.text('Add to Food Diary'));
        await tester.pumpAndSettle();

        expect(fakeNutritionRepo.loggedRecords.length, 1);
        expect(mockRemote.analyzeCallCount, 0);
      },
    );
  });
}
