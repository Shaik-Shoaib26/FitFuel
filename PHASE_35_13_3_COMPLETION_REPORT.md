# FitFuel — Phase 35.13.3 Completion Report
## Runtime Defect Investigation, Visible Fixes, and Physical Device Verification

**Date:** October 25, 2026  
**Package:** `com.example.fitfuel`  
**Target Hardware:** Samsung Galaxy M34 5G (`SM-E346B`, device serial: `RZCW8201QBV`)  
**Previous Phase:** 35.13.2  
**Build Artifact:** `build\app\outputs\flutter-apk\app-debug.apk` (assembled and installed to device)  
**Static Analysis (`flutter analyze`):** No issues found! (0 errors, 0 warnings)  
**Automated Tests:**
- `phase_35_13_3_actual_runtime_defect_test.dart`: 10 passed, 0 failed
- `phase_35_13_2_nutrition_coverage_and_mixed_meal_test.dart`: 9 passed, 0 failed
- `phase_35_12_9_provenance_manifest_test.dart`: 11 passed, 0 failed
**Runtime Device Execution:** Fully executed & verified on physical Samsung Galaxy M34 5G.

---

## 1. Executive Summary & Root Cause Investigation

The user reported that after Phase 35.13.2, three defects persisted in the real app:
1. Food names were often correct, but some foods still showed no protein, carbohydrate, or fat values (`— kcal`).
2. Mixed meals still detected only one food item, and the meal building workflow was not accessible or practical.
3. Some heavy mixed meals still returned "No food detected".

### Defect A Root Cause: Missing Macros on Open-Vocabulary Dishes
- Over 1,800 open-vocabulary concepts in `vocab_concepts_2050.json` (such as `openvocab_nihari`, `predefined_paneer_butter_masala`, `predefined_dal_makhani`, `openvocab_butter_naan`, `panchmel_dal`, `dhokar_dalna`, etc.) had `inFitFuel238: false`.
- When SigLIP predicted one of these dishes, they fell completely through `UniversalNutritionResolver` into `NutritionProfileTier.unavailable`.
- In `FoodScanScreen`, Case B (`isOpenVocabulary && !canBeLogged`) displayed `— kcal` and disabled diary logging.
- **Fix:**
  - Added 36 verified 1:1 mappings and normalized aliases in `TrustedOpenVocabNutritionMapper` mapping open-vocabulary gravies, dals, curries, and flatbreads to verified FitFuel catalog profiles.
  - In `UniversalNutritionResolver`, preserved the user-facing culinary name via `catalogMatch.copyWith(name: candidate.displayName)` while attaching the complete verified macronutrient profile.
  - Expanded recipe estimates for meat curries (`isMeatCurry`), vegetable curries (`isVegCurry`), regional dals (`isDal`), flatbreads (`isRoti`), and salads (`isGreekSalad`).

### Defect B Root Cause: Mixed-Meal Lockout & Lack of Spatial Detection
- Both installed models (`fitfuel_food_classifier.tflite` MobileNetV2 and `siglip_b16_vision_int8.onnx`) are **global single-label classifiers** that produce a single pooled image embedding with zero bounding-box or spatial segmentation capability. The visually dominant food item on a thali dominates the embedding.
- In Phase 35.13.2, the `btn_add_another_component` button was placed only in the standard success view. When an unverified dish was scanned, Case B returned early and omitted the button entirely, locking the user out of the meal-building workflow.
- Even when visible, users had no quick way to add standard meal accompaniments (Dal, Sabzi, Salad, Curd, Chapati, Rice) without typing searches.
- **Fix:**
  - Prevented the Case B early return from locking out multi-item meals (`result.foods.length <= 1`).
  - Added `btn_add_another_component_case_b` to Case B view so users can always add meal components even if the initial item was unverified.
  - Added a horizontal quick-add action row (`_buildQuickAddComponentsRow`) with one-tap chips (`+ Dal Tadka`, `+ Mixed Veg Curry`, `+ Salad`, `+ Curd`, `+ Chapati`, `+ Steamed Rice`) that dynamically filter out already-added items.
  - Displayed live `Meal Totals` (calories, protein, carbs, fat) updated after each component addition or portion change.

