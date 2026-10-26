import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';

// ==========================================
// Test Doubles
// ==========================================
class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_123';
}

class _MockTier1Classifier implements FoodVisionClassifier {
  LocalFoodPrediction nextPrediction;
  int classifyCalls = 0;

  _MockTier1Classifier(this.nextPrediction);

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

class _MockTier2Recognizer implements OpenVocabularyFoodRecognizer {
  OpenVocabularyRecognitionResult nextResult;
  int recognizeCalls = 0;

  _MockTier2Recognizer(this.nextResult);

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
  }) async =>
      null;
}

class _MockImagePickerService implements IFoodImagePickerService {
  String? nextPath = 'test_device_image.jpg';

  @override
  Future<String?> pickImage(FoodImagePickSource source) async => nextPath;

  @override
  Future<Uint8List?> getImageBytes(String path) async =>
      Uint8List.fromList([1, 2, 3, 4, 5]);

  void clearRetainedImage() {}
}

class _MockNutritionRepository implements INutritionRepository {
  final List<NutritionRecordEntity> savedRecords = [];

  @override
  Future<void> addRecord(String uid, NutritionRecordEntity record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {}

  @override
  Future<List<NutritionRecordEntity>> getRecords(String uid) async => savedRecords;

  @override
  Stream<List<NutritionRecordEntity>> streamRecords(String uid) => Stream.value(savedRecords);

  @override
  Future<void> updateRecord(String uid, NutritionRecordEntity record) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<FoodEntity> catalog =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  final resolver = UniversalNutritionResolver();
  final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  group('Phase 35.13.1 — Section A & C: Device Route Reproduction & Model Disagreement', () {
    test('1. Exact Samsung device log pattern: TFLite Sambar (0.608) vs SigLIP Sushi (0.1015) flags cross-model disagreement and low margin', () async {
      // Replicate captured Samsung Galaxy M34 log:
      // TFLite: predefined_sambar, confidence 0.608
      // SigLIP: predefined_sushi (0.1015) vs openvocab_kimbap_roll (0.0948), margin = 0.0067
      const tier1Sambar = LocalFoodPrediction(
        foodId: 'predefined_sambar',
        foodName: 'Sambar',
        confidence: 0.608,
        inferenceDurationMs: 18,
        topCandidates: [
          LocalFoodCandidate(foodId: 'predefined_sambar', foodName: 'Sambar', confidence: 0.608),
          LocalFoodCandidate(foodId: 'predefined_rasam', foodName: 'Rasam', confidence: 0.220),
        ],
      );

      final tier2SushiResult = OpenVocabularyRecognitionResult.accepted(
        topCandidates: const [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'predefined_sushi',
            canonicalName: 'Sushi',
            category: 'Japanese Cuisine',
            similarity: 0.1015,
            rank: 1,
            inFitFuelCatalog: false,
          ),
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'openvocab_kimbap_roll',
            canonicalName: 'Kimbap Roll',
            category: 'Korean Cuisine',
            similarity: 0.0948,
            rank: 2,
            inFitFuelCatalog: false,
          ),
        ],
        maxFoodSimilarity: 0.1015,
        maxNegSimilarity: -0.0100,
        negMargin: 0.1115,
        preprocessMs: 10,
        encoderMs: 500,
        retrievalMs: 2,
        totalMs: 512,
      );

      final router = FoodScanRecognitionRouter(
        localClassifier: _MockTier1Classifier(tier1Sambar),
        openVocabularyRecognizer: _MockTier2Recognizer(tier2SushiResult),
        remoteDataSource: _SpyRemoteDataSource(),
        universalNutritionResolver: resolver,
        config: const FoodScanRouterConfig(
          highConfidenceThreshold: 0.70,
          minimumConfidenceMargin: 0.15,
          openVocabSingleResultSimThreshold: 0.08,
          openVocabSingleResultMarginThreshold: 0.015, // margin 0.0067 is below this
        ),
      );

      final decision = await router.routeFreeFirst(
        requestId: 'scan_device_1',
        imagePath: 'device_test.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      // Must NOT route to single confirmed result because margin is low AND cross-model disagreement exists
      expect(decision, isA<Tier2OpenVocabSuggestionsAvailable>());
      final suggestionsDecision = decision as Tier2OpenVocabSuggestionsAvailable;

      // Primary candidate is Sushi
      expect(suggestionsDecision.candidates.first.canonicalName, equals('Sushi'));

      // Alternatives must contain both Kimbap Roll and Sambar (Tier 1 prediction surfaced for recovery)
      final altNames = suggestionsDecision.candidates.map((c) => c.canonicalName).toList();
      expect(altNames, contains('Kimbap Roll'));
      expect(altNames, contains('Sambar'));
    });

    test('2. Weak SigLIP prediction is not silently marked as confirmed', () async {
      const gate = SingleResultReliabilityGate(
        config: FoodScanRouterConfig(
          openVocabSingleResultSimThreshold: 0.08,
          openVocabSingleResultMarginThreshold: 0.015,
        ),
      );

      final tier2Ambiguous = OpenVocabularyRecognitionResult.accepted(
        topCandidates: const [
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'c1',
            canonicalName: 'Dish A',
            category: 'Soup',
            similarity: 0.082,
            rank: 1,
          ),
          OpenVocabularyFoodCandidate(
            canonicalFoodId: 'c2',
            canonicalName: 'Dish B',
            category: 'Rice',
            similarity: 0.080,
            rank: 2,
          ),
        ],
        maxFoodSimilarity: 0.082,
        maxNegSimilarity: -0.0100,
        negMargin: 0.092,
        preprocessMs: 10,
        encoderMs: 500,
        retrievalMs: 2,
        totalMs: 512,
      );

      final eval = gate.evaluate(tier2Ambiguous);
      expect(eval.isReliable, isFalse);
      expect(eval.reason, contains('ambiguous_margin'));
    });
  });

  group('Phase 35.13.1 — Section B: Nutrition Resolution & Portion Consistency', () {
    test('3. UniversalNutritionResolver resolves Sushi (predefined_sushi) to USDA generic baseline with all 4 macros', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_sushi',
        canonicalName: 'Sushi',
        category: 'Japanese Cuisine',
        similarity: 0.1015,
        rank: 1,
      );

      final resolved = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolved.hasNutrition, isTrue);
      expect(resolved.tier, equals(NutritionProfileTier.closelyRelatedGeneric));
      expect(resolved.matchedCatalogFood, isNotNull);

      final food = resolved.matchedCatalogFood!;
      expect(food.name, equals('Sushi'));
      expect(food.calories, equals(143.0));
      expect(food.protein, equals(4.0));
      expect(food.carbohydrates, equals(27.0));
      expect(food.fats, equals(1.8));
      expect(food.servingSize, equals(100.0));
      expect(food.servingUnit, equals('g'));
    });

    test('4. Unknown food without profile produces unavailable tier without fabricating values', () {
      const candidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'openvocab_exotic_space_dish',
        canonicalName: 'Exotic Space Dish',
        category: 'Alien',
        similarity: 0.09,
        rank: 1,
      );

      final resolved = resolver.resolveCandidate(candidate, foodCatalog: catalog);
      expect(resolved.hasNutrition, isFalse);
      expect(resolved.tier, equals(NutritionProfileTier.unavailable));
      expect(resolved.matchedCatalogFood, isNull);
    });

    test('5. Portion changes recalculate all 4 macros consistently and match saved diary record', () async {
      const sushiCandidate = OpenVocabularyFoodCandidate(
        canonicalFoodId: 'predefined_sushi',
        canonicalName: 'Sushi',
        category: 'Japanese Cuisine',
        similarity: 0.1015,
        rank: 1,
      );
      final resolved = resolver.resolveCandidate(sushiCandidate, foodCatalog: catalog);

      final detected = DetectedFoodCandidate(
        id: 'candidate_1',
        detectedName: 'Sushi',
        confidence: 0.1015,
        estimatedAmount: 100.0,
        originalEstimatedAmount: 100.0,
        estimatedUnit: 'g',
        matchedFood: resolved.matchedCatalogFood,
        matchConfidence: 0.85,
        visualNotes: 'Generic Baseline',
        aiEstimatedNutrition: null,
        recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
        isUserConfirmed: true,
        nutritionTier: resolved.tier,
      );

      // 100g base check
      expect(detected.scaledCalories, equals(143.0));
      expect(detected.scaledProtein, equals(4.0));
      expect(detected.scaledCarbs, equals(27.0));
      expect(detected.scaledFats, equals(1.8));

      // Scale to 150g portion
      final scaled = detected.copyWith(estimatedAmount: 150.0);
      expect(scaled.scaledCalories, closeTo(214.5, 0.01));
      expect(scaled.scaledProtein, closeTo(6.0, 0.01));
      expect(scaled.scaledCarbs, closeTo(40.5, 0.01));
      expect(scaled.scaledFats, closeTo(2.7, 0.01));

      // Test food diary persistence consistency
      final nutritionRepo = _MockNutritionRepository();
      final controller = FoodScanController(
        repository: FoodScanRepositoryImpl(
          remoteDataSource: _SpyRemoteDataSource(),
        ),
        imagePickerService: _MockImagePickerService(),
      );

      controller.state = FoodScanSuccess(
        result: FoodScanResult(
          id: 'test_scan_sushi',
          imagePath: 'sushi.jpg',
          foods: [scaled],
          overallConfidence: 0.1015,
          scannedAt: DateTime.now(),
        ),
      );

      final logged = await controller.logToDiary('user_123', nutritionRepo);
      expect(logged, isTrue);
      expect(nutritionRepo.savedRecords.length, equals(1));

      final saved = nutritionRepo.savedRecords.first;
      expect(saved.foodName, equals('Sushi'));
      expect(saved.servingSize, equals(150.0));
      expect(saved.calories, closeTo(214.5, 0.01));
      expect(saved.protein, closeTo(6.0, 0.01));
      expect(saved.carbohydrates, closeTo(40.5, 0.01));
      expect(saved.fats, closeTo(2.7, 0.01));
    });
  });

  group('Phase 35.13.1 — Section D & Presentation: Single Primary Candidate & Distinct Empty States', () {
    testWidgets('6. Suggestions screen renders ONE primary candidate with collapsed alternatives accordion', (tester) async {
      const candidates = [
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'predefined_sushi',
          canonicalName: 'Sushi',
          category: 'Japanese Cuisine',
          similarity: 0.1015,
          rank: 1,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'openvocab_kimbap_roll',
          canonicalName: 'Kimbap Roll',
          category: 'Korean Cuisine',
          similarity: 0.0948,
          rank: 2,
        ),
        OpenVocabularyFoodCandidate(
          canonicalFoodId: 'predefined_sambar',
          canonicalName: 'Sambar',
          category: 'Indian Curry',
          similarity: 0.0850,
          rank: 3,
        ),
      ];

      final suggestionsState = FoodScanSuggestions(
        imagePath: 'test.jpg',
        imageBytes: dummyBytes,
        suggestions: const [],
        openVocabSuggestions: candidates,
        openVocabPresentation: const OpenVocabPresentationDecision(
          mode: OpenVocabPresentationMode.ambiguousTop3,
          margin12: 0.0067,
          reason: 'ambiguous_margin',
        ),
        isOtherMatchesExpanded: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith(
              (ref) => Stream.value(_FakeUser()),
            ),
            networkStatusProvider.overrideWith(
              (ref) => Stream.value(NetworkStatus.online),
            ),
            foodScanControllerProvider.overrideWith((ref) {
              final c = FoodScanController(
                repository: FoodScanRepositoryImpl(
                  remoteDataSource: _SpyRemoteDataSource(),
                ),
                imagePickerService: _MockImagePickerService(),
              );
              c.state = suggestionsState;
              return c;
            }),
          ],
          child: const MaterialApp(
            home: FoodScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Primary candidate is rendered as the main prominent button
      expect(find.text('Sushi'), findsOneWidget);
      expect(find.text('Possible Match'), findsOneWidget);

      // Alternatives ("Kimbap Roll", "Sambar") should NOT be visible initially as competing buttons
      expect(find.byKey(const Key('expansion_alternative_matches')), findsOneWidget);
      expect(find.text('Wrong food? Choose another'), findsOneWidget);
      expect(find.text('Kimbap Roll'), findsNothing);
      expect(find.text('Sambar'), findsNothing);

      // Expanding the accordion reveals the alternatives
      await tester.tap(find.text('Wrong food? Choose another'));
      await tester.pumpAndSettle();

      expect(find.text('Kimbap Roll'), findsOneWidget);
      expect(find.text('Sambar'), findsOneWidget);
    });

    testWidgets('7. Invalid image produces distinct unreadable or invalid image state', (tester) async {
      const invalidImageState = FoodScanNoFoodDetected(
        imagePath: 'blank.jpg',
        reason: NoFoodReason.invalidImage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith(
              (ref) => Stream.value(_FakeUser()),
            ),
            networkStatusProvider.overrideWith(
              (ref) => Stream.value(NetworkStatus.online),
            ),
            foodScanControllerProvider.overrideWith((ref) {
              final c = FoodScanController(
                repository: FoodScanRepositoryImpl(
                  remoteDataSource: _SpyRemoteDataSource(),
                ),
                imagePickerService: _MockImagePickerService(),
              );
              c.state = invalidImageState;
              return c;
            }),
          ],
          child: const MaterialApp(
            home: FoodScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unreadable or Invalid Image'), findsOneWidget);
      expect(find.text('The photo was too blurry, dark, or unreadable. Please take a clear, well-lit photo of your meal.'), findsOneWidget);
      expect(find.text('No Food Detected'), findsNothing);
    });

    testWidgets('8. Model unavailable produces distinct scanner unavailable state', (tester) async {
      const modelUnavailableState = FoodScanNoFoodDetected(
        imagePath: 'food.jpg',
        reason: NoFoodReason.modelUnavailable,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith(
              (ref) => Stream.value(_FakeUser()),
            ),
            networkStatusProvider.overrideWith(
              (ref) => Stream.value(NetworkStatus.online),
            ),
            foodScanControllerProvider.overrideWith((ref) {
              final c = FoodScanController(
                repository: FoodScanRepositoryImpl(
                  remoteDataSource: _SpyRemoteDataSource(),
                ),
                imagePickerService: _MockImagePickerService(),
              );
              c.state = modelUnavailableState;
              return c;
            }),
          ],
          child: const MaterialApp(
            home: FoodScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food Scanner Unavailable'), findsOneWidget);
      expect(find.text('The on-device recognition model could not be initialized or encountered an error. You can search FitFuel foods or try again.'), findsOneWidget);
      expect(find.text('No Food Detected'), findsNothing);
    });
  });
}
