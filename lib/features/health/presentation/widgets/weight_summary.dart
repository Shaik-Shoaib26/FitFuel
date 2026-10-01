import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../progress/domain/entities/progress_summary_entity.dart';
import '../../../progress/domain/entities/weight_record_entity.dart';

/// Weight entry point inside Health. Trend values come from the same
/// ProgressCalculator summary the Weight page already uses, so the two never
/// disagree.
class WeightSummarySection extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<WeightRecordEntity> history;
  final ProgressSummaryEntity? summary;
  final VoidCallback onViewWeight, onRetry;

  const WeightSummarySection({
    super.key,
    required this.loading,
    required this.history,
    required this.summary,
    required this.onViewWeight,
    required this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (loading) {
      return const FitFuelCard(
        child: FitFuelLoadingState(
            label: 'Loading your weight history', indicatorSize: 20),
      );
    }

    // A failed weight stream must not look like "no weight history yet".
    if (error != null) {
      return SizedBox(
        height: 280,
        child: FitFuelErrorState(error: error, onRetry: onRetry),
      );
    }

    final data = summary;
    if (history.isEmpty || data == null) {
      // Bounded so the empty state can scroll safely inside the page column.
      return SizedBox(
        height: 260,
        child: FitFuelEmptyState(
          icon: Icons.monitor_weight_outlined,
          title: 'No weight history yet',
          description:
              'Track your weight to see your trend over time.',
          actionLabel: 'Add weight',
          onActionPressed: onViewWeight,
        ),
      );
    }

    final change = data.weightChange;
    final changePrefix = change > 0 ? '+' : '';
    final changeColor =
        change <= 0 ? FitFuelSemanticColors.of(context).success : scheme.error;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Weight summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            const spacing = AppConstants.spaceSmd;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final tiles = <Widget>[
              _WeightTile(
                label: 'Current',
                value: '${data.currentWeight.toStringAsFixed(1)} kg',
                color: scheme.primary,
              ),
              _WeightTile(
                label: 'Starting',
                value: '${data.startingWeight.toStringAsFixed(1)} kg',
                color: scheme.onSurfaceVariant,
              ),
              _WeightTile(
                label: 'Change',
                value:
                    '$changePrefix${change.toStringAsFixed(1)} kg',
                color: changeColor,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tile in tiles)
                  SizedBox(width: tileWidth, child: tile),
              ],
            );
          }),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  'Fitness goal: ${data.weightGoalDirection}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          FitFuelButton(
            label: 'View weight',
            icon: Icons.monitor_weight_outlined,
            type: FitFuelButtonType.secondary,
            onPressed: onViewWeight,
            semanticsLabel: 'View weight history',
          ),
        ],
      ),
    );
  }
}

class _WeightTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _WeightTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSmd),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .08), scheme.surface),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppConstants.space2Xs),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
