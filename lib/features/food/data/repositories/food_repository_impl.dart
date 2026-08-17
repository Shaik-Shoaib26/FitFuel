import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/utils/food_search_engine.dart';
import '../datasources/food_remote_datasource.dart';
import '../datasources/predefined_food_data.dart';
import '../models/food_model.dart';

class FoodRepositoryImpl implements FoodRepository {
  final FoodRemoteDataSource _remoteDataSource;
  final FirebaseAuth _firebaseAuth;

  FoodRepositoryImpl(this._remoteDataSource, {FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  String _getRequiredUid() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw ServerException(message: 'User must be authenticated.');
    }
    return uid;
  }

  @override
  Future<List<FoodEntity>> searchFoods(String query) async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      final List<FoodEntity> allFoods = [];

      // Add predefined foods
      allFoods.addAll(PredefinedFoodData.foods.map((m) => m.toEntity()));

      // Add custom foods if authenticated
      if (uid != null) {
        final customModels = await _remoteDataSource.getCustomFoods(uid);
        allFoods.addAll(customModels.map((m) => m.toEntity().copyWith(isCustom: true)));
      }

      // Mark favorites
      if (uid != null) {
        final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
        for (int i = 0; i < allFoods.length; i++) {
          if (favIds.contains(allFoods[i].id)) {
            allFoods[i] = allFoods[i].copyWith(isFavorite: true);
          }
        }
      }

      return FoodSearchEngine.search(foods: allFoods, query: query);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<FoodEntity?> getFoodById(String id) async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      FoodEntity? found;

      // Check predefined
      final predefinedMatch = PredefinedFoodData.foods.where((f) => f.id == id).firstOrNull;
      if (predefinedMatch != null) {
        found = predefinedMatch.toEntity();
      } else if (uid != null) {
        final customModels = await _remoteDataSource.getCustomFoods(uid);
        final customMatch = customModels.where((f) => f.id == id).firstOrNull;
        if (customMatch != null) {
          found = customMatch.toEntity().copyWith(isCustom: true);
        }
      }

      if (found != null && uid != null) {
        final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
        if (favIds.contains(found.id)) {
          found = found.copyWith(isFavorite: true);
        }
      }

      return found;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<FoodEntity>> getFoodsByCategory(String category) async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      final List<FoodEntity> categoryFoods = [];

      // Add predefined match
      final catLower = category.toLowerCase().trim();
      categoryFoods.addAll(PredefinedFoodData.foods
          .where((f) => f.category.toLowerCase().trim() == catLower)
          .map((m) => m.toEntity()));

      if (uid != null) {
        final customModels = await _remoteDataSource.getCustomFoods(uid);
        categoryFoods.addAll(customModels
            .where((f) => f.category.toLowerCase().trim() == catLower)
            .map((m) => m.toEntity().copyWith(isCustom: true)));
      }

      // Mark favorites
      if (uid != null) {
        final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
        for (int i = 0; i < categoryFoods.length; i++) {
          if (favIds.contains(categoryFoods[i].id)) {
            categoryFoods[i] = categoryFoods[i].copyWith(isFavorite: true);
          }
        }
      }

      return categoryFoods;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<FoodEntity>> getFavoriteFoods() async {
    try {
      final uid = _getRequiredUid();
      final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
      if (favIds.isEmpty) return [];

      final List<FoodEntity> allFoods = [];
      allFoods.addAll(PredefinedFoodData.foods.map((m) => m.toEntity()));

      final customModels = await _remoteDataSource.getCustomFoods(uid);
      allFoods.addAll(customModels.map((m) => m.toEntity().copyWith(isCustom: true)));

      return allFoods
          .where((f) => favIds.contains(f.id))
          .map((f) => f.copyWith(isFavorite: true))
          .toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<FoodEntity>> getRecentFoods() async {
    try {
      final uid = _getRequiredUid();
      final recentIds = await _remoteDataSource.getRecentFoodIds(uid);
      if (recentIds.isEmpty) return [];

      final List<FoodEntity> allFoods = [];
      allFoods.addAll(PredefinedFoodData.foods.map((m) => m.toEntity()));

      final customModels = await _remoteDataSource.getCustomFoods(uid);
      allFoods.addAll(customModels.map((m) => m.toEntity().copyWith(isCustom: true)));

      final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);

      // Reconstruct list in the recentIds ordering
      final result = <FoodEntity>[];
      for (final id in recentIds) {
        final match = allFoods.where((f) => f.id == id).firstOrNull;
        if (match != null) {
          result.add(match.copyWith(isFavorite: favIds.contains(id)));
        }
      }

      return result;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<FoodEntity> addCustomFood(FoodEntity food) async {
    try {
      final uid = _getRequiredUid();
      final model = FoodModel.fromEntity(food);
      final addedModel = await _remoteDataSource.addCustomFood(uid, model);
      return addedModel.toEntity().copyWith(isCustom: true);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateCustomFood(FoodEntity food) async {
    try {
      final uid = _getRequiredUid();
      final model = FoodModel.fromEntity(food);
      await _remoteDataSource.updateCustomFood(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteCustomFood(String id) async {
    try {
      final uid = _getRequiredUid();
      await _remoteDataSource.deleteCustomFood(uid, id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    try {
      final uid = _getRequiredUid();
      final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
      if (favIds.contains(id)) {
        await _remoteDataSource.removeFavoriteFoodId(uid, id);
      } else {
        await _remoteDataSource.addFavoriteFoodId(uid, id);
      }
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> addRecentFood(FoodEntity food) async {
    try {
      final uid = _getRequiredUid();
      await _remoteDataSource.addRecentFoodId(uid, food.id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<FoodEntity>> getCustomFoods() async {
    try {
      final uid = _getRequiredUid();
      final customModels = await _remoteDataSource.getCustomFoods(uid);
      final favIds = await _remoteDataSource.getFavoriteFoodIds(uid);
      return customModels.map((m) => m.toEntity().copyWith(
        isCustom: true,
        isFavorite: favIds.contains(m.id),
      )).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
