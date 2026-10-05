import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Reference-accurate Option A Daily Macro Summary Cards.
/// Three compact side-by-side cards for Protein, Carbs, and Fat showing planned / target.
class PlanMacroSummary extends StatelessWidget {
  final double plannedProtein;
  final double targetProtein;
  final double plannedCarbs;
  final double targetCarbs;
  final double plannedFat;
  final double targetFat;

  const PlanMacroSummary({
    super.key,
    required this.plannedProtein,
    required this.targetProtein,
    required this.plannedCarbs,
    required this.targetCarbs,
    required this.plannedFat,
    required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMacroCard(
            context: context,
            label: 'Protein',
            planned: plannedProtein,
            target: targetProtein,
            accentColor: AppColors.protein,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMacroCard(
            context: context,
            label: 'Carbs',
            planned: plannedCarbs,
            target: targetCarbs,
            accentColor: AppColors.carbs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMacroCard(
            context: context,
            label: 'Fat',
            planned: plannedFat,
            target: targetFat,
            accentColor: AppColors.fat,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required BuildContext context,
    required String label,
    required double planned,
    required double target,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratio = target > 0 ? (planned / target).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: '$label: ${planned.round()} of ${target.round()} grams planned',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFDDE7DF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF657169),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${planned.round()} / ${target.round()} g',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF17231D),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: accentColor.withValues(alpha: isDark ? 0.2 : 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
