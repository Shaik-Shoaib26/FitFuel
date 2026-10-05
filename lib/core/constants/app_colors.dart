import 'package:flutter/material.dart';

/// Centralized FitFuel Semantic Design System Color Palette
/// Phase 35.6 FRESH GREEN — NATURAL & HEALTHY Light Color System
abstract class AppColors {
  // ─── MASTER FRESH GREEN LIGHT PALETTE ───────────────────────────────────────
  static const Color primaryLeafGreen = Color(0xFF0F7D38);
  static const Color deepBrandGreen = Color(0xFF075E48);
  static const Color emeraldGreen = Color(0xFF22C55E);
  static const Color emerald = emeraldGreen; // Phase 35.6.2 alias
  static const Color brightLeafGreen = Color(0xFF72D94C);
  static const Color mintGreen = Color(0xFFA7F3D0);
  static const Color mint = mintGreen; // Phase 35.6.2 alias
  static const Color softSage = Color(0xFFE6F4EA);
  static const Color warmOffWhite = Color(0xFFFAFBF7);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color white = pureWhite; // Phase 35.6.2 alias
  static const Color lightBorder = Color(0xFFDDE7DF);
  static const Color paleGreenTrack = Color(0xFFDDEFE3);
  static const Color disabledMuted = Color(0xFFA7B1AA);

  // Semantic nutrients & highlights for Phase 35.6.2
  static const Color hydrationOrange = Color(0xFFF5A623);
  static const Color proteinGreen = Color(0xFF35C88A);
  static const Color carbsAmber = Color(0xFFF2B84B);
  static const Color fatOrange = Color(0xFFF5A623);
  static const Color calorieOrange = Color(0xFFFF8A34);

  // Backgrounds & Surfaces
  static const Color appCanvas = warmOffWhite; // 0xFFFAFBF7 Warm off-white canvas
  static const Color primarySurface = pureWhite; // 0xFFFFFFFF White elevated surfaces
  static const Color secondarySurface = Color(0xFFF1F8F3); // Soft green tint
  static const Color softBrandSurface = softSage; // 0xFFE6F4EA Soft sage
  static const Color softBrandSurfaceStrong = mintGreen; // 0xFFA7F3D0 Mint green

  // Primary Leaf Green (Brand Identity)
  static const Color primary = primaryLeafGreen; // 0xFF0F7D38 Primary leaf green
  static const Color primary500 = primaryLeafGreen;
  static const Color primary400 = Color(0xFF1E9B4B);
  static const Color primary300 = emeraldGreen; // 0xFF22C55E
  static const Color primary100 = softSage; // 0xFFE6F4EA
  static const Color primary50 = Color(0xFFF3FAF5);
  static const Color primary900 = Color(0xFF085B28);

  // Primary Text
  static const Color primaryText = Color(0xFF17231D); // Strong dark text
  static const Color secondaryText = Color(0xFF657169); // Medium gray-green
  static const Color mutedText = disabledMuted; // 0xFFA7B1AA Muted text

  // Border & Structure
  static const Color border = lightBorder; // 0xFFDDE7DF Light border
  static const Color borderStrong = Color(0xFFCBD5CE);

  // ─── Secondary Brand Colors ─────────────────────────────────────────────────
  static const Color secondary = emeraldGreen; // 0xFF22C55E
  static const Color secondary500 = Color(0xFF16A34A);
  static const Color secondary400 = emeraldGreen;
  static const Color secondary100 = Color(0xFFDCFCE7);
  static const Color secondary50 = Color(0xFFF0FDF4);

  // ─── Semantic Container Roles (Material 3 - LIGHT) ─────────────────────────
  static const Color primaryContainer = softSage; // 0xFFE6F4EA Soft sage container
  static const Color onPrimaryContainer = primaryLeafGreen; // 0xFF0F7D38
  static const Color secondaryContainer = Color(0xFFDCFCE7);
  static const Color onSecondaryContainer = Color(0xFF15803D);
  static const Color surfaceVariant = Color(0xFFF1F8F3); // Soft wellness surface
  static const Color onSurfaceVariant = secondaryText; // 0xFF657169
  static const Color outline = lightBorder; // 0xFFDDE7DF
  static const Color outlineVariant = Color(0xFFE5ECE7);

