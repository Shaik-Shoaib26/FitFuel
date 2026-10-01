class NutritionGapEntity {
  final double remainingCalories;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFat;
  final double remainingFiber;
  final double remainingWater;

  final bool proteinDeficit;
  final bool calorieDeficit;
  final bool calorieExcess;
  final bool fiberDeficit;
  final bool hydrationDeficit;

  const NutritionGapEntity({
    required this.remainingCalories,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    required this.remainingFiber,
    required this.remainingWater,
    required this.proteinDeficit,
    required this.calorieDeficit,
    required this.calorieExcess,
    required this.fiberDeficit,
    required this.hydrationDeficit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionGapEntity &&
          runtimeType == other.runtimeType &&
          remainingCalories == other.remainingCalories &&
          remainingProtein == other.remainingProtein &&
          remainingCarbs == other.remainingCarbs &&
          remainingFat == other.remainingFat &&
          remainingFiber == other.remainingFiber &&
          remainingWater == other.remainingWater &&
          proteinDeficit == other.proteinDeficit &&
          calorieDeficit == other.calorieDeficit &&
          calorieExcess == other.calorieExcess &&
          fiberDeficit == other.fiberDeficit &&
          hydrationDeficit == other.hydrationDeficit;

  @override
  int get hashCode =>
      remainingCalories.hashCode ^
      remainingProtein.hashCode ^
      remainingCarbs.hashCode ^
      remainingFat.hashCode ^
      remainingFiber.hashCode ^
      remainingWater.hashCode ^
      proteinDeficit.hashCode ^
      calorieDeficit.hashCode ^
      calorieExcess.hashCode ^
      fiberDeficit.hashCode ^
      hydrationDeficit.hashCode;
}
