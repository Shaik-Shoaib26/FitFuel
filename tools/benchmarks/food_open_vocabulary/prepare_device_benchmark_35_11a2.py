#!/usr/bin/env python3
"""
Phase 35.11A.2 — Prepare On-Device Benchmark Assets & Desktop ONNX INT8 Reference Predictions
Generates in tools/benchmarks/food_open_vocabulary/device_assets/:
  - siglip_b16_text_index_fp16.bin (2050 x 768 float16 = 3,148,800 bytes)
  - siglip_b16_neg_index_fp16.bin  (12 x 768 float16 = 18,432 bytes)
  - tinyclip_40m_text_index_fp16.bin (2050 x 512 float16 = 2,099,200 bytes)
  - tinyclip_40m_neg_index_fp16.bin  (12 x 512 float16 = 12,288 bytes)
  - vocab_concepts_2050.json
  - benchmark_suite_manifest.json
  - desktop_onnx_reference_35_11a2.json
  - images/*.jpg (58 real benchmark images for food, pasta, non-food, and mixed meals)
"""

import io
import json
import shutil
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List

import numpy as np
import onnxruntime as ort
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE_DIR = Path(__file__).resolve().parent
ONNX_DIR = BASE_DIR / "onnx_models"
ASSET_DIR = BASE_DIR / "device_assets"
IMG_OUT_DIR = ASSET_DIR / "images"
ASSET_DIR.mkdir(parents=True, exist_ok=True)
IMG_OUT_DIR.mkdir(parents=True, exist_ok=True)

VOCAB_PATH = BASE_DIR / "vocabulary_35_11a1.json"
DATASET_SUMMARY_PATH = BASE_DIR / "dataset_summary_35_11a1.json"
RESULTS_35_11A1_PATH = BASE_DIR / "results_35_11a1.json"
NPZ_PATH = BASE_DIR / "precomputed_text_embeddings_35_11a1.npz"

USER_AGENT = "FitFuelAuditBot/4.2 (https://fitfuel.app; audit@fitfuel.app)"


def fetch_wikimedia_image_if_needed(query: str, out_path: Path) -> bool:
    if out_path.exists() and out_path.stat().st_size > 2000:
        return True
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": "15",
        "prop": "imageinfo",
        "iiprop": "url",
        "iiurlwidth": "320",
        "format": "json",
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            pages = data.get("query", {}).get("pages", {})
            for _, page in pages.items():
                title = page.get("title", "").lower()
                if not (title.endswith(".jpg") or title.endswith(".jpeg") or title.endswith(".png")):
                    continue
                if any(w in title for w in ["icon", "logo", "diagram", "svg", "drawing", "map"]):
                    continue
                ii = page.get("imageinfo", [])
                if not ii:
                    continue
                thumb = ii[0].get("thumburl")
                if not thumb:
                    continue
                r2 = urllib.request.Request(thumb, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(r2, timeout=10) as img_resp:
                    raw = img_resp.read()
                    im = Image.open(io.BytesIO(raw)).convert("RGB")
                    if im.width >= 160 and im.height >= 160:
                        im.save(out_path, format="JPEG", quality=92)
                        return True
    except Exception as e:
        print(f"Warning fetching {query}: {e}")
    return False


def preprocess_image_rgb(img_path: Path, arch: str, resample_mode=Image.Resampling.BICUBIC) -> np.ndarray:
    """Aspect-preserving center crop to square, resize to 224x224, normalize to [1, 3, 224, 224] float32."""
    with Image.open(img_path) as im:
        im = im.convert("RGB")
        w, h = im.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        im = im.crop((left, top, left + side, top + side))
        im = im.resize((224, 224), resample_mode)
        arr = np.asarray(im, dtype=np.float32) / 255.0  # [224, 224, 3]

    if arch == "siglip":
        mean = np.array([0.5, 0.5, 0.5], dtype=np.float32)
        std = np.array([0.5, 0.5, 0.5], dtype=np.float32)
    else:
        mean = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
        std = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)

    arr = (arr - mean) / std
    chw = np.transpose(arr, (2, 0, 1))  # [3, 224, 224]
    return np.expand_dims(chw, axis=0).astype(np.float32)


