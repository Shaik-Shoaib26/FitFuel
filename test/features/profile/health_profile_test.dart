import 'package:fitfuel/core/utils/tdee_calculator.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart';
import 'package:fitfuel/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:fitfuel/features/ai_assistant/domain/utils/ai_context_generator.dart';
import 'package:fitfuel/features/profile/data/models/user_profile_model.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  group('TDEE & Goal Calculation Tests', () {
    test('Calculates BMR correctly using Mifflin-St Jeor Formula', () {
      final bmrMale = TDEECalculator.calculateBMR(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 25,
        gender: 'male',
      );
      expect(bmrMale, 1805.0);

      final bmrFemale = TDEECalculator.calculateBMR(
        weightKg: 60.0,
        heightCm: 165.0,
        age: 30,
        gender: 'female',
      );
      expect(bmrFemale, 1320.25);
    });

    test('Calculates TDEE based on activity levels multiplier changes', () {
      const bmr = 1500.0;
      
      final sedentary = TDEECalculator.calculateTDEE(bmr: bmr, activityLevel: 'sedentary');
      expect(sedentary, 1500.0 * 1.2);

      final lightlyActive = TDEECalculator.calculateTDEE(bmr: bmr, activityLevel: 'lightly_active');
      expect(lightlyActive, 1500.0 * 1.375);

      final moderatelyActive = TDEECalculator.calculateTDEE(bmr: bmr, activityLevel: 'moderately_active');
      expect(moderatelyActive, 1500.0 * 1.55);

      final veryActive = TDEECalculator.calculateTDEE(bmr: bmr, activityLevel: 'very_active');
      expect(veryActive, 1500.0 * 1.725);
    });

    test('Calculates Target Calories based on Fitness Goals', () {
      const tdee = 2500.0;

      final loseWeight = TDEECalculator.calculateCalorieTarget(tdee: tdee, goal: 'lose_weight');
      expect(loseWeight, 2000);

      final gainMuscle = TDEECalculator.calculateCalorieTarget(tdee: tdee, goal: 'gain_muscle');
      expect(gainMuscle, 2800);

      final maintain = TDEECalculator.calculateCalorieTarget(tdee: tdee, goal: 'maintain');
      expect(maintain, 2500);
    });

    test('Calculates Macro Distribution accurately', () {
      final macros = TDEECalculator.calculateMacroTargets(
        calorieTarget: 2000,
        weightKg: 70.0,
      );

      expect(macros['proteinGrams'], 140.0);
      expect(macros['fatGrams'], 55.6);
      expect(macros['carbsGrams'], 235.0);
    });
  });

  group('Profile Serialization and Deserialization', () {
    test('Converts UserProfileEntity correctly to/from UserProfileModel and Firestore formats', () {
      final entity = UserProfileEntity(
        uid: 'user_123',
        email: 'john@example.com',
        displayName: 'John Doe',
        age: 28,
        gender: 'male',
        height: 180.0,
        weight: 82.5,
        activityLevel: 'moderately_active',
        fitnessGoal: 'gain_muscle',
        dietaryPreference: 'vegan',
        createdAt: now,
        updatedAt: now,
      );

      final model = UserProfileModel.fromEntity(entity);
      expect(model.age, 28);
      expect(model.gender, 'male');
      expect(model.height, 180.0);
      expect(model.weight, 82.5);
      expect(model.activityLevel, 'moderately_active');
      expect(model.fitnessGoal, 'gain_muscle');
      expect(model.dietaryPreference, 'vegan');

      final map = model.toFirestore();
      expect(map['age'], 28);
      expect(map['gender'], 'male');
      expect(map['height'], 180.0);
      expect(map['weight'], 82.5);
      expect(map['activityLevel'], 'moderately_active');
      expect(map['fitnessGoal'], 'gain_muscle');
      expect(map['dietaryPreference'], 'vegan');
    });
  });

  group('AI Context Personalization & Intent Routing Tests', () {
    test('Different profiles produce different system contexts', () {
      final profileA = UserProfileEntity(
        uid: 'a',
        email: 'a@test.com',
        age: 25,
        gender: 'male',
        height: 180.0,
        weight: 80.0,
        activityLevel: 'sedentary',
        fitnessGoal: 'lose_weight',
        dietaryPreference: 'vegetarian',
        createdAt: now,
        updatedAt: now,
      );

      final profileB = UserProfileEntity(
        uid: 'b',
        email: 'b@test.com',
        age: 35,
        gender: 'female',
        height: 165.0,
        weight: 60.0,
        activityLevel: 'very_active',
        fitnessGoal: 'gain_muscle',
        dietaryPreference: 'anything',
        createdAt: now,
        updatedAt: now,
      );

      final contextA = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
        profile: profileA,
      );

      final contextB = AiContextGenerator.generateContext(
        todayRecords: [],
        historyRecords: [],
        goals: null,
        profile: profileB,
      );

      expect(contextA != contextB, isTrue);
      expect(contextA.contains('sedentary'), isTrue);
      expect(contextA.contains('lose_weight'), isTrue);
      expect(contextA.contains('vegetarian'), isTrue);

      expect(contextB.contains('very_active'), isTrue);
      expect(contextB.contains('gain_muscle'), isTrue);
      expect(contextB.contains('anything'), isTrue);
    });

    test('Mock AI datasource does not return fixed food suggestions for unrelated queries', () async {
      final mock = AiNutritionMockDatasource();
      
      const context = '''
USER HEALTH PROFILE:
- Activity Level: very_active
- Fitness Goal: gain_muscle
- Dietary Preference: vegetarian

USER GOALS:
- Calories Target: 2500 kcal
- Protein Target: 160 g
''';

      final replyGoal = await mock.generateResponse(
        userPrompt: 'What is my current activity level and fitness goal?',
        systemContext: context,
      );

      expect(replyGoal.suggestedFoods, isNull);
      expect(replyGoal.text.contains('very_active'), isTrue);
      expect(replyGoal.text.contains('gain_muscle'), isTrue);

      final replyTargets = await mock.generateResponse(
        userPrompt: 'Based on my current profile, what should my calorie and protein targets be today?',
        systemContext: context,
      );

      expect(replyTargets.suggestedFoods, isNull);
      expect(replyTargets.text.contains('2500'), isTrue);
      expect(replyTargets.text.contains('160'), isTrue);
    });

    test('Dietary preferences filter suggestions properly in mock datasource', () async {
      final mock = AiNutritionMockDatasource();
      
      const contextVeg = '''
USER HEALTH PROFILE:
- Dietary Preference: vegetarian
''';

      final replyVeg = await mock.generateResponse(
        userPrompt: 'Suggest a meal recommendation',
        systemContext: contextVeg,
      );

      expect(replyVeg.suggestedFoods, isNotNull);
      // Chicken must be excluded for vegetarian preferences
      expect(replyVeg.suggestedFoods!.first.foodName.toLowerCase().contains('chicken'), isFalse);
    });

    test('AI history + current profile context are both preserved', () async {
      final mock = AiNutritionMockDatasource();
      const context = '''
USER HEALTH PROFILE:
- Fitness Goal: gain_muscle
''';

      final reply = await mock.generateResponse(
        userPrompt: 'What is my goal?',
        systemContext: context,
        history: [
          ChatMessage(text: 'Hello assistant', sender: MessageSender.user, timestamp: now),
          ChatMessage(text: 'Hello, how can I help you?', sender: MessageSender.ai, timestamp: now),
        ],
      );

      expect(reply.text.contains('gain_muscle'), isTrue);
    });

    test('UserProfileEntity detects complete vs missing profile states correctly', () {
      final complete = UserProfileEntity(
        uid: '1',
        email: 'a@a.com',
        age: 25,
        gender: 'male',
        height: 180.0,
        weight: 80.0,
        activityLevel: 'sedentary',
        fitnessGoal: 'lose_weight',
        dietaryPreference: 'vegan',
        createdAt: now,
        updatedAt: now,
      );

      final incomplete = UserProfileEntity(
        uid: '2',
        email: 'b@b.com',
        createdAt: now,
        updatedAt: now,
      );

      expect(complete.isProfileComplete, isTrue);
      expect(incomplete.isProfileComplete, isFalse);
    });

    test('Mock AI datasource handles incomplete profile queries with missing info message', () async {
      final mock = AiNutritionMockDatasource();
      
      const context = '''
USER HEALTH PROFILE:
''';

      final reply = await mock.generateResponse(
        userPrompt: 'What is my current activity level, fitness goal, and dietary preference?',
        systemContext: context,
      );

      expect(reply.text.contains('Your profile is missing some information. Please complete your Health Profile.'), isTrue);
      expect(reply.text.contains('Please update your profile in the Dashboard.'), isFalse);
    });

    test('Mock AI datasource handles complete profile queries successfully', () async {
      final mock = AiNutritionMockDatasource();
      
      const context = '''
USER HEALTH PROFILE:
- Activity Level: very_active
- Fitness Goal: gain_muscle
- Dietary Preference: vegetarian
''';

      final reply = await mock.generateResponse(
        userPrompt: 'What is my current activity level, fitness goal, and dietary preference?',
        systemContext: context,
      );

      expect(reply.text.contains('very_active'), isTrue);
      expect(reply.text.contains('gain_muscle'), isTrue);
      expect(reply.text.contains('vegetarian'), isTrue);
      expect(reply.text.contains('Your profile is missing some information.'), isFalse);
    });
  });
}
