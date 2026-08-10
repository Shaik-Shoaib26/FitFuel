# FitFuel Phase 14 — Personalized Meal Planner

## 1. Executive Summary
The Personalized Meal Planner screen has been added to the FitFuel app. Using target split ratios (Breakfast: 25%, Lunch: 35%, Dinner: 30%, Snack: 10%), it segments the user's daily goals and matches food choices from the local database. The planner accounts for today's consumed logs and filters options dynamically.

---

## 2. Files Created
* [`lib/features/nutrition/domain/utils/meal_planner_engine.dart`](file:///c:/projects/FitFuel/lib/features/nutrition/domain/utils/meal_planner_engine.dart) — Splits calorie/macro goals and recommends meal options while avoiding consumed duplicates.
* [`lib/features/nutrition/presentation/screens/meal_plan_screen.dart`](file:///c:/projects/FitFuel/lib/features/nutrition/presentation/screens/meal_plan_screen.dart) — Layout showing meal suggestion divisions (Breakfast, Lunch, Dinner, Snack) and pre-populated sheet triggers.
* [`test/features/nutrition/nutrition_planner_test.dart`](file:///c:/projects/FitFuel/test/features/nutrition/nutrition_planner_test.dart) — Unit tests validating target splits, duplicate logging considerations, and empty goals fallback defaults.
* [`PHASE_14_PERSONALIZED_MEAL_PLANNER.md`](file:///c:/projects/FitFuel/PHASE_14_PERSONALIZED_MEAL_PLANNER.md) — Phase documentation.

---

## 3. Files Modified
* [`lib/app/config/routes.dart`](file:///c:/projects/FitFuel/lib/app/config/routes.dart) — Added GoRoute registration for `AppRoutes.mealPlan` pointing to `MealPlanScreen`.
* [`lib/features/dashboard/presentation/screens/dashboard_screen.dart`](file:///c:/projects/FitFuel/lib/features/dashboard/presentation/screens/dashboard_screen.dart) — Added a navigation button inside dashboard `AppBar.actions` directing to `AppRoutes.mealPlan`.

---

## 4. Features Implemented
1. **Target Distribution Splits:** Automatically divides daily targets (Calories, Protein, Carbs, Fats) across meals (Breakfast: 25%, Lunch: 35%, Dinner: 30%, Snack: 10%).
2. **Personalized Recommendations:** Scores and selects food choices dynamically, avoiding foods already consumed today.
3. **Menu Summary Metrics:** Compares the user's daily target against planned suggestions and today's remaining calories.
4. **Log Pre-filling:** Choosing recommendations pre-populates values inside the existing `FoodFormSheet` to keep logs consistent.

---

## 5. Verification Results

### Unit Tests (`flutter test`)
```text
00:03 +48: All tests passed! (48 tests verified successfully)
```

### Static Analysis (`flutter analyze`)
```text
Analyzing FitFuel...                                            
No issues found! (ran in 3.7s)
```