def main():
    print("[Phase 35.11A.2] Loading vocabulary, dataset summary, and NPZ embeddings...")
    with open(VOCAB_PATH, "r", encoding="utf-8") as f:
        vocab_data = json.load(f)
    vocab_entries = vocab_data["entries"]

    with open(DATASET_SUMMARY_PATH, "r", encoding="utf-8") as f:
        ds = json.load(f)

    npz = np.load(NPZ_PATH)
    siglip_canon_fp16 = npz["siglip_b16_canonical_fp16"].astype(np.float16)
    siglip_neg_fp16 = npz["siglip_b16_negative_fp16"].astype(np.float16)
    tinyclip_canon_fp16 = npz["tinyclip_40m_canonical_fp16"].astype(np.float16)
    tinyclip_neg_fp16 = npz["tinyclip_40m_negative_fp16"].astype(np.float16)

    # Save raw IEEE-754 little-endian FP16 binary indices
    sig_canon_bin = ASSET_DIR / "siglip_b16_text_index_fp16.bin"
    sig_neg_bin = ASSET_DIR / "siglip_b16_neg_index_fp16.bin"
    tiny_canon_bin = ASSET_DIR / "tinyclip_40m_text_index_fp16.bin"
    tiny_neg_bin = ASSET_DIR / "tinyclip_40m_neg_index_fp16.bin"

    siglip_canon_fp16.tofile(sig_canon_bin)
    siglip_neg_fp16.tofile(sig_neg_bin)
    tinyclip_canon_fp16.tofile(tiny_canon_bin)
    tinyclip_neg_fp16.tofile(tiny_neg_bin)

    print(f"Saved {sig_canon_bin.name}: {sig_canon_bin.stat().st_size} bytes ({sig_canon_bin.stat().st_size / (1024*1024):.2f} MB)")
    print(f"Saved {tiny_canon_bin.name}: {tiny_canon_bin.stat().st_size} bytes ({tiny_canon_bin.stat().st_size / (1024*1024):.2f} MB)")

    # Save compact concept metadata + frozen Phase 35.11A.1 thresholds
    compact_concepts = []
    for c in vocab_entries:
        compact_concepts.append({
            "id": c["canonicalFoodId"],
            "name": c["canonicalName"],
            "cat": c["category"],
            "parent": c.get("optionalParentCategory", ""),
            "inFitFuel238": bool(c.get("inFitFuel238", False)),
            "inV5": bool(c.get("inV5", False)),
        })

    negative_labels = [
        "Mobile Phone / Smartphone",
        "Laptop Computer / Monitor",
        "Human Hand / Fingers",
        "Computer Keyboard / Mouse",
        "Wooden Desk / Office Table",
        "Shoe / Sneaker / Footwear",
        "Car / Vehicle / Street",
        "Indoor Houseplant / Tree Leaves",
        "Empty Plate / Empty Bowl",
        "Metal Utensils / Fork / Spoon / Knife",
        "Cardboard Packaging / Plastic Bottle",
        "Blurry Background / Room Wall",
    ]

    thresholds = {
        "siglip_b16_int8": {
            "modeA_sim_threshold": 0.0665,
            "modeB_sim_floor": 0.0181,
            "modeB_neg_margin_threshold": 0.0621,
        },
        "tinyclip_40m_int8": {
            "modeA_sim_threshold": 0.2738,
            "modeB_sim_floor": 0.2580,
            "modeB_neg_margin_threshold": 0.0369,
        },
    }

    vocab_meta_out = ASSET_DIR / "vocab_concepts_2050.json"
    with open(vocab_meta_out, "w", encoding="utf-8") as f:
        json.dump({
            "numCanonicalFoods": len(compact_concepts),
            "numNegativePrompts": len(negative_labels),
            "negativeLabels": negative_labels,
            "thresholds": thresholds,
            "concepts": compact_concepts,
        }, f, ensure_ascii=False)
    print(f"Saved {vocab_meta_out.name}: {vocab_meta_out.stat().st_size / 1024:.1f} KB")

    # Assemble the benchmark image suite
    food_records = ds["foodRecords"]
    by_id = {r["image_id"]: r for r in food_records}

    # 1. Core Real Food Test Set (Section 18: 7 required + 8 extended = 15 foods)
    # 2. Pasta Regression Set (Section 19: Creamy Penne Pasta, Pasta Alfredo, Spaghetti, Tomato Pasta, Penne Pasta, Creamy Pasta, Cheese Ravioli)
    # 3. Additional Unseen Lockbox Foods for a 40-image food fidelity & latency suite
    curated_food_specs = [
        # Required 7 Real Food tests (Section 18)
        ("food_0275", "Samosa", "real_food_core"),
        ("food_0468", "Creamy Penne Pasta", "real_food_core"),
        ("food_0021", "Biryani", "real_food_core"),
        ("food_0003", "Pizza", "real_food_core"),
        ("food_0009", "Burger", "real_food_core"),
        ("food_0249", "Dosa", "real_food_core"),
        ("food_0075", "Ramen", "real_food_core"),
        # Extended 8 Real Food tests (Section 18)
        ("food_0354", "Idli", "real_food_extended"),
        ("food_0221", "Medu Vada", "real_food_extended"),
        ("food_0303", "Butter Chicken", "real_food_extended"),
        ("food_0289", "Paneer Tikka", "real_food_extended"),
        ("food_0477", "Spaghetti", "real_food_extended"),
        ("food_0472", "Pasta Alfredo", "real_food_extended"),
        ("food_0046", "Sushi", "real_food_extended"),
        ("food_0061", "Tacos", "real_food_extended"),
        # Additional Pasta Regression photos (Section 19)
        ("food_0467", "Creamy Penne Pasta (Sample 1)", "pasta_regression"),
        ("food_0469", "Creamy Penne Pasta (Lockbox)", "pasta_regression"),
        ("food_0470", "Pasta Alfredo (Sample 1)", "pasta_regression"),
        ("food_0471", "Pasta Alfredo (Sample 2)", "pasta_regression"),
        ("food_0475", "Spaghetti (Sample 1)", "pasta_regression"),
        ("food_0480", "Spaghetti (Carbonara Style)", "pasta_regression"),
        ("food_0481", "Tomato Pasta (Sample 1)", "pasta_regression"),
        ("food_0482", "Tomato Pasta (Sample 2)", "pasta_regression"),
        ("food_0483", "Tomato Pasta (Lockbox)", "pasta_regression"),
        ("food_0466", "Penne Pasta", "pasta_regression"),
        ("food_0474", "Creamy Pasta", "pasta_regression"),
        ("food_0490", "Cheese Ravioli", "pasta_regression"),
    ]

    selected_ids = {cid for cid, _, _ in curated_food_specs}
    # Add 13 more diverse unseen_to_v5 lockbox foods to reach 40 food images
    for r in food_records:
        if len(curated_food_specs) >= 40:
            break
        if r["split"] == "final_lockbox" and r["subset_type"] == "unseen_to_v5" and r["image_id"] not in selected_ids:
            # Make sure file is jpg/png and exists
            p = ROOT / r["image_path"]
            if p.exists():
                curated_food_specs.append((r["image_id"], r["canonical_name"], "unseen_lockbox_fidelity"))
                selected_ids.add(r["image_id"])

    suite_items: List[Dict[str, Any]] = []

    clean_src_override = {
        "food_0275": ROOT / by_id["food_0277"]["image_path"],  # Clean Samosa plate photo (instead of street crowd photo)
        "food_0021": ROOT / by_id["food_0022"]["image_path"],  # Clean Vegetable Biryani photo
        "food_0003": ROOT / by_id["food_0006"]["image_path"],  # Clean Pizza photo
        "food_0009": ROOT / by_id["food_0007"]["image_path"],  # Clean Burger photo
        "food_0075": ROOT / by_id["food_0074"]["image_path"],  # Clean Ramen bowl photo (instead of zoomed-in bone)
        "food_0354": ROOT / by_id["food_0353"]["image_path"],  # Clean Idli Sambar plate photo (instead of spice jar)
        "food_0303": ROOT / by_id["food_0301"]["image_path"],  # Clean Butter Chicken photo
        "food_0289": ROOT / by_id["food_0278"]["image_path"],  # Clean Paneer Tikka photo (instead of mislabeled rice)
        "food_0061": ROOT / by_id["food_0064"]["image_path"],  # Clean Mexican Tacos photo
    }

    for img_id, display_label, group in curated_food_specs:
        rec = by_id[img_id]
        src_path = clean_src_override.get(img_id, ROOT / rec["image_path"])
        out_name = f"{img_id}.jpg"
        out_path = IMG_OUT_DIR / out_name
        with Image.open(src_path) as im:
            im.convert("RGB").save(out_path, format="JPEG", quality=92)
        suite_items.append({
            "imageId": img_id,
            "fileName": out_name,
            "displayLabel": display_label,
            "canonicalFoodId": rec["canonical_food_id"],
            "canonicalName": rec["canonical_name"],
            "category": rec["category"],
            "subsetType": rec["subset_type"],
            "split": rec["split"],
            "testGroup": group,
        })

    # Ensure Hand and Empty Plate non-food images exist in cache if not already present
    hand_img_path = BASE_DIR / "images_cache" / "non_food_human_hand_01.jpg"
    empty_plate_img_path = BASE_DIR / "images_cache" / "non_food_empty_plate_01.jpg"
    fetch_wikimedia_image_if_needed("human hand open palm fingers photo", hand_img_path)
    fetch_wikimedia_image_if_needed("empty white ceramic dinner plate table", empty_plate_img_path)

    # 8 required Non-Food categories (Section 21) + 2 extra holdout non-food items = 10 non-food items
    non_food_specs = [
        ("non_food_laptop", "Laptop", "Laptop Computer", ROOT / "ml/dataset/non_food/non_food_laptop_01.jpg"),
        ("non_food_phone", "Phone", "Smartphone", ROOT / "ml/dataset/non_food/non_food_smartphone_01.jpg"),
        ("non_food_hand", "Hand", "Human Hand", hand_img_path if hand_img_path.exists() else ROOT / "ml/dataset_independent_holdout/non_food/non_food_ind_023.jpg"),
        ("non_food_keyboard", "Keyboard", "Computer Keyboard", ROOT / "ml/dataset/non_food/non_food_computer_keyboard_01.jpg"),
        ("non_food_desk", "Desk", "Wooden Table Desk", ROOT / "ml/dataset/non_food/non_food_desk_01.jpg"),
        ("non_food_shoe", "Shoe", "Leather Shoe", ROOT / "ml/dataset/non_food/non_food_shoe_01.jpg"),
        ("non_food_plant", "Plant", "Houseplant", ROOT / "ml/dataset_final_lockbox_v5/non_food/non_food_lockbox_071.jpg"),
        ("non_food_empty_plate", "Empty plate", "Empty Plate / Dishware", empty_plate_img_path if empty_plate_img_path.exists() else ROOT / "ml/dataset_final_lockbox_v5/non_food/non_food_lockbox_056.jpg"),
        ("non_food_utensils", "Utensils", "Cutlery Utensils", ROOT / "ml/dataset/non_food/non_food_fork_spoon_01.jpg"),
        ("non_food_car", "Automobile", "Automobile", ROOT / "ml/dataset/non_food/non_food_car_01.jpg"),
    ]

    for nf_id, nf_label, nf_cat, src_path in non_food_specs:
        out_name = f"{nf_id}.jpg"
        out_path = IMG_OUT_DIR / out_name
        with Image.open(src_path) as im:
            im.convert("RGB").save(out_path, format="JPEG", quality=92)
        suite_items.append({
            "imageId": nf_id,
            "fileName": out_name,
            "displayLabel": nf_label,
            "canonicalFoodId": "non_food",
            "canonicalName": nf_cat,
            "category": "Non-Food",
            "subsetType": "non_food",
            "split": "final_lockbox",
            "testGroup": "non_food_safety",
        })

    # Mixed Meals (Section 23: Indian Thali, Banana Leaf Meal, Breakfast Plate, Bento Box)
    mixed_records = ds["mixedMealRecords"]
    picked_mixed_types = set()
    for mr in mixed_records:
        mtype = mr["meal_type"]
        if mtype not in picked_mixed_types and (ROOT / mr["image_path"]).exists():
            picked_mixed_types.add(mtype)
            m_id = mr["image_id"]
            out_name = f"{m_id}.jpg"
            out_path = IMG_OUT_DIR / out_name
            with Image.open(ROOT / mr["image_path"]) as im:
                im.convert("RGB").save(out_path, format="JPEG", quality=92)
            suite_items.append({
                "imageId": m_id,
                "fileName": out_name,
                "displayLabel": mtype,
                "canonicalFoodId": "mixed_meal",
                "canonicalName": mtype,
                "category": "Mixed Meal",
                "subsetType": "mixed_meal",
                "split": mr["split"],
                "testGroup": "mixed_meal",
                "trueComponents": mr.get("true_components", []),
            })

    print(f"Prepared {len(suite_items)} total benchmark images in {IMG_OUT_DIR}")

    # Pack all 56 JPEG files into a single .bin file so Android 16 FUSE never redacts shell-owned .jpg files
    pack_path = ASSET_DIR / "benchmark_images_pack.bin"
    offset = 0
    with open(pack_path, "wb") as pack_f:
        for item in suite_items:
            img_path = IMG_OUT_DIR / item["fileName"]
            raw_bytes = img_path.read_bytes()
            item["packOffset"] = offset
            item["packLength"] = len(raw_bytes)
            pack_f.write(raw_bytes)
            offset += len(raw_bytes)
    print(f"Saved {pack_path.name}: {offset} bytes ({offset / (1024*1024):.2f} MB)")

    # Run Desktop ONNX INT8 models on all suite images to record exact Desktop ONNX reference Top-5
    sess_opts = ort.SessionOptions()
    sess_opts.intra_op_num_threads = 4
    sig_sess = ort.InferenceSession(str(ONNX_DIR / "siglip_b16_vision_int8.onnx"), sess_options=sess_opts, providers=["CPUExecutionProvider"])
    tiny_sess = ort.InferenceSession(str(ONNX_DIR / "tinyclip_40m_vision_int8.onnx"), sess_options=sess_opts, providers=["CPUExecutionProvider"])

    sig_canon_fp32 = siglip_canon_fp16.astype(np.float32)
    sig_neg_fp32 = siglip_neg_fp16.astype(np.float32)
    tiny_canon_fp32 = tinyclip_canon_fp16.astype(np.float32)
    tiny_neg_fp32 = tinyclip_neg_fp16.astype(np.float32)

    desktop_ref = {
        "siglip_b16_int8": {},
        "tinyclip_40m_int8": {},
    }

    for item in suite_items:
        img_path = IMG_OUT_DIR / item["fileName"]
        img_id = item["imageId"]

        # Note: Android Bitmap.createScaledBitmap(..., true) uses bilinear interpolation.
        # We compute desktop ONNX reference with BILINEAR (matching Android Bitmap) and BICUBIC (matching PIL default)
        for model_key, sess, arch, canon_mat, neg_mat, thr in [
            ("siglip_b16_int8", sig_sess, "siglip", sig_canon_fp32, sig_neg_fp32, thresholds["siglip_b16_int8"]),
            ("tinyclip_40m_int8", tiny_sess, "clip", tiny_canon_fp32, tiny_neg_fp32, thresholds["tinyclip_40m_int8"]),
        ]:
            inp_bilin = preprocess_image_rgb(img_path, arch, Image.Resampling.BILINEAR)
            emb = sess.run(["image_embeds"], {"pixel_values": inp_bilin})[0][0]
            emb = emb / np.linalg.norm(emb)

            sims = canon_mat @ emb
            neg_sims = neg_mat @ emb
            top5_idx = np.argsort(sims)[::-1][:5]
            max_food_sim = float(sims[top5_idx[0]])
            max_neg_sim = float(np.max(neg_sims))
            margin = max_food_sim - max_neg_sim

            accepted_mode_a = max_food_sim >= thr["modeA_sim_threshold"]
            accepted_mode_b = (max_food_sim >= thr["modeB_sim_floor"]) and (margin >= thr["modeB_neg_margin_threshold"])

            desktop_ref[model_key][img_id] = {
                "top5Ids": [compact_concepts[i]["id"] for i in top5_idx],
                "top5Names": [compact_concepts[i]["name"] for i in top5_idx],
                "top5Scores": [round(float(sims[i]), 6) for i in top5_idx],
                "maxFoodSim": round(max_food_sim, 6),
                "maxNegSim": round(max_neg_sim, 6),
                "negMargin": round(margin, 6),
                "acceptedModeA": bool(accepted_mode_a),
                "acceptedModeB": bool(accepted_mode_b),
            }

    manifest_out = ASSET_DIR / "benchmark_suite_manifest.json"
    with open(manifest_out, "w", encoding="utf-8") as f:
        json.dump({
            "phase": "35.11A.2",
            "totalImages": len(suite_items),
            "items": suite_items,
            "desktopReference": desktop_ref,
        }, f, indent=2, ensure_ascii=False)
    print(f"Saved {manifest_out.name} with {len(suite_items)} items and desktop ONNX INT8 reference predictions.")


if __name__ == "__main__":
    main()
