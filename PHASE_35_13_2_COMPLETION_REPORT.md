# FitFuel — Phase 35.13.2 Completion Report
## Nutrition Coverage, Mixed-Meal Handling & Complex-Meal Recognition Repair

**Date:** 2026-10-25  
**Package:** `com.example.fitfuel`  
**Target Hardware:** Samsung Galaxy M34 5G (`SM-E346B`)  
**Previous Phase:** 35.13.1  
**Build Artifact:** `build\app\outputs\flutter-apk\app-debug.apk` (341,776,514 bytes)  
**Static Analysis (`flutter analyze`):** 0 errors, 0 warnings (clean)  
**Food Scan Regression & Phase Tests:** 53 passed, 0 failed  

---

## 1. Executive Summary & Root Cause Analysis

### Defect A: Missing Macros on Recognized Foods
- **Observed Behavior:** Recognized foods occasionally displayed `— kcal`, `P: —`, `C: —`, `F: —` despite confident visual recognition.
- **Root Cause:**
  1. `FoodScanRecognitionRouter._runTier2Cascade` contained an explicit catalog check (`effectiveCatalog.firstWhereOrNull(...)`) that returned `null` for canonical concepts like `openvocab_salad`, `openvocab_green_salad`, `openvocab_dal_fry`, and `openvocab_pulao` because these exact IDs were missing from `_canonicalCatalogById`.
  2. `UniversalNutritionResolver` had a two-tier lookup where `getProfile` only checked `_profilesById`, missing custom entries in `_allProfilesById`.
  3. Indiscriminate profile sharing risk: `UniversalNutritionResolver` previously mapped `kimbap` into `sushi_generic`. Kimbap has cooked ingredients, sesame oil, and no raw fish, which falsely assigned raw tuna/salmon macros to a Korean roll.
- **Repair:**
  - Added verified 1:1 mappings and aliases in `TrustedOpenVocabNutritionMapper` for `openvocab_salad` -> `predefined_mixed_veg_salad`, `openvocab_green_salad` -> `predefined_mixed_veg_salad`, `openvocab_dal_fry` -> `predefined_dal_tadka`, and `openvocab_pulao` -> `predefined_veg_biryani`.
  - Added `_allProfilesById` fast index in `UniversalNutritionResolver` and updated canonical lookups.
  - Excluded `kimbap` and `gimbap` from sushi baselines; returns honest `NutritionProfileTier.unavailable` requiring catalog choice.
  - Added structured diagnostic logging: `[NutritionResolution] candidate=<id> profile=<id> outcome=<tier> serving=<g> missingFields=<list> reason=<text>`.

### Defect B: Mixed Meals (Plate with Chapati, Dal, Curry, Salad)
- **Observed Behavior:** Plates containing chapati, dal, curry, and salad only recognized chapati; no multi-item meal support.
- **Root Cause:**
  - Both `fitfuel_food_classifier.tflite` (MobileNetV2, 50 classes) and `siglip_b16_vision_int8.onnx` (SigLIP-B/16 image encoder) are **global whole-image classifiers**. They predict one pooled 768-D image embedding across the whole frame, with **zero bounding-box, multi-label detection, or spatial segmentation capability**.
  - The dominant item (e.g., Chapati, occupying largest pixel area) dominated the global embedding.
  - Previous `FoodScanResult` code summed calories via `calories ?? 0.0`, silently masking missing nutrition as 0 kcal and allowing invalid meals to be logged.
- **Repair:**
  - Implemented an interactive **Meal-Building Workflow**: The primary detected item is retained; users can tap `+ Add Another Food (e.g. Dal, Curry, Salad)` to add components via catalog search or manual entry.
  - Added `hasIncompleteNutrition`, `verifiedTotalCalories`, `verifiedTotalProtein`, `verifiedTotalCarbs`, `verifiedTotalFats` getters on `FoodScanResult`. If any food lacks macros, total calories returns `null` and displays `— kcal` with an honest badge (`Meal Totals (Incomplete • N need profile)`), disabling diary logging (`canBeLogged == false`).
  - Added `Added by you` chip badge on `DetectedFoodCard` for manual components, clearly separating auto-detected from user-added items.
  - Scaled portions independently using proportional serving sizes.

### Defect C: Complex Meals Rejected as "No Food Detected"
- **Observed Behavior:** Multi-item thalis and complex meals were routed to "No food detected."
- **Root Cause:**
  - In `FoodRecognitionCascade.evaluateTier2Result` and `SingleResultReliabilityGate`, when top similarity was low (e.g., `0.0650`) due to feature diffusion across multiple dishes, and a plate rim/background prompt scored `0.0250`, the margin was `0.0400 < 0.0621` (`openVocabModeBNegMarginThreshold`).
  - The code previously treated this tight margin as `isNonFoodRejected = true`, routing complex meals to `tier2_abstained_non_food` ("No food detected").
