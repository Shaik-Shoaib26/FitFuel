import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/logger_service.dart';
import '../models/health_record_model.dart';

abstract class IHealthRemoteDataSource {
  Future<void> saveRecord(String uid, HealthRecordModel record);
  Future<HealthRecordModel?> getRecord(String uid, String date);
  Stream<HealthRecordModel?> streamRecord(String uid, String date);
  Stream<List<HealthRecordModel>> streamAllRecords(String uid);
}

class HealthRemoteDataSourceImpl implements IHealthRemoteDataSource {
  final FirebaseFirestore _firestore;

  HealthRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _healthRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('health');
  }

  @override
  Future<void> saveRecord(String uid, HealthRecordModel record) async {
    try {
      LoggerService.info('Saving health record for UID: $uid on date: ${record.date}');
      final docRef = _healthRef(uid).doc(record.date);
      await docRef.set({
        ...record.toFirestore(),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      LoggerService.info('Health record successfully saved');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException saving health record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to save health data.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error saving health record', e, stackTrace);
      throw ServerException(message: 'Failed to save health data.');
    }
  }

  @override
  Future<HealthRecordModel?> getRecord(String uid, String date) async {
    try {
      LoggerService.info('Fetching health record for UID: $uid on date: $date');
      final doc = await _healthRef(uid).doc(date).get();
      if (!doc.exists) return null;
      return HealthRecordModel.fromFirestore(doc);
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching health record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to fetch health data.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching health record', e, stackTrace);
      throw ServerException(message: 'Failed to fetch health data.');
    }
  }

  @override
  Stream<HealthRecordModel?> streamRecord(String uid, String date) {
    return _healthRef(uid).doc(date).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return HealthRecordModel.fromFirestore(snapshot);
    }).handleError((error, stackTrace) {
      LoggerService.error('Stream error for health record of UID: $uid on date: $date', error, stackTrace);
      throw ServerException(message: 'Error listening to health record updates.');
    });
  }

  @override
  Stream<List<HealthRecordModel>> streamAllRecords(String uid) {
    return _healthRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => HealthRecordModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      LoggerService.error('Stream error for all health records of UID: $uid', error, stackTrace);
      throw ServerException(message: 'Error listening to health history updates.');
    });
  }
}
