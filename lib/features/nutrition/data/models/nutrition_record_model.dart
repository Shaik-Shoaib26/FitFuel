import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/sync/sync_status.dart';
import '../../domain/entities/nutrition_record_entity.dart';

class NutritionRecordModel {
  final String id;
  final String foodName;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double sugar;
  final double servingSize;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const NutritionRecordModel({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.sugar,
    required this.servingSize,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
  });

  factory NutritionRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return NutritionRecordModel(
      id: doc.id,
      foodName: data['foodName'] as String? ?? '',
      mealType: data['mealType'] as String? ?? 'Snack',
      calories: parseDouble(data['calories']),
      protein: parseDouble(data['protein']),
      carbohydrates: parseDouble(data['carbohydrates']),
      fats: parseDouble(data['fats']),
      sugar: parseDouble(data['sugar']),
      servingSize: parseDouble(data['servingSize']),
      consumedAt: parseDateTime(data['consumedAt']),
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
      syncStatus: doc.metadata.hasPendingWrites ? SyncStatus.pending : SyncStatus.synced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'foodName': foodName,
      'mealType': mealType,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'sugar': sugar,
      'servingSize': servingSize,
      'consumedAt': Timestamp.fromDate(consumedAt),
    };
  }

  factory NutritionRecordModel.fromEntity(NutritionRecordEntity entity) {
    return NutritionRecordModel(
      id: entity.id,
      foodName: entity.foodName,
      mealType: entity.mealType,
      calories: entity.calories,
      protein: entity.protein,
      carbohydrates: entity.carbohydrates,
      fats: entity.fats,
      sugar: entity.sugar,
      servingSize: entity.servingSize,
      consumedAt: entity.consumedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      syncStatus: entity.syncStatus,
    );
  }

  NutritionRecordEntity toEntity() {
    return NutritionRecordEntity(
      id: id,
      foodName: foodName,
      mealType: mealType,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fats: fats,
      sugar: sugar,
      servingSize: servingSize,
      consumedAt: consumedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus,
    );
  }
}
