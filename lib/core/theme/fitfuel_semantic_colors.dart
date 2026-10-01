import 'package:flutter/material.dart';

/// Presentation roles for labeled nutrition and feedback visuals.
@immutable
class FitFuelSemanticColors extends ThemeExtension<FitFuelSemanticColors> {
  final Color calories, protein, carbohydrates, fat, hydration;
  final Color success, warning, info;
  const FitFuelSemanticColors(
      {required this.calories,
      required this.protein,
      required this.carbohydrates,
      required this.fat,
      required this.hydration,
      required this.success,
      required this.warning,
      required this.info});
  static const light = FitFuelSemanticColors(
      calories: Color(0xFF9A572B),
      protein: Color(0xFF956044),
      carbohydrates: Color(0xFF376A91),
      fat: Color(0xFF76608C),
      hydration: Color(0xFF14748A),
      success: Color(0xFF047857),
      warning: Color(0xFF8C600B),
      info: Color(0xFF376A91));
  static const dark = FitFuelSemanticColors(
      calories: Color(0xFFE3AE84),
      protein: Color(0xFFD7B39D),
      carbohydrates: Color(0xFF9ABDD8),
      fat: Color(0xFFC4B0D9),
      hydration: Color(0xFF8BCBD8),
      success: Color(0xFF6ED3B0),
      warning: Color(0xFFE2C47C),
      info: Color(0xFF9ABDD8));
  static FitFuelSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<FitFuelSemanticColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);
  @override
  FitFuelSemanticColors copyWith(
          {Color? calories,
          Color? protein,
          Color? carbohydrates,
          Color? fat,
          Color? hydration,
          Color? success,
          Color? warning,
          Color? info}) =>
      FitFuelSemanticColors(
          calories: calories ?? this.calories,
          protein: protein ?? this.protein,
          carbohydrates: carbohydrates ?? this.carbohydrates,
          fat: fat ?? this.fat,
          hydration: hydration ?? this.hydration,
          success: success ?? this.success,
          warning: warning ?? this.warning,
          info: info ?? this.info);
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
        info: Color.lerp(info, other.info, t)!);
  }
}
