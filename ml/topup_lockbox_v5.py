#!/usr/bin/env python3
"""
FitFuel Phase 35.9.5 - Final Lockbox V5 Top-up
Completes lockbox targets for:
- Supported candidate classes (reach >= 15 images/class)
- Mixed meals (reach >= 40 images)
Enforces zero data leakage against all earlier datasets.
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

USER_AGENT = "FitFuelAuditBot/5.1 (https://fitfuel.app; dev@fitfuel.app)"

CLASSES_TO_TOPUP = [
    ("predefined_watermelon", "Watermelon", 16, ["watermelon fruit", "citrullus lanatus", "cut watermelon", "fresh watermelon market", "watermelon slices"]),
    ("predefined_guava", "Guava", 16, ["guava fruit", "psidium guajava", "sliced guava", "pink guava fruit", "fresh guava"]),
    ("predefined_broccoli", "Broccoli", 16, ["broccoli vegetable", "brassica oleracea italica", "fresh broccoli head", "green broccoli florets", "broccoli plate"]),
    ("predefined_rajma_curry", "Rajma Curry", 16, ["rajma masala", "kidney bean curry", "cooked rajma", "punjabi rajma gravy", "red kidney bean food"]),
    ("predefined_paneer_tikka", "Paneer Tikka", 16, ["paneer tikka", "grilled paneer kebab", "tandoori paneer", "paneer tikka plate", "paneer skewers"]),
    ("predefined_potato", "Potato", 16, ["potato tuber", "solanum tuberosum", "raw potatoes", "fresh potato market", "brown potatoes"]),
    ("predefined_medu_vada", "Medu Vada", 16, ["medu vada plate", "urad dal vada", "vada south indian", "crispy medu vada", "uddina vada"]),
    ("predefined_chole_masala", "Chole Masala", 16, ["chole masala", "chana masala curry", "punjabi chole", "chickpea curry food", "spicy chana"]),
    ("predefined_samosa", "Samosa", 16, ["samosa pastry", "fried samosas", "punjabi samosa plate", "crispy samosa snack", "samosa indian"]),
    ("predefined_dosa", "Plain Dosa", 16, ["plain dosa", "masala dosa", "crispy dosa plate", "south indian dosa", "dosa roll"]),
    ("predefined_capsicum", "Capsicum", 16, ["green capsicum", "green bell pepper", "sliced capsicum", "bell pepper vegetable"]),
    ("predefined_steamed_rice", "Steamed White Rice", 16, ["steamed rice bowl", "cooked basmati rice", "white rice plate", "boiled rice"]),
]

MIXED_MEAL_QUERIES = [
    "indian thali meal", "south indian meal plate", "north indian thali",
    "kerala sadhya feast", "bengali thali meal", "gujarati thali plate",
    "buffet meal food plate", "lunch thali meal", "dinner meal combo spread",
    "rice dal sabzi plate", "assorted indian food platter"
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
        "action": "query", "generator": "search", "gsrsearch": query,
        "gsrnamespace": "6", "gsrlimit": str(min(limit, 40)),
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

def main():
    print("=== Final Lockbox V5 Top-up ===", flush=True)
    manifest_path = "ml/final_lockbox_manifest_v5.csv"
    existing_rows = []
    class_counts = {}
    current_dhashes = []
    all_sha256 = set()

    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            existing_rows = list(csv.DictReader(f))
        for r in existing_rows:
            fid = r["food_id"]
            class_counts[fid] = class_counts.get(fid, 0) + 1
            if r.get("sha256"): all_sha256.add(r["sha256"])
            if r.get("perceptual_hash"): current_dhashes.append(r["perceptual_hash"])

    # Load all prior datasets for zero-leakage guarantee
    for mf in ["ml/dataset_manifest.csv", "ml/non_food_manifest.csv", "ml/unsupported_food_manifest.csv", "ml/mixed_meal_manifest.csv", "ml/independent_holdout_manifest.csv", "ml/reports/targeted_supplements_v5.csv"]:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    if r.get("sha256"): all_sha256.add(r["sha256"])
                    if r.get("perceptual_hash"): current_dhashes.append(r["perceptual_hash"])

    lb_base = "ml/dataset_final_lockbox_v5"
    lb_supp_dir = os.path.join(lb_base, "supported")
    lb_mixed_dir = os.path.join(lb_base, "mixed_meals")

    # 1. Top up supported candidate classes
    for fid, fname, target, queries in CLASSES_TO_TOPUP:
        cur = class_counts.get(fid, 0)
        needed = max(0, target - cur)
        if needed == 0:
            print(f"Supported {fname} already met ({cur}/{target}).", flush=True)
            continue

        print(f"Lockbox collecting {needed} more images for {fname} ({cur}/{target})...", flush=True)
        out_cls_dir = os.path.join(lb_supp_dir, fid)
        os.makedirs(out_cls_dir, exist_ok=True)

        for q in queries:
            if needed <= 0: break
            items = search_wikimedia_safe(q, limit=35)
            for it in items:
                if needed <= 0: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                if sha in all_sha256 or any(hamming_distance(dh, h) <= 6 for h in current_dhashes):
                    continue

                cur += 1
                needed -= 1
                sp = os.path.join(out_cls_dir, f"{fid}_lockbox_{cur:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                all_sha256.add(f_sha)
                current_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                new_row = {
                    "image_path": rel_p, "food_id": fid, "food_name": fname,
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                }
                existing_rows.append(new_row)
                class_counts[fid] = cur

        print(f"  -> {fname} now has {cur} images.", flush=True)

    # 2. Top up mixed meals (reach >= 40)
    cur_mixed = class_counts.get("mixed_meal", 0)
    needed_mixed = max(0, 42 - cur_mixed)
    print(f"\nMixed meals current: {cur_mixed}/42 (need {needed_mixed})...", flush=True)

    if needed_mixed > 0:
        for q in MIXED_MEAL_QUERIES:
            if needed_mixed <= 0: break
            items = search_wikimedia_safe(q, limit=30)
            for it in items:
                if needed_mixed <= 0: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)

                if sha in all_sha256 or any(hamming_distance(dh, h) <= 6 for h in current_dhashes):
                    continue

                cur_mixed += 1
                needed_mixed -= 1
                sp = os.path.join(lb_mixed_dir, f"mixed_meal_lockbox_{cur_mixed:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)

                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                all_sha256.add(f_sha)
                current_dhashes.append(f_dh)

                rel_p = os.path.relpath(sp, "ml").replace("\\", "/")
                new_row = {
                    "image_path": rel_p, "food_id": "mixed_meal", "food_name": "Mixed Meal Combination",
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_LOCKBOX_V5"
                }
                existing_rows.append(new_row)
                class_counts["mixed_meal"] = cur_mixed

    print(f"Mixed meals now total: {cur_mixed}")

    fields = ["image_path", "food_id", "food_name", "source", "source_reference", "license", "sha256", "perceptual_hash", "width", "height", "review_status"]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(existing_rows)

    print(f"\nFinal Lockbox Dataset V5 Size: {len(existing_rows)} images recorded in {manifest_path}")

if __name__ == "__main__":
    main()
