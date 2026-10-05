import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Asymmetric Editorial "Today's Health" Grid (Phase 35.6.3).
/// Matches Option C approved reference:
/// - Left side (~48-50%): Large Water hero card with live value, progress bar,
///   supportive copy, and translucent fluid wave / water droplet.
/// - Right side (~50-52%): Three stacked compact cards:
///   1. Exercise (pale orange #FFF6EF, running person, active min, sneaker decoration)
///   2. Habits (soft green #F0F8F2, checkmark, done/total, botanical leaf decoration)
///   3. Wellness (soft sage #EFF8F2, heart, dynamic score, zen stones decoration)
class HealthTodayGrid extends StatelessWidget {
  final String waterValue;
  final double waterProgress;
  final int exerciseMinutes;
  final int habitsDone;
  final int habitsTotal;
  final double wellnessScore;
  final ValueChanged<String> onSelectSection;

  const HealthTodayGrid({
    super.key,
    required this.waterValue,
    required this.waterProgress,
    required this.exerciseMinutes,
    required this.habitsDone,
    required this.habitsTotal,
    required this.wellnessScore,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 310;
        final habitsLabel = habitsTotal == 0 ? '—' : '$habitsDone / $habitsTotal';
        final wellnessLabel = wellnessScore.round().toString();

        if (isVeryNarrow) {
          // Narrow mobile fallback to avoid overflow
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LargeWaterCard(
                waterValue: waterValue,
                waterProgress: waterProgress,
                onTap: () => onSelectSection('hydration'),
              ),
              const SizedBox(height: 12),
              _CompactHealthCard(
                title: 'Exercise',
                value: '$exerciseMinutes min',
                icon: Icons.directions_run_rounded,
                iconColor: AppColors.exercise,
                iconBg: const Color(0xFFFFEADB),
                surfaceColor: AppColors.exerciseCardSurface,
                decorationAsset: 'assets/decorations/health_sneaker.webp',
                onTap: () => onSelectSection('exercise'),
              ),
              const SizedBox(height: 10),
              _CompactHealthCard(
                title: 'Habits',
                value: habitsLabel,
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.habitGreen,
                iconBg: const Color(0xFFDCFCE7),
                surfaceColor: AppColors.habitsCardSurface,
                decorationAsset: 'assets/decorations/health_habits_leaf.webp',
                onTap: () => onSelectSection('habits'),
              ),
              const SizedBox(height: 10),
              _CompactHealthCard(
                title: 'Wellness',
                value: wellnessLabel,
                icon: Icons.favorite_outline_rounded,
                iconColor: AppColors.wellnessTeal,
                iconBg: const Color(0xFFE2F7EB),
                surfaceColor: AppColors.wellnessCardSurface,
                decorationAsset: 'assets/decorations/health_zen_stones.webp',
                onTap: () => onSelectSection('wellness'),
              ),
            ],
          );
        }

        // Standard mobile / tablet / desktop asymmetric composition
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── LEFT: LARGE WATER CARD (49%) ─────────────────────
              Expanded(
                flex: 49,
                child: _LargeWaterCard(
                  waterValue: waterValue,
                  waterProgress: waterProgress,
                  onTap: () => onSelectSection('hydration'),
                ),
              ),

              const SizedBox(width: 12),

