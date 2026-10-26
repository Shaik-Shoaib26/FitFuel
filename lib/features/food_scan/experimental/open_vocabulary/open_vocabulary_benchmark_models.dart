import 'dart:convert';

/// Canonical per-image benchmark record matching Phase 35.11A Section 53.
class OpenVocabularyBenchmarkRecord {
  final String imageId;
  final String actualFood;
  final String cuisine;
  final String category;
  final String candidateModel;
  final String top1;
  final double top1Score;
  final List<String> top3;
  final List<String> top5;
  final bool correctTop1;
  final bool correctTop3;
  final bool correctTop5;
  final double latencyMs;
  final double imageDecodeMs;
  final double preprocessMs;
  final double inferenceMs;
  final double retrievalMs;
  final bool isFlaggedAsNonFood;
  final String? matchedAlias;

  const OpenVocabularyBenchmarkRecord({
    required this.imageId,
    required this.actualFood,
    required this.cuisine,
    required this.category,
    required this.candidateModel,
    required this.top1,
    required this.top1Score,
    required this.top3,
    required this.top5,
    required this.correctTop1,
    required this.correctTop3,
    required this.correctTop5,
    required this.latencyMs,
    this.imageDecodeMs = 0.0,
    this.preprocessMs = 0.0,
    this.inferenceMs = 0.0,
    this.retrievalMs = 0.0,
    this.isFlaggedAsNonFood = false,
    this.matchedAlias,
  });

  Map<String, dynamic> toJson() => {
        'image_id': imageId,
        'actual_food': actualFood,
        'cuisine': cuisine,
        'category': category,
        'candidate_model': candidateModel,
        'top1': top1,
        'top1_score': top1Score,
        'top3': top3,
        'top5': top5,
        'correct_top1': correctTop1,
        'correct_top3': correctTop3,
        'correct_top5': correctTop5,
        'latency_ms': latencyMs,
        'image_decode_ms': imageDecodeMs,
        'preprocess_ms': preprocessMs,
        'inference_ms': inferenceMs,
        'retrieval_ms': retrievalMs,
        'is_flagged_as_non_food': isFlaggedAsNonFood,
        if (matchedAlias != null) 'matched_alias': matchedAlias,
      };

