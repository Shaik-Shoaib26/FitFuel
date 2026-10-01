import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class FitFuelProgressRing extends StatelessWidget {
  final double value, size, strokeWidth;
  final String centerTitle, centerSubtitle;
  final Color? progressColor, backgroundColor;
  const FitFuelProgressRing(
      {super.key,
      required this.value,
      this.size = 140,
      this.strokeWidth = 10,
      required this.centerTitle,
      required this.centerSubtitle,
      this.progressColor,
      this.backgroundColor});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return Semantics(
        label: 'Progress ring: $centerTitle $centerSubtitle',
        value: value.isFinite
            ? '${(value * 100).toStringAsFixed(0)}%'
            : 'Unavailable',
        excludeSemantics: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final diameter = constraints.hasBoundedWidth
              ? math.min(size, constraints.maxWidth)
              : size;
          final outside = media.textScaler.scale(16) > 19.2 || diameter < 120;
          final labels = Column(mainAxisSize: MainAxisSize.min, children: [
            Text(centerTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium),
            if (centerSubtitle.isNotEmpty)
              Text(centerSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
          ]);
          final ring = TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: media.disableAnimations
                  ? Duration.zero
                  : const Duration(
                      milliseconds: AppConstants.animationDurationStandardMs),
              curve: Curves.easeOut,
              builder: (_, progress, __) => SizedBox(
                  width: diameter,
                  height: diameter,
                  child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: strokeWidth,
                      color: progressColor ?? theme.colorScheme.primary,
                      backgroundColor:
                          backgroundColor ?? theme.colorScheme.outlineVariant,
                      strokeCap: StrokeCap.round)));
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.center, children: [
              ring,
              if (!outside)
                SizedBox(
                    width: math.max(0, diameter - strokeWidth * 2 - 16),
                    child: labels)
            ]),
            if (outside) ...[const SizedBox(height: 12), labels],
          ]);
        }));
  }
}
