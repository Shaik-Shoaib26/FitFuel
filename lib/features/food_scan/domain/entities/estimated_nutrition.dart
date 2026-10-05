/// Represents AI-estimated macronutrients for a food portion when
/// no database match exists in the FitFuel catalog.
class EstimatedNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const EstimatedNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Safely parses estimated nutrition from a JSON map.
  ///
  /// STRICT NUTRITION RULE:
  /// Returns `null` if ANY of calories, protein, carbs, or fat is missing or null.
  /// Never converts missing fields to 0. True zero (0.0) is allowed and preserved.
  static EstimatedNutrition? fromJson(dynamic json) {
    if (json == null || json is! Map) return null;

    final rawCals = json['calories'];
    final rawPro = json['protein_g'] ?? json['protein'];
    final rawCarbs = json['carbs_g'] ?? json['carbs'] ?? json['carbohydrates'];
    final rawFat = json['fat_g'] ?? json['fat'] ?? json['fats'];

    // All four fields must be explicitly provided
    if (rawCals == null || rawPro == null || rawCarbs == null || rawFat == null) {
      return null;
    }

    final cals = double.tryParse(rawCals.toString());
    final pro = double.tryParse(rawPro.toString());
    final carbs = double.tryParse(rawCarbs.toString());
    final fat = double.tryParse(rawFat.toString());

    if (cals == null || pro == null || carbs == null || fat == null) {
      return null;
    }

    // Negative nutrition values are invalid
    if (cals < 0 || pro < 0 || carbs < 0 || fat < 0) {
      return null;
    }

    return EstimatedNutrition(
      calories: cals,
      protein: pro,
      carbs: carbs,
      fat: fat,
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
      };

  EstimatedNutrition copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return EstimatedNutrition(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstimatedNutrition &&
          runtimeType == other.runtimeType &&
          calories == other.calories &&
          protein == other.protein &&
          carbs == other.carbs &&
          fat == other.fat;

  @override
  int get hashCode => Object.hash(calories, protein, carbs, fat);
}
