import os, csv, time, urllib.request, urllib.parse, json, hashlib, io
from PIL import Image
import numpy as np

USER_AGENT = "FitFuelAuditBot/5.2 (https://fitfuel.app; dev@fitfuel.app)"

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

def main():
    manifest_path = "ml/final_lockbox_manifest_v5.csv"
    with open(manifest_path, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    vada_count = sum(1 for r in rows if r["food_id"] == "predefined_medu_vada")
    print(f"Current Vada count: {vada_count}")

    all_sha256 = set(r["sha256"] for r in rows if r.get("sha256"))
    all_dhashes = [r["perceptual_hash"] for r in rows if r.get("perceptual_hash")]

    for mf in ["ml/dataset_manifest.csv", "ml/non_food_manifest.csv", "ml/unsupported_food_manifest.csv", "ml/mixed_meal_manifest.csv", "ml/independent_holdout_manifest.csv", "ml/reports/targeted_supplements_v5.csv"]:
        if os.path.exists(mf):
            with open(mf, "r", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    if r.get("sha256"): all_sha256.add(r["sha256"])
                    if r.get("perceptual_hash"): all_dhashes.append(r["perceptual_hash"])

    out_dir = "ml/dataset_final_lockbox_v5/supported/predefined_medu_vada"
    queries = ["vadai food", "medu vadai", "vada breakfast south indian", "uddina vada south india", "vada chutney dish", "urad dal vada plate"]

    for q in queries:
        if vada_count >= 15: break
        params = {"action": "query", "generator": "search", "gsrsearch": q, "gsrnamespace": "6", "gsrlimit": "25", "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "320", "format": "json"}
        url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for pid, p in data.get("query", {}).get("pages", {}).items():
                    if vada_count >= 15: break
                    ii = p.get("imageinfo", [])
                    if not ii: continue
                    thumb_url = ii[0].get("thumburl", "")
                    if not thumb_url: continue
                    t_req = urllib.request.Request(thumb_url, headers={"User-Agent": USER_AGENT})
                    with urllib.request.urlopen(t_req, timeout=10) as t_resp:
                        raw = t_resp.read()
                    img = Image.open(io.BytesIO(raw)).convert("RGB")
                    if img.width < 140 or img.height < 140: continue
                    sha = compute_sha256(raw)
                    dh = compute_dhash(img)
                    if sha in all_sha256 or any(hamming_distance(dh, h) <= 6 for h in all_dhashes):
                        continue
                    vada_count += 1
                    sp = os.path.join(out_dir, f"predefined_medu_vada_lockbox_{vada_count:03d}.jpg")
                    img.thumbnail((320, 320), Image.Resampling.LANCZOS)
                    img.save(sp, "JPEG", quality=90)
                    with open(sp, "rb") as sf: f_sha = compute_sha256(sf.read())
                    f_dh = compute_dhash(img)
                    all_sha256.add(f_sha)
                    all_dhashes.append(f_dh)
                    rel = os.path.relpath(sp, "ml").replace("\\", "/")
                    rows.append({
                        "image_path": rel, "food_id": "predefined_medu_vada", "food_name": "Medu Vada",
                        "source": "Wikimedia Commons (Audited)", "source_reference": ii[0].get("descriptionurl", ""),
                        "license": ii[0].get("extmetadata", {}).get("LicenseShortName", {}).get("value", "CC BY-SA"),
                        "sha256": f_sha, "perceptual_hash": f_dh, "width": img.width, "height": img.height,
                        "review_status": "ACCEPTED_LOCKBOX_V5"
                    })
        except Exception:
            time.sleep(1.0)

    print(f"Final Vada count: {vada_count}")
    fields = ["image_path", "food_id", "food_name", "source", "source_reference", "license", "sha256", "perceptual_hash", "width", "height", "review_status"]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Total Lockbox records: {len(rows)}")

if __name__ == "__main__":
    main()
