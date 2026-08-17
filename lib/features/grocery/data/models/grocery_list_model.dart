import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/grocery_list_entity.dart';
import 'grocery_item_model.dart';

class GroceryListModel {
  final String id;
  final String userId;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<GroceryItemModel> items;
  final int totalItems;
  final int purchasedItems;
  final int remainingItems;
  final double estimatedTotalCalories;
  final double estimatedTotalProtein;
  final double estimatedTotalCarbs;
  final double estimatedTotalFat;

  const GroceryListModel({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.items,
    required this.totalItems,
    required this.purchasedItems,
    required this.remainingItems,
    this.estimatedTotalCalories = 0.0,
    this.estimatedTotalProtein = 0.0,
    this.estimatedTotalCarbs = 0.0,
    this.estimatedTotalFat = 0.0,
  });

  factory GroceryListModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, [List<GroceryItemModel> listItems = const []]) {
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

    return GroceryListModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      generatedAt: parseDateTime(data['generatedAt']) ?? DateTime.now(),
      periodStart: parseDateTime(data['periodStart']) ?? DateTime.now(),
      periodEnd: parseDateTime(data['periodEnd']) ?? DateTime.now().add(const Duration(days: 7)),
      items: listItems,
      totalItems: data['totalItems'] as int? ?? listItems.length,
      purchasedItems: data['purchasedItems'] as int? ?? listItems.where((i) => i.isPurchased).length,
      remainingItems: data['remainingItems'] as int? ?? listItems.where((i) => !i.isPurchased).length,
      estimatedTotalCalories: parseDouble(data['estimatedTotalCalories']),
      estimatedTotalProtein: parseDouble(data['estimatedTotalProtein']),
      estimatedTotalCarbs: parseDouble(data['estimatedTotalCarbs']),
      estimatedTotalFat: parseDouble(data['estimatedTotalFat']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'totalItems': totalItems,
      'purchasedItems': purchasedItems,
      'remainingItems': remainingItems,
      'estimatedTotalCalories': estimatedTotalCalories,
      'estimatedTotalProtein': estimatedTotalProtein,
      'estimatedTotalCarbs': estimatedTotalCarbs,
      'estimatedTotalFat': estimatedTotalFat,
    };
  }

  factory GroceryListModel.fromEntity(GroceryListEntity entity) {
    return GroceryListModel(
      id: entity.id,
      userId: entity.userId,
      generatedAt: entity.generatedAt,
      periodStart: entity.periodStart,
      periodEnd: entity.periodEnd,
      items: entity.items.map((i) => GroceryItemModel.fromEntity(i)).toList(),
      totalItems: entity.totalItems,
      purchasedItems: entity.purchasedItems,
      remainingItems: entity.remainingItems,
      estimatedTotalCalories: entity.estimatedTotalCalories,
      estimatedTotalProtein: entity.estimatedTotalProtein,
      estimatedTotalCarbs: entity.estimatedTotalCarbs,
      estimatedTotalFat: entity.estimatedTotalFat,
    );
  }

  GroceryListEntity toEntity() {
    return GroceryListEntity(
      id: id,
      userId: userId,
      generatedAt: generatedAt,
      periodStart: periodStart,
      periodEnd: periodEnd,
      items: items.map((i) => i.toEntity()).toList(),
      totalItems: totalItems,
      purchasedItems: purchasedItems,
      remainingItems: remainingItems,
      estimatedTotalCalories: estimatedTotalCalories,
      estimatedTotalProtein: estimatedTotalProtein,
      estimatedTotalCarbs: estimatedTotalCarbs,
      estimatedTotalFat: estimatedTotalFat,
    );
  }
}
