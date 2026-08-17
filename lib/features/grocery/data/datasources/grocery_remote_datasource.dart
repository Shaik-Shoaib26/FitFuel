import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_item_model.dart';
import '../models/grocery_list_model.dart';
import '../models/grocery_preferences_model.dart';
import '../models/pantry_item_model.dart';

abstract class IGroceryRemoteDataSource {
  Future<GroceryPreferencesModel?> getPreferences(String uid);
  Future<void> savePreferences(String uid, GroceryPreferencesModel preferences);
  Stream<GroceryPreferencesModel?> streamPreferences(String uid);

  Stream<List<GroceryListModel>> streamGroceryLists(String uid);
  Future<void> saveGroceryList(String uid, GroceryListModel groceryList);
  Future<void> deleteGroceryList(String uid, String listId);

  Stream<List<GroceryItemModel>> streamGroceryItems(String uid, String listId);
  Future<void> saveGroceryItem(String uid, String listId, GroceryItemModel item);
  Future<void> saveGroceryItems(String uid, String listId, List<GroceryItemModel> items);
  Future<void> deleteGroceryItem(String uid, String listId, String itemId);

  Stream<List<PantryItemModel>> streamPantryItems(String uid);
  Future<void> savePantryItem(String uid, PantryItemModel item);
  Future<void> deletePantryItem(String uid, String itemId);
}

class GroceryRemoteDataSourceImpl implements IGroceryRemoteDataSource {
  final FirebaseFirestore _firestore;

  GroceryRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<GroceryPreferencesModel?> getPreferences(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryPreferences')
        .doc('preferences')
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return GroceryPreferencesModel.fromFirestore(doc);
  }

  @override
  Future<void> savePreferences(String uid, GroceryPreferencesModel preferences) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryPreferences')
        .doc('preferences')
        .set(preferences.toFirestore(), SetOptions(merge: true));
  }

  @override
  Stream<GroceryPreferencesModel?> streamPreferences(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryPreferences')
        .doc('preferences')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GroceryPreferencesModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<GroceryListModel>> streamGroceryLists(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => GroceryListModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> saveGroceryList(String uid, GroceryListModel groceryList) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(groceryList.id)
        .set(groceryList.toFirestore(), SetOptions(merge: true));

    // Batch write the items inside the subcollection
    if (groceryList.items.isNotEmpty) {
      await saveGroceryItems(uid, groceryList.id, groceryList.items);
    }
  }

  @override
  Future<void> deleteGroceryList(String uid, String listId) async {
    // Delete all items first
    final itemsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(listId)
        .collection('items')
        .get();
    
    final batch = _firestore.batch();
    for (final doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(listId));
    
    await batch.commit();
  }

  @override
  Stream<List<GroceryItemModel>> streamGroceryItems(String uid, String listId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(listId)
        .collection('items')
        .orderBy('foodName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => GroceryItemModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> saveGroceryItem(String uid, String listId, GroceryItemModel item) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(listId)
        .collection('items')
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> saveGroceryItems(String uid, String listId, List<GroceryItemModel> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('groceryLists')
          .doc(listId)
          .collection('items')
          .doc(item.id);
      batch.set(docRef, item.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> deleteGroceryItem(String uid, String listId, String itemId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('groceryLists')
        .doc(listId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  @override
  Stream<List<PantryItemModel>> streamPantryItems(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .orderBy('expiryDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PantryItemModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> savePantryItem(String uid, PantryItemModel item) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deletePantryItem(String uid, String itemId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .doc(itemId)
        .delete();
  }
}
