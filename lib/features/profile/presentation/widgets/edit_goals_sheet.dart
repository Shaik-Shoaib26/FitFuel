import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../controllers/nutrition_goals_controller.dart';

class EditGoalsSheet extends ConsumerStatefulWidget {
  final String uid;
  final NutritionGoalsEntity? existingGoals;

  const EditGoalsSheet({
    super.key,
    required this.uid,
    this.existingGoals,
  });

  @override
  ConsumerState<EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends ConsumerState<EditGoalsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;

  @override
  void initState() {
    super.initState();
    final goals = widget.existingGoals;
    _caloriesController = TextEditingController(text: goals?.dailyCalorieTarget.toString() ?? '2000');
    _proteinController = TextEditingController(text: goals?.proteinTargetGrams.toString() ?? '150.0');
    _carbsController = TextEditingController(text: goals?.carbsTargetGrams.toString() ?? '200.0');
    _fatsController = TextEditingController(text: goals?.fatTargetGrams.toString() ?? '65.0');
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  void _onSaveSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(nutritionGoalsControllerProvider.notifier);

    final goals = NutritionGoalsEntity(
      userId: widget.uid,
      dailyCalorieTarget: int.tryParse(_caloriesController.text) ?? 2000,
      proteinTargetGrams: double.tryParse(_proteinController.text) ?? 150.0,
      carbsTargetGrams: double.tryParse(_carbsController.text) ?? 200.0,
      fatTargetGrams: double.tryParse(_fatsController.text) ?? 65.0,
      updatedAt: DateTime.now(),
    );

    final success = await controller.saveGoals(widget.uid, goals);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(nutritionGoalsControllerProvider);
    final isLoading = controllerState is NutritionGoalsLoadingState;

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
                      'Update Nutrition Goals',
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
                if (controllerState is NutritionGoalsErrorState) ...[
                  Text(
                    controllerState.message,
                    style: const TextStyle(color: AppColors.stateError, fontSize: 13),
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                ],

                // Calories Target Field
                TextFormField(
                  controller: _caloriesController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily Calories Goal (kcal)',
                    prefixIcon: Icon(Icons.local_fire_department_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Calories goal is required';
                    final num = int.tryParse(val);
                    if (num == null || num <= 0) return 'Please enter a valid positive integer';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Protein, Carbs, Fats Target Fields Row
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
                const SizedBox(height: AppConstants.spaceLg),

                // Save Action Button
                FitFuelButton(
                  label: 'Save Goals',
                  onPressed: isLoading ? null : _onSaveSubmitted,
                  isLoading: isLoading,
                  icon: Icons.save_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
