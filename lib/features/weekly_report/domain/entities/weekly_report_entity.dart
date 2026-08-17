class WeeklyReportEntity {
  // Weekly Score (0 - 100) and component scores
  final double healthScore;
  final double nutritionScore;
  final double hydrationScore;
  final double exerciseScore;
  final double habitsScore;
  final double wellnessScore;

  // Nutrition
  final double avgCalories;
  final double calorieAdherencePercent;
  final double calorieConsistencyPercent;
  final double avgProtein;
  final double proteinAdherencePercent;
  final double proteinConsistencyPercent;
  final double avgCarbs;
  final double avgFats;
  final int nutritionDaysLogged;
  final int nutritionStreak;
  final String nutritionStatus;

  // Hydration
  final double avgWater;
  final double waterTarget;
  final double hydrationAdherencePercent;
  final int waterDaysMet;
  final double hydrationConsistencyPercent;
  final String hydrationStatus;

  // Exercise
  final int exerciseActiveDays;
  final int exerciseTotalMinutes;
  final double exerciseAvgDuration;
  final double exerciseCaloriesBurned;
  final double exerciseConsistencyPercent;

  // Habits
  final double habitsAvgCompletionPercent;
  final int habitsSuccessfulDays;
  final String habitsBestName;
  final String habitsAttentionName;
  final double habitsConsistencyPercent;

  // Wellness
  final double wellnessAvgScore;
  final double wellnessBestScore;
  final double wellnessLowestScore;
  final String wellnessTrend; // 'Improving' | 'Stable' | 'Declining' | 'Insufficient'

  // Weight
  final double startingWeight;
  final double currentWeight;
  final double weightChange;
  final double weightChangePercent;
  final String weightGoalDirection;

  // Analysis
  final String strongestArea;
  final String strongestAreaDescription;
  final String weakestArea;
  final String weakestAreaDescription;
  final String weakestAreaSuggestion;

  // Recommendations & Milestones
  final List<String> insights;
  final List<String> actionPlan;
  final List<String> unlockedMilestones;

  const WeeklyReportEntity({
    required this.healthScore,
    required this.nutritionScore,
    required this.hydrationScore,
    required this.exerciseScore,
    required this.habitsScore,
    required this.wellnessScore,
    required this.avgCalories,
    required this.calorieAdherencePercent,
    required this.calorieConsistencyPercent,
    required this.avgProtein,
    required this.proteinAdherencePercent,
    required this.proteinConsistencyPercent,
    required this.avgCarbs,
    required this.avgFats,
    required this.nutritionDaysLogged,
    required this.nutritionStreak,
    required this.nutritionStatus,
    required this.avgWater,
    required this.waterTarget,
    required this.hydrationAdherencePercent,
    required this.waterDaysMet,
    required this.hydrationConsistencyPercent,
    required this.hydrationStatus,
    required this.exerciseActiveDays,
    required this.exerciseTotalMinutes,
    required this.exerciseAvgDuration,
    required this.exerciseCaloriesBurned,
    required this.exerciseConsistencyPercent,
    required this.habitsAvgCompletionPercent,
    required this.habitsSuccessfulDays,
    required this.habitsBestName,
    required this.habitsAttentionName,
    required this.habitsConsistencyPercent,
    required this.wellnessAvgScore,
    required this.wellnessBestScore,
    required this.wellnessLowestScore,
    required this.wellnessTrend,
    required this.startingWeight,
    required this.currentWeight,
    required this.weightChange,
    required this.weightChangePercent,
    required this.weightGoalDirection,
    required this.strongestArea,
    required this.strongestAreaDescription,
    required this.weakestArea,
    required this.weakestAreaDescription,
    required this.weakestAreaSuggestion,
    required this.insights,
    required this.actionPlan,
    required this.unlockedMilestones,
  });
}
