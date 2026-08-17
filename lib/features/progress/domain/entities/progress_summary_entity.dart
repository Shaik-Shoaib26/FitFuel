class MilestoneEntity {
  final String id;
  final String title;
  final String description;
  final bool isUnlocked;
  final String progressText;
  final double progressPercent; // 0.0 to 1.0

  const MilestoneEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.progressText,
    required this.progressPercent,
  });
}

class ProgressSummaryEntity {
  // Nutrition & Calories
  final double avgCalories;
  final double calorieTarget;
  final double calorieAdherencePercent;
  final int nutritionDaysLogged;
  final int nutritionDaysMissed;
  final double calorieConsistencyPercent; // Within tolerance range

  // Protein
  final double avgProtein;
  final double proteinTarget;
  final int proteinDaysMet;
  final double proteinConsistencyPercent;

  // Carbs / Fats
  final double avgCarbs;
  final double carbsTarget;
  final double avgFats;
  final double fatsTarget;

  // Hydration
  final double avgWater;
  final double waterTarget;
  final int waterDaysMet;
  final double waterConsistencyPercent;

  // Exercise
  final int exerciseActiveDays;
  final int exerciseTotalMinutes;
  final double exerciseAvgDuration;
  final double exerciseConsistencyPercent;
  final double exerciseTotalCaloriesBurned;

  // Habits
  final double habitsAvgCompletionRate;
  final int habitsSuccessfulDays;
  final double habitsConsistencyPercent;
  final String habitsMostConsistent;
  final String habitsLeastConsistent;

  // Wellness
  final double wellnessAvgScore;
  final double wellnessBestScore;
  final double wellnessLowestScore;
  final String wellnessTrend; // 'Improving' | 'Stable' | 'Declining' | 'Insufficient'

  // Weight
  final double currentWeight;
  final double startingWeight;
  final double weightChange;
  final double weightChangePercent;
  final String weightGoalDirection; // e.g. 'Lose Weight', 'Gain Muscle', 'Maintain'

  // Streaks
  final int currentStreak;
  final int longestStreak;

  // Milestones list
  final List<MilestoneEntity> milestones;

  const ProgressSummaryEntity({
    required this.avgCalories,
    required this.calorieTarget,
    required this.calorieAdherencePercent,
    required this.nutritionDaysLogged,
    required this.nutritionDaysMissed,
    required this.calorieConsistencyPercent,
    required this.avgProtein,
    required this.proteinTarget,
    required this.proteinDaysMet,
    required this.proteinConsistencyPercent,
    required this.avgCarbs,
    required this.carbsTarget,
    required this.avgFats,
    required this.fatsTarget,
    required this.avgWater,
    required this.waterTarget,
    required this.waterDaysMet,
    required this.waterConsistencyPercent,
    required this.exerciseActiveDays,
    required this.exerciseTotalMinutes,
    required this.exerciseAvgDuration,
    required this.exerciseConsistencyPercent,
    required this.exerciseTotalCaloriesBurned,
    required this.habitsAvgCompletionRate,
    required this.habitsSuccessfulDays,
    required this.habitsConsistencyPercent,
    required this.habitsMostConsistent,
    required this.habitsLeastConsistent,
    required this.wellnessAvgScore,
    required this.wellnessBestScore,
    required this.wellnessLowestScore,
    required this.wellnessTrend,
    required this.currentWeight,
    required this.startingWeight,
    required this.weightChange,
    required this.weightChangePercent,
    required this.weightGoalDirection,
    required this.currentStreak,
    required this.longestStreak,
    required this.milestones,
  });
}
