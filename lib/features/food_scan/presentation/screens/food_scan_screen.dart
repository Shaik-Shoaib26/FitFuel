import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/network/network_status.dart';
import 'package:fitfuel/core/network/network_status_provider.dart';
import 'package:fitfuel/core/widgets/adaptive_page_layout.dart';
import 'package:fitfuel/core/widgets/fitfuel_button.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_empty_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_loading_state.dart';
import 'package:fitfuel/core/widgets/fitfuel_section_header.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/widgets/detected_food_card.dart';
import 'package:fitfuel/features/food_scan/presentation/widgets/nutrition_estimate_card.dart';

class FoodScanScreen extends ConsumerWidget {
  const FoodScanScreen({super.key});

  void _onPick(BuildContext context, WidgetRef ref, FoodImagePickSource source) {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food scanning requires an internet connection.')),
      );
      return;
    }

    final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    ref.read(foodScanControllerProvider.notifier).pickAndScan(source, catalog: catalog);
  }

  void _openFoodSearchModal(BuildContext context, WidgetRef ref, {int? replaceIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (modalCtx) => _FoodPickerSheet(
        onFoodSelected: (food) {
          if (replaceIndex != null) {
            ref.read(foodScanControllerProvider.notifier).updateMatchedFood(replaceIndex, food);
          } else {
            ref.read(foodScanControllerProvider.notifier).addComponent(food);
          }
          Navigator.of(modalCtx).pop();
        },
      ),
    );
  }

  void _confirmAndLog(BuildContext context, WidgetRef ref, String uid, FoodScanSuccess state) {
    final notifier = ref.read(foodScanControllerProvider.notifier);
    final repo = ref.read(nutritionRepositoryProvider);

    if (state.result.hasIncompleteNutrition) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.stateWarning),
              SizedBox(width: 8),
              Expanded(child: Text('Nutrition Needs Confirmation')),
            ],
          ),
          content: const Text(
            'Some food items have incomplete nutrition values. Please choose the correct food from FitFuel or remove them before saving to your Food Diary.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Review Items'),
            ),
          ],
        ),
      );
      return;
    }

    if (state.result.hasUncertainNutrition) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.stateWarning),
              SizedBox(width: 8),
              Expanded(child: Text('Confirm Nutrition Estimates')),
            ],
          ),
          content: const Text(
            'Some food items use AI-estimated nutrition. Please confirm that you have reviewed the portions and macros before saving to your Food Diary.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.logToDiary(uid, repo);
              },
              child: const Text('Confirm & Add'),
            ),
          ],
        ),
      );
    } else {
      notifier.logToDiary(uid, repo);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodScanControllerProvider);
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOffline = ref.watch(networkStatusProvider).value == NetworkStatus.offline;

    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Scan Food')),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: AdaptivePageLayout.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOffline)
                Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                  padding: const EdgeInsets.all(AppConstants.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.stateError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(color: AppColors.stateError.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: AppColors.stateError, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Food scanning requires an internet connection.',
                          style: TextStyle(color: AppColors.stateError, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              if (state is FoodScanIdle)
                _buildIdleHero(context, ref, isDark)
              else if (state is FoodScanAnalyzing)
                _buildAnalyzingState(state.stageMessage)
              else if (state is FoodScanSuccess)
                _buildSuccessState(context, ref, state, uid, isDark)
              else if (state is FoodScanNoFoodDetected)
                _buildNoFoodDetectedState(context, ref)
              else if (state is FoodScanError)
                _buildErrorState(context, ref, state)
              else if (state is FoodScanLogging)
                const FitFuelLoadingState(label: 'Logging meal to Food Diary...')
              else if (state is FoodScanLogged)
                _buildLoggedState(context, ref, state, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleHero(BuildContext context, WidgetRef ref, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelCard(
          variant: FitFuelCardVariant.hero,
          color: isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
          padding: const EdgeInsets.all(AppConstants.spaceXl),
          child: Column(
            children: [
              // Camera framing viewfinder representation
              Container(
                width: 140,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBgSurface : AppColors.softSage,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.emeraldGreen.withValues(alpha: 0.4)
                        : AppColors.mintGreen,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _ViewfinderCorner(top: true, left: true, isDark: isDark),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ViewfinderCorner(top: true, left: false, isDark: isDark),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: _ViewfinderCorner(top: false, left: true, isDark: isDark),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _ViewfinderCorner(top: false, left: false, isDark: isDark),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryLeafGreen, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLeafGreen.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 26,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Text(
                'Scan Your Meal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Text(
                'Take a photo of your plate. FitFuel AI will identify foods and estimate calories & macros from your food database.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceLg),
              FitFuelButton(
                label: 'Take Photo',
                icon: Icons.camera_alt_rounded,
                onPressed: () => _onPick(context, ref, FoodImagePickSource.camera),
              ),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelButton(
                label: 'Choose from Gallery',
                icon: Icons.photo_library_outlined,
                type: FitFuelButtonType.secondary,
                onPressed: () => _onPick(context, ref, FoodImagePickSource.gallery),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceLg),
        // Privacy Notice
        Container(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSurface : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Estimation Notice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selected photos are held in memory and securely transmitted to the AI vision service to identify food. Raw images are not stored in Firestore or your Food Diary. Nutrition values are calculated from your FitFuel food database.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: AppConstants.spaceLg),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Identifying foods and matching database nutrition...',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    WidgetRef ref,
    FoodScanSuccess state,
    String? uid,
    bool isDark,
  ) {
    final result = state.result;
    final notifier = ref.read(foodScanControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nutrition Summary Hero Card
        NutritionEstimateCard(result: result),

        // Meal Slot Selector
        FitFuelCard(
          margin: const EdgeInsets.only(bottom: AppConstants.spaceLg),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                'Log to:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((slot) {
                    final selected = state.selectedMealType == slot;
                    return ChoiceChip(
                      label: Text(slot, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                      selected: selected,
                      onSelected: (_) => notifier.selectMealType(slot),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Identified Foods Section Header
        FitFuelSectionHeader(
          title: 'Identified Food Items',
          actionLabel: '+ Add Food',
          onActionPressed: () => _openFoodSearchModal(context, ref),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        // Candidates List
        for (var i = 0; i < result.foods.length; i++)
          DetectedFoodCard(
            candidate: result.foods[i],
            onAmountChanged: (val) => notifier.updatePortion(i, val),
            onChangeFood: () => _openFoodSearchModal(context, ref, replaceIndex: i),
            onRemove: () => notifier.removeComponent(i),
          ),

        const SizedBox(height: AppConstants.spaceMd),

        // Primary Actions
        FitFuelButton(
          label: 'Add to Food Diary',
          icon: Icons.bookmark_add_rounded,
          onPressed: uid == null
              ? null
              : () => _confirmAndLog(context, ref, uid, state),
        ),
        const SizedBox(height: AppConstants.spaceSm),
        FitFuelButton(
          label: 'Scan Another Meal',
          icon: Icons.refresh_rounded,
          type: FitFuelButtonType.secondary,
          onPressed: () => notifier.reset(),
        ),
      ],
    );
  }

  Widget _buildNoFoodDetectedState(BuildContext context, WidgetRef ref) {
    return FitFuelEmptyState(
      icon: Icons.no_food_outlined,
      title: 'No Food Detected',
      description: 'We could not clearly identify food items in this image. Try taking another photo with clear lighting.',
      actionLabel: 'Try Another Photo',
      onActionPressed: () => _onPick(context, ref, FoodImagePickSource.camera),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, FoodScanError errorState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDailyQuota = errorState.failureType == FoodScanFailureType.dailyQuotaReached;
    final canRetry = errorState.isRetryable && !isDailyQuota;

    IconData errorIcon;
    switch (errorState.failureType) {
      case FoodScanFailureType.offline:
        errorIcon = Icons.cloud_off_rounded;
        break;
      case FoodScanFailureType.rateLimited:
      case FoodScanFailureType.dailyQuotaReached:
        errorIcon = Icons.hourglass_top_rounded;
        break;
      case FoodScanFailureType.serviceUnavailable:
        errorIcon = Icons.cloud_sync_outlined;
        break;
      case FoodScanFailureType.timeout:
        errorIcon = Icons.timer_outlined;
        break;
      case FoodScanFailureType.modelUnavailable:
        errorIcon = Icons.smart_toy_outlined;
        break;
      case FoodScanFailureType.lowConfidence:
      case FoodScanFailureType.imageQualityPoor:
      case FoodScanFailureType.invalidImage:
        errorIcon = Icons.image_not_supported_outlined;
        break;
      default:
        errorIcon = Icons.error_outline_rounded;
    }

    return FitFuelCard(
      variant: FitFuelCardVariant.hero,
      color: isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
      padding: const EdgeInsets.all(AppConstants.spaceXl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.stateWarning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              errorIcon,
              size: 36,
              color: AppColors.stateWarning,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            errorState.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            errorState.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                ),
            textAlign: TextAlign.center,
          ),
          if (errorState.imagePath != null && !isDailyQuota) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white70,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Your photo is saved. Retry without retaking.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spaceLg),
          if (canRetry) ...[
            FitFuelButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.read(foodScanControllerProvider.notifier).retryScan(),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () => _onPick(context, ref, FoodImagePickSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Choose Another Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            TextButton.icon(
              onPressed: () => _openFoodSearchModal(context, ref),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Identify Food Manually'),
            ),
          ] else if (isDailyQuota) ...[
            FitFuelButton(
              label: 'Identify Food Manually',
              icon: Icons.search_rounded,
              onPressed: () => _openFoodSearchModal(context, ref),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () => _onPick(context, ref, FoodImagePickSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Choose Another Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
          ] else ...[
            FitFuelButton(
              label: 'Choose Another Photo',
              icon: Icons.photo_camera_rounded,
              onPressed: () => _onPick(context, ref, FoodImagePickSource.camera),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () => _openFoodSearchModal(context, ref),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Identify Food Manually'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoggedState(
    BuildContext context,
    WidgetRef ref,
    FoodScanLogged state,
    bool isDark,
  ) {
    return FitFuelCard(
      variant: FitFuelCardVariant.hero,
      color: isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
      padding: const EdgeInsets.all(AppConstants.spaceXl),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.primary),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Meal Added to Diary!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            'Successfully logged ${state.itemsLoggedCount} items (${state.totalCalories.toStringAsFixed(0)} kcal) to ${state.mealType}.',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceLg),
          FitFuelButton(
            label: 'View Food Diary',
            icon: Icons.calendar_today_rounded,
            onPressed: () => context.go('/nutrition'),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          OutlinedButton(
            onPressed: () => ref.read(foodScanControllerProvider.notifier).reset(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, AppConstants.minTouchTargetSize),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusControl)),
            ),
            child: const Text('Scan Another Meal'),
          ),
        ],
      ),
    );
  }
}

class _FoodPickerSheet extends StatefulWidget {
  final ValueChanged<FoodEntity> onFoodSelected;

  const _FoodPickerSheet({required this.onFoodSelected});

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodEntity> _filtered = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase().trim();
    final all = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    if (q.isEmpty) {
      setState(() => _filtered = all);
    } else {
      setState(() {
        _filtered = all
            .where((f) => f.name.toLowerCase().contains(q) || f.category.toLowerCase().contains(q))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Select Database Food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: AppConstants.spaceSm),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search FitFuel foods...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final food = _filtered[index];
                  return ListTile(
                    title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${food.calories.toStringAsFixed(0)} kcal / ${food.servingSize.toStringAsFixed(0)}${food.servingUnit} (P:${food.protein}g C:${food.carbohydrates}g F:${food.fats}g)'),
                    onTap: () => widget.onFoodSelected(food),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCorner extends StatelessWidget {
  final bool top;
  final bool left;
  final bool isDark;

  const _ViewfinderCorner({
    required this.top,
    required this.left,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.emeraldGreen : AppColors.primaryLeafGreen;
    return CustomPaint(
      size: const Size(14, 14),
      painter: _CornerPainter(top: top, left: left, color: color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;

  _CornerPainter({
    required this.top,
    required this.left,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.top != top ||
      oldDelegate.left != left;
}
