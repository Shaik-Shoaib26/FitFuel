import 'dart:typed_data';
import 'open_vocabulary_image_encoder_interface.dart';

/// Web/stub implementation of [IOpenVocabularyImageEncoder].
/// Ensures `flutter build web --no-pub` compiles without native FFI dependencies.
class TfliteOpenVocabularyImageEncoder implements IOpenVocabularyImageEncoder {
  final String modelAssetPath;
  @override
  final String modelName;
  @override
  final int embeddingDimension;

  TfliteOpenVocabularyImageEncoder({
    this.modelAssetPath =
        'assets/ml/fitfuel_openvocab_mnv3_384_float16.tflite',
    this.modelName = 'fitfuel_openvocab_mnv3_minilm_384',
    this.embeddingDimension = 384,
  });

  @override
  String get runtimeName => 'Web Stub (Native LiteRT Unavailable)';

  @override
  bool get isInitialized => false;

  @override
  double get coldLoadTimeMs => 0.0;

  @override
  Future<OpenVocabularyEncodedImage> encodeImage(Uint8List imageBytes) async {
    return OpenVocabularyEncodedImage.unavailable(
      modelName: modelName,
      runtimeName: runtimeName,
      reason: 'Native LiteRT / TFLite open-vocabulary encoder is Android/Desktop only.',
    );
  }

  @override
  void dispose() {}
}
