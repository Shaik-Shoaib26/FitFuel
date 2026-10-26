import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';

/// Structured result of running the Tier-2 on-device open-vocabulary food
/// recognizer (`SigLIP-B/16 INT8`) and its food / non-food safety gate.
class OpenVocabularyRecognitionResult {
  final bool accepted;
  final bool abstained;
  final bool isNonFoodRejected;
  final bool isUnavailable;
  final List<OpenVocabularyFoodCandidate> topCandidates;
  final String modelId;
  final double topSimilarity;
  final double negativeSimilarity;
  final double negativeMargin;
  final String? topNegativePrompt;
  final String decisionReason;
  final int modelLoadMs;
  final int preprocessMs;
  final int encoderMs;
  final int retrievalMs;
  final int totalMs;
  final bool sessionReused;
  final String? errorReason;

  const OpenVocabularyRecognitionResult({
    required this.accepted,
    required this.abstained,
    required this.isNonFoodRejected,
    required this.isUnavailable,
    required this.topCandidates,
    this.modelId = 'siglip_b16_int8',
    this.topSimilarity = 0.0,
    this.negativeSimilarity = 0.0,
    this.negativeMargin = 0.0,
    this.topNegativePrompt,
    required this.decisionReason,
    this.modelLoadMs = 0,
    this.preprocessMs = 0,
    this.encoderMs = 0,
    this.retrievalMs = 0,
    this.totalMs = 0,
    this.sessionReused = false,
    this.errorReason,
  });

  OpenVocabularyFoodCandidate? get top1 =>
      topCandidates.isNotEmpty ? topCandidates.first : null;

  factory OpenVocabularyRecognitionResult.accepted({
    required List<OpenVocabularyFoodCandidate> topCandidates,
    double maxFoodSimilarity = 0.0,
    double maxNegSimilarity = 0.0,
    double negMargin = 0.0,
    String? topNegativePrompt,
    int modelLoadMs = 0,
    int preprocessMs = 0,
    int encoderMs = 0,
    int retrievalMs = 0,
    int totalMs = 0,
    bool sessionReused = true,
    String modelId = 'siglip_b16_int8',
  }) {
    return OpenVocabularyRecognitionResult(
      accepted: true,
      abstained: false,
      isNonFoodRejected: false,
      isUnavailable: false,
      topCandidates: topCandidates,
      modelId: modelId,
      topSimilarity: maxFoodSimilarity,
      negativeSimilarity: maxNegSimilarity,
      negativeMargin: negMargin,
      topNegativePrompt: topNegativePrompt,
      decisionReason: 'accepted_open_vocab',
      modelLoadMs: modelLoadMs,
      preprocessMs: preprocessMs,
      encoderMs: encoderMs,
      retrievalMs: retrievalMs,
      totalMs: totalMs,
      sessionReused: sessionReused,
    );
  }

  factory OpenVocabularyRecognitionResult.abstained({
    double maxFoodSimilarity = 0.0,
    double maxNegSimilarity = 0.0,
    double negMargin = 0.0,
    String? topNegativePrompt,
    String abstainReason = 'below_similarity_threshold',
    int modelLoadMs = 0,
    int preprocessMs = 0,
    int encoderMs = 0,
    int retrievalMs = 0,
    int totalMs = 0,
    bool sessionReused = true,
    String modelId = 'siglip_b16_int8',
  }) {
    final isNonFood = abstainReason == 'non_food_negative_margin' ||
        abstainReason == 'rejected_non_food_margin';
    return OpenVocabularyRecognitionResult(
      accepted: false,
      abstained: true,
      isNonFoodRejected: isNonFood,
      isUnavailable: false,
      topCandidates: const [],
      modelId: modelId,
      topSimilarity: maxFoodSimilarity,
      negativeSimilarity: maxNegSimilarity,
      negativeMargin: negMargin,
      topNegativePrompt: topNegativePrompt,
      decisionReason: isNonFood
          ? 'rejected_non_food_margin'
          : 'rejected_low_food_similarity',
      modelLoadMs: modelLoadMs,
      preprocessMs: preprocessMs,
      encoderMs: encoderMs,
      retrievalMs: retrievalMs,
      totalMs: totalMs,
      sessionReused: sessionReused,
    );
  }

  factory OpenVocabularyRecognitionResult.unavailable({
    String? reason,
    String modelId = 'siglip_b16_int8',
  }) {
    final msg = reason ?? 'Tier-2 open-vocabulary model is unavailable.';
    return OpenVocabularyRecognitionResult(
      accepted: false,
      abstained: true,
      isNonFoodRejected: false,
      isUnavailable: true,
      topCandidates: const [],
      modelId: modelId,
      decisionReason: 'tier2_unavailable',
      errorReason: msg,
    );
  }

