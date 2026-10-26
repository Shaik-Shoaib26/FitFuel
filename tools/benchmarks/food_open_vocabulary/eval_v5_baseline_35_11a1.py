"""
Evaluate production-like fitfuel_food_v5.tflite baseline on all images in
benchmark_manifest_35_11a1.csv and save predictions to v5_predictions_35_11a1.json.
"""
import csv
import json
import time
from pathlib import Path
import numpy as np
from PIL import Image
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "ml" / "checkpoints" / "fitfuel_food_v5.tflite"
LABELS_PATH = ROOT / "assets" / "ml" / "fitfuel_food_labels.txt"
VOCAB_PATH = OUT_DIR / "vocabulary_35_11a1.json"
MANIFEST_PATH = OUT_DIR / "benchmark_manifest_35_11a1.csv"


def preprocess_v5(img_path: Path) -> np.ndarray:
    with Image.open(img_path) as img:
        img = img.convert("RGB")
        # Aspect-preserving center crop + 224x224 bilinear resize (matching Phase 35.10.2)
        w, h = img.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
        img = img.resize((224, 224), Image.Resampling.BILINEAR)
        arr = np.asarray(img, dtype=np.float32)
        return np.expand_dims(arr, axis=0)


def main():
    with open(VOCAB_PATH, "r", encoding="utf-8") as f:
        vocab_data = json.load(f)
    id_to_name = {c["canonicalFoodId"]: c["canonicalName"] for c in vocab_data["entries"]}

    with open(LABELS_PATH, "r", encoding="utf-8") as f:
        classes = [line.strip() for line in f if line.strip()]

    class_id_to_name = {}
    for idx, cid in enumerate(classes):
        cname = id_to_name.get(cid, cid.replace("predefined_", "").replace("_", " ").title())
        class_id_to_name[idx] = (cid, cname)

    interpreter = tf.lite.Interpreter(model_path=str(MODEL_PATH), num_threads=4)
    interpreter.allocate_tensors()
    in_details = interpreter.get_input_details()[0]
    out_details = interpreter.get_output_details()[0]

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    results = {}
    latencies_ms = []
    for row in rows:
        img_id = row["image_id"]
        img_path = ROOT / row["image_path"]
        x = preprocess_v5(img_path)
        t0 = time.perf_counter()
        interpreter.set_tensor(in_details["index"], x)
        interpreter.invoke()
        probs = interpreter.get_tensor(out_details["index"])[0].astype(np.float64)
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)

        if probs.max() > 1.001 or probs.min() < -0.001:
            e = np.exp(probs - np.max(probs))
            probs = e / e.sum()

        top5_idx = np.argsort(probs)[::-1][:5]
        top5 = []
        for idx in top5_idx:
            cid, cname = class_id_to_name[int(idx)]
            top5.append({
                "class_index": int(idx),
                "canonical_food_id": cid,
                "canonical_name": cname,
                "confidence": round(float(probs[int(idx)]), 6),
            })
        margin = float(probs[top5_idx[0]] - probs[top5_idx[1]])
        results[img_id] = {
            "top1_id": top5[0]["canonical_food_id"],
            "top1_name": top5[0]["canonical_name"],
            "top1_conf": top5[0]["confidence"],
            "top1_top2_margin": round(margin, 6),
            "top5": top5,
        }

    out = {
        "model": "fitfuel_food_v5.tflite",
        "modelSizeBytes": MODEL_PATH.stat().st_size,
        "modelSizeMB": round(MODEL_PATH.stat().st_size / (1024 * 1024), 2),
        "numClasses": len(classes),
        "meanLatencyMs": round(float(np.mean(latencies_ms)), 2),
        "p50LatencyMs": round(float(np.percentile(latencies_ms, 50)), 2),
        "p90LatencyMs": round(float(np.percentile(latencies_ms, 90)), 2),
        "predictions": results,
    }
    out_file = OUT_DIR / "v5_predictions_35_11a1.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
    print(f"[V5 Baseline] Evaluated {len(results)} images | P50: {out['p50LatencyMs']} ms | Saved to {out_file.name}")


if __name__ == "__main__":
    main()
