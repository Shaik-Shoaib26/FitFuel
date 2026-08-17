import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/grocery_remote_datasource.dart';
import '../../data/repositories/grocery_repository_impl.dart';
import '../../domain/repositories/i_grocery_repository.dart';
import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_list_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../controllers/grocery_controller.dart';

final groceryRemoteDataSourceProvider = Provider<IGroceryRemoteDataSource>((ref) {
  return GroceryRemoteDataSourceImpl();
});

final groceryRepositoryProvider = Provider<IGroceryRepository>((ref) {
  final ds = ref.watch(groceryRemoteDataSourceProvider);
  return GroceryRepositoryImpl(ds);
});

final groceryPreferencesProvider = StreamProvider<GroceryPreferencesEntity?>((ref) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(groceryRepositoryProvider).streamPreferences(user.uid);
});

final groceryListsProvider = StreamProvider<List<GroceryListEntity>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(groceryRepositoryProvider).streamGroceryLists(user.uid);
});

final pantryProvider = StreamProvider<List<PantryItemEntity>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(groceryRepositoryProvider).streamPantryItems(user.uid);
});

final selectedListIdProvider = StateProvider<String?>((ref) {
  final lists = ref.watch(groceryListsProvider).value ?? [];
  return lists.firstOrNull?.id;
});

final groceryItemsProvider = StreamProvider.family<List<GroceryItemEntity>, String>((ref, listId) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(groceryRepositoryProvider).streamGroceryItems(user.uid, listId);
});

final currentGroceryListProvider = Provider<AsyncValue<GroceryListEntity?>>((ref) {
  final listsAsync = ref.watch(groceryListsProvider);
  final selectedId = ref.watch(selectedListIdProvider);

  return listsAsync.when(
    data: (lists) {
      if (lists.isEmpty) return const AsyncValue.data(null);
      final activeList = lists.firstWhere(
        (l) => l.id == selectedId,
        orElse: () => lists.first,
      );

      final itemsAsync = ref.watch(groceryItemsProvider(activeList.id));
      return itemsAsync.when(
        data: (items) {
          final totalCount = items.length;
          final purchasedCount = items.where((i) => i.isPurchased).length;
          final remainingCount = totalCount - purchasedCount;

          return AsyncValue.data(activeList.copyWith(
            items: items,
            totalItems: totalCount,
            purchasedItems: purchasedCount,
            remainingItems: remainingCount,
          ));
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

final groceryCompletionProvider = Provider<double>((ref) {
  final listVal = ref.watch(currentGroceryListProvider).value;
  if (listVal == null) return 0.0;
  return listVal.completionPercentage;
});

final groceryCategoryProvider = Provider<Map<String, List<GroceryItemEntity>>>((ref) {
  final listVal = ref.watch(currentGroceryListProvider).value;
  if (listVal == null) return {};
  
  final Map<String, List<GroceryItemEntity>> grouped = {};
  for (final item in listVal.items) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  return grouped;
});

final groceryControllerProvider = StateNotifierProvider<GroceryController, AsyncValue<void>>((ref) {
  final repo = ref.watch(groceryRepositoryProvider);
  return GroceryController(repo, ref);
});
