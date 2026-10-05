import 'dart:typed_data';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';

abstract class IFoodScanRepository {
  /// Analyzes a food image via AI vision, detects foods with portions & confidence,
  /// matches them against the FitFuel database [foodCatalog], and returns a [FoodScanResult].
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
  });
}
