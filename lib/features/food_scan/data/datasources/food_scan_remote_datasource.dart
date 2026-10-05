import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';

class RawDetectedFood {
  final String name;
  final double estimatedGrams;
  final String unit;
  final double confidence;
  final String? visualNotes;
  final EstimatedNutrition? estimatedNutrition;

  const RawDetectedFood({
    required this.name,
    required this.estimatedGrams,
    this.unit = 'g',
    required this.confidence,
    this.visualNotes,
    this.estimatedNutrition,
  });

  factory RawDetectedFood.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString().trim() ?? '';
    if (rawName.isEmpty) {
      throw const FormatException('Detected food item missing name');
    }

    // Portion parsing with sanity bounds
    double grams = 100.0;
    if (json['estimated_grams'] != null) {
      final parsed = double.tryParse(json['estimated_grams'].toString());
      if (parsed != null && parsed > 0 && parsed.isFinite) {
        // Sanity clamp between 5g and 2000g per individual component
        grams = parsed.clamp(5.0, 2000.0);
      }
    }

    double conf = 0.80;
    if (json['confidence'] != null) {
      final parsedConf = double.tryParse(json['confidence'].toString());
      if (parsedConf != null && parsedConf.isFinite) {
        conf = parsedConf.clamp(0.0, 1.0);
      }
    }

    final unit = json['estimated_unit']?.toString() ?? 'g';
    final notes = json['visual_notes']?.toString();

    EstimatedNutrition? nutrition;
    if (json['estimated_nutrition'] is Map) {
      nutrition = EstimatedNutrition.fromJson(json['estimated_nutrition']);
    }

    return RawDetectedFood(
      name: rawName,
      estimatedGrams: grams,
      unit: unit,
      confidence: conf,
      visualNotes: notes,
      estimatedNutrition: nutrition,
    );
  }
}

abstract class IFoodScanRemoteDataSource {
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
  });

  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  });
}

class FoodScanRemoteDataSource implements IFoodScanRemoteDataSource {
  final Dio _dio;
  final String _apiKey;
  final Duration Function(int retryIndex, int? retryAfterSeconds)? _delayProvider;

  /// Global delay provider hook, particularly useful for accelerated test runs.
  static Duration Function(int retryIndex, int? retryAfterSeconds)? defaultDelayProvider;

  FoodScanRemoteDataSource({
    Dio? dio,
    required String apiKey,
    Duration Function(int retryIndex, int? retryAfterSeconds)? delayProvider,
  })  : _dio = dio ?? Dio(),
        _apiKey = apiKey,
        _delayProvider = delayProvider;

  static const String _visionPrompt = '''
You are an expert culinary vision analyst for the FitFuel nutrition app.
Analyze the provided image and identify all distinct food items present.

Strict guidelines:
1. Identify only visible foods, drinks, or ingredients. Do not invent items.
2. Estimate the portion size (in grams or standard metric units) conservatively.
3. Provide a confidence score between 0.0 and 1.0 for each recognized item.
4. For every recognized food item, provide an estimated nutrition breakdown for that estimated portion:
   - calories (kcal)
   - protein_g (grams of protein)
   - carbs_g (grams of carbohydrates)
   - fat_g (grams of total fat)
   Ensure all four macro fields are estimated realistic numbers. If a nutrient is truly absent (e.g. zero fat in an apple or sugar), use 0.0.
5. If image contains no food, return an empty "foods" array: {"foods": []}.
6. Respond ONLY with a valid JSON object matching this schema:

{
  "foods": [
    {
      "name": "Food Name (e.g. Basmati Rice, Grilled Chicken Breast, Vegetable Curry)",
      "estimated_grams": 180,
      "estimated_unit": "g",
      "confidence": 0.92,
      "visual_notes": "optional brief description of preparation or sauce",
      "estimated_nutrition": {
        "calories": 210,
        "protein_g": 6.5,
        "carbs_g": 24.0,
        "fat_g": 10.2
      }
    }
  ]
}
''';

