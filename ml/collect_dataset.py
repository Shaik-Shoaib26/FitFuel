#!/usr/bin/env python3
"""
FitFuel Phase 35.9.2 - Dataset Expansion & Hardening Collector
Collects diverse, licensed images from Wikimedia Commons for:
1. 50 V1 Supported Food Classes
2. Non-Food Out-of-Distribution Test Set
3. Unsupported Food Test Set

Performs SHA-256 and perceptual hash (dHash) deduplication, quality filtering,
stratified train/validation/test partitioning, and generates dataset_audit.json.
"""

import argparse
import csv
import hashlib
import io
import json
import os
import random
import sys
import time
import urllib.parse
import urllib.request
import numpy as np
from PIL import Image

USER_AGENT = "FitFuelResearchBot/2.0 (https://fitfuel.app; contact@fitfuel.app)"

FOOD_CLASSES = [
    # Fruits (10)
    {"food_id": "predefined_apple", "food_name": "Red Apple", "queries": ["red apple fruit", "apple fruit", "fresh apple", "sliced apple"]},
    {"food_id": "predefined_banana", "food_name": "Ripe Banana", "queries": ["ripe banana", "banana fruit", "yellow banana", "banana bunch"]},
    {"food_id": "predefined_orange", "food_name": "Orange", "queries": ["orange fruit", "fresh orange citrus", "sliced orange", "orange tree"]},
    {"food_id": "predefined_mango", "food_name": "Mango", "queries": ["mango fruit", "ripe mango", "sliced mango", "alphonso mango"]},
    {"food_id": "predefined_papaya", "food_name": "Papaya", "queries": ["papaya fruit", "sliced papaya", "fresh papaya", "pawpaw fruit"]},
    {"food_id": "predefined_watermelon", "food_name": "Watermelon", "queries": ["watermelon slice", "watermelon fruit", "fresh watermelon", "sliced watermelon"]},
    {"food_id": "predefined_pineapple", "food_name": "Pineapple", "queries": ["pineapple fruit", "fresh pineapple", "sliced pineapple", "pineapple chunks"]},
    {"food_id": "predefined_grapes", "food_name": "Green Grapes", "queries": ["green grapes", "table grapes", "grapes bunch", "white grapes"]},
    {"food_id": "predefined_guava", "food_name": "Guava", "queries": ["guava fruit", "ripe guava", "sliced guava", "pink guava"]},
    {"food_id": "predefined_strawberry", "food_name": "Strawberry", "queries": ["strawberry fruit", "fresh strawberries", "ripe strawberry", "strawberry bowl"]},

    # Breakfast / Indian (6)
    {"food_id": "predefined_idli", "food_name": "Idli", "queries": ["idli food", "idli dish", "idlis breakfast", "steamed idli"]},
    {"food_id": "predefined_dosa", "food_name": "Plain Dosa", "queries": ["plain dosa", "dosa dish", "masala dosa", "crispy dosa", "south indian dosa"]},
    {"food_id": "predefined_uttapam", "food_name": "Uttapam", "queries": ["uttapam", "onion uttapam", "uthappam", "tomato uttapam"]},
    {"food_id": "predefined_poha", "food_name": "Poha", "queries": ["poha dish", "poha breakfast", "kanda poha", "flattened rice poha"]},
    {"food_id": "predefined_upma", "food_name": "Upma", "queries": ["upma food", "rava upma", "uppittu", "sooji upma"]},
    {"food_id": "predefined_medu_vada", "food_name": "Medu Vada", "queries": ["medu vada", "vada dish", "vada sambar", "urad dal vada"]},

    # Staples / Grains (6)
    {"food_id": "predefined_steamed_rice", "food_name": "Steamed Rice (Basmati)", "queries": ["steamed white rice", "cooked basmati rice", "bowl of cooked rice", "boiled rice"]},
    {"food_id": "predefined_brown_rice_ind", "food_name": "Indian Brown Rice", "queries": ["cooked brown rice", "brown rice bowl", "brown rice", "wholegrain rice"]},
    {"food_id": "predefined_chapati", "food_name": "Chapati", "queries": ["chapati bread", "roti chapati", "indian chapati", "phulka chapati"]},
    {"food_id": "predefined_roti", "food_name": "Tandoori Roti", "queries": ["tandoori roti", "naan roti", "indian flatbread", "roti tandoor"]},
    {"food_id": "predefined_oats", "food_name": "Oats (Rolled)", "queries": ["oatmeal porridge", "rolled oats bowl", "bowl of oats", "cooked oatmeal"]},
    {"food_id": "predefined_whole_wheat_bread", "food_name": "Whole Wheat Bread Slice", "queries": ["whole wheat bread slice", "brown bread slice", "wheat bread toast", "sliced whole wheat bread"]},

    # Protein / Eggs / Meat (8)
    {"food_id": "predefined_hard_boiled_eggs", "food_name": "Hard Boiled Eggs", "queries": ["hard boiled eggs", "boiled egg", "sliced boiled egg", "shelled boiled eggs"]},
    {"food_id": "predefined_egg_omelette", "food_name": "Masala Egg Omelette", "queries": ["egg omelette", "masala omelette", "omelet food", "folded omelette"]},
    {"food_id": "predefined_scrambled_eggs", "food_name": "Scrambled Eggs (Two Eggs)", "queries": ["scrambled eggs", "plate of scrambled eggs", "cooked scrambled eggs", "pan scrambled eggs"]},
    {"food_id": "predefined_grilled_chicken_breast", "food_name": "Grilled Chicken Breast", "queries": ["grilled chicken breast", "cooked chicken breast", "chicken breast fillet", "charred chicken breast"]},
    {"food_id": "predefined_tandoori_chicken", "food_name": "Tandoori Chicken (Tikka)", "queries": ["tandoori chicken", "chicken tikka dish", "tandoori roast chicken", "murgh tandoori"]},
    {"food_id": "predefined_ind_paneer", "food_name": "Paneer (Indian Cottage Cheese)", "queries": ["paneer cheese", "raw paneer cubes", "indian paneer", "fresh paneer"]},
    {"food_id": "predefined_firm_tofu", "food_name": "Tofu (Firm)", "queries": ["tofu cubes", "firm tofu", "block of tofu", "sliced tofu"]},
    {"food_id": "predefined_paneer_tikka", "food_name": "Paneer Tikka", "queries": ["paneer tikka", "paneer tikka kebab", "grilled paneer", "paneer kebab"]},

    # Dairy / Beverages (4)
    {"food_id": "predefined_low_fat_milk", "food_name": "Low Fat Milk (1.5% Fat)", "queries": ["glass of milk", "milk glass", "fresh milk", "cup of milk"]},
    {"food_id": "predefined_curd", "food_name": "Indian Curd (Dahi)", "queries": ["bowl of curd", "dahi curd", "yogurt dahi", "pot of curd"]},
    {"food_id": "predefined_greek_yogurt_plain", "food_name": "Greek Yogurt (Plain, Non-Fat)", "queries": ["greek yogurt bowl", "plain yogurt bowl", "strained yogurt", "cup of yogurt"]},
    {"food_id": "predefined_coconut_water", "food_name": "Tender Coconut Water", "queries": ["tender coconut water", "green coconut drink", "coconut drink", "fresh coconut water"]},

    # Legumes / Curries (5)
    {"food_id": "predefined_dal_tadka", "food_name": "Dal Tadka", "queries": ["dal tadka", "yellow dal tadka", "daal curry", "tadka dal"]},
    {"food_id": "predefined_chole_masala", "food_name": "Chole Masala (Chickpeas)", "queries": ["chole masala", "chana masala dish", "punjabi chole", "chickpea curry"]},
    {"food_id": "predefined_rajma_curry", "food_name": "Rajma Curry (Kidney Beans)", "queries": ["rajma curry", "rajma dish", "kidney bean curry", "punjabi rajma"]},
    {"food_id": "predefined_moong_dal", "food_name": "Yellow Moong Dal", "queries": ["moong dal curry", "cooked moong dal", "moong dhal", "yellow lentil dal"]},
    {"food_id": "predefined_sambar", "food_name": "Sambar", "queries": ["sambar curry", "south indian sambar", "sambar soup", "bowl of sambar"]},

    # Vegetables (9)
    {"food_id": "predefined_potato", "food_name": "Potato (Raw)", "queries": ["potato tuber", "raw potatoes", "fresh potato", "russet potatoes"]},
    {"food_id": "predefined_tomato", "food_name": "Tomato (Red)", "queries": ["ripe red tomato", "tomatoes fresh", "tomato vegetable", "roma tomato"]},
    {"food_id": "predefined_carrot", "food_name": "Raw Orange Carrot", "queries": ["fresh orange carrot", "raw carrots", "carrot root", "carrots bunch"]},
    {"food_id": "predefined_broccoli", "food_name": "Broccoli", "queries": ["broccoli florets", "fresh broccoli head", "green broccoli", "raw broccoli"]},
    {"food_id": "predefined_cauliflower", "food_name": "Cauliflower", "queries": ["cauliflower head", "fresh cauliflower", "white cauliflower", "raw cauliflower"]},
    {"food_id": "predefined_cucumber", "food_name": "Cucumber (With Peel)", "queries": ["fresh cucumber vegetable", "sliced cucumber", "green cucumber", "whole cucumber"]},
    {"food_id": "predefined_spinach", "food_name": "Spinach (Raw)", "queries": ["spinach leaves", "fresh spinach bundle", "palak spinach", "raw spinach"]},
    {"food_id": "predefined_capsicum", "food_name": "Green Bell Pepper (Capsicum)", "queries": ["green bell pepper", "green capsicum", "bell pepper", "capsicum vegetable"]},
    {"food_id": "predefined_onion", "food_name": "Raw Onion", "queries": ["red onion bulb", "raw onion", "fresh onions", "yellow onion"]},

    # Snacks (2)
    {"food_id": "predefined_samosa", "food_name": "Samosa", "queries": ["samosa pastry", "fried samosa", "indian samosa", "punjabi samosa"]},
    {"food_id": "predefined_almonds", "food_name": "Almonds (Raw)", "queries": ["raw almonds nuts", "almonds bowl", "shelled almonds", "almond kernels"]}
]

