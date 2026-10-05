import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/ai_nutrition_service.dart';

import 'package:flutter/foundation.dart';

class GeminiConfig {
  static const String defaultModelName = 'gemini-3.8-flash';
  static const String defaultFallbackModelName = 'gemini-3.5-flash';

  /// Primary Gemini multimodal model for Food Scan and AI nutrition.
  static String get primaryModel => modelName;

  /// Fallback Gemini multimodal model used when primary encounters service issues.
  static String get fallbackModel => fallbackModelName;

  static String get modelName {
    try {
      if (dotenv.isInitialized) {
        final override = dotenv.env['GEMINI_MODEL']?.trim();
        if (override != null && override.isNotEmpty) {
          return override;
        }
      }
    } catch (_) {}
    return defaultModelName;
  }

  static String get fallbackModelName {
    try {
      if (dotenv.isInitialized) {
        final override = dotenv.env['GEMINI_FALLBACK_MODEL']?.trim();
        if (override != null && override.isNotEmpty) {
          return override;
        }
      }
    } catch (_) {}
    return defaultFallbackModelName;
  }

  static const Duration timeout = Duration(seconds: 20);
}

class AiNutritionRemoteDatasource implements AiNutritionService {
  final Dio _dio;
  final String _apiKey;

  AiNutritionRemoteDatasource({
    Dio? dio,
    required String apiKey,
  })  : _dio = dio ?? Dio(),
        _apiKey = apiKey;

  void _log(String message) {
    // Secure development logging: ensure no sensitive keys are ever logged
    final cleanMsg = message.replaceAll(_apiKey, '***');
    debugPrint('[AI] $cleanMsg');
  }

  @override
  Future<ChatMessage> generateResponse({
    required String userPrompt,
    required String systemContext,
    List<ChatMessage> history = const [],
  }) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/${GeminiConfig.modelName}:generateContent?key=$_apiKey';

    _log('Gemini request started');

    final List<Map<String, dynamic>> contents = [];

    // Map history to Gemini content turns
    for (final msg in history) {
      contents.add({
        'role': msg.sender == MessageSender.user ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ]
      });
    }

    // Add current user prompt and system context
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text': '''
$systemContext
'''
        }
      ]
    });

    final requestPayload = {
      'contents': contents,
    };

    Future<Response> executeRequest() {
      return _dio.post(
        url,
        data: requestPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: GeminiConfig.timeout,
          receiveTimeout: GeminiConfig.timeout,
        ),
      );
    }

    Response response;
    try {
      response = await executeRequest();
    } on DioException catch (e) {
      if (_isTransient(e)) {
        _log('Transient error encountered: ${e.type}. Retrying request once.');
        try {
          response = await executeRequest();
        } on DioException catch (retryErr) {
          _handleDioException(retryErr);
          rethrow;
        }
      } else {
        _handleDioException(e);
        rethrow;
      }
    }

    _log('Gemini response received');

    if (response.statusCode == 200) {
      final data = response.data as Map?;
      if (data == null) {
        throw Exception('invalidResponse');
      }

      // Check prompt safety block
      final promptFeedback = data['promptFeedback'] as Map?;
      if (promptFeedback != null && promptFeedback['blockReason'] != null) {
        _log('Prompt blocked by safety filters');
        return ChatMessage(
          text: "I can't help with that request, but I can provide general nutrition and wellness guidance.",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
          providerUsed: 'Gemini',
        );
      }

      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('emptyCandidate');
      }

      final candidate = candidates[0] as Map;

      // Check candidate safety block
      final finishReason = candidate['finishReason'] as String?;
      if (finishReason == 'SAFETY') {
        _log('Response candidate blocked by safety filters');
        return ChatMessage(
          text: "I can't help with that request, but I can provide general nutrition and wellness guidance.",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
          providerUsed: 'Gemini',
        );
      }

      final content = candidate['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        String text = parts[0]['text'] as String? ?? '';
        if (text.isEmpty) {
          throw Exception('emptyCandidate');
        }

        // Parse suggestion food from response if present
        final List<NutritionRecordEntity> suggestedFoods = [];
        final regex = RegExp(r'\[SUGGESTION:\s*([^,]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\]');
        final match = regex.firstMatch(text);

        if (match != null) {
          final foodName = match.group(1)?.trim() ?? '';
          final cals = double.tryParse(match.group(2) ?? '') ?? 0.0;
          final pro = double.tryParse(match.group(3) ?? '') ?? 0.0;
          final carbs = double.tryParse(match.group(4) ?? '') ?? 0.0;
          final fats = double.tryParse(match.group(5) ?? '') ?? 0.0;

          // Clean text by stripping out the raw bracket suggestion tag
          text = text.replaceAll(match.group(0)!, '').trim();

          if (foodName.isNotEmpty) {
            suggestedFoods.add(
              NutritionRecordEntity(
                id: '',
                foodName: foodName,
                mealType: 'Snack', // Default meal type fallback
                calories: cals,
                protein: pro,
                carbohydrates: carbs,
                fats: fats,
                sugar: 0.0,
                servingSize: 100.0,
                consumedAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }

        return ChatMessage(
          text: text,
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
          suggestedFoods: suggestedFoods.isNotEmpty ? suggestedFoods : null,
          providerUsed: 'Gemini',
        );
      }
    }

    throw Exception('invalidResponse');
  }

  bool _isTransient(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.response != null) {
      final status = e.response!.statusCode;
      if (status != null && status >= 500 && status < 600) {
        return true;
      }
    }
    return false;
  }

  void _handleDioException(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode;
      _log('DioException response status: $status');
      if (status == 401 || status == 403) {
        throw Exception('unauthorized');
      } else if (status == 429) {
        throw Exception('rateLimited');
      } else if (status != null && status >= 500) {
        throw Exception('serverError');
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      _log('Using fallback: timeout');
      throw Exception('timeout');
    }
    _log('Using fallback: networkUnavailable');
    throw Exception('networkUnavailable');
  }
}