  static String _buildRepairPrompt(String foodName, double estimatedGrams) {
    return '''
For the already identified food '$foodName', estimated portion ${estimatedGrams.toStringAsFixed(0)} g, provide a conservative estimated nutrition object containing ALL of:
calories
protein_g
carbs_g
fat_g

Return JSON only.
This is an estimate.
Schema:
{
  "calories": 210,
  "protein_g": 6.5,
  "carbs_g": 24.0,
  "fat_g": 10.2
}
''';
  }

  Duration _computeBackoff(int attempt, int? retryAfterSeconds) {
    final dp = _delayProvider;
    if (dp != null) {
      return dp(attempt, retryAfterSeconds);
    }
    final ddp = defaultDelayProvider;
    if (ddp != null) {
      return ddp(attempt, retryAfterSeconds);
    }
    if (retryAfterSeconds != null && retryAfterSeconds > 0) {
      // Respect Retry-After header bounded to 5s
      return Duration(seconds: retryAfterSeconds.clamp(1, 5));
    }
    // Exponential backoff: ~1s, ~2s, ~4s + random jitter up to 250ms
    final baseMs = 1000 * (1 << (attempt - 1));
    final jitterMs = Random().nextInt(250);
    return Duration(milliseconds: (baseMs + jitterMs).clamp(500, 5000));
  }

  bool _isDailyQuotaExceeded(DioException e) {
    final data = e.response?.data;
    if (data == null) return false;
    final text = data.toString().toLowerCase();
    return text.contains('daily') ||
        text.contains('per day') ||
        text.contains('daily_quota') ||
        text.contains('daily quota') ||
        text.contains('quota exceeded') ||
        text.contains('quota_exceeded') ||
        (text.contains('resource_exhausted') && text.contains('quota') && text.contains('day'));
  }

  int? _parseRetryAfter(DioException e) {
    final rawHeader = e.response?.headers.value('retry-after') ??
        e.response?.headers.value('Retry-After');
    if (rawHeader == null) return null;
    return int.tryParse(rawHeader.trim());
  }

  @override
  Future<List<RawDetectedFood>> analyzeMealImage(
    Uint8List imageBytes, {
    String? preferredModel,
  }) async {
    if (imageBytes.isEmpty) {
      throw ServerException(message: 'Image data is empty');
    }

    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY') {
      if (kDebugMode) {
        debugPrint('[FoodScan] HTTP status code: 401, Gemini error category: unauthorized');
      }
      throw FoodScanException(
        type: FoodScanFailureType.unauthorized,
        message: FoodScanErrorCopy.authMessage,
        statusCode: 401,
      );
    }

    final primaryModel = preferredModel ?? GeminiConfig.primaryModel;

