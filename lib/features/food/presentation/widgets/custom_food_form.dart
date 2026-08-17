import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../domain/entities/food_entity.dart';
import '../providers/food_providers.dart';

class CustomFoodForm extends ConsumerStatefulWidget {
  final FoodEntity? existingFood;

  const CustomFoodForm({super.key, this.existingFood});

  @override
  ConsumerState<CustomFoodForm> createState() => _CustomFoodFormState();
}

class _CustomFoodFormState extends ConsumerState<CustomFoodForm> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameController;
  late final TextEditingController _servingSizeController;
  late final TextEditingController _servingUnitController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  late final TextEditingController _fiberController;
  late final TextEditingController _sugarController;
  late final TextEditingController _sodiumController;

  String _selectedCategory = 'Custom';
  bool _isSaving = false;

  final List<String> _categories = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
    'Fruits',
    'Vegetables',
    'Grains',
    'Protein',
    'Dairy',
    'Beverages',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    final food = widget.existingFood;
    _nameController = TextEditingController(text: food?.name ?? '');
    _servingSizeController = TextEditingController(text: food?.servingSize.toString() ?? '100');
    _servingUnitController = TextEditingController(text: food?.servingUnit ?? 'g');
    _caloriesController = TextEditingController(text: food?.calories.toString() ?? '0');
    _proteinController = TextEditingController(text: food?.protein.toString() ?? '0');
    _carbsController = TextEditingController(text: food?.carbohydrates.toString() ?? '0');
    _fatsController = TextEditingController(text: food?.fats.toString() ?? '0');
    _fiberController = TextEditingController(text: food?.fiber.toString() ?? '0');
    _sugarController = TextEditingController(text: food?.sugar.toString() ?? '0');
    _sodiumController = TextEditingController(text: food?.sodium.toString() ?? '0');

    if (food != null && _categories.contains(food.category)) {
      _selectedCategory = food.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _servingUnitController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final servingSize = double.tryParse(_servingSizeController.text) ?? 100.0;
    final servingUnit = _servingUnitController.text.trim();
    final calories = double.tryParse(_caloriesController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fats = double.tryParse(_fatsController.text) ?? 0.0;
    final fiber = double.tryParse(_fiberController.text) ?? 0.0;
    final sugar = double.tryParse(_sugarController.text) ?? 0.0;
    final sodium = double.tryParse(_sodiumController.text) ?? 0.0;

    final food = FoodEntity(
      id: widget.existingFood?.id ?? '',
      name: name,
      category: _selectedCategory,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      protein: protein,
      carbohydrates: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      isCustom: true,
      isFavorite: widget.existingFood?.isFavorite ?? false,
      createdAt: widget.existingFood?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.existingFood != null) {
        await ref.read(customFoodsProvider.notifier).updateFood(food);
      } else {
        await ref.read(customFoodsProvider.notifier).addFood(food);
      }
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save food: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _deleteFood() async {
    if (widget.existingFood == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Food'),
        content: Text('Are you sure you want to delete "${widget.existingFood!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.stateError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(customFoodsProvider.notifier).deleteFood(widget.existingFood!.id);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete food: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Food name is required';
    }
    return null;
  }

  String? _validatePositive(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    final val = double.tryParse(value);
    if (val == null) {
      return 'Invalid number';
    }
    if (val <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }

  String? _validateNonNegative(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    final val = double.tryParse(value);
    if (val == null) {
      return 'Invalid number';
    }
    if (val < 0) {
      return 'Cannot be negative';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.existingFood != null ? 'Edit Custom Food' : 'Create Custom Food';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.existingFood != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.stateError),
              tooltip: 'Delete custom food',
              onPressed: _isSaving ? null : _deleteFood,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Food Name *',
                    hintText: 'e.g. Avocado Toast',
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: AppConstants.spaceMd),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _servingSizeController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Serving Size *',
                          hintText: '100',
                        ),
                        validator: _validatePositive,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _servingUnitController,
                        enabled: !_isSaving,
                        decoration: const InputDecoration(
                          labelText: 'Unit *',
                          hintText: 'g',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Text(
                  'Nutrition Information (per serving)',
                  style: AppTypography.heading3(isDark: isDark),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                TextFormField(
                  controller: _caloriesController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Calories (kcal) *',
                  ),
                  validator: _validateNonNegative,
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _proteinController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Protein (g) *',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _carbsController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Carbohydrates (g) *',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _fatsController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Fats (g) *',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fiberController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Fiber (g)',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _sugarController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Sugar (g)',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _sodiumController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Sodium (mg)',
                        ),
                        validator: _validateNonNegative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceXl),
                FitFuelButton(
                  label: _isSaving ? 'Saving...' : 'Save Custom Food',
                  onPressed: _isSaving ? null : _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
