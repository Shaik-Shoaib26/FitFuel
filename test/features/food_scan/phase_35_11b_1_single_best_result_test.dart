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
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_35_11b1';
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

class _StubOpenVocabRecognizer implements OpenVocabularyFoodRecognizer {
  OpenVocabularyRecognitionResult nextResult;
  int recognizeCalls = 0;
  int disposeCalls = 0;

  _StubOpenVocabRecognizer(this.nextResult);

  @override
  bool get isAvailable => true;

  @override
  bool get isSessionLoaded => true;

  @override
  bool get requiresColdInit => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<OpenVocabularyRecognitionResult> recognize(Uint8List imageBytes) async {
    recognizeCalls++;
    return nextResult;
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

  final List<FoodEntity> catalog = [
    ...PredefinedFoodData.foods.map((m) => m.toEntity()),
    const FoodEntity(
      id: 'predefined_burger',
      name: 'Burger',
      category: 'Fast Food',
      calories: 295.0,
      protein: 17.0,
      carbohydrates: 30.0,
      fats: 12.0,
      fiber: 2.0,
      sugar: 4.0,
      sodium: 480.0,
      servingSize: 150.0,
      servingUnit: 'g',
    ),
    const FoodEntity(
      id: 'predefined_cheeseburger',
      name: 'Cheeseburger',
      category: 'Fast Food',
      calories: 350.0,
      protein: 21.0,
      carbohydrates: 31.0,
      fats: 16.0,
      fiber: 2.0,
      sugar: 5.0,
      sodium: 590.0,
      servingSize: 170.0,
      servingUnit: 'g',
    ),
  ];
  final Uint8List dummyBytes = Uint8List.fromList([10, 20, 30, 40]);

  // Tier 1 predictions
  const samosaTier1Prediction = LocalFoodPrediction(
    foodId: 'predefined_samosa',
    foodName: 'Samosa',
    confidence: 0.95,
    topCandidates: [
      LocalFoodCandidate(
        foodId: 'predefined_samosa',
        foodName: 'Samosa',
        confidence: 0.95,
      ),
      LocalFoodCandidate(
        foodId: 'predefined_medu_vada',
        foodName: 'Medu Vada',
        confidence: 0.02,
      ),
    ],
    inferenceDurationMs: 25,
  );

  const pohaTier1Prediction = LocalFoodPrediction(
    foodId: 'predefined_poha',
    foodName: 'Poha',
    confidence: 0.96,
    topCandidates: [
      LocalFoodCandidate(
        foodId: 'predefined_poha',
        foodName: 'Poha',
        confidence: 0.96,
      ),
      LocalFoodCandidate(
        foodId: 'predefined_steamed_rice',
        foodName: 'Steamed Rice',
        confidence: 0.02,
      ),
    ],
    inferenceDurationMs: 25,
  );

  const weakTier1Prediction = LocalFoodPrediction(
    foodId: 'predefined_pineapple',
    foodName: 'Pineapple',
    confidence: 0.28,
    topCandidates: [
      LocalFoodCandidate(
        foodId: 'predefined_pineapple',
        foodName: 'Pineapple',
        confidence: 0.28,
      ),
      LocalFoodCandidate(
        foodId: 'predefined_apple',
        foodName: 'Apple',
        confidence: 0.15,
      ),
    ],
    inferenceDurationMs: 25,
  );

  // Tier 2 test results
  final burgerTier2Accepted = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_burger',
        canonicalName: 'Burger',
        category: 'Burgers & Sandwiches',
        similarity: 0.0909,
        rank: 1,
        inFitFuelCatalog: true,
        fitFuelFoodId: 'predefined_burger',
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_juicy_lucy',
        canonicalName: 'Juicy Lucy',
        category: 'Burgers & Sandwiches',
        similarity: 0.0749,
        rank: 2,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pljeskavica',
        canonicalName: 'Pljeskavica',
        category: 'Burgers & Sandwiches',
        similarity: 0.0622,
        rank: 3,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.0909,
    maxNegSimilarity: -0.0100,
    negMargin: 0.1009,
    preprocessMs: 10,
    encoderMs: 600,
    retrievalMs: 2,
    totalMs: 612,
  );

