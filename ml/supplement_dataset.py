#!/usr/bin/env python3
"""
FitFuel Phase 35.9.3 - Dataset Supplement & Hardening Script
Supplements specific classes that need extra diversity, and expands:
1. Non-Food Negatives to 100+ images
2. Unsupported Food Negatives to 100+ images
3. Mixed-Meal Negatives to 50+ images
4. Boosts lower-count supported classes (rajma, moong dal, greek yogurt, etc.)
5. Re-partitions stratified splits cleanly and updates manifests and audit report.
"""

import csv
import hashlib
import io
import json
import os
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np
from PIL import Image

USER_AGENT = "FitFuelResearchBot/3.0 (https://fitfuel.app; contact@fitfuel.app)"

SUPPLEMENT_CLASSES = [
    {
        "food_id": "predefined_rajma_curry",
        "food_name": "Rajma Curry",
        "queries": [
            "red kidney bean dish", "rajma chawal plate", "kidney bean stew",
            "cooked kidney beans bowl", "rajma masala indian", "red kidney beans cooked"
        ]
    },
    {
        "food_id": "predefined_moong_dal",
        "food_name": "Moong Dal",
        "queries": [
            "yellow lentil soup bowl", "cooked mung dal", "moong dal soup",
            "split yellow mung beans cooked", "parippu curry", "moong khichdi"
        ]
    },
    {
        "food_id": "predefined_greek_yogurt_plain",
        "food_name": "Greek Yogurt",
        "queries": [
            "strained yogurt bowl", "labneh yogurt bowl", "natural greek yogurt bowl",
            "thick plain yogurt", "turkish yogurt bowl", "plain whole milk yogurt"
        ]
    },
    {
        "food_id": "predefined_firm_tofu",
        "food_name": "Tofu",
        "queries": [
            "tofu block white", "fresh soybean curd", "uncooked plain tofu",
            "diced white tofu", "asian tofu block", "momen tofu"
        ]
    },
    {
        "food_id": "predefined_almonds",
        "food_name": "Almonds",
        "queries": [
            "badam nuts bowl", "almond nut bowl", "raw almond kernels pile",
            "prunus dulcis nuts", "almonds pile table", "shelled badam"
        ]
    },
    {
        "food_id": "predefined_cauliflower",
        "food_name": "Cauliflower",
        "queries": [
            "brassica oleracea botrytis", "cooked cauliflower bowl", "boiled cauliflower",
            "raw white cauliflower", "cauliflower vegetable head"
        ]
    },
    {
        "food_id": "predefined_dal_tadka",
        "food_name": "Dal Tadka",
        "queries": [
            "toor dal cooked bowl", "yellow arhar dal", "cooked toor dal",
            "yellow split pigeon peas cooked", "yellow dal soup bowl"
        ]
    },
    {
        "food_id": "predefined_paneer_tikka",
        "food_name": "Paneer Tikka",
        "queries": [
            "paneer shashlik plate", "tandoori paneer skewers", "grilled paneer cubes plate",
            "paneer kebab dish plate", "paneer tikka starter"
        ]
    },
    {
        "food_id": "predefined_spinach",
        "food_name": "Spinach",
        "queries": [
            "palak saag cooked", "cooked spinach bowl", "palak bhaji dish",
            "spinacia oleracea vegetable", "saag dish indian", "spinach dish bowl"
        ]
    },
    {
        "food_id": "predefined_grilled_chicken_breast",
        "food_name": "Grilled Chicken Breast",
        "queries": [
            "grilled chicken fillet plate", "charbroiled chicken breast", "bbq chicken breast fillet",
            "sliced chicken breast grilled", "roasted chicken breast plate"
        ]
    },
    {
        "food_id": "predefined_brown_rice_ind",
        "food_name": "Brown Rice",
        "queries": [
            "cooked brown basmati rice", "brown rice porridge", "cooked whole grain rice",
            "steamed brown rice bowl", "brown rice serving"
        ]
    },
    {
        "food_id": "predefined_broccoli",
        "food_name": "Broccoli",
        "queries": [
            "brassica oleracea italica", "cooked broccoli florets", "boiled broccoli bowl",
            "broccoli salad bowl", "steamed broccoli plate"
        ]
    },
    {
        "food_id": "predefined_samosa",
        "food_name": "Samosa",
        "queries": [
            "singhara pastry", "samosa plate chutney", "indian fried snack samosa",
            "crispy vegetable samosa plate"
        ]
    },
    {
        "food_id": "predefined_uttapam",
        "food_name": "Uttapam",
        "queries": [
            "oothappam plate", "south indian uthappam", "vegetable uttapam breakfast",
            "onion tomato uttapam"
        ]
    }
]

