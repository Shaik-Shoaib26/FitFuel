import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/ai_nutrition_service.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../food/domain/utils/food_recommendation_engine.dart';
import '../../../food/data/datasources/predefined_food_data.dart';
import '../../../food/data/repositories/food_asset_repository.dart';

class AiNutritionMockDatasource implements AiNutritionService {
  @override
  Future<ChatMessage> generateResponse({
    required String userPrompt,
    required String systemContext,
    List<ChatMessage> history = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate async network latency

    final prompt = userPrompt.toLowerCase();

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

    // Process history user messages and current prompt
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

    // 3. Extract values dynamically from context
    final double remainingCals = _extractValueForLine(systemContext, '- Calories:', '/', 'kcal remaining');
    final double remainingPro = _extractValueForLine(systemContext, '- Protein:', '/', 'g remaining');
    final double remainingCarbs = _extractValueForLine(systemContext, '- Carbohydrates:', '/', 'g remaining');
    final double remainingFats = _extractValueForLine(systemContext, '- Fat:', '/', 'g remaining');


    double extractVal(String lineContains, String prefix, String suffix) {
      try {
        final lines = systemContext.split('\n');
        final targetLine = lines.firstWhere((l) => l.contains(lineContains));
        final startIndex = targetLine.indexOf(prefix);
        if (startIndex == -1) return 0.0;
        final valueStart = startIndex + prefix.length;
        final endIndex = suffix.isEmpty ? targetLine.length : targetLine.indexOf(suffix, valueStart);
        final substring = targetLine.substring(valueStart, endIndex == -1 ? targetLine.length : endIndex).trim();
        return double.tryParse(substring.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }

    String extractString(String lineContains) {
      try {
        final lines = systemContext.split('\n');
        final targetLine = lines.firstWhere((l) => l.contains(lineContains));
        final parts = targetLine.split(':');
        if (parts.length < 2) return '';
        return parts[1].trim();
      } catch (_) {
        return '';
      }
    }

    final double goalCals = extractVal('Calories Target:', 'Calories Target:', ' kcal');
    final double goalPro = extractVal('Protein Target:', 'Protein Target:', ' g');

    final String activityLvl = extractString('- Activity Level:');
    final String fitnessGl = extractString('- Fitness Goal:');
    final String dietaryPref = extractString('- Dietary Preference:');
    final String calorieCons = extractString('- calorie consistency:');
    final String proteinCons = extractString('- protein consistency:');
    final String hydrationCons = extractString('- hydration consistency:');
    final String exerciseCons = extractString('- active days:');
    final String habitRate = extractString('- average completion:');
    final String wellnessTrendStr = extractString('- trend:');
    final String weightTrackerStr = extractString('- change:');
    final String unlockedMilestonesStr = extractString('Achievements:');
    final String nutritionStreakStr = extractString('Current Streak:');
    final String weeklyHealthScore = extractString('Weekly Health Score:');
    final String previousWeekScore = extractString('Previous Week Score:');
    final String weeklyScoreChange = extractString('Score Change:');
    final String strongestCategory = extractString('Strongest Area:');
    final String weakestCategory = extractString('Weakest Area:');
    final String weeklyInsights = extractString('Weekly Insights:');
    final String nextWeekActionPlan = extractString('Next Week Action Plan:');

    // Analytics Context Extractions
    final String analyticsConsistency = extractString('- Overall Consistency:');
    final String analyticsNutrition = extractString('- Nutrition Adherence:');
    final String analyticsHydration = extractString('- Hydration Adherence:');
    final String analyticsExercise = extractString('- Exercise Consistency:');
    final String analyticsWellnessTrend = extractString('- Wellness Trend:');
    final String analyticsWeightTrend = extractString('- Weight Trend:');
    final String analyticsWeakest = extractString('- Weakest Area:');
    final String analyticsStrongest = extractString('- Strongest Area:');
    final String analyticsComparison = extractString('- Period Comparison:');

    String textResponse = '';
    List<NutritionRecordEntity>? suggestedFoods;


    final String pLower = prompt.toLowerCase().trim();

    // 1. GENERAL_CONVERSATION
    final bool isGreeting = pLower == 'hi' || pLower == 'hello' || pLower == 'hey' || pLower == 'greetings' || pLower.startsWith('hi ') || pLower.startsWith('hello ') || pLower.startsWith('hey ') || pLower == 'good morning' || pLower == 'good evening';
    final bool isChat = pLower.contains('how are you') || pLower.contains('how is it going') || pLower.contains('how\'s it going') || pLower.contains('how are you doing');
    final bool isAcknowledge = pLower == 'thanks' || pLower == 'thank you' || pLower == 'ok' || pLower == 'okay' || pLower == 'great' || pLower == 'awesome' || pLower == 'perfect' || pLower == 'bye' || pLower == 'goodbye' || pLower.startsWith('thank you');
    final bool isCapabilities = pLower.contains('who are you') || pLower.contains('what can you do') || pLower.contains('what are you') || pLower.contains('help me') || pLower.contains('how do you work') || pLower.contains('tell me about yourself') || pLower.contains('tell me about fitfuel');
    final bool isGeneralConversation = isGreeting || isChat || isAcknowledge || isCapabilities;

    // 2. MOTIVATION
    final bool isMotivation = pLower.contains('motivation') || pLower.contains('missed my') || pLower.contains('didn\'t exercise') || pLower.contains('did not exercise') || pLower.contains('give up') || pLower.contains('hard to stay') || pLower.contains('struggling') || pLower.contains('lost focus') || pLower.contains('discouraged') || pLower.contains('failed');

    // 3. ACHIEVEMENT_COACHING
    final bool isAchievementCoaching = pLower.contains('achievement') || pLower.contains('milestone') || pLower.contains('streak') || pLower.contains('badge') || pLower.contains('unlock');

    // 4. WEIGHT_PROGRESS
    final bool isWeightProgress = pLower.contains('weight') && (pLower.contains('progress') || pLower.contains('trend') || pLower.contains('goal') || pLower.contains('change') || pLower.contains('scale'));

    // 5. DAILY_PLAN
    final bool isDailyPlan = pLower.contains('plan for tomorrow') || pLower.contains('tomorrow\'s plan') || pLower.contains('tomorrow plan') || pLower.contains('plan for today') || pLower.contains('today\'s plan') || pLower.contains('daily action plan') || pLower.contains('plan tomorrow');

    // 6. COACHING (What to focus on today)
    final bool isCoaching = pLower.contains('what should i focus on today') || pLower.contains('focus on today') || pLower.contains('rest of today') || pLower.contains('finish today\'s goals') || pLower.contains('finish today') || pLower.contains('focus today');
    final bool isDoingWell = pLower.contains('what am i doing well') || pLower.contains('doing well') || pLower.contains('what is going well') || pLower.contains('what am i doing right') || pLower.contains('what are my positive highlights');

    // 7. WEEKLY_COACHING (weekly specific prompts)
    final bool isWeeklyIndicator = pLower.contains('week') || pLower.contains('weekly') || pLower.contains('report') || pLower.contains('trend') || pLower.contains('history') || pLower.contains('was') || pLower.contains('were') || pLower.contains('did') || pLower.contains('overall') || pLower.contains('change');
    final bool isWeeklyOverview = (pLower.contains('how was my week') || (pLower.contains('week') && pLower.contains('report')) || pLower.contains('weekly overview') || pLower.contains('summarize my week') || pLower.contains('how did my week') || pLower.contains('how am i doing this week')) && !isGeneralConversation;
    final bool isStrongestArea = pLower.contains('strongest') && (pLower.contains('area') || pLower.contains('health') || pLower.contains('category') || pLower.contains('best') || pLower.contains('well')) && !isGeneralConversation;
    final bool isWeakestArea = (pLower.contains('weakest') || pLower.contains('area to improve') || pLower.contains('worst area')) && !isGeneralConversation;
    final bool isNextWeekImprovement = (pLower.contains('improve next week') || pLower.contains('focus on next week') || pLower.contains('plan for next week') || pLower.contains('next week')) && !isGeneralConversation;
    final bool isScoreChange = (pLower.contains('score change') || pLower.contains('score improve') || pLower.contains('score decrease') || pLower.contains('score difference') || (pLower.contains('why did my') && pLower.contains('score'))) && !isGeneralConversation;
    final bool isWeeklyNutrition = (pLower.contains('nutrition') || pLower.contains('calories') || pLower.contains('protein')) && isWeeklyIndicator && !isGeneralConversation;
    final bool isWeeklyHydration = (pLower.contains('hydration') || pLower.contains('water') || pLower.contains('drink')) && isWeeklyIndicator && !isGeneralConversation;
    final bool isWeeklyExercise = (pLower.contains('exercise') || pLower.contains('workout') || pLower.contains('active')) && isWeeklyIndicator && !isGeneralConversation;
    final bool isWeeklyHabits = (pLower.contains('habits') || pLower.contains('checklist')) && isWeeklyIndicator && !isGeneralConversation;
    final bool isWeeklyWellness = pLower.contains('wellness') && isWeeklyIndicator && !isGeneralConversation;
    final bool isWeeklyWeight = pLower.contains('weight') && (isWeeklyIndicator || pLower.contains('scale') || pLower.contains('gain') || pLower.contains('loss')) && !isGeneralConversation;
    final bool isAchievements = (pLower.contains('achievements') || pLower.contains('milestones') || pLower.contains('unlocked')) && !isGeneralConversation;
    final bool isStreak = (pLower.contains('streak') || pLower.contains('consecutive')) && !isGeneralConversation;

    final bool isWeeklyCoaching = isWeeklyOverview || isStrongestArea || isWeakestArea || isNextWeekImprovement || isScoreChange || isWeeklyNutrition || isWeeklyHydration || isWeeklyExercise || isWeeklyHabits || isWeeklyWellness || isWeeklyWeight || isAchievements || isStreak;

    // Health profile and Progress checks
    final bool isHealthProfile = (pLower.contains('activity level') || (pLower.contains('fitness goal') && (pLower.contains('what is my') || pLower.contains('current') || pLower.contains('settings') || pLower.contains('profile')) && !pLower.contains('train') && !pLower.contains('recover') && !pLower.contains('adapt')) || pLower.contains('dietary preference') || pLower.contains('profile settings') || (pLower.contains('my goal') && !pLower.contains('my goals')) || pLower.contains('health profile') || pLower.contains('profile information')) && !isGeneralConversation;
    final bool isProgress = (pLower.contains('progress') || pLower.contains('consistency') || pLower.contains('wellness change') || pLower.contains('weight trend')) && !isGeneralConversation && !isWeeklyIndicator;

    // 8. GOAL_COACHING (fit goal queries)
    final bool isGoalCoaching = (pLower.contains('fitness goal') || (pLower.contains('my goal') && !pLower.contains('my goals')) || pLower.contains('profile settings') || pLower.contains('activity level') || pLower.contains('health profile') || pLower.contains('profile information') || pLower.contains('how am i doing') || pLower.contains('what should i focus')) && !isGeneralConversation && !isCoaching;

    // Analytics Query Intent Flags
    final bool isAnalyticsQuery = (pLower.contains('analytics') ||
        pLower.contains('trend') ||
        pLower.contains('progress') ||
        pLower.contains('consistency') ||
        pLower.contains('last month') ||
        pLower.contains('this month') ||
        pLower.contains('7 days') ||
        pLower.contains('30 days') ||
        pLower.contains('90 days') ||
        pLower.contains('weight trend') ||
        pLower.contains('hydration trend') ||
        pLower.contains('nutrition trend') ||
        pLower.contains('exercise trend') ||
        pLower.contains('habit trend') ||
        pLower.contains('wellness trend') ||
        pLower.contains('strongest area') ||
        pLower.contains('weakest area') ||
        pLower.contains('focus area') ||
        pLower.contains('comparison') ||
        pLower.contains('compare') ||
        pLower.contains('improved') ||
        pLower.contains('declined') ||
        pLower.contains('how am i doing') ||
        pLower.contains('what should i focus') ||
        pLower.contains('nutrition') ||
        pLower.contains('hydration') ||
        pLower.contains('exercise') ||
        pLower.contains('habit') ||
        pLower.contains('wellness') ||
        pLower.contains('weight')) && !isGeneralConversation;

    // 9. MEAL_PLAN
    final bool isGiveMealPlan = pLower.contains('give me today\'s meal plan') ||
        pLower.contains('give me my meal plan') ||
        pLower.contains('today\'s meal plan') ||
        pLower.contains('what is my meal plan') ||
        pLower.contains('what\'s my meal plan') ||
        pLower.contains('show my meal plan');

    final bool isSwapIntent = pLower.contains('swap');

    // Smart Grocery & Pantry Intents
    final bool isGroceryQuery = pLower.contains('buy') ||
        pLower.contains('grocery') ||
        pLower.contains('groceries') ||
        pLower.contains('shopping list') ||
        pLower.contains('shopping') ||
        pLower.contains('need to get') ||
        pLower.contains('pantry') ||
        pLower.contains('expiring') ||
        pLower.contains('expired') ||
        pLower.contains('running out') ||
        pLower.contains('what do i have') ||
        pLower.contains('already have') ||
        pLower.contains('do i have') ||
        pLower.contains('what\'s expiring') ||
        pLower.contains('what is expiring') ||
        pLower.contains('pantry stock');

    final bool isSubstitutionQuery = pLower.contains('don\'t have') ||
        pLower.contains('dont have') ||
        pLower.contains('do not have') ||
        pLower.contains('alternative') ||
        pLower.contains('substitute') ||
        pLower.contains('instead of');

    final bool isMealPlan = (pLower.contains('what should i eat') ||
        pLower.contains('what should i have for') ||
        pLower.contains('what can i eat') ||
        pLower.contains('what to eat') ||
        pLower.contains('dinner plan') ||
        pLower.contains('meal plan') ||
        pLower.contains('suggest a vegetarian') ||
        pLower.contains('food recommendation') ||
        pLower.contains('meal recommendation') ||
        pLower.contains('food suggest') ||
        pLower.contains('meal suggest') ||
        ((pLower.contains('suggest') || pLower.contains('give') || pLower.contains('recommend') || pLower.contains('option') || pLower.contains('plan')) &&
         (pLower.contains('food') || pLower.contains('meal') || pLower.contains('breakfast') || pLower.contains('lunch') || pLower.contains('dinner') || pLower.contains('snack')))) && !isGiveMealPlan && !isSwapIntent;

    // 10. HYDRATION_COACHING
    final bool isHydrationCoaching = (pLower.contains('water') || pLower.contains('hydration') || pLower.contains('drink')) && !isWeeklyIndicator && !isGeneralConversation;

    // 11. EXERCISE_COACHING
    final bool isExerciseCoaching = (pLower.contains('exercise') || pLower.contains('workout') || pLower.contains('active') || pLower.contains('duration') || pLower.contains('burned')) && !isWeeklyIndicator && !isGeneralConversation;

    // 12. HABIT_COACHING
    final bool isHabitCoaching = (pLower.contains('habit') || pLower.contains('checklist') || pLower.contains('sleep') || pLower.contains('step') || pLower.contains('stretch')) && !isWeeklyIndicator && !isGeneralConversation;

    // Wellness
    final bool isWellness = (pLower.contains('wellness') || pLower.contains('score') || pLower.contains('rank')) && !isWeeklyIndicator && !isGeneralConversation;

    // 13. NUTRITION_ANALYSIS
    final bool isNutritionAnalysis = (pLower.contains('calorie') || pLower.contains('protein') || pLower.contains('carb') || pLower.contains('fat') || pLower.contains('target') || pLower.contains('remaining') || pLower.contains('left')) && !isWeeklyIndicator && !isGeneralConversation && !isMealPlan;

    // 14. FOOD_LOGGING
    final bool isFoodLogging = pLower.contains('what did i eat today') || pLower.contains('what have i eaten today') || pLower.contains('my food log') || pLower.contains('logged meals') || pLower.contains('food log') || pLower.contains('meal log');

    // 15. GENERAL_NUTRITION
    final bool isGeneralNutrition = pLower.contains('what is a calorie') ||
        pLower.contains('what is protein') ||
        pLower.contains('why is hydration') ||
        pLower.contains('tell me about hydration') ||
        pLower.contains('importance of') ||
        pLower.contains('what is fat') ||
        pLower.contains('what is carb');

    final bool isFoodExclusionPrompt = excludedFoods.isNotEmpty && (pLower.contains(RegExp(r'\bno\b')) || pLower.contains('avoid') || pLower.contains('dont want') || pLower.contains('don\'t want') || pLower.contains('exclude') || pLower.contains('without')) && !isMealPlan;

    final bool isRoutineQuery = (pLower.contains('routine') ||
        pLower.contains('reminder') ||
        pLower.contains('pending') ||
        pLower.contains('next action') ||
        pLower.contains('next task') ||
        pLower.contains('what should i do next') ||
        pLower.contains('on track') ||
        pLower.contains('what\'s left to do') ||
        pLower.contains('what is left to do') ||
        pLower.contains('tasks left') ||
        pLower.contains('things left')) && !isGeneralConversation && !isMealPlan;

    // Routing Priority: Specific queries before general settings
    final bool isRecipeQuery = pLower.contains('how do i prepare') ||
        pLower.contains('how to prepare') ||
        pLower.contains('how to make') ||
        pLower.contains('recipe for') ||
        pLower.contains('cooking instruction');

    if (isFoodExclusionPrompt) {
      textResponse = "Understood. I will exclude ${excludedFoods.join(', ')} from your food recommendations.";
      suggestedFoods = null;
    } else if (isRecipeQuery) {
      String queryFoodName = pLower
          .replaceAll('how do i prepare', '')
          .replaceAll('how to prepare', '')
          .replaceAll('how to make', '')
          .replaceAll('recipe for', '')
          .replaceAll('cooking instructions for', '')
          .replaceAll('?', '')
          .trim();
      RecipeDetails? matchedRecipe;
      
      // Try exact or partial match on recipe names
      for (final rec in FoodAssetRepository.recipes.values) {
        final name = rec.foodName.toLowerCase();
        if (name == queryFoodName || queryFoodName.contains(name) || name.contains(queryFoodName)) {
          matchedRecipe = rec;
          break;
        }
      }
      
      if (matchedRecipe != null) {
        final buffer = StringBuffer();
        buffer.writeln('Here is the recipe for **${matchedRecipe.foodName}**:\n');
        buffer.writeln('**Category:** ${matchedRecipe.dietType.toUpperCase()} • **Cuisine:** ${matchedRecipe.cuisine}');
        buffer.writeln('**Difficulty:** ${matchedRecipe.difficulty} • **Prep Time:** ${matchedRecipe.prepTimeMinutes} mins • **Cook Time:** ${matchedRecipe.cookTimeMinutes} mins\n');
        
        buffer.writeln('**Ingredients:**');
        for (final ing in matchedRecipe.ingredients) {
          buffer.writeln('- ${ing.name}: ${ing.baseAmount.toStringAsFixed(ing.baseAmount % 1 == 0 ? 0 : 1)} ${ing.unit}');
        }
        buffer.writeln('\n**Instructions:**');
        for (int i = 0; i < matchedRecipe.instructions.length; i++) {
          buffer.writeln('${i + 1}. ${matchedRecipe.instructions[i]}');
        }
        textResponse = buffer.toString();
      } else {
        textResponse = 'Recipe details are not available yet.';
      }
      suggestedFoods = null;
    } else if (isGroceryQuery) {
      // Parse grocery section from context
      final String grocerySection;
      if (systemContext.contains('=== FITFUEL SMART GROCERY CONTEXT ===')) {
        final startIndex = systemContext.indexOf('=== FITFUEL SMART GROCERY CONTEXT ===');
        final endIndex = systemContext.indexOf('=== END CONTEXT ===', startIndex);
        grocerySection = systemContext.substring(startIndex, endIndex == -1 ? systemContext.length : endIndex);
      } else if (systemContext.contains('=== GROCERY & PANTRY ===')) {
        final startIndex = systemContext.indexOf('=== GROCERY & PANTRY ===');
        final endIndex = systemContext.indexOf('=== END CONTEXT ===', startIndex);
        grocerySection = systemContext.substring(startIndex, endIndex == -1 ? systemContext.length : endIndex);
      } else {
        grocerySection = '';
      }

      final List<String> remainingItems = [];
      final List<String> purchasedItems = [];
      final List<String> pantry = [];
      bool parsingRemaining = false;
      bool parsingPurchased = false;
      bool parsingPantry = false;

      for (final line in grocerySection.split('\n')) {
        if (line.contains('- Grocery Items Remaining:')) {
          parsingRemaining = true;
          parsingPurchased = false;
          parsingPantry = false;
          continue;
        }
        if (line.contains('- Grocery Items Purchased:')) {
          parsingRemaining = false;
          parsingPurchased = true;
          parsingPantry = false;
          continue;
        }
        if (line.contains('- Pantry Items:')) {
          parsingRemaining = false;
          parsingPurchased = false;
          parsingPantry = true;
          continue;
        }
        if (line.contains('- Dietary Preferences:') || line.contains('- Food Exclusions:')) {
          parsingRemaining = false;
          parsingPurchased = false;
          parsingPantry = false;
        }

        final trimmed = line.trim();
        if (trimmed.startsWith('*')) {
          final itemText = trimmed.substring(1).trim();
          if (parsingRemaining) remainingItems.add(itemText);
          if (parsingPurchased) purchasedItems.add(itemText);
          if (parsingPantry) pantry.add(itemText);
        }
      }

      if (pLower.contains('expiring') || pLower.contains('expired') || pLower.contains('running out')) {
        final expiring = pantry.where((item) => item.contains('Expiring Soon') || item.contains('Expired')).toList();
        if (expiring.isEmpty) {
          textResponse = 'Great news! You have no expired or expiring-soon foods in your pantry right now.';
        } else {
          textResponse = 'Here are the expiring/expired foods in your pantry:\n${expiring.map((i) => '• $i').join('\n')}\n\nTry to utilize these in your upcoming meals!';
        }
      } else if (pLower.contains('pantry') || pLower.contains('already have') || pLower.contains('what do i have') || pLower.contains('do i have')) {
        if (pantry.isEmpty) {
          textResponse = 'Your pantry is currently empty. You can record your kitchen stocks in the Pantry tab of the Grocery screen.';
        } else {
          final matchingFoods = <String>[];
          for (final item in pantry) {
            final itemName = item.split(':').first.toLowerCase().trim();
            for (final food in PredefinedFoodData.foods) {
              if (food.name.toLowerCase().contains(itemName)) {
                matchingFoods.add(food.name);
              }
            }
          }
          final buffer = StringBuffer();
          buffer.writeln('Here is what you currently have in your pantry:');
          for (final i in pantry) {
            buffer.writeln('• $i');
          }
          buffer.writeln('\nHere are some healthy meals you can prepare using these ingredients:');
          if (matchingFoods.isNotEmpty) {
            for (final f in matchingFoods.toSet().take(3)) {
              buffer.writeln('- **$f** (uses pantry ingredients)');
            }
          } else {
            buffer.writeln('- **Idli** (uses rice/lentils batter)');
            buffer.writeln('- **Plain Dosa** (uses rice/lentils batter)');
            buffer.writeln('- **Dal Tadka** (uses lentils)');
          }
          textResponse = buffer.toString();
        }
      } else {
        if (remainingItems.isEmpty) {
          textResponse = "Your shopping list is all complete! You've purchased everything needed for your active meal plan.";
        } else {
          textResponse = 'Here are the remaining items on your shopping list:\n${remainingItems.map((i) => '• $i').join('\n')}\n\nYou can mark these off directly in the Smart Grocery screen.';
        }
      }
      suggestedFoods = null;
    } else if (isSubstitutionQuery) {
      String targetFood = 'chicken';
      if (pLower.contains('chicken')) {
        targetFood = 'chicken';
      } else if (pLower.contains('egg')) {
        targetFood = 'eggs';
      } else if (pLower.contains('milk')) {
        targetFood = 'milk';
      } else if (pLower.contains('rice')) {
        targetFood = 'rice';
      } else if (pLower.contains('paneer')) {
        targetFood = 'paneer';
      }

      final String isVeg = systemContext.contains('Dietary Preferences: Vegetarian') ? 'Vegetarian' : 'Any';

      if (targetFood == 'chicken') {
        if (isVeg == 'Vegetarian') {
          textResponse = 'Since you prefer vegetarian foods, a great high-protein alternative to chicken is Paneer or Tofu. 100g of Tofu gives you 8g of protein, and 100g of Paneer gives you 18g of protein.';
        } else {
          textResponse = "If you don't have chicken, you can substitute it with fish (salmon/tuna) or eggs. For vegetarian alternatives, Paneer or Greek Yogurt are excellent high-protein substitutes.";
        }
      } else if (targetFood == 'eggs') {
        textResponse = 'Instead of eggs, you can use Greek yogurt, paneer, or tofu for protein, or chia seeds/flaxseeds as a baking binder fallback.';
      } else if (targetFood == 'milk') {
        textResponse = "A great alternative to cow's milk is Almond Milk, Soy Milk, or Oat Milk. Soy milk provides a similar protein content (about 3g per 100ml).";
      } else {
        textResponse = 'For $targetFood, you can use similar foods in the same category (e.g. oats instead of rice, or almonds instead of walnuts). This will keep your macros well aligned.';
      }
      suggestedFoods = null;
    } else if (isGiveMealPlan) {
      final buffer = StringBuffer();
      try {
        final lines = systemContext.split('\n');
        bool inMealPlan = false;
        for (final line in lines) {
          if (line.contains("Today's Active Meal Plan:")) {
            inMealPlan = true;
            buffer.writeln('Here is your active meal plan for today:\n');
            continue;
          }
          if (inMealPlan) {
            if (line.contains('=== END MEAL PLAN CONTEXT ===') || line.startsWith('===')) {
              break;
            }
            buffer.writeln(line.trim());
          }
        }
      } catch (_) {}
      
      if (buffer.isEmpty) {
        textResponse = "You don't have an active meal plan generated for today yet. You can generate one on the Meal Planner screen.";
      } else {
        textResponse = buffer.toString();
      }
      suggestedFoods = null;
    } else if (isSwapIntent) {
      String targetMeal = 'Lunch';
      if (pLower.contains('breakfast')) {
        targetMeal = 'Breakfast';
      } else if (pLower.contains('dinner')) {
        targetMeal = 'Dinner';
      } else if (pLower.contains('snack')) {
        targetMeal = 'Snacks';
      }

      final List<FoodEntity> foods = [];
      try {
        final lines = systemContext.split('\n');
        for (final line in lines) {
          if (line.startsWith('- Food: ')) {
            final parts = line.substring(8).split(' | ');
            final name = parts[0];
            final category = parts[1].split(': ')[1];
            final servingParts = parts[2].split(': ')[1].split(' ');
            final servingSize = double.tryParse(servingParts[0]) ?? 100.0;
            final servingUnit = servingParts[1];
            final calories = double.tryParse(parts[3].split(': ')[1].replaceAll(' kcal', '')) ?? 0.0;
            final protein = double.tryParse(parts[4].split(': ')[1].replaceAll('g', '')) ?? 0.0;
            final carbs = double.tryParse(parts[5].split(': ')[1].replaceAll('g', '')) ?? 0.0;
            final fats = double.tryParse(parts[6].split(': ')[1].replaceAll('g', '')) ?? 0.0;
            final fiber = double.tryParse(parts[7].split(': ')[1].replaceAll('g', '')) ?? 0.0;
            final sugar = double.tryParse(parts[8].split(': ')[1].replaceAll('g', '')) ?? 0.0;
            final sodium = double.tryParse(parts[9].split(': ')[1].replaceAll('mg', '')) ?? 0.0;
            final id = parts[10].split(': ')[1];
            
            foods.add(FoodEntity(
              id: id,
              name: name,
              category: category,
              servingSize: servingSize,
              servingUnit: servingUnit,
              calories: calories,
              protein: protein,
              carbohydrates: carbs,
              fats: fats,
              fiber: fiber,
              sugar: sugar,
              sodium: sodium,
            ));
          }
        }
      } catch (_) {}

      if (foods.isEmpty) {
        foods.addAll(PredefinedFoodData.foods.map((e) => e.toEntity()));
      }

      final alternatives = FoodRecommendationEngine.recommend(
        foods: foods,
        mealType: targetMeal,
        remainingCalories: 400.0,
        proteinDeficit: 20.0,
        dietaryPreference: dietaryPref,
        excludedFoodNames: excludedFoods.toList(),
        favoriteFoodIds: const [],
        recentFoodIds: const [],
      );

      final buffer = StringBuffer();
      buffer.writeln('Here are some swap alternatives for your $targetMeal:\n');
      for (int i = 0; i < alternatives.take(3).length; i++) {
        final f = alternatives[i];
        buffer.writeln('- **${f.name}** (${f.calories.toStringAsFixed(0)} kcal, P: ${f.protein.toStringAsFixed(1)}g)');
      }
      textResponse = buffer.toString();
      suggestedFoods = alternatives.take(3).map((f) => NutritionRecordEntity(
        id: f.id,
        foodName: f.name,
        mealType: targetMeal,
        calories: f.calories,
        protein: f.protein,
        carbohydrates: f.carbohydrates,
        fats: f.fats,
        sugar: f.sugar,
        servingSize: f.servingSize,
        consumedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )).toList();
    } else if (isGeneralConversation) {
      if (isGreeting) {
        textResponse = "Hi! 👋 I'm FitFuel AI. I can help you with nutrition, meals, hydration, exercise, habits, goals, and progress. What would you like to know?";
      } else if (isChat) {
        textResponse = "I'm doing great, thank you for asking! Ready to help you stay on track with your fitness goals today.";
      } else if (isAcknowledge) {
        textResponse = "You're very welcome! Let me know if there's anything else you need help with.";
      } else {
        textResponse = "I am FitFuel's AI Nutrition and Wellness Assistant. I can track today's water/exercise, evaluate your weekly health reports, personalize calorie goals, and offer healthy meal recommendations. How can I assist you?";
      }
      suggestedFoods = null;
    } else if (isRoutineQuery) {
      final double routineCompletion = extractVal('- Routine Completion:', '- Routine Completion:', '%');
      final String completedTasks = extractString('- Completed Tasks:');
      final String pendingTasks = extractString('- Pending Tasks:');
      final String nextReminder = extractString('- Next Reminder:');
      final String hydrationStatus = extractString('- Hydration Status:');
      final String mealStatus = extractString('- Meal Status:');
      final String exerciseStatus = extractString('- Exercise Status:');
      final String habitStatus = extractString('- Habit Status:');

      if (routineCompletion > 0.0 || completedTasks.isNotEmpty || pendingTasks.isNotEmpty) {
        textResponse = 'Here is your FitFuel routine progress for today:\n'
            '- Completion: ${routineCompletion.toStringAsFixed(0)}%\n'
            '- Completed: ${completedTasks.isEmpty ? "None yet" : completedTasks}\n'
            '- Pending: ${pendingTasks.isEmpty ? "All completed!" : pendingTasks}\n'
            '- Next Action: $nextReminder\n\n'
            'Status Alerts:\n'
            '- Hydration: $hydrationStatus\n'
            '- Meals: $mealStatus\n'
            '- Workout: $exerciseStatus\n'
            '- Habits: $habitStatus\n\n'
            'Keep working through your list to reach 100% completion!';
      } else {
        textResponse = 'I don\'t have daily routine details configured yet. You can enable reminders and customize times in the settings.';
      }
      suggestedFoods = null;
    } else if (isWeeklyCoaching) {
      if (isWeeklyOverview) {
        if (weeklyHealthScore.isNotEmpty) {
          textResponse = 'Here is your weekly summary:\n'
              '- Health Score: $weeklyHealthScore\n'
              '- Strongest Area: $strongestCategory\n'
              '- Weakest Area: $weakestCategory\n\n'
              'Insights:\n${weeklyInsights.split('; ').map((i) => '- $i').join('\n')}\n\n'
              'Next Week Plan:\n${nextWeekActionPlan.split('; ').map((a) => '- $a').join('\n')}';
        } else {
          textResponse = 'I don\'t have enough weekly report data yet. Keep logging your calories, hydration, and workouts to unlock weekly insights.';
        }
      } else if (isStrongestArea) {
        if (strongestCategory.isNotEmpty) {
          textResponse = 'Your strongest health area this week was **$strongestCategory**.';
        } else {
          textResponse = 'No strongest area calculated yet. Keep logging consistently.';
        }
      } else if (isWeakestArea) {
        if (weakestCategory.isNotEmpty) {
          textResponse = 'Your weakest health area this week was **$weakestCategory**.';
        } else {
          textResponse = 'No weakest area calculated yet. Keep logging consistently.';
        }
      } else if (isNextWeekImprovement) {
        if (nextWeekActionPlan.isNotEmpty) {
          textResponse = 'Based on your weakest category ($weakestCategory), here is your focus plan for next week:\n'
              '${nextWeekActionPlan.split('; ').map((a) => '- $a').join('\n')}';
        } else {
          textResponse = 'No actions planned yet. Complete more logs to get suggestions.';
        }
      } else if (isScoreChange) {
        if (weeklyHealthScore.isNotEmpty) {
          textResponse = 'Your Weekly Health Score is **$weeklyHealthScore** (Previous Week Score: **$previousWeekScore**).\n'
              'Overall Change: **$weeklyScoreChange**.\n\n'
              'To improve your score next week, focus on your weakest area: $weakestCategory.';
        } else {
          textResponse = 'No weekly score details available yet.';
        }
      } else if (isWeeklyNutrition) {
        if (calorieCons.isNotEmpty) {
          textResponse = 'Weekly Nutrition Report:\n'
              '- Calorie Consistency: $calorieCons\n'
              '- Protein Consistency: $proteinCons';
        } else {
          textResponse = 'No weekly nutrition logs recorded.';
        }
      } else if (isWeeklyHydration) {
        if (hydrationCons.isNotEmpty) {
          textResponse = 'Weekly Hydration Report:\n'
              '- Hydration Consistency: $hydrationCons';
        } else {
          textResponse = 'No hydration logs recorded.';
        }
      } else if (isWeeklyExercise) {
        if (exerciseCons.isNotEmpty) {
          textResponse = 'Weekly Exercise Report:\n'
              '- Exercise Consistency: $exerciseCons';
        } else {
          textResponse = 'No exercise logs recorded.';
        }
      } else if (isWeeklyHabits) {
        if (habitRate.isNotEmpty) {
          textResponse = 'Weekly Habits Report:\n'
              '- Habit Completion Rate: $habitRate';
        } else {
          textResponse = 'No habits logged this week.';
        }
      } else if (isWeeklyWellness) {
        if (wellnessTrendStr.isNotEmpty) {
          textResponse = 'Weekly Wellness Report:\n'
              '- Wellness Trend: $wellnessTrendStr';
        } else {
          textResponse = 'No wellness trends calculated yet.';
        }
      } else if (isWeeklyWeight) {
        if (weightTrackerStr.isNotEmpty) {
          textResponse = 'Weekly Weight Report:\n'
              '- Weight Change: $weightTrackerStr';
        } else {
          textResponse = 'No weight entries logged.';
        }
      } else if (isAchievements) {
        if (unlockedMilestonesStr.isNotEmpty) {
          textResponse = 'Achievements Unlocked this week:\n'
              '- Milestones: $unlockedMilestonesStr';
        } else {
          textResponse = 'No milestones unlocked this week.';
        }
      } else if (isStreak) {
        if (nutritionStreakStr.isNotEmpty) {
          textResponse = 'Weekly Streaks Report:\n'
              '- Streak details: $nutritionStreakStr';
        } else {
          textResponse = 'No streak logs recorded.';
        }
      }
      suggestedFoods = null;
    } else if (isHealthProfile) {
      final List<String> details = [];
      if (activityLvl.isNotEmpty) details.add('Activity Level: $activityLvl');
      if (fitnessGl.isNotEmpty) details.add('Fitness Goal: $fitnessGl');
      if (dietaryPref.isNotEmpty) details.add('Dietary Preference: $dietaryPref');
      
      final bool isComplete = activityLvl.isNotEmpty && fitnessGl.isNotEmpty && dietaryPref.isNotEmpty;
      if (details.isNotEmpty) {
        textResponse = 'Your current profile settings are:\n${details.map((d) => '- $d').join('\n')}';
        if (!isComplete) {
          textResponse += '\n\nNote: Your profile is missing some information. Please complete your Health Profile.';
        }
      } else {
        textResponse = 'Your profile is missing some information. Please complete your Health Profile.';
      }
      suggestedFoods = null;
    } else if (isWeightProgress) {
      final double startingW = extractVal('starting weight:', 'starting weight:', ' kg');
      final double currentW = extractVal('current weight:', 'current weight:', ' kg');
      final double changeW = extractVal('change:', 'change:', ' kg');

      if (startingW == 0.0 || currentW == 0.0) {
        textResponse = 'I don\'t have enough weight log entries in your progress history yet to analyze a trend. Try logging your weight regularly in the Progress tab so I can track your goals!';
      } else {
        final String direction = changeW < 0.0 ? 'down' : 'up';
        textResponse = 'Your weight history shows starting weight: **${startingW.toStringAsFixed(1)} kg** and current weight: **${currentW.toStringAsFixed(1)} kg**.\n'
            'Overall change is **${changeW.abs().toStringAsFixed(1)} kg** ($direction).\n\n'
            'Keep tracking regularly to see progress trends relative to your goal!';
      }
      suggestedFoods = null;
    } else if (isProgress) {
      final List<String> items = [];
      if (calorieCons.isNotEmpty) items.add('Calorie Consistency: $calorieCons');
      if (proteinCons.isNotEmpty) items.add('Protein Consistency: $proteinCons');
      if (hydrationCons.isNotEmpty) items.add('Hydration Consistency: $hydrationCons');
      if (exerciseCons.isNotEmpty) items.add('Exercise Consistency: $exerciseCons');
      if (habitRate.isNotEmpty) items.add('Habits Completion Rate: $habitRate');
      if (wellnessTrendStr.isNotEmpty) items.add('Wellness Trend: $wellnessTrendStr');
      if (weightTrackerStr.isNotEmpty) items.add('Weight Progress: $weightTrackerStr');
      if (nutritionStreakStr.isNotEmpty) items.add('Streak: $nutritionStreakStr');
      if (unlockedMilestonesStr.isNotEmpty) items.add('Achievements Unlocked: $unlockedMilestonesStr');

      if (items.isNotEmpty) {
        textResponse = 'Here is your long-term progress summary:\n${items.map((i) => '- $i').join('\n')}\n\nKeep focusing on consistency across calories and hydration to build sustained success.';
      } else {
        textResponse = 'No progress history could be parsed from context. Please log activities and weight regularly.';
      }
      suggestedFoods = null;
    } else if (isCoaching) {
      if (!systemContext.contains('=== FITFUEL SMART INSIGHTS CONTEXT ===')) {
        final double waterIntake = extractVal('- Water Intake:', '- Water Intake:', ' ml /');
        final double waterTarget = extractVal('- Water Intake:', ' ml /', ' ml');
        final int exerciseMins = extractVal('- Workout Duration:', '- Workout Duration:', ' minutes').toInt();
        final int habitsCompleted = extractVal('- Habits Completed:', '- Habits Completed:', ' /').toInt();
        final int habitsTotal = extractVal('- Habits Completed:', ' /', '').toInt();

        final List<String> priorities = [];
        if (remainingPro > goalPro * 0.4 && remainingCals > 200) {
          priorities.add('**Protein intake is high priority**: You still have ${remainingPro.toStringAsFixed(1)}g of protein remaining. Try adding protein-rich options like paneer, Greek yogurt, or eggs based on your preference.');
        }
        if (waterTarget - waterIntake > 500) {
          priorities.add('**Hydration is priority**: You have ${((waterTarget - waterIntake)).toStringAsFixed(0)} ml left to reach your daily target. Keep a water bottle nearby and sip regularly.');
        }
        if (exerciseMins == 0) {
          priorities.add('**Exercise is priority**: You haven\'t logged any exercise today. Try to fit in a quick 20-30 minute active walk or home workout.');
        }
        if (habitsCompleted < habitsTotal) {
          priorities.add('**Habits checklist**: You have ${habitsTotal - habitsCompleted} habits remaining to check off today.');
        }

        if (priorities.isNotEmpty) {
          textResponse = 'Here is what you should focus on to finish today\'s goals strong:\n\n${priorities.join('\n\n')}';
        } else {
          textResponse = 'Awesome job today! You have successfully met your key wellness targets. Maintain this consistency!';
        }
        suggestedFoods = null;
      } else {
        String extractDailyFocus() {
          try {
            final lines = systemContext.split('\n');
            final line = lines.firstWhere((l) => l.contains('- Daily Focus:'));
            return line.substring(line.indexOf(':') + 1).trim();
          } catch (_) {
            return '';
          }
        }

        List<String> extractActiveInsights() {
          final List<String> list = [];
          try {
            final lines = systemContext.split('\n');
            int startIndex = lines.indexWhere((l) => l.contains('=== FITFUEL SMART INSIGHTS CONTEXT ==='));
            if (startIndex == -1) return list;
            int endIndex = lines.indexWhere((l) => l.contains('=== END CONTEXT ==='), startIndex);
            if (endIndex == -1) endIndex = lines.length;

            for (int i = startIndex + 1; i < endIndex; i++) {
              final line = lines[i].trim();
              if (line.startsWith('*')) {
                list.add(line.substring(1).trim());
              }
            }
          } catch (_) {}
          return list;
        }

        final focus = extractDailyFocus();
        final insightsList = extractActiveInsights();

        final List<String> priorities = [];
        if (focus.isNotEmpty) {
          priorities.add('**Daily Focus**: $focus');
        }
        for (final insight in insightsList) {
          if (!insight.contains('[POSITIVE]')) {
            priorities.add(insight);
          }
        }

        if (priorities.isNotEmpty) {
          textResponse = 'Here is what you should focus on today based on your smart health telemetry:\n\n${priorities.map((p) => '- $p').join('\n')}';
        } else {
          textResponse = 'Outstanding! Your nutrition, hydration, workouts, and habits are all completely on track today. Keep up the perfect momentum!';
        }
        suggestedFoods = null;
      }
    } else if (isDoingWell) {
      List<String> extractActiveInsights() {
        final List<String> list = [];
        try {
          final lines = systemContext.split('\n');
          int startIndex = lines.indexWhere((l) => l.contains('=== FITFUEL SMART INSIGHTS CONTEXT ==='));
          if (startIndex == -1) return list;
          int endIndex = lines.indexWhere((l) => l.contains('=== END CONTEXT ==='), startIndex);
          if (endIndex == -1) endIndex = lines.length;

          for (int i = startIndex + 1; i < endIndex; i++) {
            final line = lines[i].trim();
            if (line.startsWith('*')) {
              list.add(line.substring(1).trim());
            }
          }
        } catch (_) {}
        return list;
      }

      final insightsList = extractActiveInsights();
      final List<String> positives = [];
      for (final insight in insightsList) {
        if (insight.contains('[POSITIVE]') || insight.toLowerCase().contains('great') || insight.toLowerCase().contains('excellent') || insight.toLowerCase().contains('perfect') || insight.toLowerCase().contains('achieved')) {
          positives.add(insight);
        }
      }

      if (positives.isNotEmpty) {
        textResponse = 'Here is what you are doing great today:\n\n${positives.map((p) => '- $p').join('\n')}\n\nKeep maintaining this fantastic progress!';
      } else {
        textResponse = 'You are doing great just by logging and staying consistent with your health goals. Keep logging your food, water, and exercise to generate positive highlights!';
      }
      suggestedFoods = null;
    } else if (isMotivation) {
      textResponse = "I completely understand that motivation can fluctuate. Missing goals or skipping a workout is a normal part of the journey. What matters most is consistency over time. Let's aim to complete a small, easy habit today—like drinking a glass of water or stretching for 5 minutes—to rebuild momentum!";
      suggestedFoods = null;
    } else if (isAchievementCoaching) {
      textResponse = 'You are doing great! Your current streak is $nutritionStreakStr. Let\'s aim to unlock the next milestone: \'Streak Master\' by keeping up your tracking for a few more days.';
      suggestedFoods = null;
    } else if (isDailyPlan) {
      textResponse = 'Here is your structured action plan:\n\n'
          '**Morning**\n'
          '- Breakfast: Suggestion based on preference (Paneer/Greek Yogurt or Oats)\n'
          '- Water target: Drink 500 ml\n'
          '- Habit: Morning stretch\n\n'
          '**Afternoon**\n'
          '- Lunch: Healthy meal suggestion\n'
          '- Hydration: Sip 1000 ml\n'
          '- Activity: Brief walk after eating\n\n'
          '**Evening**\n'
          '- Exercise: 30 minutes of physical activity\n'
          '- Dinner: High-protein balanced dinner\n'
          '- Remaining hydration: Finish remaining target ml\n\n'
          '**Night**\n'
          '- Habit completion: Mark habits checked\n'
          '- Daily summary: Log final food records';
      suggestedFoods = null;
    } else if (isGoalCoaching) {
      final String goalStr = fitnessGl.toLowerCase();
      if (goalStr.contains('muscle') || goalStr.contains('gain')) {
        textResponse = 'Your fitness goal is **Gain Muscle**. Focus on:\n'
            '- Prioritizing adequate protein intake (target: ${goalPro.toStringAsFixed(0)} g).\n'
            '- Incorporating progressive resistance strength training.\n'
            '- Ensuring sufficient calorie intake to support muscle synthesis.\n'
            '- Prioritizing sleep and muscle recovery.';
      } else if (goalStr.contains('weight') || goalStr.contains('lose')) {
        textResponse = 'Your fitness goal is **Lose Weight**. Focus on:\n'
            '- Prioritizing sustainable calorie adherence (target: ${goalCals.toStringAsFixed(0)} kcal).\n'
            '- Hitting protein targets to preserve lean muscle tissue.\n'
            '- Maintaining daily physical activity to boost energy expenditure.\n'
            '- Tracking consistently to maintain awareness of portions.';
      } else {
        textResponse = 'Your fitness goal is **Maintain Weight**. Focus on:\n'
            '- Balancing calorie intake close to your calculated targets.\n'
            '- Consistently logging nutrition, hydration, and daily habits.\n'
            '- Maintaining moderate active days throughout the week.';
      }
      suggestedFoods = null;
    } else if (isMealPlan) {
      // 1. Try to use Smart Eat Context recommendations if available
      String? currentMeal;
      String? parsedRemainingCal;
      String? parsedRemainingPro;
      String? topRecommendation;
      String? matchScore;
      double topCalories = 0.0;
      double topProtein = 0.0;
      double topCarbs = 0.0;
      double topFats = 0.0;
      final List<String> alternatives = [];

      try {
        final lines = systemContext.split('\n');
        bool inSmartEat = false;
        String? currentLineFoodName;
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.contains('=== FITFUEL SMART EAT FOOD CONTEXT ===') || line.contains('=== FITFUEL SMART EAT CONTEXT ===')) {
            inSmartEat = true;
            continue;
          }
          if (inSmartEat) {
            if (line.contains('=== END')) {
              inSmartEat = false;
              break;
            }
            if (line.startsWith('Current meal:') || line.startsWith('- Current meal:')) {
              currentMeal = line.split(':').last.trim();
            } else if (line.startsWith('Remaining calories:') || line.startsWith('- Remaining calories:')) {
              parsedRemainingCal = line.split(':').last.trim();
            } else if (line.startsWith('Remaining protein:') || line.startsWith('- Remaining protein:')) {
              parsedRemainingPro = line.split(':').last.trim();
            } else if (line.startsWith('Top recommendation:') || line.startsWith('- Top recommendation:')) {
              topRecommendation = line.split(':').last.trim();
              currentLineFoodName = topRecommendation;
            } else if (line.startsWith('Calories:') || line.startsWith('calories:') || line.startsWith('* Calories:') || line.startsWith('  * Calories:')) {
              final val = double.tryParse(line.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
              if (currentLineFoodName == topRecommendation) topCalories = val;
            } else if (line.startsWith('Protein:') || line.startsWith('protein:') || line.startsWith('* Protein:') || line.startsWith('  * Protein:')) {
              final val = double.tryParse(line.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
              if (currentLineFoodName == topRecommendation) topProtein = val;
            } else if (line.startsWith('Carbs:') || line.startsWith('carbs:') || line.startsWith('* Carbs:') || line.startsWith('  * Carbs:')) {
              final val = double.tryParse(line.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
              if (currentLineFoodName == topRecommendation) topCarbs = val;
            } else if (line.startsWith('Fats:') || line.startsWith('fats:') || line.startsWith('fat:') || line.startsWith('* Fats:') || line.startsWith('  * Fats:')) {
              final val = double.tryParse(line.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
              if (currentLineFoodName == topRecommendation) topFats = val;
            } else if (line.startsWith('Match Score:') || line.startsWith('* Match Score:') || line.startsWith('  * Match Score:')) {
              matchScore = line.split(':').last.trim();
            } else if (RegExp(r'^\d+\.').hasMatch(line)) {
              final foodName = line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
              if (topRecommendation == null) {
                topRecommendation = foodName;
                currentLineFoodName = foodName;
              } else {
                alternatives.add(foodName);
                currentLineFoodName = foodName;
              }
            } else if (line.startsWith('* ') || line.startsWith('  * ')) {
              final clean = line.replaceFirst(RegExp(r'^\s*\*?\s*'), '').trim();
              if (!clean.contains('Calories') && !clean.contains('Protein') && !clean.contains('Carbs') && !clean.contains('Fats') && !clean.contains('Match Score')) {
                alternatives.add(clean);
              }
            }
          }
        }
      } catch (_) {}

      if (topRecommendation != null && topRecommendation != 'None' && topRecommendation.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('Based on your FitFuel Smart Eat analysis, here is what you should eat right now:\n');
        buffer.writeln('**Top Recommendation: $topRecommendation ($matchScore)**');
        buffer.writeln('- Meal Slot: $currentMeal');
        buffer.writeln('- Today\'s Remaining Calories: $parsedRemainingCal kcal');
        buffer.writeln('- Today\'s Remaining Protein: $parsedRemainingPro g\n');
        buffer.writeln('Macros for this choice:');
        buffer.writeln('- Calories: ${topCalories.toStringAsFixed(0)} kcal');
        buffer.writeln('- Protein: ${topProtein.toStringAsFixed(1)} g');
        buffer.writeln('- Carbs: ${topCarbs.toStringAsFixed(1)} g');
        buffer.writeln('- Fats: ${topFats.toStringAsFixed(1)} g\n');

        if (alternatives.isNotEmpty) {
          buffer.writeln('**Alternative Options:**');
          for (final alt in alternatives) {
            buffer.writeln('- $alt');
          }
          buffer.writeln('');
        }

        buffer.writeln('You can view details or log these recommendations directly below.');
        textResponse = buffer.toString();

        final List<NutritionRecordEntity> suggested = [];
        suggested.add(NutritionRecordEntity(
          id: 'smart_top',
          foodName: topRecommendation,
          mealType: currentMeal ?? 'Lunch',
          calories: topCalories,
          protein: topProtein,
          carbohydrates: topCarbs,
          fats: topFats,
          sugar: 0.0,
          servingSize: 150.0,
          consumedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        for (int i = 0; i < alternatives.length; i++) {
          final altName = alternatives[i].split(' (').first;
          suggested.add(NutritionRecordEntity(
            id: 'smart_alt_$i',
            foodName: altName,
            mealType: currentMeal ?? 'Lunch',
            calories: topCalories * 0.9,
            protein: topProtein * 0.9,
            carbohydrates: topCarbs * 0.9,
            fats: topFats * 0.9,
            sugar: 0.0,
            servingSize: 150.0,
            consumedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
        suggestedFoods = suggested;
      } else {
        final List<FoodEntity> foods = [];
        try {
          final lines = systemContext.split('\n');
          for (final line in lines) {
            if (line.startsWith('- Food: ')) {
              final parts = line.substring(8).split(' | ');
              final name = parts[0];
              final category = parts[1].split(': ')[1];
              final servingParts = parts[2].split(': ')[1].split(' ');
              final servingSize = double.tryParse(servingParts[0]) ?? 100.0;
              final servingUnit = servingParts[1];
              final calories = double.tryParse(parts[3].split(': ')[1].replaceAll(' kcal', '')) ?? 0.0;
              final protein = double.tryParse(parts[4].split(': ')[1].replaceAll('g', '')) ?? 0.0;
              final carbs = double.tryParse(parts[5].split(': ')[1].replaceAll('g', '')) ?? 0.0;
              final fats = double.tryParse(parts[6].split(': ')[1].replaceAll('g', '')) ?? 0.0;
              final fiber = double.tryParse(parts[7].split(': ')[1].replaceAll('g', '')) ?? 0.0;
              final sugar = double.tryParse(parts[8].split(': ')[1].replaceAll('g', '')) ?? 0.0;
              final sodium = double.tryParse(parts[9].split(': ')[1].replaceAll('mg', '')) ?? 0.0;
              final id = parts[10].split(': ')[1];
              final isFavorite = parts[11].split(': ')[1] == 'true';

              foods.add(FoodEntity(
                id: id,
                name: name,
                category: category,
                servingSize: servingSize,
                servingUnit: servingUnit,
                calories: calories,
                protein: protein,
                carbohydrates: carbs,
                fats: fats,
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                isFavorite: isFavorite,
              ));
            }
          }
        } catch (_) {}

        if (foods.isEmpty) {
          foods.addAll(PredefinedFoodData.foods.map((e) => e.toEntity()));
        }

        String mealType = 'Lunch';
        if (pLower.contains('breakfast')) {
          mealType = 'Breakfast';
        } else if (pLower.contains('lunch')) {
          mealType = 'Lunch';
        } else if (pLower.contains('dinner')) {
          mealType = 'Dinner';
        } else if (pLower.contains('snack')) {
          mealType = 'Snacks';
        }

        double finalRemainingPro = remainingPro;
        if (pLower.contains('high protein') || pLower.contains('protein')) {
          finalRemainingPro = finalRemainingPro > 0 ? finalRemainingPro : 50.0;
        }

        final List<String> excludedList = excludedFoods.toList();
        var recommendations = FoodRecommendationEngine.recommend(
          foods: foods,
          mealType: mealType,
          remainingCalories: remainingCals,
          proteinDeficit: finalRemainingPro,
          dietaryPreference: dietaryPref,
          excludedFoodNames: excludedList,
          favoriteFoodIds: const [],
          recentFoodIds: const [],
        );

        // Filter out previously recommended foods if it doesn't leave the list empty
        final filteredRecs = recommendations.where((f) => !previouslyRecommended.contains(f.name.toLowerCase())).toList();
        if (filteredRecs.isNotEmpty) {
          recommendations = filteredRecs;
        }

        if (recommendations.isNotEmpty) {
          final topFoods = recommendations.take(3).toList();
          final buffer = StringBuffer();
          buffer.writeln('Here are some smart choices matching your request:\n');

          for (int i = 0; i < topFoods.length; i++) {
            final f = topFoods[i];
            buffer.writeln('**Option ${i + 1}: ${f.name}**');
            buffer.writeln('Serving: ${f.servingSize.toStringAsFixed(0)} ${f.servingUnit}');
            buffer.writeln('- Calories: ${f.calories.toStringAsFixed(0)} kcal');
            buffer.writeln('- Protein: ${f.protein.toStringAsFixed(1)} g');
            buffer.writeln('- Carbs: ${f.carbohydrates.toStringAsFixed(1)} g');
            buffer.writeln('- Fats: ${f.fats.toStringAsFixed(1)} g\n');
          }

          buffer.writeln('You can view details or log these recommendations directly below.');
          textResponse = buffer.toString();

          suggestedFoods = topFoods.map((f) => NutritionRecordEntity(
            id: f.id,
            foodName: f.name,
            mealType: mealType,
            calories: f.calories,
            protein: f.protein,
            carbohydrates: f.carbohydrates,
            fats: f.fats,
            sugar: f.sugar,
            servingSize: f.servingSize,
            consumedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )).toList();
        } else {
          textResponse = 'I could not find any suitable foods in the database matching your constraints.';
          suggestedFoods = null;
        }
      }
    } else if (isHydrationCoaching) {
      final double waterIntake = extractVal('- Water Intake:', '- Water Intake:', ' ml /');
      final double waterTarget = extractVal('- Water Intake:', ' ml /', ' ml');
      final remaining = (waterTarget - waterIntake).clamp(0.0, double.infinity);

      if (remaining > 0) {
        textResponse = 'You have consumed ${waterIntake.toStringAsFixed(0)} ml of water today out of your target of ${waterTarget.toStringAsFixed(0)} ml. '
            'You need to drink ${remaining.toStringAsFixed(0)} ml more to meet your target. Try setting hourly reminders to sip water.';
      } else {
        textResponse = 'Excellent! You have fully achieved today\'s hydration target of ${waterTarget.toStringAsFixed(0)} ml by drinking ${waterIntake.toStringAsFixed(0)} ml.';
      }
      suggestedFoods = null;
    } else if (isExerciseCoaching) {
      final int exerciseMins = extractVal('- Workout Duration:', '- Workout Duration:', ' minutes').toInt();
      final double exerciseCals = extractVal('- Workout Calories Burned:', '- Workout Calories Burned:', ' kcal');

      textResponse = 'Today you logged $exerciseMins minutes of physical activity and burned ${exerciseCals.toStringAsFixed(0)} kcal. '
          'Aiming for at least 30 minutes of exercise per day is highly recommended to build consistency and keep you moving.';
      suggestedFoods = null;
    } else if (isHabitCoaching) {
      final int habitsCompleted = extractVal('- Habits Completed:', '- Habits Completed:', ' /').toInt();
      final int habitsTotal = extractVal('- Habits Completed:', ' /', '').toInt();

      textResponse = 'You have completed $habitsCompleted out of $habitsTotal daily checklist habits today. '
          'Habit consistency reinforces long-term wellness routines. Keep checking them off as you complete them!';
      suggestedFoods = null;
    } else if (isWellness) {
      final double wellnessScore = extractVal('- Wellness Score:', '- Wellness Score:', ' / 100');

      textResponse = 'Your Wellness Score today is ${wellnessScore.toStringAsFixed(0)}/100. '
          'This ranks your overall logging compliance, hydration intake, workout routine, and daily habit metrics.';
      suggestedFoods = null;
    } else if (isNutritionAnalysis) {
      final double targetCals = extractVal('Calories Target:', 'Calories Target:', ' kcal');
      final double targetPro = extractVal('Protein Target:', 'Protein Target:', ' g');

      if (pLower.contains('remaining') || pLower.contains('left')) {
        textResponse = 'Here are your remaining targets for today:\n'
            '- Calories: ${remainingCals.toStringAsFixed(0)} kcal\n'
            '- Protein: ${remainingPro.toStringAsFixed(1)} g\n'
            '- Carbohydrates: ${remainingCarbs.toStringAsFixed(1)} g\n'
            '- Fats: ${remainingFats.toStringAsFixed(1)} g\n\n'
            'Keep choices lean if you are close to fat limits. Please note that values are approximate.';
      } else {
        textResponse = 'Based on your calculated targets, your daily targets are:\n'
            '- Calories: ${targetCals.toStringAsFixed(0)} kcal\n'
            '- Protein: ${targetPro.toStringAsFixed(0)} g\n\n'
            'Ensure you adjust your daily intake to meet these targets.';
      }
      suggestedFoods = null;
    } else if (isFoodLogging) {
      final double loggedCals = extractVal('- Calories Consumed:', '- Calories Consumed:', ' kcal');
      textResponse = 'You have logged ${loggedCals.toStringAsFixed(0)} kcal of food today. Use the dashboard to see details or add more meals.';
      suggestedFoods = null;
    } else if (isAnalyticsQuery) {
      if (pLower.contains('weakest') || pLower.contains('focus')) {
        textResponse = 'Your weakest category is **$analyticsWeakest**. Recommendation: Try logging water immediately after each meal.';
      } else if (pLower.contains('strongest')) {
        textResponse = 'Your strongest category is **$analyticsStrongest** with **$analyticsExercise** consistency!';
      } else if (pLower.contains('weight')) {
        textResponse = 'Your weight trend is **$analyticsWeightTrend**. Keep monitoring it relative to your fitness goal of $fitnessGl.';
      } else if (pLower.contains('compare') || pLower.contains('comparison')) {
        textResponse = 'Comparing this period with the previous period: $analyticsComparison.';
      } else if (pLower.contains('improved') || pLower.contains('declined')) {
        textResponse = 'Comparing your progress, your wellness score trend is **$analyticsWellnessTrend** and your weight trend is **$analyticsWeightTrend**.';
      } else if (pLower.contains('hydration') || pLower.contains('water')) {
        textResponse = 'Your hydration target adherence is **$analyticsHydration** over the selected range. Focus on logging water regularly!';
      } else if (pLower.contains('nutrition') || pLower.contains('calorie') || pLower.contains('protein')) {
        textResponse = 'Your nutrition target adherence is **$analyticsNutrition**.';
      } else {
        textResponse = 'Over the last 30 days, your overall health consistency is **$analyticsConsistency**. Your strongest category is **$analyticsStrongest** and your weakest category is **$analyticsWeakest**.';
      }
      suggestedFoods = null;
    } else if (isGeneralNutrition) {
      if (pLower.contains('calorie')) {
        textResponse = 'A calorie is a unit of energy. It measures the amount of energy food provides to your body. To manage weight, focus on matching your daily calorie intake to your calculated targets.';
      } else if (pLower.contains('protein')) {
        textResponse = 'Protein is a crucial macronutrient used to build, repair, and maintain tissues in the body. Aim for lean sources such as Greek yogurt, dal, paneer, and eggs.';
      } else {
        textResponse = 'Hydration is essential for nutrient transport, temperature regulation, and overall organ function. FitFuel recommends keeping a water bottle nearby and drinking at least 2500 ml daily.';
      }
      suggestedFoods = null;
    } else {
      textResponse = 'I\'m here to help with your nutrition, hydration, exercise, habits, meals, goals, and progress. What would you like to know?';
      suggestedFoods = null;
    }

    // Safety checks / Guidelines disclaimer additions
    textResponse += '\n\n*Disclaimer: Advice provided is approximate. Encourage professional medical advice for specific conditions.*';

    return ChatMessage(
      text: textResponse,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      suggestedFoods: suggestedFoods,
    );
  }

  double _extractValueForLine(String context, String lineContains, String prefix, String suffix) {
    try {
      final lines = context.split('\n');
      final targetLine = lines.firstWhere((l) => l.contains(lineContains));
      final startIndex = targetLine.indexOf(prefix);
      if (startIndex == -1) return 0.0;
      final valueStart = startIndex + prefix.length;
      final endIndex = targetLine.indexOf(suffix, valueStart);
      if (endIndex == -1) return 0.0;
      final substring = targetLine.substring(valueStart, endIndex).trim();
      return double.tryParse(substring.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
