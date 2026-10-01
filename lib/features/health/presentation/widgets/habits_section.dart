import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_linear_progress.dart';

/// Habits: completion is communicated by a check control plus explicit
/// Completed / Not yet text, so status never depends on color alone.
class HabitsSection extends StatelessWidget {
  final Map<String, bool> habits;
  final void Function(String habitName, bool completed) onToggle;

  const HabitsSection({
    super.key,
    required this.habits,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (habits.isEmpty) {
      return FitFuelCard(
        padding: const EdgeInsets.all(AppConstants.spaceMlg),
        semanticsLabel: 'Habits checklist',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      AppColors.habits.withValues(alpha: .14), scheme.surface),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  size: 22, color: AppColors.habits),
            ),
            const SizedBox(width: AppConstants.spaceSmd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No habits configured yet',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppConstants.space2Xs),
                  Text(
                    'Your daily habit checklist will appear here once habits exist.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final total = habits.length;
    final done = habits.values.where((value) => value).length;
    final ratio = total > 0 ? done / total : 0.0;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Habits checklist: $done of $total complete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FitFuelLinearProgress(
            value: ratio,
            label: 'Completed today',
            valueLabel: '$done / $total',
            progressColor: AppColors.habits,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          for (final entry in habits.entries)
            CheckboxListTile(
              value: entry.value,
              onChanged: (value) {
                if (value != null) onToggle(entry.key, value);
              },
              title: Text(
                entry.key,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entry.value ? 'Completed' : 'Not yet',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: scheme.primary,
              checkColor: scheme.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