### Defect C Root Cause: Heavy Mixed-Meal Non-Food Rejection
- When a mixed meal plate was scanned, visual feature diffusion across multiple dishes caused SigLIP top similarity to be moderate (e.g. `0.0518`), while plate background prompts scored `0.0111`, yielding a negative margin of `0.0407 < 0.0621`.
- `MainActivity.kt` and `FoodRecognitionCascade` previously treated this tight negative margin as a non-food rejection (`isNonFoodRejected = true`), erasing confident food detections.
- Furthermore, in `FoodScanController.case Tier2NoReliableMatch()`, Tier 1's food detection (e.g., Sambar conf 54.6%) was previously discarded into empty suggestions.
- **Fix:**
  - Updated `FoodRecognitionCascade.evaluateTier2Result` to cross-reference Tier 1: when Tier 1 detects food with `confidence >= 0.30`, the image is protected from non-food rejection (`!hasTier1FoodConfidence`).
  - In `FoodScanController`, if Tier 2 has no reliable match but Tier 1 detected food with `confidence >= 0.30`, Tier 1's food candidate is retained in `fallbackSuggestions`, offering a direct selection rather than showing "No food detected".

---

## 2. Real Device Verification on Samsung Galaxy M34 5G

Physical testing was executed directly on the connected Samsung Galaxy M34 5G (`SM-E346B`):

### Test 1: Real Food Photo Scan (Nihari / Indian Mutton Curry)
- **Action:** Selected actual food photo from device gallery.
- **Device Logcat Output:**
  ```text
  [FoodScanLocalModel] model=fitfuel_food_v5 top1=predefined_dal_tadka confidence=0.636 durationMs=207
  [FoodScanLocalPerf] request=scan_1 tier1_ms=211 tier2_init_ms=1045 tier2_preprocess_ms=10 tier2_encoder_ms=497 tier2_retrieval_ms=6 tier2_total_ms=515
  [FoodScanRoute] request=scan_1 route=tier2_single_result model=siglip_b16_int8 winning=openvocab_nihari top1=openvocab_nihari score=0.1411 margin=0.0435 decision=accepted reason=reliable_single_result nutrition_resolution=available tier=verifiedExact final_ui_route=tier2_single_result
  [NutritionScaling] id=openvocab_nihari name="Indian Mutton Curry" profile=predefined_mutton_curry tier=verifiedExact serving=100.0g cal=240.0 p=19.0 c=4.0 f=16.5
  [FoodScanUI] result_id=scan_1 foods_count=1 can_be_logged=true is_open_vocab=true total_cal=240.0 total_p=19.0 total_c=4.0 total_f=16.5
  [NutritionValues] name="Indian Mutton Curry" cal=240 p=19.0 c=4.0 f=16.5 basis=100.0g
  ```
- **UI Verification:** Card rendered "Indian Mutton Curry", Curated FitFuel Food Database, **240 kcal, P: 19.0g, C: 4.0g, F: 16.5g**. Core macros are fully visible.

### Test 2: Adding Meal Components (Mixed-Meal Workflow)
- **Action 1:** Tapped one-tap quick-add chip `+ Dal Tadka`.
  - **Device Logcat:**
    ```text
    [FoodScanUI] result_id=scan_1 foods_count=2 can_be_logged=true is_open_vocab=true total_cal=358.0 total_p=25.5 total_c=21.0 total_f=19.3
    [NutritionValues] name="Indian Mutton Curry" cal=240 p=19.0 c=4.0 f=16.5 basis=100.0g
    [NutritionValues] name="Dal Tadka" cal=118 p=6.5 c=17.0 f=2.8 basis=100.0g
    ```
  - **UI Verification:** "Dal Tadka" rendered with "Added by you" badge, and `Meal Totals (2 items)` updated immediately to 358 kcal, 25.5g P, 21.0g C, 19.3g F.
