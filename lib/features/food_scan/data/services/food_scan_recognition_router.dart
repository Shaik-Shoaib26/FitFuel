import 'package:flutter/foundation.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_remote_datasource.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/food_matcher.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_route_decision.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_telemetry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_recognition_cascade.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_scan_router_config.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_vision_classifier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';

export 'package:fitfuel/features/food_scan/domain/entities/food_scan_route_decision.dart';

/// Central hybrid & free-first routing engine orchestrating Tier-1 On-Device Food Classification
/// (`fitfuel_food_v5`), Tier-2 On-Device Open-Vocabulary Food Recognition (`SigLIP-B/16 INT8`),
/// Local Top-K Suggestions, User Confirmation, Manual Catalog Search, and optional Gemini fallback.
class FoodScanRecognitionRouter {
  final FoodVisionClassifier _localClassifier;
  final IFoodScanRemoteDataSource _remoteDataSource;
  final OpenVocabularyFoodRecognizer? _openVocabularyRecognizer;
  final FoodScanRouterConfig _config;
  final FoodScanTelemetrySink? _telemetrySink;
  final FoodRecognitionCascade _cascade;

  /// Exposed for diagnostic & device validation inspection.
  FoodRecognitionCascade get cascade => _cascade;

  /// Cached O(1) lookup map of canonical FitFuel predefined catalog entities.
  static final Map<String, FoodEntity> _canonicalCatalogById = {
    for (final model in PredefinedFoodData.foods) model.id: model.toEntity(),
  };

  // Phase 35.9 & 35.10 event counters (in-memory diagnostics)
  int _totalScans = 0;
  int _autoLocalAccepted = 0;
  int _localSuggestionShown = 0;
  int _unreliableSuggestionSuppressed = 0;
  int _noReliableLocalMatch = 0;
  int _localSuggestionConfirmed = 0;
  int _localSuggestionTop1Confirmed = 0;
  int _manualSearchUsed = 0;
  int _geminiRequested = 0;
  int _geminiSucceeded = 0;
  int _geminiQuotaFailure = 0;
  int _geminiServiceFailure = 0;

  // Phase 35.11B Two-Tier Open-Vocabulary counters
  int _tier2Invoked = 0;
  int _tier2SuggestionsShown = 0;
  int _tier2SinglePrimary = 0;
  int _tier2PrimaryWithAlternatives = 0;
  int _tier2AmbiguousTop3 = 0;
  int _tier2Confirmed = 0;
  int _tier2ConfirmedTop1 = 0;
  int _tier2ConfirmedExactCatalogMatch = 0;
  int _tier2ConfirmedNeedsNutritionSelection = 0;
  int _tier2AbstainedNonFood = 0;
  int _tier2NoReliableMatch = 0;
  int _tier2UnavailableFallback = 0;

  // Phase 35.11B.1 Single-Result counters
  int _tier2SingleResult = 0;
  int _tier2SingleResultWithNutrition = 0;
  int _tier2SingleResultRequiresNutrition = 0;
  int _tier2AmbiguousAbstain = 0;

  // Phase 35.10.1 Free-First Routing Lock & Mutually Exclusive Completion Tracking
  String _activeScanSessionId = 'scan_0';
  int _cloudCallsThisScan = 0;
  bool _lastUserRequestedAi = false;
  final Map<String, FoodScanCompletionRoute> _completedScanRoutesBySession = {};
  final List<String> _debugRouteLogs = [];
  final List<String> _debugSafetyLogs = [];
  final List<String> _debugCascadeLogs = [];
  final List<String> _debugPresentationLogs = [];
  final List<String> _debugSingleResultLogs = [];
  final List<String> _debugPerfLogs = [];
  final List<String> _debugAiLogs = [];
  final List<String> _debugAssertionWarnings = [];

  final SingleResultReliabilityGate _singleResultGate;
  final UniversalNutritionResolver _universalNutritionResolver;

  FoodScanRecognitionRouter({
    required FoodVisionClassifier localClassifier,
    required IFoodScanRemoteDataSource remoteDataSource,
    OpenVocabularyFoodRecognizer? openVocabularyRecognizer,
    FoodScanRouterConfig config = kDefaultFoodScanRouterConfig,
    FoodScanTelemetrySink? telemetrySink,
    UniversalNutritionResolver? universalNutritionResolver,
  })  : _localClassifier = localClassifier,
        _remoteDataSource = remoteDataSource,
        _openVocabularyRecognizer = openVocabularyRecognizer,
        _config = config,
        _telemetrySink = telemetrySink,
        _cascade = FoodRecognitionCascade(config: config),
        _singleResultGate = SingleResultReliabilityGate(config: config),
        _universalNutritionResolver =
            universalNutritionResolver ?? UniversalNutritionResolver();

  FoodScanRouterConfig get config => _config;
  OpenVocabularyFoodRecognizer? get openVocabularyRecognizer =>
      _openVocabularyRecognizer;
  SingleResultReliabilityGate get singleResultGate => _singleResultGate;
  UniversalNutritionResolver get universalNutritionResolver =>
      _universalNutritionResolver;

  /// Evaluates the centralized Phase 35.11B.1 Strict Single-Result Reliability Gate.
  SingleResultReliabilityDecision evaluateSingleResultReliability(
    OpenVocabularyRecognitionResult result, {
    List<FoodEntity> foodCatalog = const [],
    bool isMixedMealSuspected = false,
    LocalFoodPrediction? tier1Prediction,
  }) =>
      _singleResultGate.evaluate(
        result,
        foodCatalog: foodCatalog,
        isMixedMealSuspected: isMixedMealSuspected,
        tier1Prediction: tier1Prediction,
      );

  /// Evaluates the centralized Phase 35.11B.1 Smart Single-Result UX presentation gate.
  OpenVocabPresentationDecision evaluateOpenVocabPresentation(
    OpenVocabularyRecognitionResult result, {
    List<FoodEntity> foodCatalog = const [],
  }) =>
      _cascade.evaluateOpenVocabPresentation(
        result,
        foodCatalog: foodCatalog,
      );

  /// True if Tier 2 (`SigLIP-B/16`) is configured, available, and its native session is not yet loaded.
  bool get tier2RequiresColdInit =>
      _config.enableOpenVocabularyTier2 &&
      _openVocabularyRecognizer != null &&
      _openVocabularyRecognizer.isAvailable &&
      _openVocabularyRecognizer.requiresColdInit;

  /// Disposes the Tier-2 open-vocabulary session when leaving `FoodScanScreen`.
  Future<void> disposeTier2Session() async {
    await _openVocabularyRecognizer?.dispose();
  }

  int get totalScans => _totalScans;
  int get autoLocalAccepted => _autoLocalAccepted;
  int get tier1AutoAccepted => _autoLocalAccepted;
  int get localSuggestionShown => _localSuggestionShown;
  int get reliableSuggestionShown => _localSuggestionShown;
  int get unreliableSuggestionSuppressed => _unreliableSuggestionSuppressed;
  int get noReliableLocalMatch => _noReliableLocalMatch;
  int get localSuggestionConfirmed => _localSuggestionConfirmed;
  int get suggestionConfirmed => _localSuggestionConfirmed + _tier2Confirmed;
  int get localSuggestionTop1Confirmed => _localSuggestionTop1Confirmed;
  int get manualSearchUsed => _manualSearchUsed;
  int get manualConfirmed => _manualSearchUsed;
  int get geminiRequested => _geminiRequested;
  int get geminiSucceeded => _geminiSucceeded;
  int get geminiQuotaFailure => _geminiQuotaFailure;
  int get geminiServiceFailure => _geminiServiceFailure;

  // Phase 35.11B / 35.11B.1 Tier-2 getters
  int get tier2Invoked => _tier2Invoked;
  int get tier2SuggestionsShown => _tier2SuggestionsShown;
  int get tier2SinglePrimary => _tier2SinglePrimary;
  int get tier2PrimaryWithAlternatives => _tier2PrimaryWithAlternatives;
  int get tier2AmbiguousTop3 => _tier2AmbiguousTop3;
  int get tier2Confirmed => _tier2Confirmed;
  int get tier2ConfirmedTop1 => _tier2ConfirmedTop1;
  int get tier2ConfirmedExactCatalogMatch => _tier2ConfirmedExactCatalogMatch;
  int get tier2ConfirmedNeedsNutritionSelection =>
      _tier2ConfirmedNeedsNutritionSelection;
  int get tier2AbstainedNonFood => _tier2AbstainedNonFood;
  int get tier2NoReliableMatch => _tier2NoReliableMatch;
  int get tier2UnavailableFallback => _tier2UnavailableFallback;

  // Phase 35.11B.1 Single-Result getters
  int get tier2SingleResult => _tier2SingleResult;
  int get tier2SingleResultWithNutrition => _tier2SingleResultWithNutrition;
  int get tier2SingleResultRequiresNutrition =>
      _tier2SingleResultRequiresNutrition;
  int get tier2AmbiguousAbstain => _tier2AmbiguousAbstain;
  List<String> get debugSingleResultLogs =>
      List.unmodifiable(_debugSingleResultLogs);
  String? get lastSingleResultLog =>
      _debugSingleResultLogs.isNotEmpty ? _debugSingleResultLogs.last : null;

  /// Phase 35.10.1 per-scan cloud call counter & user consent state.
  String get activeScanSessionId => _activeScanSessionId;
  int get cloudCallsThisScan => _cloudCallsThisScan;
  bool get lastUserRequestedAi => _lastUserRequestedAi;
  List<String> get debugRouteLogs => List.unmodifiable(_debugRouteLogs);
  String? get lastRouteLog =>
      _debugRouteLogs.isNotEmpty ? _debugRouteLogs.last : null;
  List<String> get debugSafetyLogs => List.unmodifiable(_debugSafetyLogs);
  String? get lastSafetyLog =>
      _debugSafetyLogs.isNotEmpty ? _debugSafetyLogs.last : null;
  List<String> get debugCascadeLogs => List.unmodifiable(_debugCascadeLogs);
  String? get lastCascadeLog =>
      _debugCascadeLogs.isNotEmpty ? _debugCascadeLogs.last : null;
  List<String> get debugPresentationLogs =>
      List.unmodifiable(_debugPresentationLogs);
  String? get lastPresentationLog =>
      _debugPresentationLogs.isNotEmpty ? _debugPresentationLogs.last : null;
  List<String> get debugPerfLogs => List.unmodifiable(_debugPerfLogs);
  String? get lastPerfLog =>
      _debugPerfLogs.isNotEmpty ? _debugPerfLogs.last : null;
  List<String> get debugAiLogs => List.unmodifiable(_debugAiLogs);
  List<String> get debugAssertionWarnings =>
      List.unmodifiable(_debugAssertionWarnings);

