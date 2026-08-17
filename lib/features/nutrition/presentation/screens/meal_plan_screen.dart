import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/glassmorphic_container.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/utils/meal_planner_engine.dart';
import '../../domain/utils/nutrition_calculator.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/food_form_sheet.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../food/data/datasources/predefined_food_data.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../../core/widgets/food_image_resolver.dart';

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  void _showFoodForm(BuildContext context, String uid, {NutritionRecordEntity? record}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodFormSheet(uid: uid, existingRecord: record),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nutritionAsync = ref.watch(nutritionStreamProvider);
    final goalsAsync = ref.watch(nutritionGoalsStreamProvider);
    final authUserUid = ref.watch(authStateStreamProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggested Menu'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: nutritionAsync.when(
            data: (records) {
              final todayRecords = NutritionCalculator.filterByDay(records, DateTime.now());

              return goalsAsync.when(
                data: (goals) {
                  final result = MealPlannerEngine.generateMealPlan(
                    todayRecords: todayRecords,
                    goals: goals,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Calories Distribution summary card
                      _buildSummaryCard(result, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 2. Suggestions list
                      Text(
                        "Today's Meal Plan Suggestions",
                        style: AppTypography.heading2(isDark: isDark),
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      _buildMealSection(
                        context: context,
                        mealTitle: 'Breakfast (25%)',
                        suggestions: result.breakfastSuggestions,
                        isDark: isDark,
                        uid: authUserUid,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      _buildMealSection(
                        context: context,
                        mealTitle: 'Lunch (35%)',
                        suggestions: result.lunchSuggestions,
                        isDark: isDark,
                        uid: authUserUid,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      _buildMealSection(
                        context: context,
                        mealTitle: 'Dinner (30%)',
                        suggestions: result.dinnerSuggestions,
                        isDark: isDark,
                        uid: authUserUid,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      _buildMealSection(
                        context: context,
                        mealTitle: 'Snacks (10%)',
                        suggestions: result.snackSuggestions,
                        isDark: isDark,
                        uid: authUserUid,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => GlassmorphicContainer(
                  child: Text(
                    'Error loading goals: $error',
                    style: const TextStyle(color: AppColors.stateError),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => GlassmorphicContainer(
              child: Text(
                'Error loading nutrition logs: $error',
                style: const TextStyle(color: AppColors.stateError),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(MealPlanResult result, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Target Allocation', style: AppTypography.heading3(isDark: isDark)),
            const SizedBox(height: AppConstants.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Daily Goal', '${result.dailyCalorieGoal.toStringAsFixed(0)} kcal', isDark ? AppColors.primary400 : AppColors.primary500),
                _buildMetricColumn('Planned Menu', '${result.plannedCalories.toStringAsFixed(0)} kcal', Colors.orangeAccent),
                _buildMetricColumn('Remaining Today', '${result.remainingCalories.toStringAsFixed(0)} kcal', AppColors.accentCarbs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMealSection({
    required BuildContext context,
    required String mealTitle,
    required List<MealPlanSuggestion> suggestions,
    required bool isDark,
    required String? uid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Text(
            mealTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary500),
          ),
        ),
        const SizedBox(height: 4),
        if (suggestions.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No suitable food recommendation found.'),
            ),
          )
        else
          ...suggestions.map((suggestion) {
            final food = suggestion.food;
            
            // Map suggestion food to FoodEntity for visual rendering with fallbacks & badges
            final matchedFood = PredefinedFoodData.foods
                .where((f) => f.name.toLowerCase() == food.name.toLowerCase())
                .firstOrNull
                ?.toEntity() ?? PredefinedFoodData.foods
                .where((f) => food.name.toLowerCase().contains(f.name.toLowerCase()))
                .firstOrNull
                ?.toEntity() ?? FoodEntity(
                  id: 'temp',
                  name: food.name,
                  category: suggestion.mealType,
                  servingSize: food.servingSize,
                  servingUnit: 'g',
                  calories: food.calories,
                  protein: food.protein,
                  carbohydrates: food.carbohydrates,
                  fats: food.fats,
                  fiber: 0,
                  sugar: food.sugar,
                  sodium: 0,
                );

            List<Widget> badges = [];
            if (matchedFood.isIndian) {
              badges.add(_buildCardBadge('Indian', Colors.orange));
            }
            if (matchedFood.isVegan) {
              badges.add(_buildCardBadge('Vegan', Colors.green));
            } else if (matchedFood.isVegetarian) {
              badges.add(_buildCardBadge('Veg', Colors.green));
            } else if (matchedFood.id != 'temp') {
              badges.add(_buildCardBadge('Non-Veg', Colors.red));
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceXs),
                leading: FoodImageCard(food: matchedFood, width: 48, height: 48, borderRadius: 8),
                title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '${food.calories.toStringAsFixed(0)} kcal  ·  P: ${food.protein.toStringAsFixed(0)}g  ·  C: ${food.carbohydrates.toStringAsFixed(0)}g  ·  F: ${food.fats.toStringAsFixed(0)}g',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    if (badges.isNotEmpty) ...[
                      Wrap(spacing: 4, children: badges),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      suggestion.selectionReason,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.primary400 : AppColors.primary500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary500),
                  tooltip: 'Add suggested food to food logs',
                  onPressed: uid == null
                      ? null
                      : () {
                          final newRecord = NutritionRecordEntity(
                            id: '',
                            foodName: food.name,
                            mealType: suggestion.mealType,
                            calories: food.calories,
                            protein: food.protein,
                            carbohydrates: food.carbohydrates,
                            fats: food.fats,
                            sugar: food.sugar,
                            servingSize: food.servingSize,
                            consumedAt: DateTime.now(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );
                          _showFoodForm(context, uid, record: newRecord);
                        },
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
