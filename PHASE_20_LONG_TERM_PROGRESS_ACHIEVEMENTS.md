# FitFuel Phase 20 — Long-Term Progress & Achievement Tracking

This document outlines the design, implementation, and verification details for the Long-Term Progress & Achievement system in FitFuel.

---

## 1. Executive Summary

Phase 20 introduces a unified Progress Center screen and database layer that correlates historical nutrition logs, hydration quantities, workout durations, habit checklists, and scale metrics into a comprehensive dashboard. It calculates date-filtered adherence consistency, maps rule-based milestones, computes logging streaks, and formats this details dynamically for Gemini AI integrations.

---

## 2. Features

1. **Progress Center Dashboard**: High-level trends for 7, 30, and 90-day periods.
2. **Goal Adherences**: Precise trackers for calories, proteins, carbs, fats, and water intake.
3. **Exercise Analytics**: Summarizes active days, workout minutes, average durations, and calories.
4. **Habits Consistency**: Completion rates, total checklist days, and frequency tracking (most/least consistent).
5. **Wellness Rating Trends**: Evaluates average, best, and lowest wellness ratings, identifying shift changes (Improving/Stable/Declining/Insufficient).
6. **Body Weight Tracker**: Dedicated weight logs with starting/current differences, percentage changes, and goal mapping. Includes a dynamic line chart visualizer.
7. **Rule-Based Milestones**: Automatic status checkers for 10 milestones (streaks, workouts, water targets, wellness performance).
8. **Logging Streaks**: Computes active continuous logging runs and lifetime max runs.

---

## 3. Architecture

Following Clean Architecture conventions:

- **Domain**:
  - `WeightRecordEntity`: Represents a recorded scale log.
  - `ProgressSummaryEntity`: Represents computed averages, consistency percentages, trends, and achievements list.
  - `ProgressCalculator`: Dynamic consistency parser and streaks accumulator.
  - `IProgressRepository`: Interface definitions for database operations.
- **Data**:
  - `WeightRecordModel`: Firestore model converter.
  - `ProgressRemoteDataSourceImpl`: Communicates with `users/{uid}/weightHistory`.
  - `ProgressRepositoryImpl`: Connects models to domain layers.
- **Presentation**:
  - `ProgressController`: Manages selected time ranges and weight entry submissions.
  - `ProgressScreen`: Responsive UI displaying trends, input forms, and achievement lists.

---

## 4. Firestore Schema

New Subcollection: `users/{uid}/weightHistory/{documentId}`
- `weight`: `double` (body weight in kg)
- `recordedAt`: `Timestamp` (recording date and time)
- `createdAt`: `serverTimestamp` (creation tracker)

*Firestore security rules automatically permit read/write access to this subcollection under the existing ownership matcher rule:*
```javascript
match /users/{userId}/{document=**} {
  allow read, write: if isOwner(userId);
}
```

---

## 5. Progress Calculations

1. **Tolerance Band**: Stays within $\pm 5\%$ of the calorie targets to count as a consistent calorie day.
2. **Protein Target**: Meets or exceeds the grams requirement to count as a met protein day.
3. **Hydration Adherence**: Meets or exceeds the target water volume.
4. **Wellness Trend**: Splits the range into two equal periods. If the average rating increases by more than 3, the trend is `Improving`. If it decreases by more than 3, it is `Declining`. Otherwise, it is `Stable`. If less than 3 days are logged, it returns `Insufficient`.
5. **Weight Change**:
   $$\text{Change} = W_{\text{current}} - W_{\text{starting}}$$
   $$\text{Percent Change} = \left(\frac{W_{\text{current}} - W_{\text{starting}}}{W_{\text{starting}}}\right) \times 100$$

---

## 6. Achievement Rules

- **First Meal Logged**: Nutrition collection contains at least 1 record.
- **7-Day Nutrition Streak**: Current logging streak is $\ge 7$ days.
- **Hydration Target Reached**: At least 1 daily health log meets the water target.
- **Hydration consistency**: Water target is reached on $\ge 7$ separate days.
- **First Workout Logged**: At least 1 daily health log contains exercises.
- **7 Active Days**: Workouts logged on $\ge 7$ separate days.
- **300 Workout Minutes**: Combined workout duration is $\ge 300$ minutes.
- **High Habit Performance**: At least 1 day with $\ge 80\%$ habit checklist items completed.
- **Wellness Champion**: Average wellness score is $\ge 80.0$.
- **Scale Step**: Weight history contains at least 1 entry.

