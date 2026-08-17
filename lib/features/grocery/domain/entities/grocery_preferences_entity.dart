class GroceryPreferencesEntity {
  final String preferredStore;
  final double budgetLimit;
  final String preferredUnits; // 'metric' or 'imperial'
  final bool showImages;
  final bool groupByCategory;
  final bool includePantryItems;
  final bool autoGenerateWeeklyList;
  final bool notifyWhenShoppingListReady;

  const GroceryPreferencesEntity({
    this.preferredStore = '',
    this.budgetLimit = 0.0,
    this.preferredUnits = 'metric',
    this.showImages = true,
    this.groupByCategory = true,
    this.includePantryItems = true,
    this.autoGenerateWeeklyList = false,
    this.notifyWhenShoppingListReady = false,
  });

  GroceryPreferencesEntity copyWith({
    String? preferredStore,
    double? budgetLimit,
    String? preferredUnits,
    bool? showImages,
    bool? groupByCategory,
    bool? includePantryItems,
    bool? autoGenerateWeeklyList,
    bool? notifyWhenShoppingListReady,
  }) {
    return GroceryPreferencesEntity(
      preferredStore: preferredStore ?? this.preferredStore,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      preferredUnits: preferredUnits ?? this.preferredUnits,
      showImages: showImages ?? this.showImages,
      groupByCategory: groupByCategory ?? this.groupByCategory,
      includePantryItems: includePantryItems ?? this.includePantryItems,
      autoGenerateWeeklyList: autoGenerateWeeklyList ?? this.autoGenerateWeeklyList,
      notifyWhenShoppingListReady: notifyWhenShoppingListReady ?? this.notifyWhenShoppingListReady,
    );
  }
}
