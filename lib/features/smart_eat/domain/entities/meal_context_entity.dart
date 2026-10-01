class MealContextEntity {
  final String currentMealType;
  final DateTime localTime;

  const MealContextEntity({
    required this.currentMealType,
    required this.localTime,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealContextEntity &&
          runtimeType == other.runtimeType &&
          currentMealType == other.currentMealType &&
          localTime == other.localTime;

  @override
  int get hashCode => currentMealType.hashCode ^ localTime.hashCode;
}