---

## 7. Streak Logic

- **Current Streak**: Scans backwards day-by-day starting from today (or yesterday if today has no entries yet). Continues incrementing until a calendar day with zero nutrition records is reached.
- **Longest Streak**: Chronologically sorts all unique nutrition logging dates. Iterates through the list; if dates are consecutive ($D_{i} - D_{i-1} = 1$), increments the current run. If there is a gap ($>1$), resets the run to 1. Tracks the maximum consecutive run observed.

---

## 8. Dashboard Integration

Added a compact **Progress Summary** card to the main Dashboard showing:
- Current nutrition streak in days.
- Wellness rating average score.
- Calorie target consistency percentage.
- Hydration targets consistency percentage.
- Achievements unlocked vs total.
- Total scale weight shift.
- A **"View Progress"** link routing to the full Progress Center.

---

## 9. Gemini Integration

Extended `AiContextGenerator` to append 7-day progress stats, calorie consistency percentages, hydration consistency, workout minutes, average wellness trends, scale metrics, active logging streaks, and unlocked achievements directly into the system prompt context.

Gemini can now accurately answer questions like:
- *"How was my progress this week?"*
- *"What is my weakest health area?"*
- *"Show me my current weight trend."*

---

## 10. Files Created

1. `lib/features/progress/domain/entities/weight_record_entity.dart`
2. `lib/features/progress/domain/entities/progress_summary_entity.dart`
3. `lib/features/progress/domain/utils/progress_calculator.dart`
4. `lib/features/progress/domain/repositories/i_progress_repository.dart`
5. `lib/features/progress/data/models/weight_record_model.dart`
6. `lib/features/progress/data/datasources/progress_remote_datasource.dart`
7. `lib/features/progress/data/repositories/progress_repository_impl.dart`
8. `lib/features/progress/presentation/controllers/progress_controller.dart`
9. `lib/features/progress/presentation/screens/progress_screen.dart`
10. `test/features/progress/progress_test.dart`

---

## 11. Files Modified

1. `lib/app/config/routes.dart`
2. `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
3. `lib/features/ai_assistant/domain/utils/ai_context_generator.dart`
4. `lib/features/ai_assistant/domain/repositories/ai_nutrition_repository.dart`
5. `lib/features/ai_assistant/data/repositories/ai_nutrition_repository_impl.dart`
6. `lib/features/ai_assistant/presentation/controllers/ai_assistant_controller.dart`
7. `lib/features/ai_assistant/presentation/screens/ai_assistant_screen.dart`

---

## 12. Unit Tests

1. `Calculates calorie and protein adherence correctly over ranges` (Passed)
2. `Handles missing nutrition data gracefully without failing with 0%` (Passed)
3. `Computes hydration metrics and handles empty hydration history` (Passed)
4. `Tracks exercise active days, workout minutes and calories correctly` (Passed)
5. `Calculates habit metrics and finds most/least consistent habits` (Passed)
6. `Calculates wellness averages and detects improving/declining trends` (Passed)
7. `Calculates weight changes, starting weights, and percentage shifts` (Passed)
8. `Calculates streaks correctly and checks achievement unlock criteria` (Passed)
9. `GenerateContext includes weight trends, streaks and consistency details in AI context` (Passed)

---

## 13. Manual Testing Procedure

1. **Open Dashboard**: Verify the new "Progress Summary" card is visible below the Wellness card.
2. **Access Progress Center**: Tap "View Progress". Verify range switches (7/30/90 days) refresh averages properly.
3. **Log Weight**: Enter a value (e.g. `78.5`) and tap "Log". Verify starting/current weights update, the line chart renders, and the Scale Step milestone unlocks.
4. **Ask Assistant**: Ask Gemini: *"How is my calorie consistency and weight trend this week?"* Verify the AI uses the actual progress context values.

---

## 14. Known Limitations

- **Chart scale**: The fl_chart line graph renders dates chronologically by index. Gaps between non-consecutive weight logging dates are represented uniformly.
