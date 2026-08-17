# FitFuel Phase 18 — Personalized Health Insights Documentation

This document describes the implementation of the Personalized Health Insights engine and widgets in FitFuel.

## 1. Features Overview

### Daily Summary Compilation
- Summarizes nutrition intake (calories/macros), water consumption progress against targets, logged workouts (duration and burned calories), habits checklist completion rates, and today's Wellness Rank.

### 7-Day Trend Analysis
- Aggregates daily wellness indicators over a rolling 7-day period to display visual trend graphs.

### Rule-Based Insights
- Detects patterns in hydration, exercise, and habits checklist completions:
  - **Hydration Target Warnings**: Notifies user of dehydration risks if hydration falls under 1500ml on multiple days.
  - **Sedentary Warning**: Triggers workout reminders if active days logged this week are zero.
  - **Habit Focus Alert**: Guides user to establish routines if habit completion rates fall below 50% average.
  - **Wellness Improvement Indicator**: Highlights positive trajectory trends.

### Daily Actions Suggestions
- Provides practical checklist tasks based on remaining water requirements, workout deficits, missing habit checkboxes, or missing meals logs.

---

## 2. Architecture & Data Flow

- **HealthInsightsEngine** ([`health_insights_engine.dart`](file:///c:/projects/FitFuel/lib/features/health_insights/domain/utils/health_insights_engine.dart)):
  Rule-engine calculating trends, summaries, and suggestions lists.
- **HealthInsightsScreen** ([`health_insights_screen.dart`](file:///c:/projects/FitFuel/lib/features/health_insights/presentation/screens/health_insights_screen.dart)):
  Premium presentation screen displaying trends, stats, rule insights, and daily recommendations.
- **AiContextGenerator** ([`ai_context_generator.dart`](file:///c:/projects/FitFuel/lib/features/ai_assistant/domain/utils/ai_context_generator.dart)):
  Extended to supply the active Gemini model configuration with daily hydration, workout session durations, checklist completions, and wellness scores.
- **Dashboard Card**:
  Compact summary widget embedded inside DashboardScreen columns to navigate to `/health-insights`.
