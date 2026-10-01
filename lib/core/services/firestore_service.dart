import 'package:cloud_firestore/cloud_firestore.dart';
import '../errors/exceptions.dart';
import 'logger_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates user profile document at users/{uid}
  Future<void> createUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      LoggerService.info('Creating Firestore user profile for UID: $uid');
      await _firestore.collection('users').doc(uid).set({
        ...data,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      LoggerService.info('Firestore profile created successfully for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException creating profile for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error creating user profile for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to create user profile in Firestore.');
    }
  }

  /// Gets single user profile document snapshot from users/{uid}
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) async {
    try {
      LoggerService.info('Fetching Firestore user profile for UID: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        LoggerService.warning('Firestore profile document does not exist for UID: $uid');
      }
      return doc;
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching profile for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching user profile for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to retrieve user profile from Firestore.');
    }
  }

  /// Streams real-time updates for users/{uid}
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().handleError((error, stackTrace) {
      LoggerService.error('Stream error for profile UID: $uid', error, stackTrace);
      if (error is FirebaseException) {
        throw ServerException(message: _mapFirestoreException(error));
      }
      throw ServerException(message: 'Error listening to user profile updates.');
    });
  }

  /// Updates existing user profile document at users/{uid}
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      LoggerService.info('Updating Firestore user profile for UID: $uid');
      await _firestore.collection('users').doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      LoggerService.info('Firestore profile updated successfully for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException updating profile for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error updating profile for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to update user profile in Firestore.');
    }
  }

  /// Creates/Updates user goals document at users/{uid}/goals/currentGoal
  Future<void> createUserGoals({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      LoggerService.info('Creating/updating Firestore user goals for UID: $uid');
      await _firestore.collection('users').doc(uid).collection('goals').doc('currentGoal').set({
        ...data,
        'userId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      LoggerService.info('Firestore user goals updated successfully for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException updating goals for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error updating goals for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to update user goals in Firestore.');
    }
  }

  /// Gets single user goals document snapshot from users/{uid}/goals/currentGoal
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserGoals(String uid) async {
    try {
      LoggerService.info('Fetching Firestore user goals for UID: $uid');
      final doc = await _firestore.collection('users').doc(uid).collection('goals').doc('currentGoal').get();
      return doc;
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching goals for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching user goals for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to retrieve user goals from Firestore.');
    }
  }

  /// Streams real-time updates for users/{uid}/goals/currentGoal
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserGoalsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc('currentGoal')
        .snapshots()
        .handleError((error, stackTrace) {
      LoggerService.error('Stream error for goals UID: $uid', error, stackTrace);
      if (error is FirebaseException) {
        throw ServerException(message: _mapFirestoreException(error));
      }
      throw ServerException(message: 'Error listening to user goals updates.');
    });
  }

  /// Deletes user profile document at users/{uid}
  Future<void> deleteUserProfile(String uid) async {
    try {
      LoggerService.info('Deleting Firestore user profile for UID: $uid');
      await _firestore.collection('users').doc(uid).delete();
      LoggerService.info('Firestore profile deleted successfully for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException deleting profile for UID: $uid [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error deleting user profile for UID: $uid', e, stackTrace);
      throw ServerException(message: 'Failed to delete user profile in Firestore.');
    }
  }

  /// Maps raw FirebaseException codes to user-friendly messages
  String _mapFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. You do not have permission to access this user profile.';
      case 'not-found':
        return 'The requested user profile was not found.';
      case 'already-exists':
        return 'This user profile already exists.';
      case 'unavailable':
        return 'Firestore database service is currently unavailable. Please check your internet connection.';
      case 'cancelled':
        return 'Database operation was cancelled.';
      case 'deadline-exceeded':
        return 'Database request timed out. Please try again.';
      default:
        return e.message ?? 'A database error occurred. Please try again.';
    }
  }
}
