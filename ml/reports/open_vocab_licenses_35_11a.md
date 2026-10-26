# Phase 35.11A — Open-Vocabulary Food Vision Model Licensing & Feasibility Audit

## Hard Gate Policy (Section 6)

FitFuel is intended for public distribution on the Google Play Store. Any on-device open-vocabulary vision-language model must have **both code and pretrained weights** licensed under terms that clearly permit commercial redistribution inside a mobile application.

---

## Candidate 1: `fitfuel_openvocab_mnv3_minilm_384` (MobileNetV3-Large + MiniLM-L6-v2 Dual-Encoder)
- **Model Name**: `fitfuel_openvocab_mnv3_minilm_384`
- **Source**:
  - Vision Encoder Backbone: TensorFlow / Keras `MobileNetV3Large` (`google/mobilenet_v3`) + FitFuel V5 penultimate feature projection
  - Text Encoder (Offline Precomputation Only): `sentence-transformers/all-MiniLM-L6-v2` (`https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2`)
- **Code License**: Apache-2.0
- **Weights License**: Apache-2.0 (`MobileNetV3Large` Apache-2.0; `sentence-transformers/all-MiniLM-L6-v2` Apache-2.0)
- **Commercial-Use Status**: **PERMITTED (YES)**
- **Redistribution Considerations**:
  - Precomputed 384-D normalized text embeddings (`~450 KB` binary / JSON) and the `.tflite` vision encoder (`~6.5 MB` Float16) may be bundled directly in the Android APK/AAB under Apache-2.0.
  - Text encoder weights (`all-MiniLM-L6-v2`) remain in the offline development pipeline and do not need to be shipped inside the mobile binary.
- **Attribution Requirements**:
  - Include Apache License 2.0 text and copyright notices for TensorFlow/Keras `MobileNetV3Large` and `sentence-transformers/all-MiniLM-L6-v2` in FitFuel's third-party notices.
- **Gate Decision**: **PASS — BENCHMARKED (BEST CANDIDATE)**

---

## Candidate 2: `fitfuel_openvocab_effnetb0_minilm_384` (EfficientNet-B0 + MiniLM-L6-v2 Dual-Encoder)
- **Model Name**: `fitfuel_openvocab_effnetb0_minilm_384`
- **Source**:
  - Vision Encoder Backbone: TensorFlow / Keras `EfficientNetB0` (`google/efficientnet`) + 384-D semantic projection head
  - Text Encoder (Offline Precomputation Only): `sentence-transformers/all-MiniLM-L6-v2` (`https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2`)
- **Code License**: Apache-2.0
- **Weights License**: Apache-2.0
- **Commercial-Use Status**: **PERMITTED (YES)**
- **Redistribution Considerations**:
  - Permitted for commercial Play Store distribution under Apache-2.0.
- **Attribution Requirements**:
  - Standard Apache License 2.0 attribution in FitFuel's third-party license notices.
- **Gate Decision**: **PASS — BENCHMARKED (PROMISING SECONDARY CANDIDATE)**

---

## Candidate 3: Google SigLIP / SigLIP 2 (`google/siglip-base-patch16-224` & `google/siglip2-base-patch16-224`)
- **Model Name**: `google/siglip-base-patch16-224` (`ViT-B/16` Sigmoid Loss for Language Image Pre-Training)
- **Source**: Google Research (`https://huggingface.co/google/siglip-base-patch16-224`, `https://github.com/google-research/big_vision`)
- **Code License**: Apache-2.0
- **Weights License**: Apache-2.0 (pretrained on WebLI)
- **Commercial-Use Status**: **PERMITTED (YES)**
- **Redistribution Considerations**:
  - Legally permissible under Apache-2.0.
  - **Technical/Size Gate**: Full checkpoint is ~813 MB (Float32); vision-only encoder (`ViT-B/16`, ~86M parameters) is ~344 MB (Float32), ~172 MB (Float16), and ~88 MB (INT8). Bundling inside FitFuel's 79.9 MB release AAB would increase app size to ~168–252 MB and require either ONNX Runtime Mobile or TFLite `SELECT_TF_OPS` (Flex delegate adding ~40 MB native `.so` per ABI), with ~650–1,400 ms mobile CPU latency.
- **Attribution Requirements**: Apache License 2.0 notice.
- **Gate Decision**: **PASS LICENSE / DEFER DIRECT BUNDLING (Too large for static APK/AAB bundling without dynamic on-demand model delivery)**

---

## Candidate 4: Apple MobileCLIP (`apple/MobileCLIP-S0`, `apple/MobileCLIP-S1`, `apple/MobileCLIP-S2`)
- **Model Name**: `apple/MobileCLIP-S0`
- **Source**: Apple (`https://github.com/apple/ml-mobileclip`, `https://huggingface.co/apple/MobileCLIP-S0`)
- **Code License**: Apple Sample Code License / MIT-style repository code
- **Weights License**: **Apple Machine Learning Research Model License (AMLR — Non-Commercial Research Only)**
- **Commercial-Use Status**: **PROHIBITED (NO — Research / Non-Commercial Only)**
- **Redistribution Considerations**:
  - Although repository training/inference scripts contain permissive headers, the pretrained model checkpoints released by Apple are governed by the Apple Machine Learning Research Model License (`amlr`), which restricts use to non-commercial research and prohibits commercial redistribution in a Play Store app.
- **Attribution Requirements**: N/A (Rejected)
- **Gate Decision**: **REJECT (Fails Section 6 Hard Licensing Gate)**

---

## Candidate 5: TinyCLIP (`wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M`) & OpenCLIP (`laion/CLIP-ViT-B-32-laion2B-s34B-b79K`)
- **Model Name**: `wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M` / `laion/CLIP-ViT-B-32-laion2B-s34B-b79K`
- **Source**: Microsoft Research (`https://github.com/microsoft/Cream/tree/main/TinyCLIP`) / MLFoundations (`https://github.com/mlfoundations/open_clip`)
- **Code License**: MIT License
- **Weights License**: MIT License (however, TinyCLIP weights are distilled on YFCC15M whose underlying Yahoo/Flickr Creative Commons images include CC BY-NC and CC BY-SA subsets; OpenCLIP ViT-B/32 vision encoder is 87.8M parameters / ~351 MB Float32, ~176 MB Float16)
- **Commercial-Use Status**: **LICENSE REVIEW REQUIRED** (TinyCLIP YFCC15M dataset derivative status) / **TOO LARGE** (OpenCLIP ViT-B/32 ~176 MB FP16)
- **Redistribution Considerations**:
  - Marked `LICENSE REVIEW REQUIRED` for TinyCLIP due to YFCC15M dataset terms; OpenCLIP ViT-B/32 rejected for static mobile bundling due to 176+ MB vision encoder size.
- **Attribution Requirements**: MIT License notice (if cleared).
- **Gate Decision**: **REJECT (`LICENSE REVIEW REQUIRED` / Excessive Bundled Size)**