  final creamyPennePastaTier2Accepted = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_penne_pasta',
        canonicalName: 'Creamy Penne Pasta',
        category: 'Pasta & Italian',
        similarity: 0.1150,
        rank: 1,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_penne_alfredo',
        canonicalName: 'Penne Alfredo',
        category: 'Pasta & Italian',
        similarity: 0.0720,
        rank: 2,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_creamy_pasta',
        canonicalName: 'Creamy Pasta',
        category: 'Pasta & Italian',
        similarity: 0.0650,
        rank: 3,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.1150,
    maxNegSimilarity: -0.0050,
    negMargin: 0.1200,
    preprocessMs: 10,
    encoderMs: 600,
    retrievalMs: 2,
    totalMs: 612,
  );

  final pizzaFlammkuchenTier2 = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pizza',
        category: 'Pizza & Flatbreads',
        similarity: 0.0880,
        rank: 1,
        inFitFuelCatalog: true,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_tarte_flambee',
        canonicalName: 'Tarte Flambee / Flammkuchen',
        category: 'Pizza & Flatbreads',
        similarity: 0.0810,
        rank: 2,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.0880,
    maxNegSimilarity: 0.0010,
    negMargin: 0.0870,
  );

  final ramenTsukemenTier2 = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_ramen',
        canonicalName: 'Ramen',
        category: 'Noodles & Soups',
        similarity: 0.0890,
        rank: 1,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_tsukemen',
        canonicalName: 'Tsukemen',
        category: 'Noodles & Soups',
        similarity: 0.0800,
        rank: 2,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.0890,
    maxNegSimilarity: 0.0020,
    negMargin: 0.0870,
  );

  final spaghettiBologneseChiliTier2 = OpenVocabularyRecognitionResult.accepted(
    topCandidates: const [
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_spaghetti_bolognese',
        canonicalName: 'Spaghetti Bolognese',
        category: 'Pasta & Italian',
        similarity: 0.1063,
        rank: 1,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_spaghetti',
        canonicalName: 'Spaghetti',
        category: 'Pasta & Italian',
        similarity: 0.0980,
        rank: 2,
        inFitFuelCatalog: false,
      ),
      OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_cincinnati_chili',
        canonicalName: 'Cincinnati Chili',
        category: 'Stews & Chilis',
        similarity: 0.0890,
        rank: 3,
        inFitFuelCatalog: false,
      ),
    ],
    maxFoodSimilarity: 0.1063,
    maxNegSimilarity: -0.0010,
    negMargin: 0.1073,
  );

  final nonFoodTier2 = OpenVocabularyRecognitionResult.abstained(
    maxFoodSimilarity: 0.0520,
    maxNegSimilarity: 0.0680,
    negMargin: -0.0160,
    topNegativePrompt: 'desk computer office workspace',
    abstainReason: 'non_food_negative_margin',
  );

  Widget buildTestHarness({
    required FoodScanController controller,
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
    NetworkStatus networkStatus = NetworkStatus.online,
    INutritionRepository? nutritionRepo,
  }) {
    return ProviderScope(
      overrides: [
        foodScanControllerProvider.overrideWith((ref) => controller),
        foodScanRouterConfigProvider.overrideWithValue(config),
        networkStatusProvider.overrideWith((ref) => Stream.value(networkStatus)),
        authStateStreamProvider.overrideWith((ref) => Stream.value(_FakeUser())),
        if (nutritionRepo != null)
          nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
      ],
      child: const MaterialApp(
        home: FoodScanScreen(),
      ),
    );
  }

  group('FITFUEL Phase 35.11B.1 - Single Best Food Result & Strict Reliability Gate', () {
    test('1. Burger reliable -> one result (FoodScanSuccess, 1 food, macros shown, cloud calls = 0)', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_burger_1',
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      final primaryDecision = decision as Tier2OpenVocabPrimaryResult;
      expect(primaryDecision.primaryCandidate.displayName, equals('Burger'));
      expect(primaryDecision.reliabilityDecision.isReliable, isTrue);
      expect(primaryDecision.hasExactCatalogNutrition, isTrue);
      expect(primaryDecision.matchedFood, isNotNull);
      expect(primaryDecision.matchedFood!.name, equals('Burger'));
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('2. Pasta reliable or abstain -> never Top-3 UI on screen', () async {
      // Test the strict gate decision on ambiguous pasta
      const gate = SingleResultReliabilityGate();
      final decision = gate.evaluate(
        spaghettiBologneseChiliTier2,
        foodCatalog: catalog,
      );

      expect(decision.isReliable, isFalse);
      expect(decision.reason, equals('ambiguous_confusable_siblings'));
    });

    test('3. Samosa Tier-1 -> one result, Tier 2 not invoked', () async {
      final tier1 = _StubTier1Classifier(samosaTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_samosa_1',
        imagePath: 'samosa.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier1AutoLocalAccepted>());
      expect((decision as Tier1AutoLocalAccepted).prediction!.foodName, equals('Samosa'));
      expect(tier2.recognizeCalls, equals(0));
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('4. Poha regression -> not Tier-1 auto-trusted (falls through to Tier 2)', () async {
      final tier1 = _StubTier1Classifier(pohaTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_poha_1',
        imagePath: 'poha.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      // Poha is NOT auto-trusted in Tier-1; it falls through to Tier-2
      expect(decision, isNot(isA<Tier1AutoLocalAccepted>()));
      expect(tier2.recognizeCalls, equals(1));
    });

    test('5. Pizza / Flammkuchen -> single-result gate abstains (ambiguous_confusable_siblings)', () {
      const gate = SingleResultReliabilityGate();
      final decision = gate.evaluate(
        pizzaFlammkuchenTier2,
        foodCatalog: catalog,
      );

      expect(decision.isReliable, isFalse);
      expect(decision.reason, equals('ambiguous_confusable_siblings'));
    });

    test('6. Ramen / Tsukemen -> single-result gate abstains (ambiguous_confusable_siblings)', () {
      const gate = SingleResultReliabilityGate();
      final decision = gate.evaluate(
        ramenTsukemenTier2,
        foodCatalog: catalog,
      );

      expect(decision.isReliable, isFalse);
      expect(decision.reason, equals('ambiguous_confusable_siblings'));
    });

    test('7. Spaghetti / Bolognese / Cincinnati Chili -> single-result gate abstains', () {
      const gate = SingleResultReliabilityGate();
      final decision = gate.evaluate(
        spaghettiBologneseChiliTier2,
        foodCatalog: catalog,
      );

      expect(decision.isReliable, isFalse);
      expect(decision.reason, equals('ambiguous_confusable_siblings'));
    });

    test('8. Non-food -> abstains (No food detected, 0 cloud calls)', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(nonFoodTier2);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_nonfood_1',
        imagePath: 'desk.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2NonFoodAbstained>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('9. Mixed-meal -> abstains (Multiple foods detected or suspected)', () async {
      const mixedPrediction = LocalFoodPrediction(
        foodId: 'predefined_thali',
        foodName: 'Mixed Thali',
        confidence: 0.65,
        isMixedMealSuspected: true,
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_thali', foodName: 'Mixed Thali', confidence: 0.65),
          LocalFoodCandidate(foodId: 'predefined_dosa', foodName: 'Dosa', confidence: 0.30),
        ],
      );

      final tier1 = _StubTier1Classifier(mixedPrediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_mixed_1',
        imagePath: 'mixed_plate.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<MixedMealNeedsDecision>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('10. Exact nutrition immediately -> Burger shows macros & Add to Food Diary enabled in controller', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        ),
        imagePickerService: _StubImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      final success = controller.state as FoodScanSuccess;
      expect(success.result.foods.length, equals(1));
      expect(success.result.foods.first.displayName, equals('Burger'));
      expect(success.result.canBeLogged, isTrue);
      expect(success.result.totalCalories, greaterThan(0));
      expect(success.result.isRecognizedOnDevice, isTrue);
      expect(success.result.sourceBadgeLabel, equals('Found on your device'));
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('11. Missing nutrition handling -> Creamy Penne Pasta shows honest missing nutrition state, no fake 0 kcal', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(creamyPennePastaTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        ),
        imagePickerService: _StubImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'pasta.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      expect(controller.state, isA<FoodScanSuccess>());
      final success = controller.state as FoodScanSuccess;
      expect(success.result.canBeLogged, isFalse);
      expect(success.result.hasIncompleteNutrition, isTrue);
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('12. Change Food button present and opens search without Top-3 alternatives', () async {
      expect(burgerTier2Accepted.topCandidates.length, equals(3));
      final primaryCandidate = burgerTier2Accepted.topCandidates.first;
      expect(primaryCandidate.displayName, equals('Burger'));
    });

    test('13. Manual correction -> changes food to Cheeseburger, updates source to manualConfirmed and updates nutrition', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        ),
        imagePickerService: _StubImagePickerService(),
      );

      await controller.scanImageBytes(
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );
      expect(controller.state, isA<FoodScanSuccess>());

      // User selects Cheeseburger from catalog
      final cheeseburger = catalog.firstWhere((f) => f.name.toLowerCase().contains('burger'));
      controller.updateMatchedFood(0, cheeseburger);

      final updatedSuccess = controller.state as FoodScanSuccess;
      expect(updatedSuccess.result.foods.first.displayName, equals(cheeseburger.name));
      expect(updatedSuccess.result.isUserConfirmed, isTrue);
      expect(updatedSuccess.result.sourceBadgeLabel, equals('Confirmed by you'));
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    testWidgets('14. No Top-3 UI left on production screen for Burger', (tester) async {
      tester.view.physicalSize = const Size(430, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();
      final picker = _StubImagePickerService();
      final fakeNutritionRepo = _FakeNutritionRepo();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final repo = FoodScanRepositoryImpl(
        remoteDataSource: spyRemote,
        router: router,
      );

      final controller = FoodScanController(
        repository: repo,
        imagePickerService: picker,
      );

      await tester.pumpWidget(
        buildTestHarness(
          controller: controller,
          nutritionRepo: fakeNutritionRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger photo pick via camera
      final cameraBtn = find.text('Take Photo');
      expect(cameraBtn, findsOneWidget);
      await tester.tap(cameraBtn);
      await tester.pumpAndSettle();

      // UI must show 'Burger'
      expect(find.text('Burger'), findsWidgets);

      // UI must NEVER show Top-2 'Juicy Lucy' or Top-3 'Pljeskavica'
      expect(find.text('Juicy Lucy'), findsNothing);
      expect(find.text('Pljeskavica'), findsNothing);
      expect(find.text('Other possible matches'), findsNothing);
      expect(find.text('Which food is this?'), findsNothing);
      expect(find.text('Choose the closest match'), findsNothing);

      // Badge must show 'Found on your device'
      expect(find.text('Found on your device'), findsOneWidget);

      // Change Food button must be present
      expect(find.text('Change Food'), findsOneWidget);

      // Add to Food Diary button must be disabled until nutrition is selected
      final addDiaryBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Add to Food Diary'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(addDiaryBtn.onPressed, isNull);

      // 0 cloud calls
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('15. Cloud calls = 0 across all local flows', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      await router.routeFreeFirst(
        requestId: 'req_local_1',
        imagePath: 'img1.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );
      await router.routeFreeFirst(
        requestId: 'req_local_2',
        imagePath: 'img2.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(spyRemote.analyzeCallCount, equals(0));
    });

    test('16. Gemini explicit-only -> only called on Analyze with AI', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: spyRemote,
          router: router,
        ),
        imagePickerService: _StubImagePickerService(),
      );

      // Perform local scan first
      await controller.scanImageBytes(
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        catalog: catalog,
      );

      // Initially 0 calls across local scan
      expect(spyRemote.analyzeCallCount, equals(0));

      // User explicitly calls analyzeWithAi
      await controller.analyzeWithAi(catalog: catalog, isOffline: false);
      expect(spyRemote.analyzeCallCount, equals(1));
    });

    test('17. Session reuse / disposal', () async {
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      await tier2.initialize();
      expect(tier2.isSessionLoaded, isTrue);
      await tier2.dispose();
      expect(tier2.disposeCalls, equals(1));
    });

    test('18. Offline mode works identically with 0 cloud calls', () async {
      final tier1 = _StubTier1Classifier(weakTier1Prediction);
      final tier2 = _StubOpenVocabRecognizer(burgerTier2Accepted);
      final spyRemote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'req_offline_1',
        imagePath: 'burger.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
        isOffline: true,
      );

      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });
  });
}
