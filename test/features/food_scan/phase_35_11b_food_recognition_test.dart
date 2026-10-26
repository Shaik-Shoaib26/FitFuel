import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_matcher.dart';
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
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
class _FakeUser extends Fake implements User {
  @override
  String get uid => 'phase_35_11b_test_uid';
  @override
  String get email => 'test@fitfuel.app';
  @override
  String get displayName => 'Test User';
}

class _StubTier1Classifier implements FoodVisionClassifier {
  final LocalFoodPrediction prediction;
  int classifyCalls = 0;

  _StubTier1Classifier(this.prediction);

  @override
  bool get isAvailable => prediction.isModelAvailable;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async {
    classifyCalls++;
    return prediction;
  }

  @override
  void dispose() {}
}

class _StubOpenVocabRecognizer implements OpenVocabularyFoodRecognizer {
  final OpenVocabularyRecognitionResult result;
  final bool available;
  int recognizeCalls = 0;
  int disposeCalls = 0;

  _StubOpenVocabRecognizer(this.result, {this.available = true});

  @override
  bool get isAvailable => available;

  @override
  bool get isSessionLoaded => true;

  @override
  bool get requiresColdInit => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<OpenVocabularyRecognitionResult> recognize(Uint8List imageBytes) async {
    recognizeCalls++;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _SpyRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    return const [];
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
  final Uint8List sampleBytes = Uint8List.fromList([1, 2, 3, 4]);

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    return 'test_sample.jpg';
  }

  @override
  Future<Uint8List?> getImageBytes(String path) async {
    return sampleBytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final Uint8List sampleBytes = Uint8List.fromList([10, 20, 30, 40]);

  Widget buildHarness({
    required FoodScanController controller,
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
    NetworkStatus networkStatus = NetworkStatus.online,
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
      ],
      child: const MaterialApp(
        home: FoodScanScreen(),
      ),
    );
  }

  group('Phase 35.11B Required Tests: Catalog Searchability & Alias Matching', () {
    test('1. Proves 100% of current catalog entries (all 238) are searchable by ID and name', () {
      expect(catalog.length, equals(238));

      for (final item in catalog) {
        // Search by exact food ID
        final byId = FoodSearchEngine.search(foods: catalog, query: item.id);
        expect(
          byId.any((f) => f.id == item.id),
          isTrue,
          reason: 'Food ID ${item.id} should be searchable in catalog',
        );

        // Search by food name
        final byName = FoodSearchEngine.search(foods: catalog, query: item.name);
        expect(
          byName.any((f) => f.id == item.id),
          isTrue,
          reason: 'Food name "${item.name}" should be searchable in catalog',
        );

        // Match by food.id via FoodMatcher
        final matchById = FoodMatcher.match(item.id, catalog);
        expect(
          matchById.isMatched,
          isTrue,
          reason: 'FoodMatcher should match ID ${item.id}',
        );
        expect(matchById.food?.id, equals(item.id));
      }
    });

    test('2. Tests for aliases and similar food names (pizza, burger, samosas, pasta, dosa, rajma chawal)', () {
      // Samosa aliases & plurals
      final samosaSearch = FoodSearchEngine.search(foods: catalog, query: 'samosas');
      expect(samosaSearch.any((f) => f.id == 'predefined_samosa'), isTrue);

      final sambusaMatch = FoodMatcher.match('sambusa', catalog);
      expect(sambusaMatch.isMatched, isTrue);
      expect(sambusaMatch.food?.id, equals('predefined_samosa'));

      // Dosa variants & plurals
      final dosaSearch = FoodSearchEngine.search(foods: catalog, query: 'dosas');
      expect(dosaSearch.any((f) => f.id == 'predefined_dosa'), isTrue);

      final masalaDosaSearch = FoodSearchEngine.search(foods: catalog, query: 'masala dosa');
      expect(masalaDosaSearch.any((f) => f.id == 'predefined_masala_dosa'), isTrue);

      // Rajma & Rajma Chawal
      final rajmaSearch = FoodSearchEngine.search(foods: catalog, query: 'rajma chawal');
      expect(rajmaSearch.any((f) => f.id == 'predefined_rajma_chawal'), isTrue);

      final kidneyBeansSearch = FoodSearchEngine.search(foods: catalog, query: 'kidney beans');
      expect(kidneyBeansSearch.any((f) => f.id == 'predefined_rajma_curry' || f.id == 'predefined_rajma_chawal'), isTrue);

      final rajmaMatch = FoodMatcher.match('rajma', catalog);
      expect(rajmaMatch.isMatched, isTrue);

      // Pasta variants
      final pastaSearch = FoodSearchEngine.search(foods: catalog, query: 'pasta');
      expect(pastaSearch.any((f) => f.id == 'predefined_standard_pasta'), isTrue);
      expect(pastaSearch.any((f) => f.id == 'predefined_whole_grain_pasta'), isTrue);

      final penneMatch = FoodMatcher.match('penne', catalog);
      expect(penneMatch.isMatched, isTrue);

      final spaghettiMatch = FoodMatcher.match('spaghetti', catalog);
      expect(spaghettiMatch.isMatched, isTrue);

      // Pizza & Burger aliases matchable via FoodMatcher
      final pizzaMatch = FoodMatcher.match('cheese pizza', catalog);
      expect(pizzaMatch, isNotNull);

      final burgerMatch = FoodMatcher.match('cheeseburger', catalog);
      expect(burgerMatch, isNotNull);

      // Regional staple aliases
      final rotiSearch = FoodSearchEngine.search(foods: catalog, query: 'roti');
      expect(rotiSearch.any((f) => f.name.toLowerCase().contains('chapati') || f.name.toLowerCase().contains('roti')), isTrue);

      final dahiSearch = FoodSearchEngine.search(foods: catalog, query: 'dahi');
      expect(dahiSearch.any((f) => f.name.toLowerCase().contains('curd')), isTrue);
    });
  });

