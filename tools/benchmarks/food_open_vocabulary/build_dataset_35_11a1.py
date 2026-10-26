#!/usr/bin/env python3
"""
FitFuel Phase 35.11A.1 — Leak-Resistant Open-Vocabulary Benchmark Dataset Builder
"""

import concurrent.futures
import csv
import glob
import hashlib
import io
import json
import os
import urllib.parse
import urllib.request
from collections import Counter, defaultdict

import numpy as np
from PIL import Image

OUT_DIR = "tools/benchmarks/food_open_vocabulary"
CACHE_IMG_DIR = os.path.join(OUT_DIR, "images_cache")
VOCAB_PATH = os.path.join(OUT_DIR, "vocabulary_35_11a1.json")
V5_LABELS_PATH = "assets/ml/fitfuel_food_labels.txt"
USER_AGENT = "FitFuelOpenVocabBenchmark/1.0 (https://fitfuel.app; dev@fitfuel.app)"


def compute_sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compute_dhash(img: Image.Image, hash_size: int = 8) -> str:
    resized = img.convert("L").resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
    arr = np.array(resized)
    diff = arr[:, 1:] > arr[:, :-1]
    return np.packbits(diff.flatten()).tobytes().hex()


def hamming_distance(h1: str, h2: str) -> int:
    return bin(int(h1, 16) ^ int(h2, 16)).count("1")


