import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/data/services/open_vocabulary_model_asset_provider_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/siglip_open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/data/services/tflite_food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';

/// No-op remote datasource used during local device validation to guarantee and
/// verify that zero cloud calls occur during normal two-tier local scanning.
class _ZeroCloudRemoteDataSource implements IFoodScanRemoteDataSource {
  int analyzeCallCount = 0;

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
    String? requestId,
  }) async {
    analyzeCallCount++;
    throw UnsupportedError(
      'Cloud AI must never be invoked during local Phase 35.11B validation.',
    );
  }

  @override
  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  }) async {
    analyzeCallCount++;
    return null;
  }
}

/// Real-device validation runner for Phase 35.11B (SM-E346B / RZCW8201QBV).
///
/// Activated ONLY in debug mode when MainActivity receives intent extra
/// `--es validate_35_11b "true"`.
class Phase3511BDeviceValidator {
  static const MethodChannel _channel = MethodChannel(
    'fitfuel/open_vocab_food_recognizer',
  );
  static bool _attached = false;
  static bool _running = false;

  static void attachIfDebug() {
    if (!kDebugMode || kIsWeb || _attached) return;
    _attached = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerValidation') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final shouldRun = args?['shouldRun'] == true;
        final mode = (args?['mode'] as String?) ?? 'online';
        final valDir = (args?['validationDir'] as String?) ?? '';
        if (shouldRun && !_running) {
          await _runValidationSuite(mode: mode, validationDir: valDir);
        }
      }
      return null;
    });

    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        final cfg = await _channel.invokeMapMethod<String, dynamic>(
          'getValidationConfig',
        );
        if (cfg != null && cfg['shouldRun'] == true && !_running) {
          final mode = (cfg['mode'] as String?) ?? 'online';
          final valDir = (cfg['validationDir'] as String?) ?? '';
          await _runValidationSuite(mode: mode, validationDir: valDir);
        }
      } catch (_) {
        // Ignore on non-Android or when not validating.
      }
    });
  }

  static Future<Map<String, dynamic>> _getDiagnostics() async {
    final diag = await _channel.invokeMapMethod<String, dynamic>(
      'getDeviceDiagnostics',
    );
    return diag ?? const <String, dynamic>{};
  }

  static int _percentile(List<int> sortedValues, double p) {
    if (sortedValues.isEmpty) return 0;
    final idx = ((sortedValues.length - 1) * p).round().clamp(
      0,
      sortedValues.length - 1,
    );
    return sortedValues[idx];
  }

  static Future<void> _runValidationSuite({
    required String mode,
    required String validationDir,
  }) async {
    _running = true;
    try {
      debugPrint(
        '[PHASE_35_11B_VALIDATION] === START PHASE 35.11B REAL-DEVICE VALIDATION (mode=$mode) ===',
      );

      final assetProvider = PlatformOpenVocabularyModelAssetProvider();
      final siglipRecognizer = SiglipOpenVocabularyFoodRecognizer(
        assetProvider: assetProvider,
      );

      // Ensure any previous session is disposed before measuring baseline memory
      await siglipRecognizer.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final memBeforeTier2 = await _getDiagnostics();
      debugPrint(
        '[PHASE_35_11B_VALIDATION] MEM_BEFORE_TIER2_LOAD '
        'pssMb=${memBeforeTier2['pssMb']} '
        'rssMb=${memBeforeTier2['rssMb']} '
        'nativeHeapMb=${memBeforeTier2['nativeHeapMb']} '
        'sessionLoaded=${memBeforeTier2['sessionLoaded']} '
        'networkActive=${memBeforeTier2['networkActive']} '
        'device=${memBeforeTier2['deviceModel']} '
        'sdk=${memBeforeTier2['sdkInt']} '
        'abi=${memBeforeTier2['abi']}',
      );

      final List<FoodEntity> fullCatalog = PredefinedFoodData.foods
          .map((m) => m.toEntity())
          .toList();
      final tfliteClassifier = TfliteFoodVisionClassifier();
      final remoteStub = _ZeroCloudRemoteDataSource();

      final router = FoodScanRecognitionRouter(
        localClassifier: tfliteClassifier,
        openVocabularyRecognizer: siglipRecognizer,
        remoteDataSource: remoteStub,
      );

      final isOfflineMode = mode == 'offline';

      Future<Uint8List> loadImage(String name) async {
        final f = File('$validationDir/$name');
        if (!await f.exists()) {
          throw StateError('Validation image missing: ${f.path}');
        }
        return f.readAsBytes();
      }

      // -----------------------------------------------------------------------
      // SCENARIO 1A: Trusted Tier 1 Auto-Local 8-Class Check (food_0221 / food_0249 / food_0289)
      // Verifies Tier 1 runs before Tier 2 is loaded when an 8-class allow-listed food passes.
      // -----------------------------------------------------------------------
      for (final t1File in ['food_0221.jpg', 'food_0249.jpg', 'food_0289.jpg']) {
        final f = File('$validationDir/$t1File');
        if (!await f.exists()) continue;
        final t1Bytes = await f.readAsBytes();
        final t1Pred = await tfliteClassifier.classify(t1Bytes);
        final inAllowList = kDefaultFoodScanRouterConfig
                .productionEnabledFoodIds
                ?.contains(t1Pred.foodId) ??
            false;
        final shouldAutoAccept = inAllowList &&
            t1Pred.isConfident(
              threshold: kDefaultFoodScanRouterConfig.highConfidenceThreshold,
              minMargin:
                  kDefaultFoodScanRouterConfig.minimumConfidenceMargin,
            );
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_1A_TIER1_ALLOWLIST file=$t1File '
          'tier1Id=${t1Pred.foodId} '
          'tier1Name="${t1Pred.foodName}" '
          'tier1Conf=${t1Pred.confidence.toStringAsFixed(4)} '
          'tier1Margin=${t1Pred.confidenceMargin.toStringAsFixed(4)} '
          'inAllowList=$inAllowList '
          'autoAccept=$shouldAutoAccept '
          'tier2SessionLoaded=${(await _getDiagnostics())['sessionLoaded']}',
        );
        if (shouldAutoAccept) {
          final s1aDecision = await router.routeFreeFirst(
            imagePath: '$validationDir/$t1File',
            imageBytes: t1Bytes,
            foodCatalog: fullCatalog,
            requestId: 'val_s1a_${t1File}_$mode',
            isOffline: isOfflineMode,
          );
          final memAfterS1a = await _getDiagnostics();
          debugPrint(
            '[PHASE_35_11B_VALIDATION] SCENARIO_1A_TRUSTED_TIER1 '
            'file=$t1File '
            'decision=${s1aDecision.runtimeType} '
            'tier1Id=${s1aDecision.prediction?.foodId} '
            'tier1Name="${s1aDecision.prediction?.foodName}" '
            'tier1Conf=${s1aDecision.prediction?.confidence.toStringAsFixed(4)} '
            'tier1Ms=${s1aDecision.prediction?.inferenceDurationMs} '
            'tier2Invoked=${router.tier2Invoked} '
            'tier2SessionLoaded=${memAfterS1a['sessionLoaded']} '
            'cloudCalls=${router.cloudCallsThisScan} '
            'networkActive=${memAfterS1a['networkActive']}',
          );
          break;
        }
      }

      // -----------------------------------------------------------------------
      // SCENARIO 1B: Poha Regression Check (food_0021.jpg - Vegetable Biryani)
      // V5 predicts predefined_poha (0.938), which MUST be rejected by Tier-1's
      // 8-class allow-list and escalated to Tier-2 SigLIP (Vegetable Biryani).
      // -----------------------------------------------------------------------
      final pohaBytes = await loadImage('food_0021.jpg');
      final s1Decision = await router.routeFreeFirst(
        imagePath: '$validationDir/food_0021.jpg',
        imageBytes: pohaBytes,
        foodCatalog: fullCatalog,
        requestId: 'val_s1b_poha_regression_$mode',
        isOffline: isOfflineMode,
      );
      final memAfterS1 = await _getDiagnostics();
      if (s1Decision is Tier2OpenVocabSuggestionsAvailable) {
        final pd = s1Decision.presentationDecision;
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_1B_POHA_REGRESSION_FIX '
          'decision=${s1Decision.runtimeType} '
          'tier1RejectedId=${s1Decision.prediction?.foodId} '
          'tier1Conf=${s1Decision.prediction?.confidence.toStringAsFixed(4)} '
          'tier2Primary="${pd?.primaryCandidate?.displayName}" '
          'presentationMode=${pd?.modeName} '
          'presentationReason=${pd?.reason} '
          'sameFamily=${pd?.isSameCulinaryFamily} '
          'cloudCalls=${router.cloudCallsThisScan} '
          'networkActive=${memAfterS1['networkActive']}',
        );
      }

      // -----------------------------------------------------------------------
      // SCENARIO 2: Creamy Penne Pasta (food_0468.jpg) - Primary With Alternatives UX
      // -----------------------------------------------------------------------
      final pastaBytes = await loadImage('food_0468.jpg');
      final s2Decision = await router.routeFreeFirst(
        imagePath: '$validationDir/food_0468.jpg',
        imageBytes: pastaBytes,
        foodCatalog: fullCatalog,
        requestId: 'val_s2_pasta_$mode',
        isOffline: isOfflineMode,
      );
      final memAfterTier2Load = await _getDiagnostics();
      debugPrint(
        '[PHASE_35_11B_VALIDATION] MEM_AFTER_TIER2_LOAD '
        'pssMb=${memAfterTier2Load['pssMb']} '
        'rssMb=${memAfterTier2Load['rssMb']} '
        'nativeHeapMb=${memAfterTier2Load['nativeHeapMb']} '
        'sessionLoaded=${memAfterTier2Load['sessionLoaded']}',
      );

      if (s2Decision is Tier2OpenVocabSuggestionsAvailable) {
        final top3Names = s2Decision.candidates
            .map((c) => c.displayName)
            .join(' | ');
        final ov = s2Decision.openVocabResult;
        final pd = s2Decision.presentationDecision;
        final altNames = pd?.alternativeCandidates
                .map((c) => c.displayName)
                .join(' | ') ??
            '';
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_2_PASTA_SCAN '
          'decision=${s2Decision.runtimeType} '
          'presentationMode=${pd?.modeName} '
          'primaryFood="${pd?.primaryCandidate?.displayName}" '
          'collapsedAlternatives="$altNames" '
          'sameFamily=${pd?.isSameCulinaryFamily} '
          'presentationReason=${pd?.reason} '
          'tier1Top1=${s2Decision.prediction?.foodId} '
          'tier1Conf=${s2Decision.prediction?.confidence.toStringAsFixed(4)} '
          'tier1Ms=${s2Decision.tier1DurationMs} '
          'tier2Top3="$top3Names" '
          'tier2Sim=${ov.topSimilarity.toStringAsFixed(4)} '
          'tier2NegSim=${ov.negativeSimilarity.toStringAsFixed(4)} '
          'tier2NegMargin=${ov.negativeMargin.toStringAsFixed(4)} '
          'tier2ColdInitMs=${ov.modelLoadMs} '
          'tier2PreprocessMs=${ov.preprocessMs} '
          'tier2EncoderMs=${ov.encoderMs} '
          'tier2RetrievalMs=${ov.retrievalMs} '
          'tier2TotalMs=${ov.totalMs} '
          'cloudCalls=${router.cloudCallsThisScan}',
        );

        // User confirms Creamy Penne Pasta (Case B: no exact FitFuel 238 match -> must NOT fake nutrition)
        final confirmedPasta = router.confirmOpenVocabCandidate(
          candidate: s2Decision.candidates.first,
          foodCatalog: fullCatalog,
          imagePath: '$validationDir/food_0468.jpg',
          requestId: 'val_s2_pasta_confirm_$mode',
          localInferenceDurationMs: s2Decision.localInferenceDurationMs,
          allCandidates: s2Decision.candidates,
          top1CanonicalId: s2Decision.candidates.first.canonicalFoodId,
          scanSessionId: 'val_s2_pasta_$mode',
        );
        final confirmedCandidate = confirmedPasta.foods.first;

        // Then user picks Standard Pasta (Cooked) (`predefined_standard_pasta`) via manual search fallback
        final pastaEntity = fullCatalog.firstWhere(
          (f) => f.id == 'predefined_standard_pasta',
          orElse: () => fullCatalog.first,
        );
        final manualPasta = router.recordManualSelection(
          food: pastaEntity,
          imagePath: '$validationDir/food_0468.jpg',
          requestId: 'val_s2_pasta_manual_$mode',
          scanSessionId: 'val_s2_pasta_manual_$mode',
        );
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_2_PASTA_CONFIRM '
          'confirmedSource=${confirmedPasta.recognitionSource.name} '
          'confirmedBadge="${confirmedPasta.sourceBadgeLabel}" '
          'confirmedDetail="${confirmedPasta.secondarySourceDetail}" '
          'confirmedIsLowConfidence=${confirmedCandidate.isLowConfidence} '
          'confirmedFood="${confirmedCandidate.displayName}" '
          'confirmedNutritionAvailable=${confirmedCandidate.hasNutrition} '
          'confirmedMatchedFood=${confirmedCandidate.matchedFood?.id} '
          'manualSelectedFood="${manualPasta.foods.first.displayName}" '
          'manualFoodId=${manualPasta.foods.first.matchedFood?.id} '
          'manualKcal=${manualPasta.foods.first.calories} '
          'manualHasNutrition=${manualPasta.foods.first.hasNutrition} '
          'cloudCalls=${remoteStub.analyzeCallCount}',
        );
      }

      // -----------------------------------------------------------------------
      // SCENARIO 3A: Unseen-to-V5 Food - Burger (food_0009.jpg) - Primary With Alternatives
      // -----------------------------------------------------------------------
      final burgerBytes = await loadImage('food_0009.jpg');
      final s3BurgerDecision = await router.routeFreeFirst(
        imagePath: '$validationDir/food_0009.jpg',
        imageBytes: burgerBytes,
        foodCatalog: fullCatalog,
        requestId: 'val_s3a_burger_$mode',
        isOffline: isOfflineMode,
      );
      if (s3BurgerDecision is Tier2OpenVocabSuggestionsAvailable) {
        final burgerTop3 = s3BurgerDecision.candidates
            .map((c) => c.displayName)
            .join(' | ');
        final ov = s3BurgerDecision.openVocabResult;
        final pd = s3BurgerDecision.presentationDecision;
        final confirmedBurger = router.confirmOpenVocabCandidate(
          candidate: s3BurgerDecision.candidates.first,
          foodCatalog: fullCatalog,
          imagePath: '$validationDir/food_0009.jpg',
          requestId: 'val_s3a_burger_confirm_$mode',
          localInferenceDurationMs: s3BurgerDecision.localInferenceDurationMs,
          allCandidates: s3BurgerDecision.candidates,
          top1CanonicalId: s3BurgerDecision.candidates.first.canonicalFoodId,
          scanSessionId: 'val_s3a_burger_$mode',
        );
        final burgerFood = confirmedBurger.foods.first;
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_3A_BURGER '
          'decision=${s3BurgerDecision.runtimeType} '
          'presentationMode=${pd?.modeName} '
          'primaryFood="${pd?.primaryCandidate?.displayName}" '
          'sameFamily=${pd?.isSameCulinaryFamily} '
          'tier1Top1=${s3BurgerDecision.prediction?.foodId} '
          'tier1Conf=${s3BurgerDecision.prediction?.confidence.toStringAsFixed(4)} '
          'tier2Top3="$burgerTop3" '
          'tier2Sim=${ov.topSimilarity.toStringAsFixed(4)} '
          'tier2NegMargin=${ov.negativeMargin.toStringAsFixed(4)} '
          'tier2TotalMs=${ov.totalMs} '
          'confirmedSource=${confirmedBurger.recognitionSource.name} '
          'confirmedFood="${burgerFood.displayName}" '
          'matchedFoodId=${burgerFood.matchedFood?.id} '
          'kcal=${burgerFood.calories} '
          'hasNutrition=${burgerFood.hasNutrition} '
          'cloudCalls=${router.cloudCallsThisScan}',
        );
      }

      // -----------------------------------------------------------------------
      // SCENARIO 3B: Low-Confidence V5 Samosa Rescued by Tier 2 (food_0275.jpg) + Exact FitFuel 238 Confirmation
      // -----------------------------------------------------------------------
      final samosaBytes = await loadImage('food_0275.jpg');
      final s3SamosaDecision = await router.routeFreeFirst(
        imagePath: '$validationDir/food_0275.jpg',
        imageBytes: samosaBytes,
        foodCatalog: fullCatalog,
        requestId: 'val_s3b_samosa_rescue_$mode',
        isOffline: isOfflineMode,
      );
      if (s3SamosaDecision is Tier2OpenVocabSuggestionsAvailable) {
        final samosaTop3 = s3SamosaDecision.candidates
            .map((c) => c.displayName)
            .join(' | ');
        final ov = s3SamosaDecision.openVocabResult;
        final pd = s3SamosaDecision.presentationDecision;
        final confirmedSamosa = router.confirmOpenVocabCandidate(
          candidate: s3SamosaDecision.candidates.first,
          foodCatalog: fullCatalog,
          imagePath: '$validationDir/food_0275.jpg',
          requestId: 'val_s3b_samosa_confirm_$mode',
          localInferenceDurationMs: s3SamosaDecision.localInferenceDurationMs,
          allCandidates: s3SamosaDecision.candidates,
          top1CanonicalId: s3SamosaDecision.candidates.first.canonicalFoodId,
          scanSessionId: 'val_s3b_samosa_rescue_$mode',
        );
        final samosaFood = confirmedSamosa.foods.first;
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_3B_SAMOSA_RESCUE '
          'decision=${s3SamosaDecision.runtimeType} '
          'presentationMode=${pd?.modeName} '
          'primaryFood="${pd?.primaryCandidate?.displayName}" '
          'tier2Top3="$samosaTop3" '
          'confirmedSource=${confirmedSamosa.recognitionSource.name} '
          'confirmedFood="${samosaFood.displayName}" '
          'matchedFoodId=${samosaFood.matchedFood?.id} '
          'kcal=${samosaFood.calories} '
          'proteinG=${samosaFood.protein} '
          'carbsG=${samosaFood.carbs} '
          'fatG=${samosaFood.fats} '
          'hasNutrition=${samosaFood.hasNutrition} '
          'tier2TotalMs=${ov.totalMs} '
          'cloudCalls=${router.cloudCallsThisScan}',
        );
      }

      // -----------------------------------------------------------------------
      // SCENARIO 3C: Ambiguous Confusable Regional Siblings - Pizza (food_0003.jpg) -> ambiguousTop3
      // -----------------------------------------------------------------------
      final pizzaBytes = await loadImage('food_0003.jpg');
      final s3PizzaDecision = await router.routeFreeFirst(
        imagePath: '$validationDir/food_0003.jpg',
        imageBytes: pizzaBytes,
        foodCatalog: fullCatalog,
        requestId: 'val_s3c_pizza_ambiguous_$mode',
        isOffline: isOfflineMode,
      );
      if (s3PizzaDecision is Tier2OpenVocabSuggestionsAvailable) {
        final pizzaTop3 = s3PizzaDecision.candidates
            .map((c) => c.displayName)
            .join(' | ');
        final pd = s3PizzaDecision.presentationDecision;
        debugPrint(
          '[PHASE_35_11B_VALIDATION] SCENARIO_3C_AMBIGUOUS_PIZZA '
          'decision=${s3PizzaDecision.runtimeType} '
          'presentationMode=${pd?.modeName} '
          'presentationReason=${pd?.reason} '
          'hasConfusableSiblings=${pd?.hasConfusableSiblings} '
          'tier2Top3="$pizzaTop3" '
          'cloudCalls=${router.cloudCallsThisScan}',
        );
      }

      // -----------------------------------------------------------------------
      // SCENARIO 4: Non-Food Images (non_food_laptop.jpg & non_food_empty_plate.jpg)
      // -----------------------------------------------------------------------
      for (final nfFile in ['non_food_laptop.jpg', 'non_food_empty_plate.jpg']) {
        final nfBytes = await loadImage(nfFile);
        final nfDecision = await router.routeFreeFirst(
          imagePath: '$validationDir/$nfFile',
          imageBytes: nfBytes,
          foodCatalog: fullCatalog,
          requestId: 'val_s4_${nfFile}_$mode',
          isOffline: isOfflineMode,
        );
        if (nfDecision is Tier2AbstainedNonFood) {
          final ov = nfDecision.openVocabResult;
          debugPrint(
            '[PHASE_35_11B_VALIDATION] SCENARIO_4_NON_FOOD file=$nfFile '
            'decision=${nfDecision.runtimeType} '
            'isNonFoodRejected=${ov.isNonFoodRejected} '
            'tier2Accepted=${ov.accepted} '
            'tier2Sim=${ov.topSimilarity.toStringAsFixed(4)} '
            'tier2NegSim=${ov.negativeSimilarity.toStringAsFixed(4)} '
            'tier2NegMargin=${ov.negativeMargin.toStringAsFixed(4)} '
            'tier2TotalMs=${ov.totalMs} '
            'cloudCalls=${router.cloudCallsThisScan}',
          );
        } else {
          debugPrint(
            '[PHASE_35_11B_VALIDATION] SCENARIO_4_NON_FOOD file=$nfFile '
            'decision=${nfDecision.runtimeType} '
            'cloudCalls=${router.cloudCallsThisScan}',
          );
        }
      }

      // -----------------------------------------------------------------------
      // SCENARIO 5: 10 Warm Repeated Scans (Tier 2 Open-Vocabulary)
      // -----------------------------------------------------------------------
      final warmFiles = <String>[
        'food_0468.jpg', // Creamy Penne Pasta
        'food_0009.jpg', // Burger
        'food_0003.jpg', // Cheese Pizza
        'food_0075.jpg', // Ramen
        'food_0303.jpg', // Butter Chicken
        'food_0046.jpg', // Sushi
        'food_0061.jpg', // Tacos
        'food_0477.jpg', // Spaghetti
        'food_0472.jpg', // Pasta Alfredo
        'food_0466.jpg', // Penne Pasta
      ];
      final warmTier2Ms = <int>[];
      final warmEndToEndMs = <int>[];
      for (var i = 0; i < warmFiles.length; i++) {
        final bytes = await loadImage(warmFiles[i]);
        final sw = Stopwatch()..start();
        final wDecision = await router.routeFreeFirst(
          imagePath: '$validationDir/${warmFiles[i]}',
          imageBytes: bytes,
          foodCatalog: fullCatalog,
          requestId: 'val_s5_warm_${i + 1}_$mode',
          isOffline: isOfflineMode,
        );
        sw.stop();
        int t2Ms = sw.elapsedMilliseconds;
        String top1Name = 'unknown';
        String pMode = 'n/a';
        if (wDecision is Tier2OpenVocabSuggestionsAvailable) {
          t2Ms = wDecision.openVocabResult.totalMs;
          top1Name = wDecision.candidates.first.displayName;
          pMode = wDecision.presentationDecision?.modeName ?? 'n/a';
        }
        warmTier2Ms.add(t2Ms);
        warmEndToEndMs.add(sw.elapsedMilliseconds);
        debugPrint(
          '[PHASE_35_11B_VALIDATION] WARM_SCAN_${i + 1} '
          'file=${warmFiles[i]} '
          'tier1Ms=${wDecision.prediction?.inferenceDurationMs} '
          'tier2Ms=$t2Ms '
          'endToEndMs=${sw.elapsedMilliseconds} '
          'top1="$top1Name" '
          'presentationMode=$pMode '
          'cloudCalls=${router.cloudCallsThisScan}',
        );
      }

      final sortedTier2 = List<int>.from(warmTier2Ms)..sort();
      final sortedE2E = List<int>.from(warmEndToEndMs)..sort();
      final memAfter10Warm = await _getDiagnostics();
      debugPrint(
        '[PHASE_35_11B_VALIDATION] SCENARIO_5_WARM_SUMMARY '
        'count=${warmFiles.length} '
        'tier2P50Ms=${_percentile(sortedTier2, 0.50)} '
        'tier2P95Ms=${_percentile(sortedTier2, 0.95)} '
        'tier2MinMs=${sortedTier2.first} '
        'tier2MaxMs=${sortedTier2.last} '
        'e2eP50Ms=${_percentile(sortedE2E, 0.50)} '
        'e2eP95Ms=${_percentile(sortedE2E, 0.95)} '
        'tier2SinglePrimary=${router.tier2SinglePrimary} '
        'tier2PrimaryWithAlternatives=${router.tier2PrimaryWithAlternatives} '
        'tier2AmbiguousTop3=${router.tier2AmbiguousTop3} '
        'pssMb=${memAfter10Warm['pssMb']} '
        'rssMb=${memAfter10Warm['rssMb']} '
        'nativeHeapMb=${memAfter10Warm['nativeHeapMb']} '
        'cloudCalls=${remoteStub.analyzeCallCount}',
      );

      // -----------------------------------------------------------------------
      // LIFECYCLE DISPOSAL CHECK: Leaving FoodScanScreen -> disposeTier2Session()
      // -----------------------------------------------------------------------
      await router.disposeTier2Session();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final memAfterDispose = await _getDiagnostics();
      debugPrint(
        '[PHASE_35_11B_VALIDATION] MEM_AFTER_LEAVE_FOOD_SCAN_SCREEN '
        'pssMb=${memAfterDispose['pssMb']} '
        'rssMb=${memAfterDispose['rssMb']} '
        'nativeHeapMb=${memAfterDispose['nativeHeapMb']} '
        'sessionLoaded=${memAfterDispose['sessionLoaded']}',
      );

      debugPrint(
        '[PHASE_35_11B_VALIDATION] === COMPLETED PHASE 35.11B REAL-DEVICE VALIDATION (mode=$mode, totalCloudCalls=${remoteStub.analyzeCallCount}) ===',
      );
    } catch (e, st) {
      debugPrint('[PHASE_35_11B_VALIDATION] ERROR: $e\n$st');
    } finally {
      _running = false;
    }
  }
}
