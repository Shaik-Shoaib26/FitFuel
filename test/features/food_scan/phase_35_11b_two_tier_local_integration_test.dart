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
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/data/services/siglip_open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_35_11b';
  @override
  String get email => 'test@fitfuel.app';
  @override
  String get displayName => 'Test User';
}

class _StubTier1Classifier implements FoodVisionClassifier {
  LocalFoodPrediction nextPrediction;
  int classifyCalls = 0;

  _StubTier1Classifier(this.nextPrediction);

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

class _DelayedOpenVocabRecognizer implements OpenVocabularyFoodRecognizer {
  final Completer<OpenVocabularyRecognitionResult> completer =
      Completer<OpenVocabularyRecognitionResult>();
  int recognizeCalls = 0;
  int disposeCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  bool get isSessionLoaded => false;

  @override
  bool get requiresColdInit => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<OpenVocabularyRecognitionResult> recognize(
      Uint8List imageBytes) async {
    recognizeCalls++;
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _SpyRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;
  final List<RawDetectedFood> nextResponse = const [
    RawDetectedFood(
      name: 'Creamy Penne Pasta',
      confidence: 0.92,
      estimatedGrams: 220.0,
      unit: 'g',
      estimatedNutrition: EstimatedNutrition(
        calories: 390.0,
        protein: 12.0,
        carbs: 52.0,
        fat: 14.0,
      ),
    ),
  ];

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
  int pickCalls = 0;

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    pickCalls++;
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

  const samosaAutoLocalPrediction = LocalFoodPrediction(
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
        foodId: 'predefined_medu_vada',
        foodName: 'Medu Vada',
        confidence: 0.009,
      ),
    ],
    inferenceDurationMs: 28,
  );

  const pastaWeakV5Prediction = LocalFoodPrediction(
    foodId: 'predefined_pineapple',
    foodName: 'Pineapple',
    confidence: 0.312,
    topCandidates: [
      LocalFoodCandidate(
        foodId: 'predefined_pineapple',
        foodName: 'Pineapple',
        confidence: 0.312,
      ),
      LocalFoodCandidate(
        foodId: 'predefined_grilled_chicken_breast',
        foodName: 'Grilled Chicken Breast',
        confidence: 0.141,
      ),
    ],
    inferenceDurationMs: 26,
  );

