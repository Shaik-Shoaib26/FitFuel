import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/core/sync/sync_status.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/nutrition/data/models/nutrition_record_model.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSnapshotMetadata implements SnapshotMetadata {
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;

  const FakeSnapshotMetadata({
    this.hasPendingWrites = false,
    this.isFromCache = false,
  });
}

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  final SnapshotMetadata metadata;

  FakeDocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    this.metadata = const FakeSnapshotMetadata(),
  }) : _data = data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 35.12.17 — Nullable Nutrition Contract & Deserialization Audit', () {
    final now = DateTime(2026, 10, 23, 10, 0, 0);

    test('Record with null fiber and sodium preserves nulls through entity, model, and Firestore conversion', () {
      final entity = NutritionRecordEntity(
        id: 'rec_null_opt',
        foodName: 'Generic White Sugar',
        mealType: 'Snack',
        calories: 387.0,
        protein: 0.0,
        carbohydrates: 100.0,
        fats: 0.0,
        sugar: 100.0,
        fiber: null, // explicit null
        sodium: null, // explicit null
        servingSize: 100.0,
        baseFiber: null,
        baseSodium: null,
        nutritionTier: NutritionProfileTier.verifiedExact,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(entity.fiber, isNull);
      expect(entity.sodium, isNull);
      expect(entity.baseFiber, isNull);
      expect(entity.baseSodium, isNull);

      final model = NutritionRecordModel.fromEntity(entity);
      expect(model.fiber, isNull);
      expect(model.sodium, isNull);
      expect(model.baseFiber, isNull);
      expect(model.baseSodium, isNull);

      final firestoreMap = model.toFirestore();
      // Omitted from Map or null, never forced to 0.0
      expect(firestoreMap.containsKey('fiber'), isFalse);
      expect(firestoreMap.containsKey('sodium'), isFalse);
      expect(firestoreMap.containsKey('baseFiber'), isFalse);
      expect(firestoreMap.containsKey('baseSodium'), isFalse);

      final roundTripEntity = model.toEntity();
      expect(roundTripEntity.fiber, isNull);
      expect(roundTripEntity.sodium, isNull);
    });

    test('Record with legitimate 0.0 values preserves 0.0 without treating as missing/null', () {
      final entity = NutritionRecordEntity(
        id: 'rec_zero_nutrients',
        foodName: 'Pure Water / Diet Soda',
        mealType: 'Snack',
        calories: 0.0,
        protein: 0.0,
        carbohydrates: 0.0,
        fats: 0.0,
        sugar: 0.0,
        fiber: 0.0, // verified zero
        sodium: 0.0, // verified zero
        servingSize: 250.0,
        baseCalories: 0.0,
        baseProtein: 0.0,
        baseCarbohydrates: 0.0,
        baseFats: 0.0,
        baseSugar: 0.0,
        baseFiber: 0.0,
        baseSodium: 0.0,
        baseServingSize: 250.0,
        nutritionTier: NutritionProfileTier.verifiedExact,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(entity.fiber, equals(0.0));
      expect(entity.sodium, equals(0.0));

      final model = NutritionRecordModel.fromEntity(entity);
      expect(model.fiber, equals(0.0));
      expect(model.sodium, equals(0.0));

      final firestoreMap = model.toFirestore();
      expect(firestoreMap['fiber'], equals(0.0));
      expect(firestoreMap['sodium'], equals(0.0));
      expect(firestoreMap['baseFiber'], equals(0.0));
      expect(firestoreMap['baseSodium'], equals(0.0));
    });

    test('Deserializing legacy Firestore document where fiber and sodium keys are missing yields null, not 0.0', () {
      final legacyDoc = FakeDocumentSnapshot(
        id: 'legacy_doc_001',
        data: {
          'foodName': 'Legacy Apple Pie',
          'mealType': 'Snack',
          'calories': 237.0,
          'protein': 1.9,
          'carbohydrates': 34.0,
          'fats': 10.7,
          'sugar': 18.0,
          'servingSize': 100.0,
          // 'fiber' and 'sodium' completely absent from document
          'consumedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      );

      final model = NutritionRecordModel.fromFirestore(legacyDoc);
      expect(model.fiber, isNull, reason: 'Missing legacy fiber must deserialize as null');
      expect(model.sodium, isNull, reason: 'Missing legacy sodium must deserialize as null');
      expect(model.baseFiber, isNull);
      expect(model.baseSodium, isNull);

      final entity = model.toEntity();
      expect(entity.fiber, isNull);
      expect(entity.sodium, isNull);
    });

    test('Deserializing Firestore document with explicit null values parses correctly as null', () {
      final explicitNullDoc = FakeDocumentSnapshot(
        id: 'null_fields_doc_002',
        data: {
          'foodName': 'Unanalyzed Fruit',
          'mealType': 'Snack',
          'calories': 80.0,
          'protein': 1.0,
          'carbohydrates': 18.0,
          'fats': 0.2,
          'sugar': null,
          'fiber': null,
          'sodium': null,
          'servingSize': 120.0,
          'consumedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      );

      final model = NutritionRecordModel.fromFirestore(explicitNullDoc);
      expect(model.fiber, isNull);
      expect(model.sodium, isNull);
      expect(model.sugar, equals(0.0), reason: 'Sugar defaults to 0.0 in model if null in Firestore');
    });

    test('String number representation in legacy document parses gracefully into double', () {
      final stringNumberDoc = FakeDocumentSnapshot(
        id: 'str_num_doc_003',
        data: {
          'foodName': 'Legacy String Numbers',
          'mealType': 'Lunch',
          'calories': '250.5',
          'protein': '15.2',
          'carbohydrates': '30.0',
          'fats': '7.5',
          'sugar': '5.0',
          'fiber': '3.2',
          'sodium': '120.0',
          'servingSize': '100.0',
          'consumedAt': '2026-10-23T10:00:00Z',
          'createdAt': '2026-10-23T10:00:00Z',
          'updatedAt': '2026-10-23T10:00:00Z',
        },
      );

      final model = NutritionRecordModel.fromFirestore(stringNumberDoc);
      expect(model.calories, equals(250.5));
      expect(model.protein, equals(15.2));
      expect(model.fiber, equals(3.2));
      expect(model.sodium, equals(120.0));
    });

    test('Form sheet text editing semantics accurately distinguish null and zero on reopen', () {
      // 1. Record with null fiber and sodium:
      final nullRecord = NutritionRecordEntity(
        id: 'rec_null',
        foodName: 'Item',
        mealType: 'Snack',
        calories: 100.0,
        protein: 2.0,
        carbohydrates: 20.0,
        fats: 1.0,
        sugar: 5.0,
        fiber: null,
        sodium: null,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Reopening logic:
      final fiberTextNull = nullRecord.fiber != null ? nullRecord.fiber!.toStringAsFixed(1) : '';
      final sodiumTextNull = nullRecord.sodium != null ? nullRecord.sodium!.toStringAsFixed(0) : '';
      expect(fiberTextNull, equals(''));
      expect(sodiumTextNull, equals(''));

      // Resubmission from form when user leaves field blank:
      final parsedFiberNull = double.tryParse(fiberTextNull.trim());
      final parsedSodiumNull = double.tryParse(sodiumTextNull.trim());
      expect(parsedFiberNull, isNull, reason: 'Empty string must parse back to null, preserving missing status');
      expect(parsedSodiumNull, isNull, reason: 'Empty string must parse back to null, preserving missing status');

      // 2. Record with legitimate 0.0:
      final zeroRecord = NutritionRecordEntity(
        id: 'rec_zero',
        foodName: 'Item Zero',
        mealType: 'Snack',
        calories: 50.0,
        protein: 0.0,
        carbohydrates: 12.0,
        fats: 0.0,
        sugar: 0.0,
        fiber: 0.0,
        sodium: 0.0,
        servingSize: 100.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final fiberTextZero = zeroRecord.fiber != null ? zeroRecord.fiber!.toStringAsFixed(1) : '';
      final sodiumTextZero = zeroRecord.sodium != null ? zeroRecord.sodium!.toStringAsFixed(0) : '';
      expect(fiberTextZero, equals('0.0'));
      expect(sodiumTextZero, equals('0'));

      final parsedFiberZero = double.tryParse(fiberTextZero.trim());
      final parsedSodiumZero = double.tryParse(sodiumTextZero.trim());
      expect(parsedFiberZero, equals(0.0), reason: 'Legitimate 0.0 must be preserved');
      expect(parsedSodiumZero, equals(0.0), reason: 'Legitimate 0.0 must be preserved');
    });

    test('SyncStatus pending write detection correctly sets pending state', () {
      final pendingDoc = FakeDocumentSnapshot(
        id: 'pending_doc_1',
        data: {
          'foodName': 'Pending Item',
          'mealType': 'Breakfast',
          'calories': 150.0,
          'protein': 5.0,
          'carbohydrates': 20.0,
          'fats': 2.0,
          'sugar': 1.0,
          'servingSize': 100.0,
        },
        metadata: const FakeSnapshotMetadata(hasPendingWrites: true),
      );

      final model = NutritionRecordModel.fromFirestore(pendingDoc);
      expect(model.syncStatus, equals(SyncStatus.pending));

      final syncedDoc = FakeDocumentSnapshot(
        id: 'synced_doc_1',
        data: {
          'foodName': 'Synced Item',
          'mealType': 'Breakfast',
          'calories': 150.0,
          'protein': 5.0,
          'carbohydrates': 20.0,
          'fats': 2.0,
          'sugar': 1.0,
          'servingSize': 100.0,
        },
        metadata: const FakeSnapshotMetadata(hasPendingWrites: false),
      );

      final syncedModel = NutritionRecordModel.fromFirestore(syncedDoc);
      expect(syncedModel.syncStatus, equals(SyncStatus.synced));
    });
  });
}