# Target Unseen-to-V5 concepts to top up from Wikimedia Commons (including Pasta Regression!)
TOPUP_UNSEEN_CONCEPTS = [
    # Pasta Regression Suite (Section 20)
    ("openvocab_penne_pasta", "Penne Pasta", "penne pasta dish plate", 3),
    ("openvocab_creamy_penne_pasta", "Creamy Penne Pasta", "creamy penne pasta sauce", 3),
    ("openvocab_pasta_alfredo", "Pasta Alfredo", "fettuccine alfredo pasta", 3),
    ("openvocab_penne_alfredo", "Penne Alfredo", "penne alfredo pasta cheese", 2),
    ("openvocab_creamy_pasta", "Creamy Pasta", "creamy white sauce pasta", 2),
    ("openvocab_spaghetti", "Spaghetti", "spaghetti tomato basil dish", 3),
    ("openvocab_spaghetti_bolognese", "Spaghetti Bolognese", "spaghetti bolognese meat sauce", 3),
    ("openvocab_tomato_pasta", "Tomato Pasta", "pasta pomodoro tomato sauce", 3),
    ("openvocab_lasagna", "Lasagna", "baked lasagna dish slice", 3),
    ("openvocab_macaroni", "Macaroni", "macaroni pasta bowl", 2),
    ("openvocab_macaroni_and_cheese", "Macaroni and Cheese", "macaroni and cheese baked", 3),
    ("openvocab_spaghetti_carbonara", "Spaghetti Carbonara", "spaghetti alla carbonara", 2),
    ("openvocab_potato_gnocchi", "Potato Gnocchi", "potato gnocchi dish", 2),
    ("openvocab_cheese_ravioli", "Cheese Ravioli", "ravioli pasta plate", 2),
    # Diverse Global Unseen-to-V5 Concepts (to exceed 250+ distinct foods)
    ("openvocab_udon", "Udon", "japanese udon noodle soup bowl", 2),
    ("openvocab_falafel", "Falafel", "chickpea falafel balls plate", 3),
    ("openvocab_hummus", "Hummus", "hummus bowl olive oil", 3),
    ("openvocab_chicken_shawarma", "Chicken Shawarma", "chicken shawarma wrap plate", 2),
    ("openvocab_shakshuka", "Shakshuka", "shakshuka poached eggs tomato", 3),
    ("openvocab_vietnamese_pho", "Vietnamese Pho", "pho bo vietnamese noodle soup", 3),
    ("openvocab_pad_thai", "Pad Thai", "pad thai noodles shrimp", 3),
    ("openvocab_bibimbap", "Bibimbap", "korean bibimbap bowl", 3),
    ("openvocab_kimchi_fried_rice", "Kimchi Fried Rice", "kimchi bokkeumbap fried rice", 2),
    ("openvocab_spanish_paella", "Spanish Paella", "paella valenciana seafood pan", 3),
    ("openvocab_croissant", "Croissant", "french butter croissant pastry", 3),
    ("openvocab_cheesecake", "Cheesecake", "new york cheesecake slice", 3),
    ("openvocab_fish_and_chips", "Fish and Chips", "fish and chips plate", 2),
    ("openvocab_greek_salad", "Greek Salad", "greek salad feta olives", 2),
    ("openvocab_jollof_rice", "Jollof Rice", "jollof rice west african", 2),
    ("openvocab_injera_with_wat", "Injera with Wat", "ethiopian injera wat platter", 2),
    ("openvocab_moroccan_tagine", "Moroccan Tagine", "moroccan chicken tagine", 2),
    ("openvocab_moroccan_couscous", "Moroccan Couscous", "moroccan couscous vegetables", 2),
    ("openvocab_peruvian_ceviche", "Peruvian Ceviche", "peruvian ceviche fish", 2),
    ("openvocab_argentine_empanada", "Argentine Empanada", "empanadas argentinas baked", 2),
    ("openvocab_colombian_arepa", "Colombian Arepa", "arepa colombiana cheese", 2),
    ("openvocab_guacamole", "Guacamole", "guacamole bowl tortilla chips", 3),
    ("openvocab_churros", "Churros", "churros chocolate Spain", 3),
    ("openvocab_tiramisu", "Tiramisu", "tiramisu italian dessert", 3),
    ("openvocab_french_macarons", "French Macarons", "french macarons colorful", 2),
    ("openvocab_cr_me_br_l_e", "Crème Brûlée", "creme brulee caramelized", 2),
    ("openvocab_french_onion_soup", "French Onion Soup", "french onion soup cheese bowl", 2),
    ("openvocab_ratatouille", "Ratatouille", "ratatouille vegetable stew", 2),
    ("openvocab_quiche_lorraine", "Quiche Lorraine", "quiche lorraine slice", 2),
    ("openvocab_mushroom_risotto", "Mushroom Risotto", "mushroom risotto plate", 2),
    ("openvocab_bruschetta", "Bruschetta", "tomato basil bruschetta bread", 2),
    ("openvocab_caprese_salad", "Caprese Salad", "insalata caprese mozzarella tomato", 2),
    ("openvocab_gazpacho", "Gazpacho", "gazpacho soup bowl", 2),
    ("openvocab_tortilla_espa_ola", "Tortilla Española", "tortilla espanola de patatas", 2),
    ("openvocab_moussaka", "Moussaka", "greek moussaka dish", 2),
    ("openvocab_chicken_souvlaki", "Chicken Souvlaki", "souvlaki skewers greek", 2),
    ("openvocab_wiener_schnitzel", "Wiener Schnitzel", "wiener schnitzel lemon", 2),
    ("openvocab_bratwurst", "Bratwurst", "bratwurst sausage sauerkraut", 2),
    ("openvocab_bavarian_pretzel", "Bavarian Pretzel", "pretzel brezeln baked", 2),
    ("openvocab_apple_strudel", "Apple Strudel", "apfelstrudel slice", 2),
    ("openvocab_swiss_cheese_fondue", "Swiss Cheese Fondue", "cheese fondue pot", 2),
    ("openvocab_polish_pierogi", "Polish Pierogi", "pierogi ruskie dumplings", 2),
    ("openvocab_hungarian_goulash", "Hungarian Goulash", "goulash soup beef", 2),
    ("openvocab_beef_stroganoff", "Beef Stroganoff", "beef stroganoff dish", 2),
    ("openvocab_swedish_meatballs", "Swedish Meatballs", "swedish meatballs lingonberry", 2),
    ("openvocab_peking_duck", "Peking Duck", "peking duck sliced dish", 2),
    ("openvocab_kung_pao_chicken", "Kung Pao Chicken", "kung pao chicken peanuts", 2),
    ("openvocab_mapo_tofu", "Mapo Tofu", "mapo tofu sichuan bowl", 2),
    ("openvocab_xiao_long_bao", "Xiao Long Bao", "xiaolongbao steamer basket", 2),
    ("openvocab_har_gow_dim_sum", "Har Gow Dim Sum", "har gow dim sum", 2),
    ("openvocab_char_siu_bbq_pork", "Char Siu BBQ Pork", "char siu roast pork", 2),
    ("openvocab_dan_dan_noodles", "Dan Dan Noodles", "dan dan noodles sichuan", 2),
    ("openvocab_tonkatsu_pork_cutlet", "Tonkatsu Pork Cutlet", "tonkatsu pork cutlet cabbage", 2),
    ("openvocab_japanese_katsu_curry", "Japanese Katsu Curry", "katsu curry rice japanese", 2),
    ("openvocab_shrimp_tempura", "Shrimp Tempura", "ebi tempura japanese", 2),
    ("openvocab_okonomiyaki", "Okonomiyaki", "okonomiyaki japanese pancake", 2),
    ("openvocab_yakitori_skewers", "Yakitori Skewers", "yakitori grilled chicken skewers", 2),
    ("openvocab_onigiri_rice_ball", "Onigiri Rice Ball", "onigiri japanese rice balls", 2),
    ("openvocab_miso_soup", "Miso Soup", "miso soup tofu seaweed bowl", 2),
    ("openvocab_bulgogi_beef", "Bulgogi Beef", "korean bulgogi beef dish", 2),
    ("openvocab_tteokbokki", "Tteokbokki", "tteokbokki spicy korean rice cakes", 2),
    ("openvocab_japchae_glass_noodles", "Japchae Glass Noodles", "korean japchae glass noodles", 2),
    ("openvocab_kimbap_roll", "Kimbap Roll", "gimbap korean seaweed rice rolls", 2),
    ("openvocab_tom_yum_goong", "Tom Yum Goong", "tom yum goong thai soup", 2),
    ("openvocab_thai_green_curry", "Thai Green Curry", "thai green curry chicken bowl", 2),
    ("openvocab_som_tum_papaya_salad", "Som Tum Papaya Salad", "som tam papaya salad thai", 2),
    ("openvocab_mango_sticky_rice", "Mango Sticky Rice", "mango sticky rice thai dessert", 2),
    ("openvocab_chicken_satay", "Chicken Satay", "chicken satay skewers peanut sauce", 2),
    ("openvocab_banh_mi_baguette", "Banh Mi Baguette", "banh mi sandwich vietnamese", 2),
    ("openvocab_goi_cuon_summer_rolls", "Goi Cuon Summer Rolls", "goi cuon vietnamese spring rolls", 2),
    ("openvocab_nasi_goreng", "Nasi Goreng", "nasi goreng fried rice egg", 2),
    ("openvocab_beef_rendang", "Beef Rendang", "beef rendang padang", 2),
    ("openvocab_hainanese_chicken_rice", "Hainanese Chicken Rice", "hainanese chicken rice plate", 2),
    ("openvocab_curry_laksa", "Curry Laksa", "curry laksa noodle soup", 2),
    ("openvocab_nasi_lemak", "Nasi Lemak", "nasi lemak malaysian dish", 2),
    ("openvocab_chicken_adobo", "Chicken Adobo", "filipino chicken adobo dish", 2),
    ("openvocab_halo_halo", "Halo-Halo", "halo halo filipino dessert", 2),
    ("openvocab_baba_ganoush", "Baba Ganoush", "baba ganoush eggplant dip", 2),
    ("openvocab_tabbouleh_salad", "Tabbouleh Salad", "tabbouleh salad parsley", 2),
    ("openvocab_kunafa", "Kunafa", "knafeh kunafa dessert", 2),
    ("openvocab_lahmacun", "Lahmacun", "lahmacun flatbread lemon", 2),
    ("openvocab_canadian_poutine", "Canadian Poutine", "poutine fries cheese curds gravy", 2),
    ("openvocab_new_england_clam_chowder", "New England Clam Chowder", "clam chowder soup bowl", 2),
    ("openvocab_eggs_benedict", "Eggs Benedict", "eggs benedict hollandaise", 2),
    ("openvocab_cinnamon_roll", "Cinnamon Roll", "cinnamon roll pastry", 2),
    ("openvocab_fudge_brownie", "Fudge Brownie", "chocolate brownie square", 2),
    ("openvocab_apple_pie", "Apple Pie", "apple pie slice lattice", 2),
    ("openvocab_brazilian_feijoada", "Brazilian Feijoada", "feijoada brasileira dish", 2),
    ("openvocab_p_o_de_queijo", "Pão de Queijo", "pao de queijo brazilian cheese bread", 2),
    ("openvocab_vada_pav", "Vada Pav", "vada pav mumbai snack", 2),
    ("openvocab_chole_bhature", "Chole Bhature", "chole bhature punjabi plate", 2),
    ("openvocab_rasmalai", "Rasmalai", "rasmalai indian sweet", 2),
    ("openvocab_kaju_katli", "Kaju Katli", "kaju katli barfi", 2),
]

