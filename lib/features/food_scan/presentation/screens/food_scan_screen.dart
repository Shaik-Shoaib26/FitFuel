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
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_result.dart';
import 'package:fitfuel/features/food_scan/domain/errors/food_scan_failure.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';
import 'package:fitfuel/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart';
import 'package:fitfuel/features/food_scan/presentation/controllers/food_scan_state.dart';
import 'package:fitfuel/features/food_scan/presentation/providers/food_scan_providers.dart';
import 'package:fitfuel/features/food_scan/presentation/widgets/detected_food_card.dart';
import 'package:fitfuel/features/food_scan/presentation/widgets/nutrition_estimate_card.dart';

class FoodScanScreen extends ConsumerWidget {
  const FoodScanScreen({super.key});

  void _onPick(BuildContext context, WidgetRef ref, FoodImagePickSource source) {
    final state = ref.read(foodScanControllerProvider);
    if (state is FoodScanAnalyzing || state is FoodScanLogging) {
      return; // Ignore double-taps during analysis or diary logging
    }

    final isOffline =
        ref.read(networkStatusProvider).value == NetworkStatus.offline;
    final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    ref.read(foodScanControllerProvider.notifier).pickAndScan(
          source,
          catalog: catalog,
          isOffline: isOffline,
        );
  }

  void _openFoodSearchModal(
    BuildContext context,
    WidgetRef ref, {
    int? replaceIndex,
    String? initialQuery,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (modalCtx) => _FoodPickerSheet(
        initialQuery: initialQuery,
        onFoodSelected: (food) {
          if (replaceIndex != null) {
            ref
                .read(foodScanControllerProvider.notifier)
                .updateMatchedFood(replaceIndex, food);
          } else {
            ref.read(foodScanControllerProvider.notifier).addComponent(food);
          }
          Navigator.of(modalCtx).pop();
        },
      ),
    );
  }

  void _openManualNutritionEntry(
    BuildContext context,
    WidgetRef ref, {
    required String initialName,
    int replaceIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (modalCtx) => _ManualNutritionEntrySheet(
        initialName: initialName,
        onFoodCreated: (food) {
          ref
              .read(foodScanControllerProvider.notifier)
              .updateMatchedFood(replaceIndex, food);
          Navigator.of(modalCtx).pop();
        },
      ),
    );
  }