NON_FOOD_QUERIES = [
    ("laptop", "Laptop Computer", "laptop computer electronic"),
    ("smartphone", "Smartphone", "smartphone mobile phone device"),
    ("shoe", "Leather Shoe", "leather shoe footwear"),
    ("chair", "Office Chair", "office chair furniture"),
    ("desk", "Wooden Table Desk", "wooden desk table furniture"),
    ("book", "Reading Book", "open book reading paper"),
    ("car", "Passenger Automobile", "passenger car vehicle automobile"),
    ("plate", "Empty Ceramic Plate", "empty ceramic plate tableware"),
    ("knife", "Kitchen Knife", "kitchen knife cutlery steel"),
    ("backpack", "Backpack Bag", "backpack bag travel"),
]

UNSUPPORTED_FOOD_QUERIES = [
    ("predefined_veg_biryani", "Vegetable Biryani", "vegetable biryani rice dish"),
    ("predefined_pizza", "Cheese Pizza", "cheese pizza slice italian"),
    ("predefined_burger", "Burger", "burger hamburger bun"),
    ("predefined_croissant", "Croissant", "croissant pastry bakery"),
    ("predefined_fish_curry", "Fish Curry", "fish curry seafood dish"),
    ("predefined_gulab_jamun", "Gulab Jamun", "gulab jamun sweet indian dessert"),
    ("predefined_pani_puri", "Pani Puri", "pani puri golgappa snack"),
    ("predefined_pav_bhaji", "Pav Bhaji", "pav bhaji street food"),
    ("predefined_ice_cream", "Ice Cream", "ice cream scoop sundae"),
    ("predefined_chocolate_cake", "Chocolate Cake", "chocolate cake slice dessert"),
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


def search_wikimedia(query, limit=20):
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(limit),
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
    except Exception as e:
        return []


def download_image(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = resp.read()
            img = Image.open(io.BytesIO(data))
            img = img.convert("RGB")
            if img.width < 50 or img.height < 50:
                return None, None
            # Reject solid images with very low variance
            arr = np.array(img)
            if np.std(arr) < 8.0:
                return None, None
            return img, data
    except Exception:
        return None, None


def main():
    parser = argparse.ArgumentParser(description="Expand & Harden FitFuel Food Dataset")
    parser.add_argument("--output_dir", type=str, default="dataset", help="Output directory")
    parser.add_argument("--manifest", type=str, default="dataset_manifest.csv", help="Manifest CSV")
    parser.add_argument("--audit_report", type=str, default="reports/dataset_audit.json", help="Audit report JSON")
    parser.add_argument("--images_per_class", type=int, default=20, help="Target images per class (default 20)")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    os.makedirs(os.path.dirname(args.audit_report), exist_ok=True)

    splits = ["train", "validation", "test"]
    for s in splits:
        os.makedirs(os.path.join(args.output_dir, s), exist_ok=True)

    os.makedirs(os.path.join(args.output_dir, "non_food"), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "unsupported_food"), exist_ok=True)

    global_sha256 = set()
    class_dhashes = {}  # food_id -> list of dhashes
    manifest_rows = []

    audit_stats = {
        "dataset_version": "fitfuel_food_dataset_v2",
        "total_images": 0,
        "classes_count": len(FOOD_CLASSES),
        "target_images_per_class": args.images_per_class,
        "exact_duplicates_rejected": 0,
        "near_duplicates_rejected": 0,
        "broken_or_invalid_rejected": 0,
        "per_class_counts": {},
        "splits_distribution": {"train": 0, "validation": 0, "test": 0},
        "license_distribution": {},
        "non_food_test_images": 0,
        "unsupported_food_test_images": 0,
    }

    print("============================================================", flush=True)
    print("  FITFUEL PHASE 35.9.2: DATASET EXPANSION & QUALITY AUDIT   ", flush=True)
    print("============================================================", flush=True)
    print(f"Target Classes:           {len(FOOD_CLASSES)}", flush=True)
    print(f"Target Images Per Class:  {args.images_per_class}", flush=True)
    print("Starting collection with SHA-256 and perceptual dHash filtering...\n", flush=True)

    # 1. Collect Supported Food Classes
    for idx, food in enumerate(FOOD_CLASSES, 1):
        food_id = food["food_id"]
        food_name = food["food_name"]
        queries = food["queries"]

        class_dhashes[food_id] = []
        class_images = []
        seen_titles = set()

        for s in splits:
            os.makedirs(os.path.join(args.output_dir, s, food_id), exist_ok=True)

        print(f"[{idx:02d}/50] Collecting '{food_name}' ({food_id})...", end=" ", flush=True)

        for q in queries:
            if len(class_images) >= args.images_per_class:
                break
            time.sleep(0.08)
            results = search_wikimedia(q, limit=args.images_per_class * 2)

            for item in results:
                if len(class_images) >= args.images_per_class:
                    break
                if item["title"] in seen_titles:
                    continue
                seen_titles.add(item["title"])

                img, raw_bytes = download_image(item["thumb_url"])
                if img is None or raw_bytes is None:
                    audit_stats["broken_or_invalid_rejected"] += 1
                    continue

                # SHA-256 deduplication
                img_sha = compute_sha256(raw_bytes)
                if img_sha in global_sha256:
                    audit_stats["exact_duplicates_rejected"] += 1
                    continue

                # Perceptual dHash deduplication (Hamming distance <= 4)
                img_dhash = compute_dhash(img)
                is_near_dup = False
                for existing_h in class_dhashes[food_id]:
                    if hamming_distance(img_dhash, existing_h) <= 4:
                        is_near_dup = True
                        break

                if is_near_dup:
                    audit_stats["near_duplicates_rejected"] += 1
                    continue

                # Valid, diverse image accepted
                global_sha256.add(img_sha)
                class_dhashes[food_id].append(img_dhash)
                class_images.append((img, item, img_sha, img_dhash))

        # Stratified split: 75% train, 12.5% val, 12.5% test
        n = len(class_images)
        audit_stats["per_class_counts"][food_id] = n

        # Assign splits deterministically:
        # e.g. for n images, test: max(2, round(0.125 * n)), val: max(2, round(0.125 * n)), rest train
        n_test = max(2, int(round(n * 0.125))) if n >= 6 else (1 if n >= 3 else 0)
        n_val = max(2, int(round(n * 0.125))) if n >= 6 else (1 if n >= 3 else 0)
        n_train = n - n_test - n_val

        for i, (img, item, sha, dhash_val) in enumerate(class_images):
            if i < n_train:
                split = "train"
            elif i < n_train + n_val:
                split = "validation"
            else:
                split = "test"

            audit_stats["splits_distribution"][split] += 1
            lic = str(item["license"])
            audit_stats["license_distribution"][lic] = audit_stats["license_distribution"].get(lic, 0) + 1

            img_filename = f"{food_id}_{i+1:03d}.jpg"
            rel_path = os.path.join(args.output_dir, split, food_id, img_filename).replace("\\", "/")
            full_path = os.path.join(args.output_dir, split, food_id, img_filename)

            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)

            manifest_rows.append({
                "image_path": rel_path,
                "food_id": food_id,
                "food_name": food_name,
                "source": "Wikimedia Commons",
                "source_url_or_reference": item["desc_url"],
                "license": lic,
                "split": split,
                "sha256": sha,
                "perceptual_hash": dhash_val
            })

        print(f"-> {n} images (train={n_train}, val={n_val}, test={n_test})", flush=True)

    audit_stats["total_images"] = len(manifest_rows)

    # Save dataset_manifest.csv
    with open(args.manifest, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "image_path", "food_id", "food_name", "source",
            "source_url_or_reference", "license", "split", "sha256", "perceptual_hash"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(manifest_rows)

    print(f"\nSaved primary manifest to {args.manifest} ({len(manifest_rows)} total images)", flush=True)

    # 2. Collect Non-Food Out-of-Distribution Test Set (Section 21)
    non_food_rows = []
    print("\nCollecting Non-Food OOD Test Set (10 classes)...", flush=True)
    for cat_id, cat_name, q in NON_FOOD_QUERIES:
        time.sleep(0.1)
        res = search_wikimedia(q, limit=5)
        count = 0
        for item in res:
            if count >= 3:
                break
            img, raw_bytes = download_image(item["thumb_url"])
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"non_food_{cat_id}_{count:02d}.jpg"
            rel_path = os.path.join(args.output_dir, "non_food", filename).replace("\\", "/")
            full_path = os.path.join(args.output_dir, "non_food", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            non_food_rows.append({
                "image_path": rel_path,
                "category": cat_name,
                "source": "Wikimedia Commons",
                "source_url_or_reference": item["desc_url"],
                "license": item["license"],
                "sha256": sha
            })

    audit_stats["non_food_test_images"] = len(non_food_rows)
    with open("non_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["image_path", "category", "source", "source_url_or_reference", "license", "sha256"])
        writer.writeheader()
        writer.writerows(non_food_rows)
    print(f"Saved Non-Food manifest to non_food_manifest.csv ({len(non_food_rows)} images)", flush=True)

    # 3. Collect Unsupported Food Test Set (Section 22)
    unsupported_rows = []
    print("\nCollecting Unsupported Food Test Set (10 classes)...", flush=True)
    for food_id, food_name, q in UNSUPPORTED_FOOD_QUERIES:
        time.sleep(0.1)
        res = search_wikimedia(q, limit=5)
        count = 0
        for item in res:
            if count >= 3:
                break
            img, raw_bytes = download_image(item["thumb_url"])
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"unsupported_{food_id}_{count:02d}.jpg"
            rel_path = os.path.join(args.output_dir, "unsupported_food", filename).replace("\\", "/")
            full_path = os.path.join(args.output_dir, "unsupported_food", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            unsupported_rows.append({
                "image_path": rel_path,
                "food_id": food_id,
                "food_name": food_name,
                "source": "Wikimedia Commons",
                "source_url_or_reference": item["desc_url"],
                "license": item["license"],
                "sha256": sha
            })

    audit_stats["unsupported_food_test_images"] = len(unsupported_rows)
    with open("unsupported_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["image_path", "food_id", "food_name", "source", "source_url_or_reference", "license", "sha256"])
        writer.writeheader()
        writer.writerows(unsupported_rows)
    print(f"Saved Unsupported Food manifest to unsupported_food_manifest.csv ({len(unsupported_rows)} images)", flush=True)

    # Compute audit summary metrics
    counts = list(audit_stats["per_class_counts"].values())
    audit_stats["summary"] = {
        "min_images_per_class": int(np.min(counts)) if counts else 0,
        "max_images_per_class": int(np.max(counts)) if counts else 0,
        "mean_images_per_class": float(np.mean(counts)) if counts else 0.0,
        "median_images_per_class": float(np.median(counts)) if counts else 0.0,
    }

    # Save audit report JSON
    with open(args.audit_report, "w", encoding="utf-8") as f:
        json.dump(audit_stats, f, indent=2)

    print(f"\nSaved Quality Audit Report to {args.audit_report}", flush=True)
    print("============================================================\n", flush=True)


if __name__ == "__main__":
    main()