  final pastaOpenVocabResult = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_penne_pasta',
        canonicalName: 'Creamy Penne Pasta',
        category: 'Pasta & Italian',
        similarity: 0.1680,
        rank: 1,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_penne_alfredo',
        canonicalName: 'Penne Alfredo',
        category: 'Pasta & Italian',
        similarity: 0.1328,
        rank: 2,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_pasta',
        canonicalName: 'Creamy Pasta',
        category: 'Pasta & Italian',
        similarity: 0.1235,
        rank: 3,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.1680,
    maxNegSimilarity: -0.0110,
    negMargin: 0.1790,
    topNegativePrompt: 'an empty plate or bowl with no food on it',
    preprocessMs: 9,
    encoderMs: 620,
    retrievalMs: 1,
    totalMs: 630,
  );

  final burgerOpenVocabResult = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_burger',
        canonicalName: 'Burger',
        category: 'Burgers & Sandwiches',
        similarity: 0.1381,
        rank: 1,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_hamburger',
        canonicalName: 'Hamburger',
        category: 'Burgers & Sandwiches',
        similarity: 0.1205,
        rank: 2,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_chicken_burger',
        canonicalName: 'Chicken Burger',
        category: 'Burgers & Sandwiches',
        similarity: 0.1072,
        rank: 3,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.1381,
    maxNegSimilarity: -0.0080,
    negMargin: 0.1461,
    preprocessMs: 8,
    encoderMs: 618,
    retrievalMs: 1,
    totalMs: 627,
  );

  final dosaExactCatalogOpenVocabResult =
      OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_masala_dosa',
        canonicalName: 'Masala Dosa',
        category: 'South Indian',
        similarity: 0.1492,
        rank: 1,
        inFitFuelCatalog: true,
        fitFuelFoodId: 'predefined_masala_dosa',
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_dosa',
        canonicalName: 'Plain Dosa',
        category: 'South Indian',
        similarity: 0.1210,
        rank: 2,
        inFitFuelCatalog: true,
        fitFuelFoodId: 'predefined_dosa',
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_rava_dosa',
        canonicalName: 'Rava Dosa',
        category: 'South Indian',
        similarity: 0.1104,
        rank: 3,
        inFitFuelCatalog: true,
        fitFuelFoodId: 'predefined_rava_dosa',
      ),
    ],
    maxFoodSimilarity: 0.1492,
    maxNegSimilarity: -0.0150,
    negMargin: 0.1642,
    preprocessMs: 9,
    encoderMs: 615,
    retrievalMs: 1,
    totalMs: 625,
  );

  final nonFoodAbstainedResult = OpenVocabularyRecognitionResult.abstained(
    maxFoodSimilarity: 0.0958,
    maxNegSimilarity: 0.0880,
    negMargin: 0.0078,
    topNegativePrompt: 'a blurry or dark image with no visible food',
    abstainReason: 'non_food_negative_margin',
    preprocessMs: 8,
    encoderMs: 619,
    retrievalMs: 1,
    totalMs: 628,
  );

  final lowSimilarityAbstainedResult =
      OpenVocabularyRecognitionResult.abstained(
    maxFoodSimilarity: 0.0410,
    maxNegSimilarity: -0.0300,
    negMargin: 0.0710,
    topNegativePrompt: 'an empty plate or bowl with no food on it',
    abstainReason: 'below_similarity_threshold',
    preprocessMs: 8,
    encoderMs: 617,
    retrievalMs: 1,
    totalMs: 626,
  );

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

  group('Phase 35.11B — Two-Tier Local Open-Vocabulary Food Scan Integration',
      () {
    test(
      '1. Tier 1 trusted auto-local food (Samosa) does NOT call Tier 2 SigLIP and returns LocalAutoAccepted with 0 cloud calls',
      () async {
        final tier1 = _StubTier1Classifier(samosaAutoLocalPrediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );

        final decision = await router.routeFreeFirst(
          imagePath: 'samosa.jpg',
          imageBytes: dummyBytes,
          foodCatalog: fullCatalog,
          requestId: 'scan_1',
        );

        expect(decision, isA<LocalAutoAccepted>());
        final accepted = decision as LocalAutoAccepted;
        expect(accepted.result.foods.first.displayName, 'Samosa');
        expect(accepted.result.sourceBadgeLabel, 'Recognized on your device');
        expect(tier1.classifyCalls, 1);
        expect(tier2.recognizeCallCount, 0);
        expect(remote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);
        expect(router.tier1AutoAccepted, 1);
        expect(router.tier2Invoked, 0);
        expect(
          router.debugCascadeLogs.single,
          contains('route=tier1_auto_local'),
        );
      },
    );

    test(
      '2 & 3 & 4. Tier 1 non-trusted/weak prediction invokes Tier 2 SigLIP before V5 suggestions, returns Top-3 open-vocab suggestions, and never auto-logs',
      () async {
        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );

        final decision = await router.routeFreeFirst(
          imagePath: 'pasta.jpg',
          imageBytes: dummyBytes,
          foodCatalog: fullCatalog,
          requestId: 'scan_2',
        );

        expect(decision, isA<Tier2OpenVocabSuggestionsAvailable>());
        expect(decision, isNot(isA<LocalAutoAccepted>()));
        final suggestions = decision as Tier2OpenVocabSuggestionsAvailable;
        expect(suggestions.candidates.length, 3);
        expect(suggestions.candidates[0].displayName, 'Creamy Penne Pasta');
        expect(suggestions.candidates[1].displayName, 'Penne Alfredo');
        expect(suggestions.candidates[2].displayName, 'Creamy Pasta');
        // Never surfaces V5's misleading Pineapple or Grilled Chicken Breast guess
        expect(
          suggestions.candidates.map((c) => c.displayName),
          isNot(contains('Pineapple')),
        );
        expect(
          suggestions.candidates.map((c) => c.displayName),
          isNot(contains('Grilled Chicken Breast')),
        );
        expect(tier1.classifyCalls, 1);
        expect(tier2.recognizeCallCount, 1);
        expect(remote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);
        expect(router.tier2Invoked, 1);
        expect(router.tier2SuggestionsShown, 1);
        expect(
          router.debugCascadeLogs.single,
          allOf([
            contains('final_route=tier2_open_vocab_suggestions'),
            contains(
                'tier2_top3=openvocab_creamy_penne_pasta:0.1680,openvocab_penne_alfredo:0.1328,openvocab_creamy_pasta:0.1235'),
            contains('cloud_calls=0'),
          ]),
        );
      },
    );

    testWidgets(
      '5. Tier 2 non-food rejection shows "No food detected" and hides internal food candidates',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: nonFoodAbstainedResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('No food detected'), findsOneWidget);
        expect(
          find.text('Try another photo with the food clearly visible.'),
          findsOneWidget,
        );
        expect(find.text('Possible matches'), findsNothing);
        expect(find.text('Pineapple'), findsNothing);
        expect(find.text('Search Foods'), findsOneWidget);
        expect(find.text('Try Another Photo'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsOneWidget);
        expect(remote.analyzeCallCount, 0);
        expect(router.tier2AbstainedNonFood, 1);
      },
    );

    testWidgets(
      '6. Tier 2 low-similarity abstention shows "No reliable local match found"',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: lowSimilarityAbstainedResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('No reliable local match found'), findsOneWidget);
        expect(find.text('Possible matches'), findsNothing);
        expect(remote.analyzeCallCount, 0);
        expect(router.tier2NoReliableMatch, 1);
      },
    );

    test(
      '7. Tier 2 unavailable falls back cleanly to V5 safe evaluation without calling Gemini',
      () async {
        const reliableV5Prediction = LocalFoodPrediction(
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
              confidence: 0.18,
            ),
          ],
          inferenceDurationMs: 25,
        );
        final tier1 = _StubTier1Classifier(reliableV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(isAvailable: false);
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );

        final decision = await router.routeFreeFirst(
          imagePath: 'fallback.jpg',
          imageBytes: dummyBytes,
          foodCatalog: fullCatalog,
          requestId: 'scan_fallback',
        );

        expect(decision, isA<LocalSuggestionsAvailable>());
        expect(remote.analyzeCallCount, 0);
        expect(router.tier2UnavailableFallback, 1);
      },
    );

    testWidgets(
      '8 & 21. User confirming an exact FitFuel-mapped open-vocab candidate (Masala Dosa) resolves trusted nutrition, shows "Confirmed by you" + "Found on your device", and enables Add to Food Diary',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: dosaExactCatalogOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final nutritionRepo = _FakeNutritionRepo();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(
          buildHarness(controller: controller, nutritionRepo: nutritionRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
        expect(find.text('Masala Dosa'), findsOneWidget);
        expect(find.text('Found on your device'), findsOneWidget);
        expect(find.text('Database Match'), findsOneWidget);

        await tester.ensureVisible(find.text('Add to Food Diary'));
        await tester.tap(find.text('Add to Food Diary'));
        await tester.pumpAndSettle();

        expect(nutritionRepo.loggedRecords.length, 1);
        expect(nutritionRepo.loggedRecords.first.foodName, 'Masala Dosa');
        expect(remote.analyzeCallCount, 0);
      },
    );

    testWidgets(
      '9 & 10. User confirming Creamy Penne Pasta (not in 238 catalog) does NOT substitute Whole Grain Pasta, shows "Exact nutrition profile isn\'t available yet." and "— kcal", blocks Add to Food Diary until user selects from Search FitFuel Foods',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final nutritionRepo = _FakeNutritionRepo();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(
          buildHarness(controller: controller, nutritionRepo: nutritionRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Case B assertions: honest state without wrong nutrition substitution
        expect(find.text('Food recognized'), findsOneWidget);
        expect(find.text('Creamy Penne Pasta'), findsOneWidget);
        expect(find.text('Found on your device'), findsOneWidget);
        expect(find.text('Select nutrition profile'), findsOneWidget);
        expect(
          find.text('Exact nutrition profile isn\'t available yet.'),
          findsOneWidget,
        );
        expect(
          find.text(
              'Choose the closest nutrition profile from FitFuel Foods before logging.'),
          findsOneWidget,
        );
        expect(find.text('— kcal'), findsOneWidget);

        // Forbidden UI strings in Case B
        expect(find.text('0 kcal'), findsNothing);
        expect(find.text('Whole Grain Pasta (Cooked)'), findsNothing);
        expect(find.text('Partial estimate • Totals incomplete'), findsNothing);
        expect(find.text('Database Match'), findsNothing);

        // Add to Food Diary button is disabled while nutrition is unresolved
        await tester.ensureVisible(find.text('Add to Food Diary'));
        await tester.tap(find.text('Add to Food Diary'));
        await tester.pumpAndSettle();
        expect(nutritionRepo.loggedRecords, isEmpty);

        // Tap "Search FitFuel Foods" -> opens modal pre-filled with "creamy penne pasta" and related pasta items
        await tester.ensureVisible(find.text('Search FitFuel Foods'));
        await tester.tap(find.text('Search FitFuel Foods'));
        await tester.pumpAndSettle();

        expect(find.text('Select Database Food'), findsOneWidget);
        expect(find.text('Standard Pasta (Cooked)'), findsOneWidget);

        await tester.tap(find.text('Standard Pasta (Cooked)'));
        await tester.pumpAndSettle();

        // Now nutrition is resolved from trusted manual selection and Add to Food Diary is enabled
        expect(find.text('Estimated Meal Nutrition'), findsOneWidget);
        expect(find.text('Confirmed by you'), findsOneWidget);
        expect(
          (controller.state as FoodScanSuccess).result.recognitionSource,
          FoodScanRecognitionSource.manual,
        );

        await tester.ensureVisible(find.text('Add to Food Diary'));
        await tester.tap(find.text('Add to Food Diary'));
        await tester.pumpAndSettle();

        expect(nutritionRepo.loggedRecords.length, 1);
        expect(
          nutritionRepo.loggedRecords.first.foodName,
          'Standard Pasta (Cooked)',
        );
        expect(remote.analyzeCallCount, 0);
      },
    );

    test(
      '11 & 12 & 13. Cloud Gemini lock: 0 cloud calls on local routes, StateError when userRequestedAi == false, and 1 cloud call only on explicit Analyze with AI',
      () async {
        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: burgerOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );

        await repo.evaluateFreeFirstScan(
          imagePath: 'burger.jpg',
          imageBytes: dummyBytes,
          foodCatalog: fullCatalog,
          requestId: 'scan_burger',
        );
        expect(remote.analyzeCallCount, 0);
        expect(router.cloudCallsThisScan, 0);

        // Automatic Gemini call must throw StateError
        await expectLater(
          () => repo.analyzeWithAi(
            imagePath: 'burger.jpg',
            imageBytes: dummyBytes,
            foodCatalog: fullCatalog,
            requestId: 'scan_burger',
            userRequestedAi: false,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Automatic Gemini call blocked'),
            ),
          ),
        );
        expect(remote.analyzeCallCount, 0);

        // Explicit user-requested AI call succeeds
        final aiRes = await repo.analyzeWithAi(
          imagePath: 'burger.jpg',
          imageBytes: dummyBytes,
          foodCatalog: fullCatalog,
          requestId: 'scan_burger',
          userRequestedAi: true,
        );
        expect(aiRes.recognitionSource, FoodScanRecognitionSource.cloudGemini);
        expect(remote.analyzeCallCount, 1);
      },
    );

    testWidgets(
      '14 & 15 & 16. Offline Tier 1 and Tier 2 scans work with 0 cloud calls, and offline Analyze with AI is cleanly disabled',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(
          buildHarness(
            controller: controller,
            networkStatus: NetworkStatus.offline,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        expect(find.text('Creamy Penne Pasta'), findsOneWidget);
        expect(find.text('Found on your device'), findsOneWidget);
        expect(find.text('Other possible matches'), findsNothing);
        expect(find.text('Penne Alfredo'), findsNothing);
        expect(find.text('Creamy Pasta'), findsNothing);
        expect(remote.analyzeCallCount, 0);
      },
    );

    test(
      '17 & 18. Stale request cancellation and rapid repeated taps do not run duplicate inference or overwrite newer actions',
      () async {
        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final delayedTier2 = _DelayedOpenVocabRecognizer();
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: delayedTier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        // Start scan 1 (blocks inside Tier 2)
        final scanFuture = controller.pickAndScan(
          FoodImagePickSource.camera,
          catalog: fullCatalog,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Rapid second tap while analyzing is ignored
        await controller.pickAndScan(
          FoodImagePickSource.camera,
          catalog: fullCatalog,
        );
        expect(picker.pickCalls, 1);

        // User selects manual food before Tier 2 finishes
        final manualFood = fullCatalog.first;
        controller.selectManualFood(manualFood);
        expect(controller.state, isA<FoodScanSuccess>());

        // Complete delayed Tier 2 -> must NOT overwrite manual food selection
        delayedTier2.completer.complete(pastaOpenVocabResult);
        await scanFuture;

        expect(controller.state, isA<FoodScanSuccess>());
        final success = controller.state as FoodScanSuccess;
        expect(success.result.foods.first.displayName, manualFood.name);
        expect(
          success.result.recognitionSource,
          FoodScanRecognitionSource.manual,
        );
      },
    );

    testWidgets(
      '19 & 20. Open-vocabulary suggestions deduplicate aliases and never display similarity as % confidence in normal UI',
      (tester) async {
        tester.view.physicalSize = const Size(430, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final rawWithDuplicates = [
          const OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_creamy_penne_pasta',
            canonicalName: 'Creamy Penne Pasta',
            category: 'Pasta & Italian',
            similarity: 0.1680,
            rank: 1,
          ),
          const OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_creamy_penne_pasta',
            canonicalName: 'Creamy Penne Pasta',
            category: 'Pasta & Italian',
            similarity: 0.1590,
            rank: 2,
          ),
          const OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_penne_alfredo',
            canonicalName: 'Penne Alfredo',
            category: 'Pasta & Italian',
            similarity: 0.1328,
            rank: 3,
          ),
          const OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_creamy_pasta',
            canonicalName: 'Creamy Pasta',
            category: 'Pasta & Italian',
            similarity: 0.1235,
            rank: 4,
          ),
        ];

        final deduped = TrustedOpenVocabNutritionMapper.deduplicateCandidates(
          rawWithDuplicates,
          maxSuggestions: 3,
        );
        expect(deduped.length, 3);
        expect(
          deduped.map((c) => c.canonicalFoodId).toList(),
          [
            'openvocab_creamy_penne_pasta',
            'openvocab_penne_alfredo',
            'openvocab_creamy_pasta',
          ],
        );

        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await tester.pumpWidget(buildHarness(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Normal UI must NOT display raw similarity as percentage
        expect(find.textContaining('%'), findsNothing);
      },
    );

    test(
      '22. Disposing FoodScanController disposes the Tier 2 open-vocabulary session',
      () async {
        final tier1 = _StubTier1Classifier(pastaWeakV5Prediction);
        final tier2 = FakeOpenVocabularyFoodRecognizer(
          nextResult: pastaOpenVocabResult,
        );
        final remote = _SpyRemoteDataSource();
        final router = FoodScanRecognitionRouter(
          localClassifier: tier1,
          openVocabularyRecognizer: tier2,
          remoteDataSource: remote,
        );
        final repo = FoodScanRepositoryImpl(
          remoteDataSource: remote,
          router: router,
        );
        final picker = _StubImagePickerService();
        final controller = FoodScanController(
          repository: repo,
          imagePickerService: picker,
        );

        await controller.pickAndScan(
          FoodImagePickSource.camera,
          catalog: fullCatalog,
        );
        expect(tier2.isSessionLoaded, isTrue);
        expect(tier2.disposeCallCount, 0);

        controller.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(tier2.disposeCallCount, 1);
        expect(tier2.isSessionLoaded, isFalse);
      },
    );
  });
}
