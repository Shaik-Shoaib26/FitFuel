# PHASE 35.11A.1 — TRUE OPEN-VOCABULARY VISION-LANGUAGE MODEL LICENSE VERIFICATION REPORT

**Verification Date:** 2026-10-11  
**Policy (Section 3 — License Hard Gate):** Any candidate model whose code or pretrained weights are unknown, ambiguous, non-commercial, research-only, or incompatible with Google Play Store commercial redistribution is marked **`REJECTED — LICENSE`** and excluded from recommendation.

---

## Summary Table

| Candidate | Model License | Code License | Commercial Use Allowed? | Redistribution Allowed? | Attribution Required? | Source URL / Reference | Verification Date | Gate Decision |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Candidate A1:** `wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M` | MIT License (Note: YFCC15M distillation corpus includes CC BY-NC subset) | MIT License | Conditional (MIT weights, YFCC15M provenance caveat) | Conditional | YES (MIT notice) | `https://huggingface.co/wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M`, `https://github.com/microsoft/Cream/blob/main/LICENSE` | 2026-10-11 | **BENCHMARKED ONLY — PREFER LAION-400M VARIANT (A2)** |
| **Candidate A2:** `wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M` | MIT License | MIT License | **YES** | **YES** | YES (MIT copyright & license notice) | `https://huggingface.co/wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M`, `https://github.com/microsoft/Cream/blob/main/LICENSE` | 2026-10-11 | **PASS — COMMERCIAL & PLAY STORE PERMITTED** |
| **Candidate B:** `laion/CLIP-ViT-B-32-laion2B-s34B-b79K` | MIT License | MIT License | **YES** | **YES** | YES (MIT copyright & license notice) | `https://huggingface.co/laion/CLIP-ViT-B-32-laion2B-s34B-b79K`, `https://github.com/mlfoundations/open_clip/blob/main/LICENSE` | 2026-10-11 | **PASS — COMMERCIAL & PLAY STORE PERMITTED** |
| **Candidate C:** `google/siglip-base-patch16-224` | Apache-2.0 | Apache-2.0 | **YES** | **YES** | YES (Apache-2.0 notice & attribution) | `https://huggingface.co/google/siglip-base-patch16-224`, `https://github.com/google-research/big_vision/blob/main/LICENSE` | 2026-10-11 | **PASS — COMMERCIAL & PLAY STORE PERMITTED** |
| **Candidate D:** `apple/MobileCLIP-S0` (`apple/MobileCLIP-S1`, `timm/MobileCLIP2-S0-OpenCLIP`) | Apple Machine Learning Research Model License (`apple-amlr`) | Apple Sample Code / MIT | **NO (Research Only)** | **NO (Commercial redistribution prohibited)** | N/A | `https://huggingface.co/apple/MobileCLIP-S0`, `https://github.com/apple/ml-mobileclip/blob/main/LICENSE_weights_data` | 2026-10-11 | **REJECTED — LICENSE** |
| **Candidate E:** `facebook/metaclip-b32-400m` | `CC-BY-NC-4.0` (Non-Commercial) | `CC-BY-NC-4.0` | **NO (Non-Commercial Only)** | **NO (Commercial redistribution prohibited)** | N/A | `https://huggingface.co/facebook/metaclip-b32-400m`, `https://github.com/facebookresearch/MetaCLIP/blob/main/LICENSE` | 2026-10-11 | **REJECTED — LICENSE** |

---

## Detailed Candidate Verification

### 1. `wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M` (Candidate A1 — Ultra-Small Mobile ViT)
- **Official Source:** `https://huggingface.co/wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M` and `https://github.com/microsoft/Cream/tree/main/TinyCLIP`
- **Model & Code License:** MIT License (`license: mit` in official Hugging Face model card YAML and Microsoft `Cream` repository `LICENSE`).
- **Commercial Use & Redistribution:** While Microsoft explicitly releases the code and checkpoint under the MIT License, this specific 8M checkpoint was distilled on `YFCC15M` (Yahoo Flickr Creative Commons 15M), which contains images under varied Creative Commons licenses including `CC BY-NC`. We therefore benchmark it for ultra-small mobile scaling comparison (~8.3M vision parameters) but **do not recommend shipping the YFCC15M checkpoint commercially** when the `LAION-400M` MIT-licensed sibling (`wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M`) is available.
- **Attribution:** MIT copyright notice required.
- **Decision:** **BENCHMARKED FOR ULTRA-SMALL SCALING — DO NOT RECOMMEND OVER LAION-400M SIBLING (A2)**

