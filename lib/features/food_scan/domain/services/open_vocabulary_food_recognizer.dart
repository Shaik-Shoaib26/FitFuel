import 'dart:typed_data';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_recognition_result.dart';
import 'package:fitfuel/features/food_scan/domain/services/global_food_vocabulary_service.dart';

/// Contract for the Tier-2 on-device open-vocabulary image-text food recognizer
/// (`SigLIP-B/16 INT8`).
abstract class OpenVocabularyFoodRecognizer {
  /// Lazily initializes the ONNX Runtime session and loads FP16 text indices.
  /// Safe to call multiple times; reuses an active warm session if already loaded.
  Future<void> initialize();

  /// Runs image-text open-vocabulary food recognition and safety gating on [imageBytes].
  /// Never throws fatal exceptions; returns [OpenVocabularyRecognitionResult.unavailable]
  /// if the runtime or model assets are unavailable.
  Future<OpenVocabularyRecognitionResult> recognize(Uint8List imageBytes);

  /// Disposes the native ONNX Runtime session and releases memory buffers when
  /// the user exits `FoodScanScreen`.
  Future<void> dispose();

  /// True if the recognizer is supported and model assets are available on this device.
  bool get isAvailable;

  /// True if the native ONNX session is currently loaded and warm in memory.
  bool get isSessionLoaded;

  /// True if invoking [recognize] will require cold-loading the ONNX session.
  bool get requiresColdInit => !isSessionLoaded;
}

/// Capability interface for open-vocabulary recognizers that support runtime synchronization
/// of dynamic vocabulary embedding packs into native retrieval indexes.
abstract class DynamicVocabularySyncCapable {
  /// Registers a validated dynamic vocabulary pack with native retrieval matrix.
  Future<Map<String, dynamic>?> registerDynamicVocabularyPack(
    VocabularyPack pack, {
    bool requireAllVisionEligible = false,
  });

  /// Clears dynamic vocabulary packs from native state and disk cache.
  Future<bool> clearDynamicVocabulary();

  /// Retrieves vocabulary stats from native runtime.
  Future<Map<String, dynamic>?> getRegisteredVocabularyInfo();
}
