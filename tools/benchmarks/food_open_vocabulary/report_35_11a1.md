# FITFUEL — PHASE 35.11A.1: TRUE OPEN-VOCABULARY LOCAL FOOD RECOGNITION BENCHMARK REPORT

## 1. Executive Summary
- **Mission:** Evaluate whether a genuinely jointly trained, commercially usable, true image-text-aligned open-vocabulary vision-language model can run locally (with a precomputed text embedding index and vision-only runtime encoder) to recognize foods far beyond `fitfuel_food_v5`'s 50 fixed classes while preserving `provider API calls per scan = 0`.
- **Production Isolation:** Strictly benchmark-only (`tools/benchmarks/food_open_vocabulary/`). Zero changes were made to `fitfuel_food_v5`, `FoodScanController`, `FoodScanScreen`, `FoodScanRecognitionRouter`, `Food Diary`, or production routing.
- **Key Findings:**
  1. **Prior Phase 35.11A Semantic Bridge vs True Multimodal Alignment:** Phase 35.11A (`classifier features -> linear ridge bridge -> MiniLM-384D`) failed on unseen foods (`5.8%` Top-1 / `14.5%` Top-5) because a 50-class backbone discards visual distinctions outside its 50 training classes. In contrast, **Candidate C (`google/siglip-base-patch16-224`, Apache-2.0)** achieves **`44.70%` Exact Top-1, `62.21%` Exact Top-3, `69.12%` Exact Top-5, and `74.19%` Alias-Aware Top-5** on the untouched **Unseen-to-V5 Final Lockbox (`217` images across `158` unseen foods)**—exceeding the Phase 35.11A.1 target bar (`Unseen Top-5 >= 60%`, `Unseen Top-3 >= 45–50%`).
  2. **Smaller Mobile ViT Candidates (`TinyCLIP-ViT-40M/32` & `OpenCLIP-ViT-B/32`):**
     - **Candidate A2 (`wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M`, MIT, 39.69M vision params, `38.45 MB` INT8 / `76.11 MB` FP16):** Achieves **`29.49%` Exact Top-1, `37.79%` Exact Top-3, `44.24%` Exact Top-5 (`51.61%` Alias-Aware Top-5)** at **`47.42 ms` P50 CPU latency**.
     - **Candidate B (`laion/CLIP-ViT-B-32-laion2B-s34B-b79K`, MIT, 87.85M vision params, `84.50 MB` INT8 / `168.33 MB` FP16):** Achieves **`30.88%` Exact Top-1, `44.24%` Exact Top-3, `48.85%` Exact Top-5 (`57.60%` Alias-Aware Top-5)** at **`100.56 ms` P50 CPU latency**.
  3. **Pasta Regression Resolved:** On the 26-image Pasta Regression Suite (`Penne Pasta`, `Creamy Penne Pasta`, `Pasta Alfredo`, `Spaghetti`, `Spaghetti Bolognese`, `Tomato Pasta`, `Lasagna`, `Macaroni`, `Cheese Ravioli`), `fitfuel_food_v5` achieved `0.0%` exact accuracy and misclassified pasta as `Pineapple`, `Spinach`, `Grilled Chicken Breast`, or `Poha`. `SigLIP-B/16` achieved **`61.54%` Exact Top-5** and **`80.77%` Pasta-Family Top-5** with **`0.0%` absurd fruit/meat errors**.
  4. **Non-Food Holdout Safety:** With calibrated cosine similarity floor + negative non-food prompt margin, `SigLIP-B/16` achieved **`0.0%` False Acceptance Rate (`0/71` false accepts, `100.0%` abstention)** on the untouched Final Lockbox Non-Food Holdout (`< 1%` target met).
  5. **Recommendation:** **B — Promising offline candidate (`SigLIP-B/16` INT8/FP16 for accuracy; `TinyCLIP-ViT-40M/32` as compact mobile runner-up), but requires Samsung `RZCW8201QBV` on-device latency/RAM/thermal validation before Phase 35.11B integration.**

---

## 2. License Verification Table

| Candidate | Hugging Face / Official Repo | Model / Weight License | Code License | Commercial Use Allowed? | Redistribution Allowed? | Attribution Required? | Verification Source & Date | Gate Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline: `fitfuel_food_v5`** | `ml/checkpoints/fitfuel_food_v5.tflite` | Apache-2.0 / FitFuel | Apache-2.0 | YES | YES | Standard Apache-2.0 | Repo model card (2026-10-11) | **PASS (Active 50-Class)** |
| **Candidate A1: `TinyCLIP-ViT-8M/16`** | `wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M` | MIT (card); distilled on YFCC15M | MIT (`microsoft/Cream`) | CAUTION (YFCC15M contains CC BY-NC photos) | YES (MIT weights) | YES (MIT notice) | HF Hub API + `microsoft/Cream` LICENSE (2026-10-11) | **BENCHMARK ONLY — YFCC15M CAVEAT** |
| **Candidate A2: `TinyCLIP-ViT-40M/32`** | `wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M` | MIT License | MIT (`microsoft/Cream`) | **YES** | **YES** | YES (MIT copyright notice) | HF Hub API `license: mit` (2026-10-11) | **PASS — LICENSE** |
| **Candidate B: `OpenCLIP-ViT-B/32`** | `laion/CLIP-ViT-B-32-laion2B-s34B-b79K` | MIT License | MIT (`mlfoundations/open_clip`) | **YES** | **YES** | YES (MIT copyright notice) | HF Hub API `license: mit` (2026-10-11) | **PASS — LICENSE** |
| **Candidate C: `SigLIP-B/16`** | `google/siglip-base-patch16-224` | Apache-2.0 License | Apache-2.0 (`google-research/big_vision`) | **YES** | **YES** | YES (Apache-2.0 notice) | HF Hub API `license: apache-2.0` (2026-10-11) | **PASS — LICENSE** |
| **Candidate D: `MobileCLIP-S0 / S1 / S2`** | `apple/MobileCLIP-S0`, `timm/MobileCLIP2-S0-OpenCLIP` | Apple Machine Learning Research License (`apple-amlr`) | MIT (code) / `apple-amlr` (weights) | **NO** (Research & non-commercial only) | **NO** (Commercial redistribution prohibited) | N/A | Official `apple/MobileCLIP-S0` LICENSE (2026-10-11) | **REJECTED — LICENSE** |
| **Candidate E: `MetaCLIP-B/32-400M`** | `facebook/metaclip-b32-400m` | CC-BY-NC-4.0 | CC-BY-NC-4.0 | **NO** (Non-commercial only) | **NO** | N/A | HF Hub API `license: cc-by-nc-4.0` (2026-10-11) | **REJECTED — LICENSE** |

---

## 3. Candidate Architecture Table