  // ─── Semantic Nutrients & Activities ─────────────────────────────────────
  // Exact Fresh Green semantic palette
  static const Color hydration = Color(0xFF42A5F5); // Blue for hydration
  static const Color calories = Color(0xFFFF8A34); // Warm orange for activity / calories
  static const Color activity = Color(0xFFFF8A34); // Warm orange
  static const Color exercise = Color(0xFFFF8A34); // Activity / calories
  static const Color protein = Color(0xFF42C88A); // Fresh green for protein
  static const Color carbs = Color(0xFFF2B84B); // Carbohydrates
  static const Color fat = Color(0xFFF0A22E); // Fat
  static const Color fiber = Color(0xFF69C76B); // Fiber
  static const Color sleep = Color(0xFF8174E8); // Sleep
  static const Color mindfulness = Color(0xFF4FC7A1); // Mindfulness
  static const Color warning = Color(0xFFF4A340); // Warnings
  static const Color error = Color(0xFFD94B4B); // Errors
  static const Color habits = Color(0xFF22C55E); // Emerald for habits
  static const Color ai = primaryLeafGreen; // AI Assistant
  static const Color achievement = Color(0xFFF2B84B); // Warm gold

  static const Color nutrition = primaryLeafGreen;
  static const Color weight = Color(0xFF626A92);

  // ─── Phase 35.6.3 Editorial Wellness Palette ──────────────────────────────
  static const Color habitGreen = Color(0xFF22A06B);
  static const Color wellnessTeal = Color(0xFF36A36F);
  static const Color waterCardSurface = Color(0xFFF1F8FE);
  static const Color exerciseCardSurface = Color(0xFFFFF6EF);
  static const Color habitsCardSurface = Color(0xFFF0F8F2);
  static const Color wellnessCardSurface = Color(0xFFEFF8F2);
  static const Color healthTipSurface = Color(0xFFEFF8F2);

  // ─── Legacy & Alias Mappings for Compatibility ───────────────────────────
  static const Color accentProtein = protein;
  static const Color accentCarbs = carbs;
  static const Color accentFats = fat;
  static const Color accentWater = hydration;

  static const Color lightBgTinted = secondarySurface;
  static const Color lightTextPrimary = primaryText;
  static const Color lightTextSecondary = secondaryText;
  static const Color lightTextMuted = mutedText;
  static const Color lightBgSurface = primarySurface;
  static const Color lightBorderSubtle = border;

  // Navigation colors
  static const Color lightNavBg = pureWhite; // White bottom / sidebar nav
  static const Color lightNavSelected = softSage; // Soft sage / mint selected
  static const Color lightNavSelectedHover = Color(0xFFDCECD5);
  static const Color lightNavText = primaryText;
  static const Color lightNavTextSecondary = secondaryText;
  static const Color lightNavIconSelected = primaryLeafGreen; // #0F7D38
  static const Color lightNavIconUnselected = Color(0xFF8A958D);
  static const Color lightNavBorder = Color(0xFFE5ECE7);
  static const Color lightNavDivider = Color(0xFFE5ECE7);
  static const Color lightBgBase = warmOffWhite;

  static const Color darkNavBg = Color(0xFF10382E); // Preserved for dark mode
  static const Color darkNavText = Colors.white70;
  static const Color darkNavSelectedBg = Color(0x26FFFFFF);
  static const Color darkBgBase = Color(0xFF0F172A);
  static const Color darkBgSurface = Color(0xFF1E293B);
  static const Color darkBgTinted = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFE2E8F0);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorderSubtle = Color(0xFF334155);
  static const Color darkBorder = darkBorderSubtle;

  // ─── Glassmorphic Surfaces ───────────────────────────────────────────────
  static const Color lightGlassSurface = Color(0xE6FFFFFF);
  static const Color darkGlassSurface = Color(0xCC1E293B);

  // ─── Semantic Feedback States ────────────────────────────────────────────
  static const Color success = emeraldGreen; // #22C55E
  static const Color info = Color(0xFF42A5F5);

  // ─── Premium Visual Identity ─────────────────────────────────────────────
  static const Color sidebarBackground = Color(0xFF10382E); // Preserved for dark mode
  static const Color pageCanvas = warmOffWhite;

  static const Color stateSuccess = success;
  static const Color stateWarning = warning;
  static const Color stateError = error;
  static const Color stateInfo = info;

  // ─── Dark Theme Semantic Container Roles ─────────────────────────────────
  static const Color darkPrimaryContainer = Color(0xFF064E3B);
  static const Color darkOnPrimaryContainer = Color(0xFFECFDF5);
  static const Color darkSecondaryContainer = Color(0xFF134E4A);
  static const Color darkOnSecondaryContainer = Color(0xFFCCFBF1);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOnSurfaceVariant = Color(0xFFCBD5E1);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkOutlineVariant = Color(0xFF475569);
}