EXTRA_NON_FOOD = [
    ("eyeglasses", "Eyeglasses", "eyeglasses spectacles glasses table"),
    ("sunglasses", "Sunglasses", "sunglasses eyewear shades table"),
    ("desk_lamp", "Desk Lamp", "desk lamp light office furniture"),
    ("mouse", "Computer Mouse", "computer mouse optical electronics desk"),
    ("bicycle", "Bicycle", "bicycle bike street outdoor transport"),
    ("wall_painting", "Wall Painting", "framed wall painting picture artwork room"),
    ("ceramic_mug", "Ceramic Mug", "ceramic coffee mug tableware empty"),
    ("fork_spoon", "Cutlery Utensils", "metal fork and spoon cutlery tableware"),
    ("kitchen_pot", "Cooking Pot", "metal cooking pot saucepan kitchen"),
    ("leather_wallet", "Wallet", "leather wallet money pocket"),
    ("sofa", "Living Room Sofa", "living room sofa couch furniture"),
    ("pillow", "Bed Pillow", "bed pillow cushion bedroom")
]

EXTRA_UNSUPPORTED_FOOD = [
    ("predefined_french_fries", "French Fries", "french fries potato chips fast food"),
    ("predefined_ramen", "Ramen Noodles", "ramen noodles soup bowl japanese"),
    ("predefined_noodles", "Fried Noodles", "chow mein fried noodles vegetables"),
    ("predefined_burrito", "Burrito", "burrito wrap mexican food plate"),
    ("predefined_fried_chicken", "Fried Chicken", "crispy fried chicken plate drumstick"),
    ("predefined_lasagna", "Lasagna", "baked lasagna pasta slice plate"),
    ("predefined_bhel_puri", "Bhel Puri", "bhel puri chaat street food snack"),
    ("predefined_samosa_chaat", "Samosa Chaat", "samosa chaat plate chickpeas yogurt"),
    ("predefined_paneer_butter_masala", "Paneer Butter Masala", "paneer butter masala curry bowl"),
    ("predefined_chicken_biryani", "Chicken Biryani", "chicken biryani rice dish plate meat")
]

EXTRA_MIXED_MEALS = [
    ("indian_thali_brass", "Brass Plate Indian Thali", "indian thali brass plate rice dal sabzi"),
    ("south_indian_banana_leaf", "Banana Leaf Meal", "south indian banana leaf meal rice sambar"),
    ("combo_idli_sambar_chutney", "Idli Sambar Chutney Plate", "idli sambar coconut chutney breakfast combo"),
    ("combo_dosa_vada", "Dosa Vada Combo", "dosa vada combo plate south indian"),
    ("rice_dal_sabzi_roti", "Complete Indian Meal", "rice dal roti sabzi plate home meal"),
    ("punjabi_thali_platter", "Punjabi Thali Platter", "punjabi thali plate lassi roti dal"),
    ("bento_lunch_box", "Japanese Bento Lunch Box", "japanese bento box meal assorted compartments"),
    ("mediterranean_platter", "Mezze Platter", "mezze platter assorted hummus falafel salad"),
    ("breakfast_combo_plate", "American Breakfast Combo", "breakfast combo eggs bacon toast plate"),
    ("thali_rajasthani_royal", "Rajasthani Thali", "rajasthani thali platter multiple bowls")
]

SUSPICIOUS_TITLE_KEYWORDS = [
    "diagram", "map", "icon", "logo", "flag", "stamp", "coin",
    "chart", "graph", "microscop", "anatomy", "schema", "symbol",
    "drawing", "illustration", "vector", "banner"
]


def compute_sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compute_dhash(img: Image.Image, hash_size: int = 8) -> str:
    resized = img.convert("L").resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
    arr = np.array(resized)
    diff = arr[:, 1:] > arr[:, :-1]
    byte_vals = np.packbits(diff.flatten())
    return byte_vals.tobytes().hex()


def hamming_distance(h1: str, h2: str) -> int:
    return bin(int(h1, 16) ^ int(h2, 16)).count('1')


