import 'package:flutter/material.dart';

import 'app_colors.dart';

/// FitFuel Typographic Scale Specification (Phase 35.6 Fresh Green)
/// Uses Plus Jakarta Sans for UI & Outfit for Metrics
/// Semantic hierarchy: PAGE → SECTION → CARD → METRIC → SUPPORTING INFO
abstract class AppTypography {
  // ─── Display / Hero Metrics (Outfit) ─────────────────────────────────────
  static TextStyle displayLarge({bool isDark = true}) => TextStyle(
        fontFamily: 'Outfit',
        fontSize: 34,
        height: 1.3,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.5,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  static TextStyle displayMedium({bool isDark = true}) => TextStyle(
        fontFamily: 'Outfit',
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.28,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // ─── Semantic Page Hierarchy ─────────────────────────────────────────────
  /// Top-level screen title (e.g. "Good morning, Shoaib")
  static TextStyle pageTitle({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  /// Section header within a page (e.g. "Today's Nutrition")
  static TextStyle sectionTitle({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 21,
        height: 1.35,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.1,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  /// Card-level title (e.g. food item name)
  static TextStyle cardTitle({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        letterSpacing: 0,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  /// Large hero metric value (e.g. "1,250" kcal)
  static TextStyle heroMetric({bool isDark = true}) => TextStyle(
        fontFamily: 'Outfit',
        fontSize: 34,
        height: 1.25,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.5,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  /// Standard metric value (e.g. "78 / 112 g")
  static TextStyle metric({bool isDark = true}) => TextStyle(
        fontFamily: 'Outfit',
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        letterSpacing: -0.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  /// Large nutrition number (28-32 px, w700)
  static TextStyle nutritionNumber({bool isDark = true}) => TextStyle(
        fontFamily: 'Outfit',
        fontSize: 30,
        height: 1.25,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: -0.3,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // ─── Body & Supporting Text ──────────────────────────────────────────────
  static TextStyle body({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        letterSpacing: 0,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  static TextStyle secondaryBody({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        letterSpacing: 0.1,
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      );

  static TextStyle label({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        fontVariations: const [FontVariation('wght', 500)],
        letterSpacing: 0.1,
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      );

  static TextStyle caption({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        letterSpacing: 0.1,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      );

  static TextStyle button({bool isDark = true}) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 15.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        letterSpacing: 0.15,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      );

  // ─── Legacy Aliases for Backward Compatibility ───────────────────────────
  static TextStyle heading1({bool isDark = true}) => pageTitle(isDark: isDark);
  static TextStyle heading2({bool isDark = true}) =>
      sectionTitle(isDark: isDark);
  static TextStyle heading3({bool isDark = true}) => cardTitle(isDark: isDark);
  static TextStyle bodyLarge({bool isDark = true}) => body(isDark: isDark);
  static TextStyle bodyMedium({bool isDark = true}) =>
      secondaryBody(isDark: isDark);
  static TextStyle bodySmall({bool isDark = true}) => label(isDark: isDark);
  static TextStyle buttonLabel({bool isDark = true}) => button(isDark: isDark);
}
