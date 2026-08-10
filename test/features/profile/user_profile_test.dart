import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/profile/data/models/user_profile_model.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  final testEntity = UserProfileEntity(
    uid: 'test_uid_123',
    email: 'user@example.com',
    displayName: 'FitFuel User',
    photoUrl: 'https://example.com/photo.jpg',
    emailVerified: true,
    createdAt: now,
    updatedAt: now,
  );

  final testModel = UserProfileModel(
    uid: 'test_uid_123',
    email: 'user@example.com',
    displayName: 'FitFuel User',
    photoUrl: 'https://example.com/photo.jpg',
    emailVerified: true,
    createdAt: now,
    updatedAt: now,
  );

  group('UserProfileEntity Tests', () {
    test('Entity properties verify correctly', () {
      expect(testEntity.uid, 'test_uid_123');
      expect(testEntity.email, 'user@example.com');
      expect(testEntity.displayName, 'FitFuel User');
      expect(testEntity.photoUrl, 'https://example.com/photo.jpg');
      expect(testEntity.emailVerified, isTrue);
      expect(testEntity.createdAt, now);
      expect(testEntity.updatedAt, now);
    });

    test('Entity equality and copyWith work correctly', () {
      final copy = testEntity.copyWith(displayName: 'Updated Name');
      expect(copy.displayName, 'Updated Name');
      expect(copy.uid, testEntity.uid);
      expect(copy.email, testEntity.email);

      final identicalCopy = testEntity.copyWith();
      expect(identicalCopy, testEntity);
    });
  });

  group('UserProfileModel Conversion Tests', () {
    test('Model toEntity converts accurately to UserProfileEntity', () {
      final entity = testModel.toEntity();
      expect(entity, testEntity);
    });

    test('Model fromEntity converts accurately from UserProfileEntity', () {
      final model = UserProfileModel.fromEntity(testEntity);
      expect(model.uid, testEntity.uid);
      expect(model.email, testEntity.email);
      expect(model.displayName, testEntity.displayName);
      expect(model.photoUrl, testEntity.photoUrl);
      expect(model.emailVerified, testEntity.emailVerified);
    });

    test('Model toFirestore produces valid Timestamp and schema fields', () {
      final firestoreMap = testModel.toFirestore();
      expect(firestoreMap['uid'], 'test_uid_123');
      expect(firestoreMap['email'], 'user@example.com');
      expect(firestoreMap['displayName'], 'FitFuel User');
      expect(firestoreMap['photoUrl'], 'https://example.com/photo.jpg');
      expect(firestoreMap['emailVerified'], isTrue);
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      expect(firestoreMap['updatedAt'], isA<Timestamp>());
    });
  });
}
