import '../../domain/entities/exercise_entity.dart';

class ExerciseModel {
  final String activity;
  final int duration;
  final double caloriesBurned;

  const ExerciseModel({
    required this.activity,
    required this.duration,
    required this.caloriesBurned,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ExerciseModel(
      activity: json['activity'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      caloriesBurned: parseDouble(json['caloriesBurned']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activity': activity,
      'duration': duration,
      'caloriesBurned': caloriesBurned,
    };
  }

  factory ExerciseModel.fromEntity(ExerciseEntity entity) {
    return ExerciseModel(
      activity: entity.activity,
      duration: entity.duration,
      caloriesBurned: entity.caloriesBurned,
    );
  }

  ExerciseEntity toEntity() {
    return ExerciseEntity(
      activity: activity,
      duration: duration,
      caloriesBurned: caloriesBurned,
    );
  }
}