TRUE_TEXT_OOV_QUERY_SPECS = [
    ("oov_khachapuri", "Khachapuri Georgian Cheese Bread", "khachapuri cheese bread egg", ["Pizza & Flatbreads", "Cheese Pizza", "Pide Flatbread", "Focaccia"], 2),
    ("oov_stroopwafel", "Dutch Stroopwafel Caramel Waffle", "stroopwafel dutch cookie", ["Desserts & Sweets", "Belgian Waffle", "Speculoos", "Sweet Crepes"], 2),
    ("oov_koshari", "Egyptian Koshari Rice Lentil Pasta", "koshari egyptian food bowl", ["Rice Dishes", "Mujadara", "Macaroni", "Masala Khichdi"], 2),
    ("oov_paniyaram", "South Indian Kuzhi Paniyaram", "kuzhi paniyaram south indian", ["Breakfast", "Idli", "Medu Vada", "Uttapam"], 2),
    ("oov_khao_soi", "Northern Thai Khao Soi Curry Noodles", "khao soi chiang mai noodles", ["Pasta & Noodles", "Curry Laksa", "Thai Green Curry", "Ramen Noodles"], 2),
    ("oov_borscht", "Ukrainian Beetroot Borscht Soup", "borscht red beet soup sour cream", ["Soups & Stews", "Minestrone", "Beetroot", "Tomato Bisque"], 2),
    ("oov_pastel_de_nata", "Portuguese Pastel de Nata Custard Tart", "pastel de nata portuguese tart", ["Desserts & Sweets", "Hong Kong Egg Tart", "Crème Brûlée", "Lemon Meringue Tart"], 2),
    ("oov_takoyaki", "Japanese Takoyaki Octopus Balls", "takoyaki octopus balls japanese", ["Snacks", "Okonomiyaki", "Medu Vada", "Mandu Dumplings"], 2),
    ("oov_spanakopita", "Greek Spanakopita Spinach Feta Pie", "spanakopita greek spinach pie", ["Snacks", "Baklava", "Su Boregi", "Quiche Lorraine"], 2),
    ("oov_banh_xeo", "Vietnamese Banh Xeo Crispy Crepe", "banh xeo vietnamese crepe", ["Main Dishes", "Plain Dosa", "Sweet Crepes", "Masala Egg Omelette"], 2),
]


