import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/food_entity.dart';

class FoodModel {
  final String id;
  final String name;
  final String category;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double fiber;
  final double sugar;
  final double sodium;
  final bool isCustom;
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Expanded fields for Phase 23.1
  final String? imageAsset;
  final List<String> dietaryTags;
  final List<String> mealTypes;
  final bool isIndian;
  final bool isVegetarian;
  final bool isVegan;

  const FoodModel({
    required this.id,
    required this.name,
    required this.category,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.isCustom,
    required this.isFavorite,
    this.createdAt,
    this.updatedAt,
    this.imageAsset,
    this.dietaryTags = const [],
    this.mealTypes = const [],
    this.isIndian = false,
    this.isVegetarian = false,
    this.isVegan = false,
  });

  factory FoodModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    List<String> parseList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return FoodModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Custom',
      servingSize: parseDouble(data['servingSize']),
      servingUnit: data['servingUnit'] as String? ?? 'g',
      calories: parseDouble(data['calories']),
      protein: parseDouble(data['protein']),
      carbohydrates: parseDouble(data['carbohydrates']),
      fats: parseDouble(data['fats']),
      fiber: parseDouble(data['fiber']),
      sugar: parseDouble(data['sugar']),
      sodium: parseDouble(data['sodium']),
      isCustom: data['isCustom'] as bool? ?? false,
      isFavorite: data['isFavorite'] as bool? ?? false,
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
      imageAsset: data['imageAsset'] as String?,
      dietaryTags: parseList(data['dietaryTags']),
      mealTypes: parseList(data['mealTypes']),
      isIndian: data['isIndian'] as bool? ?? false,
      isVegetarian: data['isVegetarian'] as bool? ?? false,
      isVegan: data['isVegan'] as bool? ?? false,
    );
  }

  factory FoodModel.fromMap(Map<String, dynamic> data, String id) {
    double parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> parseList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return FoodModel(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Custom',
      servingSize: parseDouble(data['servingSize']),
      servingUnit: data['servingUnit'] as String? ?? 'g',
      calories: parseDouble(data['calories']),
      protein: parseDouble(data['protein']),
      carbohydrates: parseDouble(data['carbohydrates']),
      fats: parseDouble(data['fats']),
      fiber: parseDouble(data['fiber']),
      sugar: parseDouble(data['sugar']),
      sodium: parseDouble(data['sodium']),
      isCustom: data['isCustom'] as bool? ?? false,
      isFavorite: data['isFavorite'] as bool? ?? false,
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
      imageAsset: data['imageAsset'] as String?,
      dietaryTags: parseList(data['dietaryTags']),
      mealTypes: parseList(data['mealTypes']),
      isIndian: data['isIndian'] as bool? ?? false,
      isVegetarian: data['isVegetarian'] as bool? ?? false,
      isVegan: data['isVegan'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'isCustom': isCustom,
      'isFavorite': isFavorite,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'imageAsset': imageAsset,
      'dietaryTags': dietaryTags,
      'mealTypes': mealTypes,
      'isIndian': isIndian,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
    };
  }

  factory FoodModel.fromEntity(FoodEntity entity) {
    return FoodModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      servingSize: entity.servingSize,
      servingUnit: entity.servingUnit,
      calories: entity.calories,
      protein: entity.protein,
      carbohydrates: entity.carbohydrates,
      fats: entity.fats,
      fiber: entity.fiber,
      sugar: entity.sugar,
      sodium: entity.sodium,
      isCustom: entity.isCustom,
      isFavorite: entity.isFavorite,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      imageAsset: entity.imageAsset,
      dietaryTags: entity.dietaryTags,
      mealTypes: entity.mealTypes,
      isIndian: entity.isIndian,
      isVegetarian: entity.isVegetarian,
      isVegan: entity.isVegan,
    );
  }

  FoodEntity toEntity() {
    return FoodEntity(
      id: id,
      name: name,
      category: category,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      isCustom: isCustom,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
      imageAsset: imageAsset,
      dietaryTags: dietaryTags,
      mealTypes: mealTypes,
      isIndian: isIndian,
      isVegetarian: isVegetarian,
      isVegan: isVegan,
    );
  }
}
