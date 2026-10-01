import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/theme/fitfuel_semantic_colors.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../progress/domain/entities/progress_summary_entity.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';

/// Weight entry + trend panel. Entry validation, persistence and the chart
/// series are unchanged; only the presentation uses theme surfaces now.
class WeightPanel extends ConsumerStatefulWidget {
  final String uid;
  final ProgressSummaryEntity summary;
  final List<dynamic> history;
  final bool showEntry;
  const WeightPanel(
      {super.key,
      required this.uid,
      required this.summary,
      required this.history,
      this.showEntry = true});
  @override
  ConsumerState<WeightPanel> createState() => _WeightPanelState();
}

class _WeightPanelState extends ConsumerState<WeightPanel> {
  final TextEditingController _weightInputController = TextEditingController();

  @override
  void dispose() {
    _weightInputController.dispose();
    super.dispose();
  }

  void _submitWeight(String uid) async {
    if (ref.read(networkStatusProvider).value == NetworkStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Internet connection is required for this action.')));
      return;
    }
    final text = _weightInputController.text.trim();
    if (text.isEmpty) return;
    final double? weightVal = double.tryParse(text);
    if (weightVal == null || weightVal <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in kg.')),
      );
      return;
    }

    final success = await ref
        .read(progressControllerProvider.notifier)
        .logWeight(uid, weightVal);
    if (mounted) {
      if (success) {
        _weightInputController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight logged successfully!')),
        );
      } else {
        final state = ref.read(progressControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to log weight: ${state.saveError ?? 'Unknown error'}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _buildWeightSection(
      widget.uid, widget.summary, widget.history);

  Widget _buildWeightSection(String uid, ProgressSummaryEntity summary,
      List<dynamic> weightHistory) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = FitFuelSemanticColors.of(context);
    final Color changeColor =
        summary.weightChange <= 0 ? semantic.success : scheme.error;
    final prefix = summary.weightChange > 0 ? '+' : '';

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Body weight tracker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Weight Tracker',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppConstants.spaceMd),

          // One shared weight-entry implementation, exposed only in Health.
          if (widget.showEntry)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightInputController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Log today's weight (kg)",
                      hintText: 'e.g. 75.5',
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                SizedBox(
                  width: 96,
                  child: ElevatedButton(
                    onPressed:
                        ref.watch(progressControllerProvider).isSavingWeight
                            ? null
                            : () => _submitWeight(uid),
                    child: const Text('Log'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppConstants.spaceMd),

          if (weightHistory.isEmpty)
            Text(
              'Add your first weight measurement to start tracking progress.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              const spacing = AppConstants.spaceSmd;
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _buildMetricTile(
                      'Starting Weight',
                      '${summary.startingWeight.toStringAsFixed(1)} kg',
                      scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildMetricTile(
                      'Current Weight',
                      '${summary.currentWeight.toStringAsFixed(1)} kg',
                      scheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildMetricTile(
                      'Total Change',
                      '$prefix${summary.weightChange.toStringAsFixed(1)} kg ($prefix${summary.weightChangePercent.toStringAsFixed(1)}%)',
                      changeColor,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: AppConstants.spaceMd),
            Text(
              'Fitness Goal: ${summary.weightGoalDirection}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppConstants.spaceMd),

            // fl_chart trend lines (series and calculations unchanged).
            if (weightHistory.length >= 2) ...[
              Text(
                'Weight Trend Line',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppConstants.spaceSm),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: scheme.outlineVariant)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: () {
                          final List<FlSpot> spots = [];
                          final list = List<dynamic>.from(weightHistory)
                            ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
                          for (int i = 0; i < list.length; i++) {
                            spots.add(
                                FlSpot(i.toDouble(), list[i].weight.toDouble()));
                          }
                          return spots;
                        }(),
                        isCurved: true,
                        color: scheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceSmd),
      decoration: BoxDecoration(
        color: Color.alphaBlend(valueColor.withValues(alpha: .08), scheme.surface),
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
                ?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
