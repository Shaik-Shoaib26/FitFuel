import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/progress_summary_entity.dart';

/// Overall Wellness Score Card matching Option A:
/// - Header: "Overall Wellness Score (i)" + "View details >"
/// - Left: Circular progress gauge with leaf icon, score, and "of 100"
/// - Right: Category progress rows for Nutrition, Hydration, Activity, Habits
class WellnessScoreCard extends StatelessWidget {
  final ProgressSummaryEntity summary;

  const WellnessScoreCard({
    super.key,
    required this.summary,
  });

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, color: AppColors.primaryLeafGreen),
            SizedBox(width: 8),
            Text(
              'Wellness Score',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your Overall Wellness Score (0–100) is a weighted calculation reflecting your nutrition target adherence, hydration consistency, active exercise minutes, and daily habit completion over the selected time range.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: AppColors.primaryLeafGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final overallScore = summary.wellnessAvgScore.clamp(0.0, 100.0).round();
    final nutritionScore = summary.calorieAdherencePercent.clamp(0.0, 100.0).round();
    final hydrationScore = summary.waterConsistencyPercent.clamp(0.0, 100.0).round();
    final activityScore = summary.exerciseConsistencyPercent.clamp(0.0, 100.0).round();
    final habitsScore = summary.habitsAvgCompletionRate.clamp(0.0, 100.0).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Overall Wellness Score',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryText,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.secondaryText,
                      ),
                      tooltip: 'Wellness score info',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _showInfoDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 2,
                child: InkWell(
                  onTap: () => context.go('/progress/analytics'),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'View details',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLeafGreen,
                            ),
                          ),
                        ),
                        SizedBox(width: 2),
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
            ],
          ),
          const SizedBox(height: 18),

          // Content Row: Gauge (Left) + 4 Metrics (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Ring Gauge
              SizedBox(
                width: 124,
                height: 124,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(124, 124),
                      painter: _ScoreGaugePainter(
                        progress: overallScore / 100.0,
                        trackColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.paleGreenTrack,
                        progressColor: AppColors.primaryLeafGreen,
                        strokeWidth: 11.0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          size: 18,
                          color: AppColors.primaryLeafGreen,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$overallScore',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.primaryText,
                            height: 1.0,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'of 100',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Category Progress Bars
              Expanded(
                child: Column(
                  children: [
                    _buildCategoryRow(
                      isDark: isDark,
                      icon: Icons.eco_rounded,
                      iconColor: const Color(0xFF22C55E),
                      label: 'Nutrition',
                      score: nutritionScore,
                      barColor: const Color(0xFF22C55E),
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryRow(
                      isDark: isDark,
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Hydration',
                      score: hydrationScore,
                      barColor: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryRow(
                      isDark: isDark,
                      icon: Icons.directions_run_rounded,
                      iconColor: const Color(0xFFF97316),
                      label: 'Activity',
                      score: activityScore,
                      barColor: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryRow(
                      isDark: isDark,
                      icon: Icons.directions_walk_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: 'Habits',
                      score: habitsScore,
                      barColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required int score,
    required Color barColor,
  }) {
    final trackColor = isDark
        ? AppColors.darkBorder
        : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.primaryText,
                ),
              ),
            ),
            Text(
              '$score',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5.5,
            color: trackColor,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (score / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ScoreGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw full background circle
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc starting from top (-pi / 2)
    const startAngle = -math.pi / 2;
    final sweepAngle = (2 * math.pi * progress.clamp(0.0, 1.0));

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