### 2. `wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M` (Candidate A2 — Mobile/Small Patch-32 ViT)
- **Official Source:** `https://huggingface.co/wkcn/TinyCLIP-ViT-40M-32-Text-19M-LAION400M` and `https://github.com/microsoft/Cream/blob/main/LICENSE`
- **Model & Code License:** MIT License (`license: mit`).
- **Commercial Use:** **PERMITTED (YES)**.
- **Redistribution:** **PERMITTED (YES)** — allows conversion to ONNX / TFLite, quantization (FP16/INT8), and bundling of the vision encoder + precomputed text embeddings inside a commercial Google Play Store application.
- **Attribution:** Include the Microsoft Corporation MIT License copyright notice in FitFuel's third-party notices.
- **Decision:** **PASS — APPROVED FOR BENCHMARK & COMMERCIAL MOBILE USE**

### 3. `laion/CLIP-ViT-B-32-laion2B-s34B-b79K` (Candidate B — Medium Balance OpenCLIP ViT-B/32)
- **Official Source:** `https://huggingface.co/laion/CLIP-ViT-B-32-laion2B-s34B-b79K` and `https://github.com/mlfoundations/open_clip/blob/main/LICENSE`
- **Model & Code License:** MIT License (`license: mit`).
- **Commercial Use:** **PERMITTED (YES)**.
- **Redistribution:** **PERMITTED (YES)** — unrestricted commercial conversion, quantization, and on-device distribution with MIT license notice.
- **Attribution:** Include OpenCLIP / LAION MIT License notice in third-party open-source notices.
- **Decision:** **PASS — APPROVED FOR BENCHMARK & COMMERCIAL MOBILE USE**

### 4. `google/siglip-base-patch16-224` (Candidate C — Stronger Pairwise Sigmoid ViT-B/16)
- **Official Source:** `https://huggingface.co/google/siglip-base-patch16-224` and `https://github.com/google-research/big_vision/blob/main/LICENSE`
- **Model & Code License:** Apache License 2.0 (`license: apache-2.0`).
- **Commercial Use:** **PERMITTED (YES)**.
- **Redistribution:** **PERMITTED (YES)** — Apache-2.0 explicitly permits commercial use, modification, format conversion/quantization, and binary redistribution inside mobile apps.
- **Attribution:** Include Apache License 2.0 text and Google Research attribution notice in FitFuel's third-party notices.
- **Decision:** **PASS — APPROVED FOR BENCHMARK & COMMERCIAL MOBILE USE**

### 5. `apple/MobileCLIP-S0`, `apple/MobileCLIP-S1`, `timm/MobileCLIP2-S0-OpenCLIP` (Candidate D)
- **Official Source:** `https://huggingface.co/apple/MobileCLIP-S0`, `https://huggingface.co/timm/MobileCLIP2-S0-OpenCLIP`, `https://github.com/apple/ml-mobileclip/blob/main/LICENSE_weights_data`
- **Model License:** Apple Machine Learning Research Model License (`apple-amlr`).
- **Commercial Use:** **PROHIBITED (NO)** — strictly restricted to non-commercial research.
- **Redistribution:** **PROHIBITED (NO)** — cannot be bundled in a commercial Play Store application.
- **Attribution:** N/A (Rejected).
- **Decision:** **REJECTED — LICENSE**

### 6. `facebook/metaclip-b32-400m` (Candidate E)
- **Official Source:** `https://huggingface.co/facebook/metaclip-b32-400m`, `https://github.com/facebookresearch/MetaCLIP/blob/main/LICENSE`
- **Model License:** Creative Commons Attribution-NonCommercial 4.0 International (`CC-BY-NC-4.0`).
- **Commercial Use:** **PROHIBITED (NO)**.
- **Redistribution:** Non-commercial only; incompatible with commercial Play Store distribution.
- **Attribution:** N/A (Rejected).
- **Decision:** **REJECTED — LICENSE**