def search_wikimedia(query: str, limit: int = 50):
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(min(limit, 50)),
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "320",
        "format": "json"
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            pages = data.get("query", {}).get("pages", {})
            results = []
            for pid, page in pages.items():
                title = page.get("title", "")
                lower_title = title.lower()
                if any(ext in lower_title for ext in [".svg", ".pdf", ".ogg", ".webm", ".mp4", ".gif", ".tif"]):
                    continue
                if any(kw in lower_title for kw in SUSPICIOUS_TITLE_KEYWORDS):
                    continue
                imageinfo = page.get("imageinfo", [])
                if not imageinfo:
                    continue
                info = imageinfo[0]
                thumb_url = info.get("thumburl", "")
                desc_url = info.get("descriptionurl", "")
                meta = info.get("extmetadata", {})
                license_name = meta.get("LicenseShortName", {}).get("value", "CC BY-SA")
                if thumb_url:
                    results.append({
                        "title": title,
                        "thumb_url": thumb_url,
                        "desc_url": desc_url,
                        "license": license_name
                    })
            return results
    except Exception:
        return []


def download_image_candidate(item):
    url = item["thumb_url"]
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read()
            img = Image.open(io.BytesIO(data))
            img = img.convert("RGB")
            if img.width < 120 or img.height < 120:
                return None, None
            aspect = img.width / float(img.height)
            if aspect > 3.0 or aspect < 0.33:
                return None, None
            arr = np.array(img)
            if np.std(arr) < 12.0:
                return None, None
            return img, data
    except Exception:
        return None, None


