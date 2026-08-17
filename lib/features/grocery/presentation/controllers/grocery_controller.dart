import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../../domain/repositories/i_grocery_repository.dart';
import '../../domain/utils/smart_grocery_engine.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../meal_planner/domain/entities/meal_plan_entity.dart';
import '../providers/grocery_providers.dart';

class GroceryController extends StateNotifier<AsyncValue<void>> {
  final IGroceryRepository _repository;
  final Ref _ref;

  GroceryController(this._repository, this._ref) : super(const AsyncValue.data(null));

  String? get _uid => _ref.read(authStateStreamProvider).value?.uid;

  Future<void> generateGroceryList({
    required List<MealPlanEntity> mealPlans,
    required List<PantryItemEntity> pantryItems,
    required GroceryPreferencesEntity preferences,
    List<GroceryItemEntity> existingItems = const [],
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    state = const AsyncValue.loading();
    try {
      final newList = SmartGroceryEngine.generateFromMealPlan(
        userId: uid,
        mealPlans: mealPlans,
        pantryItems: pantryItems,
        preferences: preferences,
        existingItems: existingItems,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      await _repository.saveGroceryList(uid, newList);
      _ref.read(selectedListIdProvider.notifier).state = newList.id;
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> regenerateGroceryList({
    required List<MealPlanEntity> mealPlans,
    required List<PantryItemEntity> pantryItems,
    required GroceryPreferencesEntity preferences,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final currentId = _ref.read(selectedListIdProvider);
    if (currentId == null) {
      await generateGroceryList(
        mealPlans: mealPlans,
        pantryItems: pantryItems,
        preferences: preferences,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      final lists = _ref.read(groceryListsProvider).value ?? [];
      final activeList = lists.where((l) => l.id == currentId).firstOrNull;
      
      final currentItems = _ref.read(groceryItemsProvider(currentId)).value ?? [];

      final newList = SmartGroceryEngine.generateFromMealPlan(
        userId: uid,
        mealPlans: mealPlans,
        pantryItems: pantryItems,
        preferences: preferences,
        existingItems: currentItems,
        periodStart: activeList?.periodStart,
        periodEnd: activeList?.periodEnd,
      );

      // Keep the same ID so we replace it in place
      final listToSave = newList.copyWith(id: currentId);
      await _repository.saveGroceryList(uid, listToSave);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addGroceryItem(String listId, GroceryItemEntity item) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.saveGroceryItem(uid, listId, item);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> removeGroceryItem(String listId, String itemId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.deleteGroceryItem(uid, listId, itemId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> togglePurchased(String listId, GroceryItemEntity item) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final updated = item.copyWith(
        isPurchased: !item.isPurchased,
        purchasedAt: !item.isPurchased ? DateTime.now() : null,
      );
      await _repository.saveGroceryItem(uid, listId, updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> clearPurchased(String listId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final items = _ref.read(groceryItemsProvider(listId)).value ?? [];
      for (final item in items) {
        if (item.isPurchased) {
          await _repository.deleteGroceryItem(uid, listId, item.id);
        }
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addPantryItem(PantryItemEntity item) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.savePantryItem(uid, item);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> removePantryItem(String itemId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.deletePantryItem(uid, itemId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updatePantryQuantity(String itemId, double newQty) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final pantryItems = _ref.read(pantryProvider).value ?? [];
      final item = pantryItems.where((i) => i.id == itemId).firstOrNull;
      if (item != null) {
        await _repository.savePantryItem(uid, item.copyWith(quantity: newQty));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> savePreferences(GroceryPreferencesEntity preferences) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.savePreferences(uid, preferences);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
