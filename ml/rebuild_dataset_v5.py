#!/usr/bin/env python3
"""
FitFuel Phase 35.9.5 - Dataset Rebuilder V5
1. Loads original ml/dataset_manifest.csv (3,188 images)
2. Removes all 46 flagged contaminated/mislabeled/side-dish-dominant samples
3. Adds 30 audited targeted supplements from ml/reports/targeted_supplements_v5.csv
4. Generates stratified Train (~85%) / Validation (~15%) splits
5. Outputs ml/dataset_manifest_v5.csv and ml/reports/dataset_repairs_v5.json
"""

import os
import csv
import json
import random
from collections import Counter, defaultdict

def main():
    random.seed(42)

    # 1. Load original manifest
    orig_manifest_path = "ml/dataset_manifest.csv"
    with open(orig_manifest_path, "r", encoding="utf-8") as f:
        orig_rows = list(csv.DictReader(f))
    print(f"Original manifest rows: {len(orig_rows)}")

    # 2. Load repairs list
    repairs_csv = "ml/reports/dataset_repairs_v5.csv"
    removed_paths = set()
    issue_counts = Counter()
    with open(repairs_csv, "r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            removed_paths.add(r["image_path"])
            issue_counts[r["issue"]] += 1
    print(f"Contaminated samples to remove: {len(removed_paths)}")

    # Filter clean rows
    clean_base_rows = []
    for r in orig_rows:
        if r["image_path"] not in removed_paths:
            clean_base_rows.append(r)
    print(f"Clean base rows remaining: {len(clean_base_rows)}")

    # 3. Load targeted supplements
    supplements_csv = "ml/reports/targeted_supplements_v5.csv"
    supp_rows = []
    if os.path.exists(supplements_csv):
        with open(supplements_csv, "r", encoding="utf-8") as f:
            supp_rows = list(csv.DictReader(f))
    print(f"Targeted supplements to add: {len(supp_rows)}")

    # Combine clean dataset
    combined_rows = clean_base_rows + supp_rows
    print(f"Total usable images in V5 dataset: {len(combined_rows)}")

    # Group by class
    class_groups = defaultdict(list)
    for r in combined_rows:
        class_groups[r["food_id"]].append(r)

    # Stratified 85% train / 15% validation split
    final_v5_rows = []
    train_count = 0
    val_count = 0

    per_class_counts = {}

    for fid, items in class_groups.items():
        random.shuffle(items)
        n = len(items)
        n_val = max(5, int(n * 0.15))
        n_train = n - n_val

        for i, it in enumerate(items):
            row_copy = dict(it)
            if i < n_train:
                row_copy["split"] = "train"
                train_count += 1
            else:
                row_copy["split"] = "validation"
                val_count += 1
            row_copy["dataset_version"] = "fitfuel_food_dataset_v5"
            final_v5_rows.append(row_copy)

        per_class_counts[fid] = {
            "total": n,
            "train": n_train,
            "val": n_val
        }

    # Save ml/dataset_manifest_v5.csv
    v5_manifest_path = "ml/dataset_manifest_v5.csv"
    fieldnames = [
        "image_path", "food_id", "food_name", "source", "source_reference",
        "license", "sha256", "perceptual_hash", "width", "height", "review_status",
        "split", "dataset_version"
    ]
    with open(v5_manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(final_v5_rows)

    print(f"\nWritten {v5_manifest_path}: {len(final_v5_rows)} samples (Train: {train_count}, Val: {val_count})")

    # Save comprehensive ml/reports/dataset_repairs_v5.json
    repairs_json_path = "ml/reports/dataset_repairs_v5.json"
    repairs_report = {
        "dataset_name": "fitfuel_food_dataset_v5",
        "previous_total_images": len(orig_rows),
        "total_removed_contaminated_images": len(removed_paths),
        "clean_remaining_base_images": len(clean_base_rows),
        "new_targeted_supplement_images": len(supp_rows),
        "final_usable_images": len(final_v5_rows),
        "train_samples": train_count,
        "val_samples": val_count,
        "supported_classes_count": len(per_class_counts),
        "wrong_labels_removed": sum(cnt for iss, cnt in issue_counts.items() if "LABEL" in iss or "TOMATO" in iss),
        "apple_tomato_contamination_removed": issue_counts.get("LABEL_CONTAMINATION_TOMATO", 0),
        "side_dish_dominant_removed": issue_counts.get("SIDE_DISH_DOMINANCE_SAMBAR", 0),
        "compound_dish_removed": issue_counts.get("COMPOUND_FRUIT_BOWL", 0),
        "issue_breakdown": dict(issue_counts),
        "per_class_counts": per_class_counts
    }

    with open(repairs_json_path, "w", encoding="utf-8") as f:
        json.dump(repairs_report, f, indent=2)

    print(f"Written comprehensive report to {repairs_json_path}")

if __name__ == "__main__":
    main()
