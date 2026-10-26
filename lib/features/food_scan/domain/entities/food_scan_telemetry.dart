import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';

/// Telemetry event capturing production metrics for Food Scan operations.
class FoodScanTelemetryEvent {
  final String requestId;
  final String model;
  final int attemptCount;
  final int? statusCode;
  final int durationMs;
  final int imageSizeBytes;
  final bool isFallback;
  final bool isSuccess;
  final FoodScanFailureType? failureType;
  final DateTime timestamp;

  /// Phase 35.9 / 35.10 hybrid & free-first scan metrics:
  final String? recognitionSource;
  final String? route;
  final double? localConfidence;
  final int? localInferenceDurationMs;
  final bool cloudFallbackUsed;

  const FoodScanTelemetryEvent({
    required this.requestId,
    required this.model,
    required this.attemptCount,
    this.statusCode,
    required this.durationMs,
    required this.imageSizeBytes,
    required this.isFallback,
    required this.isSuccess,
    this.failureType,
    required this.timestamp,
    this.recognitionSource,
    this.route,
    this.localConfidence,
    this.localInferenceDurationMs,
    this.cloudFallbackUsed = false,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'model': model,
        'attempt_count': attemptCount,
        'status_code': statusCode,
        'duration_ms': durationMs,
        'image_size_bytes': imageSizeBytes,
        'is_fallback': isFallback,
        'is_success': isSuccess,
        'failure_type': failureType?.name,
        'timestamp': timestamp.toIso8601String(),
        'recognition_source': recognitionSource,
        'route': route,
        'local_confidence': localConfidence,
        'local_inference_duration_ms': localInferenceDurationMs,
        'cloud_fallback_used': cloudFallbackUsed,
      };

  @override
  String toString() =>
      '[FoodScanTelemetry] req=$requestId model=$model attempts=$attemptCount '
      'status=$statusCode duration=${durationMs}ms size=${imageSizeBytes}B '
      'fallback=$isFallback success=$isSuccess failure=${failureType?.name} '
      'source=$recognitionSource route=$route localConf=$localConfidence '
      'localDuration=${localInferenceDurationMs}ms cloudFallback=$cloudFallbackUsed';
}

/// Callback definition for capturing Food Scan telemetry events.
typedef FoodScanTelemetrySink = void Function(FoodScanTelemetryEvent event);

/// Mutually exclusive completion routes for a single scan lifecycle (Phase 35.10.1 / 35.11B / 35.11B.1).
enum FoodScanCompletionRoute {
  // Phase 35.11B.1 mutually exclusive routes:
  tier1AutoLocal,
  tier2SingleResult,
  tier2SingleResultWithNutrition,
  tier2SingleResultRequiresNutrition,
  tier2AmbiguousAbstain,
  tier2NonFood,
  tier2Unavailable,
  manualConfirmed,
  geminiExplicit,

  // Backward-compatible aliases:
  autoLocal,
  suggestionConfirmed,
  openVocabConfirmed,
  geminiCompleted;

  String get routeLabel {
    switch (this) {
      case FoodScanCompletionRoute.tier1AutoLocal:
      case FoodScanCompletionRoute.autoLocal:
        return 'tier1_auto_local';
      case FoodScanCompletionRoute.tier2SingleResult:
        return 'tier2_single_result';
      case FoodScanCompletionRoute.tier2SingleResultWithNutrition:
        return 'tier2_single_result_with_nutrition';
      case FoodScanCompletionRoute.tier2SingleResultRequiresNutrition:
        return 'tier2_single_result_requires_nutrition';
      case FoodScanCompletionRoute.tier2AmbiguousAbstain:
        return 'tier2_ambiguous_abstain';
      case FoodScanCompletionRoute.tier2NonFood:
        return 'tier2_non_food';
      case FoodScanCompletionRoute.tier2Unavailable:
        return 'tier2_unavailable';
      case FoodScanCompletionRoute.suggestionConfirmed:
        return 'suggestion_confirmed';
      case FoodScanCompletionRoute.openVocabConfirmed:
        return 'open_vocab_confirmed';
      case FoodScanCompletionRoute.manualConfirmed:
        return 'manual_confirmed';
      case FoodScanCompletionRoute.geminiExplicit:
      case FoodScanCompletionRoute.geminiCompleted:
        return 'gemini_explicit';
    }
  }
}

