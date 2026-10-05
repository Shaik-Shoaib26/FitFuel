/// Domain Failure Classes for Presentation Layer Error Handling
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server processing error occurred. Please try again.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network connection failed. Please check your internet connection.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage cache error occurred.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed. Please sign in again.']);
}

class AIScanFailure extends Failure {
  const AIScanFailure([super.message = 'Unable to recognize food item. Please try again or search manually.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Camera or storage permission denied.']);
}

class ModelUnavailableFailure extends Failure {
  const ModelUnavailableFailure([
    super.message = 'The AI vision model is temporarily unavailable. Please try again later.',
  ]);
}

class FailureMapper {
  static String map(dynamic error, {bool isOffline = false, bool hasData = false}) {
    if (isOffline) {
      return 'No internet connection. Reconnect and try again.';
    }

    if (error is Failure) {
      if (error is ServerFailure) {
        return "FitFuel couldn't connect right now. Please try again.";
      }
      if (error is AuthFailure) {
        return 'Please sign in again.';
      }
      return error.message;
    }

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('model') || errStr.contains('modelunavailable')) {
      return 'The AI vision model is temporarily unavailable. Please try again later.';
    }
    if (errStr.contains('offline') || errStr.contains('network') || errStr.contains('socket') || errStr.contains('unavailable')) {
      return 'No internet connection. Reconnect and try again.';
    }

    return "FitFuel couldn't connect right now. Please try again.";
  }
}
