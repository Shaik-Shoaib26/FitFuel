/// Mifflin-St Jeor Formula for BMR & TDEE Calculation
abstract class TDEECalculator {
  /// Calculates Basal Metabolic Rate (BMR)
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    if (gender.toLowerCase() == 'female') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
    // Male or default
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
  }

  /// Calculates Total Daily Energy Expenditure (TDEE) based on activity multiplier
  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    double multiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'lightly_active':
        multiplier = 1.375;
        break;
      case 'moderately_active':
        multiplier = 1.55;
        break;
      case 'very_active':
        multiplier = 1.725;
        break;
      default:
        multiplier = 1.375;
    }
    return bmr * multiplier;
  }

  /// Calculates Target Calorie Goal based on primary objective
  static int calculateCalorieTarget({
    required double tdee,
    required String goal,
  }) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        return (tdee - 500).round(); // 500 kcal deficit
      case 'gain_muscle':
        return (tdee + 300).round(); // 300 kcal surplus
      case 'maintain':
      default:
        return tdee.round();
    }
  }

  /// Calculates Macronutrient Split Target in grams (Protein/Carbs/Fat)
  static Map<String, double> calculateMacroTargets({
    required int calorieTarget,
    required double weightKg,
  }) {
    // Protein: 2.0g per kg of body weight
    final proteinGrams = weightKg * 2.0;
    final proteinCalories = proteinGrams * 4;

    // Fat: 25% of total calorie target
    final fatCalories = calorieTarget * 0.25;
    final fatGrams = fatCalories / 9;

    // Carbs: Remaining calorie budget
    final carbsCalories = calorieTarget - (proteinCalories + fatCalories);
    final carbsGrams = (carbsCalories / 4).clamp(0, double.infinity);

    return {
      'proteinGrams': double.parse(proteinGrams.toStringAsFixed(1)),
      'carbsGrams': double.parse(carbsGrams.toStringAsFixed(1)),
      'fatGrams': double.parse(fatGrams.toStringAsFixed(1)),
    };
  }
}
