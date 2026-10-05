import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/nutrition_record_entity.dart';

/// Food Diary Section for Nutrition Screen (Option B):
/// - Header: "Food Diary" on left, "Log Food >" on right
/// - Empty state: Image-rich visual card with healthy bowl thumbnail, title,
///   description, "Add Food" CTA pill, and chevron.
/// - Populated state: Meal-grouped cards (Breakfast, Lunch, Snack, Dinner) with
///   food thumbnails, portions, calories, and actions.
class FoodDiarySection extends StatelessWidget {
  final List<NutritionRecordEntity> records;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onLogFood;
  final void Function(NutritionRecordEntity) onEditRecord;
  final void Function(NutritionRecordEntity) onDeleteRecord;
  final VoidCallback onRetry;

  const FoodDiarySection({
    super.key,
    required this.records,
    this.isLoading = false,
    this.error,
    this.onLogFood,
    required this.onEditRecord,
    required this.onDeleteRecord,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── FOOD DIARY SECTION HEADER ────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Food Diary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Log food',
                  child: InkWell(
                    onTap: onLogFood,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Log Food',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLeafGreen,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.primaryLeafGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ─── CONTENT: LOADING / ERROR / EMPTY / POPULATED ──────────────
        if (isLoading) ...[
          _buildLoadingSkeleton(isDark),
        ] else if (error != null) ...[
          FitFuelErrorState(
            error: error!,
            titleOverride: "We couldn't load today's nutrition.",
            onRetry: onRetry,
          ),
        ] else if (records.isEmpty) ...[
          _FoodDiaryEmptyCard(
            onAddFood: onLogFood,
            isDark: isDark,
          ),
        ] else ...[
          _FoodDiaryGroupedList(
            records: records,
            isDark: isDark,
            onEdit: onEditRecord,
            onDelete: onDeleteRecord,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primaryLeafGreen,
        ),
      ),
    );
  }
}

/// Image-rich empty state matching Option B reference:
/// Left: Meal thumbnail
/// Center: "Nothing logged yet", description, "Add Food" CTA
/// Right: Chevron
class _FoodDiaryEmptyCard extends StatelessWidget {
  final VoidCallback? onAddFood;
  final bool isDark;

  const _FoodDiaryEmptyCard({
    required this.onAddFood,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
      ),
      elevation: isDark ? 0 : 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAddFood,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Healthy meal thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: Image.asset(
                    'assets/decorations/nutrition_empty_meal.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.softSage,
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // 2. Middle Text & Add Food Button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nothing logged yet',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Start with your first meal to see your nutrition progress.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        height: 1.3,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Add Food CTA Button
                    Semantics(
                      button: true,
                      label: 'Add food',
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: onAddFood,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLeafGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19),
                            ),
                          ),
                          child: const Text(
                            'Add Food',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // 3. Subtle chevron on right
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryLeafGreen,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Populated meal diary grouped by meal type.
class _FoodDiaryGroupedList extends StatelessWidget {
  final List<NutritionRecordEntity> records;
  final bool isDark;
  final void Function(NutritionRecordEntity) onEdit;
  final void Function(NutritionRecordEntity) onDelete;

  const _FoodDiaryGroupedList({
    required this.records,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<NutritionRecordEntity>>{};
    for (final record in records) {
      final normalized = MealType.normalize(record.mealType);
      grouped.putIfAbsent(normalized, () => []).add(record);
    }

    final orderedMeals = MealType.displayNames
        .where((name) => grouped.containsKey(name))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < orderedMeals.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _MealGroupCard(
            mealName: orderedMeals[i],
            records: grouped[orderedMeals[i]]!,
            isDark: isDark,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ],
    );
  }
}

class _MealGroupCard extends StatelessWidget {
  final String mealName;
  final List<NutritionRecordEntity> records;
  final bool isDark;
  final void Function(NutritionRecordEntity) onEdit;
  final void Function(NutritionRecordEntity) onDelete;

  const _MealGroupCard({
    required this.mealName,
    required this.records,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _mealIcon(String meal) {
    final lower = meal.toLowerCase();
    if (lower.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (lower.contains('morning')) return Icons.coffee_rounded;
    if (lower.contains('lunch')) return Icons.restaurant_rounded;
    if (lower.contains('evening')) return Icons.cookie_rounded;
    if (lower.contains('dinner')) return Icons.nights_stay_rounded;
    if (lower.contains('snack')) return Icons.apple_rounded;
    return Icons.lunch_dining_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final totalCalories = records.fold<double>(0, (s, r) => s + r.calories);
    final totalProtein = records.fold<double>(0, (s, r) => s + r.protein);
    final totalCarbs = records.fold<double>(0, (s, r) => s + r.carbohydrates);
    final totalFats = records.fold<double>(0, (s, r) => s + r.fats);

    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
      ),
      elevation: isDark ? 0 : 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Meal Group Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPrimaryContainer
                        : AppColors.softSage,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _mealIcon(mealName),
                    size: 18,
                    color: AppColors.primaryLeafGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealName,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),
                      Text(
                        'P: ${totalProtein.toStringAsFixed(0)}g · C: ${totalCarbs.toStringAsFixed(0)}g · F: ${totalFats.toStringAsFixed(0)}g',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${totalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark
                  ? AppColors.darkBorderSubtle
                  : const Color(0xFFE5ECE7),
            ),
            // Food items
            for (int i = 0; i < records.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 58,
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : const Color(0xFFE5ECE7),
                ),
              _FoodItemRow(
                record: records[i],
                isDark: isDark,
                onEdit: () => onEdit(records[i]),
                onDelete: () => onDelete(records[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodItemRow extends StatelessWidget {
  final NutritionRecordEntity record;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodItemRow({
    required this.record,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Food Image Thumbnail (48x48, 12px radius)
            SizedBox(
              width: 48,
              height: 48,
              child: FoodImageCard(
                food: record.foodName,
                width: 48,
                height: 48,
                borderRadius: 12,
              ),
            ),
            const SizedBox(width: 12),
            // Food Name + Portion Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.foodName,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.servingSize.toStringAsFixed(0)}g · ${record.protein.toStringAsFixed(0)}g protein',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Calories
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${record.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.calorieOrange,
                  ),
                ),
              ),
            ),
            // Popup actions
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white60 : const Color(0xFF8A958D),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
