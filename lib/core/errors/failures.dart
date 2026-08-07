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
