import '../../domain/entities/nutrition_record_entity.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import './recommendation_engine.dart';

class MealPlanSuggestion {
  final SuggestionFood food;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFats;
  final String selectionReason;

  const MealPlanSuggestion({
    required this.food,
    required this.mealType,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFats,
    required this.selectionReason,
  });
}

class MealPlanResult {
  final double dailyCalorieGoal;
  final double plannedCalories;
  final double remainingCalories;
  final List<MealPlanSuggestion> breakfastSuggestions;
  final List<MealPlanSuggestion> lunchSuggestions;
  final List<MealPlanSuggestion> dinnerSuggestions;
  final List<MealPlanSuggestion> snackSuggestions;

  const MealPlanResult({
    required this.dailyCalorieGoal,
    required this.plannedCalories,
    required this.remainingCalories,
    required this.breakfastSuggestions,
    required this.lunchSuggestions,
    required this.dinnerSuggestions,
    required this.snackSuggestions,
  });
}

class MealPlannerEngine {
  /// Generate a personalized meal plan based on goals, remaining targets, and today's logs
  static MealPlanResult generateMealPlan({
    required List<NutritionRecordEntity> todayRecords,
    required NutritionGoalsEntity? goals,
    List<SuggestionFood>? customDataset,
  }) {
    final dataset = customDataset ?? RecommendationEngine.foodDataset;
    final double goalCals = goals?.dailyCalorieTarget.toDouble() ?? 2000.0;
    final double goalPro = goals?.proteinTargetGrams ?? 150.0;
    final double goalCarbs = goals?.carbsTargetGrams ?? 200.0;
    final double goalFats = goals?.fatTargetGrams ?? 65.0;

    double consumedCals = 0;
    final Set<String> consumedFoodNames = {};

    for (final r in todayRecords) {
      consumedCals += r.calories;
      consumedFoodNames.add(r.foodName.toLowerCase());
    }

    final double remainingCals = (goalCals - consumedCals).clamp(0.0, double.infinity);

    // Splits
    // Breakfast: 25%, Lunch: 35%, Dinner: 30%, Snack: 10%
    final breakfastSuggestions = _getSuggestionsForMeal(
      mealType: 'Breakfast',
      ratio: 0.25,
      goalCals: goalCals,
      goalPro: goalPro,
      goalCarbs: goalCarbs,
      goalFats: goalFats,
      consumedFoods: consumedFoodNames,
      dataset: dataset,
    );

    final lunchSuggestions = _getSuggestionsForMeal(
      mealType: 'Lunch',
      ratio: 0.35,
      goalCals: goalCals,
      goalPro: goalPro,
      goalCarbs: goalCarbs,
      goalFats: goalFats,
      consumedFoods: consumedFoodNames,
      dataset: dataset,
    );

    final dinnerSuggestions = _getSuggestionsForMeal(
      mealType: 'Dinner',
      ratio: 0.30,
      goalCals: goalCals,
      goalPro: goalPro,
      goalCarbs: goalCarbs,
      goalFats: goalFats,
      consumedFoods: consumedFoodNames,
      dataset: dataset,
    );

    final snackSuggestions = _getSuggestionsForMeal(
      mealType: 'Snack',
      ratio: 0.10,
      goalCals: goalCals,
      goalPro: goalPro,
      goalCarbs: goalCarbs,
      goalFats: goalFats,
      consumedFoods: consumedFoodNames,
      dataset: dataset,
    );

    // Compute planned calories (Sum of first suggestion of each meal type, if any)
    double plannedCals = 0;
    if (breakfastSuggestions.isNotEmpty) plannedCals += breakfastSuggestions.first.food.calories;
    if (lunchSuggestions.isNotEmpty) plannedCals += lunchSuggestions.first.food.calories;
    if (dinnerSuggestions.isNotEmpty) plannedCals += dinnerSuggestions.first.food.calories;
    if (snackSuggestions.isNotEmpty) plannedCals += snackSuggestions.first.food.calories;

    return MealPlanResult(
      dailyCalorieGoal: goalCals,
      plannedCalories: plannedCals,
      remainingCalories: remainingCals,
      breakfastSuggestions: breakfastSuggestions,
      lunchSuggestions: lunchSuggestions,
      dinnerSuggestions: dinnerSuggestions,
      snackSuggestions: snackSuggestions,
    );
  }

  static List<MealPlanSuggestion> _getSuggestionsForMeal({
    required String mealType,
    required double ratio,
    required double goalCals,
    required double goalPro,
    required double goalCarbs,
    required double goalFats,
    required Set<String> consumedFoods,
    required List<SuggestionFood> dataset,
  }) {
    if (dataset.isEmpty) return [];

    final targetCals = goalCals * ratio;
    final targetPro = goalPro * ratio;
    final targetCarbs = goalCarbs * ratio;
    final targetFats = goalFats * ratio;

    final List<MealPlanSuggestion> matches = [];

    for (final food in dataset) {
      final nameLower = food.name.toLowerCase();
      final isAlreadyConsumed = consumedFoods.contains(nameLower);



      String reason = 'Fits your daily target distribution for $mealType.';
      if (food.protein > targetPro * 0.8) {
        reason = 'High-protein option suitable for your $mealType target.';
      } else if (food.carbohydrates > targetCarbs * 0.8) {
        reason = 'Energy-dense carbs to support your $mealType metrics.';
      } else if (isAlreadyConsumed) {
        reason = 'Variant option to supplement your logged foods.';
      }

      matches.add(MealPlanSuggestion(
        food: food,
        mealType: mealType,
        targetCalories: targetCals,
        targetProtein: targetPro,
        targetCarbs: targetCarbs,
        targetFats: targetFats,
        selectionReason: reason,
        // We'll store score inside a sorting comparator
      ));
    }

    // Sort to place best scores at the top
    matches.sort((a, b) {
      final isAAlreadyConsumed = consumedFoods.contains(a.food.name.toLowerCase());
      final isBAlreadyConsumed = consumedFoods.contains(b.food.name.toLowerCase());

      final double scoreA = (a.food.calories - targetCals).abs() + (isAAlreadyConsumed ? 200.0 : 0.0);
      final double scoreB = (b.food.calories - targetCals).abs() + (isBAlreadyConsumed ? 200.0 : 0.0);

      return scoreA.compareTo(scoreB);
    });

    return matches.take(2).toList(); // Return top 2 matching options
  }
}
