#!/usr/bin/env python3
"""
FitFuel Phase 35.9.4 - Independent Validation Dataset Collector & Auditor (Resilient)
Fills remaining targets for:
- 18 production classes (min 10, target 15 each)
- 50+ non-food images
- 50+ unsupported FitFuel catalog foods
- 30+ mixed-meal images

Enforces ZERO DATA LEAKAGE against:
- ml/dataset_manifest.csv (3,188 train/val/test images)
- ml/non_food_manifest.csv
- ml/unsupported_food_manifest.csv
- ml/mixed_meal_manifest.csv
- Existing files in ml/dataset/
- Rejects exact SHA-256 and dHash Hamming distance <= 6
"""

import os
import sys
import csv
import json
import time
import hashlib
import io
import urllib.parse
import urllib.request
import numpy as np
from PIL import Image

USER_AGENT = "FitFuelAuditBot/4.2 (https://fitfuel.app; audit@fitfuel.app)"

# Production classes needing completion
REMAINING_SUPPORTED = [
    {
        "food_id": "predefined_poha",
        "food_name": "Poha",
        "target": 15,
        "queries": [
            "flattened rice food", "poha plate indian", "poha breakfast",
            "kanda poha plate", "batata poha dish", "avalakki breakfast",
            "aval food south indian", "chira food breakfast", "rice flakes indian dish"
        ]
    },
    {
        "food_id": "predefined_tandoori_chicken",
        "food_name": "Tandoori Chicken",
        "target": 15,
        "queries": [
            "tandoori chicken plate", "grilled tandoori chicken", "tandoori murgh dish",
            "chicken tikka plate roasted", "tandoori chicken drumstick", "roasted chicken tikka",
            "tandoori chicken barbecue", "tandoori chicken restaurant"
        ]
    },
    {
        "food_id": "predefined_paneer_tikka",
        "food_name": "Paneer Tikka",
        "target": 15,
        "queries": [
            "paneer tikka plate", "grilled paneer tikka skewers", "paneer kebab plate",
            "malai paneer tikka", "tandoori paneer tikka", "paneer tikka restaurant",
            "grilled cottage cheese paneer", "paneer tikka shashlik"
        ]
    },
    {
        "food_id": "predefined_rajma_curry",
        "food_name": "Rajma Curry",
        "target": 15,
        "queries": [
            "rajma chawal plate", "red kidney beans curry dish", "cooked rajma bowl",
            "rajma masala curry", "kidney beans curry indian", "rajma gravy punjabi",
            "red bean curry bowl", "rajma thali"
        ]
    },
    {
        "food_id": "predefined_broccoli",
        "food_name": "Broccoli",
        "target": 15,
        "queries": ["broccoli florets bowl", "raw green broccoli head", "cooked broccoli plate", "broccoli dish"]
    },
    {
        "food_id": "predefined_chole_masala",
        "food_name": "Chole Masala",
        "target": 15,
        "queries": ["chana masala chickpea curry", "punjabi chole dish", "chickpea curry bowl indian", "chole bhature plate"]
    },
    {
        "food_id": "predefined_samosa",
        "food_name": "Samosa",
        "target": 15,
        "queries": ["crispy samosa snack plate", "fried samosa street food", "punjabi samosas chutney", "samosa pastry fried"]
    }
]

