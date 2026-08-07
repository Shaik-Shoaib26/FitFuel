import 'package:flutter/material.dart';

/// FitFuel Color Palette Specification
/// Strictly aligned with FITFUEL_DESIGN_SYSTEM.md
abstract class AppColors {
  // Primary Emerald Brand Colors
  static const Color primary500 = Color(0xFF059669); // Light mode primary
  static const Color primary400 = Color(0xFF10B981); // Dark mode primary / accent glow
  static const Color primary100 = Color(0xFFECFDF5);
  static const Color primary900 = Color(0xFF064E3B);

  // Secondary & Accents
  static const Color secondary500 = Color(0xFF0D9488);
  static const Color accentProtein = Color(0xFFF97316); // Protein Orange
  static const Color accentCarbs = Color(0xFF3B82F6); // Carbs Blue
  static const Color accentFats = Color(0xFF8B5CF6); // Fats Purple
  static const Color accentWater = Color(0xFF06B6D4); // Water Cyan

  // Canvas & Backgrounds (Dark Default, Light Secondary)
  static const Color darkBgBase = Color(0xFF0F172A);
  static const Color darkBgSurface = Color(0xFF1E293B);
  static const Color lightBgBase = Color(0xFFF8FAFC);
  static const Color lightBgSurface = Color(0xFFFFFFFF);

  // Glassmorphic Overlays
  static const Color darkGlassSurface = Color(0xCC1E293B);
  static const Color lightGlassSurface = Color(0xD9FFFFFF);

  // Typography & Content Colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Borders & Structural Strokes
  static const Color darkBorderSubtle = Color(0xFF334155);
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF10B981);

  // Semantic Feedback States
  static const Color stateSuccess = Color(0xFF10B981);
  static const Color stateWarning = Color(0xFFF59E0B);
  static const Color stateError = Color(0xFFEF4444);
  static const Color stateInfo = Color(0xFF3B82F6);
}
