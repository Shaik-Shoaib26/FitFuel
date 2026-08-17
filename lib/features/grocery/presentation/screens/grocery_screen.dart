import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_button.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_category_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/grocery_list_entity.dart';
import '../providers/grocery_providers.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';

class GroceryScreen extends ConsumerStatefulWidget {
  const GroceryScreen({super.key});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addItemNameController = TextEditingController();
  final TextEditingController _addItemQtyController = TextEditingController();
  String _addItemCategory = 'Other';
  String _addItemUnit = 'g';

  final TextEditingController _pantryNameController = TextEditingController();
  final TextEditingController _pantryQtyController = TextEditingController();
  String _pantryUnit = 'g';
  DateTime _pantryExpiry = DateTime.now().add(const Duration(days: 7));

  String _filterType = 'All'; // 'All', 'Remaining', 'Purchased', 'Pantry'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _addItemNameController.dispose();
    _addItemQtyController.dispose();
    _pantryNameController.dispose();
    _pantryQtyController.dispose();
    super.dispose();
  }

  void _showAddCustomItemDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _addItemNameController,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addItemQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _addItemUnit,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _addItemUnit = val;
                              });
                            }
                          },
                          items: ['g', 'kg', 'ml', 'L', 'pieces', 'cups', 'tbsp', 'tsp']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _addItemCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            _addItemCategory = val;
                          });
                        }
                      },
                      items: GroceryCategoryEntity.categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = _addItemNameController.text.trim();
                    final qty = double.tryParse(_addItemQtyController.text) ?? 1.0;
                    if (name.isNotEmpty) {
                      final selectedId = ref.read(selectedListIdProvider);
                      if (selectedId != null) {
                        ref.read(groceryControllerProvider.notifier).addGroceryItem(
                              selectedId,
                              GroceryItemEntity(
                                id: '${DateTime.now().microsecondsSinceEpoch}_custom_item',
                                foodName: name,
                                category: _addItemCategory,
                                quantity: qty,
                                unit: _addItemUnit,
                                addedAt: DateTime.now(),
                              ),
                            );
                      }
                      _addItemNameController.clear();
                      _addItemQtyController.clear();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPantryItemDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Pantry Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _pantryNameController,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pantryQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _pantryUnit,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _pantryUnit = val;
                              });
                            }
                          },
                          items: ['g', 'kg', 'ml', 'L', 'pieces', 'cups', 'tbsp', 'tsp']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expiry Date: ${_pantryExpiry.toString().split(' ').first}'),
                        IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _pantryExpiry,
                              firstDate: DateTime.now().subtract(const Duration(days: 305)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                _pantryExpiry = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = _pantryNameController.text.trim();
                    final qty = double.tryParse(_pantryQtyController.text) ?? 1.0;
                    if (name.isNotEmpty) {
                      ref.read(groceryControllerProvider.notifier).addPantryItem(
                            PantryItemEntity(
                              id: '${DateTime.now().microsecondsSinceEpoch}_pantry_item',
                              foodName: name,
                              quantity: qty,
                              unit: _pantryUnit,
                              expiryDate: _pantryExpiry,
                              addedAt: DateTime.now(),
                            ),
                          );
                      _pantryNameController.clear();
                      _pantryQtyController.clear();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listAsync = ref.watch(currentGroceryListProvider);
    final pantryAsync = ref.watch(pantryProvider);
    final preferencesAsync = ref.watch(groceryPreferencesProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: AppBar(
        title: const Text('Smart Grocery & Pantry'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Shopping List', icon: Icon(Icons.shopping_cart_outlined)),
            Tab(text: 'Pantry Stock', icon: Icon(Icons.kitchen_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Grocery List
          listAsync.when(
            data: (list) {
              if (list == null) {
                return _buildNoListState();
              }
              return _buildGroceryTab(list, preferencesAsync.value ?? const GroceryPreferencesEntity());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          // Tab 2: Pantry
          pantryAsync.when(
            data: (pantryItems) {
              return _buildPantryTab(pantryItems);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildNoListState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: 80, color: AppColors.primary500),
            const SizedBox(height: 16),
            Text('No Active Shopping List', style: AppTypography.heading2(isDark: isDark)),
            const SizedBox(height: 8),
            Text(
              'Convert your meal planner requirements into an organized, category-grouped grocery checklist.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FitFuelButton(
              label: 'Generate List from Meal Plan',
              icon: Icons.flash_on_rounded,
              onPressed: () {
                final activePlan = ref.read(mealPlannerControllerProvider).value;
                if (activePlan != null) {
                  ref.read(groceryControllerProvider.notifier).generateGroceryList(
                    mealPlans: [activePlan],
                    pantryItems: ref.read(pantryProvider).value ?? [],
                    preferences: ref.read(groceryPreferencesProvider).value ?? const GroceryPreferencesEntity(),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please generate or set up a meal plan first in the Meal Planner.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroceryTab(GroceryListEntity list, GroceryPreferencesEntity preferences) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apply Search Query
    final filteredItems = list.items.where((i) {
      final nameMatches = i.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
      final catMatches = i.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final noteMatches = i.notes != null && i.notes!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSearch = nameMatches || catMatches || noteMatches;

      if (!matchesSearch) return false;

      switch (_filterType) {
        case 'Remaining':
          return !i.isPurchased;
        case 'Purchased':
          return i.isPurchased;
        default:
          return true;
      }
    }).toList();

    // Group filtered items by category
    final Map<String, List<GroceryItemEntity>> grouped = {};
    for (final item in filteredItems) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Grocery List',
                        style: AppTypography.heading3(isDark: isDark),
                      ),
                      Text(
                        '${list.purchasedItems} of ${list.totalItems} items purchased',
                        style: AppTypography.caption(isDark: isDark).copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${list.completionPercentage.toStringAsFixed(0)}%',
                        style: AppTypography.heading2(isDark: isDark).copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primary500),
                        tooltip: 'Regenerate List',
                        onPressed: () {
                          final activePlan = ref.read(mealPlannerControllerProvider).value;
                          if (activePlan != null) {
                            ref.read(groceryControllerProvider.notifier).regenerateGroceryList(
                              mealPlans: [activePlan],
                              pantryItems: ref.read(pantryProvider).value ?? [],
                              preferences: preferences,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Grocery list regenerated successfully!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: list.completionPercentage / 100.0,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
              ),
            ],
          ),
        ),

        // Search and Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search groceries...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['All', 'Remaining', 'Purchased'].map((type) {
                  final isSelected = _filterType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filterType = type;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Items list grouped by Category
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(child: Text('No matching items found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, idx) {
                    final cat = grouped.keys.elementAt(idx);
                    final catItems = grouped[cat] ?? [];
                    final emoji = GroceryCategoryEntity.getEmoji(cat);

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(
                          cat,
                          style: AppTypography.bodyLarge(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text('${catItems.length} items'),
                        children: catItems.map((item) {
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              ),
                              child: FoodImageCard(
                                food: item.foodName,
                                width: 40,
                                height: 40,
                                borderRadius: AppConstants.radiusSm,
                              ),
                            ),
                            title: Text(
                              item.foodName,
                              style: TextStyle(
                                decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.quantity.toStringAsFixed(1)} ${item.unit}'),
                                if (item.notes != null && item.notes!.isNotEmpty)
                                  Text(
                                    item.notes!,
                                    style: AppTypography.caption(isDark: isDark).copyWith(
                                      color: Colors.orange[800],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Checkbox(
                              value: item.isPurchased,
                              activeColor: AppColors.primary500,
                              onChanged: (val) {
                                ref.read(groceryControllerProvider.notifier).togglePurchased(list.id, item);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),

        // Action controls
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(groceryControllerProvider.notifier).clearPurchased(list.id);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear Purchased'),
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddCustomItemDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPantryTab(List<PantryItemEntity> pantryItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredPantry = pantryItems.where((i) {
      return i.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Pantry search bar
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search pantry...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),

        Expanded(
          child: filteredPantry.isEmpty
              ? const Center(child: Text('Pantry is empty. Add items to track available stocks.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
                  itemCount: filteredPantry.length,
                  itemBuilder: (context, idx) {
                    final item = filteredPantry[idx];
                    final status = item.getExpiryStatus();

                    Color statusColor = Colors.green;
                    if (status.contains('Expired')) {
                      statusColor = Colors.red;
                    } else if (status.contains('Expiring Soon')) {
                      statusColor = Colors.orange;
                    }

                    return FitFuelCard(
                      child: ListTile(
                        leading: const Icon(Icons.kitchen, size: 36, color: AppColors.primary500),
                        title: Text(
                          item.foodName,
                          style: AppTypography.bodyLarge(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stock: ${item.quantity.toStringAsFixed(1)} ${item.unit}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (item.quantity > 1.0) {
                                  ref
                                      .read(groceryControllerProvider.notifier)
                                      .updatePantryQuantity(item.id, item.quantity - 1.0);
                                } else {
                                  ref.read(groceryControllerProvider.notifier).removePantryItem(item.id);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                ref
                                    .read(groceryControllerProvider.notifier)
                                    .updatePantryQuantity(item.id, item.quantity + 1.0);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                ref.read(groceryControllerProvider.notifier).removePantryItem(item.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Action add pantry
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: FitFuelButton(
            label: 'Add Pantry Item',
            icon: Icons.add,
            onPressed: _showAddPantryItemDialog,
          ),
        ),
      ],
    );
  }
}
