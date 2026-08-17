import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_nutrition_repository.dart';

import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../grocery/domain/entities/grocery_item_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';

abstract class AiAssistantState {
  final List<ChatMessage> messages;
  const AiAssistantState(this.messages);
}

class AiAssistantInitial extends AiAssistantState {
  const AiAssistantInitial() : super(const []);
}

class AiAssistantLoading extends AiAssistantState {
  const AiAssistantLoading(super.messages);
}

class AiAssistantSuccess extends AiAssistantState {
  const AiAssistantSuccess(super.messages);
}

class AiAssistantError extends AiAssistantState {
  final String message;
  const AiAssistantError(super.messages, this.message);
}

class AiAssistantController extends StateNotifier<AiAssistantState> {
  final IAiNutritionRepository _repository;

  AiAssistantController(this._repository) : super(const AiAssistantInitial());

  Future<void> sendMessage({
    required String prompt,
    required List<NutritionRecordEntity> todayRecords,
    required List<NutritionRecordEntity> historyRecords,
    required NutritionGoalsEntity? goals,
    HealthRecordEntity? todayHealth,
    List<HealthRecordEntity> historyHealth = const [],
    UserProfileEntity? profile,
    List<WeightRecordEntity> weightHistory = const [],
    MealPlanEntity? mealPlan,
    DailyRoutineEntity? dailyRoutine,
    List<GroceryItemEntity> groceryItems = const [],
    List<PantryItemEntity> pantryItems = const [],
  }) async {
    if (prompt.trim().isEmpty) return;

    final history = List<ChatMessage>.from(state.messages);

    final userMessage = ChatMessage(
      text: prompt.trim(),
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final currentMessages = List<ChatMessage>.from(state.messages)..add(userMessage);
    state = AiAssistantLoading(currentMessages);

    try {
      final aiMessage = await _repository.askAssistant(
        prompt: prompt,
        todayRecords: todayRecords,
        historyRecords: historyRecords,
        goals: goals,
        history: history,
        todayHealth: todayHealth,
        historyHealth: historyHealth,
        profile: profile,
        weightHistory: weightHistory,
        mealPlan: mealPlan,
        dailyRoutine: dailyRoutine,
        groceryItems: groceryItems,
        pantryItems: pantryItems,
      );

      final updatedMessages = List<ChatMessage>.from(state.messages)..add(aiMessage);
      state = AiAssistantSuccess(updatedMessages);
    } catch (e) {
      state = AiAssistantError(
        state.messages,
        'Assistant failed to reply: ${e.toString().replaceAll('Exception:', '')}',
      );
    }
  }

  void clearHistory() {
    state = const AiAssistantInitial();
  }
}