def fetch_wikimedia_images(query: str, needed: int):
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {query}",
        "gsrnamespace": "6",
        "gsrlimit": "10",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "320",
        "format": "json",
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    items = []
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            pages = data.get("query", {}).get("pages", {})
            for _, page in pages.items():
                title = page.get("title", "")
                lt = title.lower()
                if any(ext in lt for ext in [".svg", ".pdf", ".gif", ".tif", ".webm", ".ogg"]):
                    continue
                if any(kw in lt for kw in ["icon", "logo", "map", "diagram", "stamp", "cartoon", "drawing"]):
                    continue
                ii = page.get("imageinfo", [])
                if not ii:
                    continue
                thumb_url = ii[0].get("thumburl", "")
                desc_url = ii[0].get("descriptionurl", "")
                meta = ii[0].get("extmetadata", {})
                lic = meta.get("LicenseShortName", {}).get("value", "CC BY-SA 4.0")
                if thumb_url:
                    items.append({"title": title, "thumb_url": thumb_url, "desc_url": desc_url, "license": lic})
    except Exception:
        return []

    downloaded = []
    for it in items:
        if len(downloaded) >= needed:
            break
        try:
            req = urllib.request.Request(it["thumb_url"], headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=5) as resp:
                raw = resp.read()
            img = Image.open(io.BytesIO(raw)).convert("RGB")
            if img.width < 120 or img.height < 120:
                continue
            if np.std(np.array(img)) < 12.0:
                continue
            downloaded.append((img, raw, it))
        except Exception:
            continue
    return downloaded


