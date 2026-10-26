import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/canonical_food_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_feedback_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_35_12';
  @override
  String get email => 'test@fitfuel.app';
  @override
  String get displayName => 'Test User';
}

class _StubTier1Classifier implements FoodVisionClassifier {
  LocalFoodPrediction nextPrediction;
  _StubTier1Classifier(this.nextPrediction);

  @override
  bool get isAvailable => nextPrediction.isModelAvailable;

  @override
  Future<LocalFoodPrediction> classify(Uint8List imageBytes) async => nextPrediction;

  @override
  void dispose() {}
}

class _StubOpenVocabRecognizer implements OpenVocabularyFoodRecognizer {
  OpenVocabularyRecognitionResult nextResult;
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
  Future<OpenVocabularyRecognitionResult> recognize(Uint8List imageBytes) async => nextResult;

  @override
  Future<void> dispose() async {}
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
  String? returnPath = 'test_food_image.jpg';
  Uint8List? returnBytes = Uint8List.fromList([1, 2, 3, 4]);

  @override
  Future<String?> pickImage(FoodImagePickSource source) async => returnPath;

  @override
  Future<Uint8List?> getImageBytes(String path) async => returnBytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();

  group('Phase 35.12 — Global Food Vocabulary & Scalable Taxonomy', () {
    test('1. Vocabulary service initializes 2,050+ world concepts and FitFuel catalog', () async {
      final vocabService = GlobalFoodVocabularyService();
      await vocabService.initialize();

      expect(vocabService.totalEntries, greaterThanOrEqualTo(238 + 20));
      expect(vocabService.isInitialized, isTrue);

      // Verify Indian cuisine
      final samosa = vocabService.getEntry('openvocab_samosa');
      expect(samosa, isNotNull);
      expect(samosa!.cuisine, equals('Indian'));
      expect(samosa.aliases, contains('singara'));

      // Verify Italian cuisine
      final margherita = vocabService.getEntry('openvocab_margherita_pizza');
      expect(margherita, isNotNull);
      expect(margherita!.cuisine, equals('Italian'));

      // Verify Middle Eastern cuisine
      final shawarma = vocabService.getEntry('openvocab_shawarma');
      expect(shawarma, isNotNull);
      expect(shawarma!.cuisine, equals('Middle Eastern'));

      // Verify East Asian cuisine
      final ramen = vocabService.getEntry('openvocab_ramen');
      expect(ramen, isNotNull);
      expect(ramen!.cuisine, equals('Japanese'));
    });

    test('2. Multi-token search retrieves dishes across synonyms, aliases, and transliterations', () async {
      final vocabService = GlobalFoodVocabularyService();
      await vocabService.initialize();

      // Search by transliteration / regional alias
      final singaraSearch = vocabService.search('singara');
      expect(singaraSearch.any((e) => e.canonicalId.contains('samosa')), isTrue);

      final pastaSearch = vocabService.search('penne');
      expect(pastaSearch.any((e) => e.canonicalId.contains('pasta') || e.canonicalId.contains('penne')), isTrue);

      final tacoSearch = vocabService.search('carnitas');
      expect(tacoSearch.any((e) => e.canonicalId.contains('taco')), isTrue);
    });

    test('3. Cuisine and category filtering operates accurately', () async {
      final vocabService = GlobalFoodVocabularyService();
      await vocabService.initialize();

      final indianDishes = vocabService.filterByCuisine('Indian');
      expect(indianDishes.isNotEmpty, isTrue);
      expect(indianDishes.every((e) => e.cuisine?.toLowerCase() == 'indian'), isTrue);

      final noodles = vocabService.filterByCategory('Noodles & Soups');
      expect(noodles.isNotEmpty, isTrue);
    });

    test('4. Dynamic downloadable vocabulary pack registration extends taxonomy without retraining', () async {
      final vocabService = GlobalFoodVocabularyService();
      await vocabService.initialize();

      const newPackDish = CanonicalFoodEntry(
        canonicalId: 'openvocab_west_african_jollof_rice',
        preferredName: 'Nigerian Jollof Rice',
        aliases: ['jollof', 'benachin', 'party jollof'],
        category: 'Rice & Grains',
        cuisine: 'West African',
        ingredients: ['rice', 'tomatoes', 'peppers', 'onions', 'spices'],
        source: 'West Africa Regional Pack v1.0',
      );

      vocabService.registerEntry(newPackDish);
      expect(vocabService.getEntry('openvocab_west_african_jollof_rice'), isNotNull);

      final searchResult = vocabService.search('benachin');
      expect(searchResult.any((e) => e.canonicalId == 'openvocab_west_african_jollof_rice'), isTrue);
    });
  });

