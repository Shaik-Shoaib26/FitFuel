import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_remote_datasource.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/data/services/food_matcher.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';

class _TestHttpAdapter implements HttpClientAdapter {
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

void main() {
  group('Phase 35.5 — Food Scan Vision AI Parsing Tests', () {
    test('1. Parses valid structured JSON response correctly', () {
      const jsonResponse = '''
{
  "foods": [
    {
      "name": "Basmati Rice",
      "estimated_grams": 180,
      "estimated_unit": "g",
      "confidence": 0.94,
      "visual_notes": "Steamed white long-grain rice"
    },
    {
      "name": "Chicken Tikka",
      "estimated_grams": 150,
      "estimated_unit": "g",
      "confidence": 0.88,
      "visual_notes": "Grilled spiced chicken pieces"
    }
  ]
}
''';
      final parsed = FoodScanRemoteDataSource.parseVisionResponse(jsonResponse);
      expect(parsed.length, 2);
      expect(parsed[0].name, 'Basmati Rice');
      expect(parsed[0].estimatedGrams, 180.0);
      expect(parsed[0].unit, 'g');
      expect(parsed[0].confidence, 0.94);
      expect(parsed[0].visualNotes, 'Steamed white long-grain rice');

      expect(parsed[1].name, 'Chicken Tikka');
      expect(parsed[1].estimatedGrams, 150.0);
      expect(parsed[1].confidence, 0.88);
    });

    test('2. Strips markdown code fences (```json ... ```) safely', () {
      const fencedJson = '''
```json
{
  "foods": [
    {
      "name": "Paneer Tikka",
      "estimated_grams": 120,
      "confidence": 0.91
    }
  ]
}
```
''';
      final parsed = FoodScanRemoteDataSource.parseVisionResponse(fencedJson);
      expect(parsed.length, 1);
      expect(parsed.first.name, 'Paneer Tikka');
      expect(parsed.first.estimatedGrams, 120.0);
    });

    test('3. Handles empty foods array when no food is detected', () {
      const emptyJson = '{"foods": []}';
      final parsed = FoodScanRemoteDataSource.parseVisionResponse(emptyJson);
      expect(parsed, isEmpty);
    });

    test('4. Clamps portion sizes to sensible physical bounds (5g to 2000g)', () {
      const extremePortionsJson = '''
{
  "foods": [
    {
      "name": "Salt",
      "estimated_grams": -50,
      "confidence": 1.5
    },
    {
      "name": "Feast Rice",
      "estimated_grams": 99999,
      "confidence": -0.2
    }
  ]
}
''';
      final parsed = FoodScanRemoteDataSource.parseVisionResponse(extremePortionsJson);
      expect(parsed.length, 2);
      // Negative grams defaults or clamps
      expect(parsed[0].estimatedGrams, 100.0); // Default fallback on invalid
      expect(parsed[0].confidence, 1.0); // Clamped max

      expect(parsed[1].estimatedGrams, 2000.0); // Clamped max
      expect(parsed[1].confidence, 0.0); // Clamped min
    });

    test('5. Throws FormatException on malformed JSON without crashing', () {
      const brokenJson = 'Not valid JSON at all';
      expect(
        () => FoodScanRemoteDataSource.parseVisionResponse(brokenJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Phase 35.5 — Food Database Matcher Tests', () {
    const catalog = [
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
        id: 'food_paneer_tikka',
        name: 'Paneer Tikka',
        category: 'Snacks',
        servingSize: 100.0,
        servingUnit: 'g',
        calories: 220.0,
        protein: 15.0,
        carbohydrates: 6.0,
        fats: 15.0,
        fiber: 1.0,
        sugar: 2.0,
        sodium: 350.0,
      ),
    ];

    test('6. Matches exact food name with 1.0 confidence', () {
      final match = FoodMatcher.match('Basmati Rice', catalog);
      expect(match.isMatched, isTrue);
      expect(match.food?.id, 'food_rice');
      expect(match.matchScore, 1.0);
    });

    test('7. Matches case-insensitive and trimmed names', () {
      final match = FoodMatcher.match('  basmati rice  ', catalog);
      expect(match.isMatched, isTrue);
      expect(match.food?.id, 'food_rice');
    });

    test('8. Matches common culinary alias (Roti -> Chapati)', () {
      final match = FoodMatcher.match('Wheat Roti', catalog);
      expect(match.isMatched, isTrue);
      expect(match.food?.id, 'food_chapati');
    });

    test('9. Handles token overlap (Tikka Paneer -> Paneer Tikka)', () {
      final match = FoodMatcher.match('Spiced Paneer Tikka Cubes', catalog);
      expect(match.isMatched, isTrue);
      expect(match.food?.id, 'food_paneer_tikka');
    });

    test('10. Returns un-matched when food does not exist in catalog', () {
      final match = FoodMatcher.match('Sushi Roll', catalog);
      expect(match.isMatched, isFalse);
    });
  });

  group('Phase 35.5 — Portion Scaling & Meal Totals Calculation Tests', () {
    const food = FoodEntity(
      id: 'food_rice',
      name: 'Basmati Rice',
      category: 'Grains',
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 130.0,
      protein: 3.0,
      carbohydrates: 28.0,
      fats: 1.0,
      fiber: 0.4,
      sugar: 0.1,
      sodium: 1.0,
    );

    test('11. Scales nutrition accurately based on portion amount', () {
      // 180g of rice (1.8x 100g serving)
      const candidate = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Rice',
        confidence: 0.90,
        estimatedAmount: 180.0,
        matchedFood: food,
        matchConfidence: 0.95,
      );

      expect(candidate.scaledCalories, closeTo(234.0, 0.01)); // 130 * 1.8 = 234
      expect(candidate.scaledProtein, closeTo(5.4, 0.01)); // 3 * 1.8 = 5.4
      expect(candidate.scaledCarbs, closeTo(50.4, 0.01)); // 28 * 1.8 = 50.4
      expect(candidate.scaledFats, closeTo(1.8, 0.01)); // 1 * 1.8 = 1.8
    });

    test('12. Combined meal scan totals equal sum of individual candidates', () {
      const candidate1 = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Rice',
        confidence: 0.90,
        estimatedAmount: 100.0,
        matchedFood: food,
      );

      const chicken = FoodEntity(
        id: 'food_chicken',
        name: 'Grilled Chicken',
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
      );

      const candidate2 = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Chicken',
        confidence: 0.85,
        estimatedAmount: 150.0, // 1.5x serving -> 247.5 kcal, 46.5g P, 5.4g F
        matchedFood: chicken,
      );

      final scanResult = FoodScanResult(
        id: 'scan_1',
        foods: [candidate1, candidate2],
        overallConfidence: 0.875,
        scannedAt: DateTime.now(),
      );

      expect(scanResult.totalCalories, closeTo(377.5, 0.01)); // 130 + 247.5 = 377.5
      expect(scanResult.totalProtein, closeTo(49.5, 0.01)); // 3.0 + 46.5 = 49.5
      expect(scanResult.totalCarbs, closeTo(28.0, 0.01)); // 28.0 + 0 = 28.0
      expect(scanResult.totalFats, closeTo(6.4, 0.01)); // 1.0 + 5.4 = 6.4
    });

    test('13. Proportional scaling works on non-100g database serving sizes', () {
      // 40g Chapati serving in database: 104 kcal, 3.1g P, 20.0g C, 1.5g F
      const chapati = FoodEntity(
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
      );

      // User ate 120g (3 Chapatis -> 3.0x multiplier)
      const candidate = DetectedFoodCandidate(
        id: 'c3',
        detectedName: 'Chapati',
        confidence: 0.95,
        estimatedAmount: 120.0,
        matchedFood: chapati,
      );

      // scaledValue = databaseValue * (120 / 40) = databaseValue * 3.0
      expect(candidate.scaledCalories, closeTo(312.0, 0.01)); // 104 * 3 = 312
      expect(candidate.scaledProtein, closeTo(9.3, 0.01)); // 3.1 * 3 = 9.3
      expect(candidate.scaledCarbs, closeTo(60.0, 0.01)); // 20 * 3 = 60.0
      expect(candidate.scaledFats, closeTo(4.5, 0.01)); // 1.5 * 3 = 4.5
    });
  });

  group('Phase 35.5 — Food Scan Remote DataSource API & Multimodal Tests', () {
    late Dio dio;
    late _TestHttpAdapter adapter;
    late FoodScanRemoteDataSource dataSource;
    final testImageBytes = Uint8List.fromList([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]);

    setUp(() {
      adapter = _TestHttpAdapter();
      dio = Dio()..httpClientAdapter = adapter;
      dataSource = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_api_key');
    });

    test('14. 404 Model Unavailable throws ModelUnavailableException rather than NetworkException', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '{"error": {"code": 404, "message": "models/${GeminiConfig.primaryModel} is not found"}}',
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => dataSource.analyzeMealImage(testImageBytes),
        throwsA(isA<ModelUnavailableException>()),
      );
    });

    test('15. 401/403 Auth Failure throws ServerException with status code', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '{"error": {"code": 401, "message": "API key not valid"}}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      try {
        await dataSource.analyzeMealImage(testImageBytes);
        fail('Should throw ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 401);
      }
    });

