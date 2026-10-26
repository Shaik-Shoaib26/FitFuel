#!/usr/bin/env python3
"""
Inspect training dataset for confused pairs and generate ml/reports/training_data_issues_v4.csv
Pairs to inspect:
- banana -> pineapple
- tomato -> watermelon
- apple -> orange
- watermelon -> greek_yogurt_plain
- grapes -> paneer_tikka
- dosa -> sambar
- brown_rice_ind -> hard_boiled_eggs
- chapati -> samosa
"""

import os
import csv
import json

CONFUSED_CLASSES = [
    "predefined_banana", "predefined_pineapple",
    "predefined_tomato", "predefined_watermelon",
    "predefined_apple", "predefined_orange",
    "predefined_greek_yogurt_plain",
    "predefined_grapes", "predefined_paneer_tikka",
    "predefined_dosa", "predefined_sambar",
    "predefined_brown_rice_ind", "predefined_hard_boiled_eggs",
    "predefined_chapati", "predefined_samosa"
]

def main():
    manifest_path = "ml/dataset_manifest.csv"
    with open(manifest_path, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    print(f"Total training manifest rows: {len(rows)}")

    flagged_issues = []

    # Check for label mismatch in source reference / filename or obvious cross-contamination
    for r in rows:
        fid = r.get("food_id")
        img_p = r.get("image_path")
        ref = r.get("source_reference", "").lower()
        orig = r.get("original_filename", "").lower()

        # Check apple containing tomato
        if fid == "predefined_apple" and "tomato" in ref:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "LABEL_MISMATCH",
                "detected_keyword": "tomato in reference",
                "source_reference": r.get("source_reference"),
                "recommended_action": "REPLACE_WITH_CLEAN_APPLE_PHOTO",
                "notes": "Image is a Bangladeshi tomato mislabeled as apple."
            })

        # Check tomato containing watermelon or vice versa
        if fid == "predefined_tomato" and "watermelon" in ref:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "LABEL_MISMATCH",
                "detected_keyword": "watermelon in reference",
                "source_reference": r.get("source_reference"),
                "recommended_action": "REMOVE_OR_REPLACE",
                "notes": "Watermelon keyword in tomato training reference."
            })

        # Check dosa containing large sambar bowl dominance
        if fid == "predefined_dosa" and "sambar" in orig:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "SIDE_DISH_DOMINANCE",
                "detected_keyword": "sambar in filename",
                "source_reference": r.get("source_reference"),
                "recommended_action": "CROP_TO_DOSA_OR_RESAMPLE",
                "notes": "Dosa image heavily features sambar bowl, inducing background/side-dish bias."
            })

        # Check watermelon with yogurt or bowl bias
        if fid == "predefined_watermelon" and ("bowl" in orig or "salad" in orig or "yogurt" in ref):
            if "yogurt" in ref or "salad" in orig:
                flagged_issues.append({
                    "image_path": img_p,
                    "food_id": fid,
                    "issue_type": "CONTAINER_OR_COMPOUND_BIAS",
                    "detected_keyword": "salad/yogurt in title",
                    "source_reference": r.get("source_reference"),
                    "recommended_action": "REPLACE_WITH_FRESH_SLICES",
                    "notes": "Compound dish / bowl containing multiple components confusing watermelon with yogurt/dairy."
                })

        # Check brown rice vs egg
        if fid == "predefined_brown_rice_ind" and "egg" in ref:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "COMPOUND_MEAL_OVERLAP",
                "detected_keyword": "egg in reference",
                "source_reference": r.get("source_reference"),
                "recommended_action": "REMOVE",
                "notes": "Brown rice plate contains boiled egg garnish, causing brown rice -> boiled egg confusion."
            })

        # Check banana vs pineapple
        if fid == "predefined_banana" and "pineapple" in ref:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "LABEL_MISMATCH",
                "detected_keyword": "pineapple in reference",
                "source_reference": r.get("source_reference"),
                "recommended_action": "REMOVE",
                "notes": "Mixed fruit image containing pineapple labeled as banana."
            })

        # Check chapati vs samosa
        if fid == "predefined_chapati" and "samosa" in ref:
            flagged_issues.append({
                "image_path": img_p,
                "food_id": fid,
                "issue_type": "LABEL_MISMATCH",
                "detected_keyword": "samosa in reference",
                "source_reference": r.get("source_reference"),
                "recommended_action": "REMOVE",
                "notes": "Samosa present in chapati plate photo."
            })

    output_csv = "ml/reports/training_data_issues_v4.csv"
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    fieldnames = [
        "image_path", "food_id", "issue_type", "detected_keyword",
        "source_reference", "recommended_action", "notes"
    ]
    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(flagged_issues)

    print(f"Flagged {len(flagged_issues)} training issues into {output_csv}")
    for fi in flagged_issues:
        print(f"  [{fi['issue_type']}] {fi['food_id']}: {fi['notes']}")

if __name__ == "__main__":
    main()
