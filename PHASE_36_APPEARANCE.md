# Phase 36.1 — Appearance preference

Implemented 2026-09-09 as the first bounded Phase 36 sub-phase.

Profile contains System, Light and Dark choices. The application reads the preference through a Riverpod AsyncNotifier, domain repository, and SharedPrefsService-backed repository implementation. It uses the existing light/dark themes and preserves Light as the default for absent or invalid settings. System mode follows device brightness changes.

The setting belongs to the device and contains no account or health data. No Firestore collection, rule change, package, or remote deployment is required. Failed writes retain the previous theme and report failure; loading failures can be retried.

Tests cover missing/invalid settings, persistence through repository recreation, failed-write recovery, 320px/1.4x settings layout, and application dark/system brightness behavior.

## Remaining Phase 36 work

- Streaks and ten milestones already exist in Progress Center; no duplicate achievement engine was introduced.
- NotificationServiceImpl is still a debug-print stub, not working push delivery. Scheduling, permissions, platform configuration and real-device delivery remain to implement and verify.
- Recursive account deletion through a trusted backend remains open. No function was created or deployed in this sub-phase.
- Other suggestions in the handoff remain backlog, including voice/barcode input, health sync, subscriptions and localization.

This sub-phase enables the existing dark theme; a complete contrast audit of every feature and native device acceptance testing are still separate checks.

Verification: flutter analyze reported No issues found. Full flutter test passed 476 tests (471 after Phase 35.1 plus five appearance tests). The dedicated Phase 35.1 UI suite passed 17 tests. No production deployment or native-device acceptance run was performed.
