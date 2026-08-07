# FitFuel 🥗⚡
**AI-Powered Nutrition, Calorie Tracking & Healthy Eating Mobile Assistant**

FitFuel is an enterprise-grade mobile application built with Flutter, Riverpod, Clean Architecture, and Google Gemini Vision AI to enable instant sub-5-second meal logging via camera snapshots.

---

## 📚 Technical Documentation Index

1. [Software Planning Document](SOFTWARE_PLANNING_DOCUMENT.md)
2. [UI/UX Design Specification](FITFUEL_UI_UX_DESIGN_SPECIFICATION.md)
3. [Design System Specification](FITFUEL_DESIGN_SYSTEM.md)
4. [Figma Blueprint & Prototype Map](FIGMA_DESIGN_SYSTEM_AND_PROTOTYPE_SPECIFICATION.md)
5. [Authentication & Data Architecture](AUTHENTICATION_AND_DATA_ARCHITECTURE.md)
6. [Cloud Firestore Database Design](DATABASE_DESIGN.md)
7. [Master Technical Architecture Blueprint](TECHNICAL_ARCHITECTURE.md)

---

## 🛠️ Architecture Stack

* **Client:** Flutter 3.x / Dart 3.x
* **State Management:** Riverpod 2.x (`flutter_riverpod`)
* **Architecture Paradigm:** Feature-First Clean Architecture
* **Navigation:** `go_router` 13.x
* **Backend Platform:** Firebase Serverless (Auth, Firestore, Storage, Messaging, Analytics, Crashlytics)
* **AI Engine:** Google Gemini Vision 1.5/2.0 Flash API

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Version $\ge$ 3.16.0)
* Dart SDK (Version $\ge$ 3.2.0)
* Android Studio / Xcode

### Setup Instructions
1. Clone repository and navigate to root:
   ```bash
   cd FitFuel
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Copy environment configuration:
   ```bash
   cp .env.example .env
   ```
4. Launch local development app:
   ```bash
   flutter run
   ```

---
*FitFuel Mobile App Foundation — Production Architecture Ready.*
