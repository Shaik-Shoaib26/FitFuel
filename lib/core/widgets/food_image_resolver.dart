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
    static const Set<String> _existingLocalAssets = {
    'assets/images/foods/almond_butter.webp',
    'assets/images/foods/aloo_gobi.webp',
    'assets/images/foods/aloo_methi.webp',
    'assets/images/foods/aloo_paratha.webp',
    'assets/images/foods/amritsari_fish_tikka.webp',
    'assets/images/foods/appam.webp',
    'assets/images/foods/asparagus.webp',
    'assets/images/foods/baked_potato.webp',
    'assets/images/foods/baked_sweet_potato.webp',
    'assets/images/foods/beef_steak.webp',
    'assets/images/foods/beetroot.webp',
    'assets/images/foods/bhel_puri.webp',
    'assets/images/foods/bhindi_fry.webp',
    'assets/images/foods/black_chana_curry.webp',
    'assets/images/foods/black_coffee.webp',
    'assets/images/foods/blackberry.webp',
    'assets/images/foods/bottle_gourd.webp',
    'assets/images/foods/brazil_nuts.webp',
    'assets/images/foods/cabbage.webp',
    'assets/images/foods/cabbage_poriyal.webp',
    'assets/images/foods/caesar_salad.webp',
    'assets/images/foods/capsicum.webp',
    'assets/images/foods/cashews.webp',
    'assets/images/foods/cauliflower.webp',
    'assets/images/foods/chapati.webp',
    'assets/images/foods/cherries.webp',
    'assets/images/foods/chia_pudding.webp',
    'assets/images/foods/chia_seeds.webp',
    'assets/images/foods/chicken_kebab.webp',
    'assets/images/foods/chikoo.webp',
    'assets/images/foods/coconut_ladoo.webp',
    'assets/images/foods/coconut_water.webp',
    'assets/images/foods/curd.webp',
    'assets/images/foods/dal_fry.webp',
    'assets/images/foods/dal_tadka.webp',
    'assets/images/foods/dhokla.webp',
    'assets/images/foods/dragon_fruit.webp',
    'assets/images/foods/egg_bhurji.webp',
    'assets/images/foods/egg_biryani.webp',
    'assets/images/foods/egg_curry.webp',
    'assets/images/foods/egg_omelette.webp',
    'assets/images/foods/eggplant.webp',
    'assets/images/foods/fig.webp',
    'assets/images/foods/filter_coffee.webp',
    'assets/images/foods/firm_tofu.webp',
    'assets/images/foods/fish_curry.webp',
    'assets/images/foods/flax_seeds.webp',
    'assets/images/foods/gajar_halwa.webp',
    'assets/images/foods/garlic.webp',
    'assets/images/foods/ginger.webp',
    'assets/images/foods/gobhi_paratha.webp',
    'assets/images/foods/grapes.webp',
    'assets/images/foods/green_beans.webp',
    'assets/images/foods/green_peas.webp',
    'assets/images/foods/guava.webp',
    'assets/images/foods/gulab_jamun.webp',
    'assets/images/foods/hard_boiled_eggs.webp',
    'assets/images/foods/hazelnuts.webp',
    'assets/images/foods/idli.webp',
    'assets/images/foods/jalebi.webp',
    'assets/images/foods/jeera_rice.webp',
    'assets/images/foods/kale.webp',
    'assets/images/foods/khandvi.webp',
    'assets/images/foods/kiwi.webp',
    'assets/images/foods/lemon.webp',
    'assets/images/foods/lettuce.webp',
    'assets/images/foods/mango_lassi.webp',
    'assets/images/foods/matcha_tea.webp',
    'assets/images/foods/medu_vada.webp',
    'assets/images/foods/murukku.webp',
    'assets/images/foods/muskmelon.webp',
    'assets/images/foods/peach.webp',
    'assets/images/foods/peanut_butter.webp',
    'assets/images/foods/peanuts.webp',
    'assets/images/foods/pear.webp',
    'assets/images/foods/pecans.webp',
    'assets/images/foods/pesarattu.webp',
    'assets/images/foods/pistachios.webp',
    'assets/images/foods/plum.webp',
    'assets/images/foods/poha.webp',
    'assets/images/foods/pomegranate.webp',
    'assets/images/foods/pongal.webp',
    'assets/images/foods/poori.webp',
    'assets/images/foods/pumpkin.webp',
    'assets/images/foods/pumpkin_seeds.webp',
    'assets/images/foods/rajma_curry.webp',
    'assets/images/foods/rasgulla.webp',
    'assets/images/foods/raspberry.webp',
    'assets/images/foods/rava_dosa.webp',
    'assets/images/foods/rice_kheer.webp',
    'assets/images/foods/roti.webp',
    'assets/images/foods/sabudana_khichdi.webp',
    'assets/images/foods/sambar.webp',
    'assets/images/foods/scrambled_eggs.webp',
    'assets/images/foods/steamed_shrimp.webp',
    'assets/images/foods/sunflower_seeds.webp',
    'assets/images/foods/sweet_corn.webp',
    'assets/images/foods/sweet_lime.webp',
    'assets/images/foods/sweet_potato.webp',
    'assets/images/foods/tahini.webp',
    'assets/images/foods/tomato_juice.webp',
    'assets/images/foods/turkey_breast.webp',
    'assets/images/foods/upma.webp',
    'assets/images/foods/uttapam.webp',
    'assets/images/foods/veg_biryani.webp',
    'assets/images/foods/veg_pakora.webp',
    'assets/images/foods/walnuts.webp',
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
    String? explicitImageAsset;

    if (foodInput is FoodEntity) {
      foodId = foodInput.id;
      foodName = foodInput.name;
      explicitImageAsset = foodInput.imageAsset;
    } else if (foodInput is FoodModel) {
      foodId = foodInput.id;
      foodName = foodInput.name;
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
            if (food.name.toLowerCase().contains(cleanName)) {
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

    // 4. Unknown or unverified foods safely return empty string,
    // triggering FitFuelFoodPhoto clean branded fallback.
    return '';
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
