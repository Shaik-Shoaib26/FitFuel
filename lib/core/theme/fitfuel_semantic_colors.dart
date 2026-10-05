import 'package:flutter/material.dart';

/// Presentation roles for labeled nutrition and feedback visuals.
/// Phase 35.6 FRESH GREEN — NATURAL & HEALTHY Semantic Colors
@immutable
class FitFuelSemanticColors extends ThemeExtension<FitFuelSemanticColors> {
  final Color calories, protein, carbohydrates, fat, hydration;
  final Color success, warning, info;
  final Color fiber, sleep, mindfulness;

  const FitFuelSemanticColors({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.hydration,
    required this.success,
    required this.warning,
    required this.info,
    this.fiber = const Color(0xFF69C76B),
    this.sleep = const Color(0xFF8174E8),
    this.mindfulness = const Color(0xFF4FC7A1),
  });

  static const light = FitFuelSemanticColors(
    calories: Color(0xFFFF8A34), // Warm orange for Activity / Calories
    protein: Color(0xFF42C88A), // Fresh green for protein
    carbohydrates: Color(0xFFF2B84B), // Carbohydrates
    fat: Color(0xFFF0A22E), // Fat
    hydration: Color(0xFF42A5F5), // Hydration
    success: Color(0xFF22C55E), // Emerald Green
    warning: Color(0xFFF4A340), // Warning
    info: Color(0xFF0F7D38), // Primary Leaf Green
    fiber: Color(0xFF69C76B),
    sleep: Color(0xFF8174E8),
    mindfulness: Color(0xFF4FC7A1),
  );

  static const dark = FitFuelSemanticColors(
    calories: Color(0xFFE3AE84),
    protein: Color(0xFFD7B39D),
    carbohydrates: Color(0xFF9ABDD8),
    fat: Color(0xFFC4B0D9),
    hydration: Color(0xFF8BCBD8),
    success: Color(0xFF6ED3B0),
    warning: Color(0xFFE2C47C),
    info: Color(0xFF9ABDD8),
    fiber: Color(0xFF8CD48E),
    sleep: Color(0xFFA59CF0),
    mindfulness: Color(0xFF76DFC0),
  );

  static FitFuelSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<FitFuelSemanticColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  FitFuelSemanticColors copyWith({
    Color? calories,
    Color? protein,
    Color? carbohydrates,
    Color? fat,
    Color? hydration,
    Color? success,
    Color? warning,
    Color? info,
    Color? fiber,
    Color? sleep,
    Color? mindfulness,
  }) =>
      FitFuelSemanticColors(
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbohydrates: carbohydrates ?? this.carbohydrates,
        fat: fat ?? this.fat,
        hydration: hydration ?? this.hydration,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        fiber: fiber ?? this.fiber,
        sleep: sleep ?? this.sleep,
        mindfulness: mindfulness ?? this.mindfulness,
      );

  @override
  FitFuelSemanticColors lerp(covariant FitFuelSemanticColors? other, double t) {
    if (other == null) return this;
    return FitFuelSemanticColors(
      calories: Color.lerp(calories, other.calories, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      carbohydrates: Color.lerp(carbohydrates, other.carbohydrates, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      hydration: Color.lerp(hydration, other.hydration, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      fiber: Color.lerp(fiber, other.fiber, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      mindfulness: Color.lerp(mindfulness, other.mindfulness, t)!,
    );
  }
}
