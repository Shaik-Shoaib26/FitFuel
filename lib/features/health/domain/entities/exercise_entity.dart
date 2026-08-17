class ExerciseEntity {
  final String activity;
  final int duration; // in minutes
  final double caloriesBurned;

  const ExerciseEntity({
    required this.activity,
    required this.duration,
    required this.caloriesBurned,
  });

  ExerciseEntity copyWith({
    String? activity,
    int? duration,
    double? caloriesBurned,
  }) {
    return ExerciseEntity(
      activity: activity ?? this.activity,
      duration: duration ?? this.duration,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
    );
  }
}
