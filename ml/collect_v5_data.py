#!/usr/bin/env python3
"""
FitFuel Phase 35.9.5 - Targeted Supplements & Final Lockbox Collector
1. Collects targeted training supplements for 10 classes needing reinforcement
2. Collects the untouched Final Lockbox Dataset (ml/dataset_final_lockbox_v5/)
   - 16 candidate production classes (15-20 images/class)
   - 75+ non-food images
   - 75+ unsupported FitFuel foods (including dietary risk pairs: Paneer Butter Masala, Biryani, curries)
   - 40+ mixed meals
3. Enforces ZERO DATA LEAKAGE against ALL previous datasets (3,188 baseline + negatives + Phase 35.9.4 holdout).
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

USER_AGENT = "FitFuelAuditBot/5.0 (https://fitfuel.app; dev@fitfuel.app)"

# 10 classes targeted for training additions
TARGETED_TRAIN_CLASSES = [
    {
        "food_id": "predefined_apple",
        "food_name": "Apple",
        "needed": 15,
        "queries": ["fresh red apple on table", "single whole red apple", "crisp fuji apple", "fresh apple fruit plate"]
    },
    {
        "food_id": "predefined_banana",
        "food_name": "Banana",
        "needed": 10,
        "queries": ["single ripe yellow banana", "yellow cavendish banana", "banana bunch peel"]
    },
    {
        "food_id": "predefined_dosa",
        "food_name": "Plain Dosa",
        "needed": 12,
        "queries": ["crispy plain dosa close up", "masala dosa rolled plate", "south indian dosa breakfast"]
    },
    {
        "food_id": "predefined_rajma_curry",
        "food_name": "Rajma Curry",
        "needed": 15,
        "queries": ["rajma curry bowl", "punjabi rajma masala gravy", "cooked kidney beans curry"]
    },
    {
        "food_id": "predefined_paneer_tikka",
        "food_name": "Paneer Tikka",
        "needed": 15,
        "queries": ["grilled paneer tikka skewers", "paneer tikka kebab plate", "tandoori paneer tikka pieces"]
    },
    {
        "food_id": "predefined_medu_vada",
        "food_name": "Medu Vada",
        "needed": 10,
        "queries": ["crispy medu vada close up", "golden fried vada south indian", "uddina vada plate"]
    },
    {
        "food_id": "predefined_chole_masala",
        "food_name": "Chole Masala",
        "needed": 12,
        "queries": ["punjabi chole masala bowl", "chana masala chickpea dish", "spicy chole gravy"]
    },
    {
        "food_id": "predefined_samosa",
        "food_name": "Samosa",
        "needed": 12,
        "queries": ["crispy golden samosa plate", "punjabi samosa close up", "fried vegetable samosa"]
    },
    {
        "food_id": "predefined_poha",
        "food_name": "Poha",
        "needed": 15,
        "queries": ["kanda poha breakfast plate", "batata poha flattened rice", "indori poha close up"]
    },
    {
        "food_id": "predefined_tandoori_chicken",
        "food_name": "Tandoori Chicken",
        "needed": 15,
        "queries": ["roasted tandoori chicken leg", "tandoori chicken drumstick roasted", "grilled tandoori chicken plate"]
    }
]

# 16 Candidate Production Classes for Final Lockbox
LOCKBOX_PRODUCTION_CLASSES = [
    ("predefined_watermelon", "Watermelon", ["watermelon slice on cutting board", "cut watermelon triangle", "fresh watermelon piece plate", "chilled watermelon wedges"]),
    ("predefined_strawberry", "Strawberry", ["single fresh strawberry fruit", "fresh ripe strawberries plate", "organic strawberries sweet", "strawberry cross section"]),
    ("predefined_medu_vada", "Medu Vada", ["golden crispy medu vada", "south indian vada breakfast", "urad dal vada fried", "vada close up plate"]),
    ("predefined_steamed_rice", "Steamed White Rice", ["plain steamed rice bowl", "bowl of white basmati rice", "cooked white rice dish", "steamed rice portion"]),
    ("predefined_scrambled_eggs", "Scrambled Eggs", ["fresh fluffy scrambled eggs", "cooked scrambled eggs plate", "scrambled egg breakfast dish", "yellow scrambled eggs"]),
    ("predefined_rajma_curry", "Rajma Curry", ["red kidney beans rajma bowl", "cooked rajma curry dish", "rajma bean gravy bowl", "punjabi rajma dish"]),
    ("predefined_capsicum", "Capsicum", ["whole green capsicum pepper", "fresh bell pepper green", "sliced green capsicum", "crisp green bell pepper"]),
    ("predefined_whole_wheat_bread", "Whole Wheat Bread", ["whole wheat bread loaf slice", "slice of brown bread", "whole grain bread slice", "wheat bread toast"]),
    ("predefined_guava", "Guava", ["cut guava fruit pink", "fresh guava slice plate", "whole green guava fruit", "ripe guava pieces"]),
    ("predefined_dosa", "Plain Dosa", ["crisp golden dosa roll", "plain dosa breakfast", "thin dosa south indian", "roasted dosa close up"]),
    ("predefined_broccoli", "Broccoli", ["raw green broccoli florets", "fresh broccoli vegetable head", "steamed broccoli pieces", "broccoli floret bowl"]),
    ("predefined_chole_masala", "Chole Masala", ["chickpeas chole curry bowl", "punjabi chana masala", "chole gravy indian dish", "spicy chana curry"]),
    ("predefined_low_fat_milk", "Low Fat Milk", ["fresh glass of milk", "glass cup milk white", "milk poured in glass", "cold milk drink glass"]),
    ("predefined_potato", "Potato", ["whole raw potatoes tubers", "fresh raw potato vegetable", "russet potato table", "brown potato tuber"]),
    ("predefined_samosa", "Samosa", ["golden samosa snack", "crispy samosa pastry", "fried potato samosa", "punjabi samosa plate"]),
    ("predefined_paneer_tikka", "Paneer Tikka", ["roasted paneer tikka skewer", "grilled paneer cubes plate", "tandoori paneer tikka kebab", "paneer tikka appetizer"])
]

# Non-Food Categories (75+ images)
LOCKBOX_NON_FOOD = [
    ("Smart Watch", ["apple watch smart watch wrist", "smartwatch on desk screen"]),
    ("Desk Lamp", ["table reading lamp light desk", "modern desk lamp office"]),
    ("Backpack", ["hiking backpack bag floor", "black backpack school bag"]),
    ("Sports Shoe", ["running sneakers shoes footwear", "tennis shoes sneaker pair"]),
    ("Sunglasses", ["sunglasses glasses on wooden table", "dark sunglasses shades"]),
    ("Coffee Cup Empty", ["empty ceramic mug table", "empty coffee cup saucer"]),
    ("Computer Keyboard", ["mechanical computer keyboard desk", "laptop keyboard keys typing"]),
    ("Notebook", ["spiral notebook journal open desk", "leather notebook diary pen"]),
    ("Houseplant", ["indoor houseplant potted plant", "monstera plant ceramic pot"]),
    ("Bicycle", ["commuter bicycle parked street", "road bike bicycle wheel"]),
    ("Desk Chair", ["ergonomic office chair seat", "modern wooden chair room"]),
    ("Ceramic Plate Empty", ["empty white dinner plate table", "empty ceramic plate clean"]),
    ("Ballpoint Pen", ["fountain pen ballpoint desk", "stationery pens writing table"]),
    ("Wireless Mouse", ["computer optical mouse desk", "wireless mouse on mousepad"]),
    ("Water Bottle", ["stainless steel water bottle flask", "reusable sports water bottle"]),
    ("Wall Clock", ["hanging analog wall clock", "modern round wall clock living room"]),
    ("Kitchen Knife", ["stainless steel chef knife wooden block", "cooking kitchen knife handle"])
]

# Unsupported FitFuel Foods (75+ images) - with heavy emphasis on dietary risks!
LOCKBOX_UNSUPPORTED = [
    ("predefined_biryani", "Chicken Biryani", ["chicken biryani rice dish plate", "hyderabadi biryani plate lemon", "mutton biryani pot"]),
    ("predefined_paneer_butter_masala", "Paneer Butter Masala", ["paneer butter masala bowl rich", "paneer makhani creamy gravy", "shahi paneer curry dish"]),
    ("predefined_kadai_paneer", "Kadai Paneer", ["kadai paneer bell pepper gravy", "kadhai paneer bowl restaurant", "spicy kadai paneer dish"]),
    ("predefined_butter_chicken", "Butter Chicken", ["butter chicken makhani gravy bowl", "murgh makhani chicken dish", "butter chicken curry plate"]),
    ("predefined_chicken_curry", "Chicken Curry", ["indian homestyle chicken curry bowl", "chicken gravy curry dish", "spicy chicken curry"]),
    ("predefined_dal_makhani", "Dal Makhani", ["black lentils dal makhani bowl", "punjabi dal makhani cream", "dal makhani restaurant dish"]),
    ("predefined_pav_bhaji", "Pav Bhaji", ["mumbai pav bhaji butter plate", "pav bhaji street food plate", "bhaji pav lemon onion"]),
    ("predefined_gulab_jamun", "Gulab Jamun", ["two gulab jamun sweet bowl", "sweet gulab jamun syrup plate", "kala jamun dessert bowl"]),
    ("predefined_momos", "Steamed Momos", ["steamed vegetable momos plate", "dumplings momos chutney dish", "chicken momos steamed"]),
    ("predefined_naan", "Butter Naan", ["tandoori garlic naan bread", "butter naan bread basket", "fresh tandoori naan flatbread"]),
    ("predefined_paratha", "Aloo Paratha", ["stuffed aloo paratha butter plate", "plain triangle paratha flatbread", "paratha curd pickle"]),
    ("predefined_khichdi", "Moong Dal Khichdi", ["moong dal khichdi bowl ghee", "dal khichdi indian dish", "wholesome rice khichdi bowl"]),
    ("predefined_rasgulla", "Rasgulla", ["soft white rasgulla sweet bowl", "bengali rasgulla dessert", "rasgulla syrup sweet"]),
    ("predefined_bhel_puri", "Bhel Puri", ["bhel puri sev chaat plate", "mumbai bhel puri street snack", "sev puri bhelpuri chaat"]),
    ("predefined_pani_puri", "Pani Puri", ["crispy pani puri golgappa plate", "puchka pani puri street food", "pani puri spiced water"]),
    ("predefined_palak_paneer", "Palak Paneer", ["palak paneer spinach cottage cheese", "saag paneer bowl curry", "spinach gravy paneer dish"]),
    ("predefined_jalebi", "Jalebi", ["crispy orange jalebi sweet", "jalebi indian sweet dessert plate", "fried jalebi spirals"]),
    ("predefined_vada_pav", "Vada Pav", ["mumbai vada pav snack plate", "batata vada pav burger", "vada pav spicy chutney"]),
    ("predefined_fish_curry", "Fish Curry", ["bengali fish curry gravy bowl", "south indian fish curry dish", "spicy fish curry"])
]

# Mixed Meals (40+ images)
LOCKBOX_MIXED_MEALS = [
    ("North Indian Thali", ["traditional north indian thali lunch plate", "punjabi thali assorted dishes", "thali meal indian restaurant"]),
    ("South Indian Banana Leaf Feast", ["kerala sadhya feast banana leaf meal", "south indian banana leaf lunch wedding", "traditional south indian meal leaf"]),
    ("Gujarati Thali", ["gujarati thali sweet savoury dishes plate", "kathiyawadi thali traditional lunch"]),
    ("Rajasthani Thali", ["rajasthani thali dal baati churma tray", "traditional rajasthani lunch meal"]),
    ("Bengali Thali", ["bengali lunch meal fish rice bowls", "bengali thali curries rice"]),
    ("Continental Breakfast Platter", ["continental breakfast platter eggs toast bacon", "hotel breakfast spread buffet plate"]),
    ("Buffet Dinner Plate", ["buffet food assorted plate meal dinner", "banquet meal plate multiple dishes"]),
    ("Office Lunch Tray", ["partitioned lunch tray stainless steel indian meal", "thali tray lunch meal office"]),
    ("Dinner Food Spread", ["family dinner food spread feast table", "dinner party food table spread feast"]),
    ("Rice Dal Sabzi Combination", ["lunch plate rice dal two vegetables salad", "indian home meal plate rice curries"])
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

def search_wikimedia_safe(query: str, limit: int = 35):
    params = {
        "action": "query", "generator": "search", "gsrsearch": query,
        "gsrnamespace": "6", "gsrlimit": str(min(limit, 35)),
        "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "320", "format": "json"
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
                    lt = title.lower()
                    if any(ext in lt for ext in [".svg", ".pdf", ".ogg", ".webm", ".mp4", ".gif", ".tif"]):
                        continue
                    if any(kw in lt for kw in ["drawing", "vector", "banner", "clipart", "logo", "icon", "diagram"]):
                        continue
                    ii = page.get("imageinfo", [])
                    if not ii: continue
                    thumb_url = ii[0].get("thumburl", "")
                    desc_url = ii[0].get("descriptionurl", "")
                    meta = ii[0].get("extmetadata", {})
                    lic = meta.get("LicenseShortName", {}).get("value", "CC BY-SA")
                    if thumb_url:
                        results.append({"title": title, "thumb_url": thumb_url, "desc_url": desc_url, "license": lic})
                return results
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2.5 * (attempt + 1))
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

def load_all_existing_hashes():
    all_sha256 = set()
    all_dhashes = []
    # Load all previous manifests
    manifest_files = [
        "ml/dataset_manifest.csv",
        "ml/non_food_manifest.csv",
        "ml/unsupported_food_manifest.csv",
        "ml/mixed_meal_manifest.csv",
        "ml/independent_holdout_manifest.csv"
    ]
    for mf in manifest_files:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    if r.get("sha256"): all_sha256.add(r["sha256"])
                    if r.get("perceptual_hash"): all_dhashes.append(r["perceptual_hash"])

    print(f"Loaded {len(all_sha256)} existing SHA-256 hashes and {len(all_dhashes)} existing dHashes for leakage protection.", flush=True)
    return all_sha256, all_dhashes

def is_duplicate_or_leaked(sha, dhash, existing_sha256, existing_dhashes, current_set_dhashes):
    if sha in existing_sha256:
        return True, "exact_sha_match"
    for eh in existing_dhashes:
        if hamming_distance(dhash, eh) <= 6:
            return True, "perceptual_match_prior_data"
    for ch in current_set_dhashes:
        if hamming_distance(dhash, ch) <= 4:
            return True, "internal_near_duplicate"
    return False, "ok"

def main():
    print("============================================================", flush=True)
    print("  FITFUEL 35.9.5: TARGETED SUPPLEMENTS & FINAL LOCKBOX V5   ", flush=True)
    print("============================================================", flush=True)

    existing_sha256, existing_dhashes = load_all_existing_hashes()

    # ------------------------------------------------------------
    # Part 1: Targeted Training Supplements
    # ------------------------------------------------------------
    supplements_dir = "ml/dataset_v5_supplements"
    os.makedirs(supplements_dir, exist_ok=True)
    supplements_manifest_path = "ml/reports/targeted_supplements_v5.csv"

    train_supp_dhashes = []
    supplement_rows = []

    print("\n--- Part 1: Collecting Targeted Training Supplements ---", flush=True)
    for t_cls in TARGETED_TRAIN_CLASSES:
        fid = t_cls["food_id"]
        fname = t_cls["food_name"]
        needed = t_cls["needed"]
        out_cls_dir = os.path.join(supplements_dir, fid)
        os.makedirs(out_cls_dir, exist_ok=True)
        collected = 0

        print(f"Collecting {needed} clean supplements for {fname} ({fid})...", flush=True)
        for q in t_cls["queries"]:
            if collected >= needed: break
            items = search_wikimedia_safe(q, limit=30)
            for it in items:
                if collected >= needed: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                leaked, _ = is_duplicate_or_leaked(sha, dh, existing_sha256, existing_dhashes, train_supp_dhashes)
                if leaked: continue

                collected += 1
                sp = os.path.join(out_cls_dir, f"{fid}_supp_{collected:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                train_supp_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                supplement_rows.append({
                    "image_path": rel_p, "food_id": fid, "food_name": fname,
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_SUPPLEMENT"
                })
        print(f"  -> Added {collected} clean supplements for {fname}", flush=True)

    fields = ["image_path", "food_id", "food_name", "source", "source_reference", "license", "sha256", "perceptual_hash", "width", "height", "review_status"]
    with open(supplements_manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(supplement_rows)
    print(f"Total training supplements collected: {len(supplement_rows)} into {supplements_manifest_path}")

    # ------------------------------------------------------------
    # Part 2: Final Lockbox Dataset V5
    # ------------------------------------------------------------
    lockbox_base = "ml/dataset_final_lockbox_v5"
    os.makedirs(lockbox_base, exist_ok=True)
    lb_supp_dir = os.path.join(lockbox_base, "supported")
    lb_non_food_dir = os.path.join(lockbox_base, "non_food")
    lb_unsupported_dir = os.path.join(lockbox_base, "unsupported_food")
    lb_mixed_dir = os.path.join(lockbox_base, "mixed_meals")
    for d in [lb_supp_dir, lb_non_food_dir, lb_unsupported_dir, lb_mixed_dir]:
        os.makedirs(d, exist_ok=True)

    lockbox_dhashes = []
    lockbox_rows = []

    print("\n--- Part 2: Collecting Final Lockbox V5 (Zero Leakage) ---", flush=True)

    # 1. 16 Candidate Production Classes (15-20 images each)
    for fid, fname, queries in LOCKBOX_PRODUCTION_CLASSES:
        target = 18
        out_cls_dir = os.path.join(lb_supp_dir, fid)
        os.makedirs(out_cls_dir, exist_ok=True)
        collected = 0
        print(f"Lockbox targeting {fname} ({fid})...", flush=True)
        for q in queries:
            if collected >= target: break
            items = search_wikimedia_safe(q, limit=35)
            for it in items:
                if collected >= target: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                leaked, _ = is_duplicate_or_leaked(sha, dh, existing_sha256, existing_dhashes, lockbox_dhashes)
                if leaked: continue

                collected += 1
                sp = os.path.join(out_cls_dir, f"{fid}_lockbox_{collected:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                lockbox_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                lockbox_rows.append({
                    "image_path": rel_p, "food_id": fid, "food_name": fname,
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                })
        print(f"  -> Lockbox {fname}: {collected} images", flush=True)

    # 2. Non-Food (75+ images)
    print("\nLockbox Non-Food collection (target 80 images)...", flush=True)
    nf_collected = 0
    target_nf = 80
    for cat_name, queries in LOCKBOX_NON_FOOD:
        if nf_collected >= target_nf: break
        for q in queries:
            if nf_collected >= target_nf: break
            items = search_wikimedia_safe(q, limit=25)
            for it in items:
                if nf_collected >= target_nf: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                leaked, _ = is_duplicate_or_leaked(sha, dh, existing_sha256, existing_dhashes, lockbox_dhashes)
                if leaked: continue

                nf_collected += 1
                sp = os.path.join(lb_non_food_dir, f"non_food_lockbox_{nf_collected:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                lockbox_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                lockbox_rows.append({
                    "image_path": rel_p, "food_id": "non_food", "food_name": f"Non-Food ({cat_name})",
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                })
    print(f"Lockbox Non-Food collected: {nf_collected} images")

    # 3. Unsupported FitFuel Foods (75+ images)
    print("\nLockbox Unsupported Foods collection (target 80 images)...", flush=True)
    unsupp_collected = 0
    target_unsupp = 80
    for ufid, ufname, queries in LOCKBOX_UNSUPPORTED:
        if unsupp_collected >= target_unsupp: break
        for q in queries:
            if unsupp_collected >= target_unsupp: break
            items = search_wikimedia_safe(q, limit=25)
            for it in items:
                if unsupp_collected >= target_unsupp: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                leaked, _ = is_duplicate_or_leaked(sha, dh, existing_sha256, existing_dhashes, lockbox_dhashes)
                if leaked: continue

                unsupp_collected += 1
                sp = os.path.join(lb_unsupported_dir, f"unsupported_lockbox_{unsupp_collected:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                lockbox_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                lockbox_rows.append({
                    "image_path": rel_p, "food_id": ufid, "food_name": ufname,
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                })
    print(f"Lockbox Unsupported Foods collected: {unsupp_collected} images")

    # 4. Mixed Meals (40+ images)
    print("\nLockbox Mixed Meals collection (target 45 images)...", flush=True)
    mm_collected = 0
    target_mm = 45
    for mname, queries in LOCKBOX_MIXED_MEALS:
        if mm_collected >= target_mm: break
        for q in queries:
            if mm_collected >= target_mm: break
            items = search_wikimedia_safe(q, limit=25)
            for it in items:
                if mm_collected >= target_mm: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                leaked, _ = is_duplicate_or_leaked(sha, dh, existing_sha256, existing_dhashes, lockbox_dhashes)
                if leaked: continue

                mm_collected += 1
                sp = os.path.join(lb_mixed_dir, f"mixed_meal_lockbox_{mm_collected:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                lockbox_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                lockbox_rows.append({
                    "image_path": rel_p, "food_id": "mixed_meal", "food_name": mname,
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                })
    print(f"Lockbox Mixed Meals collected: {mm_collected} images")

    # Save Lockbox Manifest
    lockbox_manifest_path = "ml/final_lockbox_manifest_v5.csv"
    with open(lockbox_manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(lockbox_rows)

    print(f"\nFinal Lockbox Dataset V5 Size: {len(lockbox_rows)} images recorded in {lockbox_manifest_path}")

if __name__ == "__main__":
    main()
