import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../food_scan/domain/entities/nutrition_profile_tier.dart';
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
  final double? fiber;
  final double? sodium;
  final double servingSize;
  final String? foodId;
  final double? baseServingSize;
  final double? baseCalories;
  final double? baseProtein;
  final double? baseCarbohydrates;
  final double? baseFats;
  final double? baseFiber;
  final double? baseSugar;
  final double? baseSodium;
  final NutritionProfileTier? nutritionTier;
  final String? nutritionAttribution;
  final String? recipeAssumptions;
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
    this.fiber,
    this.sodium,
    required this.servingSize,
    this.foodId,
    this.baseServingSize,
    this.baseCalories,
    this.baseProtein,
    this.baseCarbohydrates,
    this.baseFats,
    this.baseFiber,
    this.baseSugar,
    this.baseSodium,
    this.nutritionTier,
    this.nutritionAttribution,
    this.recipeAssumptions,
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

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    NutritionProfileTier? parseTier(dynamic val) {
      if (val is String) {
        return NutritionProfileTier.values
            .where((t) => t.name == val)
            .firstOrNull;
      }
      return null;
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
      fiber: parseNullableDouble(data['fiber']),
      sodium: parseNullableDouble(data['sodium']),
      servingSize: parseDouble(data['servingSize']),
      foodId: data['foodId'] as String?,
      baseServingSize: data['baseServingSize'] != null ? parseDouble(data['baseServingSize']) : null,
      baseCalories: data['baseCalories'] != null ? parseDouble(data['baseCalories']) : null,
      baseProtein: data['baseProtein'] != null ? parseDouble(data['baseProtein']) : null,
      baseCarbohydrates: data['baseCarbohydrates'] != null ? parseDouble(data['baseCarbohydrates']) : null,
      baseFats: data['baseFats'] != null ? parseDouble(data['baseFats']) : null,
      baseFiber: parseNullableDouble(data['baseFiber']),
      baseSugar: data['baseSugar'] != null ? parseDouble(data['baseSugar']) : null,
      baseSodium: parseNullableDouble(data['baseSodium']),
      nutritionTier: parseTier(data['nutritionTier']),
      nutritionAttribution: data['nutritionAttribution'] as String?,
      recipeAssumptions: data['recipeAssumptions'] as String?,
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
      if (fiber != null) 'fiber': fiber,
      if (sodium != null) 'sodium': sodium,
      'servingSize': servingSize,
      if (foodId != null) 'foodId': foodId,
      if (baseServingSize != null) 'baseServingSize': baseServingSize,
      if (baseCalories != null) 'baseCalories': baseCalories,
      if (baseProtein != null) 'baseProtein': baseProtein,
      if (baseCarbohydrates != null) 'baseCarbohydrates': baseCarbohydrates,
      if (baseFats != null) 'baseFats': baseFats,
      if (baseFiber != null) 'baseFiber': baseFiber,
      if (baseSugar != null) 'baseSugar': baseSugar,
      if (baseSodium != null) 'baseSodium': baseSodium,
      if (nutritionTier != null) 'nutritionTier': nutritionTier?.name,
      if (nutritionAttribution != null) 'nutritionAttribution': nutritionAttribution,
      if (recipeAssumptions != null) 'recipeAssumptions': recipeAssumptions,
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
      fiber: entity.fiber,
      sodium: entity.sodium,
      servingSize: entity.servingSize,
      foodId: entity.foodId,
      baseServingSize: entity.baseServingSize,
      baseCalories: entity.baseCalories,
      baseProtein: entity.baseProtein,
      baseCarbohydrates: entity.baseCarbohydrates,
      baseFats: entity.baseFats,
      baseFiber: entity.baseFiber,
      baseSugar: entity.baseSugar,
      baseSodium: entity.baseSodium,
      nutritionTier: entity.nutritionTier,
      nutritionAttribution: entity.nutritionAttribution,
      recipeAssumptions: entity.recipeAssumptions,
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
      fiber: fiber,
      sodium: sodium,
      servingSize: servingSize,
      foodId: foodId,
      baseServingSize: baseServingSize,
      baseCalories: baseCalories,
      baseProtein: baseProtein,
      baseCarbohydrates: baseCarbohydrates,
      baseFats: baseFats,
      baseFiber: baseFiber,
      baseSugar: baseSugar,
      baseSodium: baseSodium,
      nutritionTier: nutritionTier,
      nutritionAttribution: nutritionAttribution,
      recipeAssumptions: recipeAssumptions,
      consumedAt: consumedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus,
    );
  }
}
