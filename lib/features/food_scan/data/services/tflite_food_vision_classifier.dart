// Conditional export routing TfliteFoodVisionClassifier between mobile (dart:io)
// and web/stub environments where native FFI is unsupported.
export 'tflite_food_vision_classifier_stub.dart'
    if (dart.library.io) 'tflite_food_vision_classifier_mobile.dart';
