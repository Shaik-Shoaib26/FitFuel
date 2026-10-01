import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/sync/sync_status.dart';
import '../../domain/entities/grocery_item_entity.dart';

class GroceryItemModel {
  final String id;
  final String? foodId;
  final String foodName;
  final String category;
  final double quantity;
  final String unit;
  final double estimatedWeight;
  final double estimatedCalories;
  final double estimatedProtein;
  final double estimatedCarbs;
  final double estimatedFat;
  final String? imageUrl;
  final bool isPurchased;
  final bool isPantryItem;
  final DateTime addedAt;
  final DateTime? purchasedAt;
  final String? notes;
  final SyncStatus syncStatus;

  const GroceryItemModel({
    required this.id,
    this.foodId,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    this.estimatedWeight = 0.0,
    this.estimatedCalories = 0.0,
    this.estimatedProtein = 0.0,
    this.estimatedCarbs = 0.0,
    this.estimatedFat = 0.0,
    this.imageUrl,
    this.isPurchased = false,
    this.isPantryItem = false,
    required this.addedAt,
    this.purchasedAt,
    this.notes,
    this.syncStatus = SyncStatus.synced,
  });

  factory GroceryItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final status = doc.metadata.hasPendingWrites ? SyncStatus.pending : SyncStatus.synced;
    return GroceryItemModel.fromMap(doc.data() ?? {}, doc.id, status);
  }

  factory GroceryItemModel.fromMap(Map<String, dynamic> data, String id, [SyncStatus syncStatus = SyncStatus.synced]) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return GroceryItemModel(
      id: id,
      foodId: data['foodId'] as String?,
      foodName: data['foodName'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      quantity: parseDouble(data['quantity']),
      unit: data['unit'] as String? ?? 'g',
      estimatedWeight: parseDouble(data['estimatedWeight']),
      estimatedCalories: parseDouble(data['estimatedCalories']),
      estimatedProtein: parseDouble(data['estimatedProtein']),
      estimatedCarbs: parseDouble(data['estimatedCarbs']),
      estimatedFat: parseDouble(data['estimatedFat']),
      imageUrl: data['imageUrl'] as String?,
      isPurchased: data['isPurchased'] as bool? ?? false,
      isPantryItem: data['isPantryItem'] as bool? ?? false,
      addedAt: parseDateTime(data['addedAt']) ?? DateTime.now(),
      purchasedAt: parseDateTime(data['purchasedAt']),
      notes: data['notes'] as String?,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'foodId': foodId,
      'foodName': foodName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'estimatedWeight': estimatedWeight,
      'estimatedCalories': estimatedCalories,
      'estimatedProtein': estimatedProtein,
      'estimatedCarbs': estimatedCarbs,
      'estimatedFat': estimatedFat,
      'imageUrl': imageUrl,
      'isPurchased': isPurchased,
      'isPantryItem': isPantryItem,
      'addedAt': Timestamp.fromDate(addedAt),
      'purchasedAt': purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : null,
      'notes': notes,
    };
  }

  factory GroceryItemModel.fromEntity(GroceryItemEntity entity) {
    return GroceryItemModel(
      id: entity.id,
      foodId: entity.foodId,
      foodName: entity.foodName,
      category: entity.category,
      quantity: entity.quantity,
      unit: entity.unit,
      estimatedWeight: entity.estimatedWeight,
      estimatedCalories: entity.estimatedCalories,
      estimatedProtein: entity.estimatedProtein,
      estimatedCarbs: entity.estimatedCarbs,
      estimatedFat: entity.estimatedFat,
      imageUrl: entity.imageUrl,
      isPurchased: entity.isPurchased,
      isPantryItem: entity.isPantryItem,
      addedAt: entity.addedAt,
      purchasedAt: entity.purchasedAt,
      notes: entity.notes,
      syncStatus: entity.syncStatus,
    );
  }

  GroceryItemEntity toEntity() {
    return GroceryItemEntity(
      id: id,
      foodId: foodId,
      foodName: foodName,
      category: category,
      quantity: quantity,
      unit: unit,
      estimatedWeight: estimatedWeight,
      estimatedCalories: estimatedCalories,
      estimatedProtein: estimatedProtein,
      estimatedCarbs: estimatedCarbs,
      estimatedFat: estimatedFat,
      imageUrl: imageUrl,
      isPurchased: isPurchased,
      isPantryItem: isPantryItem,
      addedAt: addedAt,
      purchasedAt: purchasedAt,
      notes: notes,
      syncStatus: syncStatus,
    );
  }
}
