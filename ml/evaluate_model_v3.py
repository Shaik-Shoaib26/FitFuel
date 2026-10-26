#!/usr/bin/env python3
"""
FitFuel Phase 35.9.3 - Comprehensive Model Evaluation & Calibration Script V3
Evaluates TFLite food vision classifiers on:
1. Held-out test split (413 images across 50 classes)
2. High-confidence precision across thresholds (0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95)
3. Ambiguity margin analysis (0.05, 0.10, 0.15, 0.20, 0.25)
4. Non-Food OOD rejection (110 images)
5. Unsupported Food rejection (110 images)
6. Mixed-Meal negative rejection (55 images)
7. ECE (Expected Calibration Error)
8. Latency profiling & model footprint

Outputs ml/reports/model_evaluation_v3.json.
"""

import argparse
import csv
import json
import os
import sys
import time
import numpy as np
import tensorflow as tf


def parse_args():
    parser = argparse.ArgumentParser(description="Evaluate FitFuel Model Accuracy & Calibration V3")
    parser.add_argument("--model", type=str, required=True, help="Path to .tflite model file")
    parser.add_argument("--labels", type=str, default="labels.txt", help="Path to labels.txt")
    parser.add_argument("--manifest", type=str, default="dataset_manifest.csv", help="Test manifest CSV")
    parser.add_argument("--non_food_manifest", type=str, default="non_food_manifest.csv", help="Non-food manifest CSV")
    parser.add_argument("--unsupported_manifest", type=str, default="unsupported_food_manifest.csv", help="Unsupported food manifest CSV")
    parser.add_argument("--mixed_meal_manifest", type=str, default="mixed_meal_manifest.csv", help="Mixed meal manifest CSV")
    parser.add_argument("--output_report", type=str, default="reports/model_evaluation_v3.json", help="Path to output JSON")
    return parser.parse_args()


