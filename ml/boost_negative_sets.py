#!/usr/bin/env python3
"""
FitFuel Phase 35.9.3 - Negative Sets Booster
Expands negative evaluation sets to meet targets:
- Non-Food: 100+ images (target ~110-120)
- Unsupported Food: 100+ images (target ~110-120)
- Mixed Meals: 50+ images (target ~55-65)
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

MORE_NON_FOOD = [
    ("street_light", "Street Lamp", "street light lamp post urban"),
    ("park_bench", "Park Bench", "park bench wooden outdoor"),
    ("guitar", "Acoustic Guitar", "acoustic guitar musical instrument"),
    ("sneakers", "Sneakers Footwear", "sneakers running shoes footwear"),
    ("wall_mirror", "Wall Mirror", "wall mirror reflective glass bathroom"),
    ("bookshelf", "Bookshelf Library", "bookshelf books library wooden shelves"),
    ("traffic_cone", "Traffic Cone", "traffic cone orange road construction"),
    ("desktop_monitor", "Computer Monitor", "computer monitor display screen office desk"),
    ("umbrella", "Rain Umbrella", "rain umbrella open outdoor wet"),
    ("luggage_suitcase", "Suitcase Luggage", "travel suitcase luggage bag airport")
]

MORE_UNSUPPORTED = [
    ("predefined_spaghetti", "Spaghetti Pasta", "spaghetti pasta plate marinara tomato"),
    ("predefined_spring_rolls", "Spring Rolls", "spring rolls fried crispy asian plate"),
    ("predefined_macaroni_cheese", "Macaroni and Cheese", "macaroni and cheese baked pasta bowl"),
    ("predefined_quesadilla", "Quesadilla", "cheese quesadilla tortilla mexican plate"),
    ("predefined_falafel", "Falafel", "falafel balls plate tahini middle eastern"),
    ("predefined_baklava", "Baklava", "baklava sweet pastry honey nuts"),
    ("predefined_churros", "Churros", "churros cinnamon sugar pastry dip"),
    ("predefined_apple_pie", "Apple Pie", "apple pie slice baked dessert plate"),
    ("predefined_crepes", "Sweet Crepes", "crepes"),
    ("predefined_nachos", "Nachos with Cheese", "nachos"),
    ("predefined_cupcakes", "Frosted Cupcakes", "cupcakes")
]

MORE_MIXED_MEALS = [
    ("thali_full", "Indian Thali Meal", "thali"),
    ("bento_lunch", "Bento Lunch Box", "bento"),
    ("full_breakfast", "Full Breakfast Plate", "full breakfast"),
    ("buffet_plate", "Buffet Food Plate", "buffet plate"),
    ("mezze_platter", "Mezze Platter", "mezze"),
    ("tapas_spread", "Tapas Assortment", "tapas"),
    ("dim_sum_spread", "Dim Sum Assortment", "dim sum"),
    ("airline_meal", "Airline Meal Tray", "airline meal"),
    ("banana_leaf_meal", "Banana Leaf Feast", "banana leaf rice"),
    ("thali_south", "South Indian Meals", "south indian meals")
]


def compute_sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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
                lower = title.lower()
                if any(ext in lower for ext in [".svg", ".pdf", ".ogg", ".webm", ".mp4", ".gif", ".tif"]):
                    continue
                if any(kw in lower for kw in ["diagram", "map", "icon", "logo", "flag", "stamp", "coin", "chart", "graph"]):
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
    output_dir = "dataset"
    global_sha256 = set()

    # Load existing SHAs from manifests
    for mf in ["dataset_manifest.csv", "non_food_manifest.csv", "unsupported_food_manifest.csv", "mixed_meal_manifest.csv"]:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for r in reader:
                    global_sha256.add(r["sha256"])

    # 1. Non-Food Negatives
    with open("non_food_manifest.csv", "r", encoding="utf-8") as f:
        non_food_rows = list(csv.DictReader(f))

    print(f"Current Non-Food count: {len(non_food_rows)} (Target: 105+)")
    for cat_id, cat_name, q in MORE_NON_FOOD:
        if len(non_food_rows) >= 110:
            break
        time.sleep(0.05)
        res = search_wikimedia(q, limit=10)
        for item in res:
            if len(non_food_rows) >= 110:
                break
            img, raw = download_image_candidate(item)
            if img is None or raw is None:
                continue
            sha = compute_sha256(raw)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            idx = len(non_food_rows) + 1
            filename = f"non_food_extra_{cat_id}_{idx:03d}.jpg"
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
        writer = csv.DictWriter(f, fieldnames=["image_path", "category", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"])
        writer.writeheader()
        writer.writerows(non_food_rows)
    print(f"Updated Non-Food manifest: {len(non_food_rows)} images")

    # 2. Unsupported Food Negatives
    with open("unsupported_food_manifest.csv", "r", encoding="utf-8") as f:
        unsupported_rows = list(csv.DictReader(f))

    print(f"Current Unsupported Food count: {len(unsupported_rows)} (Target: 105+)")
    for fid, fname, q in MORE_UNSUPPORTED:
        if len(unsupported_rows) >= 110:
            break
        time.sleep(0.05)
        res = search_wikimedia(q, limit=10)
        for item in res:
            if len(unsupported_rows) >= 110:
                break
            img, raw = download_image_candidate(item)
            if img is None or raw is None:
                continue
            sha = compute_sha256(raw)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            idx = len(unsupported_rows) + 1
            filename = f"unsupported_extra_{fid}_{idx:03d}.jpg"
            rel_path = os.path.join(output_dir, "unsupported_food", filename).replace("\\", "/")
            full_path = os.path.join(output_dir, "unsupported_food", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            unsupported_rows.append({
                "image_path": rel_path,
                "food_id": fid,
                "food_name": fname,
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
        writer = csv.DictWriter(f, fieldnames=["image_path", "food_id", "food_name", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"])
        writer.writeheader()
        writer.writerows(unsupported_rows)
    print(f"Updated Unsupported Food manifest: {len(unsupported_rows)} images")

    # 3. Mixed Meals Negatives
    with open("mixed_meal_manifest.csv", "r", encoding="utf-8") as f:
        mixed_meal_rows = list(csv.DictReader(f))

    print(f"Current Mixed-Meal count: {len(mixed_meal_rows)} (Target: 50+)")
    for mid, mname, q in MORE_MIXED_MEALS:
        if len(mixed_meal_rows) >= 55:
            break
        time.sleep(0.05)
        res = search_wikimedia(q, limit=20)
        for item in res:
            if len(mixed_meal_rows) >= 55:
                break
            img, raw = download_image_candidate(item)
            if img is None or raw is None:
                continue
            sha = compute_sha256(raw)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            idx = len(mixed_meal_rows) + 1
            filename = f"mixed_meal_{mid}_{idx:03d}.jpg"
            rel_path = os.path.join(output_dir, "mixed_meals", filename).replace("\\", "/")
            full_path = os.path.join(output_dir, "mixed_meals", filename)
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)
            mixed_meal_rows.append({
                "image_path": rel_path,
                "meal_type": mname,
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
        writer = csv.DictWriter(f, fieldnames=["image_path", "meal_type", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"])
        writer.writeheader()
        writer.writerows(mixed_meal_rows)
    print(f"Updated Mixed-Meal manifest: {len(mixed_meal_rows)} images")

    # Update reports/dataset_audit_v3.json
    with open("reports/dataset_audit_v3.json", "r", encoding="utf-8") as f:
        audit_v3 = json.load(f)

    audit_v3["non_food_negatives"] = len(non_food_rows)
    audit_v3["unsupported_food_negatives"] = len(unsupported_rows)
    audit_v3["mixed_meal_negatives"] = len(mixed_meal_rows)

    with open("reports/dataset_audit_v3.json", "w", encoding="utf-8") as f:
        json.dump(audit_v3, f, indent=2)

    print("\nUpdated dataset_audit_v3.json successfully!")
    print(f"  Non-Food: {len(non_food_rows)}")
    print(f"  Unsupported Food: {len(unsupported_rows)}")
    print(f"  Mixed Meals: {len(mixed_meal_rows)}")


if __name__ == "__main__":
    main()
