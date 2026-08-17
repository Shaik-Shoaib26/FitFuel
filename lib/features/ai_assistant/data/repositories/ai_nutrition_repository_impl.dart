import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../health/domain/entities/health_record_entity.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_nutrition_repository.dart';
import '../../domain/services/ai_nutrition_service.dart';
import '../../domain/utils/ai_context_generator.dart';
import '../datasources/ai_nutrition_mock_datasource.dart';
import '../datasources/ai_nutrition_remote_datasource.dart';

import '../../../progress/domain/entities/weight_record_entity.dart';
import '../../../food/data/repositories/food_repository_impl.dart';
import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../../../reminders/domain/entities/daily_routine_entity.dart';
import '../../../grocery/domain/entities/grocery_item_entity.dart';
import '../../../grocery/domain/entities/pantry_item_entity.dart';

class AiNutritionRepositoryImpl implements IAiNutritionRepository {
  final AiNutritionService _remoteDatasource;
  final AiNutritionService _mockDatasource;

  AiNutritionRepositoryImpl({
    AiNutritionService? remoteDatasource,
    AiNutritionService? mockDatasource,
  })  : _remoteDatasource = remoteDatasource ??
            AiNutritionRemoteDatasource(
              apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
            ),
        _mockDatasource = mockDatasource ?? AiNutritionMockDatasource();

  @override
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
  }) async {
    final List<FoodEntity> foods = [];
    try {
      final foodRepo = FoodRepositoryImpl(FoodRemoteDataSourceImpl());
      final results = await foodRepo.searchFoods('');
      
      // Local heuristic filtering for AI prompt to fit context window
      final pLower = prompt.toLowerCase();
      final isVeg = pLower.contains('vegetarian') || (pLower.contains('veg') && !pLower.contains('vegan'));
      final isVegn = pLower.contains('vegan');
      final isInd = pLower.contains('indian') || pLower.contains('desi') || pLower.contains('roti') || pLower.contains('paneer') || pLower.contains('dosa') || pLower.contains('idli');
      
      String? mealFilter;
      if (pLower.contains('breakfast')) {
        mealFilter = 'Breakfast';
      } else if (pLower.contains('lunch')) {
        mealFilter = 'Lunch';
      } else if (pLower.contains('dinner')) {
        mealFilter = 'Dinner';
      } else if (pLower.contains('snack')) {
        mealFilter = 'Snacks';
      }

      final scored = results.map((food) {
        double score = 0.0;
        final nameLower = food.name.toLowerCase();

        // High priority: exact name match / name contained in prompt
        if (pLower.contains(nameLower) || nameLower.contains(pLower)) {
          score += 500.0;
        }

        // Dietary alignment
        if (isVegn) {
          if (food.isVegan) {
            score += 50.0;
          } else {
            score -= 200.0;
          }
        }
        if (isVeg) {
          if (food.isVegetarian) {
            score += 50.0;
          } else {
            score -= 200.0;
          }
        }

        // Cuisine alignment
        if (isInd) {
          if (food.isIndian) score += 100.0;
        } else {
          // Default: slightly favor international foods if not asking for Indian specifically
          if (!food.isIndian) score += 10.0;
        }

        // Meal alignment
        if (mealFilter != null) {
          if (food.mealTypes.contains(mealFilter)) {
            score += 100.0;
          } else {
            score -= 20.0;
          }
        }

        // High Protein preference
        if (pLower.contains('protein') || pLower.contains('high protein')) {
          score += food.protein * 5.0;
        }

        // Low Calorie preference
        if (pLower.contains('low calorie') || pLower.contains('low-calorie') || pLower.contains('under 300')) {
          score += (300.0 - food.calories).clamp(-100.0, 100.0);
        }

        // Low Fat preference
        if (pLower.contains('low fat') || pLower.contains('low-fat')) {
          score += (10.0 - food.fats).clamp(-50.0, 50.0);
        }

        // High Fiber preference
        if (pLower.contains('fiber') || pLower.contains('high fiber') || pLower.contains('high-fiber')) {
          score += food.fiber * 5.0;
        }

        // Low Sugar preference
        if (pLower.contains('low sugar') || pLower.contains('low-sugar')) {
          score += (10.0 - food.sugar).clamp(-50.0, 50.0);
        }

        return _ScoredFood(food: food, score: score);
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));
      foods.addAll(scored.take(25).map((e) => e.food));
    } catch (_) {}

    final systemContext = AiContextGenerator.generateContext(
      todayRecords: todayRecords,
      historyRecords: historyRecords,
      goals: goals,
      todayHealth: todayHealth,
      historyHealth: historyHealth,
      profile: profile,
      weightHistory: weightHistory,
      availableFoods: foods,
      mealPlan: mealPlan,
      dailyRoutine: dailyRoutine,
      groceryItems: groceryItems,
      pantryItems: pantryItems,
    );

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    // Delegate to remote provider if configured, otherwise fallback to local mock
    if (apiKey.trim().isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY') {
      try {
        return await _remoteDatasource.generateResponse(
          userPrompt: prompt,
          systemContext: systemContext,
          history: history,
        );
      } catch (e) {
        // Fallback to mock on API errors
        return _mockDatasource.generateResponse(
          userPrompt: prompt,
          systemContext: systemContext,
          history: history,
        );
      }
    } else {
      return _mockDatasource.generateResponse(
        userPrompt: prompt,
        systemContext: systemContext,
        history: history,
      );
    }
  }
}

class _ScoredFood {
  final FoodEntity food;
  final double score;
  const _ScoredFood({required this.food, required this.score});
}
