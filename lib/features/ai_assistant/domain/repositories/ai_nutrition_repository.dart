import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../entities/chat_message.dart';

import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../grocery/domain/entities/grocery_item_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';

abstract class IAiNutritionRepository {
  Future<ChatMessage> askAssistant({
    required String prompt,
    required List<NutritionRecordEntity> todayRecords,
    required List<NutritionRecordEntity> historyRecords,
    required NutritionGoalsEntity? goals,
    List<ChatMessage> history = const [],
    HealthRecordEntity? todayHealth,
    List<HealthRecordEntity> historyHealth = const [],
    UserProfileEntity? profile,
    List<WeightRecordEntity> weightHistory = const [],
    MealPlanEntity? mealPlan,
    DailyRoutineEntity? dailyRoutine,
    List<GroceryItemEntity> groceryItems = const [],
    List<PantryItemEntity> pantryItems = const [],
  });
}
