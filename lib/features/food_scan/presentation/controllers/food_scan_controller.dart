import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/core/services/logger_service.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/food_scan/data/services/food_scan_recognition_router.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/entities/local_food_prediction.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_feedback_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/universal_nutrition_resolver.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';

class FoodScanController extends StateNotifier<FoodScanState> {
  final IFoodScanRepository _repository;
  final IFoodImagePickerService _imagePickerService;
  final UniversalNutritionResolver _universalNutritionResolver;
  final GlobalFoodVocabularyService _globalFoodVocabularyService;
  final FoodFeedbackService _foodFeedbackService;

  String? _retainedImagePath;
  Uint8List? _retainedImageBytes;
  List<FoodEntity> _cachedCatalog = const [];
  List<LocalFoodCandidate> _lastSuggestions = const [];
  List<OpenVocabularyFoodCandidate> _lastOpenVocabSuggestions = const [];
  OpenVocabPresentationDecision? _lastOpenVocabPresentation;
  LocalFoodPrediction? _lastPrediction;
  FoodScanRouteDecision? _lastRouteDecision;
  bool _lastIsMixedMealSuspected = false;
  bool _lastIsNonFoodAbstained = false;
  bool _lastIsLocalModelUnavailable = false;
  bool _isOffline = false;
  String _selectedMealType = defaultMealType();
  int _currentScanRequestId = 0;
  int _scanSequence = 0;
  String _activeScanId = 'scan_0';
  int _cloudCallsThisScan = 0;
  bool _userRequestedAi = false;
  bool _isOperationInProgress = false;

  FoodScanController({
    required IFoodScanRepository repository,
    required IFoodImagePickerService imagePickerService,
    UniversalNutritionResolver? universalNutritionResolver,
    GlobalFoodVocabularyService? globalFoodVocabularyService,
    FoodFeedbackService? foodFeedbackService,
  })  : _repository = repository,
        _imagePickerService = imagePickerService,
        _universalNutritionResolver =
            universalNutritionResolver ?? UniversalNutritionResolver(),
        _globalFoodVocabularyService =
            globalFoodVocabularyService ?? GlobalFoodVocabularyService(),
        _foodFeedbackService = foodFeedbackService ?? FoodFeedbackService(),
        super(const FoodScanIdle());

