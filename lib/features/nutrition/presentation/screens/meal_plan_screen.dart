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
        title: const Text('Personalized Meal Planner'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
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
                      // 1. Calories Distribution stats card
                      _buildSummaryCard(result, isDark),
                      const SizedBox(height: AppConstants.spaceMd),

                      // 2. Suggestions list
                      Text(
                        "Today's Suggested Menu",
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
                        mealTitle: 'Snack (10%)',
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
    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meal Plan Calorie Target', style: AppTypography.heading3(isDark: isDark)),
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
          style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary500),
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
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '${food.calories.toStringAsFixed(0)} kcal  ·  P: ${food.protein.toStringAsFixed(0)}g  ·  C: ${food.carbohydrates.toStringAsFixed(0)}g  ·  F: ${food.fats.toStringAsFixed(0)}g',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.selectionReason,
                      style: TextStyle(
                        fontSize: 11,
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
}
