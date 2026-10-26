/// Denotes the recognition pathway used to identify the scanned meal.
enum FoodScanRecognitionSource {
  /// Confidently identified via on-device TFLite/LiteRT vision model (0 cloud requests).
  localModel,

  /// User confirmed a candidate from on-device Top-K local suggestions (0 cloud requests).
  localSuggestionConfirmed,

  /// Phase 35.11B.1: Single primary result from Tier-2 on-device open-vocabulary local recognition (0 cloud requests).
  openVocabularyPrimary,

  /// Phase 35.11B: Unconfirmed primary suggestion from Tier-2 on-device open-vocabulary local recognition (0 cloud requests).
  openVocabularyPrimarySuggested,

  /// User confirmed a candidate from Tier-2 on-device open-vocabulary local suggestions (0 cloud requests).
  openVocabularyConfirmed,

  /// Identified via Gemini multimodal cloud analysis (optional fallback pathway).
  gemini,

  /// User identified or selected the food manually (0 cloud requests).
  manual;

  /// Phase 35.10.3 canonical aliases:
  static const FoodScanRecognitionSource onDeviceAuto =
      FoodScanRecognitionSource.localModel;
  static const FoodScanRecognitionSource manualConfirmed =
      FoodScanRecognitionSource.manual;
  static const FoodScanRecognitionSource cloudGemini =
      FoodScanRecognitionSource.gemini;

  /// True when the food item was explicitly confirmed or selected by the user.
  bool get isUserConfirmed =>
      this == FoodScanRecognitionSource.localSuggestionConfirmed ||
      this == FoodScanRecognitionSource.openVocabularyConfirmed ||
      this == FoodScanRecognitionSource.manual;

  /// User-facing source badge label for the scan result screen.
  String get sourceBadgeLabel {
    switch (this) {
      case FoodScanRecognitionSource.localModel:
        return 'Recognized on your device';
      case FoodScanRecognitionSource.openVocabularyPrimary:
      case FoodScanRecognitionSource.openVocabularyPrimarySuggested:
        return 'Found on your device';
      case FoodScanRecognitionSource.localSuggestionConfirmed:
      case FoodScanRecognitionSource.openVocabularyConfirmed:
      case FoodScanRecognitionSource.manual:
        return 'Confirmed by you';
      case FoodScanRecognitionSource.gemini:
        return 'Identified with AI';
    }
  }

  /// Optional secondary source detail subtitle for local open-vocabulary results.
  String? get secondarySourceDetail {
    switch (this) {
      case FoodScanRecognitionSource.openVocabularyConfirmed:
        return 'Found on your device';
      case FoodScanRecognitionSource.openVocabularyPrimary:
      case FoodScanRecognitionSource.openVocabularyPrimarySuggested:
      case FoodScanRecognitionSource.localModel:
      case FoodScanRecognitionSource.localSuggestionConfirmed:
      case FoodScanRecognitionSource.manual:
      case FoodScanRecognitionSource.gemini:
        return null;
    }
  }

  /// Canonical telemetry route label for debug and diagnostics.
  String get debugRouteLabel {
    switch (this) {
      case FoodScanRecognitionSource.localModel:
        return 'auto_local';
      case FoodScanRecognitionSource.localSuggestionConfirmed:
        return 'local_suggestion';
      case FoodScanRecognitionSource.openVocabularyPrimary:
        return 'tier2_single_result';
      case FoodScanRecognitionSource.openVocabularyPrimarySuggested:
        return 'tier2_open_vocab_primary_suggested';
      case FoodScanRecognitionSource.openVocabularyConfirmed:
        return 'tier2_open_vocab_confirmed';
      case FoodScanRecognitionSource.manual:
        return 'manual';
      case FoodScanRecognitionSource.gemini:
        return 'gemini';
    }
  }
}
