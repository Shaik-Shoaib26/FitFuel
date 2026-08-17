import '../entities/grocery_item_entity.dart';
import '../entities/grocery_list_entity.dart';
import '../entities/grocery_preferences_entity.dart';
import '../entities/pantry_item_entity.dart';

abstract class IGroceryRepository {
  Future<GroceryPreferencesEntity?> getPreferences(String uid);
  Future<void> savePreferences(String uid, GroceryPreferencesEntity preferences);
  Stream<GroceryPreferencesEntity?> streamPreferences(String uid);

  Stream<List<GroceryListEntity>> streamGroceryLists(String uid);
  Future<void> saveGroceryList(String uid, GroceryListEntity groceryList);
  Future<void> deleteGroceryList(String uid, String listId);

  Stream<List<GroceryItemEntity>> streamGroceryItems(String uid, String listId);
  Future<void> saveGroceryItem(String uid, String listId, GroceryItemEntity item);
  Future<void> saveGroceryItems(String uid, String listId, List<GroceryItemEntity> items);
  Future<void> deleteGroceryItem(String uid, String listId, String itemId);

  Stream<List<PantryItemEntity>> streamPantryItems(String uid);
  Future<void> savePantryItem(String uid, PantryItemEntity item);
  Future<void> deletePantryItem(String uid, String itemId);
}
