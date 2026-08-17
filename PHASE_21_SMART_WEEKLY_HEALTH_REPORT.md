# FitFuel Phase 21 — Smart Weekly Health Report & AI Coach

This document details the design, algorithm configurations, database models, and unit verification for the Smart Weekly Health Report and AI Coach.

---

## 1. Executive Summary
Phase 21 introduces an end-to-end Weekly Report dashboard and rule engine that aggregates a user's multi-dimensional health entries (nutrition calorie adherence, protein limits, water quantities, exercise duration, habit checklists, and scale metrics) into a single screen. A dynamic weighted health scoring formula rates performance on a 0-100 scale, filtering by completed date boundaries (e.g. `[T-7, T-1]`) to prevent partial daily entries from skewing stats.

---

## 2. Features Implemented
1. **View Selector**: Switch between the last completed week (`[T-7, T-1]`), current week preview (`[T-6, T]`), and the previous completed week (`[T-14, T-8]`).
2. **Weekly Score Card**: Gauge displaying overall wellness score, score changes vs last week, current streak, and weekly achievements unlocked.
3. **WoW Comparison Grid**: Shows a comparison of health scores, calories, protein, hydration, workouts, habits, wellness, and weights against the previous period.
4. **Strengths & Weaknesses Banners**: Identifies strongest and weakest categories with practical coaching tips.
5. **Expandable Detail Cards**: Collapse/expand breakdowns for nutrition, hydration, exercise, habits, wellness, and weight logs.
6. **Next Week Plan Checklist**: Generates checklist tasks dynamically from weakest categories.
7. **AI Coach Chips Integration**: Pre-fills prompts to Ask Gemini AI Coach directly from the Weekly Report center.

---

## 3. Weekly Score Formula
The Weekly Health Score is evaluated out of 100 based on a weighted 20% split across the 5 core components:
1. **Nutrition (20%)**: Formed by calorie target consistency (within $\pm 5\%$ tolerance) with $60\%$ weight, and protein compliance (meeting target) with $40\%$ weight.
2. **Hydration (20%)**: Days meeting the daily water target divided by 7.
3. **Exercise (20%)**: Target of 3 active days a week = 100%. Active days / 3.
4. **Habits (20%)**: Average completion rate of daily checklist habits.
5. **Wellness (20%)**: Average Wellness rating calculated from logged food/health events.

*Missing metrics are excluded dynamically from the denominator. If wellness or workout logs do not exist, the score is averaged over the remaining active components to prevent misleading penalties.*

---

## 4. Data Sources
All parameters are computed dynamically at runtime from existing collections, eliminating redundant collection synchronization issues:
- `users/{uid}/nutrition`
- `users/{uid}/health`
- `users/{uid}/goals/currentGoal`
- `users/{uid}/weightHistory`

---

## 5. Weekly Comparison Logic
WoW indicators check shifts against previous periods:
- `↑ Improved`: Current value is strictly greater than previous.
- `↓ Declined`: Current value is strictly less than previous.
- `→ Stable`: Current and previous values are equal.
- `— Insufficient data`: Previous period has no logged entries.

---

## 6. Insight Rules
Generates up to 5 weekly highlights:
- Adds nutrition consistency insight if logged nutrition days $> 0$.
- Adds hydration consistency insights highlighting achieved target counts.
- Adds workout totals and durations completed.
- Highlights habit average ratios if $\ge 80\%$.
- Includes logging streaks if $\ge 3$ consecutive days.

---

## 7. Next-Week Action Rules
Generates action items targeting the weakest categories:
- **Nutrition**: Log meals for 7 days, stay within calorie target, meet protein on 5 days.
- **Hydration**: Reach target on 5 days, keep bottle at desk, log water after meals.
- **Exercise**: Complete 3 sessions, walk 15 mins daily, track duration/intensity.
- **Habits**: Completion rate $>80\%$, focus on least consistent habit, check habits early.

---

## 8. Gemini Integration
- **Context Injection**: Appends calculated score, strongest/weakest categories, WoW changes, wellness averages, scale shifts, logging streaks, and unlocked achievements to `AiContextGenerator`.
- **Intent Routing**: The `AiNutritionMockDatasource` (and Gemini model) matches queries like *"How was my week?"* and routes directly to the formatted health report.

---

## 9. Files Created
1. `lib/features/weekly_report/domain/entities/weekly_report_entity.dart`
2. `lib/features/weekly_report/domain/utils/weekly_report_calculator.dart`
3. `lib/features/weekly_report/presentation/controllers/weekly_report_controller.dart`
4. `lib/features/weekly_report/presentation/screens/weekly_report_screen.dart`
5. `test/features/weekly_report/weekly_report_test.dart`

---

## 10. Files Modified
1. `lib/app/config/routes.dart`
2. `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
3. `lib/features/ai_assistant/domain/utils/ai_context_generator.dart`
4. `lib/features/ai_assistant/data/datasources/ai_nutrition_mock_datasource.dart`
5. `lib/features/ai_assistant/presentation/screens/ai_assistant_screen.dart`

---

## 11. Unit Tests
All 114 tests passed, including:
- Perfect weekly score calculation (100).
- Missing metrics dynamic normalizations.
- Strongest and weakest category indicators.
- Date boundary separation logic.
- Weight history differences.
- Context compilations and mock intent routing responses.

---

## 12. Manual Testing Checklist
- [x] Weekly report card displays on the main Dashboard.
- [x] AppBar actions include "Weekly Report" navigation button.
- [x] Selector switches completed/preview/previous weeks.
- [x] Empty state handles accounts with no data logged.
- [x] Prompt chips prefill text field inside the AI Coach.

---

## 13. Known Limitations
- **Weights missing**: If weight records are completely missing from the history, starting and current weights fallback to the baseline profile weight.
