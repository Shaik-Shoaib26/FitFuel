class AnalyticsSummaryEntity {
  final double averageCalories;
  final double averageProtein;
  final double averageCarbs;
  final double averageFat;
  final double averageWater;
  final double averageWorkoutMinutes;
  final double averageWellness;
  final double averageHabitCompletion;

  final double calorieAdherencePercentage;
  final double proteinAdherencePercentage;
  final double hydrationAdherencePercentage;
  final double exerciseConsistencyPercentage;
  final double habitConsistencyPercentage;
  final double overallConsistencyPercentage;

  final double? startingWeight;
  final double? currentWeight;
  final double? weightChange;
  final double? weightChangePercentage;

  final double bestWellnessScore;
  final double lowestWellnessScore;

  final int activeLoggingDays;
  final int currentLoggingStreak;
  final int longestLoggingStreak;

  // Classifications: 'Improving', 'Stable', 'Declining', 'Insufficient'
  final Map<String, String> trends;

  const AnalyticsSummaryEntity({
    required this.averageCalories,
    required this.averageProtein,
    required this.averageCarbs,
    required this.averageFat,
    required this.averageWater,
    required this.averageWorkoutMinutes,
    required this.averageWellness,
    required this.averageHabitCompletion,
    required this.calorieAdherencePercentage,
    required this.proteinAdherencePercentage,
    required this.hydrationAdherencePercentage,
    required this.exerciseConsistencyPercentage,
    required this.habitConsistencyPercentage,
    required this.overallConsistencyPercentage,
    this.startingWeight,
    this.currentWeight,
    this.weightChange,
    this.weightChangePercentage,
    required this.bestWellnessScore,
    required this.lowestWellnessScore,
    required this.activeLoggingDays,
    required this.currentLoggingStreak,
    required this.longestLoggingStreak,
    required this.trends,
  });
}
