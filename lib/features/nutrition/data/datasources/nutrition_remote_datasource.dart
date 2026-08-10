import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/logger_service.dart';
import '../models/nutrition_record_model.dart';

abstract class INutritionRemoteDataSource {
  Future<void> addRecord(String uid, NutritionRecordModel record);
  Future<List<NutritionRecordModel>> getRecords(String uid);
  Stream<List<NutritionRecordModel>> streamRecords(String uid);
  Future<void> updateRecord(String uid, NutritionRecordModel record);
  Future<void> deleteRecord(String uid, String recordId);
}

class NutritionRemoteDataSourceImpl implements INutritionRemoteDataSource {
  final FirebaseFirestore _firestore;

  NutritionRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _nutritionRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('nutrition');
  }

  @override
  Future<void> addRecord(String uid, NutritionRecordModel record) async {
    try {
      LoggerService.info('Adding nutrition record to users/$uid/nutrition');
      final docRef = record.id.isNotEmpty ? _nutritionRef(uid).doc(record.id) : _nutritionRef(uid).doc();
      await docRef.set({
        ...record.toFirestore(),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Nutrition record successfully added for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException adding nutrition record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error adding nutrition record', e, stackTrace);
      throw ServerException(message: 'Failed to add nutrition record.');
    }
  }

  @override
  Future<List<NutritionRecordModel>> getRecords(String uid) async {
    try {
      LoggerService.info('Fetching nutrition records for users/$uid/nutrition');
      final snapshot = await _nutritionRef(uid).orderBy('consumedAt', descending: true).get();
      return snapshot.docs.map((doc) => NutritionRecordModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching nutrition records [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching nutrition records', e, stackTrace);
      throw ServerException(message: 'Failed to fetch nutrition records.');
    }
  }

  @override
  Stream<List<NutritionRecordModel>> streamRecords(String uid) {
    return _nutritionRef(uid)
        .orderBy('consumedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NutritionRecordModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      LoggerService.error('Stream error for nutrition records of UID: $uid', error, stackTrace);
      if (error is FirebaseException) {
        throw ServerException(message: _mapFirestoreException(error));
      }
      throw ServerException(message: 'Error listening to nutrition updates.');
    });
  }

  @override
  Future<void> updateRecord(String uid, NutritionRecordModel record) async {
    try {
      LoggerService.info('Updating nutrition record ${record.id} for users/$uid/nutrition');
      await _nutritionRef(uid).doc(record.id).update({
        ...record.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Nutrition record successfully updated for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException updating nutrition record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error updating nutrition record', e, stackTrace);
      throw ServerException(message: 'Failed to update nutrition record.');
    }
  }

  @override
  Future<void> deleteRecord(String uid, String recordId) async {
    try {
      LoggerService.info('Deleting nutrition record $recordId from users/$uid/nutrition');
      await _nutritionRef(uid).doc(recordId).delete();
      LoggerService.info('Nutrition record successfully deleted for UID: $uid');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException deleting nutrition record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirestoreException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error deleting nutrition record', e, stackTrace);
      throw ServerException(message: 'Failed to delete nutrition record.');
    }
  }

  String _mapFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. You do not have permission to modify this nutrition record.';
      case 'not-found':
        return 'Requested nutrition record not found.';
      case 'unavailable':
        return 'Database service is currently offline. Please check your internet connection.';
      default:
        return e.message ?? 'A database error occurred while modifying nutrition data.';
    }
  }
}
