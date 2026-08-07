# FitFuel — Master Design System Specification
**Official Design System & Visual Standards for AI-Powered Nutrition Tracking**

---

| System Version | Target Platform | Lead Architect | Material Baseline | Design Style |
| :--- | :--- | :--- | :--- | :--- |
| **1.0.0-DS** | iOS & Android (Flutter) | Senior Product Designer (Google Health & AI) | Material 3 Hybrid + Apple HIG | FitFuel Glass-Emerald System |

---

## Executive Summary

The **FitFuel Design System** is an enterprise-grade visual, spatial, and interactive design language engineered specifically for **FitFuel**—the AI-powered mobile nutrition and healthy eating assistant. 

Anchored in the approved `SOFTWARE_PLANNING_DOCUMENT.md` and `FITFUEL_UI_UX_DESIGN_SPECIFICATION.md`, this system synthesizes the best design principles of **Google Material 3**, **Apple Health**, and **Fitbit**, while establishing a unique, premium identity. Built around **sub-5-second meal logging via Google Gemini Vision AI**, every component, color token, typographic scale, and motion curve is designed to feel instant, tactile, friction-free, and encouraging.

---

## Table of Contents
1. [Color Palette & Token System](#1-color-palette--token-system)
2. [Typography System](#2-typography-system)
3. [Spacing & Layout System](#3-spacing--layout-system)
4. [Border Radius System](#4-border-radius-system)
5. [Elevation & Depth](#5-elevation--depth)
6. [Shadows & Glows](#6-shadows--glows)
7. [Icon Style & Guidelines](#7-icon-style--guidelines)
8. [Illustration Style & Visual Assets](#8-illustration-style--visual-assets)
9. [Component Library Specification](#9-component-library-specification)
10. [Motion Design & Micro-Interactions](#10-motion-design--micro-interactions)
11. [Accessibility Specification](#11-accessibility-specification)
12. [Figma Organization & Token Governance](#12-figma-organization--token-governance)

---

## 1. Color Palette & Token System

FitFuel employs a **dual-theme architecture** (Light Mode as the accessible baseline, Dark Slate Mode as the signature premium aesthetic). The color strategy uses vibrant emerald green as the brand primary (vitality, AI precision, health) paired with color-coded macronutrient accents (Protein Orange, Carbs Blue, Fats Purple, Water Cyan).

```
                      FITFUEL COLOR TOKEN MAP
┌──────────────────────────────────────────────────────────────────────┐
│  Brand Primary:  Emerald Green (#10B981) - Health, Balance & AI     │
│  Dark Base:       Deep Slate    (#0F172A) - Signature Canvas        │
│  Light Base:      Off-White     (#F8FAFC) - High Legibility Canvas    │
└──────────────────────────────────────────────────────────────────────┘
   ├── Protein Accent: Electric Orange (#F97316)
   ├── Carbs Accent:   Vibrant Blue   (#3B82F6)
   ├── Fats Accent:    Warm Purple    (#8B5CF6)
   └── Water Accent:   Cyan Hydro     (#06B6D4)
```

### 1.1 Complete Color Token Table

| Token Name | Category | Light Mode HEX | Dark Mode HEX | Usage & Role | WCAG Contrast |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `color-primary-500` | Primary | `#059669` | `#10B981` | Main brand, active FAB, primary CTAs | 4.8:1 (AA) |
| `color-primary-400` | Primary | `#10B981` | `#34D399` | Hover states, glowing ring accents | 6.2:1 (AA) |
| `color-primary-100` | Primary Tint | `#ECFDF5` | `#064E3B` | Selected item card backgrounds | N/A (Surface) |
| `color-secondary-500` | Secondary | `#0D9488` | `#14B8A6` | Secondary actions, active tab icons | 4.6:1 (AA) |
| `color-accent-protein` | Macro Accent | `#EA580C` | `#F97316` | Protein macro rings, linear bars | 4.6:1 (AA) |
| `color-accent-carbs` | Macro Accent | `#2563EB` | `#3B82F6` | Carbs macro rings, linear bars | 5.1:1 (AA) |
| `color-accent-fats` | Macro Accent | `#7C3AED` | `#8B5CF6` | Fat macro rings, linear bars | 4.9:1 (AA) |
| `color-accent-water` | Hydro Accent | `#0284C7` | `#06B6D4` | Water tracker widget & wave fill | 5.3:1 (AA) |
| `color-bg-base` | Background | `#F8FAFC` | `#0F172A` | Primary screen canvas background | Base Canvas |
| `color-bg-surface` | Surface | `#FFFFFF` | `#1E293B` | Cards, bottom sheets, dialog modals | Base Surface |
| `color-bg-glass` | Surface Glass | `rgba(255,255,255,0.85)` | `rgba(30,41,59,0.80)` | Frosted navigation panels & overlays | Glass Surface |
| `color-text-primary` | Text | `#0F172A` | `#F8FAFC` | Main headings, primary labels, values | 15.2:1 (AAA) |
| `color-text-secondary`| Text | `#475569` | `#94A3B8` | Subtitles, body copy, dates | 7.1:1 (AAA) |
| `color-text-muted` | Text | `#94A3B8` | `#64748B` | Disabled labels, placeholder text | 4.5:1 (AA) |
| `color-border-subtle` | Border | `#E2E8F0` | `#334155` | 1px card outlines, horizontal dividers | Structural |
| `color-border-focus` | Border | `#059669` | `#10B981` | Focused text inputs, active selection | Focus State |
| `color-state-success` | Semantic | `#059669` | `#10B981` | Goal met banners, success snackbars | Semantic |
| `color-state-warning` | Semantic | `#D97706` | `#F59E0B` | Calorie deficit alert, high sodium | Semantic |
| `color-state-error` | Semantic | `#DC2626` | `#EF4444` | Form validation error, scan failed | Semantic |
| `color-state-info` | Semantic | `#2563EB` | `#3B82F6` | AI Health suggestion card background | Semantic |

---

## 2. Typography System

FitFuel pairs **Plus Jakarta Sans** (UI, body, headings) with **Outfit** (Display metrics and calorie counts). Plus Jakarta Sans provides geometric modernity and friendly rounded terminals, while Outfit delivers high-impact numeric clarity.

### 2.1 Typographic Scale Matrix

| Style Name | Font Family | Size (sp/px) | Line Height | Weight | Letter Spacing | Target Usage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `display-large` | Outfit | 36px | 44px | Bold (700) | -0.02em | Dashboard remaining calorie count, hero numbers |
| `display-medium` | Outfit | 28px | 36px | Bold (700) | -0.01em | Screen title headers, onboarding hero titles |
| `heading-1` | Plus Jakarta Sans | 24px | 32px | SemiBold (600) | 0.00em | Major section titles, modal headers |
| `heading-2` | Plus Jakarta Sans | 20px | 28px | SemiBold (600) | 0.00em | Card titles, meal group headers (Breakfast, Lunch) |
| `heading-3` | Plus Jakarta Sans | 18px | 24px | Medium (500) | 0.00em | Food item names, sub-headings |
| `body-large` | Plus Jakarta Sans | 16px | 24px | Regular (400) | 0.00em | Primary body paragraphs, input field text |
| `body-medium` | Plus Jakarta Sans | 14px | 20px | Regular (400) | 0.01em | Secondary card descriptions, list items |
| `body-small` | Plus Jakarta Sans | 12px | 16px | Medium (500) | 0.02em | Badges, timestamps, macro tag labels |
| `caption` | Plus Jakarta Sans | 11px | 14px | Regular (400) | 0.02em | Micro disclaimers, footer footnotes |
| `button-label` | Plus Jakarta Sans | 15px | 20px | SemiBold (600) | 0.01em | Primary & Secondary CTA button text |

---

## 3. Spacing & Layout System

FitFuel strictly operates on an **8-Point Grid System** (with a 4-point micro-grid for fine alignment of icons and badges).

```
4px   - Micro Gap (Icon-to-text gap, badge inner padding)
8px   - Compact Gap (Inside input padding, stacked option gaps)
16px  - Standard Padding (Card inner padding, screen margin)
24px  - Section Gap (Gaps between dashboard cards, grid gaps)
32px  - Divider Offset (Header-to-content separation)
48px  - Screen Edge Offset (Top splash offset, camera controls margin)
```

### 3.1 Layout Boundaries
* **Screen Edge Margin:** `16dp` on Mobile (< 600dp), `24dp` on Tablet ($\ge$ 600dp).
* **Card Inner Padding:** Uniform `16dp`.
* **Component Vertical Stack Gap:** Standard `12dp`.

---

## 4. Border Radius System

Corner radii convey approachable, friendly health tech aesthetics while maintaining structural alignment:

| Token Name | Radius Value | Target Application |
| :--- | :--- | :--- |
| `radius-xs` | `4dp` | Tooltips, micro progress indicators |
| `radius-sm` | `8dp` | Macro tags, chips, input text fields, small buttons |
| `radius-md` | `12dp` | Food cards, meal group containers, alert dialogs |
| `radius-lg` | `16dp` | Dashboard metric cards, water tracker box, glass panels |
| `radius-xl` | `24dp` | Bottom Sheet modals, top navigation bar header curves |
| `radius-full` | `999dp` | Pill buttons, Floating Action Button (FAB), user avatar circles |

---

## 5. Elevation & Depth

Elevations establish visual hierarchy through surface stacking:

| Level | Value / Z-Index | Light Mode Shadow | Dark Mode Glow / Elevation | Application |
| :--- | :--- | :--- | :--- | :--- |
| `level-0` | 0dp | None | None | Base screen background canvas |
| `level-1` | 2dp | `0px 2px 8px rgba(15,23,42,0.06)` | `0px 4px 20px rgba(0,0,0,0.40)` | Meal cards, food list items, chips |
| `level-2` | 4dp | `0px 4px 16px rgba(15,23,42,0.10)` | `0px 8px 32px rgba(0,0,0,0.60)` | Dropdowns, sticky app bar headers |
| `level-3` | 8dp | `0px 8px 24px rgba(15,23,42,0.15)` | `0px 12px 48px rgba(0,0,0,0.80)` | Bottom sheets, dialog modals |
| `level-fab` | 12dp | `0px 6px 20px rgba(5,150,105,0.35)` | `0px 8px 24px rgba(16,185,129,0.40)` | Center Camera FAB button glow |

---

## 6. Shadows & Glows

Shadows in FitFuel use soft, multi-layered ambient blurring in Light Mode, and vibrant neon accent glows in Dark Mode:

* **Primary Emerald Glow:** `box-shadow: 0px 8px 24px rgba(16, 185, 129, 0.35)`
* **Protein Orange Glow:** `box-shadow: 0px 4px 16px rgba(249, 115, 22, 0.30)`
* **Water Cyan Wave Glow:** `box-shadow: 0px 4px 16px rgba(6, 182, 212, 0.30)`
* **Glassmorphic Stroke:** `1px solid rgba(255, 255, 255, 0.15)` (Dark) / `1px solid rgba(15, 23, 42, 0.08)` (Light)

---

## 7. Icon Style & Guidelines

### 7.1 Icon Library Specification
FitFuel standardizes on **Lucide Icons** (Vector SVG stroke icons).

* **Stroke Weight:** `2.0px` uniform line weight.
* **Stroke Caps & Joins:** Rounded (`stroke-linecap: round`, `stroke-linejoin: round`).
* **Sizing Rules:**
  * **Micro (16x16 dp):** Inline next to text badges (e.g. flame icon next to calories).
  * **Standard (24x24 dp):** App bar actions, navigation tabs, input field trailing icons.
  * **Hero (32x32 dp - 48x48 dp):** Empty states, scanner controls, onboarding features.
* **Touch Bounding Box:** All interactive icons must be wrapped in a minimum **48x48 dp touch target box**.

---

## 8. Illustration Style & Visual Assets

FitFuel adopts a **Modern 3D Geometric Glassmorphism Artwork Style**. Visuals feature floating geometric shapes (translucent spheres, glass plates, vibrant green leaves, water drops) with soft ambient directional lighting.

```
ILLUSTRATION SCENARIO MATRIX
├── 1. Onboarding:        3D Floating Camera Lens with Fresh Avocado & Protein Bar
├── 2. Empty History:     3D Translucent Glass Calendar with Glowing Star
├── 3. AI Scanning State: Pulsing 3D Glass Reticle Target with Laser Grid Lines
├── 4. Goal Met Success:  3D Emerald Trophy with Floating Geometric Confetti
└── 5. Network Error:     3D Cloud with Disconnected Cable & Alert Badge
```

---

## 9. Component Library Specification

Every component is fully specified across Purpose, Variants, States, and Accessibility Notes:

---

### 9.1 Primary Button
* **Purpose:** Triggers main page actions (e.g. "Get Started", "Confirm & Save Log", "Start Free Trial").
* **Variants:** Full-width (Block), Hug-content (Inline), Icon-Left, Icon-Right.
* **States:** Default, Hover, Pressed (`scale 0.96`), Disabled (`30% opacity`), Loading (20px spinner replaces label).
* **Accessibility Notes:** Contrast ratio $\ge 4.5:1$, touch target height `52dp`, screen reader reads label + state.

---

### 9.2 Secondary Button
* **Purpose:** Alternative or secondary page actions (e.g. "Cancel", "Add Another Item", "Skip").
* **Variants:** Glassmorphic Outline, Solid Secondary Tint.
* **States:** Default, Hover, Pressed, Disabled.
* **Accessibility Notes:** Minimum touch target height `48dp`, high contrast label against surface.

---

### 9.3 Icon Button
* **Purpose:** Single-tap utility actions (e.g. Back Arrow, Flash Toggle, Close X, Delete Trash).
* **Variants:** Standard Bare, Circular Filled background.
* **States:** Default, Active/Selected, Disabled.
* **Accessibility Notes:** Wrapped in `48x48dp` touch target, explicit `Tooltip` and `Semantics(label: "Close")`.

---

### 9.4 Text Field
* **Purpose:** Standard text input for forms (e.g. Email, Password, Name, Weight).
* **Variants:** Default Text, Password (with eye toggle), Number/Decimal (with unit suffix like `kg` or `cm`).
* **States:** Default, Focused (`2px emerald border`), Error (`2px red border` + inline text message below), Disabled.
* **Accessibility Notes:** Label permanently visible above or floated, high contrast placeholder (`#94A3B8`).

---

### 9.5 Search Field
* **Purpose:** Real-time text search for food database items.
* **Variants:** Standalone Header Search, Embedded Sheet Search.
* **States:** Empty Default, Active Typing (with clear 'X' button), Filled.
* **Accessibility Notes:** Debounced search query (300ms), screen reader announces search result count updates.

---

### 9.6 Dropdown / Select Input
* **Purpose:** Selecting single option from a list (e.g. Activity Level, Unit System).
* **Variants:** Form Field Dropdown, Bottom Sheet Option Picker.
* **States:** Closed Default, Open Expanded, Item Hover, Item Selected.
* **Accessibility Notes:** Announces current selection and list length (`Option 2 of 4 selected`).

---

### 9.7 Chips / Tags
* **Purpose:** Displaying macro breakdown, status indicators, or category filters.
* **Variants:** Selected Filter Chip, Unselected Filter Chip, Read-only Macro Badge (Protein/Carbs/Fat).
* **States:** Unselected, Selected (Emerald background), Disabled.
* **Accessibility Notes:** Touch target $\ge 48\text{dp}$ height for filter chips, contrast compliant text.

---

### 9.8 Cards
* **Purpose:** Grouping related content into elevated visual containers.
* **Variants:** Standard Elevated Card, Outlined Card, Glassmorphic Tinted Card.
* **States:** Resting, Pressed/Tappable (Light elevation lift).
* **Accessibility Notes:** Grouped semantic container (`Semantics(container: true)`).

---

### 9.9 Calorie Progress Ring
* **Purpose:** Core dashboard visual indicator showing Consumed vs Target Calories.
* **Variants:** Main Dual-Arc Ring (with center text), Compact Ring Widget.
* **States:** Loading Skeleton, Active Filling Animation, Target Exceeded Warning (Orange/Red stroke).
* **Accessibility Notes:** Screen reader reads: *"Daily Calorie Progress: 1,450 consumed out of 2,000 calories target, 550 calories remaining."*

---

### 9.10 Macro Linear Progress Bar
* **Purpose:** Displaying individual macronutrient progress (Protein, Carbs, Fats).
* **Variants:** Protein Bar (Orange), Carbs Bar (Blue), Fats Bar (Purple).
* **States:** Empty 0%, Partial Fill, Target Complete 100% (Checkmark icon appears).
* **Accessibility Notes:** Screen reader reads nutrient name, consumed grams, and target grams.

---

### 9.11 Floating Action Button (FAB)
* **Purpose:** Primary application action—launching the AI Camera Food Scanner.
* **Variants:** Center Docked Bar FAB (64dp circular with camera icon).
* **States:** Default (Pulsing aura glow), Pressed (`scale 0.92`), Hidden (Scrolled down).
* **Accessibility Notes:** Touch target `64x64dp`, `Semantics(label: "Open Camera Food Scanner")`.

---

### 9.12 Bottom Navigation Bar
* **Purpose:** Main navigation hub across 4 primary tabs + center Camera FAB.
* **Variants:** Translucent Glassmorphic Bar (`84dp` height, 16px blur).
* **States:** Tab Selected (Active icon color + label), Tab Unselected.
* **Accessibility Notes:** Proper tab semantics (`Semantics(selected: true, role: Tab)`).

---

### 9.13 Top App Bar
* **Purpose:** Screen title display, navigation back actions, and contextual toolbars.
* **Variants:** Main Dashboard Header (Avatar + Greeting + Date Strip), Sub-screen Header (Back Arrow + Title).
* **States:** Expanded, Collapsed Sticky on scroll.
* **Accessibility Notes:** `H1` screen title landmark for screen readers.

---

### 9.14 Meal Card
* **Purpose:** Displaying logged meal groups (Breakfast, Lunch, Dinner, Snacks) and summary calories.
* **Variants:** Expanded Meal Group (with food item cards), Collapsed Accordion.
* **States:** Empty Meal Group ("+ Add Meal"), Logged Meal Group.
* **Accessibility Notes:** Expandable accordion state announced by VoiceOver/TalkBack.

---

### 9.15 Nutrition Card
* **Purpose:** Granular breakdown of individual food items detected by AI.
* **Variants:** Read-only Summary Item Card, Interactive Editable Card (with Gram Slider).
* **States:** Normal, Edit Mode, Deleting State.
* **Accessibility Notes:** Drag slider provides audio/haptic feedback ticks every 10g step.

---

### 9.16 Water Tracker Widget
* **Purpose:** Quick logging and visualization of daily hydration intake.
* **Variants:** Dashboard Card Widget (with fluid wave fill), Detailed Water Log Sheet.
* **States:** Empty 0ml, Filling Wave State, Daily Goal Achieved (Confetti effect).
* **Accessibility Notes:** Tapping +250ml announces updated total volume immediately.

---

### 9.17 AI Health Suggestion Card
* **Purpose:** Delivering personalized, real-time dietary nudges based on logged intake.
* **Variants:** Positive Feedback (Green tint), Warning Alert (Orange tint), Educational Suggestion (Blue tint).
* **States:** Normal Card, Expanded Context Modal.
* **Accessibility Notes:** Screen reader reads alert type and actionable tip text.

---

### 9.18 Snackbars / Toasts
* **Purpose:** Brief, self-dismissing feedback messages at the bottom of the screen.
* **Variants:** Success Toast ("Meal Logged Successfully!"), Error Toast ("Network Error. Please Retry"), Information Toast.
* **States:** Sliding Up, Resting (3 seconds), Dismissing.
* **Accessibility Notes:** `LiveRegion` announcement so screen readers read message automatically.

---

### 9.19 Dialog Modals
* **Purpose:** Critical confirmation popups (e.g. "Delete Meal?", "Log Out?").
* **Variants:** Confirmation Dialog, Alert Dialog.
* **States:** Backdrop Dimmed (`50% black`), Modal Visible.
* **Accessibility Notes:** Focus trap prevents focus from leaving modal while open.

---

### 9.20 Bottom Sheets
* **Purpose:** Contextual task sheets (e.g. Scan Result Review, Meal Detail, Paywall).
* **Variants:** Draggable Sheet (60% to 90% screen height), Fixed Height Sheet.
* **States:** Peek (Collapsed), Expanded, Dismissed.
* **Accessibility Notes:** Drag handle accessible via double-tap or swipe gestures.

---

## 10. Motion Design & Micro-Interactions

FitFuel utilizes **physics-based fluid animations** to deliver instant visual feedback.

### 10.1 Key Motion Specifications
1. **Button Tap Scale:** Primary buttons scale down to `0.96` on touch down, spring back to `1.0` on release (`150ms`, `cubic-bezier(0.4, 0.0, 0.2, 1)`).
2. **Dashboard Progress Rings:** Progress arcs animate smoothly from `0%` to current fill percentage using an `ElasticOut` curve over `800ms`.
3. **Gram Slider Ticks:** Dragging portion sliders emits light haptic selection ticks every `10g` step increment.
4. **Water Hydration Wave:** Tapping +250ml water triggers a fluid wave animation filling the container over `500ms`.
5. **Page Transitions:** Horizontal slide-and-fade transition (`300ms`) for sub-screens; vertical bottom-up slide (`350ms`) for modal sheets.

---

## 11. Accessibility Specification

FitFuel is compliant with **WCAG 2.1 Level AA Guidelines**:

1. **Color Contrast:** All body text maintains a contrast ratio of $\ge 7:1$; all interactive UI controls maintain $\ge 4.5:1$ against backgrounds.
2. **Touch Targets:** Every interactive button, chip, and icon target is $\ge 48 \times 48\text{ dp}$.
3. **Font Scaling:** Supports system dynamic text scaling up to **200%** without text clipping or layout overflow.
4. **Screen Readers:** Complete semantic tree coverage for VoiceOver (iOS) and TalkBack (Android).
5. **Color Blindness Modes:** Macro progress meters pair distinct colors (Orange, Blue, Purple) with explicit icon visual tags (Protein = Flame, Carbs = Wheat, Fats = Drop).

---

## 12. Figma Organization & Token Governance

To maintain enterprise Figma files:

```
❖ FitFuel - Master Production Design.fig
├── 01. Cover & Project Brief
├── 02. Design System Foundations (Color Variables, Type Styles, Tokens)
├── 03. Iconography & Vector Assets
├── 04. Component Library & Variants (Buttons, Cards, Sliders, Navigation)
├── 05. Screen Flow Views (Light Mode Primary & Dark Mode Secondary)
└── 06. Interactive Prototypes & Handoff Specs
```

### Component Naming Standard
`Component / [Type] / [Variant] / [State]`  
*Example:* `Button / Primary / Default / Light`

---
*End of Master Design System Specification.*
