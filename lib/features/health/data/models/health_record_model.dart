import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/health_record_entity.dart';
import 'exercise_model.dart';

class HealthRecordModel {
  final String id;
  final String date;
  final double waterIntakeMl;
  final double waterTargetMl;
  final List<ExerciseModel> exercises;
  final Map<String, bool> habits;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthRecordModel({
    required this.id,
    required this.date,
    required this.waterIntakeMl,
    required this.waterTargetMl,
    required this.exercises,
    required this.habits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final exercisesJson = data['exercises'] as List? ?? [];
    final exercisesList = exercisesJson
        .map((e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final habitsMap = Map<String, bool>.from(data['habits'] as Map? ?? {});

    return HealthRecordModel(
      id: doc.id,
      date: data['date'] as String? ?? doc.id,
      waterIntakeMl: parseDouble(data['waterIntakeMl']),
      waterTargetMl: parseDouble(data['waterTargetMl']),
      exercises: exercisesList,
      habits: habitsMap,
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'waterIntakeMl': waterIntakeMl,
      'waterTargetMl': waterTargetMl,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'habits': habits,
    };
  }

  factory HealthRecordModel.fromEntity(HealthRecordEntity entity) {
    return HealthRecordModel(
      id: entity.id,
      date: entity.date,
      waterIntakeMl: entity.waterIntakeMl,
      waterTargetMl: entity.waterTargetMl,
      exercises: entity.exercises.map((e) => ExerciseModel.fromEntity(e)).toList(),
      habits: entity.habits,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  HealthRecordEntity toEntity() {
    return HealthRecordEntity(
      id: id,
      date: date,
      waterIntakeMl: waterIntakeMl,
      waterTargetMl: waterTargetMl,
      exercises: exercises.map((e) => e.toEntity()).toList(),
      habits: habits,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