  factory OpenVocabularyBenchmarkRecord.fromJson(Map<String, dynamic> json) {
    return OpenVocabularyBenchmarkRecord(
      imageId: json['image_id'] as String? ?? '',
      actualFood: json['actual_food'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      category: json['category'] as String? ?? '',
      candidateModel: json['candidate_model'] as String? ?? '',
      top1: json['top1'] as String? ?? '',
      top1Score: (json['top1_score'] as num?)?.toDouble() ?? 0.0,
      top3: (json['top3'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      top5: (json['top5'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      correctTop1: json['correct_top1'] as bool? ?? false,
      correctTop3: json['correct_top3'] as bool? ?? false,
      correctTop5: json['correct_top5'] as bool? ?? false,
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      imageDecodeMs: (json['image_decode_ms'] as num?)?.toDouble() ?? 0.0,
      preprocessMs: (json['preprocess_ms'] as num?)?.toDouble() ?? 0.0,
      inferenceMs: (json['inference_ms'] as num?)?.toDouble() ?? 0.0,
      retrievalMs: (json['retrieval_ms'] as num?)?.toDouble() ?? 0.0,
      isFlaggedAsNonFood: json['is_flagged_as_non_food'] as bool? ?? false,
      matchedAlias: json['matched_alias'] as String?,
    );
  }
}

/// Summary metrics for an evaluated open-vocabulary candidate model.
class OpenVocabularyModelBenchmarkSummary {
  final String modelName;
  final String runtime;
  final String license;
  final bool commercialUseAllowed;
  final double modelSizeMb;
  final double top1Accuracy;
  final double top3Accuracy;
  final double top5Accuracy;
  final double meanReciprocalRank;
  final double nonFoodFalseAcceptanceRate;
  final double coldLoadMs;
  final double firstInferenceMs;
  final double meanWarmInferenceMs;
  final double p50TotalMs;
  final double p95TotalMs;
  final double meanPreprocessMs;
  final double meanRetrievalMs;
  final double meanTotalMs;
  final double peakMemoryMb;
  final String decision;

  const OpenVocabularyModelBenchmarkSummary({
    required this.modelName,
    required this.runtime,
    required this.license,
    required this.commercialUseAllowed,
    required this.modelSizeMb,
    required this.top1Accuracy,
    required this.top3Accuracy,
    required this.top5Accuracy,
    required this.meanReciprocalRank,
    required this.nonFoodFalseAcceptanceRate,
    required this.coldLoadMs,
    required this.firstInferenceMs,
    required this.meanWarmInferenceMs,
    required this.p50TotalMs,
    required this.p95TotalMs,
    required this.meanPreprocessMs,
    required this.meanRetrievalMs,
    required this.meanTotalMs,
    required this.peakMemoryMb,
    required this.decision,
  });

  Map<String, dynamic> toJson() => {
        'model_name': modelName,
        'runtime': runtime,
        'license': license,
        'commercial_use_allowed': commercialUseAllowed,
        'model_size_mb': modelSizeMb,
        'top1_accuracy': top1Accuracy,
        'top3_accuracy': top3Accuracy,
        'top5_accuracy': top5Accuracy,
        'mean_reciprocal_rank': meanReciprocalRank,
        'non_food_false_acceptance_rate': nonFoodFalseAcceptanceRate,
        'cold_load_ms': coldLoadMs,
        'first_inference_ms': firstInferenceMs,
        'mean_warm_inference_ms': meanWarmInferenceMs,
        'p50_total_ms': p50TotalMs,
        'p95_total_ms': p95TotalMs,
        'mean_preprocess_ms': meanPreprocessMs,
        'mean_retrieval_ms': meanRetrievalMs,
        'mean_total_ms': meanTotalMs,
        'peak_memory_mb': peakMemoryMb,
        'decision': decision,
      };

  factory OpenVocabularyModelBenchmarkSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return OpenVocabularyModelBenchmarkSummary(
      modelName: json['model_name'] as String? ?? '',
      runtime: json['runtime'] as String? ?? '',
      license: json['license'] as String? ?? '',
      commercialUseAllowed: json['commercial_use_allowed'] as bool? ?? false,
      modelSizeMb: (json['model_size_mb'] as num?)?.toDouble() ?? 0.0,
      top1Accuracy: (json['top1_accuracy'] as num?)?.toDouble() ?? 0.0,
      top3Accuracy: (json['top3_accuracy'] as num?)?.toDouble() ?? 0.0,
      top5Accuracy: (json['top5_accuracy'] as num?)?.toDouble() ?? 0.0,
      meanReciprocalRank:
          (json['mean_reciprocal_rank'] as num?)?.toDouble() ?? 0.0,
      nonFoodFalseAcceptanceRate:
          (json['non_food_false_acceptance_rate'] as num?)?.toDouble() ?? 0.0,
      coldLoadMs: (json['cold_load_ms'] as num?)?.toDouble() ?? 0.0,
      firstInferenceMs:
          (json['first_inference_ms'] as num?)?.toDouble() ?? 0.0,
      meanWarmInferenceMs:
          (json['mean_warm_inference_ms'] as num?)?.toDouble() ?? 0.0,
      p50TotalMs: (json['p50_total_ms'] as num?)?.toDouble() ?? 0.0,
      p95TotalMs: (json['p95_total_ms'] as num?)?.toDouble() ?? 0.0,
      meanPreprocessMs:
          (json['mean_preprocess_ms'] as num?)?.toDouble() ?? 0.0,
      meanRetrievalMs: (json['mean_retrieval_ms'] as num?)?.toDouble() ?? 0.0,
      meanTotalMs: (json['mean_total_ms'] as num?)?.toDouble() ?? 0.0,
      peakMemoryMb: (json['peak_memory_mb'] as num?)?.toDouble() ?? 0.0,
      decision: json['decision'] as String? ?? 'REJECT',
    );
  }
}

/// Top-level canonical benchmark suite container for Phase 35.11A.
class OpenVocabularyBenchmarkSuiteReport {
  final String phase;
  final int canonicalFoodsCount;
  final int aliasesCount;
  final int totalTextLabelsCount;
  final int foodImagesCount;
  final int distinctFoodConceptsCount;
  final int nonFoodImagesCount;
  final int mixedMealImagesCount;
  final int cloudCallsCount;
  final List<OpenVocabularyModelBenchmarkSummary> models;
  final List<OpenVocabularyBenchmarkRecord> records;

  const OpenVocabularyBenchmarkSuiteReport({
    this.phase = '35.11A',
    required this.canonicalFoodsCount,
    required this.aliasesCount,
    required this.totalTextLabelsCount,
    required this.foodImagesCount,
    required this.distinctFoodConceptsCount,
    required this.nonFoodImagesCount,
    required this.mixedMealImagesCount,
    this.cloudCallsCount = 0,
    required this.models,
    required this.records,
  });

  Map<String, dynamic> toJson() => {
        'phase': phase,
        'canonical_foods_count': canonicalFoodsCount,
        'aliases_count': aliasesCount,
        'total_text_labels_count': totalTextLabelsCount,
        'food_images_count': foodImagesCount,
        'distinct_food_concepts_count': distinctFoodConceptsCount,
        'non_food_images_count': nonFoodImagesCount,
        'mixed_meal_images_count': mixedMealImagesCount,
        'cloud_calls_count': cloudCallsCount,
        'models': models.map((m) => m.toJson()).toList(growable: false),
        'records': records.map((r) => r.toJson()).toList(growable: false),
      };

  String toJsonString({bool pretty = true}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  factory OpenVocabularyBenchmarkSuiteReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return OpenVocabularyBenchmarkSuiteReport(
      phase: json['phase'] as String? ?? '35.11A',
      canonicalFoodsCount: json['canonical_foods_count'] as int? ?? 0,
      aliasesCount: json['aliases_count'] as int? ?? 0,
      totalTextLabelsCount: json['total_text_labels_count'] as int? ?? 0,
      foodImagesCount: json['food_images_count'] as int? ?? 0,
      distinctFoodConceptsCount:
          json['distinct_food_concepts_count'] as int? ?? 0,
      nonFoodImagesCount: json['non_food_images_count'] as int? ?? 0,
      mixedMealImagesCount: json['mixed_meal_images_count'] as int? ?? 0,
      cloudCallsCount: json['cloud_calls_count'] as int? ?? 0,
      models: (json['models'] as List<dynamic>? ?? const [])
          .map(
            (e) => OpenVocabularyModelBenchmarkSummary.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      records: (json['records'] as List<dynamic>? ?? const [])
          .map(
            (e) => OpenVocabularyBenchmarkRecord.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}
