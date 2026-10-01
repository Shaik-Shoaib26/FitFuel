import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/logger_service.dart';
import '../models/weight_record_model.dart';

abstract class IProgressRemoteDataSource {
  Future<void> addWeight(String uid, WeightRecordModel record);
  Future<List<WeightRecordModel>> getWeightHistory(String uid);
  Stream<List<WeightRecordModel>> streamWeightHistory(String uid);
}

class ProgressRemoteDataSourceImpl implements IProgressRemoteDataSource {
  final FirebaseFirestore _firestore;

  ProgressRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _weightRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('weightHistory');
  }

  @override
  Future<void> addWeight(String uid, WeightRecordModel record) async {
    try {
      LoggerService.info('Adding weight record to users/$uid/weightHistory');
      final docRef = record.id.isNotEmpty ? _weightRef(uid).doc(record.id) : _weightRef(uid).doc();
      await docRef.set({
        ...record.toFirestore(),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Weight record added successfully');
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException adding weight record [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to save weight.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error adding weight record', e, stackTrace);
      throw ServerException(message: 'Failed to save weight.');
    }
  }

  @override
  Future<List<WeightRecordModel>> getWeightHistory(String uid) async {
    try {
      LoggerService.info('Fetching weight history for users/$uid/weightHistory');
      final snapshot = await _weightRef(uid).orderBy('recordedAt', descending: true).get();
      return snapshot.docs.map((doc) => WeightRecordModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching weight history [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to fetch weight history.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching weight history', e, stackTrace);
      throw ServerException(message: 'Failed to fetch weight history.');
    }
  }

  @override
  Stream<List<WeightRecordModel>> streamWeightHistory(String uid) {
    return _weightRef(uid)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => WeightRecordModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      LoggerService.error('Stream error for weight history of UID: $uid', error, stackTrace);
      throw ServerException(message: 'Error listening to weight updates.');
    });
  }
}