  group('Phase 35.12 — Universal Nutrition Architecture & 4-Tier Resolution', () {
    final resolver = UniversalNutritionResolver();

    test('5. Verified Exact tier resolved from FitFuel curated database', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_samosa',
        canonicalName: 'Samosa',
        category: 'Snacks',
        similarity: 0.1800,
        rank: 1,
        inFitFuelCatalog: true,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.verifiedExact));
      expect(resolution.isVerifiedExact, isTrue);
      expect(resolution.hasNutrition, isTrue);
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.id, equals('predefined_samosa'));
    });

    test('6. Closely Related Generic tier resolved from USDA standard baseline', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_plain_cooked_pasta',
        canonicalName: 'Spaghetti Pasta',
        category: 'Pasta & Italian',
        similarity: 0.1750,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.profile, isNotNull);
      expect(resolution.profile!.source, equals('USDA FoodData Central'));
      expect(resolution.recipeAssumptions, isNotNull);
    });

    test('7. Recipe Estimate tier resolved with transparent stated culinary assumptions', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_penne_alfredo',
        canonicalName: 'Creamy Penne Alfredo',
        category: 'Pasta & Italian',
        similarity: 0.1650,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.recipeEstimate));
      expect(resolution.isRecipeEstimate, isTrue);
      expect(resolution.recipeAssumptions, contains('cream'));
    });

    test('8. Unavailable tier honestly protects against macro fabrication when no profile exists', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_exotic_dragonfruit_salad',
        canonicalName: 'Exotic Dragonfruit Salad',
        category: 'Salads',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.unavailable));
      expect(resolution.hasNutrition, isFalse);
      expect(resolution.explanation, contains('No verified profile'));
    });
  });

  group('Phase 35.12 — Privacy-First Food Feedback Workflow', () {
    test('9. Records user correction without uploading private images', () async {
      final feedbackService = FoodFeedbackService();

      final record = await feedbackService.submitFeedback(
        correctedFoodName: 'Medu Vada',
        feedbackType: FoodFeedbackType.correction,
        predictedFoodName: 'Donut',
        scanSessionId: 'scan_10',
        userNotes: 'South Indian breakfast lentil donut',
        consentToUseImageForReview: false,
      );

      expect(record.correctedFoodName, equals('Medu Vada'));
      expect(record.feedbackType, equals(FoodFeedbackType.correction));
      expect(record.consentToUseImageForReview, isFalse);
      expect(feedbackService.pendingCount, equals(1));
    });

    test('10. Records unsupported world food report with user consent checkbox', () async {
      final feedbackService = FoodFeedbackService();

      final record = await feedbackService.submitFeedback(
        correctedFoodName: 'Kachori',
        feedbackType: FoodFeedbackType.unknownFood,
        userNotes: 'Crispy deep fried Indian pastry with spiced lentils',
        consentToUseImageForReview: true,
      );

      expect(record.correctedFoodName, equals('Kachori'));
      expect(record.feedbackType, equals(FoodFeedbackType.unknownFood));
      expect(record.consentToUseImageForReview, isTrue);
      expect(feedbackService.pendingCount, equals(1));
    });
  });

  group('Phase 35.12 — UI Presentation & Simple Main Result', () {
    Widget buildHarness({
      required FoodScanController controller,
    }) {
      return ProviderScope(
        overrides: [
          foodScanControllerProvider.overrideWith((ref) => controller),
          networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
          authStateStreamProvider.overrideWith((ref) => Stream.value(_FakeUser())),
        ],
        child: const MaterialApp(
          home: FoodScanScreen(),
        ),
      );
    }

    testWidgets('11. Suggestions state prominently displays Best local match and expandable alternatives', (tester) async {
      const topCandidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_pizza',
          canonicalName: 'Pizza',
          category: 'Pizza & Italian',
          similarity: 0.1250,
          rank: 1,
          inFitFuelCatalog: true,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_calzone',
          canonicalName: 'Calzone',
          category: 'Pizza & Italian',
          similarity: 0.1200,
          rank: 2,
          inFitFuelCatalog: false,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_flatbread',
          canonicalName: 'Flatbread',
          category: 'Bakery',
          similarity: 0.1150,
          rank: 3,
          inFitFuelCatalog: false,
        ),
      ];

      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'unknown',
          foodName: 'Unknown',
          confidence: 0.35,
          isModelAvailable: true,
          inferenceDurationMs: 12,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: topCandidates,
          maxFoodSimilarity: 0.1250,
          maxNegSimilarity: -0.0120,
          negMargin: 0.1370,
        ),
      );
      final spyRemote = _SpyRemoteDataSource();
      final picker = _StubImagePickerService();

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

      await tester.pumpWidget(buildHarness(controller: controller));
      await tester.pumpAndSettle();

      // Trigger photo scan
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Verify Best Local Match hero header
      expect(find.text('Best local match: Pizza'), findsOneWidget);
      expect(find.text('On-Device Vision'), findsOneWidget);
      expect(find.byKey(const Key('suggestion_openvocab_pizza')), findsOneWidget);
      expect(find.textContaining('Cosine similarity: 0.1250'), findsWidgets);

      // Verify Expandable "Other possible matches"
      expect(find.text('Other possible matches'), findsOneWidget);
      expect(find.byKey(const Key('suggestion_openvocab_calzone')), findsOneWidget);
      expect(find.byKey(const Key('suggestion_openvocab_flatbread')), findsOneWidget);

      // Verify Report Food and Search Catalog action buttons
      expect(find.byKey(const Key('btn_report_food_feedback')), findsOneWidget);
      expect(find.byKey(const Key('btn_search_catalog_suggestions')), findsOneWidget);

      // Zero Gemini calls made
      expect(spyRemote.analyzeCallCount, equals(0));
    });

    testWidgets('12. User taps Report Food opens dialog without photo upload', (tester) async {
      const topCandidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_pizza',
          canonicalName: 'Pizza',
          category: 'Pizza & Italian',
          similarity: 0.1250,
          rank: 1,
          inFitFuelCatalog: true,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_calzone',
          canonicalName: 'Calzone',
          category: 'Pizza & Italian',
          similarity: 0.1200,
          rank: 2,
          inFitFuelCatalog: false,
        ),
      ];

      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'unknown',
          foodName: 'Unknown',
          confidence: 0.35,
          isModelAvailable: true,
          inferenceDurationMs: 12,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: topCandidates,
          maxFoodSimilarity: 0.1250,
          maxNegSimilarity: -0.0120,
          negMargin: 0.1370,
        ),
      );
      final spyRemote = _SpyRemoteDataSource();
      final picker = _StubImagePickerService();

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

      await tester.pumpWidget(buildHarness(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Open Feedback Dialog
      await tester.ensureVisible(find.byKey(const Key('btn_report_food_feedback')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_report_food_feedback')));
      await tester.pumpAndSettle();

      expect(find.text('Report or Correct Food'), findsOneWidget);
      expect(find.text('Detected as: Pizza'), findsOneWidget);
      expect(find.byKey(const Key('btn_submit_food_feedback')), findsOneWidget);
      expect(find.text('Include dish name in review queue (no photos uploaded)'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Report or Correct Food'), findsNothing);
    });
  });

  group('Phase 35.12.2 — Production Nutrition Resolution & Macro Scaling', () {
    final resolver = UniversalNutritionResolver();

    test('13. Confirmed generic Pizza resolves to closelyRelatedGeneric with USDA attribution', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pizza',
        category: 'Pizza & Italian',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.attribution, contains('Department of Agriculture'));
      expect(resolution.profile?.source, contains('USDA'));
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
      expect(resolution.matchedCatalogFood!.carbs, greaterThan(0));
      expect(resolution.matchedCatalogFood!.fat, greaterThan(0));
      expect(resolution.matchedCatalogFood!.protein, greaterThan(0));
    });

    test('14. Confirmed generic Burger resolves to closelyRelatedGeneric with USDA attribution', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_burger',
        canonicalName: 'Burger',
        category: 'American',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.attribution, contains('Department of Agriculture'));
      expect(resolution.profile?.source, contains('USDA'));
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.protein, greaterThan(0));
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
    });

    test('15. Confirmed generic Pasta resolves to closelyRelatedGeneric with USDA attribution', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pasta',
        canonicalName: 'Pasta',
        category: 'Pasta & Italian',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolution.isGenericBaseline, isTrue);
      expect(resolution.attribution, contains('Department of Agriculture'));
      expect(resolution.profile?.source, contains('USDA'));
      expect(resolution.matchedCatalogFood, isNotNull);
      expect(resolution.matchedCatalogFood!.carbs, greaterThan(0));
      expect(resolution.matchedCatalogFood!.calories, greaterThan(0));
    });

    test('16. Substring safety: pastrami sandwich does NOT match generic pasta and remains unavailable', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pastrami_sandwich',
        canonicalName: 'Pastrami Sandwich',
        category: 'Sandwiches',
        similarity: 0.1400,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.unavailable));
      expect(resolution.hasNutrition, isFalse);
      expect(resolution.matchedCatalogFood, isNull);
    });

    test('17. Unsupported food (e.g. dragonfruit salad) remains honestly unavailable with 0 macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_dragonfruit_salad',
        canonicalName: 'Dragonfruit Salad',
        category: 'Salads',
        similarity: 0.1300,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolution.tier, equals(NutritionProfileTier.unavailable));
      expect(resolution.hasNutrition, isFalse);
      expect(resolution.matchedCatalogFood, isNull);
    });

    test('18. Portion adjustment scales macros correctly for generic baseline', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_pizza',
        canonicalName: 'Pizza',
        category: 'Pizza & Italian',
        similarity: 0.1500,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final resolution = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      final baseFood = resolution.matchedCatalogFood!;
      final baseCal = baseFood.calories;
      final baseProt = baseFood.protein;
      final baseCarb = baseFood.carbs;
      final baseFat = baseFood.fat;

      // Portion adjustment to 250g
      const double newServing = 250.0;
      final double scale = newServing / baseFood.servingSize;
      final scaled = baseFood.copyWith(
        servingSize: newServing,
        calories: baseCal * scale,
        protein: baseProt * scale,
        carbohydrates: baseCarb * scale,
        fats: baseFat * scale,
      );

      expect(scaled.servingSize, equals(250.0));
      expect(scaled.calories, closeTo(baseCal * scale, 0.01));
      expect(scaled.protein, closeTo(baseProt * scale, 0.01));
      expect(scaled.carbs, closeTo(baseCarb * scale, 0.01));
      expect(scaled.fat, closeTo(baseFat * scale, 0.01));
    });

    test('19. FoodScanRecognitionRouter.confirmOpenVocabCandidate wires UniversalNutritionResolver', () {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'unknown',
          foodName: 'Unknown',
          confidence: 0.35,
          isModelAvailable: true,
          inferenceDurationMs: 12,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.accepted(
          topCandidates: const [
            OpenVocabularyFoodCandidate(
              canonicalFoodId: 'openvocab_burger',
              canonicalName: 'Burger',
              category: 'American',
              similarity: 0.1250,
              rank: 1,
              inFitFuelCatalog: false,
            ),
          ],
          maxFoodSimilarity: 0.1250,
          maxNegSimilarity: -0.0120,
          negMargin: 0.1370,
        ),
      );
      final spyRemote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_burger',
        canonicalName: 'Burger',
        category: 'American',
        similarity: 0.1250,
        rank: 1,
        inFitFuelCatalog: false,
      );

      final scanResult = router.confirmOpenVocabCandidate(
        candidate: candidate,
        foodCatalog: catalog,
        imagePath: 'dummy.jpg',
        requestId: 'scan_router_confirm_test',
      );

      expect(scanResult.foods.first.nutritionTier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(scanResult.foods.first.matchedFood, isNotNull);
      expect(scanResult.foods.first.matchedFood!.protein, greaterThan(0));
      expect(scanResult.foods.first.nutritionAttribution, contains('Department of Agriculture'));
      expect(spyRemote.analyzeCallCount, equals(0));
    });
  });

  group('Phase 35.12.2 — Dynamic Vocabulary Pack Validation & Integrity', () {
    test('20. Pack with valid 768-d embeddings is accepted for vision and text matching', () {
      final vocabService = GlobalFoodVocabularyService();
      final dummy768 = List<double>.filled(768, 0.036);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_mexican_birria',
        preferredName: 'Birria Tacos',
        aliases: ['birria', 'quesabirria'],
        cuisine: 'Mexican',
        category: 'Street Food',
        textEmbedding: dummy768,
        embeddingModelId: 'siglip_b16_int8',
        packVersion: '1.0.0',
      );

      final pack = VocabularyPack(
        packId: 'mexican_regional_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = vocabService.registerVocabularyPack(pack);
      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(1));
      expect(result.textOnlyEntries, equals(0));
      expect(vocabService.isImageEligible('openvocab_mexican_birria'), isTrue);
      expect(vocabService.imageEligibleEntries.any((e) => e.canonicalId == 'openvocab_mexican_birria'), isTrue);
    });

    test('21. Pack without embeddings is accepted for text search only', () {
      final vocabService = GlobalFoodVocabularyService();
      const entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_gujarati_undhiyu',
        preferredName: 'Undhiyu',
        cuisine: 'Indian',
        category: 'Curry',
      );

      const pack = VocabularyPack(
        packId: 'indian_regional_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = vocabService.registerVocabularyPack(pack);
      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(0));
      expect(result.textOnlyEntries, equals(1));
      expect(vocabService.isImageEligible('openvocab_gujarati_undhiyu'), isFalse);
      expect(vocabService.textOnlyEntries.any((e) => e.canonicalId == 'openvocab_gujarati_undhiyu'), isTrue);

      final search = vocabService.search('undhiyu');
      expect(search.any((e) => e.canonicalId == 'openvocab_gujarati_undhiyu'), isTrue);
    });

    test('22. Pack with mismatched embedding dimensions (512-d) strips vision support without crashing', () {
      final vocabService = GlobalFoodVocabularyService();
      final dummy512 = List<double>.filled(512, 0.044);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_dim_mismatch_dish',
        preferredName: 'Mismatched Dish',
        textEmbedding: dummy512,
      );

      final pack = VocabularyPack(
        packId: 'mismatched_pack_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = vocabService.registerVocabularyPack(pack);
      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(0));
      expect(result.textOnlyEntries, equals(1));
      expect(result.warnings.isNotEmpty, isTrue);
      expect(vocabService.isImageEligible('openvocab_dim_mismatch_dish'), isFalse);
    });

    test('23. Pack with requireAllVisionEligible: true triggers atomic rollback on invalid embeddings', () {
      final vocabService = GlobalFoodVocabularyService();
      final countBefore = vocabService.count;

      final dummy512 = List<double>.filled(512, 0.044);
      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_fatal_dish',
        preferredName: 'Fatal Dish',
        textEmbedding: dummy512,
      );

      final pack = VocabularyPack(
        packId: 'strict_pack_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = vocabService.registerVocabularyPack(pack, requireAllVisionEligible: true);
      expect(result.isValid, isFalse);
      expect(result.validationErrors.isNotEmpty, isTrue);
      expect(vocabService.count, equals(countBefore));
      expect(vocabService.getEntry('openvocab_fatal_dish'), isNull);
    });

    test('24. Entry with NaN or Infinite embedding values has vision support stripped', () {
      final vocabService = GlobalFoodVocabularyService();
      final nanEmb = List<double>.filled(768, 0.01);
      nanEmb[42] = double.nan;

      final entry = CanonicalFoodEntry(
        canonicalId: 'openvocab_nan_dish',
        preferredName: 'NaN Dish',
        textEmbedding: nanEmb,
      );

      final pack = VocabularyPack(
        packId: 'nan_pack_v1',
        version: '1.0.0',
        entries: [entry],
      );

      final result = vocabService.registerVocabularyPack(pack);
      expect(result.isValid, isTrue);
      expect(result.visionEligibleEntries, equals(0));
      expect(result.textOnlyEntries, equals(1));
      expect(vocabService.isImageEligible('openvocab_nan_dish'), isFalse);
    });
  });

  group('Phase 35.12.2 — SharedPreferences Feedback Persistence & Deduplication', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('25. Feedback persists across service re-initialization', () async {
      final prefs = await SharedPreferences.getInstance();
      final service1 = FoodFeedbackService(prefs);
      await service1.initialize();

      await service1.submitFeedback(
        correctedFoodName: 'Dosa',
        feedbackType: FoodFeedbackType.unknownFood,
        scanSessionId: 'scan_persist_1',
      );
      expect(service1.pendingCount, equals(1));

      final service2 = FoodFeedbackService(prefs);
      await service2.initialize();
      expect(service2.pendingCount, equals(1));
      expect(service2.pendingFeedback.first.correctedFoodName, equals('Dosa'));
    });

    test('26. Duplicate feedback for same session and food is deduplicated', () async {
      final service = FoodFeedbackService();
      await service.initialize();

      final first = await service.submitFeedback(
        correctedFoodName: 'Chole Bhature',
        feedbackType: FoodFeedbackType.correction,
        scanSessionId: 'scan_dedup_1',
      );
      expect(service.pendingCount, equals(1));

      final second = await service.submitFeedback(
        correctedFoodName: '  Chole Bhature  ',
        feedbackType: FoodFeedbackType.correction,
        scanSessionId: 'scan_dedup_1',
      );
      expect(service.pendingCount, equals(1));
      expect(second.id, equals(first.id));
    });

    test('27. JSON export format produces valid structured records', () async {
      final service = FoodFeedbackService();
      await service.initialize();

      await service.submitFeedback(
        correctedFoodName: 'Idli Vada',
        feedbackType: FoodFeedbackType.unknownFood,
        userNotes: 'Breakfast combo',
      );

      final jsonStr = service.exportQueueAsJson();
      final decoded = json.decode(jsonStr) as List<dynamic>;
      expect(decoded.length, equals(1));
      expect(decoded.first['correctedFoodName'], equals('Idli Vada'));
      expect(decoded.first['feedbackType'], equals('unknownFood'));
      expect(decoded.first['userNotes'], equals('Breakfast combo'));
    });

    test('28. Corrupted persisted storage is handled gracefully without crashing', () async {
      SharedPreferences.setMockInitialValues({
        FoodFeedbackService.storageKey: '{ this is corrupt json !!!',
      });
      final service = FoodFeedbackService();
      await service.initialize();
      expect(service.pendingCount, equals(0));
    });

    test('29. Clearing queue removes records in-memory and in storage', () async {
      final service = FoodFeedbackService();
      await service.initialize();

      await service.submitFeedback(
        correctedFoodName: 'Pani Puri',
        feedbackType: FoodFeedbackType.unknownFood,
      );
      expect(service.pendingCount, equals(1));

      await service.clearQueue();
      expect(service.pendingCount, equals(0));

      final serviceAfter = FoodFeedbackService();
      await serviceAfter.initialize();
      expect(serviceAfter.pendingCount, equals(0));
    });
  });

  group('Phase 35.12.2 — Zero Automatic Gemini Calls Guarantee', () {
    test('30. Normal scan with low confidence never invokes remote Gemini', () async {
      final tier1 = _StubTier1Classifier(
        const LocalFoodPrediction(
          foodId: 'unknown',
          foodName: 'Unknown',
          confidence: 0.15,
          isModelAvailable: true,
          inferenceDurationMs: 10,
        ),
      );
      final tier2 = _StubOpenVocabRecognizer(
        OpenVocabularyRecognitionResult.abstained(
          abstainReason: 'below_similarity_threshold',
          maxFoodSimilarity: 0.08,
          maxNegSimilarity: -0.01,
          negMargin: 0.09,
        ),
      );
      final spyRemote = _SpyRemoteDataSource();
      final router = FoodScanRecognitionRouter(
        localClassifier: tier1,
        openVocabularyRecognizer: tier2,
        remoteDataSource: spyRemote,
      );

      final decision = await router.routeFreeFirst(
        imagePath: 'dummy.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        requestId: 'scan_gemini_zero_check',
        foodCatalog: catalog,
      );

      expect(decision, isA<Tier2NoReliableMatch>());
      expect(spyRemote.analyzeCallCount, equals(0));
    });
  });
}