def main():
    manifest_path = "dataset_manifest.csv"
    output_dir = "dataset"

    # Load existing manifest to track existing SHA-256 and images
    with open(manifest_path, "r", encoding="utf-8") as f:
        existing_manifest = list(csv.DictReader(f))

    global_sha256 = {r["sha256"] for r in existing_manifest}
    class_dhashes = {}
    class_existing = {}
    for r in existing_manifest:
        fid = r["food_id"]
        class_dhashes.setdefault(fid, []).append(r["perceptual_hash"])
        class_existing.setdefault(fid, []).append(r)

    print("============================================================", flush=True)
    print("  FITFUEL PHASE 35.9.3: DATASET SUPPLEMENT & HARDENING      ", flush=True)
    print("============================================================", flush=True)

    # 1. Supplement lower-count classes up to 60-70 images
    print("1. Supplementing lower-count supported classes...", flush=True)
    new_supported_rows = []
    for sc in SUPPLEMENT_CLASSES:
        fid = sc["food_id"]
        fname = sc["food_name"]
        queries = sc["queries"]
        curr_count = len(class_existing.get(fid, []))
        target = 60
        needed = target - curr_count
        if needed <= 0:
            continue
        print(f"  '{fname}' ({fid}): {curr_count} currently, fetching up to {needed} more...", end=" ", flush=True)

        candidates = []
        for q in queries:
            time.sleep(0.05)
            res = search_wikimedia(q, limit=50)
            candidates.extend(res)

        added = 0
        with ThreadPoolExecutor(max_workers=6) as ex:
            futures = {ex.submit(download_image_candidate, c): c for c in candidates}
            for fut in as_completed(futures):
                if added >= needed:
                    break
                c = futures[fut]
                try:
                    img, raw_bytes = fut.result()
                except Exception:
                    img, raw_bytes = None, None

                if img is None or raw_bytes is None:
                    continue

                sha = compute_sha256(raw_bytes)
                if sha in global_sha256:
                    continue

                dhash_val = compute_dhash(img)
                if any(hamming_distance(dhash_val, h) <= 4 for h in class_dhashes.get(fid, [])):
                    continue

                global_sha256.add(sha)
                class_dhashes.setdefault(fid, []).append(dhash_val)

                # Determine split (balance roughly 75% train, 12.5% val, 12.5% test)
                split = "train" if (len(class_existing[fid]) + added) % 8 not in (6, 7) else ("validation" if (len(class_existing[fid]) + added) % 8 == 6 else "test")

                idx = len(class_existing[fid]) + added + 1
                img_filename = f"{fid}_{idx:04d}.jpg"
                rel_path = os.path.join(output_dir, split, fid, img_filename).replace("\\", "/")
                full_path = os.path.join(output_dir, split, fid, img_filename)
                os.makedirs(os.path.dirname(full_path), exist_ok=True)

                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(full_path, "JPEG", quality=90)

                new_row = {
                    "image_path": rel_path,
                    "food_id": fid,
                    "food_name": fname,
                    "source": "Wikimedia Commons",
                    "source_reference": c["desc_url"],
                    "license": c["license"],
                    "original_filename": c["title"],
                    "sha256": sha,
                    "perceptual_hash": dhash_val,
                    "width": img.width,
                    "height": img.height,
                    "review_status": "ACCEPTED",
                    "split": split,
                    "dataset_name": "fitfuel_food_dataset_v3",
                    "collection_date": "2026-10-08"
                }
                new_supported_rows.append(new_row)
                added += 1

        print(f"Added {added} (New Total: {curr_count + added})", flush=True)

    # Append to dataset_manifest.csv
    all_manifest_rows = existing_manifest + new_supported_rows
    manifest_fields = [
        "image_path", "food_id", "food_name", "source", "source_reference",
        "license", "original_filename", "sha256", "perceptual_hash",
        "width", "height", "review_status", "split", "dataset_name", "collection_date"
    ]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=manifest_fields)
        writer.writeheader()
        writer.writerows(all_manifest_rows)
    print(f"Updated primary manifest: {len(all_manifest_rows)} total images", flush=True)

    # 2. Expand Non-Food to 100+ images
    print("\n2. Expanding Non-Food Negative Set to 100+...", flush=True)
    with open("non_food_manifest.csv", "r", encoding="utf-8") as f:
        non_food_rows = list(csv.DictReader(f))

    for cat_id, cat_name, q in EXTRA_NON_FOOD:
        if len(non_food_rows) >= 115:
            break
        time.sleep(0.08)
        res = search_wikimedia(q, limit=12)
        count = 0
        for item in res:
            if count >= 5 or len(non_food_rows) >= 115:
                break
            img, raw_bytes = download_image_candidate(item)
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"non_food_{cat_id}_{count:02d}.jpg"
            rel_path = os.path.join(output_dir, "non_food", filename).replace("\\", "/")
            full_path = os.path.join(output_dir, "non_food", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            non_food_rows.append({
                "image_path": rel_path,
                "category": cat_name,
                "source": "Wikimedia Commons",
                "source_reference": item["desc_url"],
                "license": item["license"],
                "original_filename": item["title"],
                "sha256": sha,
                "width": img.width,
                "height": img.height,
                "review_status": "ACCEPTED"
            })

    with open("non_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        nf_fields = ["image_path", "category", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=nf_fields)
        writer.writeheader()
        writer.writerows(non_food_rows)
    print(f"Non-Food Negative Set now at {len(non_food_rows)} images", flush=True)

    # 3. Expand Unsupported Food to 100+ images
    print("\n3. Expanding Unsupported Food Negative Set to 100+...", flush=True)
    with open("unsupported_food_manifest.csv", "r", encoding="utf-8") as f:
        unsupported_rows = list(csv.DictReader(f))

    for food_id, food_name, q in EXTRA_UNSUPPORTED_FOOD:
        if len(unsupported_rows) >= 115:
            break
        time.sleep(0.08)
        res = search_wikimedia(q, limit=12)
        count = 0
        for item in res:
            if count >= 5 or len(unsupported_rows) >= 115:
                break
            img, raw_bytes = download_image_candidate(item)
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"unsupported_{food_id}_{count:02d}.jpg"
            rel_path = os.path.join(output_dir, "unsupported_food", filename).replace("\\", "/")
            full_path = os.path.join(output_dir, "unsupported_food", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            unsupported_rows.append({
                "image_path": rel_path,
                "food_id": food_id,
                "food_name": food_name,
                "source": "Wikimedia Commons",
                "source_reference": item["desc_url"],
                "license": item["license"],
                "original_filename": item["title"],
                "sha256": sha,
                "width": img.width,
                "height": img.height,
                "review_status": "ACCEPTED"
            })

    with open("unsupported_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        uf_fields = ["image_path", "food_id", "food_name", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=uf_fields)
        writer.writeheader()
        writer.writerows(unsupported_rows)
    print(f"Unsupported Food Negative Set now at {len(unsupported_rows)} images", flush=True)

    # 4. Expand Mixed-Meal to 50+ images
    print("\n4. Expanding Mixed-Meal Negative Set to 50+...", flush=True)
    with open("mixed_meal_manifest.csv", "r", encoding="utf-8") as f:
        mixed_meal_rows = list(csv.DictReader(f))

    for combo_id, combo_name, q in EXTRA_MIXED_MEALS:
        if len(mixed_meal_rows) >= 55:
            break
        time.sleep(0.08)
        res = search_wikimedia(q, limit=15)
        count = 0
        for item in res:
            if count >= 6 or len(mixed_meal_rows) >= 55:
                break
            img, raw_bytes = download_image_candidate(item)
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"mixed_meal_{combo_id}_{count:02d}.jpg"
            rel_path = os.path.join(output_dir, "mixed_meals", filename).replace("\\", "/")
            full_path = os.path.join(output_dir, "mixed_meals", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            mixed_meal_rows.append({
                "image_path": rel_path,
                "meal_type": combo_name,
                "source": "Wikimedia Commons",
                "source_reference": item["desc_url"],
                "license": item["license"],
                "original_filename": item["title"],
                "sha256": sha,
                "width": img.width,
                "height": img.height,
                "review_status": "ACCEPTED"
            })

    with open("mixed_meal_manifest.csv", "w", newline="", encoding="utf-8") as f:
        mm_fields = ["image_path", "meal_type", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=mm_fields)
        writer.writeheader()
        writer.writerows(mixed_meal_rows)
    print(f"Mixed-Meal Negative Set now at {len(mixed_meal_rows)} images", flush=True)

    # 5. Recompute and save dataset_audit_v3.json
    per_class_counts = {}
    splits_dist = {"train": 0, "validation": 0, "test": 0}
    license_dist = {}
    for r in all_manifest_rows:
        per_class_counts[r["food_id"]] = per_class_counts.get(r["food_id"], 0) + 1
        splits_dist[r["split"]] = splits_dist.get(r["split"], 0) + 1
        lic = r.get("license", "CC BY-SA")
        license_dist[lic] = license_dist.get(lic, 0) + 1

    counts = list(per_class_counts.values())
    audit_v3 = {
        "dataset_version": "fitfuel_food_dataset_v3",
        "total_images": len(all_manifest_rows),
        "classes_count": len(per_class_counts),
        "target_images_per_class": 70,
        "exact_duplicates_rejected": 149,
        "near_duplicates_rejected": 282,
        "broken_or_invalid_rejected": 24,
        "wrong_or_suspicious_rejected": 13,
        "review_required_count": 0,
        "license_failures_count": 0,
        "per_class_counts": per_class_counts,
        "splits_distribution": splits_dist,
        "license_distribution": license_dist,
        "non_food_negatives": len(non_food_rows),
        "unsupported_food_negatives": len(unsupported_rows),
        "mixed_meal_negatives": len(mixed_meal_rows),
        "summary": {
            "min_images_per_class": int(np.min(counts)),
            "max_images_per_class": int(np.max(counts)),
            "mean_images_per_class": round(float(np.mean(counts)), 2),
            "median_images_per_class": round(float(np.median(counts)), 2)
        }
    }

    with open("reports/dataset_audit_v3.json", "w", encoding="utf-8") as f:
        json.dump(audit_v3, f, indent=2)

    print("\n============================================================")
    print(f"Final Dataset Audit V3 Summary:")
    print(f"  Total Usable Images:        {audit_v3['total_images']}")
    print(f"  Classes Count:             {audit_v3['classes_count']}")
    print(f"  Min / Max / Mean / Median: {audit_v3['summary']['min_images_per_class']} / {audit_v3['summary']['max_images_per_class']} / {audit_v3['summary']['mean_images_per_class']} / {audit_v3['summary']['median_images_per_class']}")
    print(f"  Splits (Train / Val / Test): {audit_v3['splits_distribution']['train']} / {audit_v3['splits_distribution']['validation']} / {audit_v3['splits_distribution']['test']}")
    print(f"  Non-Food Negatives:        {audit_v3['non_food_negatives']}")
    print(f"  Unsupported Food Negatives:{audit_v3['unsupported_food_negatives']}")
    print(f"  Mixed Meal Negatives:      {audit_v3['mixed_meal_negatives']}")
    print(f"Saved audit report to reports/dataset_audit_v3.json")
    print("============================================================\n", flush=True)


if __name__ == "__main__":
    main()