| Candidate | Architecture Family | Vision Params | Text Params | Original Precision | Input Res | Embed Dim | Vision Encoder Size (FP32 / FP16 / INT8) | Runtime Format | Expected Mobile RAM | Text Encoder at Runtime? | Precomputed Text Index? | Android Feasibility |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`fitfuel_food_v5`** | MobileNetV3-Large (50-class closed-set) | 4.21M | 0M | FP32 | `224x224` | 50 logits | `5.85 MB` (TFLite) | TFLite XNNPACK | ~28 MB | No | N/A (Fixed 50) | Production active |
| **Phase 35.11A Bridge** *(Prior Rejected)* | EfficientNet-B0 -> Ridge Bridge -> MiniLM | 5.29M | 22.7M | FP32 | `224x224` | 384-D | `15.80 MB` | TFLite + Matrix | ~45 MB | No | Yes (`1.5 MB`) | Rejected (`14.5%` Unseen Top-5) |
| **Candidate A1: `TinyCLIP-ViT-8M/16`** | TinyCLIP Distilled ViT-8M/16 | 8.28M | 15.17M | FP32 | `224x224` | 512-D | `31.74 / 15.93 / 8.30 MB` | ONNX Runtime Mobile | ~30–46 MB | **No** (Offline only) | **Yes** (`2.0 MB` FP16) | High (Ultra-compact) |
| **Candidate A2: `TinyCLIP-ViT-40M/32`** | TinyCLIP Distilled ViT-40M/32 | 39.69M | 44.51M | FP32 | `224x224` | 512-D | `151.61 / 76.11 / 38.45 MB` | ONNX Runtime Mobile | ~74–136 MB | **No** (Offline only) | **Yes** (`2.0 MB` FP16) | High (Fast patch-32 ViT) |
| **Candidate B: `OpenCLIP-ViT-B/32`** | CLIP ViT-B/32 (LAION-2B) | 87.85M | 63.43M | FP32 | `224x224` | 512-D | `335.31 / 168.33 / 84.50 MB` | ONNX Runtime Mobile | ~140–274 MB | **No** (Offline only) | **Yes** (`2.0 MB` FP16) | Medium (86.5 MB INT8 bundle) |
| **Candidate C: `SigLIP-B/16`** | Sigmoid Loss ViT-B/16 (`google/siglip`) | 92.88M | 110.27M | FP32 | `224x224` | 768-D | `354.56 / 177.99 / 94.44 MB` | ONNX Runtime Mobile / LiteRT | ~155–289 MB | **No** (Offline only) | **Yes** (`3.0 MB` FP16) | Medium (Requires INT8 + NNAPI/GPU or On-Demand Asset Pack) |

---

## 4. Vocabulary Summary
- **Canonical Food Concepts:** **`2,050`** distinct canonical food concepts (`vocabulary_35_11a1.json`), exceeding the 1,500–3,000 preferred target.
- **Aliases / Synonyms:** **`6,150`** deduplicated aliases (`alias_mapping_35_11a1.json`), yielding **`8,200` total food text entries** (zero collisions between aliases and canonical food names).
- **FitFuel Catalog Coverage:** **`238 / 238` (`100.0%`)** of `predefined_foods.dart` covered (`50` V5-overlap classes + `188` non-V5 FitFuel catalog foods + `1,812` open-world culinary concepts).
- **Geographic & Culinary Diversity:**
  - Global / Multi-Regional: `423` concepts
  - European / Mediterranean: `416` concepts (including `22` Pasta & Noodle dishes: `Penne Pasta`, `Creamy Penne Pasta`, `Pasta Alfredo`, `Penne Alfredo`, `Creamy Pasta`, `Spaghetti`, `Spaghetti Bolognese`, `Tomato Pasta`, `Lasagna`, `Macaroni`, `Macaroni and Cheese`, `Spaghetti Carbonara`, `Cacio e Pepe`, `Potato Gnocchi`, `Cheese Ravioli`, etc.)
  - Indian & South Asian: `355` concepts (`320` Indian + `35` South Asian)
  - East Asian, Southeast Asian & Pan-Asian: `396` concepts (`135` East Asian + `106` Southeast Asian + `155` Asian)
  - Latin American: `141` concepts
  - North American: `136` concepts
  - Middle Eastern: `92` concepts
  - African: `91` concepts
- **Negative Non-Food Concepts:** `12` explicit non-food text prompts (`phone`, `laptop`, `hand`, `keyboard`, `desk`, `shoe`, `car`, `plant`, `empty plate`, `utensils`, `packaging`, `blurry background`) for open-vocabulary non-food rejection.

---

## 5. Dataset Provenance & Leak-Prevention Summary
- **Total Benchmark Images Evaluated:** **`820` verified unique images** across 5 subsets:
  - **Single-Concept Food Images:** **`647` images** across **`251` distinct canonical foods** (`benchmark_manifest_35_11a1.csv`):
    - **A. Current-V5 Overlap Foods:** `250` images across `50` foods (`5` images per class).
    - **B. Unseen-to-V5 Foods:** `397` images across **`201` distinct unseen foods** (`89` development, `91` calibration, `217` final lockbox across `158` distinct lockbox unseen foods).
  - **C. Non-Food Safety Set:** **`108` images** (`37` calibration split, `71` untouched final lockbox holdout) spanning phones, laptops, hands, keyboards, desks, shoes, cars, plants, empty plates, utensils, and packaging.
  - **D. Mixed-Meal Platter Set:** **`48` verified multi-item meal images** (`South Indian Thali`, `North Indian Thali`, `Banana Leaf Meal`, `Indian Thali Meal`, `Bento Lunch Box`, `Full Breakfast Plate`).
  - **E. True Text-OOV Set:** **`17` images across `9` distinct food concepts** intentionally excluded from the 2,050-concept text vocabulary (`Khachapuri`, `Stroopwafel`, `Kuzhi Paniyaram`, `Khao Soi`, `Borscht`, `Pastel de Nata`, `Takoyaki`, `Spanakopita`, `Banh Xeo`).
- **Duplicate & Leak Prevention:**
  - Enforced via **SHA-256 exact byte hashing**, **64-bit perceptual dHash (`Hamming distance <= 4` rejected)**, and **canonical source URL deduplication**.
  - Removed `6` exact SHA-256 duplicates, `11` same-source URLs, and `8` perceptual near-duplicates during manifest construction.
  - **Cross-split overlap (`calibration` vs `final_lockbox`):** `0` exact duplicates and `0` perceptual near-duplicates.

---

## 6. Core Accuracy Table (All Food / V5-Overlap / Unseen-to-V5 Calibration & Lockbox)