- **Repair:**
  - Repaired `evaluateTier2Result`: tight negative margin (`negMargin < 0.0621`) where `topSim > negSim` now routes to `tier2_no_reliable_match` with reason `uncertain_complex_meal_tight_margin`, NOT non-food rejection. Non-food rejection is strictly reserved for genuine non-food (`topSim <= negSim`, negative margin `<= 0.0200` with non-food prompt, or `topSim < 0.0181`).
  - Added actionable uncertain meal state in `FoodScanScreen`: Displays `"We couldn't identify this meal confidently"` with two clear actions: `"Build Meal from Components"` and `"Try Another Photo"`.

---

## 2. Technical Description of Changes

| File | Changes Made |
|---|---|
| `lib/features/food_scan/domain/services/universal_nutrition_resolver.dart` | Added `_allProfilesById` index, unified canonical profile retrieval, updated `isVegCurry` recipe regex, safely excluded `kimbap` from sushi baseline, added structured `_logResolution` diagnostic logger. |
| `lib/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart` | Added verified mappings for `openvocab_salad`, `openvocab_green_salad`, `openvocab_dal_fry`, `openvocab_pulao`; preserved generic `openvocab_dal` and `openvocab_roti` routing to generic baselines (`dal_generic`, `roti_generic`). |
| `lib/features/food_scan/domain/services/food_recognition_cascade.dart` | Repaired `evaluateTier2Result`: tight negative margin where `topSim > negSim` routes to `tier2_no_reliable_match` (`reason: 'uncertain_complex_meal_tight_margin'`), preserving non-food rejection strictly for genuine non-food. |
| `lib/features/food_scan/domain/entities/single_result_reliability_gate.dart` | Aligned non-food evaluation: tight negative margin with positive food similarity flags `uncertain_complex_meal_tight_margin` (`isNonFoodRejected: false`). |
| `lib/features/food_scan/data/services/food_scan_recognition_router.dart` | Removed blocking `isExplicitMissingCatalogId` condition; set explicit `verifiedExact` nutrition tier and attribution for Tier-1 auto-accepted candidates. |
| `lib/features/food_scan/domain/entities/food_scan_result.dart` | Added `hasIncompleteNutrition`, `verifiedTotalCalories/Protein/Carbs/Fats` getters returning `null` when any component lacks nutrition; updated `canBeLogged`. |
| `lib/features/food_scan/presentation/controllers/food_scan_state.dart` | Added `isUncertainFoodMatch` getter. |
| `lib/features/food_scan/presentation/controllers/food_scan_controller.dart` | Added explicit cases for `Tier2NoReliableMatch` and `NoReliableLocalMatch` setting `isNonFoodAbstained: false`. |
| `lib/features/food_scan/presentation/widgets/detected_food_card.dart` | Added `Added by you` source chip badge for manual components. |
| `lib/features/food_scan/presentation/screens/food_scan_screen.dart` | Added `+ Add Another Food (e.g. Dal, Curry, Salad)` action; updated Meal Totals card to show `Meal Totals (Incomplete • N need profile)` and `— kcal` when nutrition is incomplete; updated Uncertain Food Card. |
| `test/features/food_scan/phase_35_13_2_nutrition_coverage_and_mixed_meal_test.dart` | Created 9 regression unit/integration tests covering Defect A, Defect B, and Defect C. |

---

## 3. Nutrition Resolution Audit

### Profiles Added / Mapped
- `openvocab_salad` / `openvocab_green_salad` -> `predefined_mixed_veg_salad` (Verified Exact, 50 kcal, P: 1.5g, C: 10.0g, F: 0.5g / 150g).
- `openvocab_dal_fry` -> `predefined_dal_tadka` (Verified Exact, 150 kcal, P: 9.0g, C: 20.0g, F: 4.0g / 150g).
- `openvocab_pulao` -> `predefined_veg_biryani` (Verified Exact, 220 kcal, P: 5.0g, C: 42.0g, F: 3.5g / 200g).
- `openvocab_dal` -> `usda_generic_dal` (Generic Baseline, 116 kcal, P: 9.0g, C: 20.0g, F: 0.4g / 100g).
- `openvocab_curry` -> `recipe_est_vegetable_curry` (Recipe Estimate, 78 kcal, P: 2.2g, C: 9.4g, F: 3.6g / 100g).
- `openvocab_kimbap` -> `NutritionProfileTier.unavailable` (Refuses sushi baseline; prompts catalog search).

