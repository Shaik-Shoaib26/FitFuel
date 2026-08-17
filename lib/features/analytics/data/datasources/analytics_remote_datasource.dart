import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../nutrition/data/models/nutrition_record_model.dart';
import '../../../health/data/models/health_record_model.dart';
import '../../../progress/data/models/weight_record_model.dart';
import '../../../profile/data/models/user_profile_model.dart';
import '../../../profile/data/models/nutrition_goals_model.dart';

abstract class IAnalyticsRemoteDataSource {
  Future<List<NutritionRecordModel>> getNutritionRecords(String uid);
  Future<List<HealthRecordModel>> getHealthRecords(String uid);
  Future<List<WeightRecordModel>> getWeightHistory(String uid);
  Future<UserProfileModel?> getUserProfile(String uid);
  Future<NutritionGoalsModel?> getNutritionGoals(String uid);
}

class AnalyticsRemoteDataSourceImpl implements IAnalyticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  AnalyticsRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<NutritionRecordModel>> getNutritionRecords(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('nutrition').orderBy('consumedAt', descending: true).get();
    return snapshot.docs.map((doc) => NutritionRecordModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<HealthRecordModel>> getHealthRecords(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('health').orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => HealthRecordModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<WeightRecordModel>> getWeightHistory(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('weightHistory').orderBy('recordedAt', descending: true).get();
    return snapshot.docs.map((doc) => WeightRecordModel.fromFirestore(doc)).toList();
  }

  @override
  Future<UserProfileModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfileModel.fromFirestore(doc);
  }

  @override
  Future<NutritionGoalsModel?> getNutritionGoals(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).collection('goals').doc('currentGoal').get();
    if (!doc.exists) return null;
    return NutritionGoalsModel.fromFirestore(doc);
  }
}
