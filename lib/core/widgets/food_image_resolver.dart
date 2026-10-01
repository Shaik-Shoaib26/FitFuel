import 'package:flutter/material.dart';
import 'fitfuel_food_photo.dart';
import '../constants/app_constants.dart';
import '../../features/food/domain/entities/food_entity.dart';
import '../../features/food/data/models/food_model.dart';
import '../../features/food/data/food_image_manifest.dart';
import '../../features/food/data/datasources/predefined_food_data.dart';

/// Centralized Real Food Photography System for FitFuel
class FoodImageResolver {
  /// List of actually existing local image assets to prevent Web 404s
  static const Set<String> _existingLocalAssets = {};

  /// Category Default Imagery Fallbacks
  static const Map<String, String> _categoryImageMap = {
    'indian':
        'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=600&q=80',
    'breakfast':
        'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=600&q=80',
    'lunch':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
    'dinner':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
    'snacks':
        'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
    'fruits':
        'https://images.unsplash.com/photo-1490474418585-ba9bad8fd0ea?auto=format&fit=crop&w=600&q=80',
    'vegetables':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80',
    'protein':
        'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=600&q=80',
    'beverages':
        'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?auto=format&fit=crop&w=600&q=80',
    'dairy':
        'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80',
    'nuts & seeds':
        'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80',
    'grains':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
  };

  /// Resolve real food image URL for a food entity or food name (Legacy name helper)
  static String resolveImageUrl(dynamic foodInput) {
    return resolve(foodInput);
  }

  /// Helper to normalize local asset paths
  static String _normalizeLocalPath(String path) {
    String p = path.trim();
    while (p.startsWith('assets/assets/')) {
      p = p.substring(7);
    }
    if (p.startsWith('images/foods/')) {
      p = 'assets/$p';
    }
    if (!p.startsWith('assets/') &&
        !p.startsWith('http://') &&
        !p.startsWith('https://')) {
      p = 'assets/images/foods/$p';
    }
    while (p.startsWith('assets/assets/')) {
      p = p.substring(7);
    }
    return p;
  }

  /// Resolves any food input to either a valid network URL or a standardized asset path
  static String resolve(dynamic foodInput) {
    if (foodInput == null) {
      return '';
    }
    if (foodInput is String && foodInput.trim().isEmpty) {
      return '';
    }

    String foodId = '';
    String foodName = '';
    String category = '';
    String? explicitImageAsset;

    if (foodInput is FoodEntity) {
      foodId = foodInput.id;
      foodName = foodInput.name;
      category = foodInput.category;
      explicitImageAsset = foodInput.imageAsset;
    } else if (foodInput is FoodModel) {
      foodId = foodInput.id;
      foodName = foodInput.name;
      category = foodInput.category;
      explicitImageAsset = foodInput.imageAsset;
    } else if (foodInput is String) {
      if (foodInput.startsWith('http://') || foodInput.startsWith('https://')) {
        return foodInput;
      }
      foodName = foodInput;
    }

    // 1. Check for explicit image asset
    if (explicitImageAsset != null && explicitImageAsset.isNotEmpty) {
      if (explicitImageAsset.startsWith('http://') ||
          explicitImageAsset.startsWith('https://')) {
        return explicitImageAsset;
      }
      final normalized = _normalizeLocalPath(explicitImageAsset);
      if (_existingLocalAssets.contains(normalized)) {
        return normalized;
      }
    }

    // 2. Try to resolve foodId from foodName if empty
    if (foodId.isEmpty && foodName.isNotEmpty) {
      if (foodName.startsWith('predefined_')) {
        foodId = foodName;
      } else {
        final cleanName = foodName.toLowerCase().trim();
        for (final food in PredefinedFoodData.foods) {
          if (food.name.toLowerCase() == cleanName) {
            foodId = food.id;
            break;
          }
        }
        if (foodId.isEmpty) {
          for (final food in PredefinedFoodData.foods) {
            final idWithoutPrefix =
                food.id.substring('predefined_'.length).replaceAll('_', ' ');
            if (idWithoutPrefix == cleanName) {
              foodId = food.id;
              break;
            }
          }
        }
        if (foodId.isEmpty) {
          for (final food in PredefinedFoodData.foods) {
            if (food.name.toLowerCase().contains(cleanName) ||
                cleanName.contains(food.name.toLowerCase())) {
              foodId = food.id;
              break;
            }
          }
        }
      }
    }

    // 3. Check Manifest mapping by stable food ID
    if (foodId.isNotEmpty && FoodImageManifest.manifest.containsKey(foodId)) {
      return FoodImageManifest.manifest[foodId]!.imagePathOrUrl;
    }

    // 4. Generic category fallback image
    final categoryLower = category.toLowerCase().trim();
    if (_categoryImageMap.containsKey(categoryLower)) {
      return _categoryImageMap[categoryLower]!;
    }
    for (final key in _categoryImageMap.keys) {
      if (categoryLower.contains(key)) {
        return _categoryImageMap[key]!;
      }
    }

    // 5. Global FitFuel food placeholder Unsplash URL
    return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=600&q=80';
  }
}

/// Existing food lookup API with an optional explicit asset/network source.
class FoodImageCard extends StatelessWidget {
  final dynamic food;
  final double? width, height, aspectRatio;
  final double borderRadius;
  final BoxFit fit;
  final String? imageSource, semanticDescription;
  const FoodImageCard(
      {super.key,
      required this.food,
      this.width,
      this.height,
      this.aspectRatio,
      this.borderRadius = AppConstants.radiusImage,
      this.fit = BoxFit.cover,
      this.imageSource,
      this.semanticDescription});
  @override
  Widget build(BuildContext context) => FitFuelFoodPhoto(
      source: imageSource ?? FoodImageResolver.resolve(food),
      description: semanticDescription ??
          (food is FoodEntity
              ? food.name
              : food is FoodModel
                  ? food.name
                  : food is String
                      ? food
                      : 'Food photograph'),
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      borderRadius: borderRadius,
      fit: fit);
}
