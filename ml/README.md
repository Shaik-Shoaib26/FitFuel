# FitFuel On-Device Food Classification Pipeline (MobileNetV3 V1)

This directory contains the machine learning training, dataset collection, quantization, evaluation, and export pipeline for FitFuel's on-device food vision classifier.

---

## 1. Phase 35.9.1 V1 Scope & Architecture
- **Catalog Size:** 238 curated foods in FitFuel catalog (`PredefinedFoodData`).
- **V1 Target Classes:** 50 high-value, common, visually distinctive foods (Fruits, Indian Breakfast, Staples, Protein, Dairy, Legumes, Vegetables, Snacks).
- **Label Mapping:** 1:1 mapping with FitFuel stable IDs (`predefined_food_id`) listed in `labels.txt` and `assets/ml/fitfuel_food_labels.txt`.
- **Hybrid Routing:** Local classifier handles supported 50 classes. Scans for unsupported food classes or low-confidence / ambiguous predictions gracefully route to Gemini cloud fallback.
- **Macronutrient Integrity:** The classifier predicts **only food identity and confidence**. Calories, protein, carbohydrates, and fats are **never predicted by the ML model**; all nutritional values are resolved deterministically from FitFuel's database.

---

## 2. Directory Layout
```
ml/
├── README.md                 # Pipeline documentation and guidelines
├── requirements.txt          # Python ML dependencies
├── labels.txt                # 50 deterministic FitFuel food IDs for V1
├── dataset_manifest.csv      # Labeled training dataset manifest (300 images)
├── collect_dataset.py        # Wikimedia Commons verified-license dataset collector
├── train_food_classifier.py  # MobileNetV3 transfer learning training script
├── export_tflite.py          # Quantization and TFLite model export
├── evaluate_model.py         # Held-out evaluation, Top-1/Top-3 accuracy & latency
├── checkpoints/              # Saved model checkpoints (best_model.keras)
└── dataset/                  # Labeled images partitioned by split and class
    ├── train/
    ├── validation/
    └── test/
```

---

## 3. Dataset Collection & Licensing
Dataset collected using `collect_dataset.py` querying Wikimedia Commons:
- **Total Images:** 300 labeled images across 50 classes.
- **Splits:** 200 train / 50 validation / 50 test.
- **Licenses:** Verified Creative Commons (CC BY-SA 4.0, CC BY-SA 3.0, CC BY 2.0, CC0, Public Domain).
- **Manifest:** Recorded in `dataset_manifest.csv` with `image_path,food_id,food_name,source,source_url_or_reference,license,split`.

---

## 4. Training
Transfer learning using MobileNetV3Large backbone:
```bash
python train_food_classifier.py \
  --manifest dataset_manifest.csv \
  --labels labels.txt \
  --backbone MobileNetV3Large \
  --img_size 224 \
  --batch_size 16 \
  --epochs 12 \
  --output_dir checkpoints/
```
- **Phase 1:** Classification head trained with frozen ImageNet backbone (12 epochs, Adam lr=1e-3).
- **Phase 2:** Fine-tuning top 30 backbone layers (6 epochs, Adam lr=1e-4).
- **Checkpoint:** Best model checkpoint saved to `checkpoints/best_model.keras`.

---

## 5. TFLite Export & Quantization
Exported to TensorFlow Lite with float16 post-training quantization:
```bash
python export_tflite.py \
  --checkpoint checkpoints/best_model.keras \
  --quantization float16 \
  --output ../assets/ml/fitfuel_food_classifier.tflite
```
- **Output Artifact:** `assets/ml/fitfuel_food_classifier.tflite` (6.27 MB).
- **Labels File:** `assets/ml/fitfuel_food_labels.txt` (50 lines).

---

## 6. Evaluation Results (Test Split)
Evaluated on 50 held-out test images across all 50 classes:
```bash
python evaluate_model.py \
  --model ../assets/ml/fitfuel_food_classifier.tflite \
  --labels labels.txt \
  --manifest dataset_manifest.csv \
  --split test
```
- **Supported Classes:** 50
- **Test Samples:** 50 images
- **Top-1 Accuracy:** 40.00%
- **Top-3 Accuracy:** 64.00%
- **Mean Inference Latency:** 11.22 ms (CPU XNNPACK delegate)
- **P95 Latency:** 12.98 ms
- **Model Size:** 6.27 MB (float16)
