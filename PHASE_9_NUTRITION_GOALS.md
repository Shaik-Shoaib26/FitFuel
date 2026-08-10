# FitFuel Phase 9 — Nutrition Goals

## 1. Firebase Project
* **Display Name:** FitFuel
* **Project ID:** `fitfuel-ab042`
* **Configuration:** Connected via `DefaultFirebaseOptions.currentPlatform` in `lib/firebase_options.dart`.

---

## 2. Firestore Structure
The user's daily macronutrient targets and nutrition goals document is saved under:

```
users/{uid}/goals/currentGoal
```

### Document Schema (`users/{uid}/goals/currentGoal`)
* **`userId`** `(String)`: Firebase Authentication User UID (e.g. `JpYuHyMZFaRjl1F6KEbZKQbMhDj1`).
* **`dailyCalorieTarget`** `(int)`: Total energy goal in kcal (e.g. `2000`).
* **`macroTargets`** `(Map)`:
  * **`proteinGrams`** `(double)`: Target protein weight in grams.
  * **`carbsGrams`** `(double)`: Target carbohydrate weight in grams.
  * **`fatGrams`** `(double)`: Target fat weight in grams.
* **`updatedAt`** `(Timestamp)`: Server timestamp generated upon goals updates.

---

## 3. Files Created
* [`lib/features/profile/domain/entities/nutrition_goals_entity.dart`](file:///c:/projects/FitFuel/lib/features/profile/domain/entities/nutrition_goals_entity.dart) — Pure Dart entity representing user's nutrition goals.
* [`lib/features/profile/data/models/nutrition_goals_model.dart`](file:///c:/projects/FitFuel/lib/features/profile/data/models/nutrition_goals_model.dart) — DTO model handling map mapping, macro splits nesting, and Timestamp parsing.
* [`lib/features/profile/presentation/controllers/nutrition_goals_controller.dart`](file:///c:/projects/FitFuel/lib/features/profile/presentation/controllers/nutrition_goals_controller.dart) — StateNotifier managing goals save operations and states.
* [`lib/features/profile/presentation/widgets/edit_goals_sheet.dart`](file:///c:/projects/FitFuel/lib/features/profile/presentation/widgets/edit_goals_sheet.dart) — Bottom sheet edit form for inputting daily targets with validators.
* [`test/features/profile/nutrition_goals_test.dart`](file:///c:/projects/FitFuel/test/features/profile/nutrition_goals_test.dart) — Unit tests verifying nutrition goals domain models, entities, and conversions.
* [`PHASE_9_NUTRITION_GOALS.md`](file:///c:/projects/FitFuel/PHASE_9_NUTRITION_GOALS.md) — Phase documentation.

---

## 4. Files Modified
* [`lib/core/services/firestore_service.dart`](file:///c:/projects/FitFuel/lib/core/services/firestore_service.dart) — Added goals document snapshot streams, read, and write operations.
* [`lib/features/profile/domain/repositories/i_profile_repository.dart`](file:///c:/projects/FitFuel/lib/features/profile/domain/repositories/i_profile_repository.dart) — Added contract declarations for goals.
* [`lib/features/profile/data/repositories/profile_repository_impl.dart`](file:///c:/projects/FitFuel/lib/features/profile/data/repositories/profile_repository_impl.dart) — Added implementation of goals repository.
* [`lib/features/profile/presentation/providers/profile_providers.dart`](file:///c:/projects/FitFuel/lib/features/profile/presentation/providers/profile_providers.dart) — Exposes reactive `nutritionGoalsStreamProvider` listening to the user's current goal document.
* [`lib/features/dashboard/presentation/screens/dashboard_screen.dart`](file:///c:/projects/FitFuel/lib/features/dashboard/presentation/screens/dashboard_screen.dart) — Integrated daily intake vs targets progress panel with progress bars.
* [`firestore.rules`](file:///c:/projects/FitFuel/firestore.rules) — Enforced explicit rules for goals subcollection.

---

## 5. Security Rules
Production-grade security rules configured in [`firestore.rules`](file:///c:/projects/FitFuel/firestore.rules):

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return isAuthenticated() && request.auth.uid == userId; }

    match /users/{uid} {
      allow read, write: if isOwner(uid);

      // Explicit rules for user's nutrition data subcollection
      match /nutrition/{nutritionId} {
        allow read, write: if isOwner(uid);
      }

      // Explicit rules for user's nutrition goals subcollection
      match /goals/{goalId} {
        allow read, write: if isOwner(uid);
      }

      match /{subcollection=**} {
        allow read, write: if isOwner(uid);
      }
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

* **Goals Tenant Isolation:** User A can read and write ONLY `users/{userA_uid}/goals/currentGoal`.
* **Zero Cross-Tenant Access:** Access to other users' goals is blocked and returns `permission-denied`.

---

## 6. Verification Results

### Unit Tests (`flutter test`)
```text
00:02 +21: All tests passed! (21 tests verified successfully)
```

### Static Analysis (`flutter analyze`)
```text
Analyzing FitFuel...                                            
No issues found! (ran in 78.9s)
```
