import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/errors/failures.dart';

/// Explicit failure types for Food Scan domain error classification.
enum FoodScanFailureType {
  offline,
  rateLimited,
  dailyQuotaReached,
  serviceUnavailable,
  timeout,
  modelUnavailable,
  unauthorized,
  forbidden,
  invalidRequest,
  invalidImage,
  noFoodDetected,
  lowConfidence,
  offlineLowConfidence,
  imageQualityPoor,
  incompleteNutrition,
  invalidResponse,
  unknownServiceFailure,
}

/// Standardized user-facing copy for Food Scan.
/// No Food Scan screen or widget will ever show "Something Went Wrong".
class FoodScanErrorCopy {
  static const String offlineTitle = 'AI analysis needs an internet connection.';
  static const String offlineMessage =
      'Choose a match below or search foods manually from the FitFuel catalog.';

  static const String rateLimitedTitle = 'AI analysis is temporarily busy.';
  static const String rateLimitedMessage =
      "We've reached the temporary AI scanning limit. You can choose a match below, search foods manually, or try AI again in a moment.";

  static const String dailyQuotaTitle = "AI analysis isn't available right now.";
  static const String dailyQuotaMessage =
      'AI analysis is unavailable until provider quota resets. You can still use local suggestions or search foods manually.';

  static const String serviceUnavailableTitle = "AI analysis couldn't finish.";
  static const String serviceUnavailableMessage =
      'The AI service is busy right now. Your photo is still here — choose a match below, search foods manually, or retry AI.';

  static const String timeoutTitle = 'AI analysis is taking too long';
  static const String timeoutMessage =
      "We couldn't finish AI analysis for this photo. Choose a match below, search foods manually, or retry AI.";

  static const String noFoodTitle = 'No food detected';
  static const String noFoodMessage =
      'Try another photo with the food clearly visible.';

  static const String lowConfidenceTitle = "We couldn't identify this clearly";
  static const String lowConfidenceMessage =
      'Try a clearer photo or choose the food manually.';

  static const String offlineLowConfidenceTitle = 'Choose the closest match';
  static const String offlineLowConfidenceMessage =
      "Couldn't identify this food confidently offline. Please choose the closest match or search foods manually.";

  static const String imageQualityTitle = 'Image quality may be affecting recognition';
  static const String imageQualityMessage =
      'Try the original image or take a clearer photo.';

  static const String incompleteNutritionTitle = 'Nutrition needs confirmation';
  static const String incompleteNutritionMessage =
      "We identified the food, but couldn't estimate all nutrition values. Choose the correct food from FitFuel to continue.";

  static const String modelUnavailableTitle = 'AI analysis is temporarily unavailable';
  static const String modelUnavailableMessage =
      'The AI model is unavailable right now. You can still choose a match or search foods manually.';

  static const String authTitle = "AI analysis isn't available right now";
  static const String authMessage = 'Please use local suggestions or search foods manually.';

  static const String unknownTitle = "Food Scan couldn't finish";
  static const String unknownMessage =
      'Please try again or choose the food manually.';
}

/// Domain failure for Food Scan operations.
class FoodScanFailure extends Failure {
  final FoodScanFailureType type;
  final String title;
  final int? retryAfterSeconds;
  final int? statusCode;

  const FoodScanFailure({
    required this.type,
    required this.title,
    required String message,
    this.retryAfterSeconds,
    this.statusCode,
  }) : super(message);

  factory FoodScanFailure.fromType(
    FoodScanFailureType type, {
    String? titleOverride,
    String? messageOverride,
    int? retryAfterSeconds,
    int? statusCode,
  }) {
    switch (type) {
      case FoodScanFailureType.offline:
        return FoodScanNetworkFailure(
          titleOverride: titleOverride,
          messageOverride: messageOverride,
        );
      case FoodScanFailureType.rateLimited:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.rateLimitedTitle,
          message: messageOverride ?? FoodScanErrorCopy.rateLimitedMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.dailyQuotaReached:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.dailyQuotaTitle,
          message: messageOverride ?? FoodScanErrorCopy.dailyQuotaMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.serviceUnavailable:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.serviceUnavailableTitle,
          message: messageOverride ?? FoodScanErrorCopy.serviceUnavailableMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.timeout:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.timeoutTitle,
          message: messageOverride ?? FoodScanErrorCopy.timeoutMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.modelUnavailable:
        return FoodScanModelUnavailableFailure(
          titleOverride: titleOverride,
          messageOverride: messageOverride,
          statusCode: statusCode,
        );
      case FoodScanFailureType.unauthorized:
      case FoodScanFailureType.forbidden:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.authTitle,
          message: messageOverride ?? FoodScanErrorCopy.authMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.invalidRequest:
      case FoodScanFailureType.invalidResponse:
      case FoodScanFailureType.unknownServiceFailure:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.unknownTitle,
          message: messageOverride ?? FoodScanErrorCopy.unknownMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.invalidImage:
      case FoodScanFailureType.imageQualityPoor:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.imageQualityTitle,
          message: messageOverride ?? FoodScanErrorCopy.imageQualityMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.noFoodDetected:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.noFoodTitle,
          message: messageOverride ?? FoodScanErrorCopy.noFoodMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.lowConfidence:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.lowConfidenceTitle,
          message: messageOverride ?? FoodScanErrorCopy.lowConfidenceMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.offlineLowConfidence:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.offlineLowConfidenceTitle,
          message: messageOverride ?? FoodScanErrorCopy.offlineLowConfidenceMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
      case FoodScanFailureType.incompleteNutrition:
        return FoodScanFailure(
          type: type,
          title: titleOverride ?? FoodScanErrorCopy.incompleteNutritionTitle,
          message: messageOverride ?? FoodScanErrorCopy.incompleteNutritionMessage,
          retryAfterSeconds: retryAfterSeconds,
          statusCode: statusCode,
        );
    }
  }
}

class FoodScanModelUnavailableFailure extends FoodScanFailure
    implements ModelUnavailableFailure {
  const FoodScanModelUnavailableFailure({
    String? titleOverride,
    String? messageOverride,
    int? statusCode,
  }) : super(
          type: FoodScanFailureType.modelUnavailable,
          title: titleOverride ?? FoodScanErrorCopy.modelUnavailableTitle,
          message: messageOverride ?? FoodScanErrorCopy.modelUnavailableMessage,
          statusCode: statusCode ?? 404,
        );
}

class FoodScanNetworkFailure extends FoodScanFailure implements NetworkFailure {
  const FoodScanNetworkFailure({
    String? titleOverride,
    String? messageOverride,
  }) : super(
          type: FoodScanFailureType.offline,
          title: titleOverride ?? FoodScanErrorCopy.offlineTitle,
          message: messageOverride ?? FoodScanErrorCopy.offlineMessage,
        );
}

/// Custom Exception for data-layer Food Scan errors with typed status.
/// Extends ServerException for backwards compatibility with existing error catching.
class FoodScanException extends ServerException {
  final FoodScanFailureType type;
  final int? retryAfterSeconds;

  FoodScanException({
    required this.type,
    required super.message,
    super.statusCode,
    this.retryAfterSeconds,
  });

  @override
  String toString() => 'FoodScanException($type, statusCode: $statusCode, message: $message)';
}