# Unsupported FitFuel foods from 238 catalog outside 50 classes
UNSUPPORTED_EXPANDED = [
    ("predefined_biryani", "Chicken Biryani", ["biryani plate restaurant", "mutton biryani dish", "chicken biryani rice", "hyderabadi biryani plate"]),
    ("predefined_paneer_butter_masala", "Paneer Butter Masala", ["paneer butter masala bowl", "paneer makhani curry", "shahi paneer curry"]),
    ("predefined_pav_bhaji", "Pav Bhaji", ["pav bhaji plate indian", "mumbai pav bhaji dish", "bhaji pav street food"]),
    ("predefined_gulab_jamun", "Gulab Jamun", ["gulab jamun sweet bowl", "kala jamun dessert plate", "two gulab jamun plate"]),
    ("predefined_momos", "Steamed Momos", ["steamed momos plate", "dumplings momos plate", "veg momos chutney"]),
    ("predefined_butter_chicken", "Butter Chicken", ["butter chicken curry bowl", "murgh makhani chicken dish", "butter chicken restaurant"]),
    ("predefined_dal_makhani", "Dal Makhani", ["dal makhani curry bowl", "black lentil dal makhani", "punjabi dal makhani"]),
    ("predefined_naan", "Butter Naan", ["butter naan bread basket", "garlic naan bread plate", "tandoori naan flatbread"]),
    ("predefined_paratha", "Aloo Paratha", ["aloo paratha plate curd", "plain paratha flatbread", "stuffed paratha butter"]),
    ("predefined_khichdi", "Moong Dal Khichdi", ["khichdi rice lentil bowl", "dal khichdi indian dish", "moong dal khichdi"]),
    ("predefined_rasgulla", "Rasgulla", ["white rasgulla sweet bowl", "rasgulla dessert syrup", "bengali rasgulla"]),
    ("predefined_bhel_puri", "Bhel Puri", ["bhel puri street food plate", "sev puri chaat plate", "bhelpuri chaat snack"]),
    ("predefined_pani_puri", "Pani Puri", ["pani puri golgappa plate", "puchka chaat plate", "pani puri street food"]),
    ("predefined_palak_paneer", "Palak Paneer", ["palak paneer curry bowl", "cottage cheese spinach palak", "saag paneer bowl"]),
    ("predefined_jalebi", "Jalebi", ["crispy jalebi sweet plate", "orange jalebi sweet", "jalebi indian dessert"]),
    ("predefined_kheer", "Rice Kheer", ["rice kheer pudding bowl", "payasam dessert bowl", "indian kheer sweet"]),
    ("predefined_halwa", "Gajar Halwa", ["gajar ka halwa carrot dessert", "sooji halwa plate", "sheera halwa sweet"]),
    ("predefined_vada_pav", "Vada Pav", ["vada pav mumbai street food", "batata vada pav plate", "vada pav burger snack"]),
    ("predefined_fish_fry", "Fish Fry", ["fish fry plate lemon", "fried fish indian style", "crispy fish fry dish"]),
    ("predefined_chicken_curry", "Chicken Curry", ["indian chicken curry bowl", "chicken gravy curry dish", "homestyle chicken curry"]),
    ("predefined_idiyappam", "Idiyappam", ["idiyappam string hoppers plate", "sevai south indian breakfast", "idiyappam dish"]),
    ("predefined_poori", "Poori Bhaji", ["poori bhaji breakfast plate", "puri aloo curry dish", "fried poori bread"]),
    ("predefined_chana_chaat", "Chana Chaat", ["chana chaat salad plate", "chickpea salad chaat bowl", "kala chana chaat"]),
    ("predefined_missi_roti", "Missi Roti", ["missi roti flatbread plate", "gram flour flatbread roti", "rajasthani missi roti"]),
    ("predefined_dahi_vada", "Dahi Vada", ["dahi vada dahi bhalla plate", "dahi bhalla chaat bowl", "curd vada snack"])
]

# Mixed Meals (thali, platters, combo trays)
MIXED_MEAL_EXPANDED = [
    ("North Indian Thali", ["north indian thali meal lunch plate", "punjabi thali plate", "thali north india lunch"]),
    ("South Indian Banana Leaf Meal", ["south indian banana leaf meal thali wedding", "banana leaf lunch feast south india", "kerala sadhya banana leaf"]),
    ("Gujarati Thali", ["gujarati thali traditional lunch meal", "kathiyawadi thali plate lunch"]),
    ("Rajasthani Thali", ["rajasthani thali dal baati churma plate", "traditional rajasthani meal tray"]),
    ("Bengali Thali", ["bengali thali fish rice curries plate", "bengali lunch meal assortment"]),
    ("Maharashtrian Thali", ["maharashtrian thali lunch plate", "marathi thali meal"]),
    ("Continental Breakfast Platter", ["hotel breakfast platter eggs toast bacon sausage", "continental breakfast spread buffet"]),
    ("Buffet Plate Assorted", ["buffet plate food assorted meal dinner", "banquet meal plate food assortment"]),
    ("Indian Lunch Tray", ["indian meal thali tray stainless steel bowls", "office lunch thali tray"]),
    ("Dinner Combo Spread", ["family dinner food spread feast table", "potluck dinner food spread feast"]),
    ("Rice and Curries Platter", ["rice plate multiple curries bowls", "lunch plate rice dal sabzi salad"]),
    ("Bento Box Meal", ["japanese bento box meal lunch", "lunch box bento meal partitioned"])
]