    try {
      return await _executeMultimodalRequest(imageBytes, primaryModel);
    } catch (e) {
      // Check if fallback model should be attempted after transient retry exhaustion
      final fallbackModel = GeminiConfig.fallbackModel;
      final isTransient = e is FoodScanException &&
          (e.type == FoodScanFailureType.serviceUnavailable ||
              e.type == FoodScanFailureType.timeout);

      if (isTransient && fallbackModel.isNotEmpty && fallbackModel != primaryModel) {
        if (kDebugMode) {
          debugPrint('[FoodScan] fallback model started');
        }
        try {
          final result = await _executeMultimodalRequest(imageBytes, fallbackModel, maxRetries: 0);
          if (kDebugMode) {
            debugPrint('[FoodScan] fallback succeeded');
          }
          return result;
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('[FoodScan] fallback error: $fallbackError');
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<List<RawDetectedFood>> _executeMultimodalRequest(
    Uint8List imageBytes,
    String model, {
    int maxRetries = 3,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

    final base64Image = base64Encode(imageBytes);

    final requestPayload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'text': _visionPrompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      }
    };

    int attempt = 0;
    while (true) {
      attempt++;
      if (kDebugMode) {
        debugPrint('[FoodScan] request started');
      }

      try {
        final response = await _dio.post(
          url,
          data: requestPayload,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            sendTimeout: GeminiConfig.timeout,
            receiveTimeout: GeminiConfig.timeout,
          ),
        );

        final statusCode = response.statusCode;

        if (statusCode == 200) {
          final data = response.data as Map?;
          if (data == null) {
            return [];
          }

          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            return [];
          }

          final firstCandidate = candidates.first as Map?;
          final content = firstCandidate?['content'] as Map?;
          final parts = content?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            return [];
          }

          final text = parts.first['text'] as String?;
          if (text == null || text.trim().isEmpty) {
            return [];
          }

          return parseVisionResponse(text);
        } else {
          throw FoodScanException(
            type: FoodScanFailureType.invalidResponse,
            message: FoodScanErrorCopy.unknownMessage,
            statusCode: statusCode,
          );
        }
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final retryAfterSeconds = _parseRetryAfter(e);
        if (retryAfterSeconds != null && kDebugMode) {
          debugPrint('[FoodScan] Retry-After detected');
        }

        // 1. Non-retryable HTTP failures
        if (statusCode == 404) {
          throw const ModelUnavailableException(
            message: FoodScanErrorCopy.modelUnavailableMessage,
            statusCode: 404,
          );
        }
        if (statusCode == 401) {
          throw FoodScanException(
            type: FoodScanFailureType.unauthorized,
            message: 'AI service authorization failed. Please check configuration.',
            statusCode: 401,
          );
        }
        if (statusCode == 403) {
          throw FoodScanException(
            type: FoodScanFailureType.forbidden,
            message: 'AI service authorization failed. Please check configuration.',
            statusCode: 403,
          );
        }
        if (statusCode == 400) {
          throw FoodScanException(
            type: FoodScanFailureType.invalidRequest,
            message: 'Failed to analyze food image: invalid request or response.',
            statusCode: 400,
          );
        }

        // 2. HTTP 429 Rate Limit vs Daily Quota
        if (statusCode == 429) {
          if (kDebugMode) {
            debugPrint('[FoodScan] HTTP 429 rateLimit');
          }
          if (_isDailyQuotaExceeded(e)) {
            // Daily quota exceeded: Non-retryable
            throw FoodScanException(
              type: FoodScanFailureType.dailyQuotaReached,
              message: FoodScanErrorCopy.dailyQuotaMessage,
              statusCode: 429,
            );
          }

          // Short-term rate limit: Retry if attempts remaining
          if (attempt <= maxRetries) {
            if (kDebugMode) {
              debugPrint('[FoodScan] retry $attempt/$maxRetries');
            }
            final delay = _computeBackoff(attempt, retryAfterSeconds);
            await Future.delayed(delay);
            continue;
          }

          throw FoodScanException(
            type: FoodScanFailureType.rateLimited,
            message: 'AI service rate limit reached. Please wait a moment and try again.',
            statusCode: 429,
            retryAfterSeconds: retryAfterSeconds,
          );
        }

        // 3. Transient Server Failures (500, 502, 503)
        if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
          if (kDebugMode) {
            debugPrint('[FoodScan] HTTP 503 serviceUnavailable');
          }
          if (attempt <= maxRetries) {
            if (kDebugMode) {
              debugPrint('[FoodScan] retry $attempt/$maxRetries');
            }
            final delay = _computeBackoff(attempt, retryAfterSeconds);
            await Future.delayed(delay);
            continue;
          }

          throw FoodScanException(
            type: FoodScanFailureType.serviceUnavailable,
            message: FoodScanErrorCopy.serviceUnavailableMessage,
            statusCode: statusCode,
          );
        }

        // 4. Timeouts (408, 504, Dio timeout)
        if (statusCode == 408 ||
            statusCode == 504 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          if (attempt <= maxRetries) {
            if (kDebugMode) {
              debugPrint('[FoodScan] retry $attempt/$maxRetries');
            }
            final delay = _computeBackoff(attempt, retryAfterSeconds);
            await Future.delayed(delay);
            continue;
          }

          throw FoodScanException(
            type: FoodScanFailureType.timeout,
            message: 'AI vision service timed out. Please try again.',
            statusCode: statusCode,
          );
        }

        // 5. Connection Error / Network Unavailable
        if (e.type == DioExceptionType.connectionError) {
          throw NetworkException(
            message: 'No internet connection. Food scanning requires an internet connection.',
          );
        }

        // Fallback catch-all for other status codes
        throw FoodScanException(
          type: FoodScanFailureType.unknownServiceFailure,
          message: 'Failed to analyze food image: ${e.message ?? 'Unknown server error'}',
          statusCode: statusCode,
        );
      } catch (e) {
        if (e is FoodScanException ||
            e is ModelUnavailableException ||
            e is NetworkException ||
            e is ServerException ||
            e is FormatException) {
          rethrow;
        }
        throw FoodScanException(
          type: FoodScanFailureType.unknownServiceFailure,
          message: 'Unexpected error analyzing food image: $e',
        );
      }
    }
  }

  @override
  Future<EstimatedNutrition?> repairNutrition({
    required String foodName,
    required double estimatedGrams,
    String? preferredModel,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY') {
      return null;
    }

    final model = preferredModel ?? GeminiConfig.primaryModel;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

    final prompt = _buildRepairPrompt(foodName, estimatedGrams);
    final requestPayload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      }
    };

    try {
      if (kDebugMode) {
        debugPrint('[FoodScan] nutrition repair started');
      }

      final response = await _dio.post(
        url,
        data: requestPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map?;
        if (data == null) return null;

        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) return null;

        final firstCandidate = candidates.first as Map?;
        final content = firstCandidate?['content'] as Map?;
        final parts = content?['parts'] as List?;
        if (parts == null || parts.isEmpty) return null;

        final text = parts.first['text'] as String?;
        if (text == null || text.trim().isEmpty) return null;

        var clean = text.trim();
        if (clean.startsWith('```json')) clean = clean.substring(7);
        if (clean.startsWith('```')) clean = clean.substring(3);
        if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
        clean = clean.trim();

        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final nutrition = EstimatedNutrition.fromJson(decoded);
          if (nutrition != null) {
            if (kDebugMode) {
              debugPrint('[FoodScan] nutrition repair succeeded');
            }
            return nutrition;
          }
        }
      }
      return null;
    } catch (e) {
      // Controlled repair failure; never throw, protecting the scan flow
      return null;
    }
  }

  /// Parses and validates the structured JSON string returned by Gemini Vision.
  static List<RawDetectedFood> parseVisionResponse(String jsonText) {
    try {
      // Clean possible markdown fences ```json ... ```
      var clean = jsonText.trim();
      if (clean.startsWith('```json')) {
        clean = clean.substring(7);
      } else if (clean.startsWith('```')) {
        clean = clean.substring(3);
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3);
      }
      clean = clean.trim();

      final decoded = jsonDecode(clean);
      if (decoded is! Map) {
        return [];
      }

      final foodsList = decoded['foods'];
      if (foodsList is! List) {
        return [];
      }

      final List<RawDetectedFood> result = [];
      for (final item in foodsList) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(RawDetectedFood.fromJson(item));
          } catch (err) {
            debugPrint('[FoodScan] Skipping invalid item in AI response: $err');
          }
        } else if (item is Map) {
          try {
            result.add(RawDetectedFood.fromJson(Map<String, dynamic>.from(item)));
          } catch (err) {
            debugPrint('[FoodScan] Skipping invalid item in AI response: $err');
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('[FoodScan] JSON parse error on response: $e');
      throw const FormatException('Invalid or malformed AI vision response format');
    }
  }
}
