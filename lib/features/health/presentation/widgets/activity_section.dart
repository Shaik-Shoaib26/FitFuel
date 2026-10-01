import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../domain/entities/exercise_entity.dart';

/// Activity shows only what the health record actually stores: logged
/// sessions, their durations and the calories the user entered with them.
class ActivitySection extends StatelessWidget {
  final List<ExerciseEntity> exercises;
  final VoidCallback onAdd;

  const ActivitySection({
    super.key,
    required this.exercises,
    required this.onAdd,
  });

  int get _totalMinutes =>
      exercises.fold<int>(0, (sum, exercise) => sum + exercise.duration);

  double get _totalBurned =>
      exercises.fold<double>(0, (sum, exercise) => sum + exercise.caloriesBurned);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const accent = AppColors.exercise;

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMlg),
      semanticsLabel: 'Activity tracker',
      child: exercises.isEmpty
          ? _EmptyActivity(onAdd: onAdd, accent: accent)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.timer_outlined,
                        color: accent,
                        label: 'Active time',
                        value: '$_totalMinutes min',
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceSmd),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.local_fire_department_outlined,
                        color: AppColors.calories,
                        label: 'Calories burned',
                        value: '${_totalBurned.toStringAsFixed(0)} kcal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Text(
                  exercises.length == 1
                      ? '1 session logged today'
                      : '${exercises.length} sessions logged today',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                for (var i = 0; i < exercises.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: AppConstants.spaceMd,
                        color: scheme.outlineVariant),
                  _ExerciseRow(exercise: exercises[i], accent: accent),
                ],
              ],
            ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseEntity exercise;
  final Color accent;
  const _ExerciseRow({required this.exercise, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label:
          '${exercise.activity}, ${exercise.duration} minutes, ${exercise.caloriesBurned.toStringAsFixed(0)} calories',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Color.alphaBlend(
                    accent.withValues(alpha: .14), scheme.surface),
                shape: BoxShape.circle),
            child: Icon(Icons.fitness_center, size: 16, color: accent),
          ),
          const SizedBox(width: AppConstants.spaceSmd),
          Expanded(
            child: Text(
              exercise.activity,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Text(
            '${exercise.duration} min · ${exercise.caloriesBurned.toStringAsFixed(0)} kcal',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _StatBox({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppConstants.space2Xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  final VoidCallback onAdd;
  final Color accent;
  const _EmptyActivity({required this.onAdd, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      accent.withValues(alpha: .14), scheme.surface),
                  shape: BoxShape.circle),
              child: Icon(Icons.directions_run_outlined,
                  size: 22, color: accent),
            ),
            const SizedBox(width: AppConstants.spaceSmd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No exercise logged today',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppConstants.space2Xs),
                  Text(
                    'Log a workout to track your active minutes.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceMd),
        FitFuelButton(
          label: 'Log activity',
          icon: Icons.add,
          type: FitFuelButtonType.secondary,
          width: 200,
          onPressed: onAdd,
        ),
      ],
    );
  }
}
