import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_recommendation_engine.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/meal_plan_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/entities/planned_meal_entity.dart';
import 'package:fitfuel/features/meal_planner/domain/utils/meal_plan_calculator.dart';

class AdaptiveMealPlannerEngine {
  /// Generates a personalized daily meal plan based on goals, activities, dietary preferences, exclusions, and logged meals.
  static MealPlanEntity generateAdaptiveMealPlan({
    required List<FoodEntity> databaseFoods,
    required double targetCalories,
    required double targetProtein,
    required double targetCarbs,
    required double targetFat,
    required String fitnessGoal,
    required String activityLevel,
    required String dietaryPreference,
    List<String> excludedFoodNames = const [],
    List<String> favoriteFoodIds = const [],
    List<String> recentFoodIds = const [],
    List<dynamic> todayLogs = const [], // Today's actual logged food entries
    MealPlanEntity? existingPlan,
  }) {
    // 1. Determine active meals based on fitness goals and preferences
    // For Lose Weight + Sedentary users, we skip snacks to avoid forcing snack consumption.
    final bool includeSnacks = !(fitnessGoal.toLowerCase() == 'lose weight' && activityLevel.toLowerCase() == 'sedentary');

    // 2. Determine base calorie and protein distribution ratios
    final Map<String, double> baseCalRatios;
    final Map<String, double> baseProRatios;

    if (includeSnacks) {
      // Standard 5 meal distribution
      baseCalRatios = {
        'Breakfast': 0.25,
        'Morning Snack': 0.10,
        'Lunch': 0.30,
        'Evening Snack': 0.10,
        'Dinner': 0.25,
      };
      baseProRatios = {
        'Breakfast': 0.25,
        'Morning Snack': 0.10,
        'Lunch': 0.30,
        'Evening Snack': 0.10,
        'Dinner': 0.25,
      };
    } else {
      // 3 meal distribution
      baseCalRatios = {
        'Breakfast': 0.35,
        'Lunch': 0.35,
        'Dinner': 0.30,
      };
      baseProRatios = {
        'Breakfast': 0.30,
        'Lunch': 0.35,
        'Dinner': 0.35,
      };
    }

    // Adjust distribution for activity level: Very Active users get stronger morning/dinner workout support
    if (activityLevel.toLowerCase() == 'very active') {
      if (includeSnacks) {
        baseCalRatios['Breakfast'] = 0.30;
        baseCalRatios['Morning Snack'] = 0.05;
        baseCalRatios['Lunch'] = 0.30;
        baseCalRatios['Evening Snack'] = 0.05;
        baseCalRatios['Dinner'] = 0.30;
      } else {
        baseCalRatios['Breakfast'] = 0.40;
        baseCalRatios['Lunch'] = 0.30;
        baseCalRatios['Dinner'] = 0.30;
      }
    }

    // 3. Filter database foods based on strict dietary preference checks
    final filteredFoods = filterFoodsByDiet(databaseFoods, dietaryPreference);

    // 4. Calculate consumed macros today from actual logs
    double consumedCals = 0;
    double consumedPro = 0;
    double consumedCarb = 0;
    double consumedFat = 0;
    final Set<String> completedMealTypes = {};

    for (final log in todayLogs) {
      consumedCals += (log.calories as num).toDouble();
      consumedPro += (log.protein as num).toDouble();
      consumedCarb += (log.carbohydrates as num).toDouble();
      consumedFat += (log.fats as num).toDouble();
      
      final String? logMealType = log.mealType;
      if (logMealType != null && logMealType.isNotEmpty) {
        completedMealTypes.add(logMealType.toLowerCase());
      }
    }

    // 5. Calculate remaining target macros
    final double remainingCals = (targetCalories - consumedCals).clamp(0.0, double.infinity);
    final double remainingPro = (targetProtein - consumedPro).clamp(0.0, double.infinity);

    // 6. Build the list of planned meals (retaining completed/logged ones)
    final List<PlannedMealEntity> plannedMeals = [];
    final List<String> mealTypesToPlan = baseCalRatios.keys.toList();
    
    // Identify uncompleted meals
    final List<String> uncompletedMealTypes = mealTypesToPlan
        .where((m) => !completedMealTypes.contains(m.toLowerCase()))
        .toList();

    // Sum ratios for remaining uncompleted meals to scale distribution properly
    double remainingCalRatioSum = uncompletedMealTypes.fold(0.0, (sum, m) => sum + (baseCalRatios[m] ?? 0));
    double remainingProRatioSum = uncompletedMealTypes.fold(0.0, (sum, m) => sum + (baseProRatios[m] ?? 0));

    if (remainingCalRatioSum == 0) remainingCalRatioSum = 1.0;
    if (remainingProRatioSum == 0) remainingProRatioSum = 1.0;

    List<String> previouslyUsedIds = [];

    // Let's build each meal
    for (final mealType in mealTypesToPlan) {
      final isLogged = completedMealTypes.contains(mealType.toLowerCase());

      if (isLogged) {
        // Retrieve foods logged for this meal type to display in the plan
        final mealLogs = todayLogs.where((l) => l.mealType?.toLowerCase() == mealType.toLowerCase()).toList();
        final List<PlannedFoodEntity> loggedFoods = [];
        
        for (final l in mealLogs) {
          final matchedFood = databaseFoods.firstWhere(
            (f) => f.name.toLowerCase() == l.foodName?.toLowerCase(),
            orElse: () => FoodEntity(
              id: 'custom_${l.foodName}',
              name: l.foodName ?? 'Logged Food',
              category: mealType,
              servingSize: l.servingSize?.toDouble() ?? 100.0,
              servingUnit: 'g',
              calories: l.calories?.toDouble() ?? 0.0,
              protein: l.protein?.toDouble() ?? 0.0,
              carbohydrates: l.carbohydrates?.toDouble() ?? 0.0,
              fats: l.fats?.toDouble() ?? 0.0,
              fiber: 0.0,
              sugar: 0.0,
              sodium: 0.0,
            ),
          );

          loggedFoods.add(PlannedFoodEntity(
            food: matchedFood,
            servingQuantity: l.servingSize?.toDouble() ?? 100.0,
            unit: matchedFood.servingUnit,
            calories: l.calories?.toDouble() ?? 0.0,
            protein: l.protein?.toDouble() ?? 0.0,
            carbohydrates: l.carbohydrates?.toDouble() ?? 0.0,
            fat: l.fats?.toDouble() ?? 0.0,
            fiber: matchedFood.fiber * ((l.servingSize?.toDouble() ?? 100.0) / matchedFood.servingSize),
          ));
        }

        double mealCals = 0, mealPro = 0, mealCarb = 0, mealFat = 0;
        for (final f in loggedFoods) {
          mealCals += f.calories;
          mealPro += f.protein;
          mealCarb += f.carbohydrates;
          mealFat += f.fat;
        }

        plannedMeals.add(PlannedMealEntity(
          mealType: mealType,
          foods: loggedFoods,
          totalCalories: mealCals,
          totalProtein: mealPro,
          totalCarbs: mealCarb,
          totalFat: mealFat,
        ));
      } else {
        // Meal is uncompleted, we dynamically generate/scale it based on remaining budget!
        final mealCalRatio = (baseCalRatios[mealType] ?? 0) / remainingCalRatioSum;
        final mealProRatio = (baseProRatios[mealType] ?? 0) / remainingProRatioSum;

        final double mealCalTarget = remainingCals * mealCalRatio;
        final double mealProTarget = remainingPro * mealProRatio;

        // If remaining targets are essentially zero (e.g. targets met), generate tiny healthy fallbacks
        final double activeCalTarget = mealCalTarget > 50 ? mealCalTarget : 80.0;
        final double activeProTarget = mealProTarget > 2 ? mealProTarget : 5.0;

        // To prevent excessive repetition: filter out foods already generated in this plan
        final availableFoods = filteredFoods.where((f) => !previouslyUsedIds.contains(f.id)).toList();

        // Check if existing plan had a meal that is still unlogged. If yes, we can adapt its portion or regenerate.
        final existingMeal = existingPlan?.meals.firstWhere((m) => m.mealType == mealType, orElse: () => const PlannedMealEntity(mealType: '', totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0));
        
        List<PlannedFoodEntity> selectedFoods = [];
        double currentMealCals = 0.0;

        if (existingMeal != null && existingMeal.mealType.isNotEmpty && existingMeal.foods.isNotEmpty) {
          // Adapt the portions of the existing plan's uncompleted meal foods to match the scaled targets
          final double scale = (activeCalTarget / existingMeal.totalCalories).clamp(0.4, 2.5);
          for (final pf in existingMeal.foods) {
            final double targetServing = pf.servingQuantity * scale;
            selectedFoods.add(MealPlanCalculator.calculateFoodPortion(pf.food, targetServing, pf.unit));
            previouslyUsedIds.add(pf.food.id);
          }
        } else {
          // Generate fresh suggestions
          final recommendations = FoodRecommendationEngine.recommend(
            foods: availableFoods,
            mealType: mealType,
            remainingCalories: activeCalTarget,
            proteinDeficit: activeProTarget,
            dietaryPreference: dietaryPreference,
            excludedFoodNames: excludedFoodNames,
            favoriteFoodIds: favoriteFoodIds,
            recentFoodIds: recentFoodIds,
          );

          int count = 0;
          for (var food in recommendations) {
            if (currentMealCals >= activeCalTarget * 0.95 || count >= 2) break;
            
            double remainingForMeal = activeCalTarget - currentMealCals;
            double ratio = (remainingForMeal / food.calories).clamp(0.5, 2.0);
            
            if (ratio < 0.5 && count > 0) continue;
            
            double targetServing = food.servingSize * ratio;
            final plannedFood = MealPlanCalculator.calculateFoodPortion(food, targetServing, food.servingUnit);
            
            selectedFoods.add(plannedFood);
            previouslyUsedIds.add(food.id);
            currentMealCals += plannedFood.calories;
            count++;
          }

          // Fallback if empty
          if (selectedFoods.isEmpty && filteredFoods.isNotEmpty) {
            final fallbackFood = filteredFoods.first;
            selectedFoods.add(MealPlanCalculator.calculateFoodPortion(fallbackFood, fallbackFood.servingSize, fallbackFood.servingUnit));
          }
        }

        double mealCals = 0, mealPro = 0, mealCarb = 0, mealFat = 0;
        for (final f in selectedFoods) {
          mealCals += f.calories;
          mealPro += f.protein;
          mealCarb += f.carbohydrates;
          mealFat += f.fat;
        }

        plannedMeals.add(PlannedMealEntity(
          mealType: mealType,
          foods: selectedFoods,
          totalCalories: mealCals,
          totalProtein: mealPro,
          totalCarbs: mealCarb,
          totalFat: mealFat,
        ));
      }
    }

    final reason = _getPersonalizationReason(fitnessGoal, activityLevel, dietaryPreference);

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    var plan = MealPlanEntity(
      id: dateStr,
      date: today,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      consumedCalories: consumedCals,
      consumedProtein: consumedPro,
      consumedCarbs: consumedCarb,
      consumedFat: consumedFat,
      meals: plannedMeals,
      generatedAt: DateTime.now(),
      personalizationReason: reason,
    );

    return MealPlanCalculator.recalculateMealPlan(plan);
  }

