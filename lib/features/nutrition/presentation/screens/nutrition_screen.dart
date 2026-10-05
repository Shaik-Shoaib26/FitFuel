import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/utils/nutrition_calculator.dart';
import '../providers/nutrition_providers.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_editorial_hero.dart';
import '../widgets/nutrition_segmented_tabs.dart';
import '../widgets/nutrition_date_selector.dart';
import '../widgets/nutrition_summary_card.dart';
import '../widgets/nutrition_quick_actions.dart';
import '../widgets/food_diary_section.dart';
import '../widgets/nutrition_macros_view.dart';
import '../widgets/nutrition_insights_view.dart';

/// Nutrition Page redesigned for Phase 35.6.4 — Option B Editorial & Visual.
/// Reference: Option B — Image-rich, premium, engaging.
/// Features:
/// - Nutrition App Bar with AI Sparkle & Profile actions
/// - Segmented Tabs: Food Diary, Macros, Insights
/// - Editorial Nutrition Hero: "Fuel a healthier you" with realistic bowl photo
/// - Compact Date Navigation Row: < [calendar] Today, Oct 5 >
/// - Today's Nutrition Card with circular calorie ring & stacked macro metrics
/// - 4 Compact Quick Actions: Log Food, Scan Meal, Recipes, Goals
/// - Food Diary with image-rich empty state ("Nothing logged yet") & populated meal groups
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  int _selectedTab = 0;
  DateTime _selectedDate = DateTime.now();

  bool _checkOnline(BuildContext context, WidgetRef ref) {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection is required for this action.'),
        ),
      );
      return false;
    }
    return true;
  }

  void _showFoodForm(BuildContext context, String? uid,
      {NutritionRecordEntity? record}) {
    if (record == null) {
      context.go('/nutrition/log');
    } else {
      context.go('/nutrition/log/${Uri.encodeComponent(record.id)}/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(nutritionStreamProvider);
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    final goals = ref.watch(nutritionGoalsStreamProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter records for the currently selected date
    final allRecords = recordsAsync.value ?? const <NutritionRecordEntity>[];
    final selectedRecords =
        NutritionCalculator.filterByDay(allRecords, _selectedDate);

    // Calculate live totals for the selected date
    final totals = NutritionCalculator.calculateProgress(
      dailyRecords: selectedRecords,
      goals: goals,
    );

    final targetCalories = (goals?.dailyCalorieTarget ?? 2282).toDouble();
    final targetProtein = (goals?.proteinTargetGrams ?? 112).toDouble();
    final targetCarbs = (goals?.carbsTargetGrams ?? 316).toDouble();
    final targetFat = (goals?.fatTargetGrams ?? 63).toDouble();

    final router = GoRouter.maybeOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.warmOffWhite,
      appBar: FitFuelAppBar(
        backgroundColor: isDark ? AppColors.darkBgBase : AppColors.warmOffWhite,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Nutrition',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryText,
              letterSpacing: -0.4,
            ),
          ),
        ),
        actions: router != null
            ? null
            : [
                IconButton(
                  tooltip: 'AI Assistant',
                  icon: const Icon(Icons.auto_awesome_outlined),
                  onPressed: () => context.push('/ai-assistant'),
                ),
                IconButton(
                  tooltip: 'Profile',
                  icon: const Icon(Icons.person_outline_rounded),
                  onPressed: () => context.push('/profile'),
                ),
              ],
      ),
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
                // ─── 1. TOP SEGMENTED TABS (Food Diary / Macros / Insights) ─
                NutritionSegmentedTabs(
                  selectedIndex: _selectedTab,
                  onTabSelected: (index) {
                    setState(() => _selectedTab = index);
                  },
                ),

                const SizedBox(height: 16),

                // ─── RESPONSIVE TAB CONTENT ─────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 740;

                    // TAB 0: FOOD DIARY (Main Option B Flow)
                    if (_selectedTab == 0) {
                      if (!isDesktop) {
                        return _buildMobileFoodDiaryFlow(
                          context,
                          selectedRecords: selectedRecords,
                          recordsAsync: recordsAsync,
                          totals: totals,
                          targetCalories: targetCalories,
                          targetProtein: targetProtein,
                          targetCarbs: targetCarbs,
                          targetFat: targetFat,
                          uid: uid,
                          goals: goals,
                        );
                      } else {
                        return _buildDesktopFoodDiaryFlow(
                          context,
                          selectedRecords: selectedRecords,
                          recordsAsync: recordsAsync,
                          totals: totals,
                          targetCalories: targetCalories,
                          targetProtein: targetProtein,
                          targetCarbs: targetCarbs,
                          targetFat: targetFat,
                          uid: uid,
                          goals: goals,
                        );
                      }
                    }

                    // TAB 1: MACROS
                    if (_selectedTab == 1) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NutritionDateSelector(
                            selectedDate: _selectedDate,
                            onDateChanged: (d) =>
                                setState(() => _selectedDate = d),
                          ),
                          const SizedBox(height: 16),
                          NutritionMacrosView(
                            records: selectedRecords,
                            goals: goals,
                            onAdjustGoals: () => context.push('/settings/goals'),
                          ),
                        ],
                      );
                    }

                    // TAB 2: INSIGHTS
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NutritionDateSelector(
                          selectedDate: _selectedDate,
                          onDateChanged: (d) =>
                              setState(() => _selectedDate = d),
                        ),
                        const SizedBox(height: 16),
                        NutritionInsightsView(
                          records: selectedRecords,
                          goals: goals,
                          onLogFood: () => _showFoodForm(context, uid),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppConstants.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile Single-Column Flow matching Option B Reference Order
  Widget _buildMobileFoodDiaryFlow(
    BuildContext context, {
    required List<NutritionRecordEntity> selectedRecords,
    required AsyncValue<List<NutritionRecordEntity>> recordsAsync,
    required NutritionProgressData totals,
    required double targetCalories,
    required double targetProtein,
    required double targetCarbs,
    required double targetFat,
    required String? uid,
    required NutritionGoalsEntity? goals,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Editorial "Fuel a healthier you" hero
        const NutritionEditorialHero(),
        const SizedBox(height: 16),

        // 2. Compact Date Selector
        NutritionDateSelector(
          selectedDate: _selectedDate,
          onDateChanged: (d) => setState(() => _selectedDate = d),
        ),
        const SizedBox(height: 14),

        // 3. Today's Nutrition Summary Card
        NutritionSummaryCard(
          totalCalories: totals.totalCalories,
          calorieTarget: targetCalories,
          totalProtein: totals.totalProtein,
          proteinTarget: targetProtein,
          totalCarbs: totals.totalCarbs,
          carbsTarget: targetCarbs,
          totalFat: totals.totalFats,
          fatTarget: targetFat,
          onViewDetails: () => setState(() => _selectedTab = 1),
        ),
        const SizedBox(height: 16),

        // 4. Quick Actions (Log Food, Scan Meal, Recipes, Goals)
        NutritionQuickActions(
          onLogFood: () => _showFoodForm(context, uid),
          onScanMeal: () => context.go('/nutrition/scan'),
          onRecipes: () => context.go('/plan'),
          onGoals: () => context.push('/settings/goals'),
        ),
        const SizedBox(height: 24),

        // 5. Food Diary Section (Empty state or Populated Meal Groups)
        FoodDiarySection(
          records: selectedRecords,
          isLoading: recordsAsync.isLoading,
          error: recordsAsync.error,
          onLogFood: () => _showFoodForm(context, uid),
          onEditRecord: (record) =>
              _showFoodForm(context, uid, record: record),
          onDeleteRecord: (record) async {
            if (uid == null) return;
            if (!_checkOnline(context, ref)) return;
            await ref
                .read(nutritionControllerProvider.notifier)
                .deleteRecord(uid, record.id);
          },
          onRetry: () => ref.invalidate(nutritionStreamProvider),
        ),
      ],
    );
  }

  /// Desktop Two-Column Flow
  Widget _buildDesktopFoodDiaryFlow(
    BuildContext context, {
    required List<NutritionRecordEntity> selectedRecords,
    required AsyncValue<List<NutritionRecordEntity>> recordsAsync,
    required NutritionProgressData totals,
    required double targetCalories,
    required double targetProtein,
    required double targetCarbs,
    required double targetFat,
    required String? uid,
    required NutritionGoalsEntity? goals,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NutritionEditorialHero(),
        const SizedBox(height: 16),
        NutritionDateSelector(
          selectedDate: _selectedDate,
          onDateChanged: (d) => setState(() => _selectedDate = d),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (60%): Summary Card + Food Diary
            Expanded(
              flex: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutritionSummaryCard(
                    totalCalories: totals.totalCalories,
                    calorieTarget: targetCalories,
                    totalProtein: totals.totalProtein,
                    proteinTarget: targetProtein,
                    totalCarbs: totals.totalCarbs,
                    carbsTarget: targetCarbs,
                    totalFat: totals.totalFats,
                    fatTarget: targetFat,
                    onViewDetails: () => setState(() => _selectedTab = 1),
                  ),
                  const SizedBox(height: 24),
                  FoodDiarySection(
                    records: selectedRecords,
                    isLoading: recordsAsync.isLoading,
                    error: recordsAsync.error,
                    onLogFood: () => _showFoodForm(context, uid),
                    onEditRecord: (record) =>
                        _showFoodForm(context, uid, record: record),
                    onDeleteRecord: (record) async {
                      if (uid == null) return;
                      if (!_checkOnline(context, ref)) return;
                      await ref
                          .read(nutritionControllerProvider.notifier)
                          .deleteRecord(uid, record.id);
                    },
                    onRetry: () => ref.invalidate(nutritionStreamProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceLg),
            // Right Column (40%): Quick Actions + Macros Preview
            Expanded(
              flex: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutritionQuickActions(
                    onLogFood: () => _showFoodForm(context, uid),
                    onScanMeal: () => context.go('/nutrition/scan'),
                    onRecipes: () => context.go('/plan'),
                    onGoals: () => context.push('/settings/goals'),
                  ),
                  const SizedBox(height: 20),
                  NutritionMacrosView(
                    records: selectedRecords,
                    goals: goals,
                    onAdjustGoals: () => context.push('/settings/goals'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
