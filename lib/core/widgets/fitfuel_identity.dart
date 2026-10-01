import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'fitfuel_loading_state.dart';

/// Clean, provisional production brand mark for FitFuel.
/// Suggests nutrition, energy, and vitality with emerald vitality gradient.
class FitFuelBrandMark extends StatelessWidget {
  final double size;
  const FitFuelBrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary400, AppColors.primary900],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary900.withValues(alpha: 0.25),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.local_fire_department_rounded,
          size: size * 0.58,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Unified FitFuel brand identity component.
class FitFuelIdentity extends StatelessWidget {
  final ImageProvider? mark;
  final bool compact;
  final double size;
  final bool showMark;
  const FitFuelIdentity({
    super.key,
    this.mark,
    this.compact = false,
    this.size = 32,
    this.showMark = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'FitFuel',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (mark != null) ...[
          Image(image: mark!, width: size, height: size, fit: BoxFit.contain),
          if (!compact) SizedBox(width: size * 0.25)
        ] else if (showMark) ...[
          FitFuelBrandMark(size: size),
          if (!compact) SizedBox(width: size * 0.25)
        ],
        if (!compact)
          Flexible(
              child: Text('FitFuel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                      color: Theme.of(context).colorScheme.primary))),
      ]));
}

class FitFuelSplashIdentity extends StatelessWidget {
  final ImageProvider? mark;
  const FitFuelSplashIdentity({super.key, this.mark});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          FitFuelIdentity(mark: mark, size: 48),
          const SizedBox(height: AppConstants.spaceMd),
          const FitFuelLoadingState(label: 'Opening FitFuel', indicatorSize: 24),
        ])),
      );
}