              // ─── RIGHT: THREE STACKED COMPACT CARDS (51%) ────────
              Expanded(
                flex: 51,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CompactHealthCard(
                      title: 'Exercise',
                      value: '$exerciseMinutes min',
                      icon: Icons.directions_run_rounded,
                      iconColor: AppColors.exercise,
                      iconBg: const Color(0xFFFFEADB),
                      surfaceColor: AppColors.exerciseCardSurface,
                      decorationAsset: 'assets/decorations/health_sneaker.webp',
                      onTap: () => onSelectSection('exercise'),
                    ),
                    const SizedBox(height: 10),
                    _CompactHealthCard(
                      title: 'Habits',
                      value: habitsLabel,
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.habitGreen,
                      iconBg: const Color(0xFFDCFCE7),
                      surfaceColor: AppColors.habitsCardSurface,
                      decorationAsset: 'assets/decorations/health_habits_leaf.webp',
                      onTap: () => onSelectSection('habits'),
                    ),
                    const SizedBox(height: 10),
                    _CompactHealthCard(
                      title: 'Wellness',
                      value: wellnessLabel,
                      icon: Icons.favorite_outline_rounded,
                      iconColor: AppColors.wellnessTeal,
                      iconBg: const Color(0xFFE2F7EB),
                      surfaceColor: AppColors.wellnessCardSurface,
                      decorationAsset: 'assets/decorations/health_zen_stones.webp',
                      onTap: () => onSelectSection('wellness'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Large dominant Water card on the left side of Today's Health.
class _LargeWaterCard extends StatelessWidget {
  final String waterValue;
  final double waterProgress;
  final VoidCallback onTap;

  const _LargeWaterCard({
    required this.waterValue,
    required this.waterProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Water: $waterValue. Tap to view hydration.',
      child: Material(
        color: AppColors.waterCardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Translucent fluid droplet / wave decoration on lower-right
              const Positioned(
                right: -12,
                bottom: -8,
                width: 140,
                height: 150,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WaterDropletPainter(),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row: circle icon + Water + chevron
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.hydration.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.water_drop_outlined,
                                size: 16,
                                color: AppColors.hydration,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Water',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.secondaryText,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Main value: 0.0 / 2.5 L
                        Text(
                          waterValue,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            letterSpacing: -0.4,
                            color: AppColors.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: waterProgress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFDCEBFA),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.hydration,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Lower editorial motivation text
                    Text(
                      'Stay hydrated\nfor more energy\ntoday.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stacked health card on the right side of Today's Health.
class _CompactHealthCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color surfaceColor;
  final String decorationAsset;
  final VoidCallback onTap;

  const _CompactHealthCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.surfaceColor,
    required this.decorationAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$title: $value',
      child: Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Subtle botanical / wellness decoration in lower right
              Positioned(
                right: 2,
                bottom: 2,
                width: 48,
                height: 48,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      decorationAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: circle icon + title + chevron
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 15, color: iconColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.secondaryText,
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Value
                    Padding(
                      padding: const EdgeInsets.only(left: 34),
                      child: Text(
                        value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering a beautiful translucent water droplet with wave highlight.
class _WaterDropletPainter extends CustomPainter {
  const _WaterDropletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Organic fluid droplet contour
    final dropPath = Path();
    dropPath.moveTo(w * 0.72, h * 0.18);
    // Right bulge
    dropPath.cubicTo(
      w * 0.96, h * 0.42,
      w * 1.02, h * 0.72,
      w * 0.72, h * 0.94,
    );
    // Bottom contour
    dropPath.cubicTo(
      w * 0.38, h * 1.04,
      w * 0.12, h * 0.84,
      w * 0.18, h * 0.58,
    );
    // Left contour back to top
    dropPath.cubicTo(
      w * 0.28, h * 0.34,
      w * 0.56, h * 0.24,
      w * 0.72, h * 0.18,
    );
    dropPath.close();

    final dropPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.1, -0.1),
        radius: 0.8,
        colors: [
          Color(0x5542A5F5),
          Color(0x2842A5F5),
          Color(0x0042A5F5),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(dropPath, dropPaint);

    // Inner highlight reflection
    final highlightPath = Path();
    highlightPath.moveTo(w * 0.70, h * 0.26);
    highlightPath.cubicTo(
      w * 0.82, h * 0.44,
      w * 0.84, h * 0.64,
      w * 0.68, h * 0.76,
    );
    final highlightPaint = Paint()
      ..color = const Color(0x38FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
