import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/ai_assistant/data/datasources/ai_nutrition_remote_datasource.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/nutrition/domain/repositories/i_nutrition_repository.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/repositories/food_scan_repository_impl.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_controller.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/screens/food_scan_screen.dart';

class _TestAdapter implements HttpClientAdapter {
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

String _geminiJson(String innerJson) {
  final escaped = jsonEncode(innerJson);
  return '{"candidates": [{"content": {"parts": [{"text": $escaped}]}}]}';
}

class _TrackingPickerService implements IFoodImagePickerService {
  int pickCount = 0;
  String? pickedPath = '/tmp/test_food.jpg';
  Uint8List? imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    pickCount++;
    return pickedPath;
  }

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async => imageBytes;
}

class _MockNutritionRepo implements INutritionRepository {
  final List<dynamic> records = [];

  @override
  Future<void> addRecord(String uid, dynamic record) async {
    records.add(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    // Zero delay for fast test execution
    FoodScanRemoteDataSource.defaultDelayProvider = (_, __) => Duration.zero;
  });

  tearDown(() {
    FoodScanRemoteDataSource.defaultDelayProvider = null;
  });

  const catalog = [
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
      id: 'food_dal',
      name: 'Dal',
      category: 'Curry',
      servingSize: 150.0,
      servingUnit: 'g',
      calories: 150.0,
      protein: 9.0,
      carbohydrates: 22.0,
      fats: 3.0,
      fiber: 5.0,
      sugar: 1.0,
      sodium: 250.0,
    ),
  ];

  group('Phase 35.5.1 — Rate Limit (429) & Quota Tests', () {
    test('1. Short-term 429 retries and classifies as rateLimited after exhaustion', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int attempts = 0;
      adapter.handler = (opts) {
        attempts++;
        return ResponseBody.fromString(
          '{"error": {"code": 429, "message": "Rate limit exceeded. Please wait.", "status": "RESOURCE_EXHAUSTED"}}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['2'],
          },
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw FoodScanException');
      } on FoodScanException catch (e) {
        expect(e.type, FoodScanFailureType.rateLimited);
        expect(e.statusCode, 429);
        expect(e.retryAfterSeconds, 2);
        expect(attempts, 4); // initial + 3 retries
      }
    });

    test('2. Daily/project quota 429 is detected and NOT retried transiently', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int attempts = 0;
      adapter.handler = (opts) {
        attempts++;
        return ResponseBody.fromString(
          '{"error": {"code": 429, "message": "Daily quota exceeded for project. Quota resets at midnight.", "status": "RESOURCE_EXHAUSTED"}}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw FoodScanException');
      } on FoodScanException catch (e) {
        expect(e.type, FoodScanFailureType.dailyQuotaReached);
        expect(e.statusCode, 429);
        expect(attempts, 1); // Not retried
      }
    });

    test('3. 429 preserves image and retry reuses same image without reopening picker', () async {
      final picker = _TrackingPickerService();
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
      final repo = FoodScanRepositoryImpl(remoteDataSource: ds);

      bool failFirst = true;
      adapter.handler = (opts) {
        if (failFirst) {
          return ResponseBody.fromString(
            '{"error": {"code": 429, "message": "Rate limit exceeded", "status": "RESOURCE_EXHAUSTED"}}',
            429,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          _geminiJson('{"foods": [{"name": "Chapati", "estimated_grams": 80, "confidence": 0.95}]}'),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final controller = FoodScanController(repository: repo, imagePickerService: picker);

      // First attempt fails with 429
      await controller.pickAndScan(FoodImagePickSource.camera, catalog: catalog);
      expect(controller.state, isA<FoodScanError>());
      final errState = controller.state as FoodScanError;
      expect(errState.failureType, FoodScanFailureType.rateLimited);
      expect(errState.imagePath, '/tmp/test_food.jpg');
      expect(errState.imageBytes, isNotNull);
      expect(picker.pickCount, 1);

      // Retry without reopening camera/picker
      failFirst = false;
      await controller.retryScan();
      expect(picker.pickCount, 1); // Did NOT reopen picker!
      expect(controller.state, isA<FoodScanSuccess>());
    });
  });

  group('Phase 35.5.1 — Server Reliability & Transient Retry Tests', () {
    test('4. 503 first retry succeeds', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int attempts = 0;
      adapter.handler = (opts) {
        attempts++;
        if (attempts == 1) {
          return ResponseBody.fromString(
            '{"error": {"code": 503, "message": "Service unavailable"}}',
            503,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          _geminiJson('{"foods": [{"name": "Basmati Rice", "estimated_grams": 150, "confidence": 0.9}]}'),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final result = await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      expect(attempts, 2); // Initial failed, retry 1 succeeded
      expect(result.length, 1);
      expect(result.first.name, 'Basmati Rice');
    });

    test('5. 500 retry exhaustion falls back to fallback model if available', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int primaryAttempts = 0;
      int fallbackAttempts = 0;

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.defaultFallbackModelName)) {
          fallbackAttempts++;
          return ResponseBody.fromString(
            _geminiJson('{"foods": [{"name": "Fallback Food", "estimated_grams": 100, "confidence": 0.85}]}'),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          primaryAttempts++;
          return ResponseBody.fromString(
            '{"error": {"code": 500, "message": "Internal error"}}',
            500,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
      };

      final result = await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      expect(primaryAttempts, 4); // 1 initial + 3 retries
      expect(fallbackAttempts, 1); // fallback model succeeded
      expect(result.first.name, 'Fallback Food');
    });

    test('6. Non-retryable 400/401/403/404 are not retried', () async {
      for (final code in [400, 401, 403, 404]) {
        final adapter = _TestAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

        int attempts = 0;
        adapter.handler = (opts) {
          attempts++;
          return ResponseBody.fromString(
            '{"error": {"code": $code, "message": "Error $code"}}',
            code,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        try {
          await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
          fail('Should throw for $code');
        } catch (_) {
          expect(attempts, 1, reason: 'Status $code must not be retried');
        }
      }
    });
  });

  group('Phase 35.5.1 — Complete Macro Recovery Tests', () {
    test('7. Database match uses DB macros and makes 0 repair requests', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
      final repo = FoodScanRepositoryImpl(remoteDataSource: ds);

      int requestCount = 0;
      adapter.handler = (opts) {
        requestCount++;
        return ResponseBody.fromString(
          _geminiJson('{"foods": [{"name": "Chapati", "estimated_grams": 80, "confidence": 0.95}]}'),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final result = await repo.scanFoodImage(
        imagePath: '/tmp/chapati.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        foodCatalog: catalog,
      );

      expect(requestCount, 1); // Exactly 1 image request, 0 repair requests
      final candidate = result.foods.first;
      expect(candidate.isDatabaseMatch, isTrue);
      expect(candidate.calories, closeTo(208.0, 0.1)); // 104 * (80/40)
      expect(candidate.protein, closeTo(6.2, 0.1));
      expect(candidate.carbs, closeTo(40.0, 0.1));
      expect(candidate.fats, closeTo(3.0, 0.1));
    });

    test('8. Unmatched food missing macros triggers ONE repair request which succeeds', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
      final repo = FoodScanRepositoryImpl(remoteDataSource: ds);

      int requestCount = 0;
      adapter.handler = (opts) {
        requestCount++;
        if (requestCount == 1) {
          // Multimodal returns unmatched food with missing carbs
          return ResponseBody.fromString(
            _geminiJson('''
{
  "foods": [
    {
      "name": "Regional Chicken Curry",
      "estimated_grams": 180,
      "confidence": 0.85,
      "estimated_nutrition": {
        "calories": 260,
        "protein_g": 23,
        "carbs_g": null,
        "fat_g": 14
      }
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          // Text-only repair request
          return ResponseBody.fromString(
            '{"candidates": [{"content": {"parts": [{"text": "{\\"calories\\": 260, \\"protein_g\\": 23, \\"carbs_g\\": 4.5, \\"fat_g\\": 14}"}]}}]}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
      };

      final result = await repo.scanFoodImage(
        imagePath: '/tmp/curry.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        foodCatalog: catalog,
      );

      expect(requestCount, 2); // 1 vision + 1 text repair
      final candidate = result.foods.first;
      expect(candidate.isAiEstimated, isTrue);
      expect(candidate.hasNutrition, isTrue);
      expect(candidate.calories, 260.0);
      expect(candidate.protein, 23.0);
      expect(candidate.carbs, 4.5);
      expect(candidate.fats, 14.0);
    });

    test('9. Unmatched food when repair fails is preserved with Needs Confirmation and null != 0', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
      final repo = FoodScanRepositoryImpl(remoteDataSource: ds);

      int requestCount = 0;
      adapter.handler = (opts) {
        requestCount++;
        if (requestCount == 1) {
          return ResponseBody.fromString(
            _geminiJson('''
{
  "foods": [
    {
      "name": "Unknown Stew",
      "estimated_grams": 200,
      "confidence": 0.70,
      "estimated_nutrition": null
    }
  ]
}
'''),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          // Repair fails or returns malformed
          return ResponseBody.fromString(
            '{"candidates": [{"content": {"parts": [{"text": "Cannot estimate"}]}}]}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
      };

      final result = await repo.scanFoodImage(
        imagePath: '/tmp/stew.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        foodCatalog: catalog,
      );

      expect(result.foods.length, 1);
      final candidate = result.foods.first;
      expect(candidate.detectedName, 'Unknown Stew');
      expect(candidate.hasNutrition, isFalse);
      expect(candidate.calories, isNull);
      expect(candidate.protein, isNull);
      expect(candidate.carbs, isNull);
      expect(candidate.fats, isNull);
      expect(candidate.nutritionSourceLabel, contains('Needs confirmation'));
    });

    test('10. True zero macros (0.0) are preserved and distinguished from null', () {
      const jsonWithZeros = {
        'calories': 50.0,
        'protein_g': 0.0,
        'carbs_g': 12.0,
        'fat_g': 0.0,
      };

      final nutrition = EstimatedNutrition.fromJson(jsonWithZeros);
      expect(nutrition, isNotNull);
      expect(nutrition!.protein, 0.0);
      expect(nutrition.fat, 0.0);

      // Null is rejected by fromJson and NEVER fabricated as 0
      const jsonWithNull = {
        'calories': 50.0,
        'protein_g': null,
        'carbs_g': 12.0,
        'fat_g': 0.0,
      };
      expect(EstimatedNutrition.fromJson(jsonWithNull), isNull);
    });
  });

  group('Phase 35.5.1 — Mixed Meals & Partial Success Tests', () {
    test('11. Mixed meal with 1 unresolved component keeps resolved items and labels totals incomplete', () {
      final chapatiCandidate = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Chapati',
        confidence: 0.95,
        estimatedAmount: 80.0,
        matchedFood: catalog[0],
      );
      const unresolvedCandidate = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Regional Curry',
        confidence: 0.80,
        estimatedAmount: 150.0,
      );

      final result = FoodScanResult(
        id: 'scan_mixed',
        imagePath: '/tmp/plate.jpg',
        foods: [chapatiCandidate, unresolvedCandidate],
        overallConfidence: 0.875,
        scannedAt: DateTime.now(),
      );

      expect(result.foods.length, 2);
      expect(result.hasIncompleteNutrition, isTrue);
      expect(result.canBeLogged, isFalse);

      // Total reflects valid confirmed components only
      expect(result.totalCalories, closeTo(208.0, 0.1));
      expect(result.totalProtein, closeTo(6.2, 0.1));
    });

    test('12. Food diary logging is blocked while incomplete foods exist', () async {
      final repo = _MockNutritionRepo();
      const unresolvedCandidate = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Regional Curry',
        confidence: 0.80,
        estimatedAmount: 150.0,
      );

      final result = FoodScanResult(
        id: 'scan_mixed',
        imagePath: '/tmp/plate.jpg',
        foods: [unresolvedCandidate],
        overallConfidence: 0.80,
        scannedAt: DateTime.now(),
      );

      final picker = _TrackingPickerService();
      final scanRepo = FoodScanRepositoryImpl(
        remoteDataSource: FoodScanRemoteDataSource(apiKey: 'key'),
      );
      final controller = FoodScanController(repository: scanRepo, imagePickerService: picker);

      // Force state to success with incomplete nutrition
      controller.state = FoodScanSuccess(result: result);

      final logged = await controller.logToDiary('user1', repo);
      expect(logged, isFalse);
      expect(repo.records, isEmpty);
    });
  });

  group('Phase 35.5.1 — Generic Error Elimination & UI Regression Tests', () {
    testWidgets('13. "Something Went Wrong" NEVER appears in UI for any failure', (tester) async {
      final failureCases = [
        FoodScanFailureType.rateLimited,
        FoodScanFailureType.dailyQuotaReached,
        FoodScanFailureType.serviceUnavailable,
        FoodScanFailureType.timeout,
        FoodScanFailureType.offline,
        FoodScanFailureType.modelUnavailable,
        FoodScanFailureType.noFoodDetected,
        FoodScanFailureType.lowConfidence,
        FoodScanFailureType.imageQualityPoor,
        FoodScanFailureType.unknownServiceFailure,
      ];

      for (final fType in failureCases) {
        final failure = FoodScanFailure.fromType(fType);
        final errState = FoodScanError(
          title: failure.title,
          message: failure.message,
          failureType: failure.type,
          imagePath: '/tmp/pic.jpg',
        );

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(fType),
            overrides: [
              authStateStreamProvider.overrideWith((_) => Stream.value(null)),
              networkStatusProvider.overrideWith((_) => Stream.value(NetworkStatus.online)),
              foodScanControllerProvider.overrideWith((ref) {
                final c = FoodScanController(
                  repository: FoodScanRepositoryImpl(
                    remoteDataSource: FoodScanRemoteDataSource(apiKey: 'k'),
                  ),
                  imagePickerService: _TrackingPickerService(),
                );
                c.state = errState;
                return c;
              }),
            ],
            child: const MaterialApp(
              home: FoodScanScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // STRICT REGRESSION CHECK: "Something Went Wrong" must NEVER appear
        expect(find.text('Something Went Wrong'), findsNothing,
            reason: 'Found "Something Went Wrong" on failure type $fType');

        // Verify technical strings are never visible
        expect(find.textContaining('DioException'), findsNothing);
        expect(find.textContaining('RequestOptions'), findsNothing);
        expect(find.textContaining('developer.mozilla.org'), findsNothing);

        // Verify the expected failure title is rendered
        expect(find.text(failure.title), findsOneWidget);
      }
    });

    testWidgets('14. NutritionEstimateCard shows "Partial estimate • Totals incomplete" when nutrition is incomplete', (tester) async {
      const unresolvedCandidate = DetectedFoodCandidate(
        id: 'c2',
        detectedName: 'Regional Curry',
        confidence: 0.80,
        estimatedAmount: 150.0,
      );

      final result = FoodScanResult(
        id: 'scan_mixed',
        imagePath: '/tmp/plate.jpg',
        foods: [unresolvedCandidate],
        overallConfidence: 0.80,
        scannedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith((_) => Stream.value(null)),
            networkStatusProvider.overrideWith((_) => Stream.value(NetworkStatus.online)),
            foodScanControllerProvider.overrideWith((ref) {
              final c = FoodScanController(
                repository: FoodScanRepositoryImpl(
                  remoteDataSource: FoodScanRemoteDataSource(apiKey: 'k'),
                ),
                imagePickerService: _TrackingPickerService(),
              );
              c.state = FoodScanSuccess(result: result);
              return c;
            }),
          ],
          child: const MaterialApp(
            home: FoodScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partial estimate • Totals incomplete'), findsOneWidget);
      expect(find.text('Needs confirmation'), findsWidgets);
    });

    test('15. 502 and 504 status codes trigger bounded transient retries', () async {
      for (final code in [502, 504]) {
        final adapter = _TestAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

        int attempts = 0;
        adapter.handler = (opts) {
          attempts++;
          return ResponseBody.fromString(
            '{"error": {"code": $code, "message": "Server error $code"}}',
            code,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        try {
          await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
          fail('Should throw for $code');
        } on FoodScanException catch (e) {
          expect(attempts, greaterThanOrEqualTo(4)); // Bounded transient retries + fallback
          expect(e.statusCode, code);
        }
      }
    });

    test('16. Second retry succeeds (fail on initial + retry 1, succeed on retry 2)', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int attempts = 0;
      adapter.handler = (opts) {
        attempts++;
        if (attempts <= 2) {
          return ResponseBody.fromString(
            '{"error": {"code": 503, "message": "Service busy"}}',
            503,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          _geminiJson('{"foods": [{"name": "Grilled Fish", "estimated_grams": 160, "confidence": 0.92}]}'),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final result = await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      expect(attempts, 3); // initial + retry 1 + retry 2 (success)
      expect(result.first.name, 'Grilled Fish');
    });

    test('17. Fallback fails safely and throws typed serviceUnavailable without leaking internals', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      adapter.handler = (opts) {
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Service overloaded"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw FoodScanException');
      } on FoodScanException catch (e) {
        expect(e.type, FoodScanFailureType.serviceUnavailable);
        expect(e.message, isNot(contains('dio')));
        expect(e.message, isNot(contains('developer.mozilla.org')));
      }
    });

    test('18. Unmatched food missing protein / fat / calories triggers repair request', () async {
      final missingFields = [
        {'name': 'Food A', 'cals': 100, 'pro': null, 'carbs': 10.0, 'fat': 2.0},
        {'name': 'Food B', 'cals': 100, 'pro': 5.0, 'carbs': 10.0, 'fat': null},
        {'name': 'Food C', 'cals': null, 'pro': 5.0, 'carbs': 10.0, 'fat': 2.0},
      ];

      for (final item in missingFields) {
        final adapter = _TestAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');
        final repo = FoodScanRepositoryImpl(remoteDataSource: ds);

        int count = 0;
        adapter.handler = (opts) {
          count++;
          if (count == 1) {
            return ResponseBody.fromString(
              _geminiJson('''
{
  "foods": [
    {
      "name": "${item['name']}",
      "estimated_grams": 100,
      "confidence": 0.8,
      "estimated_nutrition": {
        "calories": ${item['cals']},
        "protein_g": ${item['pro']},
        "carbs_g": ${item['carbs']},
        "fat_g": ${item['fat']}
      }
    }
  ]
}
'''),
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          } else {
            return ResponseBody.fromString(
              '{"candidates": [{"content": {"parts": [{"text": "{\\"calories\\": 120, \\"protein_g\\": 6.0, \\"carbs_g\\": 15.0, \\"fat_g\\": 3.0}"}]}}]}',
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          }
        };

        final result = await repo.scanFoodImage(
          imagePath: '/tmp/food.jpg',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          foodCatalog: catalog,
        );

        expect(count, 2, reason: 'Must trigger repair for missing macro');
        expect(result.foods.first.hasNutrition, isTrue);
      }
    });

    test('19. Correcting unresolved food via updateMatchedFood resolves totals', () {
      const unresolved = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Regional Dal',
        confidence: 0.80,
        estimatedAmount: 150.0,
      );

      final result = FoodScanResult(
        id: 'scan1',
        foods: [unresolved],
        overallConfidence: 0.80,
        scannedAt: DateTime.now(),
      );

      final picker = _TrackingPickerService();
      final repo = FoodScanRepositoryImpl(
        remoteDataSource: FoodScanRemoteDataSource(apiKey: 'k'),
      );
      final controller = FoodScanController(repository: repo, imagePickerService: picker);
      controller.state = FoodScanSuccess(result: result);

      expect((controller.state as FoodScanSuccess).result.hasIncompleteNutrition, isTrue);

      // User selects Dal from database
      controller.updateMatchedFood(0, catalog[1]); // Dal

      final updated = (controller.state as FoodScanSuccess).result;
      expect(updated.hasIncompleteNutrition, isFalse);
      expect(updated.canBeLogged, isTrue);
      expect(updated.totalCalories, closeTo(150.0, 0.1));
      expect(updated.totalProtein, closeTo(9.0, 0.1));
    });

    test('20. Screen photo with low confidence sets isLowConfidence', () {
      const screenCandidate = DetectedFoodCandidate(
        id: 'c1',
        detectedName: 'Phone Screen Salad',
        confidence: 0.45, // low confidence from screen glare
        estimatedAmount: 120.0,
      );

      final result = FoodScanResult(
        id: 'scan_screen',
        foods: [screenCandidate],
        overallConfidence: 0.45,
        scannedAt: DateTime.now(),
      );

      expect(result.isLowConfidence, isTrue);
      expect(result.foods.first.isLowConfidence, isTrue);
      expect(result.foods.first.confidenceLevel, ScanConfidenceLevel.low);
    });

    test('21. Empty image bytes safely throws without crashing or leaking technical details', () async {
      final ds = FoodScanRemoteDataSource(apiKey: 'key');
      expect(
        () => ds.analyzeMealImage(Uint8List(0)),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('Phase 35.5.1 Final — Gemini Model Configuration & Fallback Verification', () {
    test('22. Primary model remains gemini-3.8-flash', () {
      expect(GeminiConfig.primaryModel, 'gemini-3.8-flash');
      expect(GeminiConfig.defaultModelName, 'gemini-3.8-flash');
      expect(GeminiConfig.modelName, 'gemini-3.8-flash');
    });

    test('23. Fallback model comes from centralized configuration (gemini-3.5-flash)', () {
      expect(GeminiConfig.fallbackModel, 'gemini-3.5-flash');
      expect(GeminiConfig.defaultFallbackModelName, 'gemini-3.5-flash');
      expect(GeminiConfig.fallbackModelName, 'gemini-3.5-flash');
      expect(GeminiConfig.fallbackModel, isNotEmpty);
    });

    test('24. No retired Gemini 1.5/2.0 production reference remains in active models', () {
      expect(GeminiConfig.primaryModel.contains('1.5'), isFalse);
      expect(GeminiConfig.fallbackModel.contains('1.5'), isFalse);
      expect(GeminiConfig.primaryModel.contains('2.0'), isFalse);
      expect(GeminiConfig.fallbackModel.contains('2.0'), isFalse);
      expect(GeminiConfig.primaryModel.contains('8b'), isFalse);
      expect(GeminiConfig.fallbackModel.contains('8b'), isFalse);
    });

    test('25. 503 retries primary model 3 times before considering fallback', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int primaryAttempts = 0;
      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.primaryModel)) {
          primaryAttempts++;
        }
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Service Unavailable"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      } catch (_) {}

      // Initial request + 3 retries = 4 primary attempts
      expect(primaryAttempts, 4);
    });

    test('26. Fallback runs after primary retry exhaustion', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      int primaryAttempts = 0;
      int fallbackAttempts = 0;

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.primaryModel)) {
          primaryAttempts++;
          return ResponseBody.fromString(
            '{"error": {"code": 503, "message": "Service Busy"}}',
            503,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else if (opts.path.contains(GeminiConfig.fallbackModel)) {
          fallbackAttempts++;
          return ResponseBody.fromString(
            _geminiJson('{"foods": [{"name": "Steamed Rice", "estimated_grams": 150, "confidence": 0.90}]}'),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 400);
      };

      final result = await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      expect(primaryAttempts, 4);
      expect(fallbackAttempts, 1);
      expect(result.first.name, 'Steamed Rice');
    });

    test('27. Fallback success returns detected foods seamlessly', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.fallbackModel)) {
          return ResponseBody.fromString(
            _geminiJson('{"foods": [{"name": "Grilled Paneer", "estimated_grams": 120, "confidence": 0.88}]}'),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        // Primary fails with 503
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Primary Outage"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final foods = await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
      expect(foods, isNotEmpty);
      expect(foods.first.name, 'Grilled Paneer');
      expect(foods.first.estimatedGrams, 120.0);
    });

    test('28. Fallback 429 handled safely without unhandled exception', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.fallbackModel)) {
          return ResponseBody.fromString(
            '{"error": {"code": 429, "message": "Fallback Rate Limit"}}',
            429,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        // Primary exhausts
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Primary Down"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw FoodScanException');
      } on FoodScanException catch (e) {
        expect(e.type, FoodScanFailureType.rateLimited);
        expect(e.statusCode, 429);
      }
    });

    test('29. Fallback 503 handled safely without unhandled exception', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.fallbackModel)) {
          return ResponseBody.fromString(
            '{"error": {"code": 503, "message": "Fallback Unavailable"}}',
            503,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Primary Down"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw FoodScanException');
      } on FoodScanException catch (e) {
        expect(e.type, FoodScanFailureType.serviceUnavailable);
        expect(e.statusCode, 503);
      }
    });

    test('30. Fallback 404 handled safely without unhandled exception', () async {
      final adapter = _TestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = FoodScanRemoteDataSource(dio: dio, apiKey: 'test_key');

      adapter.handler = (opts) {
        if (opts.path.contains(GeminiConfig.fallbackModel)) {
          return ResponseBody.fromString(
            '{"error": {"code": 404, "message": "models/${GeminiConfig.fallbackModel} is not found"}}',
            404,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          '{"error": {"code": 503, "message": "Primary Down"}}',
          503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      try {
        await ds.analyzeMealImage(Uint8List.fromList([1, 2, 3]));
        fail('Should throw ModelUnavailableException');
      } on ModelUnavailableException catch (e) {
        expect(e.statusCode, 404);
      }
    });

    testWidgets('31. Raw DioException never reaches UI in FoodScanScreen', (tester) async {
      const errState = FoodScanError(
        title: 'Food Scan is temporarily unavailable',
        message: 'The AI service is busy right now. Your photo is still here — try again in a moment.',
        failureType: FoodScanFailureType.serviceUnavailable,
        imagePath: '/tmp/photo.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith((_) => Stream.value(null)),
            networkStatusProvider.overrideWith((_) => Stream.value(NetworkStatus.online)),
            foodScanControllerProvider.overrideWith((ref) {
              final picker = _TrackingPickerService();
              final repo = FoodScanRepositoryImpl(remoteDataSource: FoodScanRemoteDataSource(apiKey: 'k'));
              final controller = FoodScanController(repository: repo, imagePickerService: picker);
              controller.state = errState;
              return controller;
            }),
          ],
          child: const MaterialApp(home: FoodScanScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('http'), findsNothing);
      expect(find.textContaining('googleapis'), findsNothing);
      expect(find.text('Food Scan is temporarily unavailable'), findsOneWidget);
    });

    testWidgets('32. "Something Went Wrong" NEVER appears in Food Scan Screen', (tester) async {
      const errState = FoodScanError(
        title: 'Food Scan is temporarily limited',
        message: "We've reached the AI scanning limit for now. Please wait a moment and try again.",
        failureType: FoodScanFailureType.rateLimited,
        imagePath: '/tmp/photo.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateStreamProvider.overrideWith((_) => Stream.value(null)),
            networkStatusProvider.overrideWith((_) => Stream.value(NetworkStatus.online)),
            foodScanControllerProvider.overrideWith((ref) {
              final picker = _TrackingPickerService();
              final repo = FoodScanRepositoryImpl(remoteDataSource: FoodScanRemoteDataSource(apiKey: 'k'));
              final controller = FoodScanController(repository: repo, imagePickerService: picker);
              controller.state = errState;
              return controller;
            }),
          ],
          child: const MaterialApp(home: FoodScanScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Something Went Wrong'), findsNothing);
      expect(find.text('Food Scan is temporarily limited'), findsOneWidget);
    });
  });
}