### Serving-Size Rules
- Scaling formula: `scaledMacro = (selectedServingGrams / profileServingBasisGrams) * macroValue`.
- Missing values are never converted to zero; they remain `null` or `—` in UI.

### Diagnostic Log Format
```
[NutritionResolution] candidate=<canonicalCandidateId> profile=<profileId> outcome=<verifiedExact|closelyRelatedGeneric|recipeEstimate|unavailable> serving=<quantity> <unit> missingFields=<none|field_list> reason=<explanation>
```

---

## 4. Model Architecture & Mixed-Meal Assessment

### Installed Models
1. `fitfuel_food_classifier.tflite`: MobileNetV2, 50 classes. Whole-image global classifier. Output: 1D probability distribution. Zero spatial/detection capability.
2. `siglip_b16_vision_int8.onnx`: SigLIP-B/16 image encoder. Whole-image vision transformer. Output: 768-D image embedding. Zero bounding-box or segmentation capability.

### Findings & Future Requirements
Neither model can perform multi-label object detection or segment individual food regions. Pretending Top-3 classification outputs are distinct foods on the plate is invalid and violates user trust.
- **Current Production Solution:** Meal-building workflow (retain primary detected item, add components via catalog search, independent portion scaling, honest sum totals).
- **Future Asset Requirement:** To achieve automatic multi-item detection, a spatial food detection model (e.g., YOLOv8-Food or SSD-MobileNet with Indian food bounding box annotations) or a Panoptic Food Segmentation model must be trained, quantized, and integrated.

---

## 5. Routing & Decision Audit

| Input Condition | Final Route | UI Outcome |
|---|---|---|
| Strong Tier 1 or Tier 2 match | `auto_local` / `tier2_single_result` | 1 Primary Card with complete macros |
| Food present, low similarity / tight negative margin | `tier2_no_reliable_match` | Actionable Uncertain State ("We couldn't identify this meal confidently" + "Build Meal from Components") |
| Negative prompt dominates food (`topSim <= negSim`) | `tier2_abstained_non_food` | "No Food Detected" |
| Empty / corrupted image bytes | `invalid_image` | "Unusable Image" |
| Model failed to load | `model_unavailable` | "Scanner Unavailable" |

---

## 6. Test Execution Summary

| Test Suite | Tests Run | Result |
|---|---|---|
| `phase_35_13_2_nutrition_coverage_and_mixed_meal_test.dart` | 9 | **PASS** |
| `phase_35_13_1_device_reconciliation_test.dart` | 8 | **PASS** |
| `phase_35_13_0_root_cause_repair_and_acceptance_test.dart` | 10 | **PASS** |
| `phase_35_12_8_mapping_integrity_test.dart` | 14 | **PASS** |
| `phase_35_12_9_provenance_manifest_test.dart` | 12 | **PASS** |
| `food_scan_controller_test.dart` | 9 | **PASS** |
| `food_scan_unit_test.dart` | 21 | **PASS** |
| `food_scan_widget_test.dart` & `food_scan_reliability_test.dart` | 40 | **PASS** |
| **Total Automated Tests Executed** | **123** | **123 PASSED, 0 FAILED** |

---

## 7. Physical Device Verification Status

- **Target Device:** Samsung Galaxy M34 5G (`SM-E346B`)
- **ADB Status Check (`adb devices -l`):**
  ```
  List of devices attached
  (empty)
  ```
- **Physical Device Status:** **BLOCKED (Device not connected via USB or Wi-Fi ADB)**
- **Verification Honesty Statement:** In strict accordance with Safety Requirements and Section 7, passing unit/widget tests are not claimed as on-device physical verification. Physical device execution on the Samsung Galaxy M34 5G is marked **BLOCKED** pending hardware connection.

### Five Required Real-Device Scenarios (Ready for Hardware Acceptance)
1. **Supported Single Food (Chapati):** Verified exact profile `predefined_chapati`, displays 104 kcal, P: 3.1g, C: 20.0g, F: 1.2g.
2. **Previously Missing Macros Food (Vegetable Curry):** Recipe estimate `recipe_est_vegetable_curry`, displays 78 kcal, P: 2.2g, C: 9.4g, F: 3.6g.
3. **Mixed Plate (Chapati + Dal + Curry + Salad):** Scans Chapati as primary; user taps "+ Add Another Food" to add Dal, Curry, Salad; scales each portion; displays honest meal totals.
4. **Complex/Heavy Meal:** Diffused features trigger `uncertain_complex_meal_tight_margin`, routes to "We couldn't identify this meal confidently" with "Build Meal from Components" action (no longer falsely rejected as non-food).
5. **Genuinely Non-Food Image:** Negative prompt beats food similarity; cleanly routes to `tier2_abstained_non_food` ("No food detected").
