import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/pantry_item_entity.dart';

class PantryItemModel {
  final String id;
  final String? foodId;
  final String foodName;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final String? imageUrl;
  final DateTime addedAt;

  const PantryItemModel({
    required this.id,
    this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    this.imageUrl,
    required this.addedAt,
  });

  factory PantryItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
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

    return PantryItemModel(
      id: doc.id,
      foodId: data['foodId'] as String?,
      foodName: data['foodName'] as String? ?? '',
      quantity: parseDouble(data['quantity']),
      unit: data['unit'] as String? ?? 'g',
      expiryDate: parseDateTime(data['expiryDate']) ?? DateTime.now(),
      imageUrl: data['imageUrl'] as String?,
      addedAt: parseDateTime(data['addedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'foodId': foodId,
      'foodName': foodName,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'imageUrl': imageUrl,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  factory PantryItemModel.fromEntity(PantryItemEntity entity) {
    return PantryItemModel(
      id: entity.id,
      foodId: entity.foodId,
      foodName: entity.foodName,
      quantity: entity.quantity,
      unit: entity.unit,
      expiryDate: entity.expiryDate,
      imageUrl: entity.imageUrl,
      addedAt: entity.addedAt,
    );
  }

  PantryItemEntity toEntity() {
    return PantryItemEntity(
      id: id,
      foodId: foodId,
      foodName: foodName,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      imageUrl: imageUrl,
      addedAt: addedAt,
    );
  }
}