def load_labels(labels_file):
    with open(labels_file, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    return labels, {label: i for i, label in enumerate(labels)}


def run_inference(interpreter, input_details, output_details, image_path, height, width):
    img = tf.keras.utils.load_img(image_path, target_size=(height, width))
    arr = tf.keras.utils.img_to_array(img)
    input_data = np.expand_dims(arr, axis=0)

    if input_details[0]["dtype"] == np.float32:
        input_data = input_data.astype(np.float32)
    elif input_details[0]["dtype"] == np.uint8:
        input_data = input_data.astype(np.uint8)

    start = time.perf_counter()
    interpreter.set_tensor(input_details[0]["index"], input_data)
    interpreter.invoke()
    output_data = interpreter.get_tensor(output_details[0]["index"])[0]
    latency = (time.perf_counter() - start) * 1000.0

    # If uint8 output, dequantize
    if output_details[0]["dtype"] == np.uint8:
        scale, zero_point = output_details[0]["quantization"]
        if scale > 0:
            output_data = (output_data.astype(np.float32) - zero_point) * scale

    return output_data, latency


def compute_ece(confidences, predictions, ground_truths, num_bins=10):
    bin_boundaries = np.linspace(0, 1, num_bins + 1)
    ece = 0.0
    total_samples = len(confidences)
    if total_samples == 0:
        return 0.0

    for i in range(num_bins):
        bin_lower = bin_boundaries[i]
        bin_upper = bin_boundaries[i + 1]

        in_bin = [(c, p == g) for c, p, g in zip(confidences, predictions, ground_truths)
                  if bin_lower < c <= bin_upper]
        if in_bin:
            bin_size = len(in_bin)
            bin_acc = sum(correct for _, correct in in_bin) / bin_size
            bin_conf = sum(conf for conf, _ in in_bin) / bin_size
            ece += (bin_size / total_samples) * abs(bin_acc - bin_conf)

    return float(ece)


def main():
    args = parse_args()
    if not os.path.exists(args.model):
        print(f"Error: Model '{args.model}' not found.")
        sys.exit(1)

    labels, label_to_index = load_labels(args.labels)
    num_classes = len(labels)
    base_dir = os.path.dirname(os.path.abspath(args.manifest))

    # Initialize TFLite interpreter
    interpreter = tf.lite.Interpreter(model_path=args.model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    height = input_details[0]["shape"][1]
    width = input_details[0]["shape"][2]

    # Load test split
    test_rows = []
    with open(args.manifest, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            if r.get("split") == "test":
                test_rows.append(r)

    print(f"\n============================================================")
    print(f"    FITFUEL PHASE 35.9.3: COMPREHENSIVE MODEL EVALUATION    ")
    print(f"============================================================")
    print(f"Model Artifact:        {args.model}")
    print(f"Supported Classes:     {num_classes}")
    print(f"Held-Out Test Images:  {len(test_rows)}")

    correct_top1 = 0
    correct_top3 = 0
    latencies = []

    y_true = []
    y_pred = []
    top_confs = []
    second_confs = []
    confusion_counts = {}

    for r in test_rows:
        p = r["image_path"]
        if not os.path.isabs(p):
            p = os.path.join(base_dir, p)
        if not os.path.exists(p):
            continue

        food_id = r["food_id"]
        gt = label_to_index.get(food_id, -1)
        if gt == -1:
            continue

        probs, lat = run_inference(interpreter, input_details, output_details, p, height, width)
        latencies.append(lat)

        sorted_indices = np.argsort(probs)[::-1]
        top1 = sorted_indices[0]
        top2 = sorted_indices[1] if len(sorted_indices) > 1 else top1
        top3 = sorted_indices[:3]

        conf1 = float(probs[top1])
        conf2 = float(probs[top2])

        y_true.append(gt)
        y_pred.append(top1)
        top_confs.append(conf1)
        second_confs.append(conf2)

        if top1 == gt:
            correct_top1 += 1
        if gt in top3:
            correct_top3 += 1

        if top1 != gt:
            pair = (labels[gt], labels[top1])
            confusion_counts[pair] = confusion_counts.get(pair, 0) + 1

    total_test = len(y_true)
    top1_acc = (correct_top1 / total_test) * 100 if total_test else 0.0
    top3_acc = (correct_top3 / total_test) * 100 if total_test else 0.0
    mean_lat = float(np.mean(latencies)) if latencies else 0.0
    p95_lat = float(np.percentile(latencies, 95)) if latencies else 0.0
    model_size_mb = os.path.getsize(args.model) / (1024 * 1024)

    # 1. Per-Class Precision, Recall, F1
    per_class_metrics = {}
    class_precisions = []
    for cls_idx, cls_label in enumerate(labels):
        tp = sum(1 for yt, yp in zip(y_true, y_pred) if yt == cls_idx and yp == cls_idx)
        fp = sum(1 for yt, yp in zip(y_true, y_pred) if yt != cls_idx and yp == cls_idx)
        fn = sum(1 for yt, yp in zip(y_true, y_pred) if yt == cls_idx and yp != cls_idx)
        support = sum(1 for yt in y_true if yt == cls_idx)

        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * prec * rec) / (prec + rec) if (prec + rec) > 0 else 0.0

        if support > 0:
            class_precisions.append(prec)

        per_class_metrics[cls_label] = {
            "precision": round(prec, 4),
            "recall": round(rec, 4),
            "f1": round(f1, 4),
            "test_samples": support,
            "correct": tp,
            "top1_class_accuracy_pct": round((tp / support) * 100, 2) if support else 0.0
        }

    # Best & Weakest Classes
    sorted_by_f1 = sorted(per_class_metrics.items(), key=lambda x: (x[1]["f1"], x[1]["recall"]), reverse=True)
    best_classes = sorted_by_f1[:8]
    weakest_classes = sorted_by_f1[-8:]

    # Most confused pairs
    sorted_confusions = sorted(confusion_counts.items(), key=lambda x: x[1], reverse=True)[:8]

    # 2. High-Confidence Precision across Thresholds (Section 26)
    thresholds = [0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95]
    threshold_analysis = {}

    for th in thresholds:
        accepted_idx = [i for i, c in enumerate(top_confs) if c >= th]
        accepted_count = len(accepted_idx)
        rejected_count = total_test - accepted_count
        coverage = (accepted_count / total_test) * 100 if total_test else 0.0

        accepted_correct = sum(1 for i in accepted_idx if y_true[i] == y_pred[i])
        accepted_fp = accepted_count - accepted_correct
        prec_accepted = (accepted_correct / accepted_count) * 100 if accepted_count else 100.0
        fp_rate = (accepted_fp / accepted_count) * 100 if accepted_count else 0.0

        threshold_analysis[f"{th:.2f}"] = {
            "accepted_scans": accepted_count,
            "rejected_scans": rejected_count,
            "coverage_pct": round(coverage, 2),
            "correct_accepted": accepted_correct,
            "incorrect_accepted": accepted_fp,
            "accepted_precision_pct": round(prec_accepted, 2),
            "false_positive_rate_pct": round(fp_rate, 2),
            "false_positives": accepted_fp
        }

    # 3. Ambiguity Margin Analysis (Section 29)
    margins = [0.05, 0.10, 0.15, 0.20, 0.25]
    margin_analysis = {}
    for mg in margins:
        accepted = [i for i in range(total_test) if top_confs[i] >= 0.80 and (top_confs[i] - second_confs[i]) >= mg]
        acc_count = len(accepted)
        acc_correct = sum(1 for i in accepted if y_true[i] == y_pred[i])
        prec = (acc_correct / acc_count) * 100 if acc_count else 100.0
        margin_analysis[f"{mg:.2f}"] = {
            "accepted": acc_count,
            "precision_pct": round(prec, 2),
            "false_positives": acc_count - acc_correct
        }

    # 4. Non-Food OOD Rejection (Section 33 & 34)
    non_food_tested = 0
    non_food_false_accepted_080 = 0
    non_food_false_accepted_085 = 0
    if os.path.exists(args.non_food_manifest):
        with open(args.non_food_manifest, "r", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                p = r["image_path"]
                if not os.path.isabs(p):
                    p = os.path.join(base_dir, p)
                if not os.path.exists(p):
                    continue
                non_food_tested += 1
                probs, _ = run_inference(interpreter, input_details, output_details, p, height, width)
                max_conf = float(np.max(probs))
                if max_conf >= 0.80:
                    non_food_false_accepted_080 += 1
                if max_conf >= 0.85:
                    non_food_false_accepted_085 += 1

    # 5. Unsupported Food Rejection (Section 32 & 34)
    unsupported_tested = 0
    unsupported_false_accepted_080 = 0
    unsupported_false_accepted_085 = 0
    if os.path.exists(args.unsupported_manifest):
        with open(args.unsupported_manifest, "r", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                p = r["image_path"]
                if not os.path.isabs(p):
                    p = os.path.join(base_dir, p)
                if not os.path.exists(p):
                    continue
                unsupported_tested += 1
                probs, _ = run_inference(interpreter, input_details, output_details, p, height, width)
                max_conf = float(np.max(probs))
                if max_conf >= 0.80:
                    unsupported_false_accepted_080 += 1
                if max_conf >= 0.85:
                    unsupported_false_accepted_085 += 1

    # 6. Mixed-Meal Negative Rejection (Section 35)
    mixed_meals_tested = 0
    mixed_meals_false_accepted_080 = 0
    mixed_meals_false_accepted_085 = 0
    if os.path.exists(args.mixed_meal_manifest):
        with open(args.mixed_meal_manifest, "r", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                p = r["image_path"]
                if not os.path.isabs(p):
                    p = os.path.join(base_dir, p)
                if not os.path.exists(p):
                    continue
                mixed_meals_tested += 1
                probs, _ = run_inference(interpreter, input_details, output_details, p, height, width)
                max_conf = float(np.max(probs))
                if max_conf >= 0.80:
                    mixed_meals_false_accepted_080 += 1
                if max_conf >= 0.85:
                    mixed_meals_false_accepted_085 += 1

    # Expected Calibration Error (ECE)
    ece_val = compute_ece(top_confs, y_pred, y_true, num_bins=10)

    # Determine Production Enabled Classes
    # A class is production enabled if it has >= 80% precision at high confidence or solid overall precision
    prod_enabled = []
    for cls_label, m in per_class_metrics.items():
        if m["precision"] >= 0.50 and m["correct"] >= 2:
            prod_enabled.append(cls_label)

    # Compile Evaluation Report
    report = {
        "model_artifact": args.model,
        "model_version": "fitfuel_food_v3",
        "model_size_mb": round(model_size_mb, 2),
        "test_samples": total_test,
        "overall_top1_accuracy_pct": round(top1_acc, 2),
        "overall_top3_accuracy_pct": round(top3_acc, 2),
        "mean_latency_ms": round(mean_lat, 2),
        "p95_latency_ms": round(p95_lat, 2),
        "expected_calibration_error": round(ece_val, 4),
        "threshold_analysis": threshold_analysis,
        "margin_analysis": margin_analysis,
        "rejection_metrics": {
            "non_food_images_tested": non_food_tested,
            "non_food_false_accepted_at_080": non_food_false_accepted_080,
            "non_food_false_accepted_at_085": non_food_false_accepted_085,
            "non_food_rejection_rate_at_085_pct": round(100.0 - (non_food_false_accepted_085 / max(1, non_food_tested) * 100), 2),
            "unsupported_foods_tested": unsupported_tested,
            "unsupported_false_accepted_at_080": unsupported_false_accepted_080,
            "unsupported_false_accepted_at_085": unsupported_false_accepted_085,
            "unsupported_rejection_rate_at_085_pct": round(100.0 - (unsupported_false_accepted_085 / max(1, unsupported_tested) * 100), 2),
            "mixed_meals_tested": mixed_meals_tested,
            "mixed_meals_false_accepted_at_080": mixed_meals_false_accepted_080,
            "mixed_meals_false_accepted_at_085": mixed_meals_false_accepted_085,
            "mixed_meals_rejection_rate_at_085_pct": round(100.0 - (mixed_meals_false_accepted_085 / max(1, mixed_meals_tested) * 100), 2),
        },
        "most_confused_pairs": [{"true_food": t, "predicted_food": p, "count": c} for (t, p), c in sorted_confusions],
        "top_performing_classes": [{"food_id": k, **v} for k, v in best_classes],
        "weakest_classes": [{"food_id": k, **v} for k, v in weakest_classes],
        "production_enabled_classes_count": len(prod_enabled),
        "production_enabled_classes": prod_enabled,
        "per_class_metrics": per_class_metrics
    }

    os.makedirs(os.path.dirname(args.output_report), exist_ok=True)
    with open(args.output_report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    # Print Formatted Evaluation Report
    print(f"Top-1 Accuracy:        {top1_acc:.2f}%")
    print(f"Top-3 Accuracy:        {top3_acc:.2f}%")
    print(f"Mean Latency (CPU):    {mean_lat:.2f} ms (P95: {p95_lat:.2f} ms)")
    print(f"Model Size:            {model_size_mb:.2f} MB")
    print(f"ECE Calibration Error: {ece_val:.4f}")
    print("\n--- HIGH-CONFIDENCE PRECISION ACROSS THRESHOLDS ---")
    for th, stats in threshold_analysis.items():
        print(f"  Threshold {th} -> Coverage: {stats['coverage_pct']:5.1f}% | Precision: {stats['accepted_precision_pct']:5.1f}% | Correct: {stats['correct_accepted']} | FP: {stats['false_positives']}")

    print("\n--- NON-FOOD, UNSUPPORTED FOOD & MIXED MEAL REJECTION ---")
    print(f"  Non-Food:        {non_food_tested} tested | {non_food_false_accepted_085} false accepts @ 0.85 ({report['rejection_metrics']['non_food_rejection_rate_at_085_pct']}% rejected)")
    print(f"  Unsupported:     {unsupported_tested} tested | {unsupported_false_accepted_085} false accepts @ 0.85 ({report['rejection_metrics']['unsupported_rejection_rate_at_085_pct']}% rejected)")
    print(f"  Mixed Meals:     {mixed_meals_tested} tested | {mixed_meals_false_accepted_085} false accepts @ 0.85 ({report['rejection_metrics']['mixed_meals_rejection_rate_at_085_pct']}% rejected)")

    print("\n--- TOP CONFUSED PAIRS ---")
    for (t, p), count in sorted_confusions:
        print(f"  {t} -> confused with {p} ({count}x)")

    print(f"\nFull evaluation saved to: {args.output_report}")
    print("============================================================\n")


if __name__ == "__main__":
    main()