  factory OpenVocabularyRecognitionResult.fromNativeMap(
    Map<dynamic, dynamic> map,
  ) {
    final rawTop = map['topCandidates'] ?? map['top5'] ?? const [];
    final parsedCandidates = <OpenVocabularyFoodCandidate>[];
    if (rawTop is List) {
      for (var i = 0; i < rawTop.length; i++) {
        final item = rawTop[i];
        if (item is Map) {
          parsedCandidates.add(
            OpenVocabularyFoodCandidate.fromJson(item, fallbackRank: i + 1),
          );
        }
      }
    }

    final accepted = map['accepted'] == true || map['foodAccepted'] == true;
    final abstainReason = map['abstainReason']?.toString();
    final isNonFoodRejected = map['isNonFoodRejected'] == true ||
        abstainReason == 'non_food_negative_margin';
    final isUnavailable = map['isUnavailable'] == true;
    final abstained = map['abstained'] == true || !accepted;

    return OpenVocabularyRecognitionResult(
      accepted: accepted,
      abstained: abstained,
      isNonFoodRejected: isNonFoodRejected,
      isUnavailable: isUnavailable,
      topCandidates: parsedCandidates,
      modelId:
          (map['modelId'] ?? map['modelVersion'] ?? 'siglip_b16_int8').toString(),
      topSimilarity: ((map['topSimilarity'] ??
                  map['maxFoodSimilarity'] ??
                  map['topFoodSim']) as num?)
              ?.toDouble() ??
          0.0,
      negativeSimilarity: ((map['negativeSimilarity'] ??
                  map['maxNegSimilarity'] ??
                  map['maxNegSim']) as num?)
              ?.toDouble() ??
          0.0,
      negativeMargin:
          ((map['negativeMargin'] ?? map['negMargin']) as num?)?.toDouble() ??
              0.0,
      topNegativePrompt:
          (map['topNegativePrompt'] ?? map['topNegLabel'])?.toString(),
      decisionReason: (map['decisionReason'] ??
              (accepted
                  ? 'accepted_open_vocab'
                  : (isNonFoodRejected
                      ? 'rejected_non_food_margin'
                      : 'rejected_low_food_similarity')))
          .toString(),
      modelLoadMs: ((map['modelLoadMs'] ??
                  map['coldInitMs'] ??
                  map['initMs']) as num?)
              ?.toInt() ??
          0,
      preprocessMs: (map['preprocessMs'] as num?)?.toInt() ?? 0,
      encoderMs: (map['encoderMs'] as num?)?.toInt() ?? 0,
      retrievalMs: (map['retrievalMs'] as num?)?.toInt() ?? 0,
      totalMs: (map['totalMs'] as num?)?.toInt() ?? 0,
      sessionReused: map['sessionReused'] == true || map['isColdInit'] == false,
      errorReason: map['errorReason']?.toString(),
    );
  }

  OpenVocabularyRecognitionResult copyWith({
    bool? accepted,
    bool? abstained,
    bool? isNonFoodRejected,
    bool? isUnavailable,
    List<OpenVocabularyFoodCandidate>? topCandidates,
    String? modelId,
    double? topSimilarity,
    double? negativeSimilarity,
    double? negativeMargin,
    String? topNegativePrompt,
    String? decisionReason,
    int? modelLoadMs,
    int? preprocessMs,
    int? encoderMs,
    int? retrievalMs,
    int? totalMs,
    bool? sessionReused,
    String? errorReason,
  }) {
    return OpenVocabularyRecognitionResult(
      accepted: accepted ?? this.accepted,
      abstained: abstained ?? this.abstained,
      isNonFoodRejected: isNonFoodRejected ?? this.isNonFoodRejected,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      topCandidates: topCandidates ?? this.topCandidates,
      modelId: modelId ?? this.modelId,
      topSimilarity: topSimilarity ?? this.topSimilarity,
      negativeSimilarity: negativeSimilarity ?? this.negativeSimilarity,
      negativeMargin: negativeMargin ?? this.negativeMargin,
      topNegativePrompt: topNegativePrompt ?? this.topNegativePrompt,
      decisionReason: decisionReason ?? this.decisionReason,
      modelLoadMs: modelLoadMs ?? this.modelLoadMs,
      preprocessMs: preprocessMs ?? this.preprocessMs,
      encoderMs: encoderMs ?? this.encoderMs,
      retrievalMs: retrievalMs ?? this.retrievalMs,
      totalMs: totalMs ?? this.totalMs,
      sessionReused: sessionReused ?? this.sessionReused,
      errorReason: errorReason ?? this.errorReason,
    );
  }
}
