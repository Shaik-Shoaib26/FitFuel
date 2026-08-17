import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitfuel/features/meal_planner/data/models/meal_plan_model.dart';
import 'package:intl/intl.dart';

abstract class MealPlanDataSource {
  Future<MealPlanModel?> getMealPlanForDate(String userId, DateTime date);
  Future<void> saveMealPlan(String userId, MealPlanModel mealPlan);
  Future<void> deleteMealPlan(String userId, String mealPlanId);
}

class MealPlanRemoteDataSource implements MealPlanDataSource {
  final FirebaseFirestore _firestore;

  MealPlanRemoteDataSource(this._firestore);

  String _getDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Future<MealPlanModel?> getMealPlanForDate(String userId, DateTime date) async {
    final dateStr = _getDateString(date);
    
    // We store meal plans with date as document ID: users/{uid}/mealPlans/{dateStr}
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealPlans')
        .doc(dateStr)
        .get();

    if (doc.exists) {
      return MealPlanModel.fromFirestore(doc);
    }
    return null;
  }

  @override
  Future<void> saveMealPlan(String userId, MealPlanModel mealPlan) async {
    final dateStr = _getDateString(mealPlan.date);
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealPlans')
        .doc(dateStr) // override id with dateStr just in case
        .set(mealPlan.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteMealPlan(String userId, String mealPlanId) async {
    // Note: mealPlanId should be the date string if we follow the convention
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealPlans')
        .doc(mealPlanId)
        .delete();
  }
}
