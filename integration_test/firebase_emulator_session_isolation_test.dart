import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/core/config/firebase_emulator_config.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/nutrition/data/datasources/nutrition_remote_datasource.dart';
import 'package:fitfuel/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:fitfuel/features/nutrition/domain/entities/nutrition_record_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 35.12.20 — Flutter Firebase Emulator Session Isolation & Contract Tests', () {
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;

    setUpAll(() async {
      // Connect to local emulators
      FirebaseEmulatorConfig.useEmulators();
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;
    });

    testWidgets('A. Authentication & Repository Identity Isolation', (tester) async {
      final emailA = 'alice_integ_${DateTime.now().millisecondsSinceEpoch}@fitfuel.test';
      final emailB = 'bob_integ_${DateTime.now().millisecondsSinceEpoch}@fitfuel.test';
      const password = 'Password123!';

      // 1. Sign in as synthetic User A
      final credA = await auth.createUserWithEmailAndPassword(email: emailA, password: password);
      final uidA = credA.user!.uid;
      expect(uidA.isNotEmpty, isTrue);

      final remoteDs = NutritionRemoteDataSourceImpl(firestore: firestore);
      final repo = NutritionRepositoryImpl(remoteDs);

      // 2. Create nutrition record under User A
      final now = DateTime.now();
      final recordA = NutritionRecordEntity(
        id: 'rec_alice_sdk_1',
        foodName: 'Grilled Salmon',
        mealType: 'Dinner',
        calories: 350.0,
        protein: 34.0,
        carbohydrates: 0.0,
        fats: 22.0,
        sugar: 0.0,
        fiber: 0.0,
        sodium: 90.0,
        servingSize: 150.0,
        nutritionTier: NutritionProfileTier.verifiedExact,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addRecord(uidA, recordA);

      // 3. Confirm stored record belongs under users/{uidA}/nutrition
      final snapshotA = await firestore.collection('users').doc(uidA).collection('nutrition').doc('rec_alice_sdk_1').get();
      expect(snapshotA.exists, isTrue);
      expect(snapshotA.data()?['foodName'], equals('Grilled Salmon'));

      // 4. Read back through normal repository flow
      final recordsA = await repo.getRecords(uidA);
      expect(recordsA.length, equals(1));
      expect(recordsA.first.id, equals('rec_alice_sdk_1'));

      // 5. Sign out User A and sign in as User B
      await auth.signOut();
      final credB = await auth.createUserWithEmailAndPassword(email: emailB, password: password);
      final uidB = credB.user!.uid;
      expect(uidB, isNot(equals(uidA)));

      // 6. User B cannot read or modify User A's record directly
      expect(
        () async => await firestore.collection('users').doc(uidA).collection('nutrition').doc('rec_alice_sdk_1').get(),
        throwsA(isA<FirebaseException>()),
      );

      // 7. User B diary contains only User B records (initially empty)
      final recordsB = await repo.getRecords(uidB);
      expect(recordsB, isEmpty);

      await auth.signOut();
    });

    testWidgets('B. Sign-out & Session Switching Isolation in Riverpod', (tester) async {
      final emailA = 'alice_switch_${DateTime.now().millisecondsSinceEpoch}@fitfuel.test';
      final emailB = 'bob_switch_${DateTime.now().millisecondsSinceEpoch}@fitfuel.test';
      const password = 'Password123!';

      final credA = await auth.createUserWithEmailAndPassword(email: emailA, password: password);
      final uidA = credA.user!.uid;

      final remoteDs = NutritionRemoteDataSourceImpl(firestore: firestore);
      final repo = NutritionRepositoryImpl(remoteDs);

      final now = DateTime.now();
      await repo.addRecord(
        uidA,
        NutritionRecordEntity(
          id: 'rec_a_live',
          foodName: 'Live Alice Oats',
          mealType: 'Breakfast',
          calories: 200.0,
          protein: 6.0,
          carbohydrates: 35.0,
          fats: 3.0,
          sugar: 1.0,
          servingSize: 100.0,
          consumedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          nutritionRemoteDataSourceProvider.overrideWithValue(remoteDs),
          nutritionRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Watch nutritionStreamProvider
      final sub = container.listen(nutritionStreamProvider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(container.read(nutritionStreamProvider).value?.any((r) => r.id == 'rec_a_live'), isTrue);

      // Sign out
      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // After sign out, provider must emit empty list
      expect(container.read(nutritionStreamProvider).value, isEmpty);

      // Sign in as User B
      await auth.signInWithEmailAndPassword(email: emailB, password: password);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // User B must see only User B records (empty)
      final stateB = container.read(nutritionStreamProvider).value;
      expect(stateB, isEmpty);
      expect(stateB?.any((r) => r.id == 'rec_a_live'), isFalse);

      await auth.signOut();
    });

    testWidgets('C. Nutrition Persistence & Nullable Update Semantics', (tester) async {
      final emailA = 'alice_updates_${DateTime.now().millisecondsSinceEpoch}@fitfuel.test';
      const password = 'Password123!';

      final credA = await auth.createUserWithEmailAndPassword(email: emailA, password: password);
      final uidA = credA.user!.uid;

      final remoteDs = NutritionRemoteDataSourceImpl(firestore: firestore);
      final repo = NutritionRepositoryImpl(remoteDs);

      final now = DateTime.now();
      final initialRecord = NutritionRecordEntity(
        id: 'rec_update_test',
        foodName: 'Almond Granola',
        mealType: 'Breakfast',
        calories: 220.0,
        protein: 7.0,
        carbohydrates: 30.0,
        fats: 8.0,
        sugar: 4.0,
        fiber: 5.0, // Nonzero
        sodium: 40.0, // Nonzero
        servingSize: 60.0,
        consumedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addRecord(uidA, initialRecord);

      // Verify readback
      final fetched = await repo.getRecords(uidA);
      expect(fetched.first.fiber, equals(5.0));
      expect(fetched.first.sodium, equals(40.0));

      // Update with zero values
      final zeroRecord = initialRecord.copyWith(fiber: 0.0, sodium: 0.0);
      await repo.updateRecord(uidA, zeroRecord);

      final fetchedZeros = await repo.getRecords(uidA);
      expect(fetchedZeros.first.fiber, equals(0.0), reason: 'Legitimate 0.0 must be preserved');
      expect(fetchedZeros.first.sodium, equals(0.0), reason: 'Legitimate 0.0 must be preserved');

      // Update with null values
      final nullRecord = initialRecord.copyWith(fiber: null, sodium: null);
      await repo.updateRecord(uidA, nullRecord);

      final fetchedNulls = await repo.getRecords(uidA);
      // Verify preserved or null
      expect(fetchedNulls.first.foodName, equals('Almond Granola'));

      await auth.signOut();
    });
  });
}