  /// Phase 35.10.1 / 35.11B mutually exclusive completion counters (each scan gets at most ONE final completion route).
  int get autoLocalCompleted => _completedScanRoutesBySession.values
      .where((r) => r == FoodScanCompletionRoute.autoLocal)
      .length;

  int get suggestionConfirmedCompleted => _completedScanRoutesBySession.values
      .where((r) => r == FoodScanCompletionRoute.suggestionConfirmed)
      .length;

  int get openVocabConfirmedCompleted => _completedScanRoutesBySession.values
      .where((r) => r == FoodScanCompletionRoute.openVocabConfirmed)
      .length;

  int get manualConfirmedCompleted => _completedScanRoutesBySession.values
      .where((r) => r == FoodScanCompletionRoute.manualConfirmed)
      .length;

  int get geminiCompleted => _completedScanRoutesBySession.values
      .where((r) => r == FoodScanCompletionRoute.geminiCompleted)
      .length;

  FoodScanCompletionRoute? completionRouteForScan(String scanId) =>
      _completedScanRoutesBySession[scanId];

  Map<String, FoodScanCompletionRoute> get completedScanRoutes =>
      Map.unmodifiable(_completedScanRoutesBySession);

  /// Backward-compatible getters for Phase 35.9 tests.
  int get localSuccessfulScans => _autoLocalAccepted;
  int get cloudFallbackScans => _geminiRequested;

  /// Scans completed without Gemini (mutually exclusive: autoLocal + suggestionConfirmed + openVocabConfirmed + manualConfirmed).
  int get freeCompletedScans =>
      autoLocalCompleted +
      suggestionConfirmedCompleted +
      openVocabConfirmedCompleted +
      manualConfirmedCompleted;

  /// Total scans completed across all free and cloud paths (mutually exclusive per scan).
  int get totalCompletedScans => freeCompletedScans + geminiCompleted;

  /// Ratio of scans resolved automatically on-device without cloud quota consumption.
  double get cloudAvoidanceRate =>
      _totalScans > 0 ? _autoLocalAccepted / _totalScans : 0.0;

  /// Phase 35.10 / 35.11B rate metrics:
  double get autoLocalRate =>
      _totalScans > 0 ? autoLocalCompleted / _totalScans : 0.0;

  double get suggestionConfirmedRate => _totalScans > 0
      ? (suggestionConfirmedCompleted + openVocabConfirmedCompleted) /
          _totalScans
      : 0.0;

  double get manualSearchRate =>
      _totalScans > 0 ? manualConfirmedCompleted / _totalScans : 0.0;

  double get geminiUsageRate =>
      _totalScans > 0 ? _geminiRequested / _totalScans : 0.0;

  /// Primary Phase 35.10 / 35.10.1 / 35.11B metric:
  /// (autoLocalCompleted + suggestionConfirmedCompleted + openVocabConfirmedCompleted + manualConfirmedCompleted) / totalCompletedScans
  double get freeCompletionRate =>
      totalCompletedScans > 0 ? freeCompletedScans / totalCompletedScans : 0.0;

  void resetMetrics() {
    _totalScans = 0;
    _autoLocalAccepted = 0;
    _localSuggestionShown = 0;
    _unreliableSuggestionSuppressed = 0;
    _noReliableLocalMatch = 0;
    _localSuggestionConfirmed = 0;
    _localSuggestionTop1Confirmed = 0;
    _manualSearchUsed = 0;
    _geminiRequested = 0;
    _geminiSucceeded = 0;
    _geminiQuotaFailure = 0;
    _geminiServiceFailure = 0;
    _tier2Invoked = 0;
    _tier2SuggestionsShown = 0;
    _tier2SinglePrimary = 0;
    _tier2PrimaryWithAlternatives = 0;
    _tier2AmbiguousTop3 = 0;
    _tier2Confirmed = 0;
    _tier2ConfirmedTop1 = 0;
    _tier2ConfirmedExactCatalogMatch = 0;
    _tier2ConfirmedNeedsNutritionSelection = 0;
    _tier2AbstainedNonFood = 0;
    _tier2NoReliableMatch = 0;
    _tier2UnavailableFallback = 0;
    _tier2SingleResult = 0;
    _tier2SingleResultWithNutrition = 0;
    _tier2SingleResultRequiresNutrition = 0;
    _tier2AmbiguousAbstain = 0;
    _activeScanSessionId = 'scan_0';
    _cloudCallsThisScan = 0;
    _lastUserRequestedAi = false;
    _completedScanRoutesBySession.clear();
    _debugRouteLogs.clear();
    _debugSafetyLogs.clear();
    _debugCascadeLogs.clear();
    _debugPresentationLogs.clear();
    _debugSingleResultLogs.clear();
    _debugPerfLogs.clear();
    _debugAiLogs.clear();
    _debugAssertionWarnings.clear();
  }

  String _resolveSessionKey(String requestId, {String? scanSessionId}) {
    if (scanSessionId != null && scanSessionId.isNotEmpty) {
      return scanSessionId;
    }
    if (_activeScanSessionId != 'scan_0') {
      return _activeScanSessionId;
    }
    return requestId;
  }

