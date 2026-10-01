import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/utils/nutrition_calculator.dart';
import '../../domain/utils/recommendation_engine.dart';
import '../providers/nutrition_providers.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_summary.dart';

/// The food diary extracted from Dashboard, using the same log controller.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  bool _checkOnline(BuildContext context, WidgetRef ref) {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Internet connection is required for this action.')));
      return false;
    }
    return true;
  }

  void _showFoodForm(BuildContext context, String uid,
      {NutritionRecordEntity? record}) {
    context.go(record == null
        ? '/nutrition/log'
        : '/nutrition/log/${Uri.encodeComponent(record.id)}/edit');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(nutritionStreamProvider);
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    final goals = ref.watch(nutritionGoalsStreamProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground =
        isDark ? null : Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Nutrition')),
      backgroundColor: pageBackground,
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nutritionStreamProvider);
            ref.invalidate(nutritionGoalsStreamProvider);
          },
          child: SingleChildScrollView(
            key: const PageStorageKey('nutrition-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AdaptivePageLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nutrition Header
                _NutritionHeader(isDark: isDark),
                const SizedBox(height: AppConstants.spaceLg),

                // Main content — responsive layout
                LayoutBuilder(builder: (context, constraints) {
                  final twoColumn = constraints.maxWidth >= 740;
                  if (!twoColumn) {
                    // Mobile: single column
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const NutritionSummary(),
                        const SizedBox(height: AppConstants.spaceLg),
                        _FoodDiarySection(
                          records: records,
                          uid: uid,
                          goals: goals,
                          isDark: isDark,
                          onEdit: (record) =>
                              _showFoodForm(context, uid!, record: record),
                          onDelete: (record) async {
                            if (uid == null) return;
                            if (!_checkOnline(context, ref)) return;
                            await ref
                                .read(nutritionControllerProvider.notifier)
                                .deleteRecord(uid, record.id);
                          },
                          onAddFood: uid == null
                              ? null
                              : () => _showFoodForm(context, uid),
                          onRetry: () => ref.invalidate(nutritionStreamProvider),
                        ),
                        const SizedBox(height: AppConstants.spaceLg),
                        _QuickFoodActions(isDark: isDark),
                        const SizedBox(height: AppConstants.spaceLg),
                        _SmartInsightsCard(
                          records: records,
                          goals: goals,
                          isDark: isDark,
                          uid: uid,
                        ),
                      ],
                    );
                  }
                  // Desktop: two-column layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const NutritionSummary(),
                            const SizedBox(height: AppConstants.spaceLg),
                            _FoodDiarySection(
                              records: records,
                              uid: uid,
                              goals: goals,
                              isDark: isDark,
                              onEdit: (record) =>
                                  _showFoodForm(context, uid!, record: record),
                              onDelete: (record) async {
                                if (uid == null) return;
                                if (!_checkOnline(context, ref)) return;
                                await ref
                                    .read(nutritionControllerProvider.notifier)
                                    .deleteRecord(uid, record.id);
                              },
                              onAddFood: uid == null
                                  ? null
                                  : () => _showFoodForm(context, uid),
                              onRetry: () => ref.invalidate(nutritionStreamProvider),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.spaceLg),
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _QuickFoodActions(isDark: isDark),
                            const SizedBox(height: AppConstants.spaceLg),
                            _SmartInsightsCard(
                              records: records,
                              goals: goals,
                              isDark: isDark,
                              uid: uid,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nutrition Header ─────────────────────────────────────────────────────────

class _NutritionHeader extends StatelessWidget {
  final bool isDark;
  const _NutritionHeader({required this.isDark});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Nutrition', style: text.headlineLarge),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: text.bodyMedium,
        ),
      ],
    );
  }
}

// ─── Food Diary Section ───────────────────────────────────────────────────────

class _FoodDiarySection extends StatelessWidget {
  final AsyncValue<List<NutritionRecordEntity>> records;
  final String? uid;
  final NutritionGoalsEntity? goals;
  final bool isDark;
  final void Function(NutritionRecordEntity) onEdit;
  final void Function(NutritionRecordEntity) onDelete;
  final VoidCallback? onAddFood;
  final VoidCallback onRetry;