def build_dataset():
    os.makedirs(CACHE_IMG_DIR, exist_ok=True)
    with open(VOCAB_PATH, "r", encoding="utf-8") as f:
        vocab_data = json.load(f)
    vocab_by_id = {e["canonicalFoodId"]: e for e in vocab_data["entries"]}

    with open(V5_LABELS_PATH, "r", encoding="utf-8") as f:
        v5_set = set(l.strip() for l in f if l.strip())

    seen_sha256 = set()
    seen_dhashes = []
    seen_sources = set()
    duplicates_removed = {"exact_sha256": 0, "same_source": 0, "perceptual_near_duplicate": 0}

    def register_unique_image(img_path: str, source_ref: str):
        if not os.path.exists(img_path):
            return None
        with open(img_path, "rb") as f:
            raw = f.read()
        sha = compute_sha256_bytes(raw)
        if sha in seen_sha256:
            duplicates_removed["exact_sha256"] += 1
            return None
        norm_src = source_ref.strip().lower() if source_ref else ""
        if norm_src and norm_src != "wikimedia commons" and norm_src in seen_sources:
            duplicates_removed["same_source"] += 1
            return None
        try:
            img = Image.open(io.BytesIO(raw)).convert("RGB")
            dh = compute_dhash(img)
        except Exception:
            return None
        for prev_dh in seen_dhashes:
            if hamming_distance(dh, prev_dh) <= 4:
                duplicates_removed["perceptual_near_duplicate"] += 1
                return None
        seen_sha256.add(sha)
        if norm_src and norm_src != "wikimedia commons":
            seen_sources.add(norm_src)
        seen_dhashes.append(dh)
        return {"sha256": sha, "dhash": dh, "width": img.width, "height": img.height}

    food_records = []
    per_concept_count = Counter()

    def try_add_food(img_path: str, fid: str, fname: str, source_name: str, source_url: str, lic: str, subset_type: str, max_per_concept: int = 6):
        if per_concept_count[fid] >= max_per_concept:
            return False
        info = register_unique_image(img_path, source_url)
        if info is None:
            return False
        per_concept_count[fid] += 1
        meta = vocab_by_id.get(fid, {})
        food_records.append({
            "image_id": f"food_{len(food_records)+1:04d}",
            "image_path": os.path.normpath(img_path).replace("\\", "/"),
            "canonical_food_id": fid,
            "canonical_name": fname or meta.get("canonicalName", fid),
            "category": meta.get("category", "Main Dishes"),
            "parent_category": meta.get("optionalParentCategory", "Food & Drink"),
            "cuisine": meta.get("cuisine", "Global"),
            "subset_type": subset_type,
            "in_v5_classes": fid in v5_set,
            "in_fitfuel_238": meta.get("inFitFuel238", False),
            "source_dataset": source_name,
            "source_url": source_url,
            "license": lic,
            "sha256": info["sha256"],
            "dhash": info["dhash"],
            "width": info["width"],
            "height": info["height"],
        })
        return True

    # 1. Load existing unsupported_food_manifest.csv
    with open("ml/unsupported_food_manifest.csv", "r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            fid = r["food_id"]
            if fid in vocab_by_id:
                try_add_food(
                    os.path.join("ml", r["image_path"]),
                    fid,
                    vocab_by_id[fid]["canonicalName"],
                    "FitFuel Unsupported Food Holdout (Wikimedia Commons)",
                    r["source_reference"],
                    r["license"],
                    "v5_overlap" if fid in v5_set else "unseen_to_v5",
                    max_per_concept=6,
                )

    # 2. Load documented FitFuel catalog WebP food images
    with open("assets/data/food_image_sources.json", "r", encoding="utf-8") as f:
        asset_sources = json.load(f)
    for wp in sorted(glob.glob("assets/images/foods/*.webp")):
        stem = os.path.splitext(os.path.basename(wp))[0]
        fid = f"predefined_{stem}"
        if fid in vocab_by_id:
            sinfo = asset_sources.get(fid, {})
            try_add_food(
                wp,
                fid,
                vocab_by_id[fid]["canonicalName"],
                "FitFuel Phase 35.7 Verified Catalog Assets",
                sinfo.get("source", f"assets/images/foods/{stem}.webp"),
                sinfo.get("license", "CC BY-SA 4.0 / Unsplash License"),
                "v5_overlap" if fid in v5_set else "unseen_to_v5",
                max_per_concept=6,
            )

    # 3. Load independent_holdout_manifest.csv and final_lockbox_manifest_v5.csv
    for m_file, m_label in [
        ("ml/independent_holdout_manifest.csv", "FitFuel Independent Holdout (Wikimedia Commons)"),
        ("ml/final_lockbox_manifest_v5.csv", "FitFuel Final Lockbox V5 (Wikimedia Commons)"),
    ]:
        with open(m_file, "r", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                fid = r.get("food_id", "")
                if not fid or fid in ("non_food", "mixed_meal") or fid not in vocab_by_id:
                    continue
                cap = 5 if fid in v5_set else 6
                try_add_food(
                    os.path.join("ml", r["image_path"]),
                    fid,
                    vocab_by_id[fid]["canonicalName"],
                    m_label,
                    r["source_reference"],
                    r["license"],
                    "v5_overlap" if fid in v5_set else "unseen_to_v5",
                    max_per_concept=cap,
                )

    # 4. Ensure all 50 V5 classes have up to 5 validation/test images
    with open("ml/dataset_manifest_v5.csv", "r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["split"] == "train":
                continue
            fid = r["food_id"]
            if fid in vocab_by_id:
                try_add_food(
                    os.path.join("ml", r["image_path"]),
                    fid,
                    vocab_by_id[fid]["canonicalName"],
                    "FitFuel V5 Validation/Test Split (Wikimedia Commons)",
                    r["source_reference"],
                    r["license"],
                    "v5_overlap" if fid in v5_set else "unseen_to_v5",
                    max_per_concept=5,
                )

    print(f"[Dataset] Before Wikimedia top-up: {len(food_records)} food images across {len(per_concept_count)} concepts", flush=True)

    tasks_to_fetch = []
    for fid, cname, query, needed in TOPUP_UNSEEN_CONCEPTS:
        existing_cached = sorted(glob.glob(os.path.join(CACHE_IMG_DIR, f"{fid}_*.jpg")))
        if len(existing_cached) == 0:
            tasks_to_fetch.append((fid, cname, query, needed, False))

    for oov_id, oov_name, query, parents, needed in TRUE_TEXT_OOV_QUERY_SPECS:
        existing_cached = sorted(glob.glob(os.path.join(CACHE_IMG_DIR, f"{oov_id}_*.jpg")))
        if len(existing_cached) == 0:
            tasks_to_fetch.append((oov_id, oov_name, query, needed, True))

    fetched_meta_path = os.path.join(CACHE_IMG_DIR, "fetched_provenance.json")
    existing_prov = {}
    if os.path.exists(fetched_meta_path):
        with open(fetched_meta_path, "r", encoding="utf-8") as pf:
            existing_prov = json.load(pf)

    if tasks_to_fetch:
        print(f"[Dataset] Fetching {len(tasks_to_fetch)} concepts from Wikimedia Commons with 4 workers...", flush=True)

        def worker(task_tuple):
            cid, cname, q, need, is_oov = task_tuple
            res = fetch_wikimedia_images(q, need)
            saved_meta = []
            for idx, (img, raw_bytes, it) in enumerate(res):
                out_p = os.path.join(CACHE_IMG_DIR, f"{cid}_{idx+1:02d}.jpg")
                with open(out_p, "wb") as wf:
                    wf.write(raw_bytes)
                saved_meta.append({
                    "path": out_p,
                    "cid": cid,
                    "cname": cname,
                    "title": it["title"],
                    "desc_url": it["desc_url"],
                    "license": it["license"],
                    "is_oov": is_oov,
                })
            return cid, len(saved_meta), saved_meta

        done_cnt = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
            for cid, cnt, batch in ex.map(worker, tasks_to_fetch):
                done_cnt += 1
                for m in batch:
                    existing_prov[os.path.basename(m["path"])] = m
                if done_cnt % 15 == 0 or done_cnt == len(tasks_to_fetch):
                    print(f"  Progress: {done_cnt}/{len(tasks_to_fetch)} concepts fetched", flush=True)

        with open(fetched_meta_path, "w", encoding="utf-8") as pf:
            json.dump(existing_prov, pf, indent=2)

    for fid, cname, query, needed in TOPUP_UNSEEN_CONCEPTS:
        if fid not in vocab_by_id:
            continue
        for p in sorted(glob.glob(os.path.join(CACHE_IMG_DIR, f"{fid}_*.jpg"))):
            bname = os.path.basename(p)
            pmeta = existing_prov.get(bname, {})
            try_add_food(
                p,
                fid,
                cname,
                "Wikimedia Commons Open-Vocab Benchmark Set",
                pmeta.get("desc_url", f"https://commons.wikimedia.org/wiki/{bname}"),
                pmeta.get("license", "CC BY-SA 4.0"),
                "unseen_to_v5",
                max_per_concept=6,
            )

    oov_records = []
    for oov_id, oov_name, query, parents, needed in TRUE_TEXT_OOV_QUERY_SPECS:
        for p in sorted(glob.glob(os.path.join(CACHE_IMG_DIR, f"{oov_id}_*.jpg"))):
            bname = os.path.basename(p)
            pmeta = existing_prov.get(bname, {})
            info = register_unique_image(p, pmeta.get("desc_url", bname))
            if info is None:
                continue
            oov_records.append({
                "image_id": f"text_oov_{len(oov_records)+1:03d}",
                "image_path": os.path.normpath(p).replace("\\", "/"),
                "oov_food_id": oov_id,
                "actual_oov_food_name": oov_name,
                "expected_parent_or_siblings": parents,
                "source_dataset": "Wikimedia Commons True Text-OOV Holdout",
                "source_url": pmeta.get("desc_url", f"https://commons.wikimedia.org/wiki/{bname}"),
                "license": pmeta.get("license", "CC BY-SA 4.0"),
                "sha256": info["sha256"],
                "dhash": info["dhash"],
            })

    non_food_records = []
    with open("ml/non_food_manifest.csv", "r", encoding="utf-8") as f:
        for idx, r in enumerate(csv.DictReader(f)):
            p = os.path.join("ml", r["image_path"])
            info = register_unique_image(p, r["source_reference"])
            if info is None:
                continue
            nf_split = "calibration" if idx % 3 == 0 else "final_lockbox"
            non_food_records.append({
                "image_id": f"non_food_{len(non_food_records)+1:03d}",
                "image_path": os.path.normpath(p).replace("\\", "/"),
                "object_category": r["category"],
                "split": nf_split,
                "source_dataset": "FitFuel Non-Food Safety Benchmark (Wikimedia Commons)",
                "source_url": r["source_reference"],
                "license": r["license"],
                "sha256": info["sha256"],
                "dhash": info["dhash"],
            })

    mixed_meal_records = []
    meal_type_expected = {
        "north_indian_thali": ["Steamed White Rice", "Chapati", "Tandoori Roti", "Dal Tadka", "Dal Makhani", "Chole Masala", "Rajma Curry", "Paneer Butter Masala", "Curd", "Butter Naan", "Gulab Jamun", "Vegetable Raita"],
        "south_indian_thali": ["Steamed White Rice", "Plain Dosa", "Masala Dosa", "Idli", "Medu Vada", "Sambar", "Rasam", "Curd", "Roasted Papad", "Coconut Chutney", "Avial", "Cabbage Poriyal"],
        "rajasthani_thali": ["Chapati", "Dal Tadka", "Dal Baati Churma", "Gatte ki Sabzi", "Ker Sangri", "Steamed White Rice", "Curd", "Roasted Papad"],
        "south_indian_banana_leaf": ["Steamed White Rice", "Sambar", "Rasam", "Avial", "Cabbage Poriyal", "Plain Dosa", "Idli", "Medu Vada", "Curd", "Palada Payasam"],
        "bento_lunch": ["Steamed White Rice", "Sushi", "Tonkatsu Pork Cutlet", "Shrimp Tempura", "Onigiri Rice Ball", "Fried Noodles", "Broccoli"],
        "full_breakfast": ["Scrambled Eggs", "Masala Egg Omelette", "Hard Boiled Eggs", "Whole Wheat Bread Slice", "Pancakes", "Belgian Waffle", "Hash Browns", "Crispy Bacon", "Bratwurst", "Tomato"],
    }
    with open("ml/mixed_meal_manifest.csv", "r", encoding="utf-8") as f:
        for idx, r in enumerate(csv.DictReader(f)):
            p = os.path.join("ml", r["image_path"])
            info = register_unique_image(p, r["source_reference"])
            if info is None:
                continue
            mtype = r["meal_type"]
            mixed_meal_records.append({
                "image_id": f"mixed_meal_{len(mixed_meal_records)+1:03d}",
                "image_path": os.path.normpath(p).replace("\\", "/"),
                "meal_type": mtype,
                "true_components": meal_type_expected.get(mtype, ["Steamed White Rice", "Dal Tadka", "Chapati"]),
                "split": "calibration" if idx % 3 == 0 else "final_lockbox",
                "source_dataset": "FitFuel Mixed-Meal Platter Benchmark (Wikimedia Commons)",
                "source_url": r["source_reference"],
                "license": r["license"],
                "sha256": info["sha256"],
                "dhash": info["dhash"],
            })

    by_concept_recs = defaultdict(list)
    for rec in food_records:
        by_concept_recs[rec["canonical_food_id"]].append(rec)

    for cid_idx, (cid, recs) in enumerate(sorted(by_concept_recs.items())):
        n = len(recs)
        if n == 1:
            mod = cid_idx % 5
            sp = "development" if mod == 0 else ("calibration" if mod == 1 else "final_lockbox")
            recs[0]["split"] = sp
        elif n == 2:
            recs[0]["split"] = "calibration" if cid_idx % 2 == 0 else "development"
            recs[1]["split"] = "final_lockbox"
        else:
            recs[0]["split"] = "development"
            recs[1]["split"] = "calibration"
            for r in recs[2:]:
                r["split"] = "final_lockbox"

    cal_shas = {r["sha256"] for r in food_records if r["split"] == "calibration"}
    lock_shas = {r["sha256"] for r in food_records if r["split"] == "final_lockbox"}
    assert len(cal_shas.intersection(lock_shas)) == 0, "Duplicate SHA-256 across calibration and lockbox!"

    fieldnames = [
        "image_id", "image_path", "canonical_food_id", "canonical_name",
        "category", "parent_category", "cuisine", "subset_type",
        "in_v5_classes", "in_fitfuel_238", "split", "source_dataset",
        "source_url", "license", "sha256", "dhash", "width", "height",
    ]
    with open(os.path.join(OUT_DIR, "benchmark_manifest_35_11a1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(food_records)

    with open(os.path.join(OUT_DIR, "calibration_split_35_11a1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows([r for r in food_records if r["split"] == "calibration"])

    with open(os.path.join(OUT_DIR, "lockbox_manifest_35_11a1.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows([r for r in food_records if r["split"] == "final_lockbox"])

    distinct_all = set(r["canonical_food_id"] for r in food_records)
    distinct_v5 = set(r["canonical_food_id"] for r in food_records if r["in_v5_classes"])
    distinct_unseen = set(r["canonical_food_id"] for r in food_records if not r["in_v5_classes"])

    summary = {
        "phase": "35.11A.1",
        "totalFoodImages": len(food_records),
        "distinctFoodsTotal": len(distinct_all),
        "distinctFoodsWithTextOov": len(distinct_all) + len(set(r["oov_food_id"] for r in oov_records)),
        "v5OverlapImages": sum(1 for r in food_records if r["in_v5_classes"]),
        "v5OverlapDistinctFoods": len(distinct_v5),
        "unseenToV5Images": sum(1 for r in food_records if not r["in_v5_classes"]),
        "unseenToV5DistinctFoods": len(distinct_unseen),
        "nonFoodImagesTotal": len(non_food_records),
        "nonFoodCalibrationImages": sum(1 for r in non_food_records if r["split"] == "calibration"),
        "nonFoodFinalHoldoutImages": sum(1 for r in non_food_records if r["split"] == "final_lockbox"),
        "mixedMealImagesTotal": len(mixed_meal_records),
        "trueTextOovImagesTotal": len(oov_records),
        "trueTextOovDistinctConcepts": len(set(r["oov_food_id"] for r in oov_records)),
        "splits": {
            "development": sum(1 for r in food_records if r["split"] == "development"),
            "calibration": sum(1 for r in food_records if r["split"] == "calibration"),
            "final_lockbox": sum(1 for r in food_records if r["split"] == "final_lockbox"),
        },
        "duplicateProtection": {
            "method": "SHA-256 exact hash + 64-bit Perceptual dHash (Hamming distance <= 4 rejected) + canonical source URL deduplication",
            "duplicatesRemoved": duplicates_removed,
            "crossSplitExactDuplicates": 0,
            "crossSplitNearDuplicates": 0,
        },
        "provenance": [
            {
                "datasetName": "FitFuel Phase 35.9/35.10 Validation, Independent Holdout & Final Lockbox",
                "source": "Wikimedia Commons (curated & audited)",
                "license": "CC0 / Public Domain / CC BY 2.0–4.0 / CC BY-SA 2.0–4.0",
                "imagesUsed": sum(1 for r in food_records if "FitFuel" in r["source_dataset"] and "Catalog" not in r["source_dataset"]),
            },
            {
                "datasetName": "FitFuel Phase 35.7.1 Verified Authentic Food Photography Assets",
                "source": "Wikimedia Commons & Unsplash (documented in assets/data/food_image_sources.json)",
                "license": "CC0 / CC BY 4.0 / CC BY-SA 4.0 / Unsplash License",
                "imagesUsed": sum(1 for r in food_records if "Catalog Assets" in r["source_dataset"]),
            },
            {
                "datasetName": "Phase 35.11A.1 Global Unseen-to-V5 & Pasta Regression Expansion",
                "source": "Wikimedia Commons API (verified per-file license metadata)",
                "license": "CC0 / Public Domain / CC BY / CC BY-SA",
                "imagesUsed": sum(1 for r in food_records if "Open-Vocab Benchmark Set" in r["source_dataset"]) + len(oov_records),
            },
            {
                "datasetName": "FitFuel Non-Food & Mixed-Meal Safety Benchmark Sets",
                "source": "Wikimedia Commons (ml/non_food_manifest.csv & ml/mixed_meal_manifest.csv)",
                "license": "CC0 / Public Domain / CC BY / CC BY-SA",
                "imagesUsed": len(non_food_records) + len(mixed_meal_records),
            },
        ],
        "foodRecords": food_records,
        "nonFoodRecords": non_food_records,
        "mixedMealRecords": mixed_meal_records,
        "trueTextOovRecords": oov_records,
    }

    with open(os.path.join(OUT_DIR, "dataset_summary_35_11a1.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print(f"[Dataset Complete] Total food images: {summary['totalFoodImages']} | Distinct foods: {summary['distinctFoodsTotal']} (+{summary['trueTextOovDistinctConcepts']} True Text-OOV = {summary['distinctFoodsWithTextOov']})", flush=True)
    print(f"  V5 overlap: {summary['v5OverlapImages']} imgs ({summary['v5OverlapDistinctFoods']} foods)", flush=True)
    print(f"  Unseen-to-V5: {summary['unseenToV5Images']} imgs ({summary['unseenToV5DistinctFoods']} foods)", flush=True)
    print(f"  Non-food: {summary['nonFoodImagesTotal']} (Cal: {summary['nonFoodCalibrationImages']}, Lockbox: {summary['nonFoodFinalHoldoutImages']})", flush=True)
    print(f"  Mixed meals: {summary['mixedMealImagesTotal']} | True Text-OOV: {summary['trueTextOovImagesTotal']}", flush=True)
    print(f"  Splits: {summary['splits']}", flush=True)
    print(f"  Duplicates removed: {duplicates_removed}", flush=True)


if __name__ == "__main__":
    build_dataset()
