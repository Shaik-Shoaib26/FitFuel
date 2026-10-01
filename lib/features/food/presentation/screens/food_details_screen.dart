import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../nutrition/domain/entities/meal_type.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/utils/food_nutrition_calculator.dart';
import '../providers/food_providers.dart';
import '../widgets/food_image.dart';
import '../widgets/recipe_sections.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  final FoodEntity food;
  final bool showRecipe;

  const FoodDetailsScreen(
      {super.key, required this.food, this.showRecipe = false});

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  final _recipeKey = GlobalKey();
  late FoodEntity _scaledFood;
  void _revealRecipe() {
    if (!widget.showRecipe) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _recipeKey.currentContext != null) {
        Scrollable.ensureVisible(_recipeKey.currentContext!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FoodDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showRecipe != oldWidget.showRecipe) _revealRecipe();
  }

  late final TextEditingController _servingController;
  String _selectedMealType = 'Breakfast';
  bool _isLogging = false;

  final List<String> _mealTypes = MealType.displayNames;

  @override
  void initState() {
    super.initState();
    _scaledFood = widget.food;
    _servingController =
        TextEditingController(text: widget.food.servingSize.toStringAsFixed(0));
    _servingController.addListener(_onServingChanged);
    _revealRecipe();
  }

  @override
  void dispose() {
    _servingController.removeListener(_onServingChanged);
    _servingController.dispose();
    super.dispose();
  }

  void _onServingChanged() {
    final val = double.tryParse(_servingController.text);
    if (val != null) {
      setState(() {
        _scaledFood = FoodNutritionCalculator.calculateScaled(
          food: widget.food,
          selectedServingSize: val,
        );
      });
    }
  }

  void _toggleFavorite() async {
    try {
      await ref
          .read(favoriteFoodsProvider.notifier)
          .toggleFavorite(widget.food.id);
      // Update local state to reflect UI change immediately
      setState(() {
        _scaledFood = _scaledFood.copyWith(isFavorite: !_scaledFood.isFavorite);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_scaledFood.isFavorite
                ? 'Added to Favorites'
                : 'Removed from Favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorite status')),
        );
      }
    }
  }

  void _logFood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLogging = true;
    });

    final record = NutritionRecordEntity(
      id: '',
      foodName: _scaledFood.name,
      mealType: _selectedMealType,
      calories: _scaledFood.calories,
      protein: _scaledFood.protein,
      carbohydrates: _scaledFood.carbohydrates,
      fats: _scaledFood.fats,
      sugar: _scaledFood.sugar,
      servingSize: _scaledFood.servingSize,
      consumedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final success = await ref
          .read(nutritionControllerProvider.notifier)
          .addRecord(uid, record);
      if (success) {
        // Save to recents
        await ref.read(recentFoodsProvider.notifier).addRecent(widget.food);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged successfully!')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log food')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final semantic = FitFuelSemanticColors.of(context);
    final pageBackground = isDark ? null : scheme.surfaceContainerLow;

    // Macro percentages
    final double totalMacros =
        _scaledFood.protein + _scaledFood.carbohydrates + _scaledFood.fats;
    final double proteinPercent =
        totalMacros > 0 ? _scaledFood.protein / totalMacros : 0.0;
    final double carbsPercent =
        totalMacros > 0 ? _scaledFood.carbohydrates / totalMacros : 0.0;
    final double fatsPercent =
        totalMacros > 0 ? _scaledFood.fats / totalMacros : 0.0;

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Food Details'),
        actions: [
          IconButton(
            icon: Icon(
              _scaledFood.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _scaledFood.isFavorite ? scheme.error : null,
            ),
            tooltip: 'Favorite Food',
            onPressed: _toggleFavorite,
          ),
          if (_scaledFood.isCustom)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Custom Food',
              onPressed: () {
                context.go(
                    '/nutrition/custom/${Uri.encodeComponent(_scaledFood.id)}/edit');
              },
            ),
        ],
      ),
      backgroundColor: pageBackground,
      body: SafeArea(
        child: AdaptivePageLayout(
          maxWidth: 960,
          child: SingleChildScrollView(
            padding: AdaptivePageLayout.pagePadding(context),
            child: LayoutBuilder(builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 640;

              final heroImage = ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusCard),
                child: FoodImage(
                  food: widget.food,
                  height: wideLayout ? 320 : 220,
                  width: double.infinity,
                  borderRadius: AppConstants.radiusCard,
                ),
              );

              final headerCard = FitFuelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + category
                    Text(_scaledFood.name, style: text.headlineSmall),
                    const SizedBox(height: AppConstants.spaceSm),

                    // Dietary & Cuisine Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                            label: _scaledFood.category,
                            color: scheme.primary),
                        if (_scaledFood.isIndian)
                          _Badge(
                              label: 'Indian',
                              color: semantic.calories),
                        if (_scaledFood.isVegan)
                          _Badge(
                              label: 'Vegan',
                              color: semantic.success)
                        else if (_scaledFood.isVegetarian)
                          _Badge(
                              label: 'Vegetarian',
                              color: semantic.success)
                        else
                          _Badge(
                              label: 'Non-Veg',
                              color: scheme.error),
                        ..._scaledFood.dietaryTags
                            .take(2)
                            .map((tag) => _Badge(
                                label: tag,
                                color: semantic.info)),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceSmd),

                    Text(
                      'Base: ${widget.food.servingSize.toStringAsFixed(0)} ${widget.food.servingUnit}',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Calorie hero metric
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _scaledFood.calories.toStringAsFixed(0),
                            style: text.displayLarge?.copyWith(
                              color: semantic.calories,
                            ),
                          ),
                          Text('kcal', style: text.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceLg),

                    // Macro row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MacroStat(
                            label: 'Protein',
                            value: '${_scaledFood.protein.toStringAsFixed(1)}g',
                            color: semantic.protein),
                        _MacroStat(
                            label: 'Carbs',
                            value:
                                '${_scaledFood.carbohydrates.toStringAsFixed(1)}g',
                            color: semantic.carbohydrates),
                        _MacroStat(
                            label: 'Fat',
                            value: '${_scaledFood.fats.toStringAsFixed(1)}g',
                            color: semantic.fat),
                      ],
                    ),
                  ],
                ),
              );

              if (wideLayout) {
                // Desktop: image + header side by side
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: heroImage),
                        const SizedBox(width: AppConstants.spaceLg),
                        Expanded(child: headerCard),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceLg),
                    _buildMacroDistribution(
                        proteinPercent, carbsPercent, fatsPercent, semantic, text, scheme),
                    const SizedBox(height: AppConstants.spaceMd),
                    _buildNutritionDetails(text, scheme),
                    const SizedBox(height: AppConstants.spaceLg),
                    RecipeSections(key: _recipeKey, food: widget.food),
                    _buildLogSection(text, scheme),
                    const SizedBox(height: AppConstants.spaceLg),
                  ],
                );
              }

              // Mobile: stacked layout
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heroImage,
                  const SizedBox(height: AppConstants.spaceMd),
                  headerCard,
                  const SizedBox(height: AppConstants.spaceMd),
                  _buildMacroDistribution(
                      proteinPercent, carbsPercent, fatsPercent, semantic, text, scheme),
                  const SizedBox(height: AppConstants.spaceMd),
                  _buildNutritionDetails(text, scheme),
                  const SizedBox(height: AppConstants.spaceLg),
                  RecipeSections(key: _recipeKey, food: widget.food),
                  _buildLogSection(text, scheme),
                  const SizedBox(height: AppConstants.spaceLg),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroDistribution(
    double proteinPercent,
    double carbsPercent,
    double fatsPercent,
    FitFuelSemanticColors semantic,
    TextTheme text,
    ColorScheme scheme,
  ) {
    return FitFuelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macro Distribution', style: text.titleSmall),
          const SizedBox(height: AppConstants.spaceSmd),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (proteinPercent > 0)
                    Expanded(
                      flex: (proteinPercent * 100).round(),
                      child: Container(color: semantic.protein),
                    ),
                  if (carbsPercent > 0)
                    Expanded(
                      flex: (carbsPercent * 100).round(),
                      child: Container(color: semantic.carbohydrates),
                    ),
                  if (fatsPercent > 0)
                    Expanded(
                      flex: (fatsPercent * 100).round(),
                      child: Container(color: semantic.fat),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSmd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DistLabel('Protein', proteinPercent, semantic.protein),
              _DistLabel('Carbs', carbsPercent, semantic.carbohydrates),
              _DistLabel('Fat', fatsPercent, semantic.fat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionDetails(TextTheme text, ColorScheme scheme) {
    return FitFuelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceMd, AppConstants.spaceMd,
                AppConstants.spaceMd, AppConstants.spaceSm),
            child: Text('Nutrition Details', style: text.titleSmall),
          ),
          _NutritionRow(
              label: 'Fiber',
              value: '${_scaledFood.fiber.toStringAsFixed(1)} g'),
          Divider(height: 1, color: scheme.outlineVariant),
          _NutritionRow(
              label: 'Sugar',
              value: '${_scaledFood.sugar.toStringAsFixed(1)} g'),
          Divider(height: 1, color: scheme.outlineVariant),
          _NutritionRow(
              label: 'Sodium',
              value: '${_scaledFood.sodium.toStringAsFixed(0)} mg'),
        ],
      ),
    );
  }

  Widget _buildLogSection(TextTheme text, ColorScheme scheme) {
    return FitFuelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add to Food Log', style: text.titleSmall),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _servingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Serving Size',
                    suffixText: widget.food.servingUnit,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                  ),
                  items: _mealTypes.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(m),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMealType = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),

          // Servings Multiplier Quick Select Row
          Text('Quick Servings:', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0.5, 1.0, 1.5, 2.0, 3.0].map((mult) {
              final expectedVal = widget.food.servingSize * mult;
              final currentVal =
                  double.tryParse(_servingController.text) ?? 0.0;
              final isSelected = (currentVal - expectedVal).abs() < 0.1;

              return ChoiceChip(
                label: Text('${mult}x'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _servingController.text =
                        expectedVal.toStringAsFixed(0);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spaceLg),

          FitFuelButton(
            label: _isLogging ? 'Adding to log...' : 'Log Food',
            onPressed: _isLogging ? null : _logFood,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .25), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
}

class _MacroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroStat(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value,
            style:
                text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

class _DistLabel extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _DistLabel(this.label, this.percent, this.color);
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text('$label ${(percent * 100).toStringAsFixed(0)}%',
            style: text.bodySmall),
      ],
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label, value;
  const _NutritionRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSmd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyMedium),
          Text(value,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
