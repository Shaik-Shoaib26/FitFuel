import '../entities/chat_message.dart';

abstract class AiNutritionService {
  Future<ChatMessage> generateResponse({
    required String userPrompt,
    required String systemContext,
    List<ChatMessage> history = const [],
  });
}