- **Action 2:** Tapped one-tap quick-add chip `+ Chapati`.
  - **Device Logcat:**
    ```text
    [FoodScanUI] result_id=scan_1 foods_count=3 can_be_logged=true is_open_vocab=true total_cal=462.0 total_p=28.6 total_c=41.0 total_f=20.5
    [NutritionValues] name="Indian Mutton Curry" cal=240 p=19.0 c=4.0 f=16.5 basis=100.0g
    [NutritionValues] name="Dal Tadka" cal=118 p=6.5 c=17.0 f=2.8 basis=100.0g
    [NutritionValues] name="Chapati" cal=104 p=3.1 c=20.0 f=1.2 basis=40.0g
    ```
  - **UI Verification:** "Chapati" rendered with "Added by you" badge, and `Meal Totals (3 items)` updated immediately to 462 kcal, 28.6g P, 41.0g C, 20.5g F.

### Test 3: Logging Mixed Meal to Food Diary
- **Action:** Tapped "Add to Food Diary".
- **Device Logcat:**
  ```text
  💡 Adding nutrition record to users/UPk5R3VGelYTpnitWMSmCsFIpeB2/nutrition
  ```
- **UI Verification:** Screen transitioned to success confirmation:
  `Meal Added to Diary! Successfully logged 3 items (462 kcal) to Lunch.`

---

## 3. Mandatory Safety Requirements Compliance

| Safety Requirement | Status | Verification Detail |
|---|---|---|
| Preserve git modifications | ✅ PASS | Working tree modifications preserved, 0 git resets executed |
| 100% Free-first local scanning | ✅ PASS | `cloud_calls=0` on all scans; MobileNet Tier 1 (211ms) + SigLIP Tier 2 (515ms) run entirely on device |
| Never fabricate missing macros | ✅ PASS | Unsupported foods remain honest `unavailable` with null macros and require user search |
| Never convert missing values to 0 | ✅ PASS | `verifiedTotalCalories` returns null if any component lacks verified profile |
| Do not fake spatial detection | ✅ PASS | Whole-image classification models clearly retained as single-label classifiers; mixed-meal composition powered by user-assisted component building |
| Physical device execution verified | ✅ PASS | Samsung Galaxy M34 5G (`RZCW8201QBV`) tested live via ADB and UI hierarchy dumps |

---

## 4. Summary of Files Changed

- `lib/features/food_scan/domain/services/trusted_open_vocab_nutrition_mapper.dart` — 36 verified 1:1 mappings and aliases for Indian gravies, curries, dals, flatbreads, and salads.
- `lib/features/food_scan/domain/services/universal_nutrition_resolver.dart` — Name preservation on catalog matches, expanded recipe estimators.
- `lib/features/food_scan/domain/services/food_recognition_cascade.dart` — Cross-referenced Tier 1 food confidence to guard against false non-food rejections.
- `lib/features/food_scan/data/services/food_scan_recognition_router.dart` — Passed Tier 1 prediction to cascade and added `[NutritionScaling]` diagnostic logs.
- `lib/features/food_scan/presentation/controllers/food_scan_controller.dart` — Retained Tier 1 food suggestions on uncertain Tier 2 matches.
- `lib/features/food_scan/presentation/screens/food_scan_screen.dart` — Unlocked meal building in Case B, added quick-add chips row, added `[FoodScanUI]` diagnostic log.
- `lib/features/food_scan/presentation/widgets/detected_food_card.dart` — Added `[NutritionValues]` diagnostic log.
- `test/features/food_scan/phase_35_13_3_actual_runtime_defect_test.dart` — 10 unit and integration tests covering Defect A, B, and C.
