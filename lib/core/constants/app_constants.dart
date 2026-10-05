abstract class AppConstants {
  static const String appName = 'FitFuel';
  static const String appTagline = 'AI-Powered Nutrition Assistant';

  // ─── Spacing Scale (4/8/12/16/20/24/32/40) ──────────────────────────────
  static const double space2Xs = 4.0; // Micro gap
  static const double spaceXs = 4.0; // Micro gap (alias)
  static const double spaceSm = 8.0; // Compact gap
  static const double spaceSmd = 12.0; // Component stack gap
  static const double spaceMd = 16.0; // Standard padding
  static const double spaceMlg = 20.0; // Main horizontal phone padding
  static const double spaceLg = 24.0; // Section gap
  static const double spaceXl = 32.0; // Section large gap / desktop padding
  static const double space40 = 40.0; // Maximum section spacing
  static const double space2Xl = 48.0; // Screen edge offset

  // ─── Semantic Spacing Aliases ────────────────────────────────────────────
  static const double xs = spaceXs;
  static const double sm = spaceSm;
  static const double md = spaceMd;
  static const double lg = spaceLg;
  static const double xl = spaceXl;
  static const double xxl = space2Xl;

  // ─── Corner Radius Tokens (Fresh Green System) ───────────────────────────
  static const double radiusXs = 4.0; // Tooltips, micro indicators
  static const double radiusSm = 8.0; // Micro controls
  static const double radiusMd = 14.0; // Chips (12-16px)
  static const double radiusLg = 16.0; // Buttons (14-16px)
  static const double radiusCard = 24.0; // Cards (22-24px)
  static const double radiusXl = 24.0; // Dialogs, sheets (20-24px)
  static const double radiusFull = 999.0; // Pill buttons, FAB, avatars

  // ─── Semantic Radius Aliases ─────────────────────────────────────────────
  static const double radiusControl = radiusMd; // Controls / chips (14px)
  static const double radiusButton = radiusLg; // Buttons (16px)
  static const double radiusImage = 16.0; // Food photographs
  static const double radiusDialog = radiusXl; // Dialogs / sheets

  // ─── Touch Target & Animation Timings ────────────────────────────────────
  static const double minTouchTargetSize = 48.0;
  static const double elevationCard = 0.0;
  static const double elevationOverlay = 2.0;
  static const int animationDurationFastMs = 150;
  static const int animationDurationStandardMs = 300;
  static const int animationDurationSlowMs = 800;

  // ─── Responsive Breakpoints ──────────────────────────────────────────────
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 1024.0;
  static const double breakpointDesktop = 1280.0;

  // ─── Content Width Targets ───────────────────────────────────────────────
  static const double maxContentWidthMobile = 600.0;
  static const double maxContentWidthTablet = 1024.0;
  static const double maxContentWidthDesktop = 1200.0;

  // ─── Meal & Portion Thresholds ───────────────────────────────────────────
  static const int maxFreeDailyScans = 5;
  static const int defaultWaterGoalMl = 2500;
}