    test('16. 429 Rate Limit throws ServerException with 429 status code', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '{"error": {"code": 429, "message": "Resource exhausted"}}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      try {
        await dataSource.analyzeMealImage(testImageBytes);
        fail('Should throw ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 429);
      }
    });

    test('17. Timeout error throws ServerException with timeout message', () async {
      adapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout after 20s',
        );
      };

      expect(
        () => dataSource.analyzeMealImage(testImageBytes),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('18. Network failure (connection error) throws NetworkException', () async {
      adapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );
      };

      expect(
        () => dataSource.analyzeMealImage(testImageBytes),
        throwsA(isA<NetworkException>()),
      );
    });

    test('19. Successful multimodal image analysis parses candidates and verifies payload', () async {
      RequestOptions? capturedOptions;
      adapter.handler = (options) {
        capturedOptions = options;
        const responseJson = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\\"foods\\": [{\\"name\\": \\"Grilled Salmon\\", \\"estimated_grams\\": 150, \\"estimated_unit\\": \\"g\\", \\"confidence\\": 0.95, \\"visual_notes\\": \\"Fresh fillet\\"}]}"
          }
        ]
      }
    }
  ]
}
''';
        return ResponseBody.fromString(
          responseJson,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final results = await dataSource.analyzeMealImage(testImageBytes);

      expect(results.length, 1);
      expect(results.first.name, 'Grilled Salmon');
      expect(results.first.estimatedGrams, 150.0);
      expect(results.first.confidence, 0.95);

      // Verify multimodal payload structure
      expect(capturedOptions, isNotNull);
      final data = capturedOptions!.data as Map;
      expect(data['contents'], isNotNull);
      final parts = (data['contents'] as List).first['parts'] as List;
      final inlineData = parts.first['inlineData'] as Map;
      expect(inlineData['mimeType'], 'image/jpeg');
      expect(inlineData['data'], isNotEmpty);
      expect(parts[1]['text'], contains('FitFuel'));
    });

    test('20. FoodScanRepositoryImpl maps ModelUnavailableException to ModelUnavailableFailure', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '{"error": {"code": 404, "message": "Model not found"}}',
          404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };
      final repo = FoodScanRepositoryImpl(remoteDataSource: dataSource);

      expect(
        () => repo.scanFoodImage(
          imagePath: '/test/image.jpg',
          imageBytes: testImageBytes,
        ),
        throwsA(isA<ModelUnavailableFailure>()),
      );
    });

    test('21. FoodScanRepositoryImpl maps NetworkException to NetworkFailure', () async {
      adapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      };
      final repo = FoodScanRepositoryImpl(remoteDataSource: dataSource);

      expect(
        () => repo.scanFoodImage(
          imagePath: '/test/image.jpg',
          imageBytes: testImageBytes,
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