  const _FoodDiarySection({
    required this.records,
    required this.uid,
    required this.goals,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    this.onAddFood,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelSectionHeader(
          title: 'Food Diary',
          actionLabel: 'Log Food',
          onActionPressed: onAddFood,
        ),
        const SizedBox(height: AppConstants.spaceSmd),
        records.when(
          data: (items) {
            final today =
                NutritionCalculator.filterByDay(items, DateTime.now());
            if (today.isEmpty) {
              return FitFuelEmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: 'Nothing logged yet',
                description:
                    'Start with your first meal to see your nutrition progress.',
                actionLabel: 'Add Food',
                onActionPressed: onAddFood,
              );
            }
            return _MealGroupedDiary(
              records: today,
              isDark: isDark,
              onEdit: onEdit,
              onDelete: onDelete,
              onAddFood: onAddFood,
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => FitFuelErrorState(
            error: error,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}

// ─── Meal-Grouped Diary ───────────────────────────────────────────────────────

class _MealGroupedDiary extends StatelessWidget {
  final List<NutritionRecordEntity> records;
  final bool isDark;
  final void Function(NutritionRecordEntity) onEdit;
  final void Function(NutritionRecordEntity) onDelete;
  final VoidCallback? onAddFood;

  const _MealGroupedDiary({
    required this.records,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    this.onAddFood,
  });

  @override
  Widget build(BuildContext context) {
    // Group by canonical meal type
    final grouped = <String, List<NutritionRecordEntity>>{};
    for (final record in records) {
      final normalized = MealType.normalize(record.mealType);
      grouped.putIfAbsent(normalized, () => []).add(record);
    }

    // Order by canonical meal order
    final orderedMeals = MealType.displayNames
        .where((name) => grouped.containsKey(name))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < orderedMeals.length; i++) ...[
          if (i > 0) const SizedBox(height: AppConstants.spaceMd),
          _MealSection(
            mealName: orderedMeals[i],
            records: grouped[orderedMeals[i]]!,
            isDark: isDark,
            onEdit: onEdit,
            onDelete: onDelete,
            onAddFood: onAddFood,
          ),
        ],
      ],
    );
  }
}

// ─── Single Meal Section ──────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String mealName;
  final List<NutritionRecordEntity> records;
  final bool isDark;
  final void Function(NutritionRecordEntity) onEdit;
  final void Function(NutritionRecordEntity) onDelete;
  final VoidCallback? onAddFood;

  const _MealSection({
    required this.mealName,
    required this.records,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    this.onAddFood,
  });

  IconData _mealIcon(String meal) {
    final lower = meal.toLowerCase();
    if (lower.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (lower.contains('morning')) return Icons.coffee_rounded;
    if (lower.contains('lunch')) return Icons.restaurant_rounded;
    if (lower.contains('evening')) return Icons.cookie_rounded;
    if (lower.contains('dinner')) return Icons.dinner_dining_rounded;
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final totalCals =
        records.fold(0.0, (sum, r) => sum + r.calories);

    return FitFuelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Meal header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spaceMd,
              AppConstants.spaceSmd,
              AppConstants.spaceSm,
              AppConstants.spaceSm,
            ),
            child: Row(
              children: [
                Icon(_mealIcon(mealName),
                    size: 20, color: scheme.primary),
                const SizedBox(width: AppConstants.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mealName,
                          style: text.titleSmall),
                      Text(
                        '${records.length} ${records.length == 1 ? 'food' : 'foods'} · ${totalCals.toStringAsFixed(0)} kcal',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onAddFood != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.add_rounded, size: 20, color: scheme.primary),
                      tooltip: 'Add food to $mealName',
                      onPressed: onAddFood,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),

          // Food entries
          for (int i = 0; i < records.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: scheme.outlineVariant),
            _FoodLogRow(
              record: records[i],
              isDark: isDark,
              onEdit: () => onEdit(records[i]),
              onDelete: () => onDelete(records[i]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Food Log Row ─────────────────────────────────────────────────────────────

class _FoodLogRow extends StatelessWidget {
  final NutritionRecordEntity record;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodLogRow({
    required this.record,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final semantic = FitFuelSemanticColors.of(context);

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMd,
          vertical: AppConstants.spaceSmd,
        ),
        child: Row(
          children: [
            // Food image thumbnail
            SizedBox(
              width: 44,
              height: 44,
              child: FoodImageCard(
                food: record.foodName,
                width: 44,
                height: 44,
                borderRadius: AppConstants.radiusSm,
              ),
            ),
            const SizedBox(width: AppConstants.spaceSmd),
            // Name + serving info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.foodName,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.protein.toStringAsFixed(0)}g protein · ${record.servingSize.toStringAsFixed(0)}g',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            // Calories
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: record.calories.toStringAsFixed(0),
                      style: text.titleSmall?.copyWith(
                        color: semantic.calories,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' kcal',
                      style: text.bodySmall,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Actions menu
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              padding: EdgeInsets.zero,
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Food Actions ───────────────────────────────────────────────────────

class _QuickFoodActions extends StatelessWidget {
  final bool isDark;
  const _QuickFoodActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FitFuelSectionHeader(title: 'Food Library'),
        const SizedBox(height: AppConstants.spaceSmd),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.search_rounded,
                label: 'Search Foods',
                color: scheme.primary,
                onTap: () => context.go('/nutrition/search'),
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: _ActionTile(
                icon: Icons.favorite_rounded,
                label: 'Favorites',
                color: const Color(0xFFE11D48),
                onTap: () => context.go('/nutrition/search?view=favorites'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceSm),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.history_rounded,
                label: 'Recent',
                color: const Color(0xFF0EA5E9),
                onTap: () => context.go('/nutrition/search?view=recent'),
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: _ActionTile(
                icon: Icons.edit_note_rounded,
                label: 'Custom Foods',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.go('/nutrition/search?view=custom'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return FitFuelCard(
      onTap: onTap,
      isInteractive: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSmd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppConstants.spaceSmd),
          Flexible(
            child: Text(
              label,
              style: text.titleSmall?.copyWith(color: scheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ─── Smart Insights Card ──────────────────────────────────────────────────────

class _SmartInsightsCard extends StatelessWidget {
  final AsyncValue<List<NutritionRecordEntity>> records;
  final NutritionGoalsEntity? goals;
  final bool isDark;
  final String? uid;

  const _SmartInsightsCard({
    required this.records,
    required this.goals,
    required this.isDark,
    this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return records.when(
      data: (items) {
        final today = NutritionCalculator.filterByDay(items, DateTime.now());
        final result = RecommendationEngine.getRecommendations(
          dailyRecords: today,
          goals: goals,
        );
        return FitFuelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_rounded,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child:
                        Text('Smart Insights', style: text.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSmd),
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceSmd),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .5),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: Text(
                        result.insightMessage,
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
