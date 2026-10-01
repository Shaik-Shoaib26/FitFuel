import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/food_image_resolver.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../food/data/repositories/food_asset_repository.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';
import '../../../meal_planner/domain/entities/planned_meal_entity.dart';
import '../../../meal_planner/domain/utils/meal_plan_calculator.dart';
import '../../../meal_planner/presentation/controllers/meal_planner_controller.dart';
import '../../../meal_planner/presentation/providers/meal_planner_providers.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';
import '../controllers/smart_eat_controller.dart';
import '../providers/smart_eat_providers.dart';
import '../widgets/nutrition_gap_card.dart';
import '../widgets/pantry_match_card.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/recommendation_reason_card.dart';
import '../widgets/smart_eat_hero_card.dart';
import '../widgets/smart_swap_card.dart';

/// Premium Smart Eat Screen — Intelligent Food Recommendations tailored to
/// nutrition gaps, pantry items, and dietary preferences.
class SmartEatScreen extends ConsumerWidget {
  const SmartEatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateStreamProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: FitFuelLoadingState(label: 'Authenticating...'),
        ),
      );
    }

    final state = ref.watch(smartEatControllerProvider);
    final profile = ref.watch(currentProfileStreamProvider).valueOrNull;
    final pantry = ref.watch(pantryProvider).valueOrNull ?? const [];
    final networkStatus =
        ref.watch(networkStatusProvider).valueOrNull ?? NetworkStatus.online;
    final isOffline = networkStatus == NetworkStatus.offline;

    final activeMealType = state.activeMealType;

    return Scaffold(
      appBar: const FitFuelAppBar(
        title: Text('Smart Eat'),
      ),
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(smartEatControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            key: const PageStorageKey('smart-eat-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Summary Card
                _buildHeader(context, profile, state),
                const SizedBox(height: AppConstants.spaceSm),

                // 2. Meal Type Selector Chips
                _buildMealTypeSelector(context, ref, activeMealType),
                const SizedBox(height: AppConstants.spaceMd),

                // 3. Recommendations Flow
                if (isOffline)
                  FitFuelErrorState(
                    error: 'offline',
                    messageOverride:
                        'Internet connection required to load Smart Eat recommendations.',
                    onRetry: () => ref
                        .read(smartEatControllerProvider.notifier)
                        .refresh(),
                  )
                else
                  state.recommendations.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppConstants.spaceXl),
                        child: FitFuelLoadingState(
                          label: 'Finding the best meals for your goals...',
                        ),
                      ),
                    ),
                    error: (e, stack) => FitFuelErrorState(
                      error: e,
                      onRetry: () => ref
                          .read(smartEatControllerProvider.notifier)
                          .refresh(),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return const FitFuelEmptyState(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'No Recommendations Available',
                          description:
                              'We couldn\'t find any matching foods. Try adjusting your preferences or profile targets.',
                        );
                      }

                      final topRec = list.first;
                      final otherRecs = list.skip(1).take(4).toList();
                      final swaps = ref.watch(smartFoodSwapProvider(topRec));

                      final errorBanner = state.error != null && !isOffline
                          ? FailureMapper.map(state.error!,
                              isOffline: false, hasData: true)
                          : '';

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 950;

                          final leftColumnWidgets = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (errorBanner.isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(
                                      bottom: AppConstants.spaceMd),
                                  padding: const EdgeInsets.all(
                                      AppConstants.spaceMd),
                                  decoration: BoxDecoration(
                                    color: AppColors.stateWarning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusSm),
                                    border: Border.all(
                                        color: AppColors.stateWarning),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: AppColors.stateWarning),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorBanner,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Text(
                                'Top Recommended Meal',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: AppConstants.spaceSm),
                              SmartEatHeroCard(
                                recommendation: topRec,
                                onLogMeal: () => _logRecommendation(
                                    context,
                                    ref,
                                    user.uid,
                                    topRec,
                                    activeMealType),
                                onSwap: () => _showSwapsDialog(context, ref,
                                    topRec, swaps, activeMealType),
                                onAddToMealPlan: () => _addPlannedMeal(
                                    context,
                                    ref,
                                    topRec,
                                    activeMealType),
                                onViewRecipe: () => _showRecipeDialog(
                                    context,
                                    topRec,
                                    ref,
                                    user.uid,
                                    activeMealType),
                              ),
                              const SizedBox(height: AppConstants.spaceMd),
                              PantryMatchCard(
                                recommendation: topRec,
                                pantryItems: pantry,
                                onCookThis: () => _logRecommendation(
                                    context,
                                    ref,
                                    user.uid,
                                    topRec,
                                    activeMealType),
                              ),
                              const SizedBox(height: AppConstants.spaceMd),
                              _buildMealPlanComparison(context, ref, state),
                            ],
                          );

                          final rightColumnWidgets = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              state.gap.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (gapEntity) =>
                                    NutritionGapCard(gap: gapEntity),
                              ),
                              const SizedBox(height: AppConstants.spaceMd),
                              if (swaps.isNotEmpty) ...[
                                SmartSwapCard(
                                  original: topRec,
                                  swaps: swaps,
                                  onSelectSwap: (selected) {
                                    ref
                                        .read(smartEatControllerProvider
                                            .notifier)
                                        .swapRecommendation(
                                            topRec, selected);
                                  },
                                ),
                                const SizedBox(height: AppConstants.spaceMd),
                              ],
                              RecommendationReasonCard(
                                  recommendation: topRec),
                              const SizedBox(height: AppConstants.spaceMd),
                              _buildAiExplanation(context, topRec, state),
                              if (otherRecs.isNotEmpty) ...[
                                const SizedBox(height: AppConstants.spaceMd),
                                Text(
                                  'Alternative Options',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: AppConstants.spaceSm),
                                ...otherRecs.map((rec) => RecommendationCard(
                                      recommendation: rec,
                                      onTap: () => _showRecipeDialog(
                                          context,
                                          rec,
                                          ref,
                                          user.uid,
                                          activeMealType),
                                      onLog: () => _logRecommendation(
                                          context,
                                          ref,
                                          user.uid,
                                          rec,
                                          activeMealType),
                                    )),
                              ],
                            ],
                          );

                          if (isDesktop) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 11, child: leftColumnWidgets),
                                const SizedBox(width: AppConstants.spaceLg),
                                Expanded(flex: 9, child: rightColumnWidgets),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                leftColumnWidgets,
                                const SizedBox(height: AppConstants.spaceMd),
                                rightColumnWidgets,
                              ],
                            );
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserProfileEntity? profile,
    SmartEatState state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeMealType = state.activeMealType;
    final dietPref = profile?.dietaryPreference ?? 'Any';

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.ai.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.ai,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Recommendations',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Targeting: $activeMealType • Diet: $dietPref',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector(
    BuildContext context,
    WidgetRef ref,
    String active,
  ) {
    final mealTypes = [
      'Breakfast',
      'Morning Snack',
      'Lunch',
      'Evening Snack',
      'Dinner',
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mealTypes.length,
        itemBuilder: (context, index) {
          final type = mealTypes[index];
          final isSelected = type.toLowerCase() == active.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(right: AppConstants.spaceSm),
            child: ChoiceChip(
              label: Text(type),
              selected: isSelected,
              selectedColor: AppColors.primary500.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary500 : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary500 : Colors.transparent,
              ),
              onSelected: (val) {
                if (val) {
                  final networkStatus =
                      ref.read(networkStatusProvider).valueOrNull ??
                          NetworkStatus.online;
                  if (networkStatus == NetworkStatus.offline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Internet connection is required for this action.'),
                        backgroundColor: AppColors.stateError,
                      ),
                    );
                    return;
                  }
                  ref
                      .read(smartEatControllerProvider.notifier)
                      .changeMealType(type);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealPlanComparison(
    BuildContext context,
    WidgetRef ref,
    SmartEatState state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = state.activeMealType;
    final mealPlan =
        ref.watch(mealPlannerControllerProvider).valueOrNull;

    if (mealPlan == null) {
      return const SizedBox.shrink();
    }

    final plannedMeal = mealPlan.meals.firstWhere(
      (m) => m.mealType.toLowerCase() == active.toLowerCase(),
      orElse: () => PlannedMealEntity(
        mealType: active,
        foods: const [],
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
      ),
    );

    final todayLogs =
        ref.watch(nutritionStreamProvider).valueOrNull ?? const [];
    final isCompleted = todayLogs
        .any((l) => l.mealType.toLowerCase() == active.toLowerCase());

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meal Planner Status: $active',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.pending_actions_rounded,
                color: isCompleted
                    ? AppColors.stateSuccess
                    : AppColors.stateWarning,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            isCompleted
                ? 'You have completed logging for this meal slot today.'
                : 'Planned in Meal Planner: ${plannedMeal.totalCalories.round()} kcal. Tap Log to mark it done.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiExplanation(
    BuildContext context,
    SmartFoodRecommendationEntity topRec,
    SmartEatState state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gap = state.gap.valueOrNull;
    final double proteinDeficit = gap?.remainingProtein ?? 0.0;

    String description = '';
    if (proteinDeficit > 20) {
      description =
          'You are currently ${proteinDeficit.round()}g short on your daily protein target. ${topRec.foodName} provides ${topRec.protein.round()}g protein while staying within your calorie budget.';
    } else {
      description =
          '${topRec.foodName} is a nutritionally balanced choice that aligns with your targets. It delivers ${topRec.protein.round()}g protein and ${topRec.calories.round()} kcal.';
    }

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  color: AppColors.ai, size: 20),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'AI Reasoning',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _logRecommendation(
    BuildContext context,
    WidgetRef ref,
    String uid,
    SmartFoodRecommendationEntity rec,
    String activeMealType, {
    double servingMultiplier = 1.0,
  }) async {
    final record = NutritionRecordEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodName: rec.foodName,
      mealType: activeMealType,
      calories: rec.calories * servingMultiplier,
      protein: rec.protein * servingMultiplier,
      carbohydrates: rec.carbs * servingMultiplier,
      fats: rec.fat * servingMultiplier,
      sugar: 0.0,
      servingSize: rec.servingSize * servingMultiplier,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(nutritionControllerProvider.notifier)
        .addRecord(uid, record);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Logged ${rec.foodName} to $activeMealType!')),
      );
    }
  }

  void _addPlannedMeal(
    BuildContext context,
    WidgetRef ref,
    SmartFoodRecommendationEntity rec,
    String activeMealType,
  ) async {
    final currentPlan =
        ref.read(mealPlannerControllerProvider).valueOrNull;
    final authUser = ref.read(authStateStreamProvider).valueOrNull;

    if (authUser == null) return;

    if (currentPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please generate a meal plan first on the Meal Planner screen.')),
      );
      return;
    }

    final foodEntity = FoodEntity(
      id: rec.foodId,
      name: rec.foodName,
      category: rec.category,
      servingSize: rec.servingSize,
      servingUnit: 'g',
      calories: rec.calories,
      protein: rec.protein,
      carbohydrates: rec.carbs,
      fats: rec.fat,
      fiber: rec.fiber,
      sugar: 0,
      sodium: 0,
      imageAsset: rec.imageUrl.isNotEmpty ? rec.imageUrl : null,
      isFavorite: rec.isFavorite,
    );

    final plannedFood = PlannedFoodEntity(
      food: foodEntity,
      servingQuantity: rec.servingSize,
      unit: 'g',
      calories: rec.calories,
      protein: rec.protein,
      carbohydrates: rec.carbs,
      fat: rec.fat,
      fiber: rec.fiber,
    );

    final plannedMealIndex = currentPlan.meals.indexWhere(
      (m) => m.mealType.toLowerCase() == activeMealType.toLowerCase(),
    );

    List<PlannedMealEntity> updatedMeals = List.from(currentPlan.meals);

    if (plannedMealIndex != -1) {
      final existingMeal = currentPlan.meals[plannedMealIndex];
      final updatedMeal = existingMeal.copyWith(
        foods: [plannedFood],
        totalCalories: plannedFood.calories,
        totalProtein: plannedFood.protein,
        totalCarbs: plannedFood.carbohydrates,
        totalFat: plannedFood.fat,
      );
      updatedMeals[plannedMealIndex] = updatedMeal;
    } else {
      final newMeal = PlannedMealEntity(
        mealType: activeMealType,
        foods: [plannedFood],
        totalCalories: plannedFood.calories,
        totalProtein: plannedFood.protein,
        totalCarbs: plannedFood.carbohydrates,
        totalFat: plannedFood.fat,
      );
      updatedMeals.add(newMeal);
    }

    var updatedPlan = currentPlan.copyWith(meals: updatedMeals);
    updatedPlan = MealPlanCalculator.recalculateMealPlan(updatedPlan);

    ref
        .read(mealPlannerControllerProvider.notifier)
        .updateMealPlan(updatedPlan);
    await ref
        .read(mealPlanRepositoryProvider)
        .saveMealPlan(authUser.uid, updatedPlan);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Added ${rec.foodName} to planned $activeMealType slot.')),
      );
    }
  }

  void _showRecipeDialog(
    BuildContext context,
    SmartFoodRecommendationEntity rec,
    WidgetRef ref,
    String uid,
    String activeMealType,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecipeDetailsSheet(
        recommendation: rec,
        ref: ref,
        uid: uid,
        activeMealType: activeMealType,
        onLog: (multiplier) {
          _logRecommendation(context, ref, uid, rec, activeMealType,
              servingMultiplier: multiplier);
        },
      ),
    );
  }

  void _showSwapsDialog(
    BuildContext context,
    WidgetRef ref,
    SmartFoodRecommendationEntity topRec,
    List<SmartFoodRecommendationEntity> swaps,
    String activeMealType,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a healthy swap'),
          content: swaps.isEmpty
              ? const Text('Searching for nutritionally compatible swaps...')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: swaps.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = swaps[index];
                      return ListTile(
                        title: Text(item.foodName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${item.calories.round()} kcal • ${item.protein.round()}g Pro'),
                        trailing: Text('${item.matchScore}% Match',
                            style: const TextStyle(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(smartEatControllerProvider.notifier)
                              .swapRecommendation(topRec, item);
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

/// Premium Recipe Details Bottom Sheet
class RecipeDetailsSheet extends StatefulWidget {
  final SmartFoodRecommendationEntity recommendation;
  final WidgetRef ref;
  final String uid;
  final String activeMealType;
  final Function(double) onLog;

  const RecipeDetailsSheet({
    super.key,
    required this.recommendation,
    required this.ref,
    required this.uid,
    required this.activeMealType,
    required this.onLog,
  });

  @override
  State<RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<RecipeDetailsSheet> {
  double _servings = 1.0;

  void _adjustServings(double delta) {
    setState(() {
      _servings = (_servings + delta).clamp(0.5, 3.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rec = widget.recommendation;
    final repo = FoodAssetRepository.instance;
    final recipe = repo.getRecipe(rec.foodId);

    final foodEntity = FoodEntity(
      id: rec.foodId,
      name: rec.foodName,
      category: rec.category,
      servingSize: rec.servingSize,
      servingUnit: 'g',
      calories: rec.calories,
      protein: rec.protein,
      carbohydrates: rec.carbs,
      fats: rec.fat,
      fiber: rec.fiber,
      sugar: 0,
      sodium: 0,
      imageAsset: rec.imageUrl.isNotEmpty ? rec.imageUrl : null,
      isFavorite: rec.isFavorite,
    );

    // Scaled values
    final scaledCalories = rec.calories * _servings;
    final scaledProtein = rec.protein * _servings;
    final scaledCarbs = rec.carbs * _servings;
    final scaledFat = rec.fat * _servings;
    final scaledFiber = rec.fiber * _servings;
    final scaledServingSize = rec.servingSize * _servings;

    // Badges / Metadata
    final dietType = recipe?.dietType ??
        (rec.tags.contains('Vegetarian') ? 'vegetarian' : 'nonVegetarian');
    final dietLabel = dietType == 'vegan'
        ? 'Vegan'
        : (dietType == 'vegetarian' ? 'Vegetarian' : 'Non-Vegetarian');
    final dietColor = (dietType == 'vegan' || dietType == 'vegetarian')
        ? AppColors.primary500
        : AppColors.calories;
    final cuisine = recipe?.cuisine ?? 'Healthy';
    final difficulty = recipe?.difficulty ?? 'Medium';
    final prepTime = recipe?.prepTimeMinutes ?? 15;
    final cookTime = recipe?.cookTimeMinutes ?? 15;
    final totalTime = recipe?.totalTimeMinutes ?? 30;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorderSubtle
                          : AppColors.lightBorderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Hero Image
                FoodImageCard(
                  food: foodEntity,
                  aspectRatio: 16 / 9,
                  borderRadius: 0,
                  semanticDescription: 'Photo of ${rec.foodName}',
                ),

                Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildBadge(dietLabel, dietColor),
                          _buildBadge(cuisine, AppColors.protein),
                          _buildBadge(rec.category, AppColors.carbs),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      // Food Name
                      Text(
                        rec.foodName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      // Servings Adjuster
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust Servings',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _servings > 0.5
                                    ? () => _adjustServings(-0.5)
                                    : null,
                                icon: const Icon(
                                    Icons.remove_circle_outline_rounded),
                              ),
                              Text(
                                '${_servings.toStringAsFixed(1)}x serving',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                onPressed: _servings < 3.0
                                    ? () => _adjustServings(0.5)
                                    : null,
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceSm),
                      Divider(
                        color: isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.lightBorderSubtle,
                        height: 1,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      // Nutrition Grid
                      _buildNutritionGrid(
                        scaledCalories,
                        scaledProtein,
                        scaledCarbs,
                        scaledFat,
                        scaledFiber,
                        scaledServingSize,
                        'g',
                        isDark,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      Divider(
                        color: isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.lightBorderSubtle,
                        height: 1,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      // Cooking Times / Difficulty
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTimeStat('Prep', '$prepTime min', isDark),
                          _buildTimeStat('Cook', '$cookTime min', isDark),
                          _buildTimeStat('Total', '$totalTime min', isDark),
                          _buildTimeStat('Difficulty', difficulty, isDark),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      Divider(
                        color: isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.lightBorderSubtle,
                        height: 1,
                      ),
                      const SizedBox(height: AppConstants.spaceMd),

                      // Ingredients
                      Text(
                        'Ingredients',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceSm),
                      if (recipe == null)
                        Text(
                          'Standard ingredient breakdown based on food database profile.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        )
                      else ...[
                        ...recipe.ingredients.map((ing) {
                          final scaledAmount = ing.baseAmount * _servings;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(ing.name),
                                Text(
                                  '${scaledAmount.toStringAsFixed(scaledAmount % 1 == 0 ? 0 : 1)} ${ing.unit}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: AppConstants.spaceMd),
                        Divider(
                          color: isDark
                              ? AppColors.darkBorderSubtle
                              : AppColors.lightBorderSubtle,
                          height: 1,
                        ),
                        const SizedBox(height: AppConstants.spaceMd),

                        // Instructions
                        Text(
                          'Preparation Steps',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceSm),
                        ...recipe.instructions.asMap().entries.map((entry) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary500
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      color: AppColors.primary500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceSm),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: AppConstants.spaceLg),

                      // Action Button
                      FitFuelButton(
                        label:
                            'Add to Food Log (${scaledCalories.round()} kcal)',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onLog(_servings);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTimeStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionGrid(
    double cal,
    double pro,
    double carb,
    double fat,
    double fib,
    double size,
    String unit,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNutrientCell(
            'Calories', '${cal.round()} kcal', AppColors.calories, isDark),
        _buildNutrientCell(
            'Protein', '${pro.round()}g', AppColors.protein, isDark),
        _buildNutrientCell(
            'Carbs', '${carb.round()}g', AppColors.carbs, isDark),
        _buildNutrientCell(
            'Fat', '${fat.round()}g', AppColors.fat, isDark),
      ],
    );
  }

  Widget _buildNutrientCell(
      String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
