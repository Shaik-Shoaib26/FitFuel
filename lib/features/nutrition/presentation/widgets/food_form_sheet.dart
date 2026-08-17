import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../controllers/nutrition_controller.dart';
import '../../../food/domain/entities/food_entity.dart';
import '../../../food/presentation/providers/food_providers.dart';
import '../../../food/data/datasources/predefined_food_data.dart';

class FoodFormSheet extends ConsumerStatefulWidget {
  final String uid;
  final NutritionRecordEntity? existingRecord;

  const FoodFormSheet({
    super.key,
    required this.uid,
    this.existingRecord,
  });

  @override
  ConsumerState<FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends ConsumerState<FoodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  late final TextEditingController _sugarController;
  late final TextEditingController _servingController;
  String _selectedMealType = 'Breakfast';

  final List<String> _mealTypes = MealType.displayNames;

  @override
  void initState() {
    super.initState();
    final record = widget.existingRecord;
    _nameController = TextEditingController(text: record?.foodName ?? '');
    _caloriesController = TextEditingController(text: record?.calories.toString() ?? '');
    _proteinController = TextEditingController(text: record?.protein.toString() ?? '');
    _carbsController = TextEditingController(text: record?.carbohydrates.toString() ?? '');
    _fatsController = TextEditingController(text: record?.fats.toString() ?? '');
    _sugarController = TextEditingController(text: record?.sugar.toString() ?? '');
    _servingController = TextEditingController(text: record?.servingSize.toString() ?? '');
    _selectedMealType = MealType.normalize(record?.mealType ?? 'Breakfast');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _sugarController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  void _onSaveSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(nutritionControllerProvider.notifier);

    final record = NutritionRecordEntity(
      id: widget.existingRecord?.id ?? '',
      foodName: _nameController.text.trim(),
      mealType: _selectedMealType,
      calories: double.tryParse(_caloriesController.text) ?? 0.0,
      protein: double.tryParse(_proteinController.text) ?? 0.0,
      carbohydrates: double.tryParse(_carbsController.text) ?? 0.0,
      fats: double.tryParse(_fatsController.text) ?? 0.0,
      sugar: double.tryParse(_sugarController.text) ?? 0.0,
      servingSize: double.tryParse(_servingController.text) ?? 100.0,
      consumedAt: widget.existingRecord?.consumedAt ?? DateTime.now(),
      createdAt: widget.existingRecord?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (widget.existingRecord != null && widget.existingRecord!.id.isNotEmpty) {
      success = await controller.updateRecord(widget.uid, record);
    } else {
      success = await controller.addRecord(widget.uid, record);
    }

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(nutritionControllerProvider);
    final isLoading = controllerState is NutritionLoadingState;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusLg),
            topRight: Radius.circular(AppConstants.radiusLg),
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingRecord != null ? 'Edit Logged Food' : 'Log Food Item',
                      style: AppTypography.heading2(isDark: isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Error message from controller
                if (controllerState is NutritionErrorState) ...[
                  Text(
                    controllerState.message,
                    style: const TextStyle(color: AppColors.stateError, fontSize: 13),
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                ],

                // Search Food Database Button
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final selectedFood = await showDialog<FoodEntity>(
                            context: context,
                            builder: (context) => const _FoodSearchDialog(),
                          );
                          if (selectedFood != null) {
                            setState(() {
                              _nameController.text = selectedFood.name;
                              _caloriesController.text = selectedFood.calories.toStringAsFixed(0);
                              _proteinController.text = selectedFood.protein.toStringAsFixed(1);
                              _carbsController.text = selectedFood.carbohydrates.toStringAsFixed(1);
                              _fatsController.text = selectedFood.fats.toStringAsFixed(1);
                              _sugarController.text = selectedFood.sugar.toStringAsFixed(1);
                              _servingController.text = selectedFood.servingSize.toStringAsFixed(0);
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500.withAlpha(20),
                    foregroundColor: AppColors.primary500,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search Food Database'),
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Food Name Field
                TextFormField(
                  controller: _nameController,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Food Name',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Food name is required' : null,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Meal Type Dropdown Field
                DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    prefixIcon: Icon(Icons.dining_rounded),
                  ),
                  items: _mealTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: isLoading
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMealType = val;
                            });
                          }
                        },
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Calories and Serving Size Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caloriesController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          prefixIcon: Icon(Icons.local_fire_department_rounded),
                        ),
                        validator: (val) => Validators.validateNumber(val, min: 0),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _servingController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Serving Size (g/ml)',
                          prefixIcon: Icon(Icons.scale_rounded),
                        ),
                        validator: (val) => Validators.validateNumber(val, min: 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Protein, Carbs, Fats Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _proteinController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                        ),
                        validator: (val) => Validators.validateNumber(val, min: 0),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        controller: _carbsController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                        ),
                        validator: (val) => Validators.validateNumber(val, min: 0),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        controller: _fatsController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Fats (g)',
                        ),
                        validator: (val) => Validators.validateNumber(val, min: 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Sugar Field
                TextFormField(
                  controller: _sugarController,
                  enabled: !isLoading,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sugar (g)',
                    prefixIcon: Icon(Icons.cookie_outlined),
                  ),
                  validator: (val) => Validators.validateNumber(val, min: 0),
                ),
                const SizedBox(height: AppConstants.spaceLg),

                // Save Action Button
                FitFuelButton(
                  label: widget.existingRecord != null ? 'Update Record' : 'Log Food Item',
                  onPressed: isLoading ? null : _onSaveSubmitted,
                  isLoading: isLoading,
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodSearchDialog extends ConsumerStatefulWidget {
  const _FoodSearchDialog();

  @override
  ConsumerState<_FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends ConsumerState<_FoodSearchDialog> {
  final TextEditingController _dialogSearchController = TextEditingController();
  List<FoodEntity> _dialogFoods = [];
  bool _dialogLoading = false;

  @override
  void initState() {
    super.initState();
    _dialogSearchController.addListener(_onSearchChanged);
    _loadInitialFoods();
  }

  @override
  void dispose() {
    _dialogSearchController.dispose();
    super.dispose();
  }

  void _loadInitialFoods() async {
    setState(() => _dialogLoading = true);
    try {
      final repo = ref.read(foodRepositoryProvider);
      final list = await repo.searchFoods('');
      if (mounted) {
        setState(() {
          _dialogFoods = list.isNotEmpty
              ? list
              : PredefinedFoodData.foods.map((e) => e.toEntity()).toList();
          _dialogLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dialogLoading = false);
      }
    }
  }

  void _onSearchChanged() async {
    final query = _dialogSearchController.text.trim();
    if (query.isEmpty) {
      _loadInitialFoods();
      return;
    }
    setState(() => _dialogLoading = true);
    try {
      final repo = ref.read(foodRepositoryProvider);
      final list = await repo.searchFoods(query);
      if (mounted) {
        setState(() {
          _dialogFoods = list;
          _dialogLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dialogLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Food Database'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _dialogSearchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or category...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _dialogLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _dialogFoods.isEmpty
                      ? const Center(child: Text('No results found.'))
                      : ListView.builder(
                          itemCount: _dialogFoods.length,
                          itemBuilder: (context, index) {
                            final food = _dialogFoods[index];
                            return ListTile(
                              title: Text(food.name),
                              subtitle: Text('${food.category} • ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}'),
                              trailing: Text('${food.calories.toStringAsFixed(0)} kcal'),
                              onTap: () {
                                Navigator.of(context).pop(food);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
