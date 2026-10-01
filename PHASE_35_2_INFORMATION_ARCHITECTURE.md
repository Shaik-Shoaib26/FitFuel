# FitFuel — Phase 35.2 information architecture

The approved restructuring gives each major feature a home while preserving the existing repositories, calculations, Firebase collections and AI integration. Pre-existing work in this checkout is retained.

## Navigation

| Screen width | Primary navigation | AI and account access |
| --- | --- | --- |
| Under 600px | Home, Health, Nutrition, Plan, Progress bottom navigation | AI and Profile actions in the header; Settings through Profile |
| 600–1023px | NavigationRail with the five domains and AI Coach | Profile and Settings rail actions |
| 1024px and wider | Expanded sidebar with the five domains and AI Coach | Profile and Settings at the bottom |

AI uses its own retained branch. Mobile AI has a return action to the previously selected domain. Profile and Settings are utility routes above the shell. Content pages use constrained widths appropriate to their existing layouts, rather than stretching cards across the desktop.

## Canonical destinations

| Domain | Routes and ownership |
| --- | --- |
| Home | `/home`: greeting, shared calorie/macronutrient summary, hydration summary, one daily focus, four quick actions, next routine task/meal, compact wellness/activity/habit summary |
| Health | `/health`: water, exercise, habits and wellness; `/health/weight`: measurement entry and history |
| Nutrition | `/nutrition`: today's diary and nutrition summary; `/nutrition/log`; `/nutrition/log/:recordId/edit`; `/nutrition/search`; `/nutrition/food/:id`; `/nutrition/custom/new`; `/nutrition/custom/:id/edit` |
| Plan | `/plan`: hub; `/plan/meals`; `/plan/smart-eat`; `/plan/routine`; `/plan/grocery`; `/plan/grocery/pantry` |
| Progress | `/progress`: existing consistency, milestone and trend overview; `/progress/analytics`; `/progress/analytics/nutrition`; `/progress/weekly-report`; `/progress/insights`; `/progress/insights/health` |
| AI Coach | `/ai`, with optional `prompt` query parameter |
| Profile and Settings | `/profile`; `/settings`; `/settings/goals`; `/settings/preferences`; `/settings/reminders`; `/settings/account` |

Food Library collections use `?view=favorites`, `recent`, `custom`, or `recipes`. Recipes belong to the planning journey and open the existing food detail destination with `?section=recipe`. Food IDs resolve through the existing repository; missing records show an unavailable state instead of requiring an in-memory route extra.

Health section links use `?section=hydration`, `exercise`, `habits`, or `wellness`. Exercise quick entry adds `&action=add`. Small health features stay grouped instead of creating five nearly identical pages.

Old URLs are retained as redirects in `feature_action_navigation.dart`, including Dashboard, Food Search, Meal Planner, Smart Eat, Grocery, Pantry, Analytics, Weekly Report and AI Assistant. Legacy food-detail/custom-food extras are translated to ID routes where available.

## Reuse and state

- `StatefulShellRoute.indexedStack` owns six retained branch navigators. Switching tabs restores a branch's child page and widget state. Responsive shell changes keep the branch workspace mounted.
- The router remains stable for repeated auth emissions with the same UID. An account transition replaces its navigation stacks; protected deep links survive the sign-in redirect. Disposed auth refresh callbacks are guarded.
- Existing feature providers remain above the shell. No second planner, Smart Eat, grocery, AI or health controller is introduced.
- Analytics and Insights refresh their existing controllers when source streams change, preserving range/filter selections. Request generations prevent older asynchronous results from replacing newer ones.
- Grocery selection survives list refreshes until the selected list disappears. Grocery and Pantry share a page identity; URL changes update the tab without resetting the screen.
- Dashboard's diary editing UI moved into Nutrition and reuses `FoodFormSheet`. Home and Nutrition share a read-only `NutritionSummary`.
- Weight entry moved to Health. Progress reuses `WeightPanel` in read-only mode, retaining the original trend presentation and calculation.
- Reconnect refresh coordination moved out of Dashboard into `SessionRefreshCoordinator`. Existing planner and Smart Eat reconnect listeners remain responsible for their own work.
- Account controls moved into Settings. Existing authentication operations are reused. Confirmation no longer tries to use a dismissed dialog's context.
- Existing specialist screens and tests were retained. The existing Smart Eat recipe sheet remains available with its serving controls; no recipe algorithm or data migration was introduced.

## Principal files

New presentation infrastructure: `lib/app/navigation/`, `lib/app/session/`, `lib/core/widgets/adaptive_page_layout.dart`.

New destinations/components: Plan and Settings screens; Nutrition screen, routed food-log screen and shared summary; food-by-ID route screen; Health weight screen and shared weight panel.

Modified: GoRouter configuration, Dashboard composition, existing screen headers/actions, Profile organization, Health section navigation, Grocery URL/tab synchronization, Analytics/Insights provider refresh coordination.

Domain algorithms, remote datasources, Firestore structure and Gemini integration were not restructured by this phase.

## Verification

The complete test suite passed: **489 tests**, including all **476 pre-existing tests** and **13 new tests**. No tests were deleted.

New coverage is in:

- `test/features/ui/navigation_architecture_test.dart`: five mobile destinations, tablet rail, desktop sidebar, 320/768/1440px at 1.4 text scale, retained drafts and child stacks across tab changes/resizing, direct child back navigation, AI return behavior and legacy query preservation.
- `test/features/ui/navigation_state_test.dart`: production route inventory, same-UID router stability/account-switch resets, analytics range/controller preservation and grocery selection preservation.
- `test/features/ui/production_navigation_test.dart`: protected deep-link sign-in, removal of private pages on sign-out, real Health/Nutrition/Plan/Grocery screens at 320/1440px and 1.4 scaling, Grocery/Pantry state identity and platform route-information updates.

Platform route-information tests exercise the event used for browser history updates; they are not a live browser end-to-end test. Live Firebase account deletion, authenticated production writes and Gemini requests were not performed as part of this presentation-only validation.

`flutter analyze --no-pub` completed with **no issues found**. `flutter build web --no-pub` completed successfully and produced `build/web`. The optional Wasm dry run reports incompatibility in the existing secure-storage web dependencies; the standard JavaScript web build succeeds.

Validation logs: `navigation_regression.log`, `navigation_analyze.log`, and `navigation_web_build.log`. The repository-wide whitespace check still reports trailing whitespace in pre-existing AI datasource/controller changes outside this navigation phase.