  /// Strict filter on database foods to conform to specific dietary preferences.
  static List<FoodEntity> filterFoodsByDiet(List<FoodEntity> foods, String preference) {
    final dietPref = preference.toLowerCase().trim();
    if (dietPref == 'any' || dietPref == 'none') {
      return foods;
    }

    final List<FoodEntity> results = [];
    for (final food in foods) {
      final nameLower = food.name.toLowerCase();

      // Vegetarian checks
      if (dietPref == 'vegetarian') {
        if (nameLower.contains('chicken') ||
            nameLower.contains('salmon') ||
            nameLower.contains('beef') ||
            nameLower.contains('fish') ||
            nameLower.contains('meat') ||
            nameLower.contains('seafood') ||
            nameLower.contains('turkey')) {
          continue;
        }
      }

      // Vegan checks
      if (dietPref == 'vegan') {
        if (nameLower.contains('chicken') ||
            nameLower.contains('salmon') ||
            nameLower.contains('beef') ||
            nameLower.contains('fish') ||
            nameLower.contains('meat') ||
            nameLower.contains('seafood') ||
            nameLower.contains('turkey') ||
            nameLower.contains('paneer') ||
            nameLower.contains('milk') ||
            nameLower.contains('yogurt') ||
            nameLower.contains('curd') ||
            nameLower.contains('egg') ||
            nameLower.contains('dairy') ||
            nameLower.contains('ghee') ||
            nameLower.contains('butter') ||
            nameLower.contains('cheese')) {
          continue;
        }
      }

      // Keto checks: Carbohydrates must be very low
      final double carbsPer100g = food.servingSize > 0 ? (food.carbohydrates / (food.servingSize / 100.0)) : food.carbohydrates;

      if (dietPref == 'keto') {
        // High carb foods like rice, bread, grains, dosa, idli, sweets must be excluded.
        if (carbsPer100g > 10.0 ||
            nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('idli') ||
            nameLower.contains('upma') ||
            nameLower.contains('poha') ||
            nameLower.contains('chapati') ||
            nameLower.contains('roti') ||
            nameLower.contains('paratha') ||
            nameLower.contains('banana') ||
            nameLower.contains('potato') ||
            nameLower.contains('oats')) {
          continue;
        }
      }

      // Low Carb checks: Restrict foods with higher carbs
      if (dietPref == 'low carb' || dietPref == 'lowcarb') {
        if (carbsPer100g > 15.0 ||
            nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('banana') ||
            nameLower.contains('sweets')) {
          continue;
        }
      }

      // Paleo checks: whole foods, no dairy, grains, legumes
      if (dietPref == 'paleo') {
        if (nameLower.contains('milk') ||
            nameLower.contains('dairy') ||
            nameLower.contains('cheese') ||
            nameLower.contains('paneer') ||
            nameLower.contains('yogurt') ||
            nameLower.contains('curd') ||
            nameLower.contains('ghee') ||
            nameLower.contains('butter') ||
            // grains
            nameLower.contains('rice') ||
            nameLower.contains('dosa') ||
            nameLower.contains('idli') ||
            nameLower.contains('upma') ||
            nameLower.contains('poha') ||
            nameLower.contains('chapati') ||
            nameLower.contains('roti') ||
            nameLower.contains('paratha') ||
            nameLower.contains('oats') ||
            nameLower.contains('bread') ||
            // legumes
            nameLower.contains('dal') ||
            nameLower.contains('lentil') ||
            nameLower.contains('chana') ||
            nameLower.contains('sambar')) {
          continue;
        }
      }

      results.add(food);
    }
    return results;
  }

  static String _getPersonalizationReason(String fitnessGoal, String activityLevel, String dietaryPreference) {
    final goalText = fitnessGoal.toUpperCase();
    final activityText = activityLevel.toUpperCase();
    final dietText = dietaryPreference.toUpperCase();
    return 'Personalized $dietText diet for $goalText fitness goals with $activityText active lifestyle.';
  }
}
