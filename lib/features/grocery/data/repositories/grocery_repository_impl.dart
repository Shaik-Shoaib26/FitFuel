import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_list_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../../domain/repositories/i_grocery_repository.dart';
import '../datasources/grocery_remote_datasource.dart';
import '../models/grocery_item_model.dart';
import '../models/grocery_list_model.dart';
import '../models/grocery_preferences_model.dart';
import '../models/pantry_item_model.dart';

import '../../../../core/utils/id_utils.dart';

class GroceryRepositoryImpl implements IGroceryRepository {
  final IGroceryRemoteDataSource _remoteDataSource;

  GroceryRepositoryImpl(this._remoteDataSource);

  @override
  Future<GroceryPreferencesEntity?> getPreferences(String uid) async {
    final model = await _remoteDataSource.getPreferences(uid);
    return model?.toEntity();
  }

  @override
  Future<void> savePreferences(String uid, GroceryPreferencesEntity preferences) async {
    final model = GroceryPreferencesModel.fromEntity(preferences);
    await _remoteDataSource.savePreferences(uid, model);
  }

  @override
  Stream<GroceryPreferencesEntity?> streamPreferences(String uid) {
    return _remoteDataSource.streamPreferences(uid).map((model) => model?.toEntity());
  }

  @override
  Stream<List<GroceryListEntity>> streamGroceryLists(String uid) {
    return _remoteDataSource.streamGroceryLists(uid).map((lists) {
      return lists.map((l) => l.toEntity()).toList();
    });
  }

  @override
  Future<void> saveGroceryList(String uid, GroceryListEntity groceryList) async {
    final listId = groceryList.id.isEmpty ? IdUtils.generateId() : groceryList.id;
    final model = GroceryListModel.fromEntity(groceryList.copyWith(id: listId));
    await _remoteDataSource.saveGroceryList(uid, model);
  }

  @override
  Future<void> deleteGroceryList(String uid, String listId) async {
    await _remoteDataSource.deleteGroceryList(uid, listId);
  }

  @override
  Stream<List<GroceryItemEntity>> streamGroceryItems(String uid, String listId) {
    return _remoteDataSource.streamGroceryItems(uid, listId).map((items) {
      return items.map((i) => i.toEntity()).toList();
    });
  }

  @override
  Future<void> saveGroceryItem(String uid, String listId, GroceryItemEntity item) async {
    final itemId = item.id.isEmpty ? IdUtils.generateId() : item.id;
    final model = GroceryItemModel.fromEntity(item.copyWith(id: itemId));
    await _remoteDataSource.saveGroceryItem(uid, listId, model);
  }

  @override
  Future<void> saveGroceryItems(String uid, String listId, List<GroceryItemEntity> items) async {
    final models = items.map((i) {
      final itemId = i.id.isEmpty ? IdUtils.generateId() : i.id;
      return GroceryItemModel.fromEntity(i.copyWith(id: itemId));
    }).toList();
    await _remoteDataSource.saveGroceryItems(uid, listId, models);
  }

  @override
  Future<void> deleteGroceryItem(String uid, String listId, String itemId) async {
    await _remoteDataSource.deleteGroceryItem(uid, listId, itemId);
  }

  @override
  Stream<List<PantryItemEntity>> streamPantryItems(String uid) {
    return _remoteDataSource.streamPantryItems(uid).map((items) {
      return items.map((i) => i.toEntity()).toList();
    });
  }

  @override
  Future<void> savePantryItem(String uid, PantryItemEntity item) async {
    final itemId = item.id.isEmpty ? IdUtils.generateId() : item.id;
    final model = PantryItemModel.fromEntity(item.copyWith(id: itemId));
    await _remoteDataSource.savePantryItem(uid, model);
  }

  @override
  Future<void> deletePantryItem(String uid, String itemId) async {
    await _remoteDataSource.deletePantryItem(uid, itemId);
  }
}
