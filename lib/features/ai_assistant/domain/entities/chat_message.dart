import '../../../nutrition/domain/entities/nutrition_record_entity.dart';

enum MessageSender { user, ai }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<NutritionRecordEntity>? suggestedFoods;
  final String? providerUsed;

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.suggestedFoods,
    this.providerUsed,
  });
}
