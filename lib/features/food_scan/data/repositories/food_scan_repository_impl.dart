import 'package:flutter/foundation.dart';
import 'package:fitfuel/core/errors/exceptions.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/estimated_nutrition.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/repositories/i_food_scan_repository.dart';
import 'package:fitfuel/features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import 'package:fitfuel/features/food_scan/data/services/food_matcher.dart';

class FoodScanRepositoryImpl implements IFoodScanRepository {
  final IFoodScanRemoteDataSource _remoteDataSource;

  FoodScanRepositoryImpl({
    required IFoodScanRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<FoodScanResult> scanFoodImage({
    required String imagePath,
    required Uint8List imageBytes,
    List<FoodEntity> foodCatalog = const [],
  }) async {
    try {
      final rawFoods = await _remoteDataSource.analyzeMealImage(imageBytes);

      final List<DetectedFoodCandidate> candidates = [];

      for (var i = 0; i < rawFoods.length; i++) {
        final raw = rawFoods[i];

        // 1. Database-first matching: check if trusted FitFuel food match exists
        final matchResult = FoodMatcher.match(raw.name, foodCatalog);

        EstimatedNutrition? resolvedNutrition;

        if (matchResult.isMatched) {
          // Trusted database match exists: use database nutrition, ignore AI macros, 0 extra requests
          resolvedNutrition = null;
        } else if (raw.estimatedNutrition != null) {
          // Unmatched food with already complete AI macros (all 4 fields present): 0 extra requests
          resolvedNutrition = raw.estimatedNutrition;
        } else {
          // Unmatched food with incomplete AI macros: attempt ONE small text-only repair request
          try {
            resolvedNutrition = await _remoteDataSource.repairNutrition(
              foodName: raw.name,
              estimatedGrams: raw.estimatedGrams,
            );
          } catch (_) {
            resolvedNutrition = null;
          }
        }

        candidates.add(
          DetectedFoodCandidate(
            id: 'detected_${i}_${DateTime.now().millisecondsSinceEpoch}',
            detectedName: raw.name,
            confidence: raw.confidence,
            estimatedAmount: raw.estimatedGrams,
            originalEstimatedAmount: raw.estimatedGrams,
            estimatedUnit: raw.unit,
            matchedFood: matchResult.isMatched ? matchResult.food : null,
            matchConfidence: matchResult.isMatched ? matchResult.matchScore : 0.0,
            visualNotes: raw.visualNotes,
            aiEstimatedNutrition: resolvedNutrition,
          ),
        );
      }

      final overallConfidence = candidates.isEmpty
          ? 0.0
          : candidates.fold(0.0, (sum, f) => sum + f.confidence) / candidates.length;

      return FoodScanResult(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: imagePath,
        foods: candidates,
        overallConfidence: overallConfidence,
        scannedAt: DateTime.now(),
      );
    } on FoodScanException catch (e) {
      throw FoodScanFailure.fromType(
        e.type,
        messageOverride: e.message,
        retryAfterSeconds: e.retryAfterSeconds,
        statusCode: e.statusCode,
      );
    } on ModelUnavailableException catch (e) {
      throw FoodScanFailure.fromType(
        FoodScanFailureType.modelUnavailable,
        messageOverride: e.message,
        statusCode: e.statusCode,
      );
    } on NetworkException catch (e) {
      throw FoodScanFailure.fromType(
        FoodScanFailureType.offline,
        messageOverride: e.message,
      );
    } on ServerException catch (e) {
      final statusCode = e.statusCode;
      if (statusCode == 404) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.modelUnavailable,
          statusCode: 404,
        );
      }
      if (statusCode == 429) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.rateLimited,
          statusCode: 429,
        );
      }
      if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.serviceUnavailable,
          statusCode: statusCode,
        );
      }
      if (statusCode == 408 || statusCode == 504) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.timeout,
          statusCode: statusCode,
        );
      }
      if (statusCode == 401) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.unauthorized,
          statusCode: 401,
        );
      }
      if (statusCode == 403) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.forbidden,
          statusCode: 403,
        );
      }
      if (statusCode == 400) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.invalidRequest,
          statusCode: 400,
        );
      }
      throw FoodScanFailure.fromType(
        FoodScanFailureType.unknownServiceFailure,
        statusCode: statusCode,
      );
    } catch (e) {
      if (e is FoodScanFailure) rethrow;
      if (e is Failure) {
        throw FoodScanFailure.fromType(
          FoodScanFailureType.unknownServiceFailure,
          messageOverride: e.message,
        );
      }
      if (kDebugMode) {
        debugPrint('[FoodScan] Unexpected error in repository: $e');
      }
      // Never expose technical exception text or raw details to presentation layer
      throw FoodScanFailure.fromType(
        FoodScanFailureType.unknownServiceFailure,
        messageOverride: FoodScanErrorCopy.unknownMessage,
      );
    }
  }
}
