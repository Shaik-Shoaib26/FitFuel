/// Custom Exception Types for Data & Remote Layer
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

class CacheException implements Exception {
  final String message;
  CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException({required this.message});

  @override
  String toString() => 'NetworkException: $message';
}

class AIScanException implements Exception {
  final String message;
  final double? confidenceScore;
  AIScanException({required this.message, this.confidenceScore});

  @override
  String toString() => 'AIScanException: $message (confidence: $confidenceScore)';
}

class ModelUnavailableException implements Exception {
  final String message;
  final int? statusCode;
  const ModelUnavailableException({
    this.message = 'The AI vision model is temporarily unavailable. Please try again later.',
    this.statusCode = 404,
  });

  @override
  String toString() => 'ModelUnavailableException: $message (code: $statusCode)';
}