  void _openFeedbackDialog(BuildContext context, String detectedFoodName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Report or Correct Food'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detected as: $detectedFoodName'),
            const SizedBox(height: AppConstants.spaceSm),
            const Text(
                'Include dish name in review queue (no photos uploaded)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('btn_submit_food_feedback'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmAndLog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    FoodScanSuccess state,
  ) {
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
    final isOffline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;

    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Scan Food')),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: AdaptivePageLayout.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOffline && state is! FoodScanSuggestions)
                Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                  padding: const EdgeInsets.all(AppConstants.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.stateError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(
                        color: AppColors.stateError.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: AppColors.stateError, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Food scanning requires an internet connection.',
                          style: TextStyle(
                            color: AppColors.stateError,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (state is FoodScanIdle)
                _buildIdleHero(context, ref, isDark)
              else if (state is FoodScanAnalyzing)
                _buildAnalyzingState(state.stageMessage)
              else if (state is FoodScanSuggestions)
                _buildSuggestionsState(context, ref, state, isDark, isOffline)
              else if (state is FoodScanSuccess)
                _buildSuccessState(context, ref, state, uid, isDark)
              else if (state is FoodScanNoFoodDetected)
                _buildNoFoodDetectedState(context, ref, state)
              else if (state is FoodScanError)
                _buildErrorState(context, ref, state)
              else if (state is FoodScanLogging)
                const FitFuelLoadingState(
                    label: 'Logging meal to Food Diary...')
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
          color:
              isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
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
                      child:
                          _ViewfinderCorner(top: true, left: true, isDark: isDark),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ViewfinderCorner(
                          top: true, left: false, isDark: isDark),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: _ViewfinderCorner(
                          top: false, left: true, isDark: isDark),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _ViewfinderCorner(
                          top: false, left: false, isDark: isDark),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkPrimaryContainer
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryLeafGreen, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLeafGreen
                                .withValues(alpha: 0.15),
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
                'Scan Your Food',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Text(
                'Take a photo and FitFuel will scan it on your device first.\nNo internet or AI quota is required for local scanning.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.secondaryText,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceSm),
              const Text(
                'Free • On-device',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLeafGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceMd),
              FitFuelButton(
                label: 'Take Photo',
                icon: Icons.camera_alt_rounded,
                onPressed: () =>
                    _onPick(context, ref, FoodImagePickSource.camera),
              ),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelButton(
                label: 'Choose from Gallery',
                icon: Icons.photo_library_outlined,
                type: FitFuelButtonType.secondary,
                onPressed: () =>
                    _onPick(context, ref, FoodImagePickSource.gallery),
              ),
              const SizedBox(height: AppConstants.spaceSm),
              TextButton.icon(
                onPressed: () => _openFoodSearchModal(context, ref),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Search Foods'),
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
            border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.primary),
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
                      'Food photos are analyzed on your device first. Your photo is only sent to the online AI service if you choose \'Analyze with AI\'. Nutrition values come from FitFuel\'s food database.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.secondaryText,
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

  Widget _buildSuggestionsState(
    BuildContext context,
    WidgetRef ref,
    FoodScanSuggestions state,
    bool isDark,
    bool networkOffline,
  ) {
    final notifier = ref.read(foodScanControllerProvider.notifier);
    final routerConfig = ref.watch(foodScanRouterConfigProvider);
    final effectiveOffline = networkOffline || state.isOffline;
    final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    final aiFailure = state.aiFailure;
    final isQuotaExhausted = state.isQuotaExhausted;
    final showRetryAi =
        aiFailure != null && !isQuotaExhausted && !effectiveOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Non-blocking AI status notice when cloud analysis failed or quota exhausted
        if (aiFailure != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.stateWarning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                  color: AppColors.stateWarning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.stateWarning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aiFailure.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  aiFailure.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Offline non-blocking info banner
        if (effectiveOffline) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.primaryLeafGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(
                  color: AppColors.primaryLeafGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_outlined,
                    color: AppColors.primaryLeafGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose the closest match',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'AI analysis needs an internet connection.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Retained photo indicator
        if (state.imagePath != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
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
                Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your photo is saved.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Mixed Meal Decision Card
        if (state.isMixedMealSuspected) ...[
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded,
                        color: AppColors.primaryLeafGreen, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Multiple foods detected or suspected.',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Add each food item manually from the FitFuel catalog or analyze the plate with AI.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                FitFuelButton(
                  label: 'Add Foods Manually',
                  icon: Icons.playlist_add_rounded,
                  onPressed: () => _openFoodSearchModal(context, ref),
                ),
              ],
            ),
          ),
        ],

        // Open-Vocabulary Top Local Matches (Tier 2)
        if (state.openVocabSuggestions.isNotEmpty) ...[
          const FitFuelSectionHeader(title: 'Top Local Matches'),
          const SizedBox(height: AppConstants.spaceSm),
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        state.isUncertainMatch
                            ? 'Possible match: ${state.openVocabSuggestions.first.canonicalName}'
                            : 'Best local match: ${state.openVocabSuggestions.first.canonicalName}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.isUncertainMatch
                            ? AppColors.stateWarning.withValues(alpha: 0.15)
                            : AppColors.primaryLeafGreen.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        state.isUncertainMatch
                            ? 'Possible Match'
                            : 'On-Device Vision',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: state.isUncertainMatch
                              ? AppColors.stateWarning
                              : AppColors.primaryLeafGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                OutlinedButton(
                  key: Key(
                      'suggestion_${state.openVocabSuggestions.first.canonicalFoodId}'),
                  onPressed: () => notifier.confirmOpenVocabSuggestion(
                    state.openVocabSuggestions.first,
                    catalog: catalog,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    backgroundColor:
                        isDark ? AppColors.darkBgSurface : Colors.white,
                    side: BorderSide(
                      color:
                          AppColors.primaryLeafGreen.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusControl),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.openVocabSuggestions.first.canonicalName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryText,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Cosine similarity: ${state.openVocabSuggestions.first.similarity.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ],
                  ),
                ),
                if (state.openVocabSuggestions.length > 1) ...[
                  const SizedBox(height: AppConstants.spaceSm),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: FitFuelCard(
                      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: const Key('expansion_alternative_matches'),
                        initiallyExpanded: state.isOtherMatchesExpanded,
                        onExpansionChanged: (_) =>
                            notifier.toggleOtherMatchesExpanded(),
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        leading: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 20,
                          color: AppColors.primaryLeafGreen,
                        ),
                        title: Text(
                          'Wrong food? Choose another',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.secondaryText,
                          ),
                        ),
                        children: [
                          for (final alt in state.openVocabSuggestions.sublist(1))
                            ListTile(
                              key: Key('suggestion_${alt.canonicalFoodId}'),
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              title: Text(
                                alt.canonicalName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: alt.category.isNotEmpty
                                  ? Text(
                                      alt.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.secondaryText,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (routerConfig.enableDebugTelemetryUi)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        alt.similarity.toStringAsFixed(3),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppColors.primaryLeafGreen,
                                  ),
                                ],
                              ),
                              onTap: () => notifier.confirmOpenVocabSuggestion(
                                alt,
                                catalog: catalog,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_report_food_feedback'),
                        onPressed: () => _openFeedbackDialog(
                          context,
                          state.openVocabSuggestions.first.canonicalName,
                        ),
                        icon: const Icon(Icons.flag_outlined, size: 16),
                        label: const Text('Report Food'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_search_catalog_suggestions'),
                        onPressed: () => _openFoodSearchModal(context, ref),
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: const Text('Search Catalog'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (state.hasSuggestions && state.suggestions.isNotEmpty) ...[
          const FitFuelSectionHeader(title: 'Identified Food'),
          const SizedBox(height: AppConstants.spaceSm),
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.suggestions.first.confidence < 0.70
                          ? 'Possible match'
                          : 'Identified food',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (state.suggestions.first.confidence < 0.70
                                ? AppColors.stateWarning
                                : AppColors.primaryLeafGreen)
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        state.suggestions.first.confidence < 0.70
                            ? 'Possible match'
                            : 'Identified food',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: state.suggestions.first.confidence < 0.70
                              ? AppColors.stateWarning
                              : AppColors.primaryLeafGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  state.suggestions.first.confidence < 0.70
                      ? 'Low confidence match. Select below or choose another.'
                      : 'Choose the closest match or tap below to search.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                OutlinedButton(
                  key: Key('suggestion_${state.suggestions.first.foodId}'),
                  onPressed: () => notifier.confirmSuggestion(
                    state.suggestions.first,
                    catalog: catalog,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    backgroundColor:
                        isDark ? AppColors.darkBgSurface : Colors.white,
                    side: BorderSide(
                      color: AppColors.primaryLeafGreen.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusControl),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.suggestions.first.foodName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryText,
                          ),
                        ),
                      ),
                      if (routerConfig.enableDebugTelemetryUi)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${(state.suggestions.first.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ],
                  ),
                ),
                if (state.suggestions.length > 1) ...[
                  const SizedBox(height: AppConstants.spaceSm),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: FitFuelCard(
                      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: const Key('expansion_alternative_matches'),
                        initiallyExpanded: state.isOtherMatchesExpanded,
                        onExpansionChanged: (_) =>
                            notifier.toggleOtherMatchesExpanded(),
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        leading: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 20,
                          color: AppColors.primaryLeafGreen,
                        ),
                        title: Text(
                          'Wrong food? Choose another',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.secondaryText,
                          ),
                        ),
                        children: [
                          for (final alt in state.suggestions.sublist(1))
                            ListTile(
                              key: Key('suggestion_${alt.foodId}'),
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              title: Text(
                                alt.foodName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (routerConfig.enableDebugTelemetryUi)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '${(alt.confidence * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppColors.primaryLeafGreen,
                                  ),
                                ],
                              ),
                              onTap: () => notifier.confirmSuggestion(
                                alt,
                                catalog: catalog,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (state.isLocalModelUnavailable) ...[
          // Local Model Unavailable Card (distinct from non-food or uncertain food)
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Food scanner unavailable',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'The on-device model could not be initialized or encountered an error. You can search FitFuel foods or try again.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ] else if (state.isNonFoodAbstained) ...[
          // Tier 2 Non-Food Abstention Card (never shows internal food guesses)
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No food detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Try another photo with the food clearly visible.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ] else if (!state.isMixedMealSuspected) ...[
          // Uncertain Food Prediction Card (distinct from "No food detected")
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "We couldn't identify this meal confidently",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'This meal may contain multiple food components (such as chapati, dal, curry and salad) or complex ingredients.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                FitFuelButton(
                  key: const Key('btn_build_meal_components'),
                  label: 'Build Meal from Components',
                  icon: Icons.playlist_add_rounded,
                  onPressed: () => _openFoodSearchModal(context, ref),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => notifier.reset(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Another Photo'),
                ),
              ],
            ),
          ),
        ],

        // Secondary Actions ("Not here?")
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceXs),
          child: Text(
            'Not here?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        FitFuelButton(
          label: 'Search Foods',
          icon: Icons.search_rounded,
          onPressed: () => _openFoodSearchModal(context, ref),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        if (showRetryAi) ...[
          FitFuelButton(
            label: 'Retry AI',
            icon: Icons.refresh_rounded,
            type: FitFuelButtonType.secondary,
            onPressed: () => notifier.analyzeWithAi(
              catalog: catalog,
              isOffline: effectiveOffline,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
        ] else if (!isQuotaExhausted) ...[
          FitFuelButton(
            label: 'Analyze with AI',
            icon: Icons.auto_awesome_rounded,
            type: FitFuelButtonType.secondary,
            onPressed: effectiveOffline
                ? null
                : () => notifier.analyzeWithAi(
                      catalog: catalog,
                      isOffline: effectiveOffline,
                    ),
          ),
          if (effectiveOffline) ...[
            const SizedBox(height: 4),
            const Text(
              'Online AI analysis is unavailable while offline.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppConstants.spaceSm),
        ],

        OutlinedButton.icon(
          onPressed: () => _onPick(context, ref, FoodImagePickSource.camera),
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: const Text('Try Another Photo'),
          style: OutlinedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, AppConstants.minTouchTargetSize),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusControl),
            ),
          ),
        ),
      ],
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
    final routerConfig = ref.watch(foodScanRouterConfigProvider);
    final isOffline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    final primaryFood = result.foods.isNotEmpty ? result.foods.first : null;

    debugPrint(
      '[FoodScanUI] result_id=${result.id} foods_count=${result.foods.length} '
      'can_be_logged=${result.canBeLogged} is_open_vocab=${result.isOpenVocabulary} '
      'total_cal=${result.totalCalories} total_p=${result.totalProtein} total_c=${result.totalCarbs} total_f=${result.totalFats}',
    );

    // Case B — Confirmed Open-Vocabulary Food Without Exact FitFuel Nutrition Match Yet
    if (result.isOpenVocabulary && !result.canBeLogged && result.foods.length <= 1) {
      final confirmedName = primaryFood?.displayName ?? 'Food';
      final smartQuery =
          TrustedOpenVocabNutritionMapper.buildSmartSearchQuery(confirmedName);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FitFuelCard(
            variant: FitFuelCardVariant.hero,
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food recognized',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            confirmedName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryText,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBgSurface : Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorderSubtle
                              : AppColors.border,
                        ),
                      ),
                      child: const Text(
                        '— kcal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryLeafGreen.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        border: Border.all(
                          color: AppColors.primaryLeafGreen
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 14,
                            color: AppColors.primaryLeafGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            result.sourceBadgeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLeafGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (result.secondarySourceDetail != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white70,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusFull),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorderSubtle
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          result.secondarySourceDetail!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.stateWarning.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        border: Border.all(
                          color: AppColors.stateWarning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Select nutrition profile',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stateWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgSurface : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorderSubtle
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exact nutrition profile isn\'t available yet.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Nutrition profile unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stateWarning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the closest nutrition profile from FitFuel Foods before logging.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                FitFuelButton(
                  key: const Key('btn_search_fitfuel_foods'),
                  label: 'Search FitFuel Foods',
                  icon: Icons.search_rounded,
                  onPressed: () => _openFoodSearchModal(
                    context,
                    ref,
                    replaceIndex: 0,
                    initialQuery: smartQuery,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                FitFuelButton(
                  key: const Key('btn_enter_food_manually'),
                  label: 'Enter Food & Portion Manually',
                  icon: Icons.edit_note_rounded,
                  type: FitFuelButtonType.secondary,
                  onPressed: () => _openManualNutritionEntry(
                    context,
                    ref,
                    initialName: confirmedName,
                    replaceIndex: 0,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openFoodSearchModal(
                          context,
                          ref,
                          replaceIndex: 0,
                                                  ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Change Food'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _onPick(context, ref, FoodImagePickSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Try Another Photo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                FitFuelButton(
                  label: 'Analyze with AI',
                  icon: Icons.auto_awesome_rounded,
                  type: FitFuelButtonType.secondary,
                  onPressed: isOffline
                      ? null
                      : () => notifier.analyzeWithAi(
                            catalog: catalog,
                            isOffline: isOffline,
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          OutlinedButton.icon(
            key: const Key('btn_add_another_component_case_b'),
            onPressed: () => _openFoodSearchModal(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('+ Add Another Food (e.g. Dal, Curry, Salad)'),
            style: OutlinedButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, AppConstants.minTouchTargetSize),
              side: BorderSide(
                  color: AppColors.primaryLeafGreen.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusControl),
              ),
            ),
          ),
          _buildQuickAddComponentsRow(context, ref, result, catalog, isDark),
          const SizedBox(height: AppConstants.spaceSm),
          const FitFuelButton(
            label: 'Add to Food Diary',
            icon: Icons.bookmark_add_rounded,
            onPressed: null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nutrition Summary Hero Card
        NutritionEstimateCard(result: result),

        const SizedBox(height: AppConstants.spaceSm),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLeafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  border: Border.all(
                    color: AppColors.primaryLeafGreen.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.isRecognizedOnDevice
                          ? Icons.bolt_rounded
                          : (result.isUserConfirmed
                              ? Icons.verified_user_outlined
                              : Icons.auto_awesome_rounded),
                      size: 14,
                      color: AppColors.primaryLeafGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      result.sourceBadgeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.isOpenVocabularyConfirmed &&
                  result.secondarySourceDetail != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white70,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorderSubtle
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    result.secondarySourceDetail!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceSm),

        if (routerConfig.enableDebugTelemetryUi) ...[
          Center(
            child: Text(
              result.debugRoute,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
        ],

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
                  children:
                      ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((slot) {
                    final selected = state.selectedMealType == slot;
                    return ChoiceChip(
                      label: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
            onChangeFood: () => _openFoodSearchModal(
              context,
              ref,
              replaceIndex: i,
            ),
            onRemove: () => notifier.removeComponent(i),
          ),

        // Phase 35.13.2: Explicit meal-building action to add mixed meal components
        const SizedBox(height: AppConstants.spaceXs),
        OutlinedButton.icon(
          key: const Key('btn_add_another_component'),
          onPressed: () => _openFoodSearchModal(context, ref),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('+ Add Another Food (e.g. Dal, Curry, Salad)'),
          style: OutlinedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, AppConstants.minTouchTargetSize),
            side: BorderSide(
                color: AppColors.primaryLeafGreen.withValues(alpha: 0.45)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusControl),
            ),
          ),
        ),
        _buildQuickAddComponentsRow(context, ref, result, catalog, isDark),

        // Phase 35.13.0 Section 6 & 35.13.2: Honest Meal Totals summary card for mixed meals
        if (result.foods.length > 1) ...[
          const SizedBox(height: AppConstants.spaceSm),
          FitFuelCard(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            color: isDark
                ? AppColors.darkPrimaryContainer
                : AppColors.softBrandSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.hasIncompleteNutrition
                          ? 'Meal Totals (Incomplete • ${result.unresolvedFoods.length} need profile)'
                          : 'Meal Totals (${result.foods.length} items)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      result.verifiedTotalCalories != null
                          ? '${result.verifiedTotalCalories!.toStringAsFixed(0)} kcal'
                          : '— kcal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: result.hasIncompleteNutrition
                            ? AppColors.stateWarning
                            : AppColors.primaryLeafGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'P: ${result.verifiedTotalProtein != null ? "${result.verifiedTotalProtein!.toStringAsFixed(1)}g" : "—"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.protein,
                      ),
                    ),
                    Text(
                      'C: ${result.verifiedTotalCarbs != null ? "${result.verifiedTotalCarbs!.toStringAsFixed(1)}g" : "—"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.carbs,
                      ),
                    ),
                    Text(
                      'F: ${result.verifiedTotalFats != null ? "${result.verifiedTotalFats!.toStringAsFixed(1)}g" : "—"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.fat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Phase 35.13.0 Section 3: Subordinate expandable variant selector
        if (result.foods.length == 1 &&
            result.openVocabCandidates.length > 1) ...[
          const SizedBox(height: AppConstants.spaceXs),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: FitFuelCard(
              margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: AppColors.primaryLeafGreen,
                ),
                title: Text(
                  'Wrong dish? Choose alternative variant',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.secondaryText,
                  ),
                ),
                children: [
                  for (final alt in result.openVocabCandidates.sublist(1))
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      title: Text(
                        alt.displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        alt.category.isNotEmpty ? alt.category : 'Dish Variant',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: AppColors.primaryLeafGreen,
                      ),
                      onTap: () => notifier.confirmOpenVocabSuggestion(
                        alt,
                        catalog: catalog,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: AppConstants.spaceSm),
        Container(
          margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.black12 : AppColors.softBrandSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryLeafGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm portion size: A photo alone cannot determine exact ingredients, cooking oil, or recipe variations.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Primary Actions
        FitFuelButton(
          label: 'Add to Food Diary',
          icon: Icons.bookmark_add_rounded,
          onPressed: uid == null || !result.canBeLogged
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

  Widget _buildNoFoodDetectedState(
      BuildContext context, WidgetRef ref, FoodScanNoFoodDetected state) {
    IconData icon;
    String title;
    String description;
    String actionLabel = 'Try Another Photo';
    VoidCallback onActionPressed =
        () => _onPick(context, ref, FoodImagePickSource.camera);

    switch (state.reason) {
      case NoFoodReason.nonFood:
        icon = Icons.no_food_outlined;
        title = 'No Food Detected';
        description = state.customMessage ??
            'No food items were detected in this image. Please take a photo of a meal or ingredient.';
        break;
      case NoFoodReason.uncertainMatch:
        icon = Icons.help_outline_rounded;
        title = 'Uncertain Food Match';
        description = state.customMessage ??
            'We could not identify this food with sufficient confidence. Try another angle or search the catalog.';
        break;
      case NoFoodReason.nutritionMissing:
        icon = Icons.menu_book_outlined;
        title = 'Nutrition Profile Unavailable';
        description = state.customMessage ??
            'Food was detected, but no matching nutrition profile is available. Please search our catalog or enter macros manually.';
        actionLabel = 'Search Foods';
        onActionPressed = () => _openFoodSearchModal(context, ref);
        break;
      case NoFoodReason.invalidImage:
        icon = Icons.broken_image_outlined;
        title = 'Unreadable or Invalid Image';
        description = state.customMessage ??
            'The photo was too blurry, dark, or unreadable. Please take a clear, well-lit photo of your meal.';
        break;
      case NoFoodReason.modelUnavailable:
        icon = Icons.memory_outlined;
        title = 'Food Scanner Unavailable';
        description = state.customMessage ??
            'The on-device recognition model could not be initialized or encountered an error. You can search FitFuel foods or try again.';
        actionLabel = 'Retry Scan';
        onActionPressed = () =>
            ref.read(foodScanControllerProvider.notifier).retryScan();
        break;
      case NoFoodReason.emptyResult:
        icon = Icons.no_food_outlined;
        title = 'No Food Detected';
        description = state.customMessage ??
            'We could not clearly identify food items in this image. Try taking another photo with clear lighting.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitFuelEmptyState(
          icon: icon,
          title: title,
          description: description,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
        ),
        const SizedBox(height: AppConstants.spaceSm),
        FitFuelButton(
          label: 'Search Foods',
          icon: Icons.search_rounded,
          type: FitFuelButtonType.secondary,
          onPressed: () => _openFoodSearchModal(context, ref),
        ),
      ],
    );
  }

  Widget _buildErrorState(
      BuildContext context, WidgetRef ref, FoodScanError errorState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDailyQuota =
        errorState.failureType == FoodScanFailureType.dailyQuotaReached;
    final canRetry = errorState.isRetryable && !isDailyQuota;
    final catalog = PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
    final notifier = ref.read(foodScanControllerProvider.notifier);

    IconData errorIcon;
    switch (errorState.failureType) {
      case FoodScanFailureType.offline:
      case FoodScanFailureType.offlineLowConfidence:
        errorIcon = Icons.cloud_off_rounded;
        break;
      case FoodScanFailureType.rateLimited:
        errorIcon = Icons.hourglass_top_rounded;
        break;
      case FoodScanFailureType.dailyQuotaReached:
        errorIcon = Icons.event_busy_rounded;
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
      color:
          isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
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
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.secondaryText,
                ),
            textAlign: TextAlign.center,
          ),
          if (errorState.imagePath != null) ...[
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
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Your photo is saved. Retry without retaking.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          if (errorState.localSuggestions.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceMd),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Possible matches',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            for (final candidate in errorState.localSuggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spaceSm),
                child: OutlinedButton(
                  onPressed: () =>
                      notifier.confirmSuggestion(candidate, catalog: catalog),
                  child: Text(candidate.foodName),
                ),
              ),
          ],
          const SizedBox(height: AppConstants.spaceLg),
          if (canRetry) ...[
            FitFuelButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.read(foodScanControllerProvider.notifier).retryScan(),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () => _openFoodSearchModal(context, ref),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search Foods'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                    double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () =>
                  _onPick(context, ref, FoodImagePickSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Try Another Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                    double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusControl),
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
              label: 'Search Foods',
              icon: Icons.search_rounded,
              onPressed: () => _openFoodSearchModal(context, ref),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () =>
                  _onPick(context, ref, FoodImagePickSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Try Another Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                    double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            TextButton.icon(
              onPressed: () => _openFoodSearchModal(context, ref),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Identify Food Manually'),
            ),
          ] else ...[
            FitFuelButton(
              label: 'Search Foods',
              icon: Icons.search_rounded,
              onPressed: () => _openFoodSearchModal(context, ref),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            OutlinedButton.icon(
              onPressed: () =>
                  _onPick(context, ref, FoodImagePickSource.camera),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: const Text('Try Another Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                    double.infinity, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusControl),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            TextButton.icon(
              onPressed: () => _openFoodSearchModal(context, ref),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Identify Food Manually'),
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
      color:
          isDark ? AppColors.darkPrimaryContainer : AppColors.softBrandSurface,
      padding: const EdgeInsets.all(AppConstants.spaceXl),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 56, color: AppColors.primary),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            'Meal Added to Diary!',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            'Successfully logged ${state.itemsLoggedCount} items (${state.totalCalories.toStringAsFixed(0)} kcal) to ${state.mealType}.',
            style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.secondaryText),
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
            onPressed: () =>
                ref.read(foodScanControllerProvider.notifier).reset(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                  double.infinity, AppConstants.minTouchTargetSize),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusControl)),
            ),
            child: const Text('Scan Another Meal'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddComponentsRow(
    BuildContext context,
    WidgetRef ref,
    FoodScanResult result,
    List<FoodEntity> catalog,
    bool isDark,
  ) {
    final suggestions = <({String label, String id})>[
      (label: 'Dal Tadka', id: 'predefined_dal_tadka'),
      (label: 'Mixed Veg Curry', id: 'predefined_mixed_veg_curry'),
      (label: 'Salad', id: 'predefined_mixed_veg_salad'),
      (label: 'Curd', id: 'predefined_curd'),
      (label: 'Chapati', id: 'predefined_chapati'),
      (label: 'Steamed Rice', id: 'predefined_steamed_rice'),
    ];

    final existingIds = result.foods
        .map((f) => f.matchedFood?.id)
        .whereType<String>()
        .toSet();
    final existingNames = result.foods
        .map((f) => f.displayName.toLowerCase().trim())
        .toSet();

    final available = suggestions.where((s) {
      if (existingIds.contains(s.id)) return false;
      if (existingNames.contains(s.label.toLowerCase())) return false;
      return true;
    }).take(4).toList();

    if (available.isEmpty) return const SizedBox.shrink();

    final notifier = ref.read(foodScanControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(
          top: AppConstants.spaceXs, bottom: AppConstants.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick add meal components:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in available)
                ActionChip(
                  key: Key('chip_quick_add_${item.id}'),
                  avatar: const Icon(Icons.add,
                      size: 14, color: AppColors.primaryLeafGreen),
                  label: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.darkBgSurface
                      : AppColors.primaryLeafGreen.withValues(alpha: 0.08),
                  side: BorderSide(
                    color:
                        AppColors.primaryLeafGreen.withValues(alpha: 0.3),
                  ),
                  onPressed: () {
                    final food = catalog.firstWhere(
                      (f) => f.id == item.id,
                      orElse: () => PredefinedFoodData.foods
                          .firstWhere((m) => m.id == item.id)
                          .toEntity(),
                    );
                    notifier.addComponent(food);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoodPickerSheet extends StatefulWidget {
  final ValueChanged<FoodEntity> onFoodSelected;
  final String? initialQuery;

  const _FoodPickerSheet({
    required this.onFoodSelected,
    this.initialQuery,
  });

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  late final TextEditingController _searchController;
  static final List<FoodEntity> _allCatalogFoods =
      PredefinedFoodData.foods.map((m) => m.toEntity()).toList();
  late List<FoodEntity> _filtered;

  @override
  void initState() {
    super.initState();
    final initQ = widget.initialQuery?.trim() ?? '';
    _searchController = TextEditingController(text: initQ);
    if (initQ.isEmpty) {
      _filtered = _allCatalogFoods;
    } else {
      final strict = FoodSearchEngine.search(
        foods: _allCatalogFoods,
        query: initQ,
      );
      _filtered = strict.isNotEmpty
          ? strict
          : TrustedOpenVocabNutritionMapper.searchCatalogWithRelatedFallback(
              foods: _allCatalogFoods,
              query: initQ,
            );
    }
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _filtered = _allCatalogFoods);
    } else {
      setState(() {
        final strict = FoodSearchEngine.search(
          foods: _allCatalogFoods,
          query: q,
        );
        _filtered = strict.isNotEmpty
            ? strict
            : TrustedOpenVocabNutritionMapper.searchCatalogWithRelatedFallback(
                foods: _allCatalogFoods,
                query: q,
              );
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
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Database Food',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
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
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spaceLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No matching catalog foods found.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            FitFuelButton(
                              key: const Key('btn_picker_manual_entry'),
                              label: 'Enter Food Manually',
                              icon: Icons.edit_note_rounded,
                              type: FitFuelButtonType.secondary,
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(
                                          AppConstants.radiusLg),
                                    ),
                                  ),
                                  builder: (modalCtx) =>
                                      _ManualNutritionEntrySheet(
                                    initialName: _searchController.text.trim(),
                                    onFoodCreated: (newFood) {
                                      Navigator.of(modalCtx).pop();
                                      widget.onFoodSelected(newFood);
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final food = _filtered[index];
                        return ListTile(
                          key: Key('catalog_food_${food.id}'),
                          title: Text(food.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${food.calories.toStringAsFixed(0)} kcal / ${food.servingSize.toStringAsFixed(0)}${food.servingUnit} (P:${food.protein}g C:${food.carbohydrates}g F:${food.fats}g)',
                          ),
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

class _ManualNutritionEntrySheet extends StatefulWidget {
  final String initialName;
  final ValueChanged<FoodEntity> onFoodCreated;

  const _ManualNutritionEntrySheet({
    required this.initialName,
    required this.onFoodCreated,
  });

  @override
  State<_ManualNutritionEntrySheet> createState() =>
      _ManualNutritionEntrySheetState();
}

class _ManualNutritionEntrySheetState
    extends State<_ManualNutritionEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _servingSizeController;
  late final TextEditingController _servingUnitController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _servingSizeController = TextEditingController(text: '100');
    _servingUnitController = TextEditingController(text: 'g');
    _caloriesController = TextEditingController(text: '');
    _proteinController = TextEditingController(text: '');
    _carbsController = TextEditingController(text: '');
    _fatsController = TextEditingController(text: '');
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
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final servingSize =
        double.tryParse(_servingSizeController.text.trim()) ?? 100.0;
    final servingUnit = _servingUnitController.text.trim().isEmpty
        ? 'g'
        : _servingUnitController.text.trim();
    final calories = double.tryParse(_caloriesController.text.trim()) ?? 0.0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final fats = double.tryParse(_fatsController.text.trim()) ?? 0.0;

    final manualFood = FoodEntity(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: 'Manual Entry',
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      protein: protein,
      carbohydrates: carbs,
      fats: fats,
      fiber: 0.0,
      sugar: 0.0,
      sodium: 0.0,
      isCustom: true,
    );

    widget.onFoodCreated(manualFood);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppConstants.spaceMd,
        right: AppConstants.spaceMd,
        top: AppConstants.spaceMd,
      ),
      child: SafeArea(
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
                    const Text(
                      'Enter Nutrition Manually',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                TextFormField(
                  key: const Key('input_manual_food_name'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Food Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter food name' : null,
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: const Key('input_manual_portion_size'),
                        controller: _servingSizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Portion Size',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid portion';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        key: const Key('input_manual_portion_unit'),
                        controller: _servingUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('input_manual_calories'),
                        controller: _caloriesController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        key: const Key('input_manual_protein'),
                        controller: _proteinController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('input_manual_carbs'),
                        controller: _carbsController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSm),
                    Expanded(
                      child: TextFormField(
                        key: const Key('input_manual_fats'),
                        controller: _fatsController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                FitFuelButton(
                  key: const Key('btn_submit_manual_nutrition'),
                  label: 'Confirm & Apply Nutrition',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppConstants.spaceMd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
