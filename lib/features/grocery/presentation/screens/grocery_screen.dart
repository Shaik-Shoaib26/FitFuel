import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../domain/entities/grocery_category_entity.dart';
import '../../domain/entities/grocery_item_entity.dart';
import '../../domain/entities/grocery_list_entity.dart';
import '../../domain/entities/grocery_preferences_entity.dart';
import '../../domain/entities/pantry_item_entity.dart';
import '../providers/grocery_providers.dart';

/// Premium Grocery and Pantry workspace screen
class GroceryScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const GroceryScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen>
    with SingleTickerProviderStateMixin {
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

  String _filterType = 'All'; // 'All', 'Remaining', 'Purchased'
  String _searchQuery = '';

  bool _checkOnline(BuildContext context) {
    final networkStatus =
        ref.read(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection is required for this action.'),
          backgroundColor: AppColors.stateError,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(_syncTabLocation);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _syncTabLocation() {
    if (_tabController.indexIsChanging ||
        _tabController.index == widget.initialTab) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.go(
        _tabController.index == 1 ? '/plan/grocery/pantry' : '/plan/grocery');
  }

  @override
  void didUpdateWidget(covariant GroceryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.index = widget.initialTab;
    }
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
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g. Greek Yogurt, Oats',
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addItemQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceSm),
                        DropdownButton<String>(
                          value: _addItemUnit,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _addItemUnit = val;
                              });
                            }
                          },
                          items: [
                            'g',
                            'kg',
                            'ml',
                            'L',
                            'pieces',
                            'cups',
                            'tbsp',
                            'tsp'
                          ]
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
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
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
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
                FitFuelButton(
                  label: 'Add Item',
                  onPressed: () {
                    if (!_checkOnline(context)) return;
                    final name = _addItemNameController.text.trim();
                    final qty =
                        double.tryParse(_addItemQtyController.text) ?? 1.0;
                    if (name.isNotEmpty) {
                      final selectedId = ref.read(selectedListIdProvider);
                      if (selectedId != null) {
                        ref
                            .read(groceryControllerProvider.notifier)
                            .addGroceryItem(
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
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g. Brown Rice, Olive Oil',
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pantryQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceSm),
                        DropdownButton<String>(
                          value: _pantryUnit,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _pantryUnit = val;
                              });
                            }
                          },
                          items: [
                            'g',
                            'kg',
                            'ml',
                            'L',
                            'pieces',
                            'cups',
                            'tbsp',
                            'tsp'
                          ]
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Expiry: ${_pantryExpiry.toString().split(' ').first}'),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month_outlined, size: 18),
                          label: const Text('Pick Date'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _pantryExpiry,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 305)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
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
                FitFuelButton(
                  label: 'Add to Pantry',
                  onPressed: () {
                    if (!_checkOnline(context)) return;
                    final name = _pantryNameController.text.trim();
                    final qty =
                        double.tryParse(_pantryQtyController.text) ?? 1.0;
                    if (name.isNotEmpty) {
                      ref
                          .read(groceryControllerProvider.notifier)
                          .addPantryItem(
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final listAsync = ref.watch(currentGroceryListProvider);
    final allListsAsync = ref.watch(groceryListsProvider);
    final pantryAsync = ref.watch(pantryProvider);
    final preferencesAsync = ref.watch(groceryPreferencesProvider);

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Grocery & Pantry'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary500,
          unselectedLabelColor:
              isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          indicatorColor: AppColors.primary500,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              text: 'Shopping List',
              icon: Icon(Icons.shopping_cart_outlined, size: 20),
            ),
            Tab(
              text: 'Pantry Stock',
              icon: Icon(Icons.kitchen_outlined, size: 20),
            ),
          ],
        ),
      ),
      body: AdaptivePageLayout(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Grocery List
            listAsync.when(
              data: (list) {
                if (list == null) {
                  return _buildNoListState();
                }
                final allLists = allListsAsync.valueOrNull ?? [list];
                return _buildGroceryTab(
                  list,
                  allLists,
                  preferencesAsync.valueOrNull ??
                      const GroceryPreferencesEntity(),
                );
              },
              loading: () => const Center(
                child: FitFuelLoadingState(label: 'Loading grocery list...'),
              ),
              error: (err, stack) => FitFuelErrorState(
                error: err,
                messageOverride: 'Unable to load grocery list.',
                onRetry: () => ref.refresh(groceryListsProvider),
              ),
            ),

            // Tab 2: Pantry
            pantryAsync.when(
              data: (pantryItems) {
                return _buildPantryTab(pantryItems);
              },
              loading: () => const Center(
                child: FitFuelLoadingState(label: 'Loading pantry items...'),
              ),
              error: (err, stack) => FitFuelErrorState(
                error: err,
                messageOverride: 'Unable to load pantry stock.',
                onRetry: () => ref.refresh(pantryProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoListState() {
    return Center(
      child: FitFuelEmptyState(
        icon: Icons.shopping_basket_outlined,
        title: 'No Active Shopping List',
        description:
            'Convert your meal planner requirements into an organized, category-grouped grocery checklist.',
        actionLabel: 'Generate List from Meal Plan',
        onActionPressed: () {
          if (!_checkOnline(context)) return;
          final activePlan =
              ref.read(mealPlannerControllerProvider).valueOrNull;
          if (activePlan != null) {
            ref.read(groceryControllerProvider.notifier).generateGroceryList(
                  mealPlans: [activePlan],
                  pantryItems: ref.read(pantryProvider).valueOrNull ?? const [],
                  preferences: ref.read(groceryPreferencesProvider).valueOrNull ??
                      const GroceryPreferencesEntity(),
                );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please generate or set up a meal plan first in the Meal Planner.'),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildGroceryTab(
    GroceryListEntity list,
    List<GroceryListEntity> allLists,
    GroceryPreferencesEntity preferences,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Apply Search Query
    final filteredItems = list.items.where((i) {
      final nameMatches =
          i.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
      final catMatches =
          i.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final noteMatches = i.notes != null &&
          i.notes!.toLowerCase().contains(_searchQuery.toLowerCase());
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

    final double completionFraction =
        (list.completionPercentage / 100.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Summary & Selector Card
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: FitFuelCard(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-list selector chips if more than 1 list exists
                if (allLists.length > 1) ...[
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: allLists.length,
                      itemBuilder: (context, idx) {
                        final l = allLists[idx];
                        final isSelected = l.id == list.id;
                        return Padding(
                          padding:
                              const EdgeInsets.only(right: AppConstants.spaceSm),
                          child: ChoiceChip(
                            label: Text('List ${idx + 1}'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(selectedListIdProvider.notifier).state =
                                    l.id;
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                ],

                Wrap(
                  spacing: AppConstants.spaceSm,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shopping Checklist',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${list.purchasedItems} of ${list.totalItems} items purchased',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spaceSm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary500.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                          ),
                          child: Text(
                            '${list.completionPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded,
                              color: AppColors.primary500),
                          tooltip: 'Regenerate List',
                          onPressed: () {
                            if (!_checkOnline(context)) return;
                            final activePlan = ref
                                .read(mealPlannerControllerProvider)
                                .valueOrNull;
                            if (activePlan != null) {
                              ref
                                  .read(groceryControllerProvider.notifier)
                                  .regenerateGroceryList(
                                    mealPlans: [activePlan],
                                    pantryItems: ref
                                            .read(pantryProvider)
                                            .valueOrNull ??
                                        const [],
                                    preferences: preferences,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Grocery list regenerated successfully!'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: completionFraction,
                    backgroundColor: isDark
                        ? AppColors.darkBorderSubtle
                        : AppColors.primary500.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary500),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search and Filter Bar
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search grocery items...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list_rounded,
                    color: AppColors.primary500),
                tooltip: 'Filter List',
                onSelected: (val) {
                  setState(() {
                    _filterType = val;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'All', child: Text('All Items')),
                  const PopupMenuItem(
                      value: 'Remaining', child: Text('Remaining Items')),
                  const PopupMenuItem(
                      value: 'Purchased', child: Text('Purchased Items')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        // Items list grouped by Category
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(
                  child: Text('No matching grocery items found.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceMd,
                    vertical: AppConstants.spaceSm,
                  ),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, idx) {
                    final cat = grouped.keys.elementAt(idx);
                    final catItems = grouped[cat] ?? [];
                    final emoji = GroceryCategoryEntity.getEmoji(cat);

                    return FitFuelCard(
                      margin: const EdgeInsets.only(
                          bottom: AppConstants.spaceMd),
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Text(emoji,
                              style: const TextStyle(fontSize: 22)),
                          title: Text(
                            cat,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${catItems.length} items',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          children: catItems.map((item) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spaceMd,
                                vertical: 2,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSm),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: FoodImageCard(
                                    food: item.foodName,
                                    width: 48,
                                    height: 48,
                                    borderRadius: AppConstants.radiusSm,
                                    semanticDescription:
                                        'Photo of ${item.foodName}',
                                  ),
                                ),
                              ),
                              title: Text(
                                item.foodName,
                                style: TextStyle(
                                  decoration: item.isPurchased
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w600,
                                  color: item.isPurchased
                                      ? (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)
                                      : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  if (item.notes != null &&
                                      item.notes!.isNotEmpty)
                                    Text(
                                      item.notes!,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.carbs
                                            : AppColors.calories,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: item.isPurchased,
                                    activeColor: AppColors.primary500,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (val) {
                                      if (!_checkOnline(context)) return;
                                      ref
                                          .read(groceryControllerProvider
                                              .notifier)
                                          .togglePurchased(list.id, item);
                                    },
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.stateError,
                                    ),
                                    tooltip: 'Remove Item',
                                    onPressed: () {
                                      if (!_checkOnline(context)) return;
                                      ref
                                          .read(groceryControllerProvider
                                              .notifier)
                                          .removeGroceryItem(
                                              list.id, item.id);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Action Toolbar
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (!_checkOnline(context)) return;
                    ref
                        .read(groceryControllerProvider.notifier)
                        .clearPurchased(list.id);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear Purchased'),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(0, AppConstants.minTouchTargetSize),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusControl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: FitFuelButton(
                  onPressed: _showAddCustomItemDialog,
                  icon: Icons.add_rounded,
                  label: 'Add Item',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPantryTab(List<PantryItemEntity> pantryItems) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredPantry = pantryItems.where((i) {
      return i.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pantry Summary Card
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: FitFuelCard(
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppConstants.spaceSm,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Pantry Inventory',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceSm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        '${pantryItems.length} items',
                        style: const TextStyle(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Foods in your pantry are matched for Smart Eat recommendations.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search pantry stock...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        // Items List
        Expanded(
          child: filteredPantry.isEmpty
              ? Center(
                  child: FitFuelEmptyState(
                    icon: Icons.kitchen_outlined,
                    title: 'Your Pantry is Empty',
                    description:
                        'Add items already in your kitchen so Smart Eat can suggest recipes using available ingredients.',
                    actionLabel: 'Add Pantry Item',
                    onActionPressed: () {
                      if (!_checkOnline(context)) return;
                      _showAddPantryItemDialog();
                    },
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    if (isWide) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(AppConstants.spaceMd),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisExtent: 110,
                          crossAxisSpacing: AppConstants.spaceMd,
                          mainAxisSpacing: AppConstants.spaceMd,
                        ),
                        itemCount: filteredPantry.length,
                        itemBuilder: (context, idx) {
                          final item = filteredPantry[idx];
                          return _buildPantryItemCard(item, isDark, theme);
                        },
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceMd,
                        vertical: AppConstants.spaceSm,
                      ),
                      itemCount: filteredPantry.length,
                      itemBuilder: (context, idx) {
                        final item = filteredPantry[idx];
                        return _buildPantryItemCard(item, isDark, theme);
                      },
                    );
                  },
                ),
        ),

        // Action add pantry
        Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: FitFuelButton(
            label: 'Add Pantry Item',
            icon: Icons.add_rounded,
            onPressed: () {
              if (!_checkOnline(context)) return;
              _showAddPantryItemDialog();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPantryItemCard(
    PantryItemEntity item,
    bool isDark,
    ThemeData theme,
  ) {
    final status = item.getExpiryStatus();
    Color statusColor = AppColors.stateSuccess;
    if (status.contains('Expired')) {
      statusColor = AppColors.stateError;
    } else if (status.contains('Expiring Soon')) {
      statusColor = AppColors.stateWarning;
    }

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: const Icon(
              Icons.kitchen_rounded,
              color: AppColors.primary500,
              size: 18,
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.foodName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Stock: ${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            tooltip: 'Decrease Quantity',
            onPressed: () {
              if (!_checkOnline(context)) return;
              if (item.quantity > 1.0) {
                ref
                    .read(groceryControllerProvider.notifier)
                    .updatePantryQuantity(item.id, item.quantity - 1.0);
              } else {
                ref
                    .read(groceryControllerProvider.notifier)
                    .removePantryItem(item.id);
              }
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: AppColors.primary500),
            tooltip: 'Increase Quantity',
            onPressed: () {
              if (!_checkOnline(context)) return;
              ref
                  .read(groceryControllerProvider.notifier)
                  .updatePantryQuantity(item.id, item.quantity + 1.0);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.stateError),
            tooltip: 'Delete Item',
            onPressed: () {
              if (!_checkOnline(context)) return;
              ref
                  .read(groceryControllerProvider.notifier)
                  .removePantryItem(item.id);
            },
          ),
        ],
      ),
    );
  }
}
