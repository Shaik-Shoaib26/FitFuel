import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_model_asset_provider.dart';

/// Platform-channel backed implementation of [OpenVocabularyModelAssetProvider].
///
/// On Android, resolves or extracts the bundled `SigLIP-B/16 INT8` ONNX model,
/// FP16 food text index, FP16 negative text index, and vocabulary metadata in
/// app-private internal storage (`filesDir/openvocab/`).
/// On non-Android platforms (Web, Windows, iOS, macOS, Linux), gracefully returns
/// `null` / `false` without throwing.
class PlatformOpenVocabularyModelAssetProvider
    implements OpenVocabularyModelAssetProvider {
  static const MethodChannel _channel =
      MethodChannel('fitfuel/open_vocab_food_recognizer');

  OpenVocabularyModelAssets? _cachedAssets;

  bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<OpenVocabularyModelAssets?> resolveAssets() async {
    if (!_isSupportedPlatform) {
      return null;
    }
    if (_cachedAssets != null && _cachedAssets!.isValid) {
      return _cachedAssets;
    }

    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'resolveAssets',
      );
      if (map == null || map['available'] != true) {
        return null;
      }
      final assets = OpenVocabularyModelAssets(
        visionModelPath: (map['visionModelPath'] ?? '').toString(),
        textIndexPath: (map['textIndexPath'] ?? '').toString(),
        negIndexPath: (map['negIndexPath'] ?? '').toString(),
        vocabJsonPath: (map['vocabJsonPath'] ?? '').toString(),
      );
      if (assets.isValid) {
        _cachedAssets = assets;
        return assets;
      }
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> areAssetsAvailable() async {
    if (!_isSupportedPlatform) {
      return false;
    }
    if (_cachedAssets != null && _cachedAssets!.isValid) {
      return true;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'isAvailable',
      );
      return result != null && result['available'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
