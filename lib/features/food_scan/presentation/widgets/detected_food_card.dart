import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_photo.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';
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
                        ScanConfidenceChip(level: candidate.confidenceLevel),
                      ],
                    ),
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

          // Low Confidence warning banner if recognition is weak
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
        ],
      ),
    );
  }

  Widget _sourceChip(bool isDark) {
    if (candidate.isDatabaseMatch) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.stateSuccess.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(color: AppColors.stateSuccess.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.stateSuccess),
            SizedBox(width: 4),
            Text(
              'Database Match',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.stateSuccess,
              ),
            ),
          ],
        ),
      );
    }

    if (candidate.isAiEstimated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.stateWarning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(color: AppColors.stateWarning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.stateWarning),
            const SizedBox(width: 4),
            Text(
              'AI Estimate • Needs confirmation',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.amber.shade200 : AppColors.stateWarning,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.stateError.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.stateError.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline_rounded, size: 12, color: AppColors.stateError),
          SizedBox(width: 4),
          Text(
            'Needs confirmation',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.stateError,
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
}