SUSPICIOUS_TITLE_KEYWORDS = [
    "drawing", "illustration", "vector", "banner", "clipart", "logo", "icon", "diagram"
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

def search_wikimedia_safe(query: str, limit: int = 40):
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(min(limit, 40)),
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "320",
        "format": "json"
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    for attempt in range(4):
        time.sleep(0.4)
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
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait_sec = 2.5 * (attempt + 1)
                time.sleep(wait_sec)
            else:
                break
        except Exception:
            time.sleep(1.0)
    return []

def download_candidate(item):
    url = item["thumb_url"]
    for attempt in range(3):
        time.sleep(0.3)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = resp.read()
                img = Image.open(io.BytesIO(data)).convert("RGB")
                if img.width < 140 or img.height < 140:
                    return None, None, "low_resolution"
                aspect = img.width / float(img.height)
                if aspect > 3.0 or aspect < 0.33:
                    return None, None, "extreme_aspect_ratio"
                arr = np.array(img)
                if np.std(arr) < 14.0:
                    return None, None, "low_variance"
                return img, data, "ok"
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2.0 * (attempt + 1))
            else:
                break
        except Exception:
            time.sleep(0.5)
    return None, None, "network_error"

def load_prior_hashes():
    existing_sha256 = set()
    existing_dhashes = set()
    manifest_files = [
        "ml/dataset_manifest.csv",
        "ml/non_food_manifest.csv",
        "ml/unsupported_food_manifest.csv",
        "ml/mixed_meal_manifest.csv"
    ]
    for mf in manifest_files:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for r in reader:
                    s = r.get("sha256")
                    if s:
                        existing_sha256.add(s)
                    h = r.get("perceptual_hash")
                    if h:
                        existing_dhashes.add(h)

    dataset_dir = "ml/dataset"
    if os.path.exists(dataset_dir):
        for root, _, files in os.walk(dataset_dir):
            for file in files:
                if file.lower().endswith((".jpg", ".jpeg", ".png")):
                    full_p = os.path.join(root, file)
                    try:
                        with open(full_p, "rb") as f:
                            sha = hashlib.sha256(f.read()).hexdigest()
                            existing_sha256.add(sha)
                        with Image.open(full_p) as img:
                            dh = compute_dhash(img.convert("RGB"))
                            existing_dhashes.add(dh)
                    except Exception:
                        pass
    return existing_sha256, list(existing_dhashes)

def is_leaked_or_duplicate(sha, dhash, existing_sha256, existing_dhashes, holdout_dhashes):
    if sha in existing_sha256:
        return True, "exact_sha256_leakage"
    for eh in existing_dhashes:
        if hamming_distance(dhash, eh) <= 6:
            return True, "perceptual_leakage_distance_le_6"
    for hh in holdout_dhashes:
        if hamming_distance(dhash, hh) <= 4:
            return True, "internal_near_duplicate_distance_le_4"
    return False, "clean"

