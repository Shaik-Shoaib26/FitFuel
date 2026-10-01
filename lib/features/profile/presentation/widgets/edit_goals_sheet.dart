import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/tdee_calculator.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../controllers/user_profile_controller.dart';
import '../providers/profile_providers.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';

class EditGoalsSheet extends ConsumerStatefulWidget {
  final String uid;
  final dynamic existingGoals; // Keep to support old signature

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
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedFitnessGoal;
  String? _selectedDietaryPreference;

  // Real-time calculated previews
  int _calcCalories = 2000;
  double _calcProtein = 150.0;
  double _calcCarbs = 200.0;
  double _calcFats = 65.0;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields from stream state safely after widget bounds are initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentProfileStreamProvider).value;
      if (profile != null) {
        setState(() {
          if (profile.age != null) _ageController.text = profile.age.toString();
          if (profile.height != null) _heightController.text = profile.height.toString();
          if (profile.weight != null) _weightController.text = profile.weight.toString();
          _selectedGender = profile.gender;
          _selectedActivityLevel = profile.activityLevel;
          _selectedFitnessGoal = profile.fitnessGoal;
          _selectedDietaryPreference = profile.dietaryPreference;
          _recalculatePreview();
        });
      }
    });

    _ageController.addListener(_recalculatePreview);
    _heightController.addListener(_recalculatePreview);
    _weightController.addListener(_recalculatePreview);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _recalculatePreview() {
    final age = int.tryParse(_ageController.text);
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (age != null &&
        height != null &&
        weight != null &&
        _selectedGender != null &&
        _selectedActivityLevel != null &&
        _selectedFitnessGoal != null) {
      
      final bmr = TDEECalculator.calculateBMR(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: _selectedGender!,
      );

      final tdee = TDEECalculator.calculateTDEE(
        bmr: bmr,
        activityLevel: _selectedActivityLevel!,
      );

      final calories = TDEECalculator.calculateCalorieTarget(
        tdee: tdee,
        goal: _selectedFitnessGoal!,
      );

      final macros = TDEECalculator.calculateMacroTargets(
        calorieTarget: calories,
        weightKg: weight,
      );

      setState(() {
        _calcCalories = calories;
        _calcProtein = macros['proteinGrams'] ?? 150.0;
        _calcCarbs = macros['carbsGrams'] ?? 200.0;
        _calcFats = macros['fatGrams'] ?? 65.0;
      });
    }
  }

  void _onSaveSubmitted() async {
    if (!_formKey.currentState!.validate()) return;

    final networkStatus = ref.read(networkStatusProvider).value ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection is required for this action.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = ref.read(userProfileControllerProvider.notifier);
    final currentProfile = ref.read(currentProfileStreamProvider).value;

    final updatedProfile = UserProfileEntity(
      uid: widget.uid,
      email: currentProfile?.email ?? '',
      displayName: currentProfile?.displayName,
      photoUrl: currentProfile?.photoUrl,
      emailVerified: currentProfile?.emailVerified ?? false,
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      height: double.tryParse(_heightController.text),
      weight: double.tryParse(_weightController.text),
      activityLevel: _selectedActivityLevel,
      fitnessGoal: _selectedFitnessGoal,
      dietaryPreference: _selectedDietaryPreference,
      createdAt: currentProfile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await controller.updateProfile(updatedProfile);
    if (success && mounted) {
      ref.invalidate(currentProfileStreamProvider);
      ref.invalidate(nutritionGoalsStreamProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllerState = ref.watch(userProfileControllerProvider);
    final isLoading = controllerState is UserProfileLoadingState;

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
                      'Update Health Profile',
                      style: AppTypography.heading2(isDark: isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                if (controllerState is UserProfileErrorState) ...[
                  Text(
                    controllerState.message,
                    style: const TextStyle(color: AppColors.stateError, fontSize: 13),
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                ],

                // Age, Height, Weight fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final n = int.tryParse(val);
                          if (n == null || n <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Height (cm)'),
                        validator: (val) => Validators.validateNumber(val, min: 30),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)'),
                        validator: (val) => Validators.validateNumber(val, min: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),

                // Gender, Activity Level, Fitness Goal
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (val) {
                          setState(() {
                            _selectedGender = val;
                            _recalculatePreview();
                          });
                        },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                DropdownButtonFormField<String>(
                  initialValue: _selectedActivityLevel,
                  decoration: const InputDecoration(labelText: 'Activity Level'),
                  items: const [
                    DropdownMenuItem(value: 'sedentary', child: Text('Sedentary (desk job)')),
                    DropdownMenuItem(value: 'lightly_active', child: Text('Lightly Active (1-3 days/wk)')),
                    DropdownMenuItem(value: 'moderately_active', child: Text('Moderately Active (3-5 days/wk)')),
                    DropdownMenuItem(value: 'very_active', child: Text('Very Active (6-7 days/wk)')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (val) {
                          setState(() {
                            _selectedActivityLevel = val;
                            _recalculatePreview();
                          });
                        },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                DropdownButtonFormField<String>(
                  initialValue: _selectedFitnessGoal,
                  decoration: const InputDecoration(labelText: 'Fitness Goal'),
                  items: const [
                    DropdownMenuItem(value: 'lose_weight', child: Text('Lose Weight')),
                    DropdownMenuItem(value: 'maintain', child: Text('Maintain Weight')),
                    DropdownMenuItem(value: 'gain_muscle', child: Text('Gain Muscle')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (val) {
                          setState(() {
                            _selectedFitnessGoal = val;
                            _recalculatePreview();
                          });
                        },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: AppConstants.spaceMd),

                DropdownButtonFormField<String>(
                  initialValue: _selectedDietaryPreference,
                  decoration: const InputDecoration(labelText: 'Dietary Preference'),
                  items: const [
                    DropdownMenuItem(value: 'anything', child: Text('Anything / No Limit')),
                    DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarian')),
                    DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                    DropdownMenuItem(value: 'keto', child: Text('Keto')),
                    DropdownMenuItem(value: 'paleo', child: Text('Paleo')),
                    DropdownMenuItem(value: 'low_carb', child: Text('Low Carb')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (val) {
                          setState(() {
                            _selectedDietaryPreference = val;
                          });
                        },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: AppConstants.spaceLg),

                // Calculated goals preview section
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recalculated Daily Targets Preview:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Calories: $_calcCalories kcal', style: const TextStyle(fontSize: 12)),
                          Text('Protein: ${_calcProtein.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 12)),
                          Text('Carbs: ${_calcCarbs.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 12)),
                          Text('Fats: ${_calcFats.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),

                FitFuelButton(
                  label: 'Save Profile & Recalculate Goals',
                  onPressed: isLoading ? null : _onSaveSubmitted,
                  isLoading: isLoading,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
