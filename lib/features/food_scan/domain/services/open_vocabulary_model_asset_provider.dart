/// Resolved local file system paths for the Tier-2 open-vocabulary food
/// recognition artifacts (`SigLIP-B/16 INT8`).
class OpenVocabularyModelAssets {
  final String visionModelPath;
  final String textIndexPath;
  final String negIndexPath;
  final String vocabJsonPath;

  const OpenVocabularyModelAssets({
    required this.visionModelPath,
    required this.textIndexPath,
    required this.negIndexPath,
    required this.vocabJsonPath,
  });

  bool get isValid =>
      visionModelPath.isNotEmpty &&
      textIndexPath.isNotEmpty &&
      negIndexPath.isNotEmpty &&
      vocabJsonPath.isNotEmpty;

  Map<String, String> toMap() => {
        'visionModelPath': visionModelPath,
        'textIndexPath': textIndexPath,
        'negIndexPath': negIndexPath,
        'vocabJsonPath': vocabJsonPath,
      };
}

/// Abstraction for resolving Tier-2 open-vocabulary model assets across
/// bundled debug/dev builds and future Play Asset Delivery / on-demand model packs.
abstract class OpenVocabularyModelAssetProvider {
  /// Resolves local file paths for the vision ONNX model, FP16 food text index,
  /// FP16 negative text index, and vocabulary JSON metadata.
  /// Returns `null` if assets are missing or unsupported on the current platform.
  Future<OpenVocabularyModelAssets?> resolveAssets();

  /// Returns `true` if all required open-vocabulary model assets are present and readable.
  Future<bool> areAssetsAvailable();
}
