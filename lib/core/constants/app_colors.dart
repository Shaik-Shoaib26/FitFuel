import 'package:flutter/material.dart';

/// Centralized FitFuel Semantic Design System Color Palette
/// Bright / Light / Clean / Premium / Friendly / Wellness Visual Identity
abstract class AppColors {
  // ─── Primary Emerald Brand Colors (Fresh Green) ───────────────────────────
  static const Color primary = Color(0xFF047857); // Accessible emerald
  static const Color primary500 = primary;
  static const Color primary400 = Color(0xFF10B981);
  static const Color primary300 = Color(0xFF34D399);
  static const Color primary100 = Color(0xFFD1FAE5);
  static const Color primary50 = Color(0xFFECFDF5);
  static const Color primary900 = Color(0xFF064E3B);

  // ─── Secondary Brand Colors (Teal / Aqua) ────────────────────────────────
  static const Color secondary = Color(0xFF0D9488);
  static const Color secondary500 = Color(0xFF0F766E);
  static const Color secondary400 = Color(0xFF14B8A6);
  static const Color secondary100 = Color(0xFFCCFBF1);
  static const Color secondary50 = Color(0xFFF0FDF4);

  // ─── Semantic Container Roles (Material 3) ───────────────────────────────
  static const Color primaryContainer = Color(0xFFECFDF5); // Light: soft mint
  static const Color onPrimaryContainer = Color(0xFF064E3B);
  static const Color secondaryContainer = Color(0xFFCCFBF1);
  static const Color onSecondaryContainer = Color(0xFF0D9488);
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Light tinted surface
  static const Color onSurfaceVariant = Color(0xFF475569);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFCBD5E1);

  // ─── Semantic Nutrients & Activities ─────────────────────────────────────
  // Restrained nutrition palette: improves understanding without rainbow UI.
  static const Color calories = Color(0xFFF97316); // Warm Orange — energy
  static const Color protein = Color(0xFFEA580C); // Deeper Orange — muscle
  static const Color carbs = Color(0xFF3B82F6); // Clean Blue — energy source
  static const Color fat = Color(0xFF8B5CF6); // Modern Purple — healthy fats
  static const Color hydration = Color(0xFF06B6D4); // Aqua Cyan — water
  static const Color exercise = Color(0xFFB85B32); // Active Rose
  static const Color habits = Color(0xFF80723C); // Habits olive
  static const Color ai = Color(0xFF6366F1); // AI Indigo/Purple
  static const Color achievement = Color(0xFFF59E0B); // Soft Gold/Amber

  static const Color nutrition = primary;
  static const Color weight = Color(0xFF626A92);

  // ─── Legacy & Alias Mappings for Compatibility ───────────────────────────
  static const Color accentProtein = protein;
  static const Color accentCarbs = carbs;
  static const Color accentFats = fat;
  static const Color accentWater = hydration;

  // ─── Backgrounds & Surfaces (Light Default, Dark Equivalent) ─────────────
  static const Color lightBgBase =
      Color(0xFFF3F5F1); // Neutral canvas separates white data cards
  static const Color lightBgSurface =
      Color(0xFFFFFFFF); // Pure White Card Surface
  static const Color lightBgTinted = Color(0xFFF1F5F9);

  static const Color darkBgBase = Color(0xFF0F172A);
  static const Color darkBgSurface = Color(0xFF1E293B);
  static const Color darkBgTinted = Color(0xFF334155);

  // ─── Glassmorphic Surfaces ───────────────────────────────────────────────
  static const Color lightGlassSurface = Color(0xE6FFFFFF);
  static const Color darkGlassSurface = Color(0xCC1E293B);

  // ─── Typography Colors ───────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0F172A); // Very Dark Charcoal
  static const Color lightTextSecondary = Color(0xFF475569); // Slate Gray
  static const Color lightTextMuted = Color(0xFF64748B);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // ─── Borders & Structural Strokes ────────────────────────────────────────
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color darkBorderSubtle = Color(0xFF334155);
  static const Color borderFocus = Color(0xFF10B981);

  // ─── Semantic Feedback States ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

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
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkOutlineVariant = Color(0xFF475569);
}
