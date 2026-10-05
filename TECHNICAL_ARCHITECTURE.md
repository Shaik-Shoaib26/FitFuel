# FitFuel — Master Technical Architecture Blueprint
**Production-Ready Flutter Mobile Application, Clean Architecture & Firebase Infrastructure Specification**

---

| System Version | Lead Architect | Target Framework | State Management | Backend Ecosystem | AI Engine |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1.0.0-ARCH** | Principal Flutter Architect & Technical Lead | Flutter 3.x (Dart 3.x) | Riverpod 2.x (`AsyncNotifier`) | Firebase Serverless | Google Gemini 1.5/2.0 Flash API |

---

## Executive Summary

This document serves as the official **Master Technical Architecture Blueprint** for **FitFuel**—the AI-powered mobile nutrition, calorie tracking, and healthy eating assistant. 

Grounded exclusively in the approved single sources of truth (`SOFTWARE_PLANNING_DOCUMENT.md`, `FITFUEL_UI_UX_DESIGN_SPECIFICATION.md`, `FITFUEL_DESIGN_SYSTEM.md`, `AUTHENTICATION_AND_DATA_ARCHITECTURE.md`, and `DATABASE_DESIGN.md`), this architecture translates business and UX requirements into an enterprise-grade, maintainable, scalable, and testable codebase.

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [Project Folder Structure](#3-project-folder-structure)
4. [Clean Architecture Layer Specification](#4-clean-architecture-layer-specification)
5. [Feature Module Architecture](#5-feature-module-architecture)
6. [State Management Strategy (Riverpod)](#6-state-management-strategy-riverpod)
7. [Repository Pattern Specification](#7-repository-pattern-specification)
8. [Service Layer Architecture](#8-service-layer-architecture)
9. [Navigation Architecture (GoRouter)](#9-navigation-architecture-gorouter)
10. [Global Error Handling Strategy](#10-global-error-handling-strategy)
11. [Offline Caching & Synchronization Strategy](#11-offline-caching--synchronization-strategy)
12. [Performance Optimization Plan](#12-performance-optimization-plan)
13. [Security Architecture & Secrets Management](#13-security-architecture--secrets-management)
14. [Logging, Telemetry & Monitoring](#14-logging-telemetry--monitoring)
15. [Dependency Management & Package Governance](#15-dependency-management--package-governance)
16. [Environment Configuration & Build Flavors](#16-environment-configuration--build-flavors)
17. [Comprehensive Testing Strategy](#17-comprehensive-testing-strategy)
18. [CI/CD Pipeline (GitHub Actions)](#18-cicd-pipeline-github-actions)
19. [Coding Standards & Lint Rules](#19-coding-standards--lint-rules)
20. [Development Workflow & Git Branching](#20-development-workflow--git-branching)
21. [Future Scalability Architecture](#21-future-scalability-architecture)
22. [Engineering Checklist](#22-engineering-checklist)
23. [End-to-End System Architecture Diagram](#23-end-to-end-system-architecture-diagram)

---

## 1. Architecture Overview

FitFuel is engineered using **Feature-First Clean Architecture** combined with **Riverpod Reactive State Management**. The design enforces strict separation of concerns, single-direction data flow, and complete decoupling of business logic from Flutter UI rendering frameworks and external backend services.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER UI LAYER                               │
│            Widgets, Screens, Custom Painters, Material 3 Theme           │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      RIVERPOD PRESENTATION LAYER                         │
│         AsyncNotifier, StateNotifier, State & Value Controllers          │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                            DOMAIN LAYER                                  │
│              Entities, Value Objects, Use Cases, Interfaces              │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                             DATA LAYER                                   │
│            Repositories, Data Sources, DTO Mappers, Local Caches         │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           EXTERNAL SERVICES                              │
│       Firebase Auth, Cloud Firestore, Firebase Storage, Gemini API       │
└──────────────────────────────────────────────────────────────────────────┘
```

### Design Philosophy
1. **Frictionless Latency ($< 3.0$s End-to-End):** AI food camera processing executes via compressed client payloads and direct serverless Cloud Functions, returning structured nutrition data in under 3 seconds.
2. **Offline-First Resilience:** Local optimistic UI state updates ensure the user never waits for network round-trips to update daily calorie progress rings or water logs.
3. **Immutability & Reactive Streams:** UI screens consume immutable state models exposed via Riverpod providers, preventing accidental state mutations.

---

## 2. Technology Stack

| Layer / Responsibility | Technology / Package | Specification |
| :--- | :--- | :--- |
| **Frontend Framework** | **Flutter** (Latest Stable) | Cross-platform client for iOS 15+ & Android API 26+ |
| **Language** | **Dart 3.x** | Null-safety, pattern matching, records |
| **State Management** | **flutter_riverpod** | Version 2.x declarative reactive providers |
| **Code Generation** | **freezed**, **json_serializable** | Immutable domain entities and JSON DTOs |
| **Navigation** | **go_router** | Declarative router with deep linking & auth guards |
| **Backend & Cloud** | **Firebase Ecosystem** | Authentication, Cloud Firestore, Cloud Storage |
| **AI Vision Engine** | **Google Gemini Multimodal API** | `gemini-3.8-flash` / `gemini-3.5-flash` |
| **In-App Purchases** | **Purchases_flutter (RevenueCat)** | Apple IAP & Google Play Billing abstraction |
| **Camera & Image** | **camera**, **image_picker**, **image** | Viewfinder capture & client JPEG compression |
| **Charts & Graphics** | **fl_chart** | Custom weight trend spline & calorie bar charts |
| **Local Storage** | **shared_preferences**, **hive_flutter** | Fast key-value & local JSON document cache |
| **Networking** | **dio** | Interceptor-capable HTTP client for Cloud Functions |
| **Logging** | **logger**, **firebase_crashlytics** | Local debug logs & production error aggregation |
| **Testing Harness** | **flutter_test**, **mocktail** | Unit, widget, and repository mocking |

---

## 3. Project Folder Structure

FitFuel employs a **Feature-First Clean Architecture** folder taxonomy:

```
lib/
├── core/
│   ├── config/
│   │   ├── env_config.dart
│   │   ├── routes.dart
│   │   └── theme.dart
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   └── firebase_constants.dart
│   ├── errors/
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   └── network_info.dart
│   ├── services/
│   │   ├── analytics_service.dart
│   │   ├── firebase_auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── gemini_ai_service.dart
│   │   ├── image_processing_service.dart
│   │   └── storage_service.dart
│   ├── utils/
│   │   ├── formatters.dart
│   │   ├── tdee_calculator.dart
│   │   └── validators.dart
│   └── widgets/
│       ├── fitfuel_button.dart
│       ├── fitfuel_card.dart
│       ├── fitfuel_macro_ring.dart
│       ├── fitfuel_text_field.dart
│       └── glassmorphic_container.dart
├── features/
│   ├── authentication/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── dashboard/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── scanner/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── meal_history/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── water/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── progress/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── profile/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── settings/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── premium/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

---

## 4. Clean Architecture Layer Specification

```
   Presentation Layer (UI + Riverpod Controllers)
              │ (depends on)
              ▼
   Domain Layer (Entities + Use Cases + Repository Interfaces)
              ▲ (implemented by)
              │
   Data Layer (DTOs + Data Sources + Repository Implementations)
```

1. **Presentation Layer:** Contains Flutter screens, reusable widgets, and Riverpod `AsyncNotifier` controllers. Receives user actions, invokes Use Cases, and rebuilds UI reactively upon state emissions.
2. **Domain Layer:** The pure Dart core of the application. Contains domain entities (`Meal`, `UserProfile`), business rules (`TDEECalculator`), abstract repository contracts, and Use Cases. Zero external package dependencies (no Flutter or Firebase imports).
3. **Data Layer:** Implements Domain Repository contracts. Manages remote Firestore data sources, local Hive caches, and maps raw DTOs (`MealModel`) to domain entities (`Meal`).

---

## 5. Feature Module Architecture

Every feature module follows a strict 3-tier subfolder layout. Below is the specification across all 10 core features:

```
feature_module/
├── data/
│   ├── datasources/
│   │   ├── feature_remote_datasource.dart
│   │   └── feature_local_datasource.dart
│   ├── models/
│   │   └── feature_model.dart (JSON DTO)
│   └── repositories/
│       └── feature_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── feature_entity.dart
│   ├── repositories/
│   │   └── i_feature_repository.dart
│   └── usecases/
│       └── perform_feature_action.dart
└── presentation/
    ├── controllers/
    │   └── feature_controller.dart (Riverpod AsyncNotifier)
    ├── screens/
    │   └── feature_screen.dart
    └── widgets/
        └── feature_card.dart
```

### Feature Module Registry
* **Authentication:** Login, Register, Social Auth, Forgot Password.
* **Dashboard:** Calorie rings, daily timeline, quick water box.
* **Scanner:** Viewfinder, camera shutter, Gemini AI payload parsing.
* **Nutrition / Scan Edit:** Portion sliders, ingredient macro recalculations.
* **Meal History:** Historical calendar picker, historical meal breakdowns.
* **Water:** Hydration intake logging (+250ml/500ml), fluid wave visualizer.
* **Progress:** Weight trend charts, calorie adherence metrics.
* **Profile:** User bio setup, goal updating, TDEE recalculation.
* **Settings:** Measurement unit toggles, notification preferences.
* **Premium:** RevenueCat paywalls, subscription tier unlocks.

---

## 6. State Management Strategy (Riverpod)

FitFuel uses **Riverpod 2.x** with code generation (`riverpod_generator`).

### 6.1 Provider Taxonomy Matrix

| Provider Type | Recommended Usage | Target Feature Scenario |
| :--- | :--- | :--- |
| **`AsyncNotifierProvider`** | Complex async states requiring user mutations | `DashboardController`, `ScannerController` |
| **`StreamProvider`** | Real-time database streams from Firestore | `dailySummaryStreamProvider`, `authSecurityStream` |
| **`FutureProvider`** | One-time async data fetches | `fetchFoodItemDetailsProvider` |
| **`Provider`** | Synchronous dependency injection | `firebaseAuthServiceProvider`, `dioClientProvider` |

### 6.2 State Lifecycle & Immutable UI States
UI controllers emit immutable states built using `Freezed`:

```dart
// Conceptual State Definition (No code execution)
// AsyncValue<DashboardState> represents:
// - AsyncLoading: Shows skeleton loading screen
// - AsyncData: Displays macro rings and daily timeline
// - AsyncError: Displays error snackbar or retry state
```

---

## 7. Repository Pattern Specification

Repositories decouple business logic from underlying database details.

### Repository Interface Contracts

1. **`AuthRepository`:** Handles `signInWithEmail`, `signInWithGoogle`, `registerUser`, `sendPasswordReset`, `signOut`, `deleteAccount`.
2. **`MealRepository`:** Handles `logMeal`, `fetchDailySummary`, `updateMealPortion`, `deleteMeal`, `streamTodaySummary`.
3. **`UserRepository`:** Handles `getUserProfile`, `createUserProfile`, `updateGoals`, `recalculateTDEE`.
4. **`WaterRepository`:** Handles `logWaterIntake`, `fetchDailyWaterTotal`.
5. **`ProgressRepository`:** Handles `logWeight`, `fetchWeightHistory`, `fetchCalorieAdherence`.
6. **`AIRepository`:** Handles `analyzeFoodImage`, `generateDailyInsight`.
7. **`SettingsRepository`:** Handles `getPreferences`, `updateUnitSystem`, `updateThemeMode`.

---

## 8. Service Layer Architecture

The service layer wraps external APIs and device hardware capabilities:

* **`FirebaseAuthService`:** Direct wrapper for Firebase Auth SDK operations.
* **`FirestoreService`:** Low-level Firestore CRUD wrapper enforcing timeouts and error mapping.
* **`StorageService`:** Uploads pre-compressed food scan images to `/users/{uid}/scans/`.
* **`GeminiAIService`:** Invokes Firebase Cloud Function `scanFood` endpoint passing Base64 image payloads.
* **`NotificationService`:** Configures FCM push triggers and local scheduled water reminders.
* **`AnalyticsService`:** Tracks user events (`scan_completed`, `paywall_viewed`) via Firebase Analytics.
* **`ImageProcessingService`:** Downscales camera images to 1024x1024 JPEG (~150KB) on-device before transmission.

---

## 9. Navigation Architecture (GoRouter)

FitFuel uses **GoRouter** for declarative navigation, deep linking, and route guards.

```
Route Tree:
/splash (SCR-01)
/welcome (SCR-02a)
├── /login (SCR-02b)
├── /register (SCR-02c)
└── /forgot-password (SCR-02d)
/onboarding (SCR-03)
/shell (Main Dashboard Tab Shell)
├── /dashboard (SCR-04)
├── /history (SCR-09)
├── /progress (SCR-10)
└── /profile (SCR-12a)
/camera-scanner (SCR-05) [Modal Push]
/scan-result (SCR-07) [Modal Push]
/premium (SCR-13) [Modal Sheet Push]
```

### Authentication Guards
A top-level GoRouter `redirect` callback observes `authStateProvider`. If an unauthenticated user attempts to access `/dashboard`, they are redirected to `/welcome`. If an authenticated user has not completed onboarding (`isOnboardingComplete == false`), they are locked to `/onboarding`.

---

## 10. Global Error Handling Strategy

FitFuel converts raw platform errors into domain-specific `Failure` objects:

```
[ Raw Exception (SocketException / FirebaseException) ]
                       │
                       ▼
[ Repository Exception Handler ] -> Converts to [ Failure ]
                       │
                       ▼
[ Riverpod Controller ] -> Emits AsyncError(Failure)
                       │
                       ▼
[ UI Layer ] -> Displays Human-Readable Error Snackbar / Banner
```

### Failure Taxonomy
* **`NetworkFailure`:** "Connection timeout. Please check your internet connection."
* **`AuthFailure`:** "Invalid email or password."
* **`AIScanFailure`:** "Unable to recognize food item. Please try again or search manually."
* **`PermissionFailure`:** "Camera permission required to take food photos."

---

## 11. Offline Strategy

1. **Firestore Persistence:** Native offline persistence enabled (`Settings(persistenceEnabled: true)`).
2. **Optimistic UI Updates:** Water additions and weight logs write to the local cache instantly; progress rings update in under 50ms while background workers handle cloud synchronization.
3. **Offline Image Queue:** If a scan is taken offline, the compressed photo is cached locally in Hive until network connectivity is re-established.

---

## 12. Performance Optimization Plan

* **Image Compression:** Client-side downscaling to 1024x1024 @ 80% JPEG quality before network transfer.
* **Widget Optimization:** `const` constructors enforced across all UI components; custom painters for progress rings prevent unnecessary layout rebuilds.
* **Pagination:** Cursor-based pagination (`startAfterDocument`, limit 20) for historical weight and meal lists.
* **Memory Management:** Auto-dispose providers (`@riverpod`) release memory when screens are popped from navigation stack.

---

## 13. Security Architecture & Secrets Management

* **Zero Binary Secrets:** Gemini API keys and GCP credentials are held strictly inside Firebase Cloud Function secrets. The Flutter client binary contains zero API secret keys.
* **App Check Enforcement:** Firebase App Check with **Play Integrity (Android)** and **DeviceCheck (iOS)** validates app binary authenticity.
* **Secure Local Storage:** Auth refresh tokens and local sensitive preferences stored via **Flutter Secure Storage** (AES-256 Encrypted SharedPreferences on Android, Keychain on iOS).

---

## 14. Logging, Telemetry & Monitoring

* **Production Crash Reporting:** **Firebase Crashlytics** logs uncaught exceptions, stack traces, and custom keys (`userId`, `activeScreen`).
* **Local Debug Logger:** `logger` package used for colorized console output in development builds (disabled in release mode).
* **Performance Telemetry:** **Firebase Performance Monitoring** tracks app startup latency, Cloud Function network calls, and screen frame drops.

---

## 15. Dependency Management & Package Governance

All dependencies in `pubspec.yaml` are pinned to explicit version bounds:

```yaml
# Conceptual Dependency Governance
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^13.2.0
  firebase_core: ^2.30.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  purchases_flutter: ^8.0.0
  fl_chart: ^0.67.0
```

---

## 16. Environment Configuration & Build Flavors

FitFuel defines three distinct build environments via compile-time `--dart-define-from-file`:

1. **Development (`dev`):** Connects to local Firebase Emulators (`localhost:8080`).
2. **Staging (`stage`):** Connects to isolated staging Firebase project (`fitfuel-stage`).
3. **Production (`prod`):** Connects to live production Firebase project (`fitfuel-prod`).

---

## 17. Comprehensive Testing Strategy

FitFuel targets a **80%+ code coverage** minimum across business logic layers:

```
        / \
       /   \     Integration Tests (10%) - Full App Flows & Emulators
      /     \
     /-------\   Widget Tests (30%) - UI Cards, Sliders, Screen Layouts
    /---------\
   /-----------\ Unit Tests (60%) - TDEE Calculator, Repositories, BLoC/Notifier
```

### Mocking Harness
Uses `mocktail` to stub `FirebaseAuthService`, `FirestoreService`, and `GeminiAIService` responses during automated test runs.

---

## 18. CI/CD Pipeline (GitHub Actions)

Every pull request to `main` triggers automated GitHub Action workflows:

```
[ Code Push / PR ] 
       │
       ├─► Step 1: Flutter Analyze & Linter Check
       ├─► Step 2: Run Unit & Widget Tests (Coverage Report)
       ├─► Step 3: Build Android App Bundle (.aab) & iOS IPA
       └─► Step 4: Deploy to Firebase App Distribution / TestFlight
```

---

## 19. Coding Standards & Lint Rules

Strict linting enforced via `very_good_analysis` rules:
* **Class Names:** `PascalCase` (`FitFuelMacroRing`).
* **File & Folder Names:** `snake_case` (`fitfuel_macro_ring.dart`).
* **Variables & Functions:** `camelCase` (`totalCaloriesConsumed`).
* **Constants:** `lowerCamelCase` (`appPrimaryColor`).

---

## 20. Development Workflow & Git Branching

Adopts **GitFlow Branching Model**:
* `main`: Production release branch.
* `develop`: Staging integration branch.
* `feature/feature-name`: Isolated feature development branches.
* `hotfix/bug-name`: Production bugfix patches.

---

## 21. Future Scalability Architecture

The clean modular architecture guarantees effortless feature additions:
* **Barcode Scanner:** Simply plug `mobile_scanner` into `features/scanner/data`.
* **AI Coach Chat:** Add `features/ai_coach` with a new Riverpod notifier.
* **Wearable HealthKit Sync:** Add `HealthKitService` implementing a new data source contract under `features/progress`.

---

## 22. Engineering Checklist

- [x] Feature-First Clean Architecture folder structure verified.
- [x] Riverpod provider state management strategy specified.
- [x] GoRouter navigation hierarchy & security guards designed.
- [x] Client-side image compression & Gemini API function contract mapped.
- [x] Firebase offline persistence & error handling strategy integrated.
- [x] Zero-secret binary security policy enforced.

---

## 23. End-to-End System Architecture Diagram

```mermaid
flowchart TD
    subgraph Client [Flutter Mobile Client Application]
        UI[Flutter Material 3 UI Screens]
        RP[Riverpod AsyncNotifiers & Controllers]
        UC[Domain Use Cases & TDEE Rules]
        REPO[Data Repositories]
        LOCAL[Hive Local Offline Cache]
    end

    subgraph Firebase [Firebase Cloud Backend Engine]
        AUTH[Firebase Auth - JWT Token Service]
        FS[Cloud Firestore Database Engine]
        ST[Firebase Storage Bucket - JPEG Media]
        CF[Firebase Cloud Functions Node.js Engine]
    end

    subgraph AI [Google Cloud Platform AI Service]
        GEMINI[Google Gemini 1.5/2.0 Flash Vision API]
    end

    UI -->|User Interactions| RP
    RP -->|Invoke Logic| UC
    UC -->|Fetch/Mutate| REPO
    REPO <-->|Read/Write Cache| LOCAL
    REPO <-->|Network Stream| FS
    REPO -->|Authenticate| AUTH
    REPO -->|Upload Media| ST
    REPO -->|HTTPS Callable| CF
    CF -->|Base64 Multimodal Payload| GEMINI
    GEMINI -->>|Structured JSON Response| CF
    CF -->>|Sanitized Nutrition Data| REPO
```

---
*End of Master Technical Architecture Specification.*