  /// Default meal type determined by local time of day.
  static String defaultMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 16) return 'Lunch';
    if (hour < 19) return 'Snack';
    return 'Dinner';
  }

  /// Retained image path for retry operations without retaking photos.
  String? get retainedImagePath => _retainedImagePath;

  /// Retained image bytes for retry operations without re-reading disks.
  Uint8List? get retainedImageBytes => _retainedImageBytes;

  /// Retained local suggestions from the latest on-device classification.
  List<LocalFoodCandidate> get retainedSuggestions => _lastSuggestions;

  /// Retained Tier-2 open-vocabulary suggestions from the latest scan.
  List<OpenVocabularyFoodCandidate> get retainedOpenVocabSuggestions =>
      _lastOpenVocabSuggestions;

  /// Retained Tier-2 open-vocabulary presentation decision from the latest scan.
  OpenVocabPresentationDecision? get retainedOpenVocabPresentation =>
      _lastOpenVocabPresentation;

  /// Current meal type target.
  String get selectedMealType => _selectedMealType;

  /// Current generation token for request synchronization.
  int get currentScanRequestId => _currentScanRequestId;

  /// Logical request ID for the current scan session (e.g. `scan_1`, `scan_12`).
  String get activeScanId => _activeScanId;

  /// Cloud (Gemini) calls made during the current scan session.
  int get cloudCallsThisScan => _cloudCallsThisScan;

  /// True only if the user explicitly tapped "Analyze with AI" or "Retry AI" in the current scan.
  bool get userRequestedAi => _userRequestedAi;

  /// Phase 35.12 Universal Nutrition Resolver instance.
  UniversalNutritionResolver get universalNutritionResolver =>
      _universalNutritionResolver;

  /// Phase 35.12 Global Food Taxonomy service.
  GlobalFoodVocabularyService get globalFoodVocabularyService =>
      _globalFoodVocabularyService;

  /// Phase 35.12 Privacy-first user feedback service.
  FoodFeedbackService get foodFeedbackService => _foodFeedbackService;

  /// Submits structured user feedback or reporting for food recognition without photo upload.
  Future<FoodFeedbackRecord> submitFeedback({
    required String correctedFoodName,
    required FoodFeedbackType feedbackType,
    String? predictedFoodName,
    String? userNotes,
    bool consentToUseImageForReview = false,
  }) {
    return _foodFeedbackService.submitFeedback(
      correctedFoodName: correctedFoodName,
      feedbackType: feedbackType,
      predictedFoodName: predictedFoodName,
      scanSessionId: _activeScanId,
      userNotes: userNotes,
      consentToUseImageForReview: consentToUseImageForReview,
    );
  }

  bool get _useFreeFirstRouting =>
      _repository is IFreeFirstFoodScanRepository &&
      _repository.hasFreeFirstRouter;

  List<FoodEntity> _effectiveCatalog([List<FoodEntity>? provided]) {
    if (provided != null && provided.isNotEmpty) return provided;
    if (_cachedCatalog.isNotEmpty) return _cachedCatalog;
    return PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  }

  /// Initiates image acquisition (camera or gallery) and Free-First on-device analysis.
  Future<void> pickAndScan(
    FoodImagePickSource source, {
    List<FoodEntity> catalog = const [],
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  }) async {
    if (_isOperationInProgress ||
        state is FoodScanAnalyzing ||
        state is FoodScanLogging) {
      return; // Prevent duplicate invocation / double-tap
    }

    _isOperationInProgress = true;
    final requestId = ++_currentScanRequestId;

    try {
      final imagePath = await _imagePickerService.pickImage(source);
      if (requestId != _currentScanRequestId) return; // Stale request cancelled
      if (imagePath == null) {
        // User cancelled picker; keep idle or prior state
        return;
      }

      _activeScanId = 'scan_${++_scanSequence}';
      _cloudCallsThisScan = 0;
      _userRequestedAi = false;
      _retainedImagePath = imagePath;
      _cachedCatalog = catalog;
      _isOffline = isOffline;

      state = FoodScanAnalyzing(
        imagePath: imagePath,
        stageMessage: 'Scanning on your device...',
      );

      final bytes = await _imagePickerService.getImageBytes(imagePath);
      if (requestId != _currentScanRequestId) return; // Stale request cancelled
      if (bytes == null || bytes.isEmpty) {
        state = FoodScanError(
          title: FoodScanErrorCopy.imageQualityTitle,
          message: FoodScanErrorCopy.imageQualityMessage,
          failureType: FoodScanFailureType.invalidImage,
          imagePath: imagePath,
        );
        return;
      }

      _retainedImageBytes = bytes;

      await _performScan(
        imagePath: imagePath,
        imageBytes: bytes,
        catalog: catalog,
        requestId: requestId,
        isOffline: isOffline,
        isMixedMealSuspected: isMixedMealSuspected,
      );
    } catch (e, stackTrace) {
      if (requestId != _currentScanRequestId) return;
      LoggerService.error(
          'FoodScanController error during pickAndScan', e, stackTrace);
      if (e is FoodScanFailure) {
        state = FoodScanError(
          title: e.title,
          message: e.message,
          failureType: e.type,
          imagePath: _retainedImagePath,
          imageBytes: _retainedImageBytes,
          retryAfterSeconds: e.retryAfterSeconds,
          localSuggestions: _lastSuggestions,
        );
      } else {
        state = FoodScanError(
          title: FoodScanErrorCopy.unknownTitle,
          message: e is Failure ? e.message : FoodScanErrorCopy.unknownMessage,
          imagePath: _retainedImagePath,
          imageBytes: _retainedImageBytes,
          localSuggestions: _lastSuggestions,
        );
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Directly analyzes raw image bytes (used by test suites & picked images).
  Future<void> scanImageBytes({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> catalog = const [],
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  }) async {
    final requestId = ++_currentScanRequestId;
    _activeScanId = 'scan_${++_scanSequence}';
    _cloudCallsThisScan = 0;
    _userRequestedAi = false;
    await _performScan(
      imagePath: imagePath,
      imageBytes: imageBytes,
      catalog: catalog,
      requestId: requestId,
      isOffline: isOffline,
      isMixedMealSuspected: isMixedMealSuspected,
    );
  }

  /// Internal scan execution with latest-wins race guard and Free-First routing.
  Future<void> _performScan({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> catalog = const [],
    required int requestId,
    bool isOffline = false,
    bool isMixedMealSuspected = false,
  }) async {
    if (imageBytes.isEmpty) {
      state = FoodScanNoFoodDetected(
        imagePath: imagePath,
        reason: NoFoodReason.invalidImage,
        customMessage:
            'The selected image is empty or invalid. Please take a clear, well-lit photo of your meal.',
      );
      return;
    }

    _retainedImagePath = imagePath;
    _retainedImageBytes = imageBytes;
    if (catalog.isNotEmpty) {
      _cachedCatalog = catalog;
    }
    _isOffline = isOffline;
    if (_activeScanId == 'scan_0') {
      _activeScanId = 'scan_${++_scanSequence}';
    }

    // Phase 35.11B.1 Section 27:
    // Loading copy:
    // Tier 1: "Scanning on your device..."
    // Tier 2: "Checking your food on your device..."
    final needsColdTier2 = _useFreeFirstRouting &&
        ((_repository as IFreeFirstFoodScanRepository)
                .router
                ?.tier2RequiresColdInit ??
            false);

    state = FoodScanAnalyzing(
      imagePath: imagePath,
      stageMessage: needsColdTier2
          ? 'Checking your food on your device...'
          : 'Scanning on your device...',
    );

    if (_useFreeFirstRouting) {
      final freeRepo = _repository as IFreeFirstFoodScanRepository;
      try {
        final decision = await freeRepo.evaluateFreeFirstScan(
          imagePath: imagePath,
          imageBytes: imageBytes,
          foodCatalog: _effectiveCatalog(catalog),
          requestId: _activeScanId,
          isOffline: isOffline,
          isMixedMealSuspected: isMixedMealSuspected,
        );

        if (requestId != _currentScanRequestId) return; // Superseded

        _lastRouteDecision = decision;
        _lastPrediction = decision.prediction;
        _selectedMealType = defaultMealType();

        switch (decision) {
          case LocalAutoAccepted():
            _lastSuggestions = decision.result.localCandidates;
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuccess(
              result: decision.result,
              selectedMealType: _selectedMealType,
            );
          case Tier2OpenVocabPrimaryResult():
            _lastOpenVocabSuggestions = [decision.primaryCandidate];
            _lastOpenVocabPresentation = null;
            _lastSuggestions = const [];
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;

            final primary = decision.primaryCandidate;
            final matched = decision.matchedFood;

            final visualNotes = decision.nutritionTier == NutritionProfileTier.verifiedExact
                ? 'Curated FitFuel Food Database'
                : decision.nutritionTier == NutritionProfileTier.closelyRelatedGeneric
                    ? 'Generic Baseline (${decision.nutritionAttribution ?? "USDA FoodData Central"})'
                    : decision.nutritionTier == NutritionProfileTier.recipeEstimate
                        ? 'Recipe Estimate (${decision.recipeAssumptions ?? "Standard Culinary Formulation"})'
                        : 'Found on your device • Select a FitFuel nutrition profile before logging';

            final detected = DetectedFoodCandidate(
              id: 'openvocab_primary_${DateTime.now().millisecondsSinceEpoch}',
              detectedName: matched?.name ?? primary.displayName,
              confidence: primary.similarity,
              estimatedAmount: matched?.servingSize ?? 100.0,
              originalEstimatedAmount: matched?.servingSize ?? 100.0,
              estimatedUnit: matched?.servingUnit ?? 'g',
              matchedFood: matched,
              matchConfidence: decision.nutritionTier == NutritionProfileTier.verifiedExact
                  ? 1.0
                  : decision.nutritionTier == NutritionProfileTier.closelyRelatedGeneric
                      ? 0.85
                      : decision.nutritionTier == NutritionProfileTier.recipeEstimate
                          ? 0.75
                          : 0.0,
              visualNotes: visualNotes,
              aiEstimatedNutrition: null,
              recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
              isUserConfirmed: false,
              nutritionTier: decision.nutritionTier,
              nutritionExplanation: decision.nutritionExplanation,
              recipeAssumptions: decision.recipeAssumptions,
              nutritionAttribution: decision.nutritionAttribution,
            );

            final scanResult = FoodScanResult(
              id: decision.requestId,
              imagePath: imagePath,
              foods: [detected],
              overallConfidence: primary.similarity,
              scannedAt: DateTime.now(),
              recognitionSource: FoodScanRecognitionSource.openVocabularyPrimary,
              localConfidence: primary.similarity,
              localInferenceDurationMs: decision.localInferenceDurationMs,
              openVocabCandidates: decision.candidates.isNotEmpty
                  ? decision.candidates
                  : [primary], // Preserves candidate alternatives for subordinate selection
            );

            state = FoodScanSuccess(
              result: scanResult,
              selectedMealType: _selectedMealType,
            );
          case Tier2AmbiguousAbstain():
            _lastSuggestions = const [];
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case Tier2OpenVocabSuggestionsAvailable():
            _lastOpenVocabSuggestions = decision.candidates;
            _lastOpenVocabPresentation = decision.presentationDecision;
            _lastSuggestions = const [];
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: decision.candidates,
              openVocabPresentation: decision.presentationDecision,
              isOtherMatchesExpanded: false,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case LocalSuggestionsAvailable():
            _lastSuggestions = decision.suggestions;
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: decision.suggestions,
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case MixedMealNeedsDecision():
            _lastSuggestions = decision.suggestions;
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = true;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: decision.suggestions,
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: true,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case LocalModelUnavailable():
            _lastSuggestions = const [];
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = true;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: true,
              selectedMealType: _selectedMealType,
            );
          case Tier2AbstainedNonFood():
            _lastSuggestions = const [];
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = true;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: true,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case Tier2NoReliableMatch():
            final hasTier1Prediction = decision.prediction != null &&
                decision.prediction!.isModelAvailable &&
                decision.prediction!.foodId.isNotEmpty &&
                decision.prediction!.foodId != 'unknown' &&
                decision.prediction!.confidence >= 0.30;

            final fallbackSuggestions = hasTier1Prediction
                ? <LocalFoodCandidate>[
                    LocalFoodCandidate(
                      foodId: decision.prediction!.foodId,
                      foodName: decision.prediction!.foodName,
                      confidence: decision.prediction!.confidence,
                    )
                  ]
                : const <LocalFoodCandidate>[];

            _lastSuggestions = fallbackSuggestions;
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: fallbackSuggestions,
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case NoReliableLocalMatch():
            _lastSuggestions = const [];
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
          case CloudRequired():
            _lastSuggestions = const [];
            _lastOpenVocabSuggestions = const [];
            _lastOpenVocabPresentation = null;
            _lastIsMixedMealSuspected = false;
            _lastIsNonFoodAbstained = false;
            _lastIsLocalModelUnavailable = false;
            state = FoodScanSuggestions(
              imagePath: imagePath,
              imageBytes: imageBytes,
              suggestions: const [],
              openVocabSuggestions: const [],
              openVocabPresentation: null,
              prediction: decision.prediction,
              routeDecision: decision,
              isMixedMealSuspected: false,
              isNonFoodAbstained: false,
              isOffline: isOffline,
              isLocalModelUnavailable: false,
              selectedMealType: _selectedMealType,
            );
        }
      } catch (e, stackTrace) {
        if (requestId != _currentScanRequestId) return;
        LoggerService.error(
            'FoodScanController error during free-first scan', e, stackTrace);
        final failure = e is FoodScanFailure
            ? e
            : FoodScanFailure.fromType(
                FoodScanFailureType.unknownServiceFailure);
        state = FoodScanSuggestions(
          imagePath: imagePath,
          imageBytes: imageBytes,
          suggestions: _lastSuggestions,
          openVocabSuggestions: _lastOpenVocabSuggestions,
          openVocabPresentation: _lastOpenVocabPresentation,
          prediction: _lastPrediction,
          routeDecision: _lastRouteDecision,
          isMixedMealSuspected: _lastIsMixedMealSuspected,
          isNonFoodAbstained: _lastIsNonFoodAbstained,
          isOffline: isOffline,
          isLocalModelUnavailable: _lastIsLocalModelUnavailable,
          aiFailure: failure,
          selectedMealType: _selectedMealType,
        );
      }
      return;
    }

    // Legacy / non-router repository fallback (used by legacy mock repositories in Phase 35.5/35.8 tests)
    try {
      final result = await _repository.scanFoodImage(
        imagePath: imagePath,
        imageBytes: imageBytes,
        foodCatalog: catalog,
        requestId: _activeScanId,
      );

      if (requestId != _currentScanRequestId) return; // Drop response: superseded

      if (result.isEmpty) {
        state = FoodScanNoFoodDetected(
          imagePath: imagePath,
          reason: NoFoodReason.nonFood,
        );
      } else {
        _selectedMealType = defaultMealType();
        state = FoodScanSuccess(
          result: result,
          selectedMealType: _selectedMealType,
        );
      }
    } on FoodScanFailure catch (e) {
      if (requestId != _currentScanRequestId) return;
      state = FoodScanError(
        title: e.title,
        message: e.message,
        failureType: e.type,
        imagePath: imagePath,
        imageBytes: imageBytes,
        retryAfterSeconds: e.retryAfterSeconds,
        localSuggestions: _lastSuggestions,
      );
    } on Failure catch (e) {
      if (requestId != _currentScanRequestId) return;
      state = FoodScanError(
        title: FoodScanErrorCopy.unknownTitle,
        message: e.message,
        failureType: FoodScanFailureType.unknownServiceFailure,
        imagePath: imagePath,
        imageBytes: imageBytes,
        localSuggestions: _lastSuggestions,
      );
    } catch (e, stackTrace) {
      if (requestId != _currentScanRequestId) return;
      LoggerService.error(
          'FoodScanController error analyzing image', e, stackTrace);
      state = FoodScanError(
        title: FoodScanErrorCopy.offlineTitle,
        message: FoodScanErrorCopy.offlineMessage,
        failureType: FoodScanFailureType.offline,
        imagePath: imagePath,
        imageBytes: imageBytes,
        localSuggestions: _lastSuggestions,
      );
    }
  }

  /// User confirms one of the local Top-K suggestions.
  /// Resolves nutrition from FitFuel database with ZERO Gemini calls.
  /// Immediately invalidates any in-flight cloud request so user choice ALWAYS wins.
  void confirmSuggestion(
    LocalFoodCandidate candidate, {
    List<FoodEntity>? catalog,
  }) {
    ++_currentScanRequestId;
    _isOperationInProgress = false;
    if (_activeScanId == 'scan_0') {
      _activeScanId = 'scan_${++_scanSequence}';
    }

    final effectiveCat = _effectiveCatalog(catalog);
    final imagePath = _retainedImagePath ?? '';
    final reqStr = _activeScanId;

    FoodScanResult result;
    if (_repository is IFreeFirstFoodScanRepository) {
      result = _repository.confirmLocalSuggestion(
        candidate: candidate,
        foodCatalog: effectiveCat,
        imagePath: imagePath,
        requestId: reqStr,
        localInferenceDurationMs: _lastPrediction?.inferenceDurationMs,
        allSuggestions: _lastSuggestions,
        top1FoodId: _lastPrediction?.foodId,
      );
    } else {
      final matched = effectiveCat.firstWhere(
        (f) => f.id == candidate.foodId,
        orElse: () => FoodEntity(
          id: candidate.foodId,
          name: candidate.foodName,
          category: 'Other',
          servingSize: 100.0,
          servingUnit: 'g',
          calories: 100.0,
          protein: 5.0,
          carbohydrates: 15.0,
          fats: 2.0,
          fiber: 1.0,
          sugar: 1.0,
          sodium: 50.0,
        ),
      );
      result = FoodScanResult(
        id: reqStr,
        imagePath: imagePath,
        foods: [
          DetectedFoodCandidate(
            id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: matched.name,
            confidence: candidate.confidence,
            estimatedAmount: matched.servingSize,
            originalEstimatedAmount: matched.servingSize,
            estimatedUnit: matched.servingUnit,
            matchedFood: matched,
            matchConfidence: 1.0,
            visualNotes: 'Confirmed from local suggestions',
            aiEstimatedNutrition: null,
            recognitionSource:
                FoodScanRecognitionSource.localSuggestionConfirmed,
            isUserConfirmed: true,
          ),
        ],
        overallConfidence: candidate.confidence,
        scannedAt: DateTime.now(),
        recognitionSource:
            FoodScanRecognitionSource.localSuggestionConfirmed,
        localConfidence: candidate.confidence,
        localInferenceDurationMs: _lastPrediction?.inferenceDurationMs,
        localCandidates:
            _lastSuggestions.isNotEmpty ? _lastSuggestions : [candidate],
      );
    }

    state = FoodScanSuccess(
      result: result,
      selectedMealType: _selectedMealType,
    );
  }

  /// Phase 35.11B: User confirms one of the Tier-2 open-vocabulary suggestions (`SigLIP-B/16`).
  /// Resolves exact FitFuel nutrition if available (`canBeLogged == true`), or transitions
  /// to the honest "Food recognized • Exact nutrition profile isn't available yet" state
  /// (`canBeLogged == false`) with ZERO Gemini calls.
  /// Immediately invalidates any in-flight cloud request so user choice ALWAYS wins.
  void confirmOpenVocabSuggestion(
    OpenVocabularyFoodCandidate candidate, {
    List<FoodEntity>? catalog,
  }) {
    ++_currentScanRequestId;
    _isOperationInProgress = false;
    if (_activeScanId == 'scan_0') {
      _activeScanId = 'scan_${++_scanSequence}';
    }

    final effectiveCat = _effectiveCatalog(catalog);
    final imagePath = _retainedImagePath ?? '';
    final reqStr = _activeScanId;
    final top1CanonicalId = _lastOpenVocabSuggestions.isNotEmpty
        ? _lastOpenVocabSuggestions.first.canonicalFoodId
        : null;

    FoodScanResult result;
    if (_repository is IFreeFirstFoodScanRepository) {
      result = _repository.confirmOpenVocabCandidate(
        candidate: candidate,
        foodCatalog: effectiveCat,
        imagePath: imagePath,
        requestId: reqStr,
        localInferenceDurationMs: _lastRouteDecision?.localInferenceDurationMs,
        allCandidates: _lastOpenVocabSuggestions,
        top1CanonicalId: top1CanonicalId,
      );
    } else {
      final resolution = _universalNutritionResolver.resolveCandidate(
        candidate,
        foodCatalog: effectiveCat,
      );
      final matched = resolution.matchedCatalogFood;

      final visualNotes = resolution.isVerifiedExact
          ? 'Curated FitFuel Food Database'
          : resolution.isGenericBaseline
              ? 'Generic Baseline (${resolution.attribution ?? "USDA FoodData Central"})'
              : resolution.isRecipeEstimate
                  ? 'Recipe Estimate (${resolution.recipeAssumptions ?? "Standard Culinary Formulation"})'
                  : 'Confirmed by you • Select a FitFuel nutrition profile before logging';

      result = FoodScanResult(
        id: reqStr,
        imagePath: imagePath,
        foods: [
          DetectedFoodCandidate(
            id: 'openvocab_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: matched?.name ?? candidate.canonicalName,
            confidence: 1.0,
            estimatedAmount: matched?.servingSize ?? 100.0,
            originalEstimatedAmount: matched?.servingSize ?? 100.0,
            estimatedUnit: matched?.servingUnit ?? 'g',
            matchedFood: matched,
            matchConfidence: resolution.isVerifiedExact
                ? 1.0
                : resolution.isGenericBaseline
                    ? 0.85
                    : resolution.isRecipeEstimate
                        ? 0.75
                        : 0.0,
            visualNotes: visualNotes,
            aiEstimatedNutrition: null,
            recognitionSource:
                FoodScanRecognitionSource.openVocabularyConfirmed,
            isUserConfirmed: true,
            nutritionTier: resolution.tier,
            nutritionExplanation: resolution.explanation,
            recipeAssumptions: resolution.recipeAssumptions,
            nutritionAttribution: resolution.attribution,
          ),
        ],
        overallConfidence: 1.0,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.openVocabularyConfirmed,
        localConfidence: candidate.similarity,
        localInferenceDurationMs: _lastRouteDecision?.localInferenceDurationMs,
        openVocabCandidates: _lastOpenVocabSuggestions.isNotEmpty
            ? _lastOpenVocabSuggestions
            : [candidate],
      );
    }

    state = FoodScanSuccess(
      result: result,
      selectedMealType: _selectedMealType,
    );
  }

  /// User selects a food manually from the 238-food FitFuel catalog search.
  /// Immediately invalidates any in-flight cloud request so user choice ALWAYS wins.
  void selectManualFood(FoodEntity food, {double? amount}) {
    ++_currentScanRequestId;
    _isOperationInProgress = false;
    if (state is FoodScanIdle ||
        state is FoodScanLogged ||
        _activeScanId == 'scan_0') {
      _activeScanId = 'scan_${++_scanSequence}';
      _cloudCallsThisScan = 0;
      _userRequestedAi = false;
    }

    final imagePath = _retainedImagePath ?? '';
    final reqStr = _activeScanId;

    FoodScanResult result;
    if (_repository is IFreeFirstFoodScanRepository) {
      result = _repository.recordManualFoodSelection(
        food: food,
        amount: amount,
        imagePath: imagePath,
        requestId: reqStr,
      );
    } else {
      final servingAmount = amount ?? food.servingSize;
      final isCustom = food.isCustom || food.id.startsWith('manual_');
      result = FoodScanResult(
        id: reqStr,
        imagePath: imagePath,
        foods: [
          DetectedFoodCandidate(
            id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: food.name,
            confidence: 1.0,
            estimatedAmount: servingAmount,
            originalEstimatedAmount: food.servingSize,
            estimatedUnit: food.servingUnit,
            matchedFood: food,
            matchConfidence: 1.0,
            visualNotes: isCustom
                ? 'User-entered custom food nutrition'
                : 'Selected manually from FitFuel catalog',
            aiEstimatedNutrition: null,
            recognitionSource: FoodScanRecognitionSource.manual,
            isUserConfirmed: true,
            nutritionTier: isCustom ? null : NutritionProfileTier.verifiedExact,
            nutritionAttribution: isCustom
                ? 'User-entered nutrition'
                : 'Curated FitFuel Food Database',
          ),
        ],
        overallConfidence: 1.0,
        scannedAt: DateTime.now(),
        recognitionSource: FoodScanRecognitionSource.manual,
      );
    }

    state = FoodScanSuccess(
      result: result,
      selectedMealType: _selectedMealType,
    );
  }

  /// Explicitly invokes Gemini cloud analysis when the user taps "Analyze with AI" or "Retry AI".
  /// On cloud failure (quota, 429, 503, timeout, offline), falls back to the non-blocking
  /// free assistance state (`FoodScanSuggestions`) retaining image and local suggestions.
  Future<void> analyzeWithAi({
    List<FoodEntity>? catalog,
    bool? isOffline,
  }) async {
    if (_isOperationInProgress ||
        state is FoodScanAnalyzing ||
        state is FoodScanLogging) {
      return; // Guard against duplicate taps
    }

    if (_retainedImagePath == null || _retainedImageBytes == null) {
      return;
    }

    final offline = isOffline ?? _isOffline;
    final imagePath = _retainedImagePath!;
    final imageBytes = _retainedImageBytes!;
    final effectiveCat = _effectiveCatalog(catalog);

    if (offline) {
      final offlineFailure =
          FoodScanFailure.fromType(FoodScanFailureType.offline);
      state = FoodScanSuggestions(
        imagePath: imagePath,
        imageBytes: imageBytes,
        suggestions: _lastSuggestions,
        openVocabSuggestions: _lastOpenVocabSuggestions,
        openVocabPresentation: _lastOpenVocabPresentation,
        prediction: _lastPrediction,
        routeDecision: _lastRouteDecision,
        isMixedMealSuspected: _lastIsMixedMealSuspected,
        isNonFoodAbstained: _lastIsNonFoodAbstained,
        isOffline: true,
        isLocalModelUnavailable: _lastIsLocalModelUnavailable,
        aiFailure: offlineFailure,
        selectedMealType: _selectedMealType,
      );
      return;
    }

    if (_activeScanId == 'scan_0') {
      _activeScanId = 'scan_${++_scanSequence}';
    }
    _userRequestedAi = true;
    _cloudCallsThisScan++;
    _isOperationInProgress = true;
    final requestId = ++_currentScanRequestId;

    state = FoodScanAnalyzing(
      imagePath: imagePath,
      stageMessage: 'Analyzing with AI...',
    );

    try {
      final reqStr = _activeScanId;
      final FoodScanResult result;
      if (_repository is IFreeFirstFoodScanRepository) {
        result = await _repository.analyzeWithAi(
          imagePath: imagePath,
          imageBytes: imageBytes,
          foodCatalog: effectiveCat,
          requestId: reqStr,
          priorLocalPrediction: _lastPrediction,
          localInferenceDurationMs: _lastPrediction?.inferenceDurationMs ?? 0,
          isOffline: offline,
          userRequestedAi: true,
        );
      } else {
        result = await _repository.scanFoodImage(
          imagePath: imagePath,
          imageBytes: imageBytes,
          foodCatalog: effectiveCat,
          requestId: reqStr,
        );
      }

      if (requestId != _currentScanRequestId) {
        return; // Drop stale cloud response: user already confirmed local/manual choice
      }

      if (result.isEmpty) {
        state = FoodScanSuggestions(
          imagePath: imagePath,
          imageBytes: imageBytes,
          suggestions: _lastSuggestions,
          openVocabSuggestions: _lastOpenVocabSuggestions,
          openVocabPresentation: _lastOpenVocabPresentation,
          prediction: _lastPrediction,
          routeDecision: _lastRouteDecision,
          isMixedMealSuspected: _lastIsMixedMealSuspected,
          isNonFoodAbstained: _lastIsNonFoodAbstained,
          isOffline: offline,
          isLocalModelUnavailable: _lastIsLocalModelUnavailable,
          aiFailure:
              FoodScanFailure.fromType(FoodScanFailureType.noFoodDetected),
          selectedMealType: _selectedMealType,
        );
      } else {
        state = FoodScanSuccess(
          result: result,
          selectedMealType: _selectedMealType,
        );
      }
    } on FoodScanFailure catch (e) {
      if (requestId != _currentScanRequestId) return;
      state = FoodScanSuggestions(
        imagePath: imagePath,
        imageBytes: imageBytes,
        suggestions: _lastSuggestions,
        openVocabSuggestions: _lastOpenVocabSuggestions,
        openVocabPresentation: _lastOpenVocabPresentation,
        prediction: _lastPrediction,
        routeDecision: _lastRouteDecision,
        isMixedMealSuspected: _lastIsMixedMealSuspected,
        isNonFoodAbstained: _lastIsNonFoodAbstained,
        isOffline: offline,
        isLocalModelUnavailable: _lastIsLocalModelUnavailable,
        aiFailure: e,
        selectedMealType: _selectedMealType,
      );
    } on Failure catch (e) {
      if (requestId != _currentScanRequestId) return;
      state = FoodScanSuggestions(
        imagePath: imagePath,
        imageBytes: imageBytes,
        suggestions: _lastSuggestions,
        openVocabSuggestions: _lastOpenVocabSuggestions,
        openVocabPresentation: _lastOpenVocabPresentation,
        prediction: _lastPrediction,
        routeDecision: _lastRouteDecision,
        isMixedMealSuspected: _lastIsMixedMealSuspected,
        isNonFoodAbstained: _lastIsNonFoodAbstained,
        isOffline: offline,
        isLocalModelUnavailable: _lastIsLocalModelUnavailable,
        aiFailure: FoodScanFailure.fromType(
          FoodScanFailureType.unknownServiceFailure,
          messageOverride: e.message,
        ),
        selectedMealType: _selectedMealType,
      );
    } catch (e, stackTrace) {
      if (requestId != _currentScanRequestId) return;
      LoggerService.error(
          'FoodScanController error during analyzeWithAi', e, stackTrace);
      state = FoodScanSuggestions(
        imagePath: imagePath,
        imageBytes: imageBytes,
        suggestions: _lastSuggestions,
        openVocabSuggestions: _lastOpenVocabSuggestions,
        openVocabPresentation: _lastOpenVocabPresentation,
        prediction: _lastPrediction,
        routeDecision: _lastRouteDecision,
        isMixedMealSuspected: _lastIsMixedMealSuspected,
        isNonFoodAbstained: _lastIsNonFoodAbstained,
        isOffline: offline,
        isLocalModelUnavailable: _lastIsLocalModelUnavailable,
        aiFailure: FoodScanFailure.fromType(
          FoodScanFailureType.serviceUnavailable,
        ),
        selectedMealType: _selectedMealType,
      );
    } finally {
      if (requestId == _currentScanRequestId) {
        _isOperationInProgress = false;
      }
    }
  }

  /// Explicit alias for the "Retry AI" button action.
  Future<void> retryAi({
    List<FoodEntity>? catalog,
    bool? isOffline,
  }) =>
      analyzeWithAi(catalog: catalog, isOffline: isOffline);

  /// Toggles the "Other possible matches" accordion in `primaryWithAlternatives` mode
  /// without counting as a new scan or invoking any inference.
  void toggleOtherMatchesExpanded() {
    if (state is! FoodScanSuggestions) return;
    final current = state as FoodScanSuggestions;
    state = current.copyWith(
      isOtherMatchesExpanded: !current.isOtherMatchesExpanded,
    );
  }

  /// Retries local free-first scanning with the retained image without reopening camera or picker.
  /// Never automatically triggers Gemini; Gemini requires an explicit [analyzeWithAi] / [retryAi] call.
  Future<void> retryScan() async {
    if (state is FoodScanAnalyzing || state is FoodScanLogging) {
      return; // Guard against double-tap
    }
    if (_retainedImagePath == null || _retainedImageBytes == null) {
      state = const FoodScanIdle();
      return;
    }

    final requestId = ++_currentScanRequestId;
    _activeScanId = 'scan_${++_scanSequence}';
    _cloudCallsThisScan = 0;
    _userRequestedAi = false;
    await _performScan(
      imagePath: _retainedImagePath!,
      imageBytes: _retainedImageBytes!,
      catalog: _cachedCatalog,
      requestId: requestId,
      isOffline: _isOffline,
      isMixedMealSuspected: _lastIsMixedMealSuspected,
    );
  }

  /// Adjusts the estimated portion size for a candidate at [index].
  void updatePortion(int index, double newAmount) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    final existing = updatedFoods[index];
    updatedFoods[index] = existing.copyWith(
      estimatedAmount: newAmount.clamp(5.0, 2500.0),
    );

    state = current.copyWith(
      result: current.result.copyWith(foods: updatedFoods),
    );
  }

  /// Replaces or assigns a FitFuel database [FoodEntity] to a candidate at [index].
  void updateMatchedFood(int index, FoodEntity newFood) {
    ++_currentScanRequestId;
    _isOperationInProgress = false;

    if (state is! FoodScanSuccess) {
      selectManualFood(newFood);
      return;
    }
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    final existing = updatedFoods[index];
    final targetAmount = existing.matchedFood == null
        ? newFood.servingSize
        : existing.estimatedAmount;
    final isCustom = newFood.isCustom || newFood.id.startsWith('manual_');
    updatedFoods[index] = DetectedFoodCandidate(
      id: existing.id,
      detectedName: existing.detectedName,
      confidence: existing.confidence,
      estimatedAmount: targetAmount,
      originalEstimatedAmount: newFood.servingSize,
      estimatedUnit: newFood.servingUnit,
      matchedFood: newFood,
      matchConfidence: 1.0,
      visualNotes: isCustom ? 'User-entered nutrition' : 'Curated FitFuel Food Database',
      aiEstimatedNutrition: null,
      recognitionSource: FoodScanRecognitionSource.manual,
      isUserConfirmed: true,
      nutritionTier: isCustom ? null : NutritionProfileTier.verifiedExact,
      nutritionExplanation: isCustom ? 'User supplied custom nutrition values.' : null,
      nutritionAttribution: isCustom
          ? 'User-entered nutrition'
          : 'Curated FitFuel Food Database',
    );

    final allManual = updatedFoods
        .every((f) => f.recognitionSource == FoodScanRecognitionSource.manual);

    if (allManual && _repository is IFreeFirstFoodScanRepository) {
      _repository.recordManualFoodSelection(
        food: newFood,
        amount: targetAmount,
        imagePath: current.result.imagePath ?? _retainedImagePath ?? '',
        requestId: _activeScanId,
      );
    }

    state = current.copyWith(
      result: current.result.copyWith(
        foods: updatedFoods,
        recognitionSource: allManual
            ? FoodScanRecognitionSource.manual
            : current.result.recognitionSource,
      ),
    );
  }

  /// Removes a detected food component at [index].
  void removeComponent(int index) {
    if (state is! FoodScanSuccess) return;
    final current = state as FoodScanSuccess;
    if (index < 0 || index >= current.result.foods.length) return;

    final updatedFoods = List<DetectedFoodCandidate>.from(current.result.foods);
    updatedFoods.removeAt(index);

    if (updatedFoods.isEmpty) {
      state = FoodScanNoFoodDetected(
        imagePath: current.result.imagePath,
        reason: NoFoodReason.emptyResult,
        customMessage: 'All food items were removed from this meal.',
      );
    } else {
      state = current.copyWith(
        result: current.result.copyWith(foods: updatedFoods),
      );
    }
  }

  /// Adds a food item from the FitFuel database to the current scan result,
  /// or initializes a manual scan result if called from suggestions / error / mixed-meal states.
  /// Prevents duplicate components and accidental double-counting by incrementing the existing
  /// component's portion if already present.
  void addComponent(FoodEntity food, {double? amount}) {
    ++_currentScanRequestId;
    _isOperationInProgress = false;

    if (state is! FoodScanSuccess) {
      selectManualFood(food, amount: amount);
      return;
    }

    final current = state as FoodScanSuccess;
    final servingAmount = amount ?? food.servingSize;

    // Check for duplicate components to prevent accidental double counting (Phase 35.12.8 Requirement 3)
    final existingIndex = current.result.foods.indexWhere(
      (f) =>
          (f.matchedFood != null && f.matchedFood!.id == food.id) ||
          f.displayName.trim().toLowerCase() == food.name.trim().toLowerCase(),
    );

    if (existingIndex != -1) {
      final existing = current.result.foods[existingIndex];
      updatePortion(existingIndex, existing.estimatedAmount + servingAmount);
      return;
    }

    final isCustom = food.isCustom || food.id.startsWith('manual_');
    final newCandidate = DetectedFoodCandidate(
      id: 'added_${DateTime.now().millisecondsSinceEpoch}',
      detectedName: food.name,
      confidence: 1.0,
      estimatedAmount: servingAmount,
      originalEstimatedAmount: food.servingSize,
      estimatedUnit: food.servingUnit,
      matchedFood: food,
      matchConfidence: 1.0,
      recognitionSource: FoodScanRecognitionSource.manual,
      isUserConfirmed: true,
      nutritionTier: isCustom ? null : NutritionProfileTier.verifiedExact,
      nutritionAttribution: isCustom
          ? 'User-entered nutrition'
          : 'Curated FitFuel Food Database',
    );

    final updatedFoods = [...current.result.foods, newCandidate];
    state = current.copyWith(
      result: current.result.copyWith(foods: updatedFoods),
    );
  }

  /// Changes the targeted meal slot (Breakfast / Lunch / Dinner / Snack).
  void selectMealType(String mealType) {
    _selectedMealType = mealType;
    if (state is FoodScanSuccess) {
      final current = state as FoodScanSuccess;
      state = current.copyWith(selectedMealType: mealType);
    } else if (state is FoodScanSuggestions) {
      final current = state as FoodScanSuggestions;
      state = current.copyWith(selectedMealType: mealType);
    }
  }

  /// Adds all confirmed detected foods to the Food Diary.
  /// Requires all items to have valid nutrition (incomplete items must be resolved first).
  Future<bool> logToDiary(
      String uid, INutritionRepository nutritionRepo) async {
    if (state is! FoodScanSuccess) return false;
    final current = state as FoodScanSuccess;
    final confirmedFoods = current.result.foods;

    if (confirmedFoods.isEmpty) return false;

    // Safety rule: Never log foods with incomplete nutrition
    if (current.result.hasIncompleteNutrition) {
      return false;
    }

    state = FoodScanLogging(
      result: current.result,
      selectedMealType: current.selectedMealType,
    );

    try {
      final now = DateTime.now();
      for (var i = 0; i < confirmedFoods.length; i++) {
        final item = confirmedFoods[i];
        final record = NutritionRecordEntity(
          id: 'scan_${now.millisecondsSinceEpoch}_$i',
          foodName: item.displayName,
          mealType: current.selectedMealType,
          calories: item.scaledCalories,
          protein: item.scaledProtein,
          carbohydrates: item.scaledCarbs,
          fats: item.scaledFats,
          sugar: item.sugar ?? 0.0,
          fiber: item.fiber,
          sodium: item.sodium,
          servingSize: item.estimatedAmount,
          foodId: item.matchedFood?.id,
          baseServingSize: item.matchedFood?.servingSize,
          baseCalories: item.matchedFood?.calories,
          baseProtein: item.matchedFood?.protein,
          baseCarbohydrates: item.matchedFood?.carbohydrates,
          baseFats: item.matchedFood?.fats,
          baseFiber: item.matchedFood?.fiber,
          baseSugar: item.matchedFood?.sugar,
          baseSodium: item.matchedFood?.sodium,
          nutritionTier: item.nutritionTier,
          nutritionAttribution: item.nutritionAttribution,
          recipeAssumptions: item.recipeAssumptions,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await nutritionRepo.addRecord(uid, record);
      }

      state = FoodScanLogged(
        itemsLoggedCount: confirmedFoods.length,
        totalCalories: current.result.totalCalories,
        mealType: current.selectedMealType,
      );
      return true;
    } catch (e, stackTrace) {
      LoggerService.error(
          'FoodScanController error logging to diary', e, stackTrace);
      state = FoodScanError(
        title: FoodScanErrorCopy.unknownTitle,
        message: 'Failed to add meal to Food Diary. Please try again.',
        imagePath: current.result.imagePath,
        imageBytes: _retainedImageBytes,
        localSuggestions: _lastSuggestions,
      );
      return false;
    }
  }

  /// Resets back to idle state, invalidates in-flight requests, and clears retained image.
  void reset() {
    _currentScanRequestId++;
    _isOperationInProgress = false;
    _retainedImagePath = null;
    _retainedImageBytes = null;
    _lastSuggestions = const [];
    _lastOpenVocabSuggestions = const [];
    _lastOpenVocabPresentation = null;
    _lastPrediction = null;
    _lastRouteDecision = null;
    _lastIsMixedMealSuspected = false;
    _lastIsNonFoodAbstained = false;
    _lastIsLocalModelUnavailable = false;
    state = const FoodScanIdle();
  }

  @override
  void dispose() {
    _currentScanRequestId++;
    if (_repository is IFreeFirstFoodScanRepository) {
      _repository.disposeLocalSessions();
    }
    super.dispose();
  }
}
