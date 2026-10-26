#!/usr/bin/env python3
"""
FitFuel Phase 35.9.5 - Validation Calibration & Final Lockbox V5 Evaluation
Executes strictly in order:
Stage 1: Validation Calibration on fitfuel_food_dataset_v5 validation split (457 images)
  - Keras vs TFLite agreement check
  - Threshold sweep (0.80, 0.85, 0.90, 0.95)
  - Margin sweep (0.10, 0.15, 0.20, 0.25)
  - Per-class validation evidence evaluation
  - FREEZES threshold, margin, and kFitFuelV5ProductionEnabledFoodIds

Stage 2: Single-pass Final Lockbox V5 Evaluation on untouched dataset (465 images)
  - 263 supported candidate class images
  - 80 non-food images
  - 80 unsupported FitFuel food images
  - 42 mixed-meal images
  - Dietary safety audit (meat vs veg)
  - Poha & Tandoori chicken audit
  - Generates:
    ml/reports/model_evaluation_v5.json
    ml/reports/final_lockbox_validation_v5.json
    ml/reports/misclassification_forensics_v5.csv
"""

import os
import sys
import csv
import json
import time
import numpy as np
import tensorflow as tf
from PIL import Image

CANDIDATE_V5_CLASSES = [
    "predefined_watermelon",
    "predefined_strawberry",
    "predefined_medu_vada",
    "predefined_steamed_rice",
    "predefined_scrambled_eggs",
    "predefined_rajma_curry",
    "predefined_capsicum",
    "predefined_whole_wheat_bread",
    "predefined_guava",
    "predefined_dosa",
    "predefined_broccoli",
    "predefined_chole_masala",
    "predefined_low_fat_milk",
    "predefined_potato",
    "predefined_samosa",
    "predefined_paneer_tikka"
]

def load_labels(path="assets/ml/fitfuel_food_labels.txt"):
    with open(path, "r", encoding="utf-8") as f:
        labels = [l.strip() for l in f if l.strip()]
    return labels, {l: i for i, l in enumerate(labels)}

def run_tflite_inference(interpreter, input_details, output_details, image_path):
    img = Image.open(image_path).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.BILINEAR)
    arr = np.array(img, dtype=np.float32)
    input_data = np.expand_dims(arr, axis=0)

    start = time.perf_counter()
    interpreter.set_tensor(input_details[0]["index"], input_data)
    interpreter.invoke()
    output_data = interpreter.get_tensor(output_details[0]["index"])[0]
    lat = (time.perf_counter() - start) * 1000.0

    return output_data, lat, img