| Model | Split (`N` Images / `D` Foods) | Exact Top-1 | Exact Top-3 | Exact Top-5 | Alias-Aware Top-1 | Alias-Aware Top-3 | Alias-Aware Top-5 | Category Top-1 | Category Top-5 | Macro Top-1 | Macro Top-5 | MRR |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`fitfuel_food_v5`** *(50-class TFLite)* | All Food (`647` / `251`) | 16.69% | 24.11% | 27.36% | 16.69% | 24.11% | 27.36% | 30.60% | 47.14% | 8.61% | 14.10% | 0.2070 |
| | V5-Overlap (`250` / `50`) | **43.20%** | **62.40%** | **70.80%** | 43.20% | 62.40% | 70.80% | 60.80% | 88.00% | 43.20% | 70.80% | 0.5356 |
| | Unseen Calibration (`91` / `91`) | **0.00%** | **0.00%** | **0.00%** | 0.00% | 0.00% | 0.00% | 8.79% | 20.88% | 0.00% | 0.00% | 0.0000 |
| | **Unseen Lockbox (`217` / `158`)** | **0.00%** | **0.00%** | **0.00%** | **0.00%** | **0.00%** | **0.00%** | 11.98% | 22.58% | 0.00% | 0.00% | 0.0000 |
| | Unseen All (`397` / `201`) | 0.00% | 0.00% | 0.00% | 0.00% | 0.00% | 0.00% | 11.59% | 21.41% | 0.00% | 0.00% | 0.0000 |
| **Phase 35.11A Bridge** *(Prior Rejected)* | Unseen Holdout (`Phase 35.11A`) | 5.80% | 10.60% | 14.50% | — | — | — | — | — | — | — | — |
| **Candidate A1: `TinyCLIP-ViT-8M/16`** | All Food (`647` / `251`) | 12.67% | 20.56% | 25.04% | 16.23% | 27.20% | 33.85% | 35.09% | 57.81% | 14.81% | 30.26% | 0.1704 |
| | V5-Overlap (`250` / `50`) | 5.60% | 10.40% | 12.80% | 9.60% | 18.00% | 22.40% | 18.40% | 40.40% | 5.60% | 12.80% | 0.0823 |
| | Unseen Calibration (`91` / `91`) | 21.98% | 31.87% | 37.36% | 23.08% | 39.56% | 45.05% | 54.95% | 74.73% | 21.98% | 37.36% | 0.2758 |
| | **Unseen Lockbox (`217` / `158`)** | **15.67%** | **24.88%** | **31.34%** | **20.28%** | **30.88%** | **40.09%** | 43.32% | 66.36% | 15.88% | 32.70% | 0.2106 |
| | Unseen All (`397` / `201`) | 17.13% | 26.95% | 32.75% | 20.40% | 33.00% | 41.06% | 45.59% | 68.77% | 17.10% | 34.60% | 0.2259 |
| **Candidate A2: `TinyCLIP-ViT-40M/32`** | All Food (`647` / `251`) | 21.95% | 30.76% | 36.63% | 25.81% | 36.63% | 43.89% | 41.11% | 63.99% | 28.91% | 43.79% | 0.2713 |
| | V5-Overlap (`250` / `50`) | 12.40% | 19.60% | 25.20% | 17.20% | 25.20% | 33.20% | 23.20% | 45.60% | 12.40% | 25.20% | 0.1673 |
| | Unseen Calibration (`91` / `91`) | 27.47% | 41.76% | 47.25% | 34.07% | 48.35% | 54.95% | 59.34% | 75.82% | 27.47% | 47.25% | 0.3473 |
| | **Unseen Lockbox (`217` / `158`)** | **29.49%** | **37.79%** | **44.24%** | **32.26%** | **43.78%** | **51.61%** | 50.23% | 74.65% | 34.34% | 48.00% | 0.3472 |
| | Unseen All (`397` / `201`) | 27.96% | 37.78% | 43.83% | 31.23% | 43.83% | 50.63% | 52.39% | 75.57% | 33.02% | 48.42% | 0.3368 |
| **Candidate B: `OpenCLIP-ViT-B/32`** | All Food (`647` / `251`) | 25.66% | 35.86% | 40.80% | 29.21% | 41.73% | 48.53% | 42.97% | 67.08% | 33.17% | 49.89% | 0.3123 |
| | V5-Overlap (`250` / `50`) | 15.60% | 22.00% | 28.00% | 20.00% | 27.60% | 35.60% | 26.40% | 47.20% | 15.60% | 28.00% | 0.1959 |
| | Unseen Calibration (`91` / `91`) | 35.16% | 48.35% | 51.65% | 39.56% | 52.75% | 57.14% | 59.34% | 83.52% | 35.16% | 51.65% | 0.4161 |
| | **Unseen Lockbox (`217` / `158`)** | **30.88%** | **44.24%** | **48.85%** | **33.64%** | **50.23%** | **57.60%** | 49.77% | 77.88% | 37.18% | 54.38% | 0.3780 |
| | Unseen All (`397` / `201`) | 31.99% | 44.58% | 48.87% | 35.01% | 50.63% | 56.68% | 53.40% | 79.60% | 37.54% | 55.33% | 0.3856 |
| **Candidate C: `SigLIP-B/16`** | All Food (`647` / `251`) | **37.56%** | **49.77%** | **55.64%** | **42.97%** | **57.19%** | **61.98%** | **55.18%** | **73.26%** | **46.65%** | **65.46%** | **0.4432** |
| | V5-Overlap (`250` / `50`) | 26.40% | 34.40% | 39.20% | 31.20% | 40.80% | 46.40% | 38.80% | 56.80% | 26.40% | 39.20% | 0.3092 |
| | Unseen Calibration (`91` / `91`) | **49.45%** | **62.64%** | **69.23%** | **56.04%** | **72.53%** | **75.82%** | **70.33%** | **87.91%** | **49.45%** | **69.23%** | **0.5674** |
| | **Unseen Lockbox (`217` / `158`)** | **44.70%** | **62.21%** | **69.12%** | **49.77%** | **69.12%** | **74.19%** | **63.59%** | **83.87%** | **52.58%** | **74.10%** | **0.5425** |
| | Unseen All (`397` / `201`) | **44.58%** | **59.45%** | **65.99%** | **50.38%** | **67.51%** | **71.79%** | **65.49%** | **83.63%** | **51.69%** | **71.99%** | **0.5276** |

