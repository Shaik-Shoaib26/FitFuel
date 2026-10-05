import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Main Today's Nutrition card matching Option B approved reference:
/// - Header: "Today's Nutrition", subtext: "$consumed of $target kcal", action: "View details >"
/// - Left: Large circular calorie ring with flame icon, remaining kcal, and "kcal remaining".
/// - Right: Stacked macro metrics (Protein, Carbs, Fat) with circular semantic badges and progress bars.
/// - Botanical leaf decoration subtly positioned on the left edge.
class NutritionSummaryCard extends StatelessWidget {
  final double totalCalories;
  final double calorieTarget;
  final double totalProtein;
  final double proteinTarget;
  final double totalCarbs;
  final double carbsTarget;
  final double totalFat;
  final double fatTarget;
  final VoidCallback? onViewDetails;

  const NutritionSummaryCard({
    super.key,
    required this.totalCalories,
    required this.calorieTarget,
    required this.totalProtein,
    required this.proteinTarget,
    required this.totalCarbs,
    required this.carbsTarget,
    required this.totalFat,
    required this.fatTarget,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasTarget = calorieTarget > 0;
    final remaining = hasTarget ? (calorieTarget - totalCalories) : 0.0;
    final isOverTarget = hasTarget && totalCalories > calorieTarget;
    final calorieProgress = hasTarget
        ? (totalCalories / calorieTarget).clamp(0.0, 1.0)
        : 0.0;

    final subtext = hasTarget
        ? '${totalCalories.toStringAsFixed(0)} of ${calorieTarget.toStringAsFixed(0)} kcal'
        : '${totalCalories.toStringAsFixed(0)} kcal logged';

    final remainingFormatted = isOverTarget
        ? '+${(totalCalories - calorieTarget).toStringAsFixed(0)}'
        : remaining.clamp(0.0, double.infinity).toStringAsFixed(0);

    final remainingLabel = isOverTarget ? 'kcal over' : 'kcal remaining';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ─── BOTANICAL LEAF ACCENT ON LEFT EDGE ───────────────────────────
        Positioned(
          left: -18,
          bottom: 12,
          width: 60,
          height: 100,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.4 : 0.85,
              child: Image.asset(
                'assets/decorations/nutrition_leaf_left.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),

        // ─── MAIN WHITE CARD CONTAINER ───────────────────────────────────
        Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
              width: 1,
            ),
          ),
          elevation: isDark ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── HEADER ROW ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Today's Nutrition",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 17.5,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtext,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
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
                        alignment: Alignment.topRight,
                        child: Semantics(
                          button: true,
                          label: 'View nutrition details',
                          child: InkWell(
                            onTap: onViewDetails,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View details',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryLeafGreen,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppColors.primaryLeafGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ─── CALORIE RING + MACROS LAYOUT ─────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isCompact = width < 320;

                    final ringWidget = _NutritionCalorieRing(
                      progress: calorieProgress,
                      remainingValue: remainingFormatted,
                      remainingLabel: remainingLabel,
                      isDark: isDark,
                      size: isCompact ? 135.0 : 145.0,
                    );

                    final macrosWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MacroRow(
                          label: 'Protein',
                          currentGrams: totalProtein,
                          targetGrams: proteinTarget,
                          color: AppColors.proteinGreen,
                          icon: Icons.fitness_center_rounded,
                          iconBg: const Color(0xFFE8F8F0),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _MacroRow(
                          label: 'Carbs',
                          currentGrams: totalCarbs,
                          targetGrams: carbsTarget,
                          color: AppColors.carbsAmber,
                          icon: Icons.grain_rounded,
                          iconBg: const Color(0xFFFEF7EB),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _MacroRow(
                          label: 'Fat',
                          currentGrams: totalFat,
                          targetGrams: fatTarget,
                          color: AppColors.fatOrange,
                          icon: Icons.water_drop_rounded,
                          iconBg: const Color(0xFFFEF5E7),
                          isDark: isDark,
                        ),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          ringWidget,
                          const SizedBox(height: 16),
                          macrosWidget,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: width * 0.45,
                          child: Center(child: ringWidget),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: macrosWidget),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular calorie ring matching Option B with flame icon in center.
class _NutritionCalorieRing extends StatelessWidget {
  final double progress;
  final String remainingValue;
  final String remainingLabel;
  final bool isDark;
  final double size;

  const _NutritionCalorieRing({
    required this.progress,
    required this.remainingValue,
    required this.remainingLabel,
    required this.isDark,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CalorieRingPainter(
              progress: progress,
              trackColor: isDark
                  ? const Color(0xFF233529)
                  : AppColors.paleGreenTrack,
              progressColor: AppColors.primaryLeafGreen,
              strokeWidth: 11,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flame icon
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.calorieOrange,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  // Remaining number
                  Text(
                    remainingValue,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // kcal remaining
                  Text(
                    remainingLabel,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w400,
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      final activePaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Start from top (-pi / 2)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

/// Macro metric row with circle icon, label, current/target, and progress bar.
class _MacroRow extends StatelessWidget {
  final String label;
  final double currentGrams;
  final double targetGrams;
  final Color color;
  final IconData icon;
  final Color iconBg;
  final bool isDark;

  const _MacroRow({
    required this.label,
    required this.currentGrams,
    required this.targetGrams,
    required this.color,
    required this.icon,
    required this.iconBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = targetGrams > 0;
    final progress = hasTarget
        ? (currentGrams / targetGrams).clamp(0.0, 1.0)
        : 0.0;
    final gramsText = hasTarget
        ? '${currentGrams.toStringAsFixed(0)} / ${targetGrams.toStringAsFixed(0)} g'
        : '${currentGrams.toStringAsFixed(0)} g';

    final trackBg = isDark
        ? const Color(0xFF26332A)
        : const Color(0xFFEDF2EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Circular icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.2) : iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 13, color: color),
              ),
            ),
            const SizedBox(width: 8),
            // Label
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Grams
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  gramsText,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: trackBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