def main():
    print("============================================================", flush=True)
    print("  FITFUEL 35.9.5: VALIDATION CALIBRATION & LOCKBOX V5 AUDIT ", flush=True)
    print("============================================================", flush=True)

    labels, label_to_idx = load_labels("assets/ml/fitfuel_food_labels.txt")
    tflite_path = "assets/ml/fitfuel_food_classifier.tflite"
    keras_path = "ml/checkpoints/fitfuel_food_v5.keras"

    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    keras_model = tf.keras.models.load_model(keras_path)
    print(f"Loaded Keras checkpoint: {keras_path}")
    print(f"Loaded Deployed TFLite:  {tflite_path} ({os.path.getsize(tflite_path)/1024/1024:.2f} MB)")

    # ------------------------------------------------------------
    # STAGE 1: VALIDATION CALIBRATION (457 images from fitfuel_food_dataset_v5)
    # ------------------------------------------------------------
    val_manifest = "ml/dataset_manifest_v5.csv"
    val_rows = []
    with open(val_manifest, "r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r.get("split") == "validation":
                val_rows.append(r)

    print(f"\n--- STAGE 1: VALIDATION CALIBRATION ({len(val_rows)} images) ---", flush=True)

    keras_top1_correct = 0
    keras_top3_correct = 0
    tflite_top1_correct = 0
    tflite_top3_correct = 0
    model_disagreements = 0
    max_prob_delta = 0.0

    val_predictions = []

    for r in val_rows:
        img_p = r["image_path"]
        if not os.path.isabs(img_p):
            img_p = os.path.join("ml", img_p)
        if not os.path.exists(img_p):
            continue

        target_fid = r["food_id"]
        gt_idx = label_to_idx[target_fid]

        t_probs, lat, pil_img = run_tflite_inference(interpreter, input_details, output_details, img_p)

        # Keras inference
        arr = np.expand_dims(np.array(pil_img, dtype=np.float32), axis=0)
        k_probs = keras_model(arr, training=False).numpy()[0]

        delta = np.max(np.abs(t_probs - k_probs))
        if delta > max_prob_delta:
            max_prob_delta = delta

        k_top1 = int(np.argmax(k_probs))
        k_top3 = list(np.argsort(k_probs)[-3:][::-1])

        t_top1 = int(np.argmax(t_probs))
        t_top2 = int(np.argsort(t_probs)[-2])
        t_top3 = list(np.argsort(t_probs)[-3:][::-1])

        if k_top1 != t_top1:
            model_disagreements += 1

        if k_top1 == gt_idx: keras_top1_correct += 1
        if gt_idx in k_top3: keras_top3_correct += 1
        if t_top1 == gt_idx: tflite_top1_correct += 1
        if gt_idx in t_top3: tflite_top3_correct += 1

        val_predictions.append({
            "image_path": r["image_path"],
            "actual_id": target_fid,
            "predicted_top1": labels[t_top1],
            "predicted_top2": labels[t_top2],
            "confidence": float(t_probs[t_top1]),
            "margin": float(t_probs[t_top1] - t_probs[t_top2]),
            "is_correct": (t_top1 == gt_idx)
        })

    n_val = len(val_predictions)
    val_top1_pct = (tflite_top1_correct / n_val) * 100
    val_top3_pct = (tflite_top3_correct / n_val) * 100
    print(f"Validation Deployed TFLite Top-1: {tflite_top1_correct}/{n_val} ({val_top1_pct:.2f}%)")
    print(f"Validation Deployed TFLite Top-3: {tflite_top3_correct}/{n_val} ({val_top3_pct:.2f}%)")
    print(f"Validation Keras Top-1:          {keras_top1_correct}/{n_val} ({(keras_top1_correct/n_val)*100:.2f}%)")
    print(f"Validation Keras Top-3:          {keras_top3_correct}/{n_val} ({(keras_top3_correct/n_val)*100:.2f}%)")
    print(f"Keras vs TFLite Disagreements:   {model_disagreements}/{n_val} ({((n_val-model_disagreements)/n_val)*100:.2f}% agreement)")
    print(f"Max Probability Delta:           {max_prob_delta:.6f}")

    # Threshold Sweep on Validation Data
    print("\n--- Validation Threshold Grid Sweep (Margin=0.15) ---")
    val_th_grid = {}
    for th in [0.80, 0.85, 0.90, 0.95]:
        acc = [v for v in val_predictions if v["confidence"] >= th and v["margin"] >= 0.15]
        corr = sum(1 for v in acc if v["is_correct"])
        wrong = sum(1 for v in acc if not v["is_correct"])
        prec = (corr / len(acc) * 100) if acc else 100.0
        cov = (len(acc) / n_val * 100)
        val_th_grid[f"{th:.2f}"] = {
            "accepted": len(acc), "correct": corr, "wrong": wrong,
            "precision_pct": round(prec, 2), "coverage_pct": round(cov, 2)
        }
        print(f"  th={th:.2f} -> accepted={len(acc):3d}, correct={corr:3d}, wrong={wrong:2d}, prec={prec:5.1f}%, cov={cov:4.1f}%")

    # Margin Sweep on Validation Data
    print("\n--- Validation Margin Grid Sweep (Threshold=0.85) ---")
    val_mg_grid = {}
    for mg in [0.10, 0.15, 0.20, 0.25]:
        acc = [v for v in val_predictions if v["confidence"] >= 0.85 and v["margin"] >= mg]
        corr = sum(1 for v in acc if v["is_correct"])
        wrong = sum(1 for v in acc if not v["is_correct"])
        prec = (corr / len(acc) * 100) if acc else 100.0
        cov = (len(acc) / n_val * 100)
        val_mg_grid[f"{mg:.2f}"] = {
            "accepted": len(acc), "correct": corr, "wrong": wrong,
            "precision_pct": round(prec, 2), "coverage_pct": round(cov, 2)
        }
        print(f"  margin={mg:.2f} -> accepted={len(acc):3d}, correct={corr:3d}, wrong={wrong:2d}, prec={prec:5.1f}%, cov={cov:4.1f}%")

    # Per-Class Validation Evaluation for Candidate Production Classes
    print("\n--- Per-Class Validation Safety Gating ---")
    val_class_stats = {}
    retained_prod_classes = []
    cloud_only_classes = []

    for cid in CANDIDATE_V5_CLASSES:
        cls_val = [v for v in val_predictions if v["actual_id"] == cid]
        s_count = len(cls_val)
        acc = [v for v in cls_val if v["confidence"] >= 0.85 and v["margin"] >= 0.15 and v["predicted_top1"] == cid]
        wrong = [v for v in val_predictions if v["predicted_top1"] == cid and v["confidence"] >= 0.85 and v["margin"] >= 0.15 and v["actual_id"] != cid]
        prec = (len(acc) / (len(acc) + len(wrong)) * 100) if (len(acc) + len(wrong)) > 0 else 100.0

        val_class_stats[cid] = {
            "val_samples": s_count,
            "accepted_correct": len(acc),
            "false_accepts": len(wrong),
            "precision_pct": round(prec, 2)
        }
        # Safety gate: require 0 false accepts on validation
        if len(wrong) == 0:
            retained_prod_classes.append(cid)
            status = "APPROVED_CANDIDATE"
        else:
            cloud_only_classes.append((cid, f"{len(wrong)} validation false accept(s)"))
            status = "CLOUD_ONLY"
        print(f"  {cid:32s}: val_samples={s_count:2d}, correct_acc={len(acc):2d}, false_acc={len(wrong):2d}, status={status}")

    # FROZEN PARAMETERS FOR STAGE 2
    FROZEN_THRESHOLD = 0.85
    FROZEN_MARGIN = 0.15
    FROZEN_PRODUCTION_CLASSES = set(retained_prod_classes)

    print(f"\n============================================================")
    print(f"FROZEN CONFIGURATION FOR FINAL LOCKBOX EVALUATION:")
    print(f"  Model Version:      fitfuel_food_v5")
    print(f"  Threshold:          {FROZEN_THRESHOLD}")
    print(f"  Margin:             {FROZEN_MARGIN}")
    print(f"  Production Classes: {len(FROZEN_PRODUCTION_CLASSES)} classes")
    print(f"============================================================\n", flush=True)

    # ------------------------------------------------------------
    # STAGE 2: FINAL UNTOUCHED LOCKBOX EVALUATION (465 images)
    # ------------------------------------------------------------
    lockbox_manifest = "ml/final_lockbox_manifest_v5.csv"
    with open(lockbox_manifest, "r", encoding="utf-8") as f:
        lockbox_rows = list(csv.DictReader(f))

    print(f"--- STAGE 2: FINAL LOCKBOX EVALUATION ({len(lockbox_rows)} images) ---", flush=True)

    lb_supported = []
    lb_non_food = []
    lb_unsupported = []
    lb_mixed = []

    for r in lockbox_rows:
        img_p = r["image_path"]
        if not os.path.isabs(img_p):
            img_p = os.path.join("ml", img_p)
        if not os.path.exists(img_p):
            continue

        fid = r["food_id"]
        t_probs, lat, pil_img = run_tflite_inference(interpreter, input_details, output_details, img_p)

        top1_idx = int(np.argmax(t_probs))
        top2_idx = int(np.argsort(t_probs)[-2])
        top3_indices = [int(i) for i in np.argsort(t_probs)[-3:][::-1]]

        conf = float(t_probs[top1_idx])
        margin = conf - float(t_probs[top2_idx])
        pred_label = labels[top1_idx]

        item = {
            "image_path": r["image_path"],
            "food_id": fid,
            "food_name": r.get("food_name", fid),
            "predicted_top1": pred_label,
            "predicted_top2": labels[top2_idx],
            "predicted_top3": [labels[i] for i in top3_indices],
            "confidence": conf,
            "margin": margin,
            "latency_ms": lat,
            "is_prod_enabled_top1": pred_label in FROZEN_PRODUCTION_CLASSES
        }

        if fid in FROZEN_PRODUCTION_CLASSES:
            lb_supported.append(item)
        elif fid == "non_food":
            lb_non_food.append(item)
        elif fid == "mixed_meal":
            lb_mixed.append(item)
        else:
            lb_unsupported.append(item)

    forensic_records = []

    # 1. Supported Lockbox Evaluation
    total_supp = len(lb_supported)
    supp_accepted = 0
    supp_correct_accepted = 0
    supp_wrong_accepted = 0
    supp_fallback = 0

    per_class_lockbox = {cid: {
        "samples": 0, "accepted": 0, "correct": 0, "wrong": 0, "fallback": 0
    } for cid in FROZEN_PRODUCTION_CLASSES}

    for item in lb_supported:
        gt = item["food_id"]
        pred = item["predicted_top1"]
        conf = item["confidence"]
        marg = item["margin"]

        per_class_lockbox[gt]["samples"] += 1

        is_accepted = (conf >= FROZEN_THRESHOLD) and (marg >= FROZEN_MARGIN) and (pred in FROZEN_PRODUCTION_CLASSES)

        if is_accepted:
            supp_accepted += 1
            per_class_lockbox[gt]["accepted"] += 1
            if pred == gt:
                supp_correct_accepted += 1
                per_class_lockbox[gt]["correct"] += 1
            else:
                supp_wrong_accepted += 1
                per_class_lockbox[gt]["wrong"] += 1
                forensic_records.append({
                    "image": item["image_path"], "actual": gt, "predicted": pred,
                    "confidence": round(conf, 4), "margin": round(marg, 4),
                    "class_type": "SUPPORTED_LOCAL", "error_type": "WRONG_LOCAL_ACCEPT",
                    "production_enabled": "YES", "notes": f"Supported class {gt} misclassified as {pred} and locally accepted."
                })
        else:
            supp_fallback += 1
            per_class_lockbox[gt]["fallback"] += 1
            if pred != gt and conf >= 0.70:
                forensic_records.append({
                    "image": item["image_path"], "actual": gt, "predicted": pred,
                    "confidence": round(conf, 4), "margin": round(marg, 4),
                    "class_type": "SUPPORTED_LOCAL", "error_type": "SAFE_FALLBACK_MISCLASSIFICATION",
                    "production_enabled": "SAFE_FALLBACK", "notes": f"Supported class {gt} mispredicted as {pred} but safely routed to Gemini."
                })

    accepted_local_prec = (supp_correct_accepted / supp_accepted * 100) if supp_accepted > 0 else 0.0
    local_acc_rate = (supp_accepted / total_supp * 100) if total_supp > 0 else 0.0
    safe_cloud_avoidance = (supp_correct_accepted / total_supp * 100) if total_supp > 0 else 0.0
    wrong_local_rate = (supp_wrong_accepted / total_supp * 100) if total_supp > 0 else 0.0

    print("=== Final Lockbox Supported Food Results ===")
    print(f"Supported Images:         {total_supp}")
    print(f"Accepted Locally:         {supp_accepted} ({local_acc_rate:.2f}%)")
    print(f"Correct Local Accepted:   {supp_correct_accepted}")
    print(f"Wrong Local Accepted:     {supp_wrong_accepted}")
    print(f"Gemini Fallback:          {supp_fallback} ({(supp_fallback/total_supp)*100:.2f}%)")
    print(f"Accepted Local Precision: {accepted_local_prec:.2f}%")
    print(f"Safe Cloud Avoidance:     {safe_cloud_avoidance:.2f}%")
    print(f"Wrong Local Rate:         {wrong_local_rate:.2f}%\n")

    print("--- Lockbox Per-Class Outcomes ---")
    for cid, st in per_class_lockbox.items():
        c_prec = (st["correct"] / st["accepted"] * 100) if st["accepted"] > 0 else 100.0
        print(f"  {cid:32s}: samples={st['samples']:2d}, accepted={st['accepted']:2d}, correct={st['correct']:2d}, wrong={st['wrong']:2d}, prec={c_prec:5.1f}%")

    # 2. Non-Food Lockbox Evaluation (80 images)
    nf_total = len(lb_non_food)
    nf_false_accepted = 0
    nf_rejected = 0
    for item in lb_non_food:
        conf = item["confidence"]
        marg = item["margin"]
        pred = item["predicted_top1"]
        if (conf >= FROZEN_THRESHOLD) and (marg >= FROZEN_MARGIN) and (pred in FROZEN_PRODUCTION_CLASSES):
            nf_false_accepted += 1
            forensic_records.append({
                "image": item["image_path"], "actual": "non_food", "predicted": pred,
                "confidence": round(conf, 4), "margin": round(marg, 4),
                "class_type": "NON_FOOD", "error_type": "CRITICAL_NON_FOOD_FALSE_ACCEPT",
                "production_enabled": "YES", "notes": f"Non-food image false accepted as {pred}."
            })
        else:
            nf_rejected += 1

    print(f"\n--- Non-Food Lockbox ---")
    print(f"Tested:         {nf_total}")
    print(f"Rejected:       {nf_rejected} ({(nf_rejected/nf_total)*100:.2f}%)")
    print(f"False Accepted: {nf_false_accepted}")

    # 3. Unsupported-Food Lockbox Evaluation (80 images)
    unsupp_total = len(lb_unsupported)
    unsupp_false_accepted = 0
    unsupp_rejected = 0
    unsupp_false_details = []

    meat_to_veg_errors = 0
    veg_to_meat_errors = 0

    MEAT_CLASSES = {"predefined_tandoori_chicken", "predefined_grilled_chicken_breast"}
    VEG_CLASSES = set(labels) - MEAT_CLASSES

    for item in lb_unsupported:
        conf = item["confidence"]
        marg = item["margin"]
        pred = item["predicted_top1"]
        act = item["food_id"]

        is_acc = (conf >= FROZEN_THRESHOLD) and (marg >= FROZEN_MARGIN) and (pred in FROZEN_PRODUCTION_CLASSES)
        if is_acc:
            unsupp_false_accepted += 1
            unsupp_false_details.append({
                "actual": act, "predicted": pred, "confidence": round(conf, 4), "margin": round(marg, 4)
            })
            forensic_records.append({
                "image": item["image_path"], "actual": act, "predicted": pred,
                "confidence": round(conf, 4), "margin": round(marg, 4),
                "class_type": "UNSUPPORTED_FOOD", "error_type": "UNSUPPORTED_FALSE_ACCEPT",
                "production_enabled": "YES", "notes": f"Unsupported food {act} accepted locally as {pred}."
            })

            # Check dietary safety
            if "chicken" in act or "mutton" in act or "fish" in act:
                if pred in VEG_CLASSES:
                    meat_to_veg_errors += 1
            if "paneer" in act or "dal" in act or "veg" in act:
                if pred in MEAT_CLASSES:
                    veg_to_meat_errors += 1
        else:
            unsupp_rejected += 1

    print(f"\n--- Unsupported-Food Lockbox ---")
    print(f"Tested:         {unsupp_total}")
    print(f"Rejected:       {unsupp_rejected} ({(unsupp_rejected/unsupp_total)*100:.2f}%)")
    print(f"False Accepted: {unsupp_false_accepted}")
    for ufd in unsupp_false_details:
        print(f"  - Actual {ufd['actual']} -> Predicted {ufd['predicted']} (conf={ufd['confidence']:.2f}, margin={ufd['margin']:.2f})")

    # 4. Mixed Meals Lockbox Evaluation (42 images)
    mm_total = len(lb_mixed)
    mm_fallback = 0
    mm_wrong_local = 0
    for item in lb_mixed:
        conf = item["confidence"]
        marg = item["margin"]
        pred = item["predicted_top1"]
        if (conf >= FROZEN_THRESHOLD) and (marg >= FROZEN_MARGIN) and (pred in FROZEN_PRODUCTION_CLASSES):
            mm_wrong_local += 1
            forensic_records.append({
                "image": item["image_path"], "actual": "mixed_meal", "predicted": pred,
                "confidence": round(conf, 4), "margin": round(marg, 4),
                "class_type": "MIXED_MEAL", "error_type": "MIXED_MEAL_FALSE_ACCEPT",
                "production_enabled": "YES", "notes": f"Mixed meal accepted locally as single class {pred}."
            })
        else:
            mm_fallback += 1

    print(f"\n--- Mixed Meals Lockbox ---")
    print(f"Tested:      {mm_total}")
    print(f"Fallback:    {mm_fallback} ({(mm_fallback/mm_total)*100:.2f}%)")
    print(f"Wrong Local: {mm_wrong_local}")

    # 5. Poha and Tandoori Chicken Safety Checks
    print("\n--- Poha & Tandoori Chicken Safety Checks ---")
    poha_lockbox = [it for it in lb_unsupported if "biryani" in it["food_id"] or "khichdi" in it["food_id"]]
    poha_false_as_poha = sum(1 for it in poha_lockbox if it["predicted_top1"] == "predefined_poha" and it["confidence"] >= FROZEN_THRESHOLD and it["margin"] >= FROZEN_MARGIN)
    print(f"Poha Local Enabled: NO (Cloud-only safety retained)")
    print(f"Biryani/Khichdi falsely accepted as Poha: {poha_false_as_poha}")

    tandoori_lockbox = [it for it in lb_unsupported if "paneer" in it["food_id"]]
    tandoori_false_as_tandoori = sum(1 for it in tandoori_lockbox if it["predicted_top1"] == "predefined_tandoori_chicken" and it["confidence"] >= FROZEN_THRESHOLD and it["margin"] >= FROZEN_MARGIN)
    print(f"Tandoori Chicken Local Enabled: NO (Cloud-only safety retained)")
    print(f"Paneer dishes falsely accepted as Tandoori Chicken: {tandoori_false_as_tandoori}")

    # 6. Dietary Safety
    print(f"\n--- Dietary Safety ---")
    print(f"Vegetarian -> Meat False Accepts: {veg_to_meat_errors}")
    print(f"Meat -> Vegetarian False Accepts: {meat_to_veg_errors}")

    # Write Misclassification Forensics CSV
    forensics_csv = "ml/reports/misclassification_forensics_v5.csv"
    os.makedirs(os.path.dirname(forensics_csv), exist_ok=True)
    fieldnames = ["image", "actual", "predicted", "confidence", "margin", "class_type", "error_type", "production_enabled", "notes"]
    with open(forensics_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(forensic_records)
    print(f"\nWritten {len(forensic_records)} forensic entries to {forensics_csv}")

    # Write Final Lockbox Validation JSON
    lockbox_report_path = "ml/reports/final_lockbox_validation_v5.json"
    lockbox_report = {
        "dataset_version": "fitfuel_final_lockbox_v5",
        "total_samples": len(lockbox_rows),
        "supported_count": total_supp,
        "non_food_count": nf_total,
        "unsupported_count": unsupp_total,
        "mixed_meal_count": mm_total,
        "frozen_threshold": FROZEN_THRESHOLD,
        "frozen_margin": FROZEN_MARGIN,
        "production_classes_count": len(FROZEN_PRODUCTION_CLASSES),
        "production_classes": list(FROZEN_PRODUCTION_CLASSES),
        "supported_results": {
            "accepted_local": supp_accepted,
            "correct_local_accepted": supp_correct_accepted,
            "wrong_local_accepted": supp_wrong_accepted,
            "gemini_fallback": supp_fallback,
            "accepted_local_precision_pct": round(accepted_local_prec, 2),
            "local_acceptance_rate_pct": round(local_acc_rate, 2),
            "safe_cloud_avoidance_pct": round(safe_cloud_avoidance, 2),
            "wrong_local_rate_pct": round(wrong_local_rate, 2)
        },
        "per_class_outcomes": per_class_lockbox,
        "non_food": {
            "tested": nf_total, "rejected": nf_rejected, "false_accepted": nf_false_accepted
        },
        "unsupported_foods": {
            "tested": unsupp_total, "rejected": unsupp_rejected, "false_accepted": unsupp_false_accepted,
            "details": unsupp_false_details
        },
        "mixed_meals": {
            "tested": mm_total, "fallback": mm_fallback, "wrong_local": mm_wrong_local
        },
        "dietary_safety": {
            "veg_to_meat_false_accepts": veg_to_meat_errors,
            "meat_to_veg_false_accepts": meat_to_veg_errors
        },
        "safety_checks": {
            "poha_local_enabled": False,
            "tandoori_chicken_local_enabled": False
        }
    }
    with open(lockbox_report_path, "w", encoding="utf-8") as f:
        json.dump(lockbox_report, f, indent=2)
    print(f"Written Final Lockbox Report: {lockbox_report_path}")

    # Write Canonical Model Evaluation JSON
    canonical_model_eval_path = "ml/reports/model_evaluation_v5.json"
    canonical_eval = {
        "model_artifact": "assets/ml/fitfuel_food_classifier.tflite",
        "model_version": "fitfuel_food_v5",
        "architecture": "MobileNetV3Large",
        "labels_path": "assets/ml/fitfuel_food_labels.txt",
        "labels_count": len(labels),
        "validation_metrics": {
            "val_samples": n_val,
            "tflite_top1_pct": round(val_top1_pct, 2),
            "tflite_top3_pct": round(val_top3_pct, 2),
            "keras_top1_pct": round((keras_top1_correct / n_val) * 100, 2),
            "keras_top3_pct": round((keras_top3_correct / n_val) * 100, 2),
            "model_disagreements": model_disagreements,
            "max_probability_delta": round(float(max_prob_delta), 6)
        },
        "frozen_calibration": {
            "threshold": FROZEN_THRESHOLD,
            "margin": FROZEN_MARGIN,
            "production_classes_count": len(FROZEN_PRODUCTION_CLASSES),
            "production_classes": list(FROZEN_PRODUCTION_CLASSES),
            "cloud_only_classes": [c[0] for c in cloud_only_classes]
        },
        "lockbox_evaluation": lockbox_report["supported_results"]
    }
    with open(canonical_model_eval_path, "w", encoding="utf-8") as f:
        json.dump(canonical_eval, f, indent=2)
    print(f"Written Canonical Model Evaluation: {canonical_model_eval_path}")

if __name__ == "__main__":
    main()
