import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/grocery_preferences_entity.dart';

class GroceryPreferencesModel {
  final String preferredStore;
  final double budgetLimit;
  final String preferredUnits;
  final bool showImages;
  final bool groupByCategory;
  final bool includePantryItems;
  final bool autoGenerateWeeklyList;
  final bool notifyWhenShoppingListReady;

  const GroceryPreferencesModel({
    this.preferredStore = '',
    this.budgetLimit = 0.0,
    this.preferredUnits = 'metric',
    this.showImages = true,
    this.groupByCategory = true,
    this.includePantryItems = true,
    this.autoGenerateWeeklyList = false,
    this.notifyWhenShoppingListReady = false,
  });

  factory GroceryPreferencesModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return GroceryPreferencesModel(
      preferredStore: data['preferredStore'] as String? ?? '',
      budgetLimit: parseDouble(data['budgetLimit']),
      preferredUnits: data['preferredUnits'] as String? ?? 'metric',
      showImages: data['showImages'] as bool? ?? true,
      groupByCategory: data['groupByCategory'] as bool? ?? true,
      includePantryItems: data['includePantryItems'] as bool? ?? true,
      autoGenerateWeeklyList: data['autoGenerateWeeklyList'] as bool? ?? false,
      notifyWhenShoppingListReady: data['notifyWhenShoppingListReady'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'preferredStore': preferredStore,
      'budgetLimit': budgetLimit,
      'preferredUnits': preferredUnits,
      'showImages': showImages,
      'groupByCategory': groupByCategory,
      'includePantryItems': includePantryItems,
      'autoGenerateWeeklyList': autoGenerateWeeklyList,
      'notifyWhenShoppingListReady': notifyWhenShoppingListReady,
    };
  }

  factory GroceryPreferencesModel.fromEntity(GroceryPreferencesEntity entity) {
    return GroceryPreferencesModel(
      preferredStore: entity.preferredStore,
      budgetLimit: entity.budgetLimit,
      preferredUnits: entity.preferredUnits,
      showImages: entity.showImages,
      groupByCategory: entity.groupByCategory,
      includePantryItems: entity.includePantryItems,
      autoGenerateWeeklyList: entity.autoGenerateWeeklyList,
      notifyWhenShoppingListReady: entity.notifyWhenShoppingListReady,
    );
  }

  GroceryPreferencesEntity toEntity() {
    return GroceryPreferencesEntity(
      preferredStore: preferredStore,
      budgetLimit: budgetLimit,
      preferredUnits: preferredUnits,
      showImages: showImages,
      groupByCategory: groupByCategory,
      includePantryItems: includePantryItems,
      autoGenerateWeeklyList: autoGenerateWeeklyList,
      notifyWhenShoppingListReady: notifyWhenShoppingListReady,
    );
  }
}
