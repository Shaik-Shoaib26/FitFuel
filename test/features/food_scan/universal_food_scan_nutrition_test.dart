import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';

class _FakeAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'Network connection failed',
    );
  }

  @override
  void close({bool force = false}) {}
}

String _geminiResponse(String innerJson) {
  final escaped = jsonEncode(innerJson);
  return '{"candidates": [{"content": {"parts": [{"text": $escaped}]}}]}';
}

void main() {
  const catalog = [
    FoodEntity(
      id: 'food_apple',
      name: 'Apple',
      category: 'Fruits',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 52.0,
      protein: 0.3,
      carbohydrates: 14.0,
      fats: 0.2,
      fiber: 2.4,
      sugar: 10.0,
      sodium: 1.0,
    ),
    FoodEntity(
      id: 'food_banana',
      name: 'Banana',
      category: 'Fruits',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 89.0,
      protein: 1.1,
      carbohydrates: 23.0,
      fats: 0.3,
      fiber: 2.6,
      sugar: 12.0,
      sodium: 1.0,
    ),
    FoodEntity(
      id: 'food_chapati',
      name: 'Chapati',
      category: 'Grains',
      servingSize: 40.0,
      servingUnit: 'g',
      calories: 104.0,
      protein: 3.1,
      carbohydrates: 20.0,
      fats: 1.5,
      fiber: 2.3,
      sugar: 0.2,
      sodium: 110.0,
    ),
    FoodEntity(
      id: 'food_rice',
      name: 'Basmati Rice',
      category: 'Grains',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 130.0,
      protein: 2.7,
      carbohydrates: 28.0,
      fats: 0.3,
      fiber: 0.4,
      sugar: 0.1,
      sodium: 1.0,
    ),
    FoodEntity(
      id: 'food_dosa',
      name: 'Dosa',
      category: 'Breakfast',
      servingSize: 80.0,
      servingUnit: 'g',
      calories: 168.0,
      protein: 3.9,
      carbohydrates: 29.0,
      fats: 3.7,
      fiber: 1.5,
      sugar: 0.5,
      sodium: 180.0,
    ),
    FoodEntity(
      id: 'food_chicken',
      name: 'Grilled Chicken Breast',
      category: 'Meat',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 165.0,
      protein: 31.0,
      carbohydrates: 0.0,
      fats: 3.6,
      fiber: 0.0,
      sugar: 0.0,
      sodium: 74.0,
    ),
  ];

  late Dio dio;
  late _FakeAdapter adapter;
  late FoodScanRemoteDataSource dataSource;
  late FoodScanRepositoryImpl repository;
  final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    dataSource = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
    repository = FoodScanRepositoryImpl(remoteDataSource: dataSource);
  });

  group('Phase 35.5 — Universal Food Scan Nutrition Tests', () {
    test('1. Single Food — Apple: correctly identifies, matches DB, exposes all 4 macros', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Red Apple",
      "estimated_grams": 185,
      "confidence": 0.95,
      "estimated_nutrition": {
        "calories": 95,
        "protein_g": 0.5,
        "carbs_g": 25.0,
        "fat_g": 0.3
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/apple.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(result.foods.length, 1);
      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      expect(food.displayName, 'Apple');
      expect(food.estimatedAmount, 185.0);

      // Database values scaled to 185g (1.85x 100g serving)
      expect(food.calories, closeTo(52.0 * 1.85, 0.01));
      expect(food.protein, closeTo(0.3 * 1.85, 0.01));
      expect(food.carbs, closeTo(14.0 * 1.85, 0.01));
      expect(food.fats, closeTo(0.2 * 1.85, 0.01));
      expect(food.hasNutrition, isTrue);
    });

    test('2. Single Food — Banana: correctly identifies, matches DB, exposes all 4 macros', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Fresh Banana",
      "estimated_grams": 120,
      "confidence": 0.93,
      "estimated_nutrition": {
        "calories": 105,
        "protein_g": 1.3,
        "carbs_g": 27.0,
        "fat_g": 0.4
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/banana.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      expect(food.calories, closeTo(89.0 * 1.20, 0.01));
      expect(food.protein, closeTo(1.1 * 1.20, 0.01));
      expect(food.carbs, closeTo(23.0 * 1.20, 0.01));
      expect(food.fats, closeTo(0.3 * 1.20, 0.01));
      expect(food.hasNutrition, isTrue);
    });

    test('3. Single Food — Chapati: correctly matches alias and scales 40g serving', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Wheat Roti",
      "estimated_grams": 80,
      "confidence": 0.90,
      "estimated_nutrition": {
        "calories": 200,
        "protein_g": 6.0,
        "carbs_g": 38.0,
        "fat_g": 3.0
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/roti.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      expect(food.displayName, 'Chapati');
      // 80g is 2x 40g serving
      expect(food.calories, closeTo(104.0 * 2.0, 0.01));
      expect(food.protein, closeTo(3.1 * 2.0, 0.01));
      expect(food.carbs, closeTo(20.0 * 2.0, 0.01));
      expect(food.fats, closeTo(1.5 * 2.0, 0.01));
    });

    test('4. Single Food — Rice: correctly matches Basmati Rice from DB', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Basmati Rice",
      "estimated_grams": 150,
      "confidence": 0.95,
      "estimated_nutrition": {
        "calories": 190,
        "protein_g": 4.0,
        "carbs_g": 40.0,
        "fat_g": 0.5
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/rice.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      expect(food.calories, closeTo(130.0 * 1.5, 0.01));
      expect(food.protein, closeTo(2.7 * 1.5, 0.01));
      expect(food.carbs, closeTo(28.0 * 1.5, 0.01));
      expect(food.fats, closeTo(0.3 * 1.5, 0.01));
    });

    test('5. Single Food — Dosa: correctly matches Dosa from DB', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Crispy Dosa",
      "estimated_grams": 160,
      "confidence": 0.91,
      "estimated_nutrition": {
        "calories": 320,
        "protein_g": 7.5,
        "carbs_g": 55.0,
        "fat_g": 7.0
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/dosa.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      // 160g is 2x 80g serving
      expect(food.calories, closeTo(168.0 * 2.0, 0.01));
      expect(food.protein, closeTo(3.9 * 2.0, 0.01));
      expect(food.carbs, closeTo(29.0 * 2.0, 0.01));
      expect(food.fats, closeTo(3.7 * 2.0, 0.01));
    });

    test('6. Single Food — Chicken: correctly matches Grilled Chicken Breast', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Grilled Chicken",
      "estimated_grams": 200,
      "confidence": 0.94,
      "estimated_nutrition": {
        "calories": 330,
        "protein_g": 60.0,
        "carbs_g": 0.0,
        "fat_g": 7.0
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/chicken.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isTrue);
      // 200g is 2x 100g serving
      expect(food.calories, closeTo(330.0, 0.01));
      expect(food.protein, closeTo(62.0, 0.01));
      expect(food.carbs, closeTo(0.0, 0.01));
      expect(food.fats, closeTo(7.2, 0.01));
    });

    test('7. Mixed Meal — Multi-food meal calculates total calories, protein, carbs, fat', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Chapati",
      "estimated_grams": 80,
      "confidence": 0.90,
      "estimated_nutrition": {
        "calories": 208,
        "protein_g": 6.2,
        "carbs_g": 40.0,
        "fat_g": 3.0
      }
    },
    {
      "name": "Vegetable Curry",
      "estimated_grams": 180,
      "confidence": 0.85,
      "estimated_nutrition": {
        "calories": 210,
        "protein_g": 6.5,
        "carbs_g": 24.0,
        "fat_g": 10.2
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/mixed_meal.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(result.foods.length, 2);
      expect(result.foods[0].isDatabaseMatch, isTrue); // Chapati in catalog
      expect(result.foods[1].isDatabaseMatch, isFalse); // Vegetable Curry not in this small catalog
      expect(result.foods[1].isAiEstimated, isTrue); // Fallback to AI estimate

      // Meal Totals
      final expectedCalories = result.foods[0].scaledCalories + result.foods[1].scaledCalories;
      final expectedProtein = result.foods[0].scaledProtein + result.foods[1].scaledProtein;
      final expectedCarbs = result.foods[0].scaledCarbs + result.foods[1].scaledCarbs;
      final expectedFats = result.foods[0].scaledFats + result.foods[1].scaledFats;

      expect(result.totalCalories, closeTo(expectedCalories, 0.01));
      expect(result.totalProtein, closeTo(expectedProtein, 0.01));
      expect(result.totalCarbs, closeTo(expectedCarbs, 0.01));
      expect(result.totalFats, closeTo(expectedFats, 0.01));
    });

    test('8. Unmatched recognizable food uses AI-estimated fallback nutrition', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('''
{
  "foods": [
    {
      "name": "Spinach Ricotta Lasagna",
      "estimated_grams": 250,
      "confidence": 0.88,
      "estimated_nutrition": {
        "calories": 380,
        "protein_g": 18.0,
        "carbs_g": 42.0,
        "fat_g": 16.0
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/lasagna.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      final food = result.foods.first;
      expect(food.isDatabaseMatch, isFalse);
      expect(food.isAiEstimated, isTrue);
      expect(food.calories, 380.0);
      expect(food.protein, 18.0);
      expect(food.carbs, 42.0);
      expect(food.fats, 16.0);
      expect(food.nutritionSourceLabel, contains('AI Estimate'));
      expect(food.isNutritionUncertain, isTrue);
    });

    test('9. AI-estimated fallback scales correctly when portion is modified', () async {
      const candidate = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Vegetable Curry',
        confidence: 0.85,
        estimatedAmount: 180.0,
        originalEstimatedAmount: 180.0,
        aiEstimatedNutrition: EstimatedNutrition(
          calories: 210.0,
          protein: 6.5,
          carbs: 24.0,
          fat: 10.2,
        ),
      );

      // Increase portion from 180g to 270g (1.5x)
      final scaled = candidate.copyWith(estimatedAmount: 270.0);
      expect(scaled.calories, closeTo(210.0 * 1.5, 0.01));
      expect(scaled.protein, closeTo(6.5 * 1.5, 0.01));
      expect(scaled.carbs, closeTo(24.0 * 1.5, 0.01));
      expect(scaled.fats, closeTo(10.2 * 1.5, 0.01));
    });

    test('10. No-food image returns empty result without fabricating macros', () async {
      adapter.handler = (opts) => ResponseBody.fromString(
            _geminiResponse('{"foods": []}'),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );

      final result = await repository.scanFoodImage(
        imagePath: '/tmp/empty.jpg',
        imageBytes: dummyBytes,
        foodCatalog: catalog,
      );

      expect(result.isEmpty, isTrue);
      expect(result.totalCalories, 0.0);
      expect(result.totalProtein, 0.0);
      expect(result.totalCarbs, 0.0);
      expect(result.totalFats, 0.0);
    });

    test('11. Low-confidence food flags isLowConfidence and requests confirmation', () {
      const candidate = DetectedFoodCandidate(
        id: 'c_low',
        detectedName: 'Mystery Stew',
        confidence: 0.45, // Weak confidence
        estimatedAmount: 150.0,
        aiEstimatedNutrition: EstimatedNutrition(
          calories: 180.0,
          protein: 8.0,
          carbs: 20.0,
          fat: 6.0,
        ),
      );

      expect(candidate.isLowConfidence, isTrue);
      expect(candidate.confidenceLevel, ScanConfidenceLevel.low);
      expect(candidate.isNutritionUncertain, isTrue);
    });

    test('12. Missing protein field marks nutrition as null/uncertain', () {
      final json = {
        'calories': 200,
        // protein_g is missing/null
        'carbs_g': 25.0,
        'fat_g': 5.0,
      };

      final nutrition = EstimatedNutrition.fromJson(json);
      expect(nutrition, isNull);

      const candidate = DetectedFoodCandidate(
        id: 'c_miss_p',
        detectedName: 'Incomplete Item',
        confidence: 0.90,
        estimatedAmount: 100.0,
        aiEstimatedNutrition: null, // Because parsing returned null
      );

      expect(candidate.calories, isNull);
      expect(candidate.protein, isNull);
      expect(candidate.carbs, isNull);
      expect(candidate.fats, isNull);
      expect(candidate.hasNutrition, isFalse);
      expect(candidate.isNutritionUncertain, isTrue);
    });

    test('13. Missing carbs field marks nutrition as null/uncertain', () {
      final json = {
        'calories': 200,
        'protein_g': 15.0,
        // carbs_g is missing
        'fat_g': 5.0,
      };

      final nutrition = EstimatedNutrition.fromJson(json);
      expect(nutrition, isNull);
    });

    test('14. Missing fat field marks nutrition as null/uncertain', () {
      final json = {
        'calories': 200,
        'protein_g': 15.0,
        'carbs_g': 30.0,
        // fat_g is missing
      };

      final nutrition = EstimatedNutrition.fromJson(json);
      expect(nutrition, isNull);
    });

    test('15. True zero-fat food preserves 0.0g fat and is distinct from null', () {
      final json = {
        'calories': 90,
        'protein_g': 0.0,
        'carbs_g': 23.0,
        'fat_g': 0.0, // Explicit zero fat
      };

      final nutrition = EstimatedNutrition.fromJson(json);
      expect(nutrition, isNotNull);
      expect(nutrition!.fat, 0.0);

      final candidate = DetectedFoodCandidate(
        id: 'c_zero_fat',
        detectedName: 'Gummy Candy',
        confidence: 0.92,
        estimatedAmount: 30.0,
        aiEstimatedNutrition: nutrition,
      );

      expect(candidate.fats, isNotNull);
      expect(candidate.fats, 0.0);
      expect(candidate.protein, 0.0);
      expect(candidate.hasNutrition, isTrue);
    });

    test('16. Multi-food totals: calculates exact sums of all 4 macros', () {
      const c1 = DetectedFoodCandidate(
        id: '1',
        detectedName: 'Food A',
        confidence: 0.90,
        estimatedAmount: 100.0,
        aiEstimatedNutrition: EstimatedNutrition(
          calories: 150.0,
          protein: 10.0,
          carbs: 20.0,
          fat: 3.0,
        ),
      );

      const c2 = DetectedFoodCandidate(
        id: '2',
        detectedName: 'Food B',
        confidence: 0.90,
        estimatedAmount: 100.0,
        aiEstimatedNutrition: EstimatedNutrition(
          calories: 250.0,
          protein: 15.0,
          carbs: 30.0,
          fat: 8.0,
        ),
      );

      final result = FoodScanResult(
        id: 'res_multi',
        foods: [c1, c2],
        overallConfidence: 0.90,
        scannedAt: DateTime.now(),
      );

      expect(result.totalCalories, 400.0);
      expect(result.totalProtein, 25.0);
      expect(result.totalCarbs, 50.0);
      expect(result.totalFats, 11.0);
    });
  });
}