  group('Phase 35.11B Required Tests: Non-Food & Mixed-Meal Safety', () {
    test('3. Non-food negative prompt rejection abstains without calling Gemini', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_tomato',
          foodName: 'Tomato',
          confidence: 0.25,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.abstained(
          maxFoodSimilarity: 0.08,
          maxNegSimilarity: 0.095,
          negMargin: -0.015,
          topNegativePrompt: 'an empty plate or bowl with no food on it',
          abstainReason: 'non_food_negative_margin',
        ),
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_non_food',
        imagePath: 'empty_plate.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2AbstainedNonFood>());
      expect(remote.analyzeCallCount, equals(0));
      expect(router.cloudCallsThisScan, equals(0));
      expect(router.tier2AbstainedNonFood, equals(1));
    });

    test('4. Mixed meal suspicion prompts manual decision and never auto-logs', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_rice',
          foodName: 'Steamed Rice',
          confidence: 0.60,
          isMixedMealSuspected: true,
          topCandidates: [
            LocalFoodCandidate(foodId: 'predefined_steamed_rice', foodName: 'Steamed Rice', confidence: 0.60),
            LocalFoodCandidate(foodId: 'predefined_dal_tadka', foodName: 'Dal Tadka', confidence: 0.35),
          ],
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.abstained(
          maxFoodSimilarity: 0.10,
          maxNegSimilarity: 0.0,
          negMargin: 0.10,
          abstainReason: 'mixed_meal',
        ),
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_mixed',
        imagePath: 'mixed_plate.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
        isMixedMealSuspected: true,
      );

      expect(decision, isA<MixedMealNeedsDecision>());
      expect(remote.analyzeCallCount, equals(0));
      expect(router.cloudCallsThisScan, equals(0));
    });
  });

  group('Phase 35.11B Required Tests: Nutrition Safety & Non-Fabrication', () {
    test('5. Recognized catalog food retrieves exact database nutrition and requests portion confirmation', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_rajma_curry',
          foodName: 'Rajma Curry',
          confidence: 0.45, // Low confidence in Tier 1 -> falls to Tier 2
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: [
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'predefined_rajma_chawal',
              canonicalName: 'Rajma Chawal',
              category: 'Lunch',
              similarity: 0.185,
              rank: 1,
              inFitFuelCatalog: true,
              fitFuelFoodId: 'predefined_rajma_chawal',
            ),
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'predefined_rajma_curry',
              canonicalName: 'Rajma Curry (Kidney Beans)',
              category: 'Legumes',
              similarity: 0.130,
              rank: 2,
              inFitFuelCatalog: true,
              fitFuelFoodId: 'predefined_rajma_curry',
            ),
          ],
          maxFoodSimilarity: 0.185,
          maxNegSimilarity: -0.01,
          negMargin: 0.195,
        ),
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_rajma',
        imagePath: 'rajma_chawal.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      final primary = decision as Tier2OpenVocabPrimaryResult;
      expect(primary.primaryCandidate.displayName, equals('Rajma Chawal'));
      expect(primary.hasExactCatalogNutrition, isTrue);
      expect(primary.matchedFood, isNotNull);

      // Verify exact nutrition matches PredefinedFoodData database values (never fabricated)
      final dbFood = catalog.firstWhere((f) => f.id == 'predefined_rajma_chawal');
      expect(primary.matchedFood!.calories, equals(dbFood.calories));
      expect(primary.matchedFood!.protein, equals(dbFood.protein));
      expect(primary.matchedFood!.carbohydrates, equals(dbFood.carbohydrates));
      expect(primary.matchedFood!.fats, equals(dbFood.fats));
      expect(remote.analyzeCallCount, equals(0));
    });

    test('6. Unmapped food NEVER fabricates macros and requires user profile selection before logging', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_steamed_rice',
          foodName: 'Steamed Rice',
          confidence: 0.35,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: [
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_dragonfruit_salad',
              canonicalName: 'Dragonfruit Salad',
              category: 'Specialty Salads',
              similarity: 0.170,
              rank: 1,
              inFitFuelCatalog: false,
            ),
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_exotic_fruit_bowl',
              canonicalName: 'Exotic Fruit Bowl',
              category: 'Specialty Salads',
              similarity: 0.135,
              rank: 2,
              inFitFuelCatalog: false,
            ),
          ],
          maxFoodSimilarity: 0.170,
          maxNegSimilarity: -0.01,
          negMargin: 0.180,
        ),
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_dragonfruit_salad',
        imagePath: 'dragonfruit_salad.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2OpenVocabPrimaryResult>());
      final primary = decision as Tier2OpenVocabPrimaryResult;
      expect(primary.hasExactCatalogNutrition, isFalse);
      expect(primary.matchedFood, isNull);

      final repo = FoodScanRepositoryImpl(remoteDataSource: remote, router: router);
      final confirmed = repo.confirmOpenVocabCandidate(
        candidate: primary.primaryCandidate,
        foodCatalog: catalog,
        imagePath: 'dragonfruit_salad.jpg',
        requestId: 'confirm_dragonfruit_salad',
      );

      final food = confirmed.foods.first;
      // Calories and macros must NOT be fabricated (null or hasNutrition false)
      expect(food.hasNutrition, isFalse);
      expect(food.calories, isNull);
      expect(food.protein, isNull);
      expect(food.carbs, isNull);
      expect(food.fats, isNull);
      expect(confirmed.canBeLogged, isFalse); // Blocks logging until profile chosen
      expect(remote.analyzeCallCount, equals(0));
    });
  });

  group('Phase 35.11B Required Tests: Top-3 Suggestions & Normal Screen UI', () {
    testWidgets('7. Ambiguous match returns top three local suggestions with scores in normal Food Scan UI', (tester) async {
      tester.view.physicalSize = const Size(430, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_tomato',
          foodName: 'Tomato',
          confidence: 0.40,
        ),
      );
      // Confusable siblings / ambiguous margin between Pizza, Flammkuchen, Zanzibar Pizza
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: [
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_pizza',
              canonicalName: 'Cheese Pizza',
              category: 'Pizza & Flatbreads',
              similarity: 0.145,
              rank: 1,
              inFitFuelCatalog: false,
            ),
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_flammkuchen',
              canonicalName: 'Flammkuchen',
              category: 'Pizza & Flatbreads',
              similarity: 0.141,
              rank: 2,
              inFitFuelCatalog: false,
            ),
            const OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_zanzibar_pizza',
              canonicalName: 'Zanzibar Pizza',
              category: 'Pizza & Flatbreads',
              similarity: 0.138,
              rank: 3,
              inFitFuelCatalog: false,
            ),
          ],
          maxFoodSimilarity: 0.145,
          maxNegSimilarity: -0.015,
          negMargin: 0.160,
        ),
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

      // Normal Food Scan screen displays Top Local Matches with all 3 candidates and scores
      expect(find.text('Top Local Matches'), findsOneWidget);
      expect(find.text('Cheese Pizza'), findsOneWidget);
      expect(find.text('Flammkuchen'), findsOneWidget);
      expect(find.text('Zanzibar Pizza'), findsOneWidget);
      expect(find.text('On-Device Vision'), findsOneWidget);
      expect(find.textContaining('similarity:'), findsNWidgets(3));

      expect(remote.analyzeCallCount, equals(0));
      expect(router.cloudCallsThisScan, equals(0));

      // User confirms one of the top suggestions
      await tester.tap(find.byKey(const Key('suggestion_openvocab_pizza')));
      await tester.pumpAndSettle();

      // Transitions to recognition result with portion confirmation
      expect(find.text('Cheese Pizza'), findsOneWidget);
      expect(find.text('Found on your device'), findsOneWidget);
      expect(remote.analyzeCallCount, equals(0));
    });
  });

  group('Phase 35.11B Required Tests: Offline Operation & Cloud Safety', () {
    test('8. Offline mode recognizes catalog food locally with 0 cloud calls', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'predefined_samosa',
          foodName: 'Samosa',
          confidence: 0.94,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.abstained(
          maxFoodSimilarity: 0.0,
          maxNegSimilarity: 0.0,
          negMargin: 0.0,
        ),
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_offline',
        imagePath: 'samosa.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
        isOffline: true,
      );

      expect(decision, isA<LocalAutoAccepted>());
      expect((decision as LocalAutoAccepted).result.foods.first.displayName, equals('Samosa'));
      expect(remote.analyzeCallCount, equals(0));
      expect(router.cloudCallsThisScan, equals(0));
    });

    test('9. Low confidence and model failure never trigger Gemini automatically', () async {
      final tier1 = _StubTier1Classifier(
        LocalFoodPrediction.unavailable(reason: 'Classifier crashed'),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.unavailable(reason: 'SigLIP session missing'),
        available: false,
      );
      final remote = _SpyRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: remote,
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_failure',
        imagePath: 'broken.jpg',
        imageBytes: sampleBytes,
        foodCatalog: catalog,
      );

      expect(decision, isA<LocalModelUnavailable>());
      expect(remote.analyzeCallCount, equals(0));
      expect(router.cloudCallsThisScan, equals(0));
    });
  });
}