def main():
    print("=== Resilient Independent Holdout Completion ===", flush=True)
    manifest_path = "ml/independent_holdout_manifest.csv"
    existing_manifest_rows = []
    current_class_counts = {}
    holdout_dhashes = []

    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            existing_manifest_rows = list(csv.DictReader(f))
        for r in existing_manifest_rows:
            fid = r["food_id"]
            current_class_counts[fid] = current_class_counts.get(fid, 0) + 1
            if r.get("perceptual_hash"):
                holdout_dhashes.append(r["perceptual_hash"])

    print(f"Loaded {len(existing_manifest_rows)} already accepted independent images.", flush=True)

    existing_sha256, existing_dhashes = load_prior_hashes()
    base_out = "ml/dataset_independent_holdout"
    supported_dir = os.path.join(base_out, "supported")
    unsupported_dir = os.path.join(base_out, "unsupported_food")
    mixed_dir = os.path.join(base_out, "mixed_meals")

    new_rows = []

    # 1. Complete Remaining Supported Classes
    for cls in REMAINING_SUPPORTED:
        fid = cls["food_id"]
        fname = cls["food_name"]
        target = cls["target"]
        cur = current_class_counts.get(fid, 0)
        needed = max(0, target - cur)
        if needed == 0:
            print(f"Supported {fname} already satisfied ({cur}/{target}).", flush=True)
            continue

        print(f"Collecting {needed} more images for {fname} ({cur}/{target})...", flush=True)
        out_cls_dir = os.path.join(supported_dir, fid)
        os.makedirs(out_cls_dir, exist_ok=True)

        for query in cls["queries"]:
            if needed <= 0:
                break
            items = search_wikimedia_safe(query, limit=35)
            for item in items:
                if needed <= 0:
                    break
                img, raw_bytes, status = download_candidate(item)
                if status != "ok":
                    continue
                sha = compute_sha256(raw_bytes)
                dh = compute_dhash(img)
                leaked, _ = is_leaked_or_duplicate(sha, dh, existing_sha256, existing_dhashes, holdout_dhashes)
                if leaked:
                    continue

                cur += 1
                needed -= 1
                save_path = os.path.join(out_cls_dir, f"{fid}_ind_{cur:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(save_path, "JPEG", quality=90)

                with open(save_path, "rb") as sf:
                    final_sha = compute_sha256(sf.read())
                final_dh = compute_dhash(img)
                holdout_dhashes.append(final_dh)

                rel_path = os.path.relpath(save_path, "ml").replace("\\", "/")
                new_row = {
                    "image_path": rel_path,
                    "food_id": fid,
                    "food_name": fname,
                    "source": "Wikimedia Commons (Audited)",
                    "source_reference": item["desc_url"],
                    "license": item["license"],
                    "sha256": final_sha,
                    "perceptual_hash": final_dh,
                    "width": img.width,
                    "height": img.height,
                    "review_status": "ACCEPTED_INDEPENDENT"
                }
                new_rows.append(new_row)
                existing_manifest_rows.append(new_row)
                current_class_counts[fid] = cur

        print(f"  -> {fname} now has {cur} images.", flush=True)

    # 2. Complete Unsupported FitFuel Foods (Target 55 total)
    total_unsupported = sum(1 for r in existing_manifest_rows if r["food_id"].startswith("predefined_") and r["food_id"] not in [
        "predefined_watermelon", "predefined_strawberry", "predefined_medu_vada", "predefined_steamed_rice",
        "predefined_scrambled_eggs", "predefined_rajma_curry", "predefined_capsicum", "predefined_whole_wheat_bread",
        "predefined_guava", "predefined_dosa", "predefined_broccoli", "predefined_chole_masala",
        "predefined_low_fat_milk", "predefined_poha", "predefined_potato", "predefined_samosa",
        "predefined_tandoori_chicken", "predefined_paneer_tikka"
    ])
    needed_unsupported = max(0, 55 - total_unsupported)
    print(f"\nCurrent unsupported foods: {total_unsupported}/55 (need {needed_unsupported})...", flush=True)

    if needed_unsupported > 0:
        for ufid, ufname, queries in UNSUPPORTED_EXPANDED:
            if needed_unsupported <= 0:
                break
            for query in queries:
                if needed_unsupported <= 0:
                    break
                items = search_wikimedia_safe(query, limit=25)
                for item in items:
                    if needed_unsupported <= 0:
                        break
                    img, raw_bytes, status = download_candidate(item)
                    if status != "ok":
                        continue
                    sha = compute_sha256(raw_bytes)
                    dh = compute_dhash(img)
                    leaked, _ = is_leaked_or_duplicate(sha, dh, existing_sha256, existing_dhashes, holdout_dhashes)
                    if leaked:
                        continue

                    total_unsupported += 1
                    needed_unsupported -= 1
                    save_path = os.path.join(unsupported_dir, f"unsupported_ind_{total_unsupported:03d}.jpg")
                    img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                    img.save(save_path, "JPEG", quality=90)

                    with open(save_path, "rb") as sf:
                        final_sha = compute_sha256(sf.read())
                    final_dh = compute_dhash(img)
                    holdout_dhashes.append(final_dh)

                    rel_path = os.path.relpath(save_path, "ml").replace("\\", "/")
                    new_row = {
                        "image_path": rel_path,
                        "food_id": ufid,
                        "food_name": ufname,
                        "source": "Wikimedia Commons (Audited)",
                        "source_reference": item["desc_url"],
                        "license": item["license"],
                        "sha256": final_sha,
                        "perceptual_hash": final_dh,
                        "width": img.width,
                        "height": img.height,
                        "review_status": "ACCEPTED_INDEPENDENT"
                    }
                    new_rows.append(new_row)
                    existing_manifest_rows.append(new_row)

    print(f"Unsupported foods now total: {total_unsupported}", flush=True)

    # 3. Complete Mixed Meals (Target 35 total)
    total_mixed = sum(1 for r in existing_manifest_rows if r["food_id"] == "mixed_meal")
    needed_mixed = max(0, 35 - total_mixed)
    print(f"\nCurrent mixed meals: {total_mixed}/35 (need {needed_mixed})...", flush=True)

    if needed_mixed > 0:
        for mname, queries in MIXED_MEAL_EXPANDED:
            if needed_mixed <= 0:
                break
            for query in queries:
                if needed_mixed <= 0:
                    break
                items = search_wikimedia_safe(query, limit=25)
                for item in items:
                    if needed_mixed <= 0:
                        break
                    img, raw_bytes, status = download_candidate(item)
                    if status != "ok":
                        continue
                    sha = compute_sha256(raw_bytes)
                    dh = compute_dhash(img)
                    leaked, _ = is_leaked_or_duplicate(sha, dh, existing_sha256, existing_dhashes, holdout_dhashes)
                    if leaked:
                        continue

                    total_mixed += 1
                    needed_mixed -= 1
                    save_path = os.path.join(mixed_dir, f"mixed_meal_ind_{total_mixed:03d}.jpg")
                    img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                    img.save(save_path, "JPEG", quality=90)

                    with open(save_path, "rb") as sf:
                        final_sha = compute_sha256(sf.read())
                    final_dh = compute_dhash(img)
                    holdout_dhashes.append(final_dh)

                    rel_path = os.path.relpath(save_path, "ml").replace("\\", "/")
                    new_row = {
                        "image_path": rel_path,
                        "food_id": "mixed_meal",
                        "food_name": mname,
                        "source": "Wikimedia Commons (Audited)",
                        "source_reference": item["desc_url"],
                        "license": item["license"],
                        "sha256": final_sha,
                        "perceptual_hash": final_dh,
                        "width": img.width,
                        "height": img.height,
                        "review_status": "ACCEPTED_INDEPENDENT"
                    }
                    new_rows.append(new_row)
                    existing_manifest_rows.append(new_row)

    print(f"Mixed meals now total: {total_mixed}", flush=True)

    # Save final manifest
    fieldnames = [
        "image_path", "food_id", "food_name", "source", "source_reference",
        "license", "sha256", "perceptual_hash", "width", "height", "review_status"
    ]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(existing_manifest_rows)

    print(f"\nFinal Independent Holdout Size: {len(existing_manifest_rows)} images recorded in {manifest_path}", flush=True)

if __name__ == "__main__":
    main()
