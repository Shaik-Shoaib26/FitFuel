import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Stable image geometry shared by all food-image compatibility wrappers.
class FitFuelFoodPhoto extends StatelessWidget {
  final String source, description;
  final double? width, height, aspectRatio;
  final double borderRadius;
  final BoxFit fit;
  const FitFuelFoodPhoto(
      {super.key,
      required this.source,
      required this.description,
      this.width,
      this.height,
      this.aspectRatio,
      this.borderRadius = AppConstants.radiusImage,
      this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final ratio =
            aspectRatio != null && aspectRatio!.isFinite && aspectRatio! > 0
                ? aspectRatio!
                : 1.0;
        final w = width ??
            (constraints.hasBoundedWidth
                ? constraints.maxWidth
                : (height ?? 160) * ratio);
        final h = height ?? w / ratio;
        final scheme = Theme.of(context).colorScheme;
        Widget fallback({bool loading = false}) => ColoredBox(
            color: scheme.primaryContainer,
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.restaurant_rounded,
                  size: (h * .3).clamp(12, 32),
                  color: scheme.onPrimaryContainer),
              if (w >= 96 && h >= 80) ...[
                const SizedBox(height: 4),
                Text(loading ? 'Loading photo' : 'FitFuel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onPrimaryContainer))
              ],
            ])));
        final network =
            source.startsWith('https://') || source.startsWith('http://');
        Widget picture;
        if (source.isEmpty) {
          picture = fallback();
        } else if (network) {
          picture = Image.network(source,
              width: w,
              height: h,
              fit: fit,
              excludeFromSemantics: true,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : fallback(loading: true),
              errorBuilder: (_, __, ___) => fallback());
        } else {
          picture = Image.asset(source,
              width: w,
              height: h,
              fit: fit,
              excludeFromSemantics: true,
              frameBuilder: (_, child, frame, synchronous) =>
                  synchronous || frame != null
                      ? child
                      : fallback(loading: true),
              errorBuilder: (_, __, ___) => fallback());
        }
        return Semantics(
            image: true,
            label: description.isEmpty ? 'Food photograph' : description,
            excludeSemantics: true,
            child: SizedBox(
                width: w,
                height: h,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: picture)));
      });
}