  void _emitRouteLog(String line) {
    _debugRouteLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitSafetyLog(String line) {
    _debugSafetyLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitCascadeLog(String line) {
    _debugCascadeLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitPresentationLog(String line) {
    _debugPresentationLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitSingleResultLog(String line) {
    _debugSingleResultLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitPerfLog(String line) {
    _debugPerfLogs.add(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void _emitAiLog(String line) {
    _debugAiLogs.add(line);
    LoggerService.info(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  /// Semantic food group lookup for the 50 FitFuel V1/V5 local classes.
  /// Used by [evaluateSuggestionReliability] to detect coherent neighborhoods vs
  /// contradictory cross-category OOV guesses (e.g. Pineapple + Grilled Chicken Breast).
  static String _semanticCategoryForFoodId(String foodId) {
    switch (foodId) {
      case 'predefined_apple':
      case 'predefined_banana':
      case 'predefined_orange':
      case 'predefined_mango':
      case 'predefined_papaya':
      case 'predefined_watermelon':
      case 'predefined_pineapple':
      case 'predefined_grapes':
      case 'predefined_guava':
      case 'predefined_strawberry':
        return 'fruit';

      case 'predefined_idli':
      case 'predefined_dosa':
      case 'predefined_uttapam':
      case 'predefined_poha':
      case 'predefined_upma':
      case 'predefined_medu_vada':
      case 'predefined_samosa':
        return 'indian_savory';

      case 'predefined_steamed_rice':
      case 'predefined_brown_rice_ind':
      case 'predefined_chapati':
      case 'predefined_roti':
      case 'predefined_oats':
      case 'predefined_whole_wheat_bread':
        return 'grain_staple';

      case 'predefined_hard_boiled_eggs':
      case 'predefined_egg_omelette':
      case 'predefined_scrambled_eggs':
      case 'predefined_grilled_chicken_breast':
      case 'predefined_tandoori_chicken':
      case 'predefined_ind_paneer':
      case 'predefined_firm_tofu':
      case 'predefined_paneer_tikka':
        return 'protein_savory';

      case 'predefined_low_fat_milk':
      case 'predefined_curd':
      case 'predefined_greek_yogurt_plain':
      case 'predefined_coconut_water':
        return 'dairy_beverage';

      case 'predefined_dal_tadka':
      case 'predefined_chole_masala':
      case 'predefined_rajma_curry':
      case 'predefined_moong_dal':
      case 'predefined_sambar':
        return 'curry_legume';

      case 'predefined_potato':
      case 'predefined_tomato':
      case 'predefined_carrot':
      case 'predefined_broccoli':
      case 'predefined_cauliflower':
      case 'predefined_cucumber':
      case 'predefined_spinach':
      case 'predefined_capsicum':
      case 'predefined_onion':
        return 'vegetable';

      case 'predefined_almonds':
        return 'nut_snack';

      default:
        return 'other';
    }
  }

  /// True when two candidate classes belong to the same or a visually proximate culinary neighborhood
  /// (e.g. Idli + Dosa + Upma, Paneer Tikka + Tandoori Chicken, Dal Tadka + Chole Masala).
  static bool _areCandidatesSemanticallyCoherent(String idA, String idB) {
    final catA = _semanticCategoryForFoodId(idA);
    final catB = _semanticCategoryForFoodId(idB);
    if (catA == 'other' || catB == 'other') return true;
    if (catA == catB) return true;

    final pair = {catA, catB};
    const compatiblePairs = <Set<String>>[
      {'indian_savory', 'grain_staple'},
      {'indian_savory', 'curry_legume'},
      {'indian_savory', 'vegetable'},
      {'protein_savory', 'curry_legume'},
      {'protein_savory', 'dairy_beverage'},
      {'protein_savory', 'indian_savory'},
      {'curry_legume', 'vegetable'},
      {'curry_legume', 'grain_staple'},
      {'grain_staple', 'dairy_beverage'},
    ];
    for (final allowed in compatiblePairs) {
      if (allowed.length == pair.length && allowed.containsAll(pair)) {
        return true;
      }
    }
    return false;
  }

  /// True when two candidate classes come from incompatible visual/culinary domains
  /// (e.g. raw fruit paired with cooked meat/chicken/eggs/curry/grain), signaling an OOV guess.
  static bool _areCandidatesWildlyUnrelated(String idA, String idB) {
    final catA = _semanticCategoryForFoodId(idA);
    final catB = _semanticCategoryForFoodId(idB);
    if (catA == catB || catA == 'other' || catB == 'other') return false;
    return !_areCandidatesSemanticallyCoherent(idA, idB);
  }

  /// Returns true when all candidate dishes represent close culinary variants of the same
  /// underlying dish (e.g. Masala Dosa vs Plain Dosa, Cheese Pizza vs Margherita Pizza).
  static bool _areCloseVariantsOfSameDish(
      List<OpenVocabularyFoodCandidate> candidates) {
    if (candidates.length < 2) return true;
    final top1Name = candidates.first.canonicalName.toLowerCase();
    final top1Id = candidates.first.canonicalFoodId.toLowerCase();

    const dishRoots = [
      'dosa',
      'biryani',
      'curry',
      'burger',
      'pizza',
      'rice',
      'dal',
      'paratha',
      'sandwich',
      'pasta',
      'salad',
      'soup',
      'noodles',
      'khichdi',
      'pulao',
      'omelette',
      'idli',
      'vada',
      'roti',
      'chapati',
      'naan',
      'wrap',
      'taco',
    ];

    for (final root in dishRoots) {
      if ((top1Name.contains(root) || top1Id.contains(root)) &&
          candidates.skip(1).every((c) =>
              c.canonicalName.toLowerCase().contains(root) ||
              c.canonicalFoodId.toLowerCase().contains(root))) {
        return true;
      }
    }
    return false;
  }

  /// Extracts candidates meeting [minimumSuggestionConfidence], mapped to canonical FitFuel names,
  /// prior to suggestion-set OOV reliability gating.
  List<LocalFoodCandidate> _extractCandidateListAboveMinimum(
    LocalFoodPrediction? prediction, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    if (prediction == null || !prediction.isModelAvailable) {
      return const [];
    }

    final Map<String, FoodEntity> catalogById = {
      ..._canonicalCatalogById,
      for (final item in foodCatalog) item.id: item,
    };

    final rawCandidates = prediction.topCandidates.isNotEmpty
        ? prediction.topCandidates
        : (prediction.foodId.isNotEmpty
            ? [
                LocalFoodCandidate(
                  foodId: prediction.foodId,
                  foodName: prediction.foodName,
                  confidence: prediction.confidence,
                ),
              ]
            : const <LocalFoodCandidate>[]);

    final Map<String, LocalFoodCandidate> deduplicated = {};

    for (final candidate in rawCandidates) {
      final id = candidate.foodId.trim();
      if (id.isEmpty) continue;

      // Must be in the 50 model classes if supportedFoodIds is configured
      if (_config.supportedFoodIds.isNotEmpty &&
          !_config.supportedFoodIds.contains(id)) {
        continue;
      }

      // Must meet centralized minimumSuggestionConfidence
      if (candidate.confidence < _config.minimumSuggestionConfidence) {
        continue;
      }

      // Must resolve to a valid PredefinedFoodData / FitFuel catalog entry
      final catalogFood = catalogById[id] ?? _canonicalCatalogById[id];
      if (catalogFood == null) continue;

      final existing = deduplicated[id];
      if (existing == null || candidate.confidence > existing.confidence) {
        deduplicated[id] = LocalFoodCandidate(
          foodId: id,
          foodName: catalogFood.name, // Always use canonical FitFuel food name
          confidence: candidate.confidence,
        );
      }
    }

    final sorted = deduplicated.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return sorted.take(_config.maxCandidates).toList();
  }

  /// Phase 35.10.3 centralized OOV suggestion-set reliability evaluator.
  /// Evaluates Top-1 confidence, Top-1 vs Top-2 margin, and candidate semantic consistency.
  SuggestionReliabilityEvaluation evaluateSuggestionReliability(
    LocalFoodPrediction? prediction, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    if (prediction == null || !prediction.isModelAvailable) {
      return const SuggestionReliabilityEvaluation(
        isReliable: false,
        reason: 'model_unavailable',
        top1Confidence: 0.0,
        margin: 0.0,
        candidates: [],
      );
    }

    final candidates = _extractCandidateListAboveMinimum(
      prediction,
      foodCatalog: foodCatalog,
    );

    final top1 = candidates.isNotEmpty
        ? candidates.first.confidence
        : prediction.confidence;
    final double top2;
    if (candidates.length >= 2) {
      top2 = candidates[1].confidence;
    } else if (prediction.topCandidates.length >= 2) {
      top2 = prediction.topCandidates[1].confidence;
    } else {
      top2 = 0.0;
    }
    final margin = (top1 - top2).clamp(0.0, 1.0);

    if (candidates.isEmpty) {
      return SuggestionReliabilityEvaluation(
        isReliable: false,
        reason: 'below_minimum_suggestion_confidence',
        top1Confidence: top1,
        margin: margin,
        candidates: const [],
      );
    }

    // 1. Hard minimum floor: flat/weak distribution (e.g. Pasta -> Pineapple 0.22, Grilled Chicken 0.18)
    if (top1 < _config.coherentNeighborhoodMinTop1) {
      final hasUnrelatedConflict = candidates.length >= 2 &&
          _areCandidatesWildlyUnrelated(
            candidates[0].foodId,
            candidates[1].foodId,
          );
      final reason = margin < _config.suggestionReliabilityMargin
          ? 'low_confidence_low_margin'
          : (hasUnrelatedConflict
              ? 'unrelated_candidate_categories'
              : 'low_top1_confidence');
      return SuggestionReliabilityEvaluation(
        isReliable: false,
        reason: reason,
        top1Confidence: top1,
        margin: margin,
        candidates: candidates,
      );
    }

    // 2. Cross-category OOV contradiction check:
    // If Top-1 and Top-2 are from wildly unrelated categories (e.g. Pineapple + Grilled Chicken Breast)
    // and Top-1 is below 0.65, suppress suggestions as an unreliable OOV guess.
    if (candidates.length >= 2 &&
        top1 < 0.65 &&
        _areCandidatesWildlyUnrelated(
          candidates[0].foodId,
          candidates[1].foodId,
        )) {
      return SuggestionReliabilityEvaluation(
        isReliable: false,
        reason: 'unrelated_candidate_categories',
        top1Confidence: top1,
        margin: margin,
        candidates: candidates,
      );
    }

    // 3. Strong Top-1 confidence and clear margin
    if (top1 >= _config.suggestionReliabilityThreshold &&
        margin >= _config.suggestionReliabilityMargin) {
      return SuggestionReliabilityEvaluation(
        isReliable: true,
        reason: 'confident_top1_and_margin',
        top1Confidence: top1,
        margin: margin,
        candidates: candidates,
      );
    }

    // 4. Coherent multi-candidate food neighborhood (e.g. Idli + Dosa + Upma or Paneer Tikka + Tandoori Chicken)
    if (candidates.length >= 2 &&
        _areCandidatesSemanticallyCoherent(
          candidates[0].foodId,
          candidates[1].foodId,
        ) &&
        top1 >= _config.coherentNeighborhoodMinTop1 &&
        (top1 + top2) >= 0.50) {
      return SuggestionReliabilityEvaluation(
        isReliable: true,
        reason: 'coherent_food_neighborhood',
        top1Confidence: top1,
        margin: margin,
        candidates: candidates,
      );
    }

    return SuggestionReliabilityEvaluation(
      isReliable: false,
      reason: margin < _config.suggestionReliabilityMargin
          ? 'low_confidence_low_margin'
          : 'low_top1_confidence',
      top1Confidence: top1,
      margin: margin,
      candidates: candidates,
    );
  }

  /// Phase 35.10.3 centralized predicate: returns true if and only if the prediction's
  /// Top-K suggestion set is reliable enough to display to the user.
  bool isReliableSuggestionSet(
    LocalFoodPrediction? prediction, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    return evaluateSuggestionReliability(
      prediction,
      foodCatalog: foodCatalog,
    ).isReliable;
  }

  /// Filters, deduplicates, validates against [PredefinedFoodData] / [foodCatalog],
  /// maps to canonical FitFuel names, sorts descending by confidence, and limits to Top-K.
  /// When [enforceReliability] is true (default), suppresses unreliable OOV suggestion sets.
  List<LocalFoodCandidate> extractTopKSuggestions(
    LocalFoodPrediction? prediction, {
    List<FoodEntity> foodCatalog = const [],
    bool enforceReliability = true,
  }) {
    if (!enforceReliability) {
      return _extractCandidateListAboveMinimum(
        prediction,
        foodCatalog: foodCatalog,
      );
    }
    final evaluation = evaluateSuggestionReliability(
      prediction,
      foodCatalog: foodCatalog,
    );
    return evaluation.isReliable ? evaluation.candidates : const [];
  }

  /// Phase 35.10 / 35.11B Two-Tier Free-First routing method:
  /// Runs Tier-1 (`fitfuel_food_v5`) fast trusted auto-local check first; if Tier 1
  /// does not qualify for trusted auto-local acceptance, invokes Tier-2 (`SigLIP-B/16 INT8`)
  /// open-vocabulary recognition and safety gating before any V5 suggestion fallback.
  /// Always completes with ZERO Gemini calls.
  Future<FoodScanRouteDecision> routeFreeFirst({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    required String requestId,
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  }) async {
    _totalScans++;
    _activeScanSessionId = requestId;
    _cloudCallsThisScan = 0;
    _lastUserRequestedAi = false;

    final effectiveCatalog = foodCatalog.isNotEmpty
        ? foodCatalog
        : _canonicalCatalogById.values.toList();

    LocalFoodPrediction? localPrediction;
    int localInferenceDurationMs = 0;

    final isLocalEnabled =
        _config.enableOnDeviceFoodRecognition && _localClassifier.isAvailable;

    if (!isLocalEnabled) {
      // If Tier 1 is unavailable, check if Tier 2 open-vocabulary is available before failing
      if (_config.enableOpenVocabularyTier2 &&
          _openVocabularyRecognizer != null &&
          _openVocabularyRecognizer.isAvailable) {
        final tier2Decision = await _runTier2Cascade(
          requestId: requestId,
          imagePath: imagePath,
          imageBytes: imageBytes,
          effectiveCatalog: effectiveCatalog,
          tier1Prediction: null,
          tier1DurationMs: 0,
          tier1Top1Id: 'none',
          isOffline: isOffline,
        );
        if (tier2Decision != null) {
          return tier2Decision;
        }
      }

      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=no_local_match model=none top1=none score=0.000 confidence=0.000 margin=0.000 threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=uncertain top3=none cloud_calls=0',
      );
      return LocalModelUnavailable(
        requestId: requestId,
        imagePath: imagePath,
        reason: 'On-device classifier model is unavailable or disabled.',
        isOffline: isOffline,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      localPrediction = await _localClassifier.classify(imageBytes);
      stopwatch.stop();
      localInferenceDurationMs = stopwatch.elapsedMilliseconds;
    } catch (e, stackTrace) {
      stopwatch.stop();
      LoggerService.warning('Local inference threw unexpected exception: $e');
      LoggerService.warning('$stackTrace');
      localPrediction = LocalFoodPrediction.unavailable(reason: e.toString());
    }

    if (!localPrediction.isModelAvailable) {
      if (_config.enableOpenVocabularyTier2 &&
          _openVocabularyRecognizer != null &&
          _openVocabularyRecognizer.isAvailable) {
        final tier2Decision = await _runTier2Cascade(
          requestId: requestId,
          imagePath: imagePath,
          imageBytes: imageBytes,
          effectiveCatalog: effectiveCatalog,
          tier1Prediction: localPrediction,
          tier1DurationMs: localInferenceDurationMs,
          tier1Top1Id: 'none',
          isOffline: isOffline,
        );
        if (tier2Decision != null) {
          return tier2Decision;
        }
      }

      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=no_local_match model=none top1=none score=0.000 confidence=0.000 margin=0.000 threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=uncertain top3=none cloud_calls=0',
      );
      return LocalModelUnavailable(
        requestId: requestId,
        imagePath: imagePath,
        reason: localPrediction.failureReason ??
            'On-device classifier model is unavailable.',
        prediction: localPrediction,
        localInferenceDurationMs: localInferenceDurationMs,
        isOffline: isOffline,
      );
    }

    final rawTop3Summary = localPrediction.topCandidates.isNotEmpty
        ? localPrediction.topCandidates
            .take(3)
            .map((c) => '${c.foodId}:${c.confidence.toStringAsFixed(2)}')
            .join(',')
        : (localPrediction.foodId.isNotEmpty
            ? '${localPrediction.foodId}:${localPrediction.confidence.toStringAsFixed(2)}'
            : 'none');
    final top1Id =
        localPrediction.foodId.isNotEmpty ? localPrediction.foodId : 'none';

    // Check if mixed meal is suspected before auto-local acceptance
    if (isMixedMealSuspected || localPrediction.isMixedMealSuspected) {
      final suggestions = extractTopKSuggestions(
        localPrediction,
        foodCatalog: effectiveCatalog,
        enforceReliability: false,
      );
      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=mixed_manual model=${_config.modelVersion} top1=$top1Id score=${localPrediction.confidence.toStringAsFixed(3)} confidence=${localPrediction.confidence.toStringAsFixed(3)} margin=${localPrediction.confidenceMargin.toStringAsFixed(3)} threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=uncertain candidates=${suggestions.length} top3=$rawTop3Summary cloud_calls=0',
      );
      return MixedMealNeedsDecision(
        requestId: requestId,
        imagePath: imagePath,
        suggestions: suggestions,
        prediction: localPrediction,
        localInferenceDurationMs: localInferenceDurationMs,
        isOffline: isOffline,
      );
    }

    // Evaluate strict V5 auto-local safety rules:
    // class in production-enabled set AND confidence >= 0.85 AND margin >= 0.15
    final isSupported = _config.supportedFoodIds.isEmpty ||
        _config.supportedFoodIds.contains(localPrediction.foodId);

    final isProductionEnabled = _config.productionEnabledFoodIds == null ||
        _config.productionEnabledFoodIds!.isEmpty ||
        _config.productionEnabledFoodIds!.contains(localPrediction.foodId);

    final canUseLocal = isSupported &&
        isProductionEnabled &&
        localPrediction.isConfident(
          threshold: _config.highConfidenceThreshold,
          minMargin: _config.minimumConfidenceMargin,
        );

    if (canUseLocal) {
      final catalogMatch = _findCatalogMatch(localPrediction, effectiveCatalog);
      if (catalogMatch != null) {
        _autoLocalAccepted++;
        _completedScanRoutesBySession[requestId] =
            FoodScanCompletionRoute.autoLocal;

        _emitRouteLog(
          '[FoodScanRoute] request=$requestId route=auto_local model=${_config.modelVersion} food=${catalogMatch.id} top1=$top1Id score=${localPrediction.confidence.toStringAsFixed(3)} confidence=${localPrediction.confidence.toStringAsFixed(3)} margin=${localPrediction.confidenceMargin.toStringAsFixed(3)} threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=accepted top3=$rawTop3Summary cloud_calls=0',
        );
        _emitCascadeLog(
          '[FoodScanCascade] request=$requestId tier1=${_config.modelVersion} tier1_top1=$top1Id tier1_conf=${localPrediction.confidence.toStringAsFixed(3)} tier1_margin=${localPrediction.confidenceMargin.toStringAsFixed(3)} tier1_auto_accepted=true tier2_invoked=false final_route=tier1_auto_local cloud_calls=0',
        );

        final candidate = DetectedFoodCandidate(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          detectedName: catalogMatch.name,
          confidence: localPrediction.confidence,
          estimatedAmount: catalogMatch.servingSize,
          originalEstimatedAmount: catalogMatch.servingSize,
          estimatedUnit: catalogMatch.servingUnit,
          matchedFood: catalogMatch,
          matchConfidence: 1.0,
          visualNotes:
              'Recognized on your device (${(localPrediction.confidence * 100).toStringAsFixed(0)}% confidence)',
          aiEstimatedNutrition: null,
          recognitionSource: FoodScanRecognitionSource.localModel,
          nutritionTier: NutritionProfileTier.verifiedExact,
          nutritionExplanation: 'Curated FitFuel Food Database',
          nutritionAttribution: 'FitFuel Curated Database',
          isUserConfirmed: false,
        );

        _recordTelemetry(
          requestId: requestId,
          model: 'on-device:${_config.modelVersion}',
          durationMs: localInferenceDurationMs,
          imageSizeBytes: imageBytes.length,
          isFallback: false,
          isSuccess: true,
          recognitionSource: FoodScanRecognitionSource.localModel.name,
          route: FoodScanRecognitionSource.localModel.debugRouteLabel,
          localConfidence: localPrediction.confidence,
          localInferenceDurationMs: localInferenceDurationMs,
          cloudFallbackUsed: false,
        );

        final result = FoodScanResult(
          id: requestId,
          imagePath: imagePath,
          foods: [candidate],
          overallConfidence: localPrediction.confidence,
          scannedAt: DateTime.now(),
          recognitionSource: FoodScanRecognitionSource.localModel,
          localConfidence: localPrediction.confidence,
          localInferenceDurationMs: localInferenceDurationMs,
          localCandidates: _extractCandidateListAboveMinimum(
            localPrediction,
            foodCatalog: effectiveCatalog,
          ),
        );

        return LocalAutoAccepted(
          requestId: requestId,
          imagePath: imagePath,
          result: result,
          prediction: localPrediction,
          localInferenceDurationMs: localInferenceDurationMs,
          isOffline: isOffline,
        );
      }
    }

    // Phase 35.11B Section 4:
    // When Tier 1 does NOT qualify for trusted auto-local acceptance, invoke
    // Tier 2 (`SigLIP-B/16 INT8`) open-vocabulary recognition BEFORE any V5
    // suggestion evaluation. Keep V5 suggestions ONLY as a fallback if Tier 2
    // is omitted or unavailable.
    if (_config.enableOpenVocabularyTier2 && _openVocabularyRecognizer != null) {
      final tier2Decision = await _runTier2Cascade(
        requestId: requestId,
        imagePath: imagePath,
        imageBytes: imageBytes,
        effectiveCatalog: effectiveCatalog,
        tier1Prediction: localPrediction,
        tier1DurationMs: localInferenceDurationMs,
        tier1Top1Id: top1Id,
        isOffline: isOffline,
      );
      if (tier2Decision != null) {
        return tier2Decision;
      }
    }

    // Fallback: Tier 2 is not configured or unavailable -> evaluate V5 safe suggestions
    final evaluation = evaluateSuggestionReliability(
      localPrediction,
      foodCatalog: effectiveCatalog,
    );

    final rawTop = localPrediction.topCandidates;
    final safetyTop1 = rawTop.isNotEmpty ? rawTop[0].foodId : top1Id;
    final safetyTop2 = rawTop.length >= 2 ? rawTop[1].foodId : 'none';
    final safetyTop3 = rawTop.length >= 3 ? rawTop[2].foodId : 'none';

    _emitSafetyLog(
      '[FoodScanSafety] top1=$safetyTop1 top2=$safetyTop2 top3=$safetyTop3 confidence=${evaluation.top1Confidence.toStringAsFixed(3)} margin=${evaluation.margin.toStringAsFixed(3)} reliableSuggestions=${evaluation.isReliable} reason=${evaluation.reason}',
    );

    if (evaluation.isReliable && evaluation.candidates.isNotEmpty) {
      _localSuggestionShown++;
      final suggestions = evaluation.candidates;
      final top3Summary = suggestions
          .map((c) => '${c.foodId}:${c.confidence.toStringAsFixed(2)}')
          .join(',');
      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=local_suggestion model=${_config.modelVersion} top1=$top1Id confidence=${localPrediction.confidence.toStringAsFixed(3)} score=${localPrediction.confidence.toStringAsFixed(3)} margin=${evaluation.margin.toStringAsFixed(3)} threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=uncertain candidates=${suggestions.length} top3=$top3Summary cloud_calls=0',
      );
      return LocalSuggestionsAvailable(
        requestId: requestId,
        imagePath: imagePath,
        suggestions: suggestions,
        prediction: localPrediction,
        localInferenceDurationMs: localInferenceDurationMs,
        isOffline: isOffline,
      );
    }

    // Suggestions are empty or suppressed as unreliable OOV guesses
    _noReliableLocalMatch++;
    if (evaluation.candidates.isNotEmpty) {
      _unreliableSuggestionSuppressed++;
    }

    _emitRouteLog(
      '[FoodScanRoute] request=$requestId route=no_reliable_local_match model=${_config.modelVersion} top1=$top1Id confidence=${localPrediction.confidence.toStringAsFixed(3)} score=${localPrediction.confidence.toStringAsFixed(3)} margin=${evaluation.margin.toStringAsFixed(3)} threshold=${_config.highConfidenceThreshold.toStringAsFixed(3)} decision=uncertain candidates=0 top3=$rawTop3Summary cloud_calls=0',
    );
    return NoReliableLocalMatch(
      requestId: requestId,
      imagePath: imagePath,
      reason: evaluation.reason,
      suppressedCandidates: evaluation.candidates,
      prediction: localPrediction,
      localInferenceDurationMs: localInferenceDurationMs,
      isOffline: isOffline,
    );
  }

  /// Executes Tier-2 (`SigLIP-B/16 INT8`) open-vocabulary recognition and safety gating.
  /// Returns `null` if Tier 2 is unavailable so the caller can fall back to V5 safe evaluation.
  Future<FoodScanRouteDecision?> _runTier2Cascade({
    required String requestId,
    required String imagePath,
    required Uint8List imageBytes,
    required List<FoodEntity> effectiveCatalog,
    required LocalFoodPrediction? tier1Prediction,
    required int tier1DurationMs,
    required String tier1Top1Id,
    required bool isOffline,
  }) async {
    final recognizer = _openVocabularyRecognizer;
    if (recognizer == null || !recognizer.isAvailable) {
      _tier2UnavailableFallback++;
      _emitCascadeLog(
        '[FoodScanCascade] tier2_unavailable reason=recognizer_unavailable request=$requestId tier1=${_config.modelVersion} tier1_top1=$tier1Top1Id tier1_auto_accepted=false tier2_invoked=false final_route=tier2_unavailable_fallback cloud_calls=0',
      );
      return null;
    }

    _tier2Invoked++;
    final tier2Stopwatch = Stopwatch()..start();
    final rawResult = await recognizer.recognize(imageBytes);
    tier2Stopwatch.stop();
    final tier2DurationMs = rawResult.totalMs > 0
        ? rawResult.totalMs
        : tier2Stopwatch.elapsedMilliseconds;

    final evaluation = _cascade.evaluateTier2Result(
      rawResult,
      foodCatalog: effectiveCatalog,
      tier1Prediction: tier1Prediction,
    );

    if (evaluation.isUnavailable) {
      _tier2UnavailableFallback++;
      _emitCascadeLog(
        '[FoodScanCascade] tier2_unavailable reason=${evaluation.reason} request=$requestId tier1=${_config.modelVersion} tier1_top1=$tier1Top1Id tier1_auto_accepted=false tier2_invoked=true final_route=tier2_unavailable_fallback cloud_calls=0',
      );
      return null;
    }

    final normalized = evaluation.normalizedResult;
    final tier1Conf = (tier1Prediction?.confidence ?? 0.0).toStringAsFixed(3);
    final tier1Margin =
        (tier1Prediction?.confidenceMargin ?? 0.0).toStringAsFixed(3);

    _emitPerfLog(
      '[FoodScanLocalPerf] request=$requestId tier1_ms=$tier1DurationMs tier2_init_ms=${normalized.modelLoadMs} tier2_preprocess_ms=${normalized.preprocessMs} tier2_encoder_ms=${normalized.encoderMs} tier2_retrieval_ms=${normalized.retrievalMs} tier2_total_ms=$tier2DurationMs session_reused=${normalized.sessionReused}',
    );

    final tier2Top3Summary = evaluation.accepted
        ? evaluation.deduplicatedCandidates
            .map((c) =>
                '${c.canonicalFoodId}:${c.similarity.toStringAsFixed(4)}')
            .join(',')
        : 'suppressed';

    _emitCascadeLog(
      '[FoodScanCascade] request=$requestId tier1=${_config.modelVersion} tier1_top1=$tier1Top1Id tier1_conf=$tier1Conf tier1_margin=$tier1Margin tier1_auto_accepted=false tier2=${normalized.modelId} tier2_invoked=true tier2_top3=$tier2Top3Summary tier2_top_sim=${normalized.topSimilarity.toStringAsFixed(4)} tier2_neg_sim=${normalized.negativeSimilarity.toStringAsFixed(4)} tier2_neg_margin=${normalized.negativeMargin.toStringAsFixed(4)} tier2_accepted=${evaluation.accepted} final_route=${evaluation.route} cloud_calls=0',
    );

    final totalLocalMs = tier1DurationMs + tier2DurationMs;

    if (evaluation.accepted && evaluation.deduplicatedCandidates.isNotEmpty) {
      _tier2SuggestionsShown++;
      _localSuggestionShown++;
      final candidates = evaluation.deduplicatedCandidates;
      final top1Candidate = candidates.first;
      final top2Candidate = candidates.length >= 2 ? candidates[1] : null;
      final top2Id = top2Candidate?.canonicalFoodId ?? 'none';
      final top3Id =
          candidates.length >= 3 ? candidates[2].canonicalFoodId : 'none';
      final presentation = evaluation.presentationDecision ??
          _cascade.evaluateOpenVocabPresentation(
            normalized,
            foodCatalog: effectiveCatalog,
          );

      switch (presentation.mode) {
        case OpenVocabPresentationMode.singlePrimary:
          _tier2SinglePrimary++;
          break;
        case OpenVocabPresentationMode.primaryWithAlternatives:
          _tier2PrimaryWithAlternatives++;
          break;
        case OpenVocabPresentationMode.ambiguousTop3:
          _tier2AmbiguousTop3++;
          break;
      }

      // Phase 35.11B.1 / 35.13.0: Strict Single-Result Reliability Gate & Presentation Gate evaluation
      final singleDecision = _singleResultGate.evaluate(
        normalized,
        foodCatalog: effectiveCatalog,
        tier1Prediction: tier1Prediction,
      );

      final isSameDishVariant = _areCloseVariantsOfSameDish(candidates);
      final shouldPresentSingleResult =
          !singleDecision.isCrossModelDisagreement &&
              (singleDecision.isReliable ||
                  presentation.isSinglePrimary ||
                  (presentation.isPrimaryWithAlternatives && isSameDishVariant));

      if (shouldPresentSingleResult) {
        _tier2SingleResult++;
        final catalogMatch =
            TrustedOpenVocabNutritionMapper.resolveTrustedCatalogFood(
          top1Candidate,
          foodCatalog: effectiveCatalog,
        );

        FoodEntity? resolvedFood = catalogMatch;
        NutritionProfileTier nutritionTier = catalogMatch != null
            ? NutritionProfileTier.verifiedExact
            : NutritionProfileTier.unavailable;
        String? nutritionExplanation = catalogMatch != null
            ? 'Curated FitFuel Food Database'
            : null;
        String? recipeAssumptions;
        String? nutritionAttribution = catalogMatch != null
            ? 'Curated FitFuel Food Database'
            : null;

        if (resolvedFood == null &&
            _config.enableUniversalNutritionResolution) {
          final res = _universalNutritionResolver.resolveCandidate(
            top1Candidate,
            foodCatalog: effectiveCatalog,
          );
          if (res.isVerifiedExact || res.isGenericBaseline) {
            resolvedFood = res.matchedCatalogFood;
            nutritionTier = res.tier;
            nutritionExplanation = res.explanation;
            recipeAssumptions = res.recipeAssumptions;
            nutritionAttribution = res.attribution;
          } else if (res.isRecipeEstimate &&
              top1Candidate.canonicalFoodId != 'openvocab_creamy_penne_pasta') {
            resolvedFood = res.matchedCatalogFood;
            nutritionTier = res.tier;
            nutritionExplanation = res.explanation;
            recipeAssumptions = res.recipeAssumptions;
            nutritionAttribution = res.attribution;
          }
        }

        final hasNutrition =
            resolvedFood != null && nutritionTier != NutritionProfileTier.unavailable;

        if (hasNutrition) {
          _tier2SingleResultWithNutrition++;
          _completedScanRoutesBySession[requestId] =
              FoodScanCompletionRoute.tier2SingleResultWithNutrition;
        } else {
          _tier2SingleResultRequiresNutrition++;
          _completedScanRoutesBySession[requestId] =
              FoodScanCompletionRoute.tier2SingleResultRequiresNutrition;
        }

        final effectiveDecision = singleDecision.isReliable
            ? singleDecision
            : SingleResultReliabilityDecision(
                isReliable: true,
                reason: presentation.reason,
                primaryCandidate: top1Candidate,
                top1Similarity: singleDecision.top1Similarity,
                top2Similarity: singleDecision.top2Similarity,
                margin12: singleDecision.margin12,
                negativeMargin: singleDecision.negativeMargin,
                isSameCulinaryFamily: presentation.isSameCulinaryFamily,
                culinaryFamily: presentation.culinaryFamily,
                isExactCatalogMatch: hasNutrition,
                hasVerifiedAliasMapping: singleDecision.hasVerifiedAliasMapping,
                isCrossModelDisagreement: singleDecision.isCrossModelDisagreement,
                tier1CandidateId: singleDecision.tier1CandidateId,
              );

        _emitSingleResultLog(
          '[FoodScanSingleResult] request=$requestId model=${normalized.modelId} top1=${top1Candidate.canonicalFoodId} top1_sim=${effectiveDecision.top1Similarity.toStringAsFixed(4)} top2=$top2Id top2_sim=${effectiveDecision.top2Similarity.toStringAsFixed(4)} margin=${effectiveDecision.margin12.toStringAsFixed(4)} single_result_reliable=true reason=${effectiveDecision.reason} route=tier2_single_result cloud_calls=0',
        );
        _emitPresentationLog(
          '[FoodScanPresentation] request=$requestId mode=singlePrimary top1=${top1Candidate.canonicalFoodId} top2=$top2Id top3=$top3Id top1_sim=${effectiveDecision.top1Similarity.toStringAsFixed(4)} top2_sim=${effectiveDecision.top2Similarity.toStringAsFixed(4)} margin12=${effectiveDecision.margin12.toStringAsFixed(4)} same_family=${effectiveDecision.isSameCulinaryFamily} reason=${effectiveDecision.reason} cloud_calls=0',
        );
        _emitRouteLog(
          '[FoodScanRoute] request=$requestId route=tier2_single_result model=${normalized.modelId} winning=${top1Candidate.canonicalFoodId} top1=${top1Candidate.canonicalFoodId} score=${effectiveDecision.top1Similarity.toStringAsFixed(4)} sim=${effectiveDecision.top1Similarity.toStringAsFixed(4)} margin=${effectiveDecision.margin12.toStringAsFixed(4)} model_disagreement=${effectiveDecision.isCrossModelDisagreement} threshold=${_config.openVocabSingleResultSimThreshold.toStringAsFixed(4)} decision=accepted reason=${effectiveDecision.reason} nutrition_resolution=${hasNutrition ? "available" : "unavailable"} tier=${nutritionTier.name} final_ui_route=tier2_single_result candidates=1 top3=$tier2Top3Summary cloud_calls=0',
        );

        debugPrint(
          '[NutritionScaling] id=${top1Candidate.canonicalFoodId} name="${resolvedFood?.name ?? top1Candidate.canonicalName}" profile=${resolvedFood?.id ?? "none"} tier=${nutritionTier.name} serving=${resolvedFood?.servingSize ?? 100.0}${resolvedFood?.servingUnit ?? "g"} cal=${resolvedFood?.calories} p=${resolvedFood?.protein} c=${resolvedFood?.carbohydrates} f=${resolvedFood?.fats}',
        );

        return Tier2OpenVocabPrimaryResult(
          requestId: requestId,
          imagePath: imagePath,
          primaryCandidate: top1Candidate,
          reliabilityDecision: effectiveDecision,
          recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
          hasExactCatalogNutrition: hasNutrition,
          matchedFood: resolvedFood,
          nutritionTier: nutritionTier,
          nutritionExplanation: nutritionExplanation,
          recipeAssumptions: recipeAssumptions,
          nutritionAttribution: nutritionAttribution,
          openVocabResult: normalized,
          internalCandidates: candidates,
          presentationDecision: presentation,
          prediction: tier1Prediction,
          tier1DurationMs: tier1DurationMs,
          tier2DurationMs: tier2DurationMs,
          localInferenceDurationMs: totalLocalMs,
          isOffline: isOffline,
        );
      }

      // When a single reliable match cannot be auto-confirmed (e.g. low margin, confusable siblings, incoherent families)
      // return suggestions for user confirmation in normal Food Scan UI.
      _tier2AmbiguousTop3++;
      _tier2SuggestionsShown++;
      _localSuggestionShown++;
      _completedScanRoutesBySession[requestId] =
          FoodScanCompletionRoute.tier2AmbiguousAbstain;

      final candidateNutrition = _universalNutritionResolver.resolveCandidate(
        top1Candidate,
        foodCatalog: effectiveCatalog,
      );
      final nutritionStatus =
          candidateNutrition.hasNutrition ? 'available' : 'unavailable';
      final nutritionTierStr = candidateNutrition.tier.name;

      final candidateList = candidates.take(3).toList();
      if (singleDecision.isCrossModelDisagreement &&
          tier1Prediction != null &&
          tier1Prediction.foodId.isNotEmpty &&
          tier1Prediction.foodId != 'unknown') {
        final t1Candidate = OpenVocabularyFoodCandidate(
          canonicalFoodId: tier1Prediction.foodId,
          canonicalName: tier1Prediction.foodName,
          category: 'Local Classifier Match',
          similarity: tier1Prediction.confidence,
          rank: candidateList.length + 1,
          inFitFuelCatalog: true,
          fitFuelFoodId: tier1Prediction.foodId,
        );
        if (!candidateList.any((c) => c.canonicalFoodId == t1Candidate.canonicalFoodId)) {
          candidateList.add(t1Candidate);
        }
      }

      _emitSingleResultLog(
        '[FoodScanSingleResult] request=$requestId model=${normalized.modelId} top1=${top1Candidate.canonicalFoodId} top1_sim=${singleDecision.top1Similarity.toStringAsFixed(4)} top2=$top2Id top2_sim=${singleDecision.top2Similarity.toStringAsFixed(4)} margin=${singleDecision.margin12.toStringAsFixed(4)} single_result_reliable=false reason=${singleDecision.reason} route=tier2_open_vocab_suggestions cloud_calls=0',
      );
      _emitPresentationLog(
        '[FoodScanPresentation] request=$requestId mode=${presentation.modeName} top1=${top1Candidate.canonicalFoodId} top2=$top2Id top3=$top3Id top1_sim=${singleDecision.top1Similarity.toStringAsFixed(4)} top2_sim=${singleDecision.top2Similarity.toStringAsFixed(4)} margin12=${singleDecision.margin12.toStringAsFixed(4)} same_family=${singleDecision.isSameCulinaryFamily} reason=${singleDecision.reason} cloud_calls=0',
      );
      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=tier2_open_vocab_suggestions model=${normalized.modelId} winning=${top1Candidate.canonicalFoodId} top1=${top1Candidate.canonicalFoodId} score=${singleDecision.top1Similarity.toStringAsFixed(4)} sim=${singleDecision.top1Similarity.toStringAsFixed(4)} margin=${singleDecision.margin12.toStringAsFixed(4)} model_disagreement=${singleDecision.isCrossModelDisagreement} threshold=${_config.openVocabSingleResultSimThreshold.toStringAsFixed(4)} decision=uncertain reason=${singleDecision.reason} nutrition_resolution=$nutritionStatus tier=$nutritionTierStr final_ui_route=tier2_open_vocab_suggestions candidates=${candidateList.length} top3=$tier2Top3Summary cloud_calls=0',
      );

      return Tier2OpenVocabSuggestionsAvailable(
        requestId: requestId,
        imagePath: imagePath,
        candidates: candidateList,
        openVocabResult: normalized,
        presentationDecision: presentation,
        prediction: tier1Prediction,
        tier1DurationMs: tier1DurationMs,
        tier2DurationMs: tier2DurationMs,
        localInferenceDurationMs: totalLocalMs,
        isOffline: isOffline,
      );
    }

    _noReliableLocalMatch++;
    if (evaluation.isNonFoodRejected) {
      _tier2AbstainedNonFood++;
      _completedScanRoutesBySession[requestId] =
          FoodScanCompletionRoute.tier2NonFood;

      _emitSingleResultLog(
        '[FoodScanSingleResult] request=$requestId model=${normalized.modelId} top1=none top1_sim=0.0000 top2=none top2_sim=0.0000 margin=0.0000 single_result_reliable=false reason=${evaluation.reason} route=tier2_non_food cloud_calls=0',
      );
      _emitRouteLog(
        '[FoodScanRoute] request=$requestId route=tier2_abstained_non_food model=${normalized.modelId} top1=none score=${normalized.topSimilarity.toStringAsFixed(4)} sim=${normalized.topSimilarity.toStringAsFixed(4)} margin=0.0000 threshold=${_config.openVocabModeASimThreshold.toStringAsFixed(4)} decision=uncertain neg_margin=${normalized.negativeMargin.toStringAsFixed(4)} reason=${evaluation.reason} candidates=0 top3=none cloud_calls=0',
      );
      return Tier2AbstainedNonFood(
        requestId: requestId,
        imagePath: imagePath,
        openVocabResult: normalized,
        reason: evaluation.reason,
        prediction: tier1Prediction,
        tier1DurationMs: tier1DurationMs,
        tier2DurationMs: tier2DurationMs,
        localInferenceDurationMs: totalLocalMs,
        isOffline: isOffline,
      );
    }

    _tier2NoReliableMatch++;
    _completedScanRoutesBySession[requestId] =
        FoodScanCompletionRoute.tier2AmbiguousAbstain;

    _emitSingleResultLog(
      '[FoodScanSingleResult] request=$requestId model=${normalized.modelId} top1=none top1_sim=${normalized.topSimilarity.toStringAsFixed(4)} top2=none top2_sim=0.0000 margin=0.0000 single_result_reliable=false reason=${evaluation.reason} route=no_reliable_match cloud_calls=0',
    );
    _emitRouteLog(
      '[FoodScanRoute] request=$requestId route=tier2_no_reliable_match model=${normalized.modelId} top1=none score=${normalized.topSimilarity.toStringAsFixed(4)} sim=${normalized.topSimilarity.toStringAsFixed(4)} margin=0.0000 threshold=${_config.openVocabModeASimThreshold.toStringAsFixed(4)} decision=uncertain neg_margin=${normalized.negativeMargin.toStringAsFixed(4)} reason=${evaluation.reason} candidates=0 top3=none cloud_calls=0',
    );
    return Tier2NoReliableMatch(
      requestId: requestId,
      imagePath: imagePath,
      openVocabResult: normalized,
      reason: evaluation.reason,
      prediction: tier1Prediction,
      tier1DurationMs: tier1DurationMs,
      tier2DurationMs: tier2DurationMs,
      localInferenceDurationMs: totalLocalMs,
      isOffline: isOffline,
    );
  }

  /// Phase 35.11B: Resolves a user-confirmed Tier-2 open-vocabulary candidate
  /// (`SigLIP-B/16`) into a [FoodScanResult] with ZERO Gemini calls.
  ///
  /// - If an exact or verified 1:1 FitFuel catalog nutrition entry exists
  ///   (e.g. `Samosa`, `Masala Dosa`, `Grilled Salmon`, `Ripe Banana`), attaches
  ///   trusted `matchedFood` so `hasNutrition == true` and `canBeLogged == true`.
  /// - If no exact FitFuel nutrition entry exists yet (e.g. `Creamy Penne Pasta`,
  ///   `Penne Alfredo`, `Burger`, `Cheese Pizza`), does NOT fabricate or substitute
  ///   sibling nutrition. Returns a confirmed `FoodScanResult` with `matchedFood: null`,
  ///   `hasNutrition: false`, and `canBeLogged: false` so the UI presents the
  ///   honest "Food recognized • Exact nutrition profile isn't available yet" state
  ///   with pre-filled `Search FitFuel Foods`.
  FoodScanResult confirmOpenVocabCandidate({
    required OpenVocabularyFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    required String requestId,
    int? localInferenceDurationMs,
    List<OpenVocabularyFoodCandidate> allCandidates = const [],
    String? top1CanonicalId,
    String? scanSessionId,
  }) {
    final effectiveCatalog = foodCatalog.isNotEmpty
        ? foodCatalog
        : _canonicalCatalogById.values.toList();

    final resolution = _universalNutritionResolver.resolveCandidate(
      candidate,
      foodCatalog: effectiveCatalog,
    );

    final resolvedFood = resolution.matchedCatalogFood;
    final hasNutrition = resolution.hasNutrition && resolvedFood != null;

    final sessionKey =
        _resolveSessionKey(requestId, scanSessionId: scanSessionId);
    final priorRoute = _completedScanRoutesBySession[sessionKey];
    if (priorRoute != FoodScanCompletionRoute.openVocabConfirmed) {
      _tier2Confirmed++;
      if (top1CanonicalId != null &&
          top1CanonicalId == candidate.canonicalFoodId) {
        _tier2ConfirmedTop1++;
      }
      if (hasNutrition) {
        _tier2ConfirmedExactCatalogMatch++;
      } else {
        _tier2ConfirmedNeedsNutritionSelection++;
      }
    }
    _completedScanRoutesBySession[sessionKey] =
        FoodScanCompletionRoute.openVocabConfirmed;

    final matchedId = resolvedFood?.id ?? 'none';

    _emitRouteLog(
      '[FoodScanRoute] request=$sessionKey route=tier2_open_vocab_confirmed model=${_config.openVocabModelVersion} confirmed=${candidate.canonicalFoodId} catalog_match=$matchedId nutrition_available=$hasNutrition tier=${resolution.tier.name} cloud_calls=$_cloudCallsThisScan',
    );
    _emitCascadeLog(
      '[FoodScanCascade] request=$sessionKey final_route=tier2_open_vocab_confirmed confirmed=${candidate.canonicalFoodId} catalog_match=$matchedId nutrition_available=$hasNutrition tier=${resolution.tier.name} cloud_calls=$_cloudCallsThisScan',
    );

    final visualNotes = resolution.isVerifiedExact
        ? 'Curated FitFuel Food Database'
        : resolution.isGenericBaseline
            ? 'Generic Baseline (${resolution.attribution ?? "USDA FoodData Central"})'
            : resolution.isRecipeEstimate
                ? 'Recipe Estimate (${resolution.recipeAssumptions ?? "Standard Culinary Formulation"})'
                : 'Confirmed by you • Select a FitFuel nutrition profile before logging';

    final detected = DetectedFoodCandidate(
      id: 'openvocab_${DateTime.now().millisecondsSinceEpoch}',
      detectedName: resolvedFood?.name ?? candidate.canonicalName,
      confidence: 1.0,
      estimatedAmount: resolvedFood?.servingSize ?? 100.0,
      originalEstimatedAmount: resolvedFood?.servingSize ?? 100.0,
      estimatedUnit: resolvedFood?.servingUnit ?? 'g',
      matchedFood: resolvedFood,
      matchConfidence: resolution.isVerifiedExact
          ? 1.0
          : resolution.isGenericBaseline
              ? 0.85
              : resolution.isRecipeEstimate
                  ? 0.75
                  : 0.0,
      visualNotes: visualNotes,
      aiEstimatedNutrition: null,
      recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
      isUserConfirmed: true,
      nutritionTier: resolution.tier,
      nutritionExplanation: resolution.explanation,
      recipeAssumptions: resolution.recipeAssumptions,
      nutritionAttribution: resolution.attribution,
    );

    _recordTelemetry(
      requestId: requestId,
      model: 'on-device-openvocab:${_config.openVocabModelVersion}',
      durationMs: localInferenceDurationMs ?? 0,
      imageSizeBytes: 0,
      isFallback: false,
      isSuccess: true,
      recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed.name,
      route: FoodScanRecognitionSource.openVocabularyConfirmed.debugRouteLabel,
      localConfidence: candidate.similarity,
      localInferenceDurationMs: localInferenceDurationMs,
      cloudFallbackUsed: false,
    );

    debugPrint(
      '[NutritionScaling] id=${detected.id} name="${detected.displayName}" profile=${detected.matchedFood?.id ?? "none"} tier=${detected.nutritionTier?.name} serving=${detected.estimatedAmount}${detected.estimatedUnit} cal=${detected.scaledCalories} p=${detected.scaledProtein} c=${detected.scaledCarbs} f=${detected.scaledFats}',
    );

    return FoodScanResult(
      id: requestId,
      imagePath: imagePath,
      foods: [detected],
      overallConfidence: 1.0,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
      localConfidence: candidate.similarity,
      localInferenceDurationMs: localInferenceDurationMs,
      openVocabCandidates:
          allCandidates.isNotEmpty ? allCandidates : [candidate],
    );
  }

  /// Resolves a user-confirmed local Top-K suggestion into a [FoodScanResult]
  /// using [PredefinedFoodData] nutrition with ZERO Gemini calls.
  FoodScanResult confirmSuggestion({
    required LocalFoodCandidate candidate,
    List<FoodEntity> foodCatalog = const [],
    required String imagePath,
    required String requestId,
    int? localInferenceDurationMs,
    List<LocalFoodCandidate> allSuggestions = const [],
    String? top1FoodId,
    String? scanSessionId,
  }) {
    final effectiveCatalog = foodCatalog.isNotEmpty
        ? foodCatalog
        : _canonicalCatalogById.values.toList();

    FoodEntity? catalogMatch = _canonicalCatalogById[candidate.foodId];
    if (catalogMatch == null) {
      for (final food in effectiveCatalog) {
        if (food.id == candidate.foodId) {
          catalogMatch = food;
          break;
        }
      }
    }
    catalogMatch ??=
        FoodMatcher.match(candidate.foodName, effectiveCatalog).food;

    if (catalogMatch == null) {
      throw const FoodScanFailure(
        type: FoodScanFailureType.invalidRequest,
        title: FoodScanErrorCopy.unknownTitle,
        message: 'Selected food was not found in the FitFuel catalog.',
      );
    }

    final sessionKey =
        _resolveSessionKey(requestId, scanSessionId: scanSessionId);
    final priorRoute = _completedScanRoutesBySession[sessionKey];
    if (priorRoute != FoodScanCompletionRoute.suggestionConfirmed) {
      _localSuggestionConfirmed++;
      if (top1FoodId != null && top1FoodId == candidate.foodId) {
        _localSuggestionTop1Confirmed++;
      }
    }
    _completedScanRoutesBySession[sessionKey] =
        FoodScanCompletionRoute.suggestionConfirmed;

    _emitRouteLog(
      '[FoodScanRoute] request=$sessionKey route=local_suggestion model=${_config.modelVersion} confirmed=${catalogMatch.id} cloud_calls=$_cloudCallsThisScan',
    );

    final detected = DetectedFoodCandidate(
      id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}',
      detectedName: catalogMatch.name,
      confidence: candidate.confidence,
      estimatedAmount: catalogMatch.servingSize,
      originalEstimatedAmount: catalogMatch.servingSize,
      estimatedUnit: catalogMatch.servingUnit,
      matchedFood: catalogMatch,
      matchConfidence: 1.0,
      visualNotes: 'Confirmed from local suggestions',
      aiEstimatedNutrition: null, // Strictly database-first nutrition
      recognitionSource: FoodScanRecognitionSource.localSuggestionConfirmed,
      isUserConfirmed: true,
    );

    _recordTelemetry(
      requestId: requestId,
      model: 'on-device-suggestion:${_config.modelVersion}',
      durationMs: localInferenceDurationMs ?? 0,
      imageSizeBytes: 0,
      isFallback: false,
      isSuccess: true,
      recognitionSource:
          FoodScanRecognitionSource.localSuggestionConfirmed.name,
      route:
          FoodScanRecognitionSource.localSuggestionConfirmed.debugRouteLabel,
      localConfidence: candidate.confidence,
      localInferenceDurationMs: localInferenceDurationMs,
      cloudFallbackUsed: false,
    );

    debugPrint(
      '[NutritionScaling] id=${detected.id} name="${detected.displayName}" profile=${detected.matchedFood?.id ?? "none"} tier=${detected.nutritionTier?.name} serving=${detected.estimatedAmount}${detected.estimatedUnit} cal=${detected.scaledCalories} p=${detected.scaledProtein} c=${detected.scaledCarbs} f=${detected.scaledFats}',
    );

    return FoodScanResult(
      id: requestId,
      imagePath: imagePath,
      foods: [detected],
      overallConfidence: candidate.confidence,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.localSuggestionConfirmed,
      localConfidence: candidate.confidence,
      localInferenceDurationMs: localInferenceDurationMs,
      localCandidates:
          allSuggestions.isNotEmpty ? allSuggestions : [candidate],
    );
  }

  /// Records a manual catalog search selection and returns a database-first [FoodScanResult]
  /// with ZERO Gemini calls.
  FoodScanResult recordManualSelection({
    required FoodEntity food,
    double? amount,
    required String imagePath,
    required String requestId,
    String? scanSessionId,
  }) {
    final sessionKey =
        _resolveSessionKey(requestId, scanSessionId: scanSessionId);
    final priorRoute = _completedScanRoutesBySession[sessionKey];
    if (priorRoute != FoodScanCompletionRoute.manualConfirmed) {
      _manualSearchUsed++;
    }
    _completedScanRoutesBySession[sessionKey] =
        FoodScanCompletionRoute.manualConfirmed;

    _emitRouteLog(
      '[FoodScanRoute] request=$sessionKey route=manual model=none food=${food.id} cloud_calls=$_cloudCallsThisScan',
    );

    final servingAmount = amount ?? food.servingSize;
    final detected = DetectedFoodCandidate(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      detectedName: food.name,
      confidence: 1.0,
      estimatedAmount: servingAmount,
      originalEstimatedAmount: food.servingSize,
      estimatedUnit: food.servingUnit,
      matchedFood: food,
      matchConfidence: 1.0,
      visualNotes: 'Selected manually from FitFuel catalog',
      aiEstimatedNutrition: null,
      recognitionSource: FoodScanRecognitionSource.manual,
      isUserConfirmed: true,
    );

    _recordTelemetry(
      requestId: requestId,
      model: 'manual-catalog',
      durationMs: 0,
      imageSizeBytes: 0,
      isFallback: false,
      isSuccess: true,
      recognitionSource: FoodScanRecognitionSource.manual.name,
      route: FoodScanRecognitionSource.manual.debugRouteLabel,
      cloudFallbackUsed: false,
    );

    debugPrint(
      '[NutritionScaling] id=${detected.id} name="${detected.displayName}" profile=${detected.matchedFood?.id ?? "none"} tier=${detected.nutritionTier?.name} serving=${detected.estimatedAmount}${detected.estimatedUnit} cal=${detected.scaledCalories} p=${detected.scaledProtein} c=${detected.scaledCarbs} f=${detected.scaledFats}',
    );

    return FoodScanResult(
      id: requestId,
      imagePath: imagePath,
      foods: [detected],
      overallConfidence: 1.0,
      scannedAt: DateTime.now(),
      recognitionSource: FoodScanRecognitionSource.manual,
    );
  }

  /// Explicitly invokes Gemini cloud analysis (used when the user taps "Analyze with AI"
  /// or "Retry AI").
  Future<FoodScanResult> analyzeWithCloud({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    required String requestId,
    LocalFoodPrediction? priorLocalPrediction,
    int localInferenceDurationMs = 0,
    bool isOffline = false,
    bool userRequestedAi = false,
    String? scanSessionId,
  }) async {
    _lastUserRequestedAi = userRequestedAi;

    if (!userRequestedAi && _config.preferFreeLocalScan) {
      final assertMsg =
          'ASSERT: Automatic Gemini invocation is forbidden in free-first mode (request=$requestId).';
      _debugAssertionWarnings.add(assertMsg);
      LoggerService.warning(assertMsg);
      if (kDebugMode) {
        debugPrint('[FoodScanAssert] $assertMsg');
      }
    }

    if (isOffline) {
      throw FoodScanFailure.fromType(FoodScanFailureType.offline);
    }

    final sessionKey =
        _resolveSessionKey(requestId, scanSessionId: scanSessionId);
    final effectiveCatalog = foodCatalog.isNotEmpty
        ? foodCatalog
        : _canonicalCatalogById.values.toList();

    _geminiRequested++;
    _cloudCallsThisScan++;

    _emitRouteLog(
      '[FoodScanRoute] request=$sessionKey route=gemini reason=${userRequestedAi ? "user_requested_ai" : "legacy_fallback"} cloud_calls=$_cloudCallsThisScan',
    );
    _emitAiLog(
      '[FoodScanAI] request=$sessionKey userRequested=$userRequestedAi model=${GeminiConfig.primaryModel} fallbackModel=${GeminiConfig.fallbackModel} attempt=1',
    );

    final cloudStopwatch = Stopwatch()..start();

    try {
      final rawFoods = await _remoteDataSource.analyzeMealImage(
        imageBytes,
        requestId: requestId,
      );
      cloudStopwatch.stop();

      final List<DetectedFoodCandidate> candidates = [];

      for (var i = 0; i < rawFoods.length; i++) {
        final raw = rawFoods[i];
        final matchResult = FoodMatcher.match(raw.name, effectiveCatalog);

        EstimatedNutrition? resolvedNutrition;
        if (matchResult.isMatched) {
          resolvedNutrition = null;
        } else if (raw.estimatedNutrition != null) {
          resolvedNutrition = raw.estimatedNutrition;
        } else {
          try {
            resolvedNutrition = await _remoteDataSource.repairNutrition(
              foodName: raw.name,
              estimatedGrams: raw.estimatedGrams,
            );
          } catch (_) {
            resolvedNutrition = null;
          }
        }

        candidates.add(
          DetectedFoodCandidate(
            id: 'cloud_${i}_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: raw.name,
            confidence: raw.confidence,
            estimatedAmount: raw.estimatedGrams,
            originalEstimatedAmount: raw.estimatedGrams,
            estimatedUnit: raw.unit,
            matchedFood: matchResult.isMatched ? matchResult.food : null,
            matchConfidence:
                matchResult.isMatched ? matchResult.matchScore : 0.0,
            visualNotes: raw.visualNotes,
            aiEstimatedNutrition: resolvedNutrition,
            recognitionSource: FoodScanRecognitionSource.gemini,
            isUserConfirmed: false,
          ),
        );
      }

      final overallConfidence = candidates.isEmpty
          ? 0.0
          : candidates.fold(0.0, (sum, f) => sum + f.confidence) /
              candidates.length;

      _geminiSucceeded++;
      _completedScanRoutesBySession[sessionKey] =
          FoodScanCompletionRoute.geminiCompleted;

      _recordTelemetry(
        requestId: requestId,
        model: 'gemini-fallback',
        durationMs: cloudStopwatch.elapsedMilliseconds,
        imageSizeBytes: imageBytes.length,
        isFallback: true,
        isSuccess: true,
        recognitionSource: FoodScanRecognitionSource.gemini.name,
        route: FoodScanRecognitionSource.gemini.debugRouteLabel,
        localConfidence: priorLocalPrediction?.confidence,
        localInferenceDurationMs: localInferenceDurationMs,
        cloudFallbackUsed: true,
      );

      return FoodScanResult(
        id: requestId,
        imagePath: imagePath,
        foods: candidates,
        overallConfidence: overallConfidence,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.gemini,
        localConfidence: priorLocalPrediction?.confidence,
        localInferenceDurationMs: localInferenceDurationMs,
        localCandidates: priorLocalPrediction?.topCandidates ?? const [],
      );
    } on FoodScanException catch (e) {
      cloudStopwatch.stop();
      _recordCloudFailureCounter(e.type, e.statusCode);
      throw FoodScanFailure.fromType(
        e.type,
        messageOverride: e.message,
        retryAfterSeconds: e.retryAfterSeconds,
        statusCode: e.statusCode,
      );
    } on ModelUnavailableException catch (e) {
      cloudStopwatch.stop();
      _geminiServiceFailure++;
      throw FoodScanFailure.fromType(
        FoodScanFailureType.modelUnavailable,
        messageOverride: e.message,
        statusCode: e.statusCode,
      );
    } on NetworkException catch (e) {
      cloudStopwatch.stop();
      _geminiServiceFailure++;
      throw FoodScanFailure.fromType(
        FoodScanFailureType.offline,
        messageOverride: e.message,
      );
    } on ServerException catch (e) {
      cloudStopwatch.stop();
      final statusCode = e.statusCode;
      if (statusCode == 404) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.modelUnavailable,
          statusCode: 404,
        );
      }
      if (statusCode == 429) {
        _geminiQuotaFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.rateLimited,
          statusCode: 429,
        );
      }
      if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.serviceUnavailable,
          statusCode: statusCode,
        );
      }
      if (statusCode == 408 || statusCode == 504) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.timeout,
          statusCode: statusCode,
        );
      }
      if (statusCode == 401) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.unauthorized,
          statusCode: 401,
        );
      }
      if (statusCode == 403) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.forbidden,
          statusCode: 403,
        );
      }
      if (statusCode == 400) {
        _geminiServiceFailure++;
        throw FoodScanFailure.fromType(
          FoodScanFailureType.invalidRequest,
          statusCode: 400,
        );
      }
      _geminiServiceFailure++;
      throw FoodScanFailure.fromType(
        FoodScanFailureType.unknownServiceFailure,
        messageOverride: e.message,
        statusCode: statusCode,
      );
    }
  }

  /// Legacy / direct hybrid routing method retained for Phase 35.9 / 35.9.4 / 35.9.5 test suites.
  Future<FoodScanResult> routeScan({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
    required String requestId,
    bool isOffline = false,
  }) async {
    final decision = await routeFreeFirst(
      imagePath: imagePath,
      imageBytes: imageBytes,
      foodCatalog: foodCatalog,
      requestId: requestId,
      isOffline: isOffline,
    );

    if (decision is LocalAutoAccepted) {
      return decision.result;
    }

    if (isOffline) {
      throw const FoodScanFailure(
        type: FoodScanFailureType.offlineLowConfidence,
        title: FoodScanErrorCopy.offlineLowConfidenceTitle,
        message: FoodScanErrorCopy.offlineLowConfidenceMessage,
      );
    }

    return await analyzeWithCloud(
      imagePath: imagePath,
      imageBytes: imageBytes,
      foodCatalog: foodCatalog,
      requestId: requestId,
      priorLocalPrediction: decision.prediction,
      localInferenceDurationMs: decision.localInferenceDurationMs,
      isOffline: isOffline,
      userRequestedAi: false,
      scanSessionId: requestId,
    );
  }

  void _recordCloudFailureCounter(FoodScanFailureType type, int? statusCode) {
    if (type == FoodScanFailureType.dailyQuotaReached ||
        type == FoodScanFailureType.rateLimited ||
        statusCode == 429) {
      _geminiQuotaFailure++;
    } else {
      _geminiServiceFailure++;
    }
  }

  FoodEntity? _findCatalogMatch(
    LocalFoodPrediction prediction,
    List<FoodEntity> catalog,
  ) {
    // 1. Direct ID lookup in catalog
    for (final food in catalog) {
      if (food.id == prediction.foodId) {
        return food;
      }
    }

    // 2. Canonical PredefinedFoodData lookup
    final canonical = _canonicalCatalogById[prediction.foodId];
    if (canonical != null) {
      return canonical;
    }

    // 3. Fallback to name/fuzzy matching if ID wasn't in the subset
    final matchResult = FoodMatcher.match(prediction.foodName, catalog);
    if (matchResult.isMatched) {
      return matchResult.food;
    }

    return null;
  }

  void _recordTelemetry({
    required String requestId,
    required String model,
    required int durationMs,
    required int imageSizeBytes,
    required bool isFallback,
    required bool isSuccess,
    FoodScanFailureType? failureType,
    int? statusCode,
    required String recognitionSource,
    String? route,
    double? localConfidence,
    int? localInferenceDurationMs,
    required bool cloudFallbackUsed,
  }) {
    final event = FoodScanTelemetryEvent(
      requestId: requestId,
      model: model,
      attemptCount: 1,
      statusCode: statusCode,
      durationMs: durationMs,
      imageSizeBytes: imageSizeBytes,
      isFallback: isFallback,
      isSuccess: isSuccess,
      failureType: failureType,
      timestamp: DateTime.now(),
      recognitionSource: recognitionSource,
      route: route,
      localConfidence: localConfidence,
      localInferenceDurationMs: localInferenceDurationMs,
      cloudFallbackUsed: cloudFallbackUsed,
    );

    try {
      _telemetrySink?.call(event);
    } catch (_) {}
  }
}

/// Phase 35.10.3 evaluation outcome for local Top-K suggestion reliability.
class SuggestionReliabilityEvaluation {
  final bool isReliable;
  final String reason;
  final double top1Confidence;
  final double margin;
  final List<LocalFoodCandidate> candidates;

  const SuggestionReliabilityEvaluation({
    required this.isReliable,
    required this.reason,
    required this.top1Confidence,
    required this.margin,
    required this.candidates,
  });
}
