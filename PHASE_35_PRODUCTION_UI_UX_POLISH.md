# FitFuel Phase 35 — Production UI/UX Polish & Design Guidelines

This document details the visual standards, responsive layout conventions, text scaling safeguards, and accessibility standards implemented for the FitFuel production release.

---

## 🎨 Color System

| Domain | Color / Swatch | Purpose |
| :--- | :--- | :--- |
| **Nutrition** | `AppColors.stateSuccess` (Green) | Macro targets, calorie intake indicators, positive nutrition tags |
| **Hydration** | `AppColors.hydration` | Water log summaries, drink cards, hydration adherence trends |
| **Activity** | `AppColors.exercise` | Active minutes, exercises, routine cards, activity badges |
| **AI Features** | `AppColors.ai` (Purple) | Chat screen, assistant button, bot suggestion components |
| **Progress** | `Colors.indigo` / `Colors.blue` | Score cards, milestones, comparisons, history trend visuals |
| **Success States** | `AppColors.stateSuccess` (Green) | Done indicators, positive achievements, checkmarks |
| **Warnings** | `Colors.amber` | Pending items, network warnings, low targets alerts |
| **Errors / Failures** | `AppColors.stateError` (Red) | Mapped exceptions, invalid inputs, favorites removal |

---

## 📱 Responsive Layout Conventions

FitFuel uses view-based bounds constraints to deliver an optimal visual experience across Mobile, Tablet, and Desktop web screen widths:

1. **Desktop Viewports (1280px–1440px+)**:
   - Central application content uses `Align` + `ConstrainedBox` wrapper with a maximum width of **1200px** on primary screens (Dashboard, Smart Eat, Meal Planner, Grocery, Analytics).
   - Detailed single-item screens (e.g. Food Details, Insights, Progress, Weekly Report) use a narrower **800px** content container to maintain paragraph readability.
2. **Compact Viewports (320px–360px Mobile)**:
   - Elements are ordered in single-column layouts.
   - Margins/Padding: Standardized to `AppConstants.spaceMd` (16px) or `AppConstants.spaceSm` (8px).

---

## 🔍 Text Scaling & Safe Wrapping (Accessibility)

To support custom operating system font scales up to **1.4x scale** without clipping labels or creating horizontal scroll overflows:

- **Horizontal Row Alignment**: Any `Row` children displaying text elements are wrapped in `Expanded` or `Flexible` widgets combined with `TextOverflow.ellipsis`.
- **Button Safeguards**: Text labels inside the primary `FitFuelButton` are protected with a `Flexible` wrapper to let long labels scale and wrap gracefully.
- **Header Truncation**: Screen-level headers (e.g., in `AppBar` or dashboard cards) utilize `Expanded` wrappers to dynamically shrink their width on extremely narrow screens.

---

## ♿ Accessibility (A11y) Touch Targets & Semantics

- **Minimum Touch Targets**: All action elements, icons, button widgets, and list tiles maintain a minimum click area of **48px x 48px**.
- **Descriptive Labels**: Explicit `semanticsLabel` properties are integrated into key user actions (e.g., "Add Food Log", "Hydration log", "AI Assistant", "Sign Out") to assist screen reader users.

---

## 📦 Component Standards

All screens must prioritize using the standardized components:
- **`FitFuelCard`**: Consistent border radius, shadows, and background theme colors.
- **`FitFuelButton`**: Custom primary/secondary states with unified loading and text wrapping.
- **`FitFuelErrorState`**: Friendly, branded visual block with mapped retry actions.
- **`FitFuelEmptyState`**: Non-generic, illustrated empty state placeholders.


## Phase 35.1 implementation — 2026-09-09

- Neutral canvas and white bordered cards strengthen dashboard separation; the nutrition hero uses the FitFuel green border.
- Existing Outfit metric / Plus Jakarta Sans UI type scale retained (36/28 metrics, 24/20/18 headings, 16/14 body).
- Meal Planner uses two naturally sized columns when content is at least 1000px wide. Planned food thumbnails are 88px; macro badges wrap.
- Grocery thumbnails increased from 40px to 56px.
- Analytics summary statistics have individual bordered surfaces and wrap instead of floating in a fixed row.
- AI Assistant conversation and composer share an 880px maximum workspace.
- Smart Eat imagery is larger on desktop, food names allow three lines, macro tags wrap, and logging has a descriptive tooltip.
- Food Details now displays recipe yield, preparation/cooking times, ingredients, and numbered instructions. Recipe quantities remain separate from food-log portion scaling. Serving chips wrap.
- Uses existing food assets and fallbacks; no new stock images, image service, or dependency was added.

Verification at the Phase 35.1 checkpoint: flutter analyze reported No issues found; UI suite passed 17 tests; full suite passed 471 tests.
The earlier 20-test UI file contained unconditional assertions. Four placeholder cases were removed, other cases gained actual widget assertions, and a populated narrow-card case was added (net -3 tests).
The MediaQuery test harness now preserves viewport dimensions. This verifies widget layout, not a manual Android/iOS device acceptance pass or all populated screen combinations.
