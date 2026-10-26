import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_photo.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
import 'package:fitfuel/features/food_scan/domain/entities/food_scan_recognition_source.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/presentation/widgets/scan_confidence_chip.dart';

class DetectedFoodCard extends StatelessWidget {
  final DetectedFoodCandidate candidate;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onChangeFood;
  final VoidCallback onRemove;

  const DetectedFoodCard({
    super.key,
    required this.candidate,
    required this.onAmountChanged,
    required this.onChangeFood,
    required this.onRemove,
  });

  void _showPortionDialog(BuildContext context) {
    final controller =
        TextEditingController(text: candidate.estimatedAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust ${candidate.displayName} Portion'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Portion (${candidate.estimatedUnit})',
            suffixText: candidate.estimatedUnit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                onAmountChanged(val);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    debugPrint(
      '[NutritionValues] name="${candidate.displayName}" '
      'cal=${candidate.calories != null ? candidate.scaledCalories.toStringAsFixed(0) : "null"} '
      'p=${candidate.protein != null ? candidate.scaledProtein.toStringAsFixed(1) : "null"} '
      'c=${candidate.carbs != null ? candidate.scaledCarbs.toStringAsFixed(1) : "null"} '
      'f=${candidate.fats != null ? candidate.scaledFats.toStringAsFixed(1) : "null"} '
      'basis=${candidate.estimatedAmount}${candidate.estimatedUnit}',
    );

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food photo or branded fallback (20px radius per Fresh Green spec)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FitFuelFoodPhoto(
                  source: candidate.matchedFood?.imageAsset ?? '',
                  description: candidate.displayName,
                  width: 60,
                  height: 60,
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (candidate.matchedFood != null &&
                        candidate.matchedFood!.name.toLowerCase() !=
                            candidate.detectedName.toLowerCase()) ...[
                       const SizedBox(height: 2),
                      Text(
                        'Detected: ${candidate.detectedName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _sourceChip(isDark),
                        if (!candidate.isConfirmedByUser)
                          ScanConfidenceChip(level: candidate.confidenceLevel),
                      ],
                    ),
                    if (candidate.nutritionAttribution != null &&
                        candidate.nutritionAttribution!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        candidate.nutritionAttribution!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                    if (candidate.recipeAssumptions != null &&
                        candidate.recipeAssumptions!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Assumptions: ${candidate.recipeAssumptions}',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Remove item',
                onPressed: onRemove,
              ),
            ],
          ),

          // Low Confidence warning banner if recognition is weak and unconfirmed
          if (candidate.isLowConfidence) ...[
            const SizedBox(height: AppConstants.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stateWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.stateWarning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.stateWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "We're not confident about this food.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber.shade200 : AppColors.stateWarning,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onChangeFood,
                    child: const Text(
                      'Search Food',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Explicit Missing Nutrition Banner (Phase 35.13.0 Section 4)
          if (!candidate.hasNutrition) ...[
            const SizedBox(height: AppConstants.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stateWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.stateWarning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.stateWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nutrition profile requires selection before diary logging.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber.shade200 : AppColors.stateWarning,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onChangeFood,
                    child: const Text(
                      'Select Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppConstants.spaceMd),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.spaceMd),

          // Portion size controls and nutrition stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Portion stepper
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    tooltip: 'Decrease portion',
                    onPressed: candidate.estimatedAmount > 10
                        ? () => onAmountChanged(
                            (candidate.estimatedAmount - 20).clamp(5.0, 2500.0))
                        : null,
                  ),
                  InkWell(
                    onTap: () => _showPortionDialog(context),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '${candidate.estimatedAmount.toStringAsFixed(0)} ${candidate.estimatedUnit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    tooltip: 'Increase portion',
                    onPressed: () => onAmountChanged(
                        (candidate.estimatedAmount + 20).clamp(5.0, 2500.0)),
                  ),
                ],
              ),

              // Calories
              Text(
                candidate.calories != null
                    ? '${candidate.scaledCalories.toStringAsFixed(0)} kcal'
                    : '— kcal',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryLeafGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceSm),

          // Macros row + Change button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _macroBadge(
                    'P',
                    candidate.protein != null
                        ? '${candidate.scaledProtein.toStringAsFixed(1)} g'
                        : '—',
                    AppColors.protein,
                  ),
                  _macroBadge(
                    'C',
                    candidate.carbs != null
                        ? '${candidate.scaledCarbs.toStringAsFixed(1)} g'
                        : '—',
                    AppColors.carbs,
                  ),
                  _macroBadge(
                    'F',
                    candidate.fats != null
                        ? '${candidate.scaledFats.toStringAsFixed(1)} g'
                        : '—',
                    AppColors.fat,
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onChangeFood,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change Food'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),

          // Trusted secondary nutrition fields (Fiber, Sugar, Sodium) when available
          if (candidate.hasSecondaryNutrition) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (candidate.fiber != null)
                  _secondaryNutrientPill(
                    'Fiber',
                    '${candidate.fiber!.toStringAsFixed(1)}g',
                    isDark,
                  ),
                if (candidate.sugar != null)
                  _secondaryNutrientPill(
                    'Sugar',
                    '${candidate.sugar!.toStringAsFixed(1)}g',
                    isDark,
                  ),
                if (candidate.sodium != null)
                  _secondaryNutrientPill(
                    'Sodium',
                    '${candidate.sodium!.toStringAsFixed(0)}mg',
                    isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceChip(bool isDark) {
    Color chipColor;
    IconData icon;
    String label = candidate.nutritionSourceLabel;

    if (candidate.recognitionSource == FoodScanRecognitionSource.manual) {
      chipColor = Colors.teal;
      icon = Icons.person_add_rounded;
      label = 'Added by you';
    } else if (candidate.isUserEnteredNutrition) {
      chipColor = Colors.purple;
      icon = Icons.edit_note_rounded;
      label = 'User-entered nutrition';
    } else {
      switch (candidate.nutritionTier) {
        case NutritionProfileTier.verifiedExact:
          chipColor = AppColors.stateSuccess;
          icon = Icons.verified_rounded;
          label = 'Database Match';
          break;
        case NutritionProfileTier.closelyRelatedGeneric:
          chipColor = Colors.blue;
          icon = Icons.menu_book_rounded;
          final isUsda = candidate.nutritionAttribution != null &&
              (candidate.nutritionAttribution!.contains('USDA') ||
                  candidate.nutritionAttribution!
                      .contains('Department of Agriculture'));
          label = isUsda
              ? 'USDA Generic Baseline'
              : 'Generic Nutrition Baseline';
          break;
        case NutritionProfileTier.recipeEstimate:
          chipColor = AppColors.stateWarning;
          icon = Icons.soup_kitchen_rounded;
          label = 'Recipe Estimate';
          break;
        case NutritionProfileTier.unavailable:
          chipColor = AppColors.stateError;
          icon = Icons.help_outline_rounded;
          label = 'Nutrition Unavailable';
          break;
        case null:
          if (candidate.isDatabaseMatch) {
            chipColor = AppColors.stateSuccess;
            icon = Icons.check_circle_outline_rounded;
            label = 'Database Match';
          } else if (candidate.isAiEstimated) {
            chipColor = AppColors.stateWarning;
            icon = Icons.auto_awesome_rounded;
            label = 'AI Estimate • Needs confirmation';
          } else {
            chipColor = AppColors.stateError;
            icon = Icons.help_outline_rounded;
            label = 'Needs confirmation';
          }
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark && chipColor == AppColors.stateWarning
                    ? Colors.amber.shade200
                    : chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _secondaryNutrientPill(String label, String value, bool isDark) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
      ),
    );
  }
}
