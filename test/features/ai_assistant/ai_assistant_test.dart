import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';
import 'package:fitfuel/features/ai_assistant/data/repositories/ai_nutrition_repository_impl.dart';
import 'package:fitfuel/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=');
  });

  final now = DateTime.now();

  final testGoal = NutritionGoalsEntity(
    userId: 'user_ai',
    dailyCalorieTarget: 2000,
    proteinTargetGrams: 100.0,
    carbsTargetGrams: 200.0,
    fatTargetGrams: 50.0,
    updatedAt: now,
  );

  final breakfastLog = NutritionRecordEntity(
    id: 'b1',
    foodName: 'Oats',
    mealType: 'Breakfast',
    calories: 400.0,
    protein: 15.0,
    carbohydrates: 60.0,
    fats: 6.0,
    sugar: 2.0,
    servingSize: 150.0,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('AI Context Generator Tests', () {
    test('Correctly compiles goals, today consumed, and remaining values', () {
      final context = AiContextGenerator.generateContext(
        todayRecords: [breakfastLog],
        historyRecords: [breakfastLog],
        goals: testGoal,
      );

      // Verify goals are formatted in context
      expect(context.contains('Calories Target: 2000 kcal'), isTrue);
      expect(context.contains('Protein Target: 100 g'), isTrue);

      // Verify today progress is calculated (400 consumed / 1600 remaining)
      expect(context.contains('Calories: 400 kcal consumed / 1600 kcal remaining'), isTrue);
      expect(context.contains('Protein: 15.0 g consumed / 85.0 g remaining'), isTrue);
    });

    test('Includes recent history averages and consistency score', () {
      final context = AiContextGenerator.generateContext(
        todayRecords: [breakfastLog],
        historyRecords: [breakfastLog],
        goals: testGoal,
      );

      expect(context.contains('Weekly Logging Consistency: 14%'), isTrue);
      expect(context.contains('Average Calories Logged: 400 kcal'), isTrue);
    });

    test('Handles empty user goals and logs safely', () {
      final context = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
      );

      // Fallback goals: 2000 kcal
      expect(context.contains('Calories Target: 2000 kcal'), isTrue);
      expect(context.contains('Calories: 0 kcal consumed / 2000 kcal remaining'), isTrue);
    });
  });

  group('AI Provider and Repository Tests', () {
    test('Mock AI provider generates replies matching user prompts', () async {
      final mockProvider = AiNutritionMockDatasource();

      final context = AiContextGenerator.generateContext(
        todayRecords: [breakfastLog],
        historyRecords: [breakfastLog],
        goals: testGoal,
      );

      final reply = await mockProvider.generateResponse(
        userPrompt: 'What is left in my calorie target?',
        systemContext: context,
      );

      expect(reply.sender, MessageSender.ai);
      expect(reply.text.contains('1600 kcal'), isTrue);
      expect(reply.text.contains('Disclaimer:'), isTrue); // Verify safety disclaimer exists
    });

    test('Chooses mock datasource if API key is not configured', () async {
      final repo = AiNutritionRepositoryImpl();

      final reply = await repo.askAssistant(
        prompt: 'Give me a high protein dinner option',
        todayRecords: [],
        historyRecords: [],
        goals: testGoal,
      );

      expect(reply.sender, MessageSender.ai);
      expect(reply.suggestedFoods != null && reply.suggestedFoods!.isNotEmpty, isTrue);
    });

    test('Mock AI provider respects chicken exclusion and avoids suggesting chicken', () async {
      final mockProvider = AiNutritionMockDatasource();

      final reply = await mockProvider.generateResponse(
        userPrompt: 'I cannot eat chicken today. Suggest a high protein dinner.',
        systemContext: 'Dummy context',
      );

      expect(reply.suggestedFoods != null && reply.suggestedFoods!.isNotEmpty, isTrue);
      expect(reply.suggestedFoods!.first.foodName.toLowerCase().contains('chicken'), isFalse);
      
      final suggestedFoodName = reply.suggestedFoods!.first.foodName.toLowerCase();
      final matchedFood = PredefinedFoodData.foods.firstWhere(
        (f) => f.name.toLowerCase() == suggestedFoodName,
        orElse: () => PredefinedFoodData.foods.first,
      );
      expect(matchedFood.protein, greaterThanOrEqualTo(10.0));
    });

    test('Mock AI provider respects oats exclusion and avoids suggesting oats', () async {
      final mockProvider = AiNutritionMockDatasource();

      final reply = await mockProvider.generateResponse(
        userPrompt: 'Suggest a meal rather than oats',
        systemContext: 'Dummy context',
      );

      expect(reply.suggestedFoods != null && reply.suggestedFoods!.isNotEmpty, isTrue);
      expect(reply.suggestedFoods!.first.foodName.toLowerCase().contains('oats'), isFalse);
    });

    test('Mock AI provider offers different suggestion when request is repeated', () async {
      final mockProvider = AiNutritionMockDatasource();

      final firstReply = await mockProvider.generateResponse(
        userPrompt: 'Suggest a high protein food',
        systemContext: 'Dummy context',
        history: [],
      );

      final dummyTime = DateTime(2026, 8, 10);
      final secondReply = await mockProvider.generateResponse(
        userPrompt: 'Suggest another high protein food',
        systemContext: 'Dummy context',
        history: [
          ChatMessage(text: 'Suggest a high protein food', sender: MessageSender.user, timestamp: dummyTime),
          firstReply,
        ],
      );

      expect(firstReply.suggestedFoods != null && firstReply.suggestedFoods!.isNotEmpty, isTrue);
      expect(secondReply.suggestedFoods != null && secondReply.suggestedFoods!.isNotEmpty, isTrue);

      final firstName = firstReply.suggestedFoods!.first.foodName;
      final secondName = secondReply.suggestedFoods!.first.foodName;
      expect(firstName != secondName, isTrue);
    });

    test('Mock AI provider preserves multi-turn exclusions across history', () async {
      final mockProvider = AiNutritionMockDatasource();
      final dummyTime = DateTime(2026, 8, 10);

      final reply = await mockProvider.generateResponse(
        userPrompt: 'What should I eat?',
        systemContext: 'Dummy context',
        history: [
          ChatMessage(text: 'I cannot eat chicken today', sender: MessageSender.user, timestamp: dummyTime),
          ChatMessage(text: 'Got it. I suggest Paneer.', sender: MessageSender.ai, timestamp: dummyTime),
        ],
      );

      expect(reply.suggestedFoods != null && reply.suggestedFoods!.isNotEmpty, isTrue);
      expect(reply.suggestedFoods!.first.foodName.toLowerCase().contains('chicken'), isFalse);
    });

    test('Mock AI provider prioritizes hydration questions and does not return food suggestions', () async {
      final mockProvider = AiNutritionMockDatasource();
      const context = '''
TODAY HYDRATION, WORKOUT & HABITS:
- Water Intake: 1000 ml / 2000 ml
''';

      final reply = await mockProvider.generateResponse(
        userPrompt: 'Am I drinking enough water today? What should I do based on my current hydration?',
        systemContext: context,
      );

      expect(reply.suggestedFoods, isNull);
      expect(reply.text.contains('1000 ml'), isTrue);
      expect(reply.text.contains('2000 ml'), isTrue);
    });

    test('Mock AI provider prioritizes exercise questions and does not return food suggestions', () async {
      final mockProvider = AiNutritionMockDatasource();
      const context = '''
TODAY HYDRATION, WORKOUT & HABITS:
- Workout Duration: 45 minutes
- Workout Calories Burned: 400 kcal
''';

      final reply = await mockProvider.generateResponse(
        userPrompt: 'Tell me about my exercise duration and calories burned today.',
        systemContext: context,
      );

      expect(reply.suggestedFoods, isNull);
      expect(reply.text.contains('45 minutes'), isTrue);
      expect(reply.text.contains('400 kcal'), isTrue);
    });

    test('Mock AI provider prioritizes habits checklist questions and does not return food suggestions', () async {
      final mockProvider = AiNutritionMockDatasource();
      const context = '''
TODAY HYDRATION, WORKOUT & HABITS:
- Habits Completed: 2 / 3
''';

      final reply = await mockProvider.generateResponse(
        userPrompt: 'Have I completed all my daily habits today?',
        systemContext: context,
      );

      expect(reply.suggestedFoods, isNull);
      expect(reply.text.contains('2 out of 3'), isTrue);
    });

    test('Mock AI provider prioritizes wellness score questions and does not return food suggestions', () async {
      final mockProvider = AiNutritionMockDatasource();
      const context = '''
TODAY HYDRATION, WORKOUT & HABITS:
- Wellness Score: 85 / 100
''';

      final reply = await mockProvider.generateResponse(
        userPrompt: 'What is my current wellness score rank?',
        systemContext: context,
      );

      expect(reply.suggestedFoods, isNull);
      expect(reply.text.contains('85'), isTrue);
    });
    test('Mock AI provider routes conversations and prevents food suggestions for generic intents', () async {
      final mockProvider = AiNutritionMockDatasource();
      const context = '''
=== FITFUEL WEEKLY HEALTH REPORT ===
Weekly Health Score: 75/100
Strongest Area: Habits
Weakest Area: Hydration
Next Week Action Plan: Reach hydration target at least 5 days
=== END WEEKLY HEALTH REPORT ===
TODAY HYDRATION, WORKOUT & HABITS:
- Water Intake: 1000 ml / 2500 ml
''';

      // 1. Greeting
      final hiReply = await mockProvider.generateResponse(userPrompt: 'Hi', systemContext: context);
      expect(hiReply.suggestedFoods, isNull);
      expect(hiReply.text.contains('Hi! 👋 I\'m FitFuel AI'), isTrue);

      final helloReply = await mockProvider.generateResponse(userPrompt: 'Hello', systemContext: context);
      expect(helloReply.suggestedFoods, isNull);
      expect(helloReply.text.contains('Hi! 👋 I\'m FitFuel AI'), isTrue);

      // 2. Chat
      final chatReply = await mockProvider.generateResponse(userPrompt: 'How are you?', systemContext: context);
      expect(chatReply.suggestedFoods, isNull);
      expect(chatReply.text.contains('doing great'), isTrue);

      // 3. Acknowledge
      final thanksReply = await mockProvider.generateResponse(userPrompt: 'Thanks', systemContext: context);
      expect(thanksReply.suggestedFoods, isNull);
      expect(thanksReply.text.contains('very welcome'), isTrue);

      // 4. Capabilities
      final capReply = await mockProvider.generateResponse(userPrompt: 'What can you do?', systemContext: context);
      expect(capReply.suggestedFoods, isNull);
      expect(capReply.text.contains('FitFuel\'s AI Nutrition and Wellness Assistant'), isTrue);

      // 5. Meal Recommendation
      final dinnerReply = await mockProvider.generateResponse(userPrompt: 'What should I eat for dinner?', systemContext: context);
      expect(dinnerReply.suggestedFoods != null && dinnerReply.suggestedFoods!.isNotEmpty, isTrue);

      final proteinReply = await mockProvider.generateResponse(userPrompt: 'Suggest a high protein food', systemContext: context);
      expect(proteinReply.suggestedFoods != null && proteinReply.suggestedFoods!.isNotEmpty, isTrue);

      // 6. Hydration
      final hydrationReply = await mockProvider.generateResponse(userPrompt: 'How is my hydration today?', systemContext: context);
      expect(hydrationReply.suggestedFoods, isNull);
      expect(hydrationReply.text.contains('1000 ml'), isTrue);

      // 7. Weekly Report
      final weeklyReply = await mockProvider.generateResponse(userPrompt: 'How was my week?', systemContext: context);
      expect(weeklyReply.suggestedFoods, isNull);
      expect(weeklyReply.text.contains('Health Score: 75/100'), isTrue);

      final improveReply = await mockProvider.generateResponse(userPrompt: 'What should I improve next week?', systemContext: context);
      expect(improveReply.suggestedFoods, isNull);
      expect(improveReply.text.contains('Reach hydration target at least 5 days'), isTrue);
    });

    test('Mock AI provider Phase 22 coaching replies', () async {
      final mockProvider = AiNutritionMockDatasource();

      // 1. Motivation
      final motivationReply = await mockProvider.generateResponse(
        userPrompt: 'I missed my goals today and feel discouraged.',
        systemContext: 'Dummy context',
      );
      expect(motivationReply.suggestedFoods, isNull);
      expect(motivationReply.text.contains('consistency'), isTrue);
      expect(motivationReply.text.contains('momentum'), isTrue);

      // 2. Weight Progress
      const weightContext = '''
LONG-TERM PROGRESS
- starting weight: 85.0 kg
- current weight: 82.5 kg
- change: -2.5 kg
''';
      final weightReply = await mockProvider.generateResponse(
        userPrompt: 'How is my weight progressing?',
        systemContext: weightContext,
      );
      expect(weightReply.suggestedFoods, isNull);
      expect(weightReply.text.contains('85.0 kg'), isTrue);
      expect(weightReply.text.contains('82.5 kg'), isTrue);
      expect(weightReply.text.contains('2.5 kg'), isTrue);

      // 3. Structured Daily Action Plan
      final dailyPlanReply = await mockProvider.generateResponse(
        userPrompt: 'Give me a plan for tomorrow.',
        systemContext: 'Dummy context',
      );
      expect(dailyPlanReply.suggestedFoods, isNull);
      expect(dailyPlanReply.text.contains('Morning'), isTrue);
      expect(dailyPlanReply.text.contains('Afternoon'), isTrue);
      expect(dailyPlanReply.text.contains('Evening'), isTrue);
      expect(dailyPlanReply.text.contains('Night'), isTrue);

      // 4. Focus Today Priorities
      const focusContext = '''
USER HEALTH PROFILE:
- Protein Target: 150 g
- Calories Target: 2000 kcal
USER NUTRITION CONTEXT:
- Calories: 1000 / 1000 kcal remaining
- Protein: 50 / 100 g remaining
TODAY HYDRATION, WORKOUT & HABITS:
- Water Intake: 1000 ml / 2500 ml
- Workout Duration: 0 minutes
- Habits Completed: 1 / 3
''';
      final focusReply = await mockProvider.generateResponse(
        userPrompt: 'What should I focus on today?',
        systemContext: focusContext,
      );
      expect(focusReply.suggestedFoods, isNull);
      expect(focusReply.text.contains('Protein intake is high priority'), isTrue);
      expect(focusReply.text.contains('Hydration is priority'), isTrue);
      expect(focusReply.text.contains('Exercise is priority'), isTrue);

      // 5. Goal-Aware Coaching
      const goalContext = '''
USER HEALTH PROFILE:
- Fitness Goal: Gain Muscle
- Protein Target: 160 g
- Calories Target: 2500 kcal
''';
      final goalReply = await mockProvider.generateResponse(
        userPrompt: 'How do I train and recover for my fitness goal?',
        systemContext: goalContext,
      );
      expect(goalReply.suggestedFoods, isNull);
      expect(goalReply.text.contains('Gain Muscle'), isTrue);
      expect(goalReply.text.contains('protein'), isTrue);
    });

    test('Mock AI provider Phase 23 food database and exclusion flow', () async {
      final mockProvider = AiNutritionMockDatasource();
      final nowTime = DateTime.now();
      const context = '''
USER HEALTH PROFILE:
- Dietary Preference: none
USER NUTRITION CONTEXT:
- Calories: 1000 / 2000 kcal remaining
- Protein: 50 / 150 g remaining
AVAILABLE FOODS DATABASE:
- Food: Grilled Chicken Breast | Category: Protein | Serving: 100 g | Calories: 165 kcal | Protein: 31.0g | Carbs: 0.0g | Fats: 3.6g | Fiber: 0.0g | Sugar: 0.0g | Sodium: 74mg | id: predefined_chicken_breast | isFavorite: false
- Food: Paneer (Cottage Cheese) | Category: Dairy | Serving: 100 g | Calories: 265 kcal | Protein: 18.3g | Carbs: 1.2g | Fats: 20.8g | Fiber: 0.0g | Sugar: 1.2g | Sodium: 18mg | id: predefined_paneer | isFavorite: false
- Food: Whole Eggs (Boiled) | Category: Breakfast | Serving: 100 g | Calories: 155 kcal | Protein: 13.0g | Carbs: 1.1g | Fats: 11.0g | Fiber: 0.0g | Sugar: 1.1g | Sodium: 124mg | id: predefined_eggs | isFavorite: false
''';

      // 1. Ask general recommendation
      final recReply = await mockProvider.generateResponse(
        userPrompt: 'What should I eat?',
        systemContext: context,
      );
      expect(recReply.suggestedFoods != null && recReply.suggestedFoods!.isNotEmpty, isTrue);

      // 2. Reject chicken
      final rejectReply = await mockProvider.generateResponse(
        userPrompt: 'I don\'t want chicken.',
        systemContext: context,
        history: [
          ChatMessage(text: 'What should I eat?', sender: MessageSender.user, timestamp: nowTime),
          ChatMessage(text: recReply.text, sender: MessageSender.ai, timestamp: nowTime),
        ],
      );
      expect(rejectReply.text.contains('chicken'), isTrue);

      // 3. Ask high protein dinner excluding chicken
      final nextReply = await mockProvider.generateResponse(
        userPrompt: 'Give me a high protein dinner.',
        systemContext: context,
        history: [
          ChatMessage(text: 'What should I eat?', sender: MessageSender.user, timestamp: nowTime),
          ChatMessage(text: recReply.text, sender: MessageSender.ai, timestamp: nowTime),
          ChatMessage(text: 'I don\'t want chicken.', sender: MessageSender.user, timestamp: nowTime),
          ChatMessage(text: rejectReply.text, sender: MessageSender.ai, timestamp: nowTime),
        ],
      );
      expect(nextReply.suggestedFoods!.any((f) => f.foodName.toLowerCase().contains('chicken')), isFalse);
      expect(nextReply.suggestedFoods!.any((f) => f.foodName.toLowerCase().contains('paneer')), isTrue);
    });
  });
}
