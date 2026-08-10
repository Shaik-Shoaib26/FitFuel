class NutritionGoalsEntity {
  final String userId;
  final int dailyCalorieTarget;
  final double proteinTargetGrams;
  final double carbsTargetGrams;
  final double fatTargetGrams;
  final DateTime updatedAt;

  const NutritionGoalsEntity({
    required this.userId,
    required this.dailyCalorieTarget,
    required this.proteinTargetGrams,
    required this.carbsTargetGrams,
    required this.fatTargetGrams,
    required this.updatedAt,
  });

  NutritionGoalsEntity copyWith({
    String? userId,
    int? dailyCalorieTarget,
    double? proteinTargetGrams,
    double? carbsTargetGrams,
    double? fatTargetGrams,
    DateTime? updatedAt,
  }) {
    return NutritionGoalsEntity(
      userId: userId ?? this.userId,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      proteinTargetGrams: proteinTargetGrams ?? this.proteinTargetGrams,
      carbsTargetGrams: carbsTargetGrams ?? this.carbsTargetGrams,
      fatTargetGrams: fatTargetGrams ?? this.fatTargetGrams,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionGoalsEntity &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          dailyCalorieTarget == other.dailyCalorieTarget &&
          proteinTargetGrams == other.proteinTargetGrams &&
          carbsTargetGrams == other.carbsTargetGrams &&
          fatTargetGrams == other.fatTargetGrams &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      userId.hashCode ^
      dailyCalorieTarget.hashCode ^
      proteinTargetGrams.hashCode ^
      carbsTargetGrams.hashCode ^
      fatTargetGrams.hashCode ^
      updatedAt.hashCode;
}
