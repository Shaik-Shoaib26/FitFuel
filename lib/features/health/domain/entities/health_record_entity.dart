import 'exercise_entity.dart';

class HealthRecordEntity {
  final String id;
  final String date; // yyyy-MM-dd
  final double waterIntakeMl;
  final double waterTargetMl;
  final List<ExerciseEntity> exercises;
  final Map<String, bool> habits;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthRecordEntity({
    required this.id,
    required this.date,
    required this.waterIntakeMl,
    required this.waterTargetMl,
    required this.exercises,
    required this.habits,
    required this.createdAt,
    required this.updatedAt,
  });

  HealthRecordEntity copyWith({
    String? id,
    String? date,
    double? waterIntakeMl,
    double? waterTargetMl,
    List<ExerciseEntity>? exercises,
    Map<String, bool>? habits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthRecordEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      exercises: exercises ?? this.exercises,
      habits: habits ?? this.habits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory HealthRecordEntity.empty(String date) {
    return HealthRecordEntity(
      id: date,
      date: date,
      waterIntakeMl: 0.0,
      waterTargetMl: 2500.0,
      exercises: const [],
      habits: const {
        'Sleep 7-8h': false,
        '10k Steps': false,
        'Stretching': false,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
