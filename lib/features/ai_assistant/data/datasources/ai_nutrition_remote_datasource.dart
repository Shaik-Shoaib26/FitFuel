import 'package:dio/dio.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/ai_nutrition_service.dart';

class AiNutritionRemoteDatasource implements AiNutritionService {
  final Dio _dio;
  final String _apiKey;

  AiNutritionRemoteDatasource({
    Dio? dio,
    required String apiKey,
  })  : _dio = dio ?? Dio(),
        _apiKey = apiKey;

  @override
  Future<ChatMessage> generateResponse({
    required String userPrompt,
    required String systemContext,
    List<ChatMessage> history = const [],
  }) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$_apiKey';



    // 1. Build excluded-foods list based on full multi-turn chat history
    final Set<String> excludedFoods = {};
    final triggers = ['no', 'avoid', 'cannot eat', 'don\'t want', 'rather than', 'exclude', 'without', 'cannot prefer'];
    final foodsList = ['chicken', 'eggs', 'yogurt', 'dal', 'paneer', 'oats', 'banana', 'rice', 'milk', 'vegetables'];

    void checkExclusions(String text) {
      final tLower = text.toLowerCase();
      for (final trigger in triggers) {
        if (tLower.contains(trigger)) {
          for (final food in foodsList) {
            if (tLower.contains(food)) {
              excludedFoods.add(food);
            }
          }
        }
      }
    }

    for (final msg in history) {
      if (msg.sender == MessageSender.user) {
        checkExclusions(msg.text);
      }
    }
    checkExclusions(userPrompt);

    // 2. Track previously recommended foods
    final Set<String> previouslyRecommended = {};
    for (final msg in history) {
      if (msg.sender == MessageSender.ai) {
        if (msg.suggestedFoods != null) {
          for (final f in msg.suggestedFoods!) {
            previouslyRecommended.add(f.foodName.toLowerCase());
          }
        }
        for (final food in foodsList) {
          if (msg.text.toLowerCase().contains(food)) {
            previouslyRecommended.add(food);
          }
        }
      }
    }

    final String exclusionInstruction = excludedFoods.isNotEmpty
        ? 'CRITICAL: Do NOT recommend or mention any of the following excluded foods: ${excludedFoods.join(', ')}.'
        : '';

    final String recommendationInstruction = previouslyRecommended.isNotEmpty
        ? 'CRITICAL: Try to suggest a DIFFERENT food item than the ones already suggested in history: ${previouslyRecommended.join(', ')}.'
        : '';

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

    // Add current turn with the guidelines, context, exclusions, and recommendations instructions
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text': '''
SYSTEM INSTRUCTION:
You are FitFuel AI, a helpful nutrition and wellness assistant.
Answering Safety Guidelines:
1. Avoid medical diagnoses or claiming to treat/cure diseases.
2. Avoid extreme dieting, fasts, or dangerous calorie restriction.
3. State clearly when nutrition figures are approximate.
4. Encourage consulting certified dietitians or professionals for medical/dietary conditions.
5. Keep your responses practical, clear, and concise.
6. If the user asks about water, hydration, exercise, habits, or wellness score, discuss these health metrics specifically, and do NOT append any [SUGGESTION: ...] tag or recommend any food unless the user explicitly requests food recommendations in their prompt.
7. Answer the user's specific question using the supplied FitFuel health data. Do not answer a different question. Do not repeat a generic summary when the user asks for a specific metric.

$exclusionInstruction
$recommendationInstruction

USER QUESTION:
$userPrompt

USER HEALTH CONTEXT:
$systemContext
'''
        }
      ]
    });

    try {
      final response = await _dio.post(
        url,
        data: {
          'contents': contents,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            String text = parts[0]['text'] as String? ?? 'No response generated.';

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
            );
          }
        }
      }
      throw DioException(
        requestOptions: RequestOptions(path: url),
        message: 'Invalid Gemini API response status: ${response.statusCode}',
      );
    } on DioException catch (e) {
      throw Exception('API connection error: ${e.message ?? 'Unknown connection issue.'}');
    } catch (e) {
      throw Exception('Error parsing AI assistant response: $e');
    }
  }
}
