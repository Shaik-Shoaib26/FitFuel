# FitFuel Phase 17 — Health & Habit Tracking Documentation

This document describes the implementation of Health & Habit tracking in the FitFuel application.

## 1. Features

### Water Intake Tracking
- Track daily water intake (ml) with a target (ml) and progress bar.
- Quick buttons to add 250ml or 500ml water intake.
- Option to edit daily hydration target.

### Exercise Tracking
- Track workout activities with activity name, duration (minutes), and estimated calories burned.
- Logs multiple activities dynamically for today.

### Habits Checklist
- Track daily habits (e.g., Sleep 7-8 hours, 10k steps, Stretching).
- Checkbox switches to mark completion statuses.

### Daily Wellness Score
- Dynamically calculated score from 0 to 100 based on today's activities:
  - **Nutrition Logging (25%)**: 25 points if at least 1 food record is logged today.
  - **Hydration (25%)**: Water intake ratio relative to target (capped at 25 points).
  - **Exercise (25%)**: Total duration minutes relative to a 30-minute target (capped at 25 points).
  - **Habits (25%)**: Habits completed ratio relative to total checklist habits.

---

## 2. Architecture & Data Schemas

Following the clean architecture layers:

### Domain
- `ExerciseEntity`: Representing logged workout details.
- `HealthRecordEntity`: Main aggregate entity containing target, intake, exercise items, and habits statuses map.
- `WellnessCalculator`: Computes score and filters list records by calendar dates.

### Data
- `ExerciseModel`: Maps JSON to/from remote Firestore payloads.
- `HealthRecordModel`: Main document model mapper.
- Firestore path: `users/{uid}/health/{documentId}`.

### Presentation
- `HealthController` & `healthControllerProvider`: StateNotifier managing logic updates.
- `HealthScreen`: Dashboard layout showing hydration, exercises, habits checklist, and score indicators.
- `_buildCompactWellnessCard`: Wellness widget added to Dashboard screen layout columns with real-time listeners.
