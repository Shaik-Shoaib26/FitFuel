import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../nutrition/domain/entities/meal_type.dart';
import '../../../nutrition/domain/entities/nutrition_record_entity.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/utils/food_nutrition_calculator.dart';
import '../providers/food_providers.dart';
import '../widgets/food_image.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  final FoodEntity food;

  const FoodDetailsScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  late FoodEntity _scaledFood;
  late final TextEditingController _servingController;
  String _selectedMealType = 'Breakfast';
  bool _isLogging = false;

  final List<String> _mealTypes = MealType.displayNames;

  @override
  void initState() {
    super.initState();
    _scaledFood = widget.food;
    _servingController = TextEditingController(text: widget.food.servingSize.toStringAsFixed(0));
    _servingController.addListener(_onServingChanged);
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
      await ref.read(favoriteFoodsProvider.notifier).toggleFavorite(widget.food.id);
      // Update local state to reflect UI change immediately
      setState(() {
        _scaledFood = _scaledFood.copyWith(isFavorite: !_scaledFood.isFavorite);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_scaledFood.isFavorite ? 'Added to Favorites' : 'Removed from Favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite status: $e')),
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
      final success = await ref.read(nutritionControllerProvider.notifier).addRecord(uid, record);
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
          SnackBar(content: Text('Failed to log food: $e')),
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

    // Macro percentages
    final double totalMacros = _scaledFood.protein + _scaledFood.carbohydrates + _scaledFood.fats;
    final double proteinPercent = totalMacros > 0 ? _scaledFood.protein / totalMacros : 0.0;
    final double carbsPercent = totalMacros > 0 ? _scaledFood.carbohydrates / totalMacros : 0.0;
    final double fatsPercent = totalMacros > 0 ? _scaledFood.fats / totalMacros : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Details'),
        actions: [
          IconButton(
            icon: Icon(
              _scaledFood.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _scaledFood.isFavorite ? AppColors.stateError : null,
            ),
            tooltip: 'Favorite Food',
            onPressed: _toggleFavorite,
          ),
          if (_scaledFood.isCustom)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Custom Food',
              onPressed: () {
                context.push('/custom-food', extra: _scaledFood);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Standalone top food image with local asset loading
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: FoodImage(
                  food: widget.food,
                  height: 200,
                  width: double.infinity,
                  borderRadius: AppConstants.radiusMd,
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),

              // 1. Header Card with tags and regional badges
              Card(
                elevation: 2,
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _scaledFood.name,
                              style: AppTypography.heading2(isDark: isDark),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary500.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _scaledFood.category,
                              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      // Dietary & Cuisine Badges row
                      Wrap(
                        spacing: 4,
                        children: [
                          if (_scaledFood.isIndian)
                            _buildDetailBadge('Indian', Colors.orange),
                          if (_scaledFood.isVegan)
                            _buildDetailBadge('Vegan', Colors.green)
                          else if (_scaledFood.isVegetarian)
                            _buildDetailBadge('Vegetarian', Colors.green)
                          else
                            _buildDetailBadge('Non-Vegetarian', Colors.red),
                          ..._scaledFood.dietaryTags.map((tag) => _buildDetailBadge(tag, Colors.blue)),
                          ..._scaledFood.mealTypes.map((mt) => _buildDetailBadge(mt, Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceSm),

                      Text(
                        'Base Serving: ${widget.food.servingSize.toStringAsFixed(0)} ${widget.food.servingUnit}',
                        style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroItem('Calories', '${_scaledFood.calories.toStringAsFixed(0)} kcal', Colors.orange, isDark),
                          _buildMacroItem('Protein', '${_scaledFood.protein.toStringAsFixed(1)}g', AppColors.stateSuccess, isDark),
                          _buildMacroItem('Carbs', '${_scaledFood.carbohydrates.toStringAsFixed(1)}g', AppColors.accentCarbs, isDark),
                          _buildMacroItem('Fats', '${_scaledFood.fats.toStringAsFixed(1)}g', Colors.redAccent, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),

              // 2. Macro distribution bars
              Card(
                elevation: 1,
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Macro Distribution',
                        style: AppTypography.heading3(isDark: isDark),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              if (proteinPercent > 0)
                                Expanded(
                                  flex: (proteinPercent * 100).round(),
                                  child: Container(color: AppColors.stateSuccess),
                                ),
                              if (carbsPercent > 0)
                                Expanded(
                                  flex: (carbsPercent * 100).round(),
                                  child: Container(color: AppColors.accentCarbs),
                                ),
                              if (fatsPercent > 0)
                                Expanded(
                                  flex: (fatsPercent * 100).round(),
                                  child: Container(color: Colors.redAccent),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDistributionLabel('Protein', proteinPercent, AppColors.stateSuccess, isDark),
                          _buildDistributionLabel('Carbs', carbsPercent, AppColors.accentCarbs, isDark),
                          _buildDistributionLabel('Fats', fatsPercent, Colors.redAccent, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),

              // 3. Detailed Nutrition Info List (fiber, sugar, sodium)
              Card(
                elevation: 1,
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                child: Column(
                  children: [
                    _buildNutritionRow('Fiber', '${_scaledFood.fiber.toStringAsFixed(1)} g', isDark),
                    const Divider(height: 1),
                    _buildNutritionRow('Sugar', '${_scaledFood.sugar.toStringAsFixed(1)} g', isDark),
                    const Divider(height: 1),
                    _buildNutritionRow('Sodium', '${_scaledFood.sodium.toStringAsFixed(0)} mg', isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),

              // 4. Logging inputs with servings quick-selector multipliers (0.5x, 1x, 1.5x, 2x, 3x)
              Card(
                elevation: 2,
                color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to Food Log',
                        style: AppTypography.heading3(isDark: isDark),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _servingController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      Text(
                        'Quick Servings Multiplier:',
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [0.5, 1.0, 1.5, 2.0, 3.0].map((mult) {
                          final expectedVal = widget.food.servingSize * mult;
                          final currentVal = double.tryParse(_servingController.text) ?? 0.0;
                          final isSelected = (currentVal - expectedVal).abs() < 0.1;

                          return ChoiceChip(
                            label: Text('${mult}x'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _servingController.text = expectedVal.toStringAsFixed(0);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),

                      FitFuelButton(
                        label: _isLogging ? 'Adding to log...' : 'Log Food',
                        onPressed: _isLogging ? null : _logFood,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.heading3(isDark: isDark).copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall(isDark: isDark).copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDistributionLabel(String label, double percent, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ${(percent * 100).toStringAsFixed(0)}%',
          style: AppTypography.bodySmall(isDark: isDark),
        ),
      ],
    );
  }

  Widget _buildNutritionRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium(isDark: isDark)),
          Text(value, style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
