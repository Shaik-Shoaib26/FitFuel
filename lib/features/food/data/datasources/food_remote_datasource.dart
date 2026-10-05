import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/logger_service.dart';
import '../models/food_model.dart';

abstract class FoodRemoteDataSource {
  Future<List<FoodModel>> getCustomFoods(String uid);
  Future<FoodModel> addCustomFood(String uid, FoodModel food);
  Future<void> updateCustomFood(String uid, FoodModel food);
  Future<void> deleteCustomFood(String uid, String id);
  Future<List<String>> getFavoriteFoodIds(String uid);
  Future<void> addFavoriteFoodId(String uid, String foodId);
  Future<void> removeFavoriteFoodId(String uid, String foodId);
  Future<List<String>> getRecentFoodIds(String uid);
  Future<void> addRecentFoodId(String uid, String foodId);
}

class FoodRemoteDataSourceImpl implements FoodRemoteDataSource {
  final FirebaseFirestore? _injectedFirestore;

  FoodRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _customFoodsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('customFoods');
  }

  CollectionReference<Map<String, dynamic>> _favoriteFoodsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('favoriteFoods');
  }

  CollectionReference<Map<String, dynamic>> _recentFoodsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('recentFoods');
  }

  @override
  Future<List<FoodModel>> getCustomFoods(String uid) async {
    try {
      LoggerService.info('Fetching custom foods for users/$uid/customFoods');
      final snapshot = await _customFoodsRef(uid).get();
      return snapshot.docs.map((doc) => FoodModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching custom foods', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to fetch custom foods.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching custom foods', e, stackTrace);
      throw ServerException(message: 'Failed to fetch custom foods.');
    }
  }

  @override
  Future<FoodModel> addCustomFood(String uid, FoodModel food) async {
    try {
      LoggerService.info('Adding custom food for users/$uid/customFoods');
      final docRef = food.id.isNotEmpty ? _customFoodsRef(uid).doc(food.id) : _customFoodsRef(uid).doc();
      final newFood = food.toFirestore();
      newFood['createdAt'] = FieldValue.serverTimestamp();
      newFood['updatedAt'] = FieldValue.serverTimestamp();
      newFood['isCustom'] = true;
      await docRef.set(newFood);
      
      final snap = await docRef.get();
      return FoodModel.fromFirestore(snap);
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException adding custom food', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to add custom food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error adding custom food', e, stackTrace);
      throw ServerException(message: 'Failed to add custom food.');
    }
  }

  @override
  Future<void> updateCustomFood(String uid, FoodModel food) async {
    try {
      LoggerService.info('Updating custom food ${food.id} for users/$uid/customFoods');
      final newFood = food.toFirestore();
      newFood['updatedAt'] = FieldValue.serverTimestamp();
      await _customFoodsRef(uid).doc(food.id).update(newFood);
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException updating custom food', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to update custom food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error updating custom food', e, stackTrace);
      throw ServerException(message: 'Failed to update custom food.');
    }
  }

  @override
  Future<void> deleteCustomFood(String uid, String id) async {
    try {
      LoggerService.info('Deleting custom food $id for users/$uid/customFoods');
      await _customFoodsRef(uid).doc(id).delete();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException deleting custom food', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to delete custom food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error deleting custom food', e, stackTrace);
      throw ServerException(message: 'Failed to delete custom food.');
    }
  }

  @override
  Future<List<String>> getFavoriteFoodIds(String uid) async {
    try {
      LoggerService.info('Fetching favorite food IDs for users/$uid/favoriteFoods');
      final snapshot = await _favoriteFoodsRef(uid).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching favorite food IDs', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to fetch favorite food IDs.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching favorite food IDs', e, stackTrace);
      throw ServerException(message: 'Failed to fetch favorite food IDs.');
    }
  }

  @override
  Future<void> addFavoriteFoodId(String uid, String foodId) async {
    try {
      LoggerService.info('Adding favorite food ID $foodId for users/$uid/favoriteFoods');
      await _favoriteFoodsRef(uid).doc(foodId).set({
        'foodId': foodId,
        'isFavorite': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException adding favorite food ID', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to favorite food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error adding favorite food ID', e, stackTrace);
      throw ServerException(message: 'Failed to favorite food.');
    }
  }

  @override
  Future<void> removeFavoriteFoodId(String uid, String foodId) async {
    try {
      LoggerService.info('Removing favorite food ID $foodId for users/$uid/favoriteFoods');
      await _favoriteFoodsRef(uid).doc(foodId).delete();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException removing favorite food ID', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to unfavorite food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error removing favorite food ID', e, stackTrace);
      throw ServerException(message: 'Failed to unfavorite food.');
    }
  }

  @override
  Future<List<String>> getRecentFoodIds(String uid) async {
    try {
      LoggerService.info('Fetching recent food IDs for users/$uid/recentFoods');
      final snapshot = await _recentFoodsRef(uid).orderBy('timestamp', descending: true).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException fetching recent food IDs', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to fetch recent food IDs.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error fetching recent food IDs', e, stackTrace);
      throw ServerException(message: 'Failed to fetch recent food IDs.');
    }
  }

  @override
  Future<void> addRecentFoodId(String uid, String foodId) async {
    try {
      LoggerService.info('Adding/Updating recent food ID $foodId for users/$uid/recentFoods');
      await _recentFoodsRef(uid).doc(foodId).set({
        'foodId': foodId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, stackTrace) {
      LoggerService.error('FirebaseException adding recent food ID', e, stackTrace);
      throw ServerException(message: e.message ?? 'Failed to log recent food.');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error adding recent food ID', e, stackTrace);
      throw ServerException(message: 'Failed to log recent food.');
    }
  }
}
