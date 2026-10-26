import 'dart:typed_data';

/// Output of encoding a raw image into a normalized open-vocabulary embedding vector.
class OpenVocabularyEncodedImage {
  final List<double> embedding;
  final double imageDecodeMs;
  final double preprocessMs;
  final double inferenceMs;
  final double coldLoadMs;
  final bool wasColdStart;
  final String modelName;
  final String runtimeName;
  final bool isSuccess;
  final String? errorReason;

  const OpenVocabularyEncodedImage({
    required this.embedding,
    this.imageDecodeMs = 0.0,
    this.preprocessMs = 0.0,
    this.inferenceMs = 0.0,
    this.coldLoadMs = 0.0,
    this.wasColdStart = false,
    required this.modelName,
    required this.runtimeName,
    this.isSuccess = true,
    this.errorReason,
  });

  factory OpenVocabularyEncodedImage.unavailable({
    required String modelName,
    required String runtimeName,
    required String reason,
  }) {
    return OpenVocabularyEncodedImage(
      embedding: const [],
      modelName: modelName,
      runtimeName: runtimeName,
      isSuccess: false,
      errorReason: reason,
    );
  }
}

/// Abstract interface for an on-device open-vocabulary image encoder.
abstract class IOpenVocabularyImageEncoder {
  String get modelName;
  String get runtimeName;
  int get embeddingDimension;
  bool get isInitialized;
  double get coldLoadTimeMs;

  /// Encodes [imageBytes] into an L2-normalized embedding vector locally (0 cloud calls).
  Future<OpenVocabularyEncodedImage> encodeImage(Uint8List imageBytes);

  void dispose();
}
