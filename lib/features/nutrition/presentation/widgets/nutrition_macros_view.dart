import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/utils/nutrition_calculator.dart';

/// Clean editorial view for the "Macros" tab in Option B.
class NutritionMacrosView extends StatelessWidget {
  final List<NutritionRecordEntity> records;
  final NutritionGoalsEntity? goals;
  final VoidCallback onAdjustGoals;

  const NutritionMacrosView({
    super.key,
    required this.records,
    required this.goals,
    required this.onAdjustGoals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totals = NutritionCalculator.calculateProgress(
      dailyRecords: records,
      goals: goals,
    );

    final totalMacrosGrams = totals.totalProtein + totals.totalCarbs + totals.totalFats;
    final pPct = totalMacrosGrams > 0 ? (totals.totalProtein / totalMacrosGrams * 100).round() : 0;
    final cPct = totalMacrosGrams > 0 ? (totals.totalCarbs / totalMacrosGrams * 100).round() : 0;
    final fPct = totalMacrosGrams > 0 ? (totals.totalFats / totalMacrosGrams * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ratio Distribution Card
        Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Macronutrient Ratio',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onAdjustGoals,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primaryLeafGreen,
                          ),
                          child: const Text('Adjust Goals'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Ratio bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: totalMacrosGrams == 0
                        ? Container(color: AppColors.paleGreenTrack)
                        : Row(
                            children: [
                              if (pPct > 0)
                                Expanded(
                                  flex: pPct,
                                  child: Container(color: AppColors.proteinGreen),
                                ),
                              if (cPct > 0)
                                Expanded(
                                  flex: cPct,
                                  child: Container(color: AppColors.carbsAmber),
                                ),
                              if (fPct > 0)
                                Expanded(
                                  flex: fPct,
                                  child: Container(color: AppColors.fatOrange),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _MacroRatioLegend(
                          color: AppColors.proteinGreen,
                          label: 'Protein',
                          pct: '$pPct%',
                          grams: '${totals.totalProtein.toStringAsFixed(0)}g',
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _MacroRatioLegend(
                          color: AppColors.carbsAmber,
                          label: 'Carbs',
                          pct: '$cPct%',
                          grams: '${totals.totalCarbs.toStringAsFixed(0)}g',
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _MacroRatioLegend(
                          color: AppColors.fatOrange,
                          label: 'Fat',
                          pct: '$fPct%',
                          grams: '${totals.totalFats.toStringAsFixed(0)}g',
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Target vs Consumed Breakdown
        _MacroDetailCard(
          title: 'Protein',
          subtitle: 'Essential for muscle repair & satiety',
          current: totals.totalProtein,
          target: goals?.proteinTargetGrams ?? 0,
          color: AppColors.proteinGreen,
          icon: Icons.fitness_center_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _MacroDetailCard(
          title: 'Carbohydrates',
          subtitle: 'Primary source of cellular energy',
          current: totals.totalCarbs,
          target: goals?.carbsTargetGrams ?? 0,
          color: AppColors.carbsAmber,
          icon: Icons.grain_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _MacroDetailCard(
          title: 'Fats',
          subtitle: 'Hormone balance & nutrient absorption',
          current: totals.totalFats,
          target: goals?.fatTargetGrams ?? 0,
          color: AppColors.fatOrange,
          icon: Icons.water_drop_rounded,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _MacroRatioLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String pct;
  final String grams;
  final bool isDark;

  const _MacroRatioLegend({
    required this.color,
    required this.label,
    required this.pct,
    required this.grams,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$pct ($grams)',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _MacroDetailCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double current;
  final double target;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _MacroDetailCard({
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = target > 0;
    final progress = hasTarget ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = hasTarget ? (target - current) : 0.0;

    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      hasTarget
                          ? '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}g'
                          : '${current.toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark
                    ? const Color(0xFF26332A)
                    : const Color(0xFFEDF2EE),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (hasTarget) ...[
              const SizedBox(height: 6),
              Text(
                remaining > 0
                    ? '${remaining.toStringAsFixed(0)}g remaining today'
                    : 'Target reached!',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.secondaryText,
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
