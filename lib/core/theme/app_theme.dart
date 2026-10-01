import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_typography.dart';
import 'fitfuel_semantic_colors.dart';

abstract class AppTheme {
  static ThemeData get lightTheme => _build(false);
  static ThemeData get darkTheme => _build(true);

  static ThemeData _build(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: dark ? AppColors.primary300 : AppColors.primary500,
      onPrimary: dark ? AppColors.primary900 : Colors.white,
      primaryContainer:
          dark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
      onPrimaryContainer: dark
          ? AppColors.darkOnPrimaryContainer
          : AppColors.onPrimaryContainer,
      secondary: dark ? AppColors.secondary400 : AppColors.secondary500,
      onSecondary: dark ? AppColors.darkBgBase : Colors.white,
      surface: dark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
      onSurface: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant:
          dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      surfaceContainerLow: dark ? AppColors.darkBgBase : AppColors.lightBgBase,
      surfaceContainerHighest:
          dark ? AppColors.darkBgTinted : AppColors.lightBgTinted,
      outline: dark ? const Color(0xFF8898AC) : AppColors.lightTextMuted,
      outlineVariant:
          dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF690005) : Colors.white,
    );
    final text = TextTheme(
      displayLarge: AppTypography.heroMetric(isDark: dark),
      displayMedium: AppTypography.displayMedium(isDark: dark),
      displaySmall: AppTypography.metric(isDark: dark),
      headlineLarge: AppTypography.pageTitle(isDark: dark),
      headlineMedium: AppTypography.pageTitle(isDark: dark),
      headlineSmall: AppTypography.sectionTitle(isDark: dark),
      titleLarge: AppTypography.sectionTitle(isDark: dark),
      titleMedium: AppTypography.cardTitle(isDark: dark),
      titleSmall: AppTypography.secondaryBody(isDark: dark)
          .copyWith(fontWeight: FontWeight.w600),
      bodyLarge: AppTypography.body(isDark: dark),
      bodyMedium: AppTypography.secondaryBody(isDark: dark),
      bodySmall: AppTypography.caption(isDark: dark),
      labelLarge:
          AppTypography.button(isDark: dark).copyWith(color: scheme.onSurface),
      labelMedium: AppTypography.label(isDark: dark),
      labelSmall: AppTypography.caption(isDark: dark),
    );
    final controlShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusControl));
    final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusButton));
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      elevation: const WidgetStatePropertyAll(0),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusControl),
            borderSide: BorderSide(color: color, width: width));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor:
          dark ? AppColors.darkBgBase : AppColors.lightBgBase,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [
        dark ? FitFuelSemanticColors.dark : FitFuelSemanticColors.light
      ],
      appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: text.titleLarge,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: AppConstants.elevationCard,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
              side: BorderSide(color: scheme.outlineVariant))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: button.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? scheme.onSurface.withValues(alpha: .12)
                      : scheme.primary),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? scheme.onSurface.withValues(alpha: .38)
                      : scheme.onPrimary))),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 48)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: text.bodyMedium,
          hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          errorStyle: text.bodySmall?.copyWith(color: scheme.error),
          errorMaxLines: 3,
          border: border(scheme.outline),
          enabledBorder: border(scheme.outline),
          disabledBorder: border(scheme.outlineVariant),
          focusedBorder: border(scheme.primary, 2),
          errorBorder: border(scheme.error),
          focusedErrorBorder: border(scheme.error, 2)),
      chipTheme: ChipThemeData(
          backgroundColor: scheme.surface,
          selectedColor: scheme.primaryContainer,
          labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
          checkmarkColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: scheme.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith((states) =>
              text.labelMedium!.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant))),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
          selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
          unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
          selectedLabelTextStyle: text.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
          unselectedLabelTextStyle: text.labelMedium),
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusDialog))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusDialog)))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 2,
          shape: buttonShape),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }
}