> **Architectural Observation on V5-Overlap vs Unseen-to-V5:** Notice that on the 50 V5-overlap classes (`Idli`, `Dosa`, `Poha`, `Upma`, `Dal Tadka`, etc.) across a 2,050-label open vocabulary where each V5 food competes with ~15 regional fine-grained variants (`Masala Dosa`, `Rava Dosa`, `Neer Dosa`, `Kanchipuram Idli`, `Rava Idli`), the closed-set 50-class `fitfuel_food_v5` classifier remains stronger on its 50 trained classes (`43.20%` Top-1 / `70.80%` Top-5 across 50 labels vs `SigLIP-B/16`'s `26.40%` Exact Top-1 / `46.40%` Alias-Aware Top-5 across 2,050 labels), whereas on **Unseen-to-V5 foods** `fitfuel_food_v5` is `0.00%` and `SigLIP-B/16` jumps to **`44.70%` Exact Top-1 / `69.12%` Exact Top-5 / `74.19%` Alias-Aware Top-5**. This strongly motivates a **two-tier local cascade** in future Phase 35.11B (retaining `fitfuel_food_v5` for high-confidence trusted V5 classes and invoking the open-vocabulary encoder when `fitfuel_food_v5` abstains or detects OOV).

---

## 7. Unseen-to-V5 Detailed Results & Ablations (Prompt Engineering, Alias Indexing, Flat vs Hierarchical)

### 7.1 Prompt Engineering Ablation (Unseen-to-V5 Calibration Split, `N = 91`)
| Prompt Template | `TinyCLIP-8M/16` Top-1 / Top-5 | `TinyCLIP-40M/32` Top-1 / Top-5 | `OpenCLIP-ViT-B/32` Top-1 / Top-5 | `SigLIP-B/16` Top-1 / Top-5 (Alias Top-5) |
| :--- | :--- | :--- | :--- | :--- |
| `T1`: `"{food}"` | 17.58% / 31.87% | 27.47% / 49.45% | 35.16% / 53.85% | 51.65% / 69.23% (75.82%) |
| `T2`: `"a photo of {food}"` | 16.48% / **38.46%** | 29.67% / **51.65%** | 35.16% / **59.34%** | **52.75%** / **70.33%** (**76.92%**) |
| `T3`: `"a photo of a plate of {food}"` | **21.98%** / 32.97% | 28.57% / 42.86% | 36.26% / 51.65% | 49.45% / **70.33%** (**76.92%**) |
| `T4`: `"a close-up photo of {food}, a type of food"` | **21.98%** / 32.97% | 25.27% / 43.96% | **37.36%** / 51.65% | 40.66% / 63.74% (70.33%) |
| `T5`: `"cooked {food} dish"` | 19.78% / 34.07% | **30.77%** / 47.25% | 35.16% / 52.75% | 41.76% / 68.13% (75.82%) |
| `T_ensemble` (L2-normalized average of `T2–T5`) | 20.88% / **38.46%** | 26.37% / 48.35% | **37.36%** / 51.65% | 49.45% / 69.23% (75.82%) |

### 7.2 Alias Indexing Strategy Ablation (Section 19)
| Indexing Strategy | Index Vectors | Runtime Search Latency (`ms`) | `TinyCLIP-40M/32` Cal Top-1 / Top-5 | `OpenCLIP-B/32` Cal Top-1 / Top-5 | `SigLIP-B/16` Cal Top-1 / Top-5 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Canonical-Only** | `2,050` | `0.025–0.042 ms` | 26.37% / **48.35%** | **37.36%** / **51.65%** | 49.45% / **69.23%** |
| **2. Canonical + Alias Centroid (`0.72 C + 0.28 A`)** | `2,050` | `0.024–0.035 ms` | **27.47%** / 47.25% | 35.16% / **51.65%** | 49.45% / **69.23%** |
| **3. Multi-Vector Alias Index + Canonical Collapse** | `8,200 -> 2,050` | `0.261–0.478 ms` | 26.37% / 46.15% | 35.16% / 50.55% | **50.55%** / 65.93% |

### 7.3 Flat vs Hierarchical Retrieval (Section 20, Unseen-to-V5 Lockbox `N = 217`)
| Candidate | Flat Retrieval Top-1 / Top-5 (`2,050` vectors) | Flat Search Latency | Hierarchical Stage 1 -> Stage 2 Top-1 / Top-5 | Hierarchical Search Latency | Finding |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`TinyCLIP-ViT-8M/16`** | **15.67% / 31.34%** | **`0.0316 ms`** | 13.36% / 27.65% | `1.6023 ms` | Flat is **+3.69% Top-5 more accurate** and **50x faster** (vectorized BLAS GEMV) |
| **`TinyCLIP-ViT-40M/32`** | **29.49% / 44.24%** | **`0.0182 ms`** | 26.73% / 40.55% | `2.2501 ms` | Flat avoids Stage-1 coarse centroid routing errors (**+3.69% Top-5**) |
| **`OpenCLIP-ViT-B/32`** | **30.88% / 48.85%** | **`0.0189 ms`** | 28.11% / 44.70% | `1.9486 ms` | Flat is **+4.15% Top-5 more accurate** |
| **`SigLIP-B/16`** | **44.70% / 69.12%** | **`0.0318 ms`** | 32.72% / 49.77% | `1.6845 ms` | Flat is **+19.35% Top-5 more accurate** because coarse category centroids blur sigmoid embeddings |

---

## 8. Pasta Regression Results (Section 26)
Evaluated across **`26` pasta test images** spanning `Penne Pasta`, `Creamy Penne Pasta`, `Pasta Alfredo`, `Creamy Pasta`, `Spaghetti`, `Spaghetti Bolognese`, `Tomato Pasta`, `Macaroni`, `Spaghetti Carbonara`, and `Cheese Ravioli`:

| Model | Exact Pasta Concept Top-1 | Exact Pasta Concept Top-5 | Pasta-Family / Sibling Top-1 | Pasta-Family / Sibling Top-5 | Absurd Fruit / Unrelated Error Rate |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`fitfuel_food_v5` (50-class Baseline)** | 0.00% | 0.00% | 0.00% | 0.00% | **100.0% wrong domain** (`Pineapple`, `Spinach`, `Grilled Chicken Breast`, `Poha`, `Scrambled Eggs`) |
| **Candidate A1: `TinyCLIP-ViT-8M/16`** | 3.85% | 11.54% | 19.23% | 42.31% | **0.00%** fruit errors |
| **Candidate A2: `TinyCLIP-ViT-40M/32`** | 11.54% | 30.77% | 30.77% | 65.38% | **0.00%** fruit errors |
| **Candidate B: `OpenCLIP-ViT-B/32`** | 15.38% | 38.46% | 38.46% | 65.38% | **0.00%** fruit errors |
| **Candidate C: `SigLIP-B/16`** | **26.92%** | **61.54%** | **50.00%** | **80.77%** | **0.00%** fruit errors |

### Representative Pasta Regression Cases (`fitfuel_food_v5` vs `SigLIP-B/16` & `OpenCLIP-ViT-B/32`)
| Image ID (Split) | Ground Truth | `fitfuel_food_v5` Top-3 Predictions | `OpenCLIP-ViT-B/32` Top-4 Retrieved | `SigLIP-B/16` Top-4 Retrieved |
| :--- | :--- | :--- | :--- | :--- |
| `food_0467` (`dev`) | **Creamy Penne Pasta** | `Indian Brown Rice (51.8%)`, `Steamed Rice (17.3%)`, `Tofu (14.6%)` | `1. Penne Alfredo (0.365)`, `2. Creamy Penne Pasta (0.349)`, `3. Creamy Pasta (0.348)`, `4. Pasta Alfredo (0.346)` | `1. Penne Alfredo (0.135)`, `2. Creamy Penne Pasta (0.122)`, `3. Pasta Alfredo (0.118)`, `4. Creamy Pasta (0.109)` |
| `food_0468` (`cal`) | **Creamy Penne Pasta** | `Steamed Rice (42.7%)`, `Indian Brown Rice (11.3%)`, `Oats (11.1%)` | `1. Yaprak Sarma (0.331)`, `2. Manti Dumplings (0.326)` | **`1. Creamy Penne Pasta (0.125)`**, `2. Penne Alfredo (0.121)`, `3. Creamy Pasta (0.118)`, `4. Pasta Alfredo (0.116)` |
| `food_0469` (`lockbox`) | **Creamy Penne Pasta** | `Spinach (Raw) (31.5%)`, `Grilled Chicken Breast (22.1%)`, `Almonds (16.1%)` | `1. Pasta Puttanesca (0.336)`, `2. Whole Grain Pasta (0.335)`, `3. Standard Pasta (0.328)`, `4. Pasta (0.327)` | **`1. Creamy Penne Pasta (0.102)`**, `2. Tomato Pasta (0.100)`, `3. Penne Pasta (0.095)`, `4. Creamy Pasta (0.093)` |
| `food_0472` (`lockbox`) | **Pasta Alfredo** | `Spinach (Raw) (97.9%)`, `Grilled Chicken Breast (0.7%)`, `Poha (0.5%)` | **`1. Pasta Alfredo (0.311)`**, `2. Pasta Primavera (0.303)`, `3. Cacio e Pepe (0.298)`, `4. Creamy Pasta (0.294)` | **`1. Pasta Alfredo (0.108)`**, `2. Creamy Pasta (0.100)`, `3. Linguine Clam Sauce (0.099)`, `4. Standard Pasta (0.091)` |
| `food_0474` (`lockbox`) | **Creamy Pasta** | `Poha (59.9%)`, `Upma (8.6%)`, `Grilled Chicken Breast (8.3%)` | **`1. Creamy Pasta (0.325)`**, `2. Yakhni Pulao (0.319)`, `5. Pasta Primavera (0.314)` | `1. Shan Noodles (0.103)`, **`2. Creamy Pasta (0.099)`**, `3. Standard Pasta (0.097)`, `4. Pasta Alfredo (0.096)` |
| `food_0477` (`lockbox`) | **Spaghetti** | `Paneer (25.5%)`, `Grilled Chicken Breast (15.4%)`, `Masala Egg Omelette (13.1%)` | `1. Spaghetti Bolognese (0.328)`, `2. Lasagna (0.311)`, **`3. Spaghetti (0.310)`** | `1. Spaghetti Bolognese (0.110)`, **`2. Spaghetti (0.098)`**, `3. Cincinnati Chili (0.089)`, `4. Pasta (0.084)` |
| `food_0480` (`lockbox`) | **Spaghetti** | `Masala Egg Omelette (38.0%)`, `Grilled Chicken Breast (17.4%)`, `Guava (7.2%)` | `1. Spaghetti Carbonara (0.362)`, `2. Bucatini Amatriciana (0.341)`, **`3. Spaghetti (0.307)`**, `4. Cacio e Pepe (0.305)` | `1. Spaghetti Carbonara (0.111)`, `2. Creamy Pasta (0.085)`, `3. Pasta (0.077)`, **`4. Spaghetti (0.077)`** |
| `food_0490` (`lockbox`) | **Cheese Ravioli** | `Spinach (Raw) (45.1%)`, `Broccoli (27.6%)`, `Grilled Chicken Breast (18.6%)` | `1. Escargots (0.457)`, `2. Tagliatelle al Ragu (0.427)`, `3. Pasta Alfredo (0.422)` | **`1. Cheese Ravioli (0.103)`**, `2. Farfalle Mushroom (0.098)`, `3. Creamy Pasta (0.087)`, `4. Standard Pasta (0.084)` |

---

## 9. Semantic Error Analysis (Section 22, Unseen-to-V5 Final Lockbox `N = 217`)

When Exact Top-1 is wrong, does the candidate still predict a semantically meaningful food (sibling or parent category) rather than a catastrophic cross-domain mismatch?

| Semantic Category of Top-1 Prediction | `fitfuel_food_v5` (Baseline) | `TinyCLIP-ViT-8M/16` | `TinyCLIP-ViT-40M/32` | `OpenCLIP-ViT-B/32` | `SigLIP-B/16` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Exact Canonical Match** | `0` (`0.00%`) | `34` (`15.67%`) | `64` (`29.49%`) | `67` (`30.88%`) | **`97` (`44.70%`)** |
| **2. Close Culinary Sibling** *(e.g., `Chocolate Cake` -> `Sachertorte`, `Gulab Jamun` -> `Luqaimat`, `Biryani` -> `Kashmiri Pulao`)* | `0` (`0.00%`) | `8` (`3.69%`) | `10` (`4.61%`) | `11` (`5.07%`) | **`16` (`7.37%`)** |
| **3. Correct Parent / Culinary Family** *(same food domain, e.g., another pasta/noodle, curry, or pastry)* | `26` (`11.98%`) | `87` (`40.09%`) | `71` (`32.72%`) | `67` (`30.88%`) | **`62` (`28.57%`)** |
| **Meaningful Top-1 Subtotal (`1 + 2 + 3`)** | **`11.98%`** | **`59.45%`** | **`66.82%`** | **`66.82%`** | **`80.65%`** |
| **4. Reasonable Visual Relation** *(visually similar cooked savory dish or regional plate)* | `54` (`24.88%`) | `56` (`25.81%`) | `57` (`26.27%`) | `59` (`27.19%`) | `34` (`15.67%`) |
| **5. Catastrophic Semantic Mismatch** *(unrelated food category, e.g., dessert -> meat/soup, snack -> beverage)* | **`137` (`63.13%`)** | `32` (`14.75%`) | `15` (`6.91%`) | `13` (`5.99%`) | **`8` (`3.69%`)** |

---

## 10. Non-Food Safety Results (Section 23)
Thresholds were calibrated exclusively on the **Calibration Split (`37` non-food images vs `141` calibration food images)** and evaluated unmodified on the **Untouched Final Lockbox Non-Food Holdout (`71` non-food images vs `367` lockbox food images)**:

| Candidate | Mode A: Without Negative Concepts (Raw Similarity Threshold $\tau_{\text{sim}}$) | Mode A Lockbox Non-Food FAR | Mode B: With 12 Negative Non-Food Prompts ($\tau_{\text{floor}}$ + Margin $\tau_{\text{diff}}$) | Mode B Lockbox Non-Food False Accepts (`N = 71`) | Mode B Lockbox Non-Food FAR (Target `< 1%`) | Mode B Lockbox Non-Food Abstention Rate | Mode B Lockbox Food Retention Rate |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`TinyCLIP-ViT-8M/16`** | $\tau_{\text{sim}} = 0.3941$ | `1.41%` (`1/71`) | $\tau_{\text{floor}} = 0.3485, \tau_{\text{diff}} = 0.0719$ | `3 / 71` | `4.23%` | `95.77%` | `87.47%` |
| **`TinyCLIP-ViT-40M/32`** | $\tau_{\text{sim}} = 0.2738$ | `1.41%` (`1/71`) | $\tau_{\text{floor}} = 0.2580, \tau_{\text{diff}} = 0.0369$ | `2 / 71` | `2.82%` | `97.18%` | `86.10%` |
| **`OpenCLIP-ViT-B/32`** | $\tau_{\text{sim}} = 0.2724$ | `1.41%` (`1/71`) | $\tau_{\text{floor}} = 0.2530, \tau_{\text{diff}} = 0.0397$ | `1 / 71` | `1.41%` | `98.59%` | `88.56%` |
| **`SigLIP-B/16`** | $\tau_{\text{sim}} = 0.0665$ | **`0.00%` (`0/71`)** | $\tau_{\text{floor}} = 0.0181, \tau_{\text{diff}} = 0.0621$ | **`0 / 71`** | **`0.00%` (PASS `< 1%`)** | **`100.00%`** | **`88.28%`** (Mode A) / **`85.29%`** (Mode B) |

---

## 11. Mixed-Meal Results (Section 24)
Evaluated across **`48` verified multi-item meal images** (`South Indian Thali`, `North Indian Thali`, `Banana Leaf Meal`, `Indian Thali Meal`, `Bento Lunch Box`, `Full Breakfast Plate`):

| Candidate | Top-3 Contains $\ge 1$ True Meal Component | Top-5 Contains $\ge 1$ True Meal Component | Top-5 Contains $\ge 2$ True Meal Components | Representative Multi-Component Retrieval (`SigLIP-B/16`) |
| :--- | :--- | :--- | :--- | :--- |
| **`TinyCLIP-ViT-8M/16`** | 54.17% | 62.50% | 37.50% | Retrieves `Chapati`, `Masale Bhaat`, `Pav Bhaji` on Indian thalis |
| **`TinyCLIP-ViT-40M/32`** | 41.67% | 56.25% | 33.33% | Retrieves `Dal Bhat Tarkari`, `Chapati`, `Onigiri`, `Scrambled Eggs` |
| **`OpenCLIP-ViT-B/32`** | 43.75% | 54.17% | 35.42% | Retrieves `Dal Bhat Tarkari`, `Sambar`, `Gyoza`, `Full English Breakfast` |
| **`SigLIP-B/16`** | **`72.92%`** | **`87.50%`** | **`58.33%`** | `North Indian Thali` -> `Chapati`, `Dal Bhat Tarkari`; `Banana Leaf Meal` -> `Vatha Kuzhambu`, `Mor Kuzhambu`, `Kootu`, `Bagara Khana`, `Rasam` |

---

## 12. True Text-OOV Results (Section 25)
Evaluated on **`17` images of `9` food concepts intentionally excluded from the 2,050-concept text vocabulary**:

| Excluded True Text-OOV Food | Expected Culinary Family / Sibling | `SigLIP-B/16` Top-3 Retrieved from 2,050 Vocabulary | Top-1 Sim / Margin | Semantic Relationship | Uncertain / Nearest-Family Flag Triggered? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Khachapuri** *(Georgian Cheese Bread)* | Flatbreads / `Pide` / `Cheese Pizza` | `1. Pide Flatbread`, `2. Mutabbaq`, `3. Plăcintă` | `0.1374` / `0.0185` | **Close Regional Sibling** (Stuffed cheese flatbreads) | Image 1: No / Image 2: **Yes** (`margin=0.0103`) |
| **Stroopwafel** *(Dutch Caramel Waffle)* | Waffles / `Belgian Waffle` / `Speculoos` | `1. Belgian Waffle`, `2. Medovník`, `3. Speculoos` | `0.0914` / `0.0104` | **Close Sibling** (`Belgian Waffle` + `Speculoos` spiced cookie!) | **Yes** (`margin=0.0104 < 0.015`) |
| **Kuzhi Paniyaram** *(South Indian Dumplings)* | Griddled Batter / `Idli` / `Poffertjes` | `1. Khanom Krok`, `2. Poffertjes`, `3. Chhena Jhili` | `0.1133` / `0.0094` | **Visual & Culinary Analogue** (Hemispherical griddled batter cakes) | **Yes** (`margin=0.0094 < 0.015`) |
| **Khao Soi** *(Northern Thai Curry Noodles)* | Coconut Curry Noodles / `Laksa` | `1. Kalguksu`, `2. Ohn No Khao Swè`, `3. Shan Noodles` / `Thukpa` | `0.1297` / `0.0057` | **Direct Culinary Sibling** (`Ohn No Khao Swè` is the Burmese parent dish of Khao Soi) | **Yes** (`margin=0.0057 < 0.015`) |
| **Borscht** *(Ukrainian Beetroot Soup)* | Soups & Stews / `Minestrone` | `1. Brudet`, `2. Minestrone`, `3. Zacuscă` | `0.0552` / `0.0009` | **Parent Category** (`Minestrone` / red vegetable stew) | **Yes** (`sim=0.0552`, `margin=0.0009`) |
| **Pastel de Nata** *(Portuguese Custard Tart)* | Egg Tarts / `Queijadas` | `1. Queijadas`, `2. Pastiera Napoletana`, `3. Pastel de Feira` | `0.1011` / `0.0049` | **Close Regional Sibling** (`Queijadas` Portuguese sweet tartlet) | **Yes** (`margin=0.0049 < 0.015`) |
| **Takoyaki** *(Japanese Octopus Balls)* | Japanese Griddled Street Snacks | `1. Imagawayaki`, `2. Kushikatsu`, `3. Taiyaki` | `0.0727` / `0.0034` | **Close Culinary Sibling** (`Imagawayaki` / `Taiyaki` griddled batter snacks) | **Yes** (`margin=0.0034 < 0.015`) |
| **Spanakopita** *(Greek Spinach Feta Pie)* | Balkan/Greek Filo Pies / Spinach | `1. Prekmurska Gibanica` / `Spinach (Raw)`, `3. Plăcintă` | `0.0731` / `0.0022` | **Close Regional Sibling** (`Gibanica` / `Plăcintă` layered cheese pastry & `Spinach`) | **Yes** (Image 2 `margin=0.0022`) |
| **Banh Xeo** *(Vietnamese Crispy Crepe)* | Vietnamese Rice Crepes / Dosa | `1. Banh Trang Nuong`, `2. Banh Beo`, `3. Banh Nam` | `0.1361` / `0.0267` | **Close Regional Sibling** (`Banh Trang Nuong` Vietnamese crispy rice paper crepe) | No (High-confidence sibling match) |

- **Overall True Text-OOV Summary (`SigLIP-B/16`):** **`94.12%` (`16/17`)** retrieved a semantically related culinary sibling or parent category in Top-3, while **`76.47%` (`13/17`)** automatically triggered the low-margin/low-similarity uncertainty flag (`margin < 0.015` or `sim < P25`) so the UI can safely label them as *"Closest matches in catalog"* rather than an exact identity claim.

---

## 13. Size, Quantization, Latency & RAM Table (Sections 27, 29, 45)

All vision encoders were exported to **ONNX Runtime (`opset 17`)** and benchmarked across **PyTorch FP32 (Before Conversion)**, **ONNX FP32**, **FP16**, and **ONNX Dynamic INT8 (After Conversion)** on local CPU (`4 threads`), alongside the **`2,050`-concept FP16 Precomputed Text Embedding Index**:

| Model | Precision / Format | Vision Encoder Size | Text Index Size (`2,050` FP16) | Total Asset Package | Cold Load (`ms`) | Warm P50 (`ms`) | Warm P90 (`ms`) | Warm Mean (`ms`) | Search (`2,050` labels) | Total Per-Scan P50 | RAM Delta (`MB`) | Unseen Lockbox Top-1 / Top-3 / Top-5 | Cosine Fidelity vs PyTorch FP32 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`fitfuel_food_v5`** | TFLite FP32 | `5.85 MB` | `0.00 MB` | **`5.85 MB`** | `22.4 ms` | **`5.34 ms`** | `7.07 ms` | `5.56 ms` | `0.00 ms` | **`5.34 ms`** | `28.0 MB` | `0.00% / 0.00% / 0.00%` | `1.000000` |
| **`TinyCLIP-ViT-8M/16`** | PyTorch FP32 (Before) | `31.74 MB` | `2.00 MB` | `33.74 MB` | `1360.9 ms` | `55.19 ms` | — | `55.19 ms` | `0.03 ms` | `55.22 ms` | `69.4 MB` | `15.67% / 24.88% / 31.34%` | `1.000000` |
| | ONNX FP32 | `31.74 MB` | `2.00 MB` | `33.74 MB` | `4499.1 ms` | `109.11 ms` | `115.61 ms` | `96.57 ms` | `0.03 ms` | `109.14 ms` | `69.4 MB` | `15.67% / 24.88% / 31.34%` | `1.000000` |
| | **FP16** | `15.93 MB` | `2.00 MB` | **`17.93 MB`** | `3239.4 ms` | `92.74 ms` | `98.27 ms` | `82.08 ms` | `0.03 ms` | `92.78 ms` | `45.9 MB` | `15.67% / 24.88% / 31.34%` | `0.999999` |
| | **ONNX Dynamic INT8** | **`8.30 MB`** | `2.00 MB` | **`10.30 MB`** | `4259.5 ms` | **`62.83 ms`** | `109.30 ms` | `75.26 ms` | `0.03 ms` | **`62.86 ms`** | **`30.0 MB`** | `13.82% / 24.42% / 29.03%` | `0.991330` |
| **`TinyCLIP-ViT-40M/32`** | PyTorch FP32 (Before) | `151.61 MB` | `2.00 MB` | `153.61 MB` | `2762.8 ms` | `70.42 ms` | — | `70.42 ms` | `0.02 ms` | `70.44 ms` | `237.3 MB` | `29.49% / 37.79% / 44.24%` | `1.000000` |
| | ONNX FP32 | `151.61 MB` | `2.00 MB` | `153.61 MB` | `1647.5 ms` | `95.94 ms` | `185.11 ms` | `111.56 ms` | `0.02 ms` | `95.96 ms` | `237.3 MB` | `29.49% / 37.79% / 44.24%` | `1.000000` |
| | **FP16** | `76.11 MB` | `2.00 MB` | **`78.11 MB`** | `1186.2 ms` | `81.55 ms` | `157.34 ms` | `94.83 ms` | `0.02 ms` | `81.57 ms` | `136.2 MB` | `29.49% / 37.79% / 43.78%` | `0.999998` |
| | **ONNX Dynamic INT8** | **`38.45 MB`** | `2.00 MB` | **`40.45 MB`** | `1446.5 ms` | **`47.42 ms`** | **`53.77 ms`** | **`48.07 ms`** | `0.02 ms` | **`47.44 ms`** | **`73.8 MB`** | `26.27% / 37.33% / 43.78%` | `0.971960` |
| **`OpenCLIP-ViT-B/32`** | PyTorch FP32 (Before) | `335.31 MB` | `2.00 MB` | `337.31 MB` | `1465.9 ms` | `122.12 ms` | — | `122.12 ms` | `0.02 ms` | `122.14 ms` | `494.4 MB` | `30.88% / 44.24% / 48.85%` | `1.000000` |
| | ONNX FP32 | `335.31 MB` | `2.00 MB` | `337.31 MB` | `4699.1 ms` | `130.09 ms` | `164.91 ms` | `134.96 ms` | `0.02 ms` | `130.11 ms` | `494.4 MB` | `30.88% / 44.24% / 48.85%` | `1.000000` |
| | **FP16** | `168.33 MB` | `2.00 MB` | `170.33 MB` | `3383.4 ms` | `110.58 ms` | `140.17 ms` | `114.72 ms` | `0.02 ms` | `110.60 ms` | `274.5 MB` | `30.88% / 44.24% / 48.85%` | `0.999997` |
| | **ONNX Dynamic INT8** | **`84.50 MB`** | `2.00 MB` | **`86.50 MB`** | `4407.7 ms` | **`100.56 ms`** | `159.67 ms` | `109.69 ms` | `0.02 ms` | **`100.58 ms`** | **`140.5 MB`** | **`30.41% / 43.32% / 49.31%`** | `0.944300` |
| **`SigLIP-B/16`** | PyTorch FP32 (Before) | `354.56 MB` | `3.00 MB` | `357.56 MB` | `4623.9 ms` | `548.85 ms` | — | `548.85 ms` | `0.03 ms` | `548.88 ms` | `521.4 MB` | **`44.70% / 62.21% / 69.12%`** | `1.000000` |
| | ONNX FP32 | `354.56 MB` | `3.00 MB` | `357.56 MB` | `13717.9 ms` | `379.77 ms` | `413.92 ms` | `381.85 ms` | `0.03 ms` | `379.80 ms` | `521.4 MB` | **`44.70% / 62.21% / 69.12%`** | `1.000000` |
| | **FP16** | `177.99 MB` | `3.00 MB` | `180.99 MB` | `9876.9 ms` | `322.80 ms` | `351.83 ms` | `324.57 ms` | `0.03 ms` | `322.84 ms` | `289.0 MB` | **`44.70% / 62.21% / 69.12%`** | `0.999998` |
| | **ONNX Dynamic INT8** | **`94.44 MB`** | `3.00 MB` | **`97.44 MB`** | `12687.1 ms` | **`256.14 ms`** | **`301.52 ms`** | **`262.44 ms`** | `0.03 ms` | **`256.17 ms`** | **`154.9 MB`** | **`43.32% / 61.75% / 69.12%`** | `0.969001` |

> **Key Quantization & Conversion Finding:**
> - **FP16 conversion** reduces vision encoder size by **50%** with **`0.00%` Top-1/Top-3/Top-5 accuracy loss** (`cosine_fidelity = 0.999998` vs PyTorch FP32).
> - **ONNX Dynamic INT8 quantization** compresses `SigLIP-B/16` from `354.56 MB` to **`94.44 MB`** (`97.44 MB` total with the `3.00 MB` 2,050-food text index), speeds up P50 latency to **`256.14 ms`**, reduces RAM delta to **`154.9 MB`**, and preserves **`69.12%` Exact Top-5** (`0.00%` Top-5 drop; only `-1.38%` Top-1 drop from `44.70%` to `43.32%`).
> - For strict `< 50 MB` APK size budgets, **`TinyCLIP-ViT-40M/32` Dynamic INT8** requires only **`38.45 MB`** (`40.45 MB` total with `2.00 MB` text index), runs in **`47.42 ms` P50**, uses **`73.8 MB` RAM**, and achieves **`43.78%` Exact Top-5 (`51.61%` Alias-Aware Top-5)**.

### Vocabulary Scaling Table (Section 28)
| Vocabulary Size (Canonical Foods) | `512-D` Index Size (FP32 / FP16) | `512-D` P50 Search Latency (`ms`) | `768-D` (`SigLIP-B/16`) Index Size (FP32 / FP16) | `768-D` P50 Search Latency (`ms`) |
| :--- | :--- | :--- | :--- | :--- |
| **`1,000` labels** | `1.95 MB` / **`0.98 MB`** | `0.258 ms` | `2.93 MB` / **`1.46 MB`** | `0.381 ms` |
| **`2,050` labels (Benchmark Index)** | `4.00 MB` / **`2.00 MB`** | `0.369 ms` | `6.01 MB` / **`3.00 MB`** | `0.625 ms` |
| **`3,000` labels** | `5.86 MB` / **`2.93 MB`** | `0.474 ms` | `8.79 MB` / **`4.39 MB`** | `0.822 ms` |
| **`5,000` labels** | `9.77 MB` / **`4.88 MB`** | `0.672 ms` | `14.65 MB` / **`7.32 MB`** | `1.078 ms` |

---

## 14. Real Samsung Device (`RZCW8201QBV`) Benchmark Status
- **Connected:** `NO` (Verified via `adb devices` and `flutter devices`; `List of devices attached` is empty).
- **Status:** **`REAL DEVICE BENCHMARK PENDING`**
- **Note:** Per Phase 35.11A.1 rules (Section 30), no on-device measurements were fabricated or extrapolated as device measurements. All latency and RAM figures in Section 13 are measured local CPU ONNX Runtime / PyTorch benchmarks; physical Samsung `RZCW8201QBV` validation is required before any production integration.

---

## 15. Offline Verification
- **Gemini API Calls:** `0`
- **External Cloud / Hosted Inference Calls:** `0`
- **Network Required at Inference Time:** `NO` (`local_files_only=True` verified across all Hugging Face processors/models and standalone ONNX Runtime `.onnx` + `.npz` inference).
- **Quota Statement:** Local open-vocabulary inference incurs **no provider API request quota or per-scan cloud charge** (`provider API calls per scan = 0`), bounded only by local device storage, RAM, battery, and thermal budgets.

---

## 16. Nutrition Mapping Compatibility (Section 33)
- Every one of the `2,050` canonical food concepts in `vocabulary_35_11a1.json` is mapped to a structured `canonicalFoodId`, `canonicalName`, `category`, `optionalParentCategory`, and `inFitFuel238` flag:
  - **Tier 1 — Exact FitFuel Predefined Food (`238 / 238` concepts, `100.0%` coverage):** Maps directly to `predefined_foods.dart` (`FoodItem`) with verified macro/micronutrient profiles.
  - **Tier 2 — Culinary Sibling / Category Archetype Fallback (`1,812` open-vocabulary concepts):** Maps deterministically via `alias_mapping_35_11a1.json` and `category` / sibling linkage to the nearest verified FitFuel nutrition profile or triggers pre-filled manual food search after explicit user confirmation.
  - **No Unconfirmed Auto-Logging:** All open-vocabulary suggestions require explicit user confirmation before nutrition lookup or diary logging.

---

## 17. Final Candidate Ranking

| Rank | Candidate | License Gate | Unseen Lockbox Exact Top-1 / Top-3 / Top-5 | Unseen Lockbox Alias Top-5 | Pasta Family Top-5 | Non-Food Lockbox FAR | INT8 Package Size (Vision + Index) | INT8 P50 Latency | Overall Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1 (Winner — Accuracy & Safety)** | **Candidate C: `SigLIP-B/16`** (`google/siglip-base-patch16-224`) | **PASS** (Apache-2.0) | **`44.70% / 62.21% / 69.12%`** | **`74.19%`** | **`80.77%`** | **`0.00%`** (`0/71`) | `97.44 MB` (`94.44 + 3.00 MB`) | `256.17 ms` | **PASSES ALL ACCURACY & SAFETY GATES** (`Top-5 >= 60%`, `Top-3 >= 50%`, `FAR < 1%`). Best candidate for Play Asset Delivery / on-demand local download. |
| **2 (Runner-Up — Balanced Mobile)** | **Candidate B: `OpenCLIP-ViT-B/32`** (`laion/CLIP-ViT-B-32-laion2B-s34B-b79K`) | **PASS** (MIT) | `30.88% / 44.24% / 48.85%` | `57.60%` | `65.38%` | `1.41%` (`1/71`) | `86.50 MB` (`84.50 + 2.00 MB`) | `100.58 ms` | Strong 2.5x faster alternative to SigLIP-B/16 (`57.60%` Alias Top-5), slightly below strict `60%` Exact Top-5 bar. |
| **3 (Best Compact APK Model)** | **Candidate A2: `TinyCLIP-ViT-40M/32`** (`wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M`) | **PASS** (MIT) | `29.49% / 37.79% / 44.24%` | `51.61%` | `65.38%` | `1.41%`–`2.82%` | **`40.45 MB`** (`38.45 + 2.00 MB`) | **`47.44 ms`** | Best ultra-fast `< 45 MB` model (`47.4 ms` P50, `73.8 MB` RAM), ideal if strict APK size ceiling prohibits `~95 MB` models. |
| **4 (Ultra-Tiny Baseline)** | **Candidate A1: `TinyCLIP-ViT-8M/16`** (`wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M`) | CAUTION (YFCC15M) | `15.67% / 24.88% / 31.34%` | `40.09%` | `42.31%` | `1.41%`–`4.23%` | `10.30 MB` (`8.30 + 2.00 MB`) | `62.86 ms` | Too weak on fine-grained unseen foods (`31.34%` Top-5) + YFCC15M distillation dataset caveat. |
| **— (Rejected)** | **Candidate D: `MobileCLIP-S0 / S1 / S2`** | **REJECTED — LICENSE** (`apple-amlr`) | — | — | — | — | — | — | Non-commercial research license only; incompatible with Play Store commercial distribution. |
| **— (Rejected)** | **Candidate E: `MetaCLIP-B/32-400M`** | **REJECTED — LICENSE** (`cc-by-nc-4.0`) | — | — | — | — | — | — | Non-commercial CC-BY-NC-4.0 license; incompatible with commercial distribution. |

---

## 18. Final Recommendation (`A` / `B` / `C`)

> ### **SELECTED RECOMMENDATION: `B`**
> **"Promising offline candidate, but requires real-device validation before integration."**

### Rationale for Selecting `B` (and not `A` or `C`):
1. **Why not `A`?** Unlike Phase 35.11A's failed semantic bridge (`14.5%` Unseen Top-5), true sigmoid-aligned multimodal pretraining (**Candidate C: `SigLIP-B/16`**, Apache-2.0) **passes every offline quality, license, and safety gate**:
   - Unseen-to-V5 Lockbox Exact Top-5: **`69.12%`** (`74.19%` Alias-Aware Top-5) vs `>= 60%` target.
   - Unseen-to-V5 Lockbox Exact Top-3: **`62.21%`** (`69.12%` Alias-Aware Top-3) vs `>= 45–50%` target.
   - Non-Food Lockbox False Acceptance Rate: **`0.00%` (`0/71`)** vs `< 1%` target.
   - Pasta Regression: **`80.77%` Pasta-Family Top-5** (`61.54%` Exact Top-5) with **`0.00%` fruit/meat hallucinations**.
   - Quantization: ONNX Dynamic INT8 reduces the vision encoder to **`94.44 MB`** (`97.44 MB` total with the `3.00 MB` FP16 text index) with **`0.00%` loss in Unseen Lockbox Top-5 (`69.12%`)**.
2. **Why `B` instead of `C`?**
   - Per Section 30 & Section 52, **Option `C` may only be chosen if the Samsung Android phone (`RZCW8201QBV`) is connected and real-device latency/RAM/thermal benchmarks are completed**. Because `RZCW8201QBV` is currently disconnected (`REAL DEVICE BENCHMARK PENDING`), **Option `B`** is the mandatory, scientifically rigorous choice.
   - Additionally, `SigLIP-B/16` INT8 (`97.44 MB` total package, `256 ms` desktop CPU P50) is ~16x larger than `fitfuel_food_v5.tflite` (`5.85 MB`), so validating its cold-start time, NNAPI/XNNPACK latency, and memory footprint on `RZCW8201QBV` (alongside `TinyCLIP-ViT-40M/32` INT8 at `40.45 MB` / `47.4 ms`) is essential before wiring it into the app in Phase 35.11B.

---

## 19. Exact Files Created / Modified
All Phase 35.11A.1 benchmark scripts and artifacts are isolated inside `tools/benchmarks/food_open_vocabulary/`:
- [license_report_35_11a1.md](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/license_report_35_11a1.md) — Authoritative license verification gate for all evaluated and rejected candidates.
- [build_vocabulary_35_11a1.py](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/build_vocabulary_35_11a1.py) — Builds the 2,050-concept canonical food ontology + 6,150 deduplicated aliases.
- [vocabulary_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/vocabulary_35_11a1.json) — 2,050 canonical foods, categories, cuisines, and 12 negative non-food concepts.
- [alias_mapping_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/alias_mapping_35_11a1.json) — 8,200 surface-form alias-to-canonical mappings (zero collisions).
- [build_dataset_35_11a1.py](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/build_dataset_35_11a1.py) — Leak-resistant dataset builder with SHA-256 + 64-bit dHash perceptual deduplication.
- [benchmark_manifest_35_11a1.csv](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/benchmark_manifest_35_11a1.csv) — Full 647-image single-food benchmark manifest across 251 distinct foods.
- [calibration_split_35_11a1.csv](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/calibration_split_35_11a1.csv) — 141-image calibration split manifest.
- [lockbox_manifest_35_11a1.csv](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/lockbox_manifest_35_11a1.csv) — 367-image untouched final lockbox manifest.
- [dataset_summary_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/dataset_summary_35_11a1.json) — Full dataset provenance, deduplication audit, non-food (`108`), mixed-meal (`48`), and true text-OOV (`17`) records.
- [eval_v5_baseline_35_11a1.py](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/eval_v5_baseline_35_11a1.py) & [v5_predictions_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/v5_predictions_35_11a1.json) — `fitfuel_food_v5.tflite` baseline predictions and latencies.
- [run_benchmark_35_11a1.py](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/run_benchmark_35_11a1.py) & [refine_results_35_11a1.py](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/refine_results_35_11a1.py) — End-to-end multimodal evaluation, ONNX FP32/FP16/INT8 export, and ablation runner.
- [candidate_metadata_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/candidate_metadata_35_11a1.json) — Architectural metadata for all candidates.
- [precomputed_text_embeddings_35_11a1.npz](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/precomputed_text_embeddings_35_11a1.npz) — Precomputed L2-normalized FP16 text embeddings (`8.38 MB` combined archive for all 4 candidates; `2.00 MB`–`3.00 MB` per candidate).
- [results_35_11a1.json](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/results_35_11a1.json) — Complete JSON benchmark output across all splits and experiments.
- [results_accuracy_35_11a1.csv](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/results_accuracy_35_11a1.csv) — Tabular accuracy results across all candidates and splits.
- [latency_results_35_11a1.csv](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/latency_results_35_11a1.csv) — Tabular quantization, size, latency, RAM, and conversion fidelity metrics.
- [report_35_11a1.md](file:///c:/projects/FitFuel/tools/benchmarks/food_open_vocabulary/report_35_11a1.md) — This full benchmark report.

---

## 20. Verification Commands Run
1. `python tools/benchmarks/food_open_vocabulary/build_vocabulary_35_11a1.py` -> Generated `2,050` canonical foods + `6,150` aliases (`0` collisions, `100%` FitFuel-238 coverage).
2. `python tools/benchmarks/food_open_vocabulary/build_dataset_35_11a1.py` -> Generated `647` food images (`251` foods) + `108` non-food + `48` mixed-meal + `17` True Text-OOV (`0` cross-split duplicates).
3. `python tools/benchmarks/food_open_vocabulary/eval_v5_baseline_35_11a1.py` -> Evaluated `fitfuel_food_v5.tflite` across all `647` food images (`5.34 ms` P50).
4. `python tools/benchmarks/food_open_vocabulary/run_benchmark_35_11a1.py` & `refine_results_35_11a1.py` -> Evaluated `TinyCLIP-ViT-8M/16`, `TinyCLIP-ViT-40M/32`, `OpenCLIP-ViT-B/32`, and `SigLIP-B/16` (including ONNX FP32/FP16/INT8 export & conversion validation).
5. `adb devices` -> Verified `RZCW8201QBV` connection status (`Connected: NO`).
6. `flutter analyze --no-pub` -> **`No issues found!`**
7. `flutter test --no-pub test/features/food_scan/phase_35_10_3_oov_safety_nutrition_ui_test.dart test/features/food_scan/phase_35_10_2_free_scan_ui_test.dart test/features/food_scan/phase_35_10_1_free_first_routing_lock_test.dart` -> **`31/31 tests passed!` (0 regressions in Phase 35.10 production scanner).**

---

## 21. Next Recommended Action
1. **Connect Samsung Android device `RZCW8201QBV`** via USB debugging (`adb devices`) and run a standalone on-device ONNX Runtime Mobile / LiteRT benchmark harness comparing:
   - **`SigLIP-B/16` Dynamic INT8 (`94.44 MB` vision encoder + `3.00 MB` FP16 text index)**
   - **`TinyCLIP-ViT-40M/32` Dynamic INT8 (`38.45 MB` vision encoder + `2.00 MB` FP16 text index)**
   to measure real-phone cold start, warm P50/P90 latency, peak PSS/RSS memory, and 20-consecutive-scan thermal stability.
2. Once `RZCW8201QBV` latency (`<= 500–800 ms` target) and memory stability are confirmed, proceed to **Phase 35.11B**: a **Two-Tier Local Recognition Cascade** where `fitfuel_food_v5` (`5.3 ms`) handles high-confidence trusted V5 scans and the local open-vocabulary vision encoder + precomputed 2,050-food text index handles all other food scans offline (`cloud_calls = 0`) with user-confirmed FitFuel nutrition lookup.
