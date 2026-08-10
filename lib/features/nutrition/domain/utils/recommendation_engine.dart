import '../../domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';

class SuggestionFood {
  final String name;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double sugar;
  final double servingSize;

  const SuggestionFood({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.sugar,
    required this.servingSize,
  });
}

class SmartRecommendationResult {
  final double remainingCalories;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFats;
  final bool isCalorieExceeded;
  final bool isProteinExceeded;
  final bool isCarbsExceeded;
  final bool isFatExceeded;
  final String insightMessage;
  final List<SuggestedFoodItem> suggestions;

  const SmartRecommendationResult({
    required this.remainingCalories,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFats,
    required this.isCalorieExceeded,
    required this.isProteinExceeded,
    required this.isCarbsExceeded,
    required this.isFatExceeded,
    required this.insightMessage,
    required this.suggestions,
  });
}

class SuggestedFoodItem {
  final SuggestionFood food;
  final String reason;

  const SuggestedFoodItem({
    required this.food,
    required this.reason,
  });
}

class RecommendationEngine {
  static const List<SuggestionFood> foodDataset = [
    SuggestionFood(
      name: 'Chicken Breast',
      calories: 165.0,
      protein: 31.0,
      carbohydrates: 0.0,
      fats: 3.6,
      sugar: 0.0,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Eggs',
      calories: 143.0,
      protein: 13.0,
      carbohydrates: 1.1,
      fats: 9.5,
      sugar: 0.6,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Greek Yogurt',
      calories: 59.0,
      protein: 10.0,
      carbohydrates: 3.6,
      fats: 0.4,
      sugar: 3.2,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Dal (Lentils)',
      calories: 116.0,
      protein: 9.0,
      carbohydrates: 20.0,
      fats: 0.4,
      sugar: 1.8,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Paneer',
      calories: 265.0,
      protein: 18.3,
      carbohydrates: 1.2,
      fats: 20.8,
      sugar: 1.2,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Oats',
      calories: 389.0,
      protein: 16.9,
      carbohydrates: 66.3,
      fats: 6.9,
      sugar: 0.0,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Banana',
      calories: 89.0,
      protein: 1.1,
      carbohydrates: 22.8,
      fats: 0.3,
      sugar: 12.2,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'White Rice',
      calories: 130.0,
      protein: 2.7,
      carbohydrates: 28.0,
      fats: 0.3,
      sugar: 0.0,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Whole Milk',
      calories: 61.0,
      protein: 3.2,
      carbohydrates: 4.8,
      fats: 3.3,
      sugar: 5.1,
      servingSize: 100.0,
    ),
    SuggestionFood(
      name: 'Mixed Vegetables',
      calories: 65.0,
      protein: 2.0,
      carbohydrates: 11.0,
      fats: 0.2,
      sugar: 4.0,
      servingSize: 100.0,
    ),
  ];

  static SmartRecommendationResult getRecommendations({
    required List<NutritionRecordEntity> dailyRecords,
    required NutritionGoalsEntity? goals,
  }) {
    double consumedCals = 0;
    double consumedPro = 0;
    double consumedCarbs = 0;
    double consumedFats = 0;

    for (final r in dailyRecords) {
      consumedCals += r.calories;
      consumedPro += r.protein;
      consumedCarbs += r.carbohydrates;
      consumedFats += r.fats;
    }

    final double goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double goalPro = goals?.proteinTargetGrams ?? 150.0;
    final double goalCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double goalFats = goals?.fatTargetGrams ?? 65.0;

    final double rawRemainingCals = goalCals - consumedCals;
    final double rawRemainingPro = goalPro - consumedPro;
    final double rawRemainingCarbs = goalCarbs - consumedCarbs;
    final double rawRemainingFats = goalFats - consumedFats;

    final double remainingCals = rawRemainingCals.clamp(0.0, double.infinity);
    final double remainingPro = rawRemainingPro.clamp(0.0, double.infinity);
    final double remainingCarbs = rawRemainingCarbs.clamp(0.0, double.infinity);
    final double remainingFats = rawRemainingFats.clamp(0.0, double.infinity);

    final bool isCalorieExceeded = rawRemainingCals < 0;
    final bool isProteinExceeded = rawRemainingPro < 0;
    final bool isCarbsExceeded = rawRemainingCarbs < 0;
    final bool isFatExceeded = rawRemainingFats < 0;

    String insight = "You're on track with today's nutrition goals.";
    if (goals == null) {
      insight = 'Set your goals to receive personalized smart nutrition feedback.';
    } else {
      if (isFatExceeded || rawRemainingFats < goalFats * 0.05) {
        insight = 'Consider choosing a lower-fat food for your next meal.';
      } else if (isCalorieExceeded) {
        insight = 'You have exceeded your calorie goal today.';
      } else if (rawRemainingCals > goalCals * 0.5) {
        insight = 'Your calorie intake is below your daily target.';
      } else if (rawRemainingPro > goalPro * 0.4) {
        insight = 'Your protein intake is below your target.';
      }
    }

    // Determine target deficiency priorities
    final bool needsProtein = rawRemainingPro > 15;
    final bool needsCarbs = rawRemainingCarbs > 25;
    final bool limitFats = rawRemainingFats < 10;

    final List<SuggestedFoodItem> suggestions = [];

    // Filter and score foods based on remaining targets
    for (final food in foodDataset) {
      if (limitFats && food.fats > 5.0) {
        continue; // Exclude high fat options if fat target is low or exceeded
      }

      String reason = 'Healthy addition to support daily energy metrics.';

      if (needsProtein && food.protein > 8.0) {
        reason = 'High in protein to help meet your target.';
      }
      if (needsCarbs && food.carbohydrates > 15.0) {
        reason = 'Good source of carbohydrates to fuel your daily goals.';
      }
      if (limitFats && food.fats <= 1.0) {
        reason = 'Low in fat to prevent exceeding your target.';
      }

      suggestions.add(SuggestedFoodItem(food: food, reason: reason));
    }

    // Sort suggestions: items offering protein or low-fat options prioritized higher
    suggestions.sort((a, b) {
      // Sort logic prioritizing high protein or carbs depending on needs
      int scoreA = 0;
      int scoreB = 0;

      if (needsProtein) {
        if (a.food.protein > b.food.protein) scoreA += 5;
        if (b.food.protein > a.food.protein) scoreB += 5;
      }
      if (needsCarbs) {
        if (a.food.carbohydrates > b.food.carbohydrates) scoreA += 3;
        if (b.food.carbohydrates > a.food.carbohydrates) scoreB += 3;
      }
      if (limitFats) {
        if (a.food.fats < b.food.fats) scoreA += 4;
        if (b.food.fats < a.food.fats) scoreB += 4;
      }

      return scoreB.compareTo(scoreA);
    });

    final limitedSuggestions = suggestions.take(3).toList();

    return SmartRecommendationResult(
      remainingCalories: remainingCals,
      remainingProtein: remainingPro,
      remainingCarbs: remainingCarbs,
      remainingFats: remainingFats,
      isCalorieExceeded: isCalorieExceeded,
      isProteinExceeded: isProteinExceeded,
      isCarbsExceeded: isCarbsExceeded,
      isFatExceeded: isFatExceeded,
      insightMessage: insight,
      suggestions: limitedSuggestions,
    );
  }
}
