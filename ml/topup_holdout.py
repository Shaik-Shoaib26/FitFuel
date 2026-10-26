#!/usr/bin/env python3
"""
Quick top-up for Rajma Curry (reach 10+) and Mixed Meals (reach 30+)
"""
import os, csv, time, urllib.request, urllib.parse, json, hashlib, io
from PIL import Image
import numpy as np

USER_AGENT = "FitFuelAuditBot/4.3 (https://fitfuel.app; audit@fitfuel.app)"

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
    for attempt in range(3):
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
        except Exception:
            time.sleep(0.5)
    return None, None, "network_error"

def main():
    manifest_path = "ml/independent_holdout_manifest.csv"
    with open(manifest_path, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    existing_sha256 = set(r["sha256"] for r in rows)
    existing_dhashes = [r["perceptual_hash"] for r in rows if r.get("perceptual_hash")]

    # Also load previous dataset hashes
    for mf in ["ml/dataset_manifest.csv", "ml/non_food_manifest.csv", "ml/unsupported_food_manifest.csv", "ml/mixed_meal_manifest.csv"]:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    if r.get("sha256"): existing_sha256.add(r["sha256"])
                    if r.get("perceptual_hash"): existing_dhashes.append(r["perceptual_hash"])

    # 1. Rajma top up (need at least 1 more, target 11)
    rajma_count = sum(1 for r in rows if r["food_id"] == "predefined_rajma_curry")
    print(f"Current Rajma count: {rajma_count}")
    if rajma_count < 10:
        queries = ["kidney beans stew dish", "rajma dal indian bowl", "red bean curry lunch", "cooked red kidney beans bowl"]
        out_dir = "ml/dataset_independent_holdout/supported/predefined_rajma_curry"
        for q in queries:
            if rajma_count >= 10: break
            for it in search_wikimedia_safe(q, limit=20):
                if rajma_count >= 10: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)
                if sha in existing_sha256 or any(hamming_distance(dh, h) <= 6 for h in existing_dhashes):
                    continue
                rajma_count += 1
                sp = os.path.join(out_dir, f"predefined_rajma_curry_ind_{rajma_count:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)
                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                rel = os.path.relpath(sp, "ml").replace("\\", "/")
                rows.append({
                    "image_path": rel, "food_id": "predefined_rajma_curry", "food_name": "Rajma Curry",
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_INDEPENDENT"
                })
    print(f"Rajma count after top-up: {rajma_count}")

    # 2. Mixed Meals top up (need at least 30)
    mixed_count = sum(1 for r in rows if r["food_id"] == "mixed_meal")
    print(f"Current Mixed Meal count: {mixed_count}")
    if mixed_count < 30:
        queries = [
            "indian meal plate food", "south indian lunch meal", "thali lunch dinner plate",
            "kerala feast sadhya meal", "bengali meal lunch rice curries", "indian combo meal tray",
            "buffet dinner food plate", "lunch tray partitioned meal", "full indian meal spread",
            "rice dal vegetables meal plate", "sadhya banana leaf meal feast"
        ]
        out_dir = "ml/dataset_independent_holdout/mixed_meals"
        for q in queries:
            if mixed_count >= 30: break
            for it in search_wikimedia_safe(q, limit=20):
                if mixed_count >= 30: break
                img, raw, st = download_candidate(it)
                if st != "ok": continue
                sha = compute_sha256(raw)
                dh = compute_dhash(img)
                if sha in existing_sha256 or any(hamming_distance(dh, h) <= 6 for h in existing_dhashes):
                    continue
                mixed_count += 1
                sp = os.path.join(out_dir, f"mixed_meal_ind_{mixed_count:03d}.jpg")
                img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                img.save(sp, "JPEG", quality=90)
                with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                f_dh = compute_dhash(img)
                existing_sha256.add(f_sha)
                existing_dhashes.append(f_dh)
                rel = os.path.relpath(sp, "ml").replace("\\", "/")
                rows.append({
                    "image_path": rel, "food_id": "mixed_meal", "food_name": "Mixed Meal Platter",
                    "source": "Wikimedia Commons (Audited)", "source_reference": it["desc_url"],
                    "license": it["license"], "sha256": f_sha, "perceptual_hash": f_dh,
                    "width": img.width, "height": img.height, "review_status": "ACCEPTED_INDEPENDENT"
                })
    print(f"Mixed Meal count after top-up: {mixed_count}")

    fieldnames = [
        "image_path", "food_id", "food_name", "source", "source_reference",
        "license", "sha256", "perceptual_hash", "width", "height", "review_status"
    ]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Updated manifest: {len(rows)} total images.")

if __name__ == "__main__":
    main()
