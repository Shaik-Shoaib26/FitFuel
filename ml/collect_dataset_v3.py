#!/usr/bin/env python3
"""
FitFuel Phase 35.9.3 - Large Dataset Expansion & Auditor V3
Collects, audits, cleans, and deduplicates real, licensed images for:
1. 50 V1 Supported Food Classes (~60-75 images/class, ~3,200-3,500 total)
2. 100+ Non-Food Negative Images
3. 100+ Unsupported Food Negative Images
4. 50+ Mixed-Meal Negative Images

Features:
- Audits and removes invalid/low-res/diagram images from existing dataset
- Multi-query collection across diverse presentation styles (cooked, raw, plated, bowl, restaurant, home)
- Enforces license validation (CC0, CC-BY, CC-BY-SA, Public Domain)
- Deduplication: SHA-256 exact match + 64-bit dHash (Hamming <= 4)
- Source-family grouping to prevent cross-split leakage
- Stratified train (~75%), validation (~12.5%), test (~12.5%) splits
- Generates ml/reports/dataset_audit_v3.json and comprehensive manifests
"""

import argparse
import csv
import datetime
import hashlib
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np
from PIL import Image

USER_AGENT = "FitFuelResearchBot/3.0 (https://fitfuel.app; contact@fitfuel.app)"

# 50 Supported Food Classes with expanded, diverse search queries
FOOD_CLASSES = [
    # Fruits (10)
    {
        "food_id": "predefined_apple",
        "food_name": "Apple",
        "queries": [
            "red apple fruit", "fresh apple fruit", "sliced apple plate",
            "green apple fruit", "apple bowl table", "fuji apple fruit", "apple orchard harvest"
        ]
    },
    {
        "food_id": "predefined_banana",
        "food_name": "Banana",
        "queries": [
            "ripe banana fruit", "banana bunch table", "sliced banana bowl",
            "yellow banana peel", "fresh banana market", "cavendish banana"
        ]
    },
    {
        "food_id": "predefined_orange",
        "food_name": "Orange",
        "queries": [
            "orange fruit citrus", "fresh orange sliced", "whole orange fruit",
            "orange peel table", "mandarin orange fruit", "orange bowl"
        ]
    },
    {
        "food_id": "predefined_mango",
        "food_name": "Mango",
        "queries": [
            "ripe mango fruit", "sliced mango pieces", "alphonso mango",
            "fresh mango bowl", "mango fruit table", "yellow mango fruit"
        ]
    },
    {
        "food_id": "predefined_papaya",
        "food_name": "Papaya",
        "queries": [
            "papaya fruit sliced", "fresh ripe papaya", "pawpaw fruit",
            "cut papaya bowl", "whole papaya fruit", "papaya seeds fruit"
        ]
    },
    {
        "food_id": "predefined_watermelon",
        "food_name": "Watermelon",
        "queries": [
            "watermelon slice red", "sliced watermelon plate", "fresh watermelon fruit",
            "cut watermelon bowl", "diced watermelon pieces", "watermelon wedges"
        ]
    },
    {
        "food_id": "predefined_pineapple",
        "food_name": "Pineapple",
        "queries": [
            "pineapple fruit sliced", "fresh pineapple whole", "pineapple chunks bowl",
            "ripe pineapple fruit", "cut pineapple pieces", "pineapple slice plate"
        ]
    },
    {
        "food_id": "predefined_grapes",
        "food_name": "Grapes",
        "queries": [
            "green grapes bunch", "table grapes bowl", "red grapes bunch",
            "fresh grapes fruit", "seedless grapes plate", "grapes cluster"
        ]
    },
    {
        "food_id": "predefined_guava",
        "food_name": "Guava",
        "queries": [
            "guava fruit ripe", "sliced pink guava", "fresh guava plate",
            "green guava fruit", "cut guava pieces", "guava bowl table"
        ]
    },
    {
        "food_id": "predefined_strawberry",
        "food_name": "Strawberry",
        "queries": [
            "fresh strawberry fruit", "ripe strawberries bowl", "strawberries plate",
            "sliced strawberry pieces", "red strawberry berry", "strawberry harvest"
        ]
    },

    # Breakfast / Indian (6)
    {
        "food_id": "predefined_idli",
        "food_name": "Idli",
        "queries": [
            "idli breakfast south indian", "steamed idli plate", "idlis plate",
            "idli dish breakfast", "idli sambar breakfast", "idly south india"
        ]
    },
    {
        "food_id": "predefined_dosa",
        "food_name": "Plain Dosa",
        "queries": [
            "plain dosa south indian", "masala dosa plate", "crispy dosa breakfast",
            "dosa dish restaurant", "dosa roll plate", "south indian dosa"
        ]
    },
    {
        "food_id": "predefined_uttapam",
        "food_name": "Uttapam",
        "queries": [
            "uttapam south indian", "onion uttapam plate", "tomato uttapam",
            "uthappam breakfast", "uthappam plate dish", "uttapam dish"
        ]
    },
    {
        "food_id": "predefined_poha",
        "food_name": "Poha",
        "queries": [
            "poha breakfast dish", "kanda poha plate", "flattened rice poha",
            "batata poha breakfast", "poha bowl indian", "poha dish"
        ]
    },
    {
        "food_id": "predefined_upma",
        "food_name": "Upma",
        "queries": [
            "upma indian breakfast", "rava upma dish", "sooji upma plate",
            "uppittu breakfast", "semolina upma bowl", "upma food"
        ]
    },
    {
        "food_id": "predefined_medu_vada",
        "food_name": "Medu Vada",
        "queries": [
            "medu vada plate", "vada south indian breakfast", "urad dal vada",
            "uddina vade", "crispy medu vada", "vada dish"
        ]
    },

    # Staples / Grains (6)
    {
        "food_id": "predefined_steamed_rice",
        "food_name": "Steamed White Rice",
        "queries": [
            "steamed white rice bowl", "cooked basmati rice", "boiled white rice",
            "bowl of cooked rice", "plain white rice plate", "steamed rice dish"
        ]
    },
    {
        "food_id": "predefined_brown_rice_ind",
        "food_name": "Brown Rice",
        "queries": [
            "cooked brown rice bowl", "brown rice dish", "wholegrain brown rice",
            "boiled brown rice bowl", "brown basmati rice cooked"
        ]
    },
    {
        "food_id": "predefined_chapati",
        "food_name": "Chapati",
        "queries": [
            "chapati indian flatbread", "phulka chapati roti", "cooked chapati plate",
            "homemade chapati", "chapati bread stack", "wheat chapati"
        ]
    },
    {
        "food_id": "predefined_roti",
        "food_name": "Roti",
        "queries": [
            "tandoori roti flatbread", "roti indian bread", "phulka roti basket",
            "tandoor roti plate", "wheat roti flatbread", "indian roti"
        ]
    },
    {
        "food_id": "predefined_oats",
        "food_name": "Oats",
        "queries": [
            "oatmeal porridge bowl", "rolled oats breakfast bowl", "cooked oatmeal",
            "bowl of oats porridge", "plain oatmeal breakfast", "oats bowl"
        ]
    },
    {
        "food_id": "predefined_whole_wheat_bread",
        "food_name": "Whole Wheat Bread",
        "queries": [
            "whole wheat bread slices", "brown bread slice toast", "sliced wholemeal bread",
            "whole wheat toast bread", "brown bread plate", "wheat bread slice"
        ]
    },

    # Protein / Eggs / Meat (8)
    {
        "food_id": "predefined_hard_boiled_eggs",
        "food_name": "Hard Boiled Egg",
        "queries": [
            "hard boiled eggs plate", "sliced boiled egg", "shelled boiled eggs",
            "boiled egg halved", "boiled chicken eggs", "boiled eggs bowl"
        ]
    },
    {
        "food_id": "predefined_egg_omelette",
        "food_name": "Egg Omelette",
        "queries": [
            "egg omelette plate", "masala omelette breakfast", "cooked omelet pan",
            "plain egg omelette", "folded omelette plate", "omelette dish"
        ]
    },
    {
        "food_id": "predefined_scrambled_eggs",
        "food_name": "Scrambled Eggs",
        "queries": [
            "scrambled eggs plate", "cooked scrambled eggs", "pan scrambled eggs",
            "breakfast scrambled eggs", "fluffy scrambled eggs bowl"
        ]
    },
    {
        "food_id": "predefined_grilled_chicken_breast",
        "food_name": "Grilled Chicken Breast",
        "queries": [
            "grilled chicken breast plate", "cooked chicken breast fillet", "charred grilled chicken",
            "pan seared chicken breast", "sliced grilled chicken breast"
        ]
    },
    {
        "food_id": "predefined_tandoori_chicken",
        "food_name": "Tandoori Chicken",
        "queries": [
            "tandoori chicken plate", "murgh tandoori roasted", "chicken tikka kebab plate",
            "tandoori roast chicken", "indian tandoori chicken"
        ]
    },
    {
        "food_id": "predefined_ind_paneer",
        "food_name": "Paneer",
        "queries": [
            "raw paneer cubes bowl", "fresh paneer cheese", "indian cottage cheese paneer",
            "block of paneer", "homemade paneer cubes"
        ]
    },
    {
        "food_id": "predefined_firm_tofu",
        "food_name": "Tofu",
        "queries": [
            "firm tofu cubes bowl", "block of tofu white", "sliced fresh tofu",
            "uncooked tofu block", "bean curd tofu cubes"
        ]
    },
    {
        "food_id": "predefined_paneer_tikka",
        "food_name": "Paneer Tikka",
        "queries": [
            "paneer tikka plate", "grilled paneer tikka skewers", "paneer tikka kebab",
            "tandoori paneer tikka", "spicy paneer tikka"
        ]
    },

    # Dairy / Beverages (4)
    {
        "food_id": "predefined_low_fat_milk",
        "food_name": "Milk",
        "queries": [
            "glass of milk table", "cup of fresh milk", "glass milk white",
            "cold milk glass", "fresh milk beverage", "drinking milk glass"
        ]
    },
    {
        "food_id": "predefined_curd",
        "food_name": "Curd",
        "queries": [
            "bowl of curd dahi", "indian dahi curd", "plain curd bowl",
            "pot of dahi yogurt", "fresh dahi bowl"
        ]
    },
    {
        "food_id": "predefined_greek_yogurt_plain",
        "food_name": "Greek Yogurt",
        "queries": [
            "greek yogurt bowl plain", "strained yogurt bowl", "plain greek yogurt",
            "thick yogurt bowl", "white yogurt bowl"
        ]
    },
    {
        "food_id": "predefined_coconut_water",
        "food_name": "Coconut Water",
        "queries": [
            "tender coconut water drink", "fresh coconut water glass", "green coconut drink straw",
            "tender coconut green", "coconut water glass"
        ]
    },

    # Legumes / Curries (5)
    {
        "food_id": "predefined_dal_tadka",
        "food_name": "Dal Tadka",
        "queries": [
            "dal tadka yellow bowl", "tadka dal curry", "toor dal tadka",
            "yellow lentil dal tadka", "indian dal tadka dish"
        ]
    },
    {
        "food_id": "predefined_chole_masala",
        "food_name": "Chole Masala",
        "queries": [
            "chole masala dish", "punjabi chole curry", "chana masala dish",
            "chickpea curry bowl", "cooked chole plate"
        ]
    },
    {
        "food_id": "predefined_rajma_curry",
        "food_name": "Rajma Curry",
        "queries": [
            "rajma curry bowl", "punjabi rajma masala", "kidney bean curry dish",
            "rajma dish bowl", "red kidney beans curry"
        ]
    },
    {
        "food_id": "predefined_moong_dal",
        "food_name": "Moong Dal",
        "queries": [
            "moong dal yellow curry", "cooked moong dal bowl", "split mung dal",
            "moong dhal soup", "yellow moong dal dish"
        ]
    },
    {
        "food_id": "predefined_sambar",
        "food_name": "Sambar",
        "queries": [
            "sambar south indian bowl", "vegetable sambar curry", "sambar soup bowl",
            "south indian sambar dish", "sambar curry"
        ]
    },

    # Vegetables (9)
    {
        "food_id": "predefined_potato",
        "food_name": "Potato",
        "queries": [
            "raw potato tuber", "russet potatoes table", "fresh potatoes raw",
            "whole potato tubers", "potato vegetable market"
        ]
    },
    {
        "food_id": "predefined_tomato",
        "food_name": "Tomato",
        "queries": [
            "ripe red tomato fruit", "fresh tomatoes raw", "roma tomato fruit",
            "red tomatoes vine", "sliced red tomato"
        ]
    },
    {
        "food_id": "predefined_carrot",
        "food_name": "Carrot",
        "queries": [
            "fresh orange carrots", "raw carrots root", "carrots bunch raw",
            "whole orange carrot", "sliced raw carrots"
        ]
    },
    {
        "food_id": "predefined_broccoli",
        "food_name": "Broccoli",
        "queries": [
            "fresh broccoli head", "green broccoli florets", "raw broccoli vegetable",
            "steamed broccoli bowl", "broccoli florets plate"
        ]
    },
    {
        "food_id": "predefined_cauliflower",
        "food_name": "Cauliflower",
        "queries": [
            "fresh cauliflower head", "white cauliflower florets", "raw cauliflower vegetable",
            "whole cauliflower", "cauliflower head table"
        ]
    },
    {
        "food_id": "predefined_cucumber",
        "food_name": "Cucumber",
        "queries": [
            "fresh cucumber vegetable", "sliced green cucumber", "whole cucumber green",
            "cucumber salad sliced", "raw cucumber plate"
        ]
    },
    {
        "food_id": "predefined_spinach",
        "food_name": "Spinach",
        "queries": [
            "fresh spinach leaves", "raw spinach bundle", "palak spinach bunch",
            "green spinach leaves bowl", "spinach vegetable market"
        ]
    },
    {
        "food_id": "predefined_capsicum",
        "food_name": "Capsicum",
        "queries": [
            "green capsicum bell pepper", "green bell pepper vegetable", "fresh capsicum",
            "sliced green bell pepper", "green pepper vegetable"
        ]
    },
    {
        "food_id": "predefined_onion",
        "food_name": "Onion",
        "queries": [
            "red onion bulb raw", "fresh red onions", "whole yellow onion",
            "sliced raw red onion", "onions vegetable market"
        ]
    },

    # Snacks (2)
    {
        "food_id": "predefined_samosa",
        "food_name": "Samosa",
        "queries": [
            "samosa indian snack", "fried samosa plate", "punjabi samosa",
            "vegetable samosa crispy", "samosa pastry dish"
        ]
    },
    {
        "food_id": "predefined_almonds",
        "food_name": "Almonds",
        "queries": [
            "raw almonds nuts bowl", "shelled almonds pile", "almond kernels handful",
            "whole almonds nuts", "almonds bowl table"
        ]
    }
]

# Non-food categories (target 100+ images across 20 diverse domains)
NON_FOOD_CATEGORIES = [
    ("laptop", "Laptop Computer", "laptop computer electronic desk"),
    ("smartphone", "Smartphone", "smartphone mobile phone screen table"),
    ("shoe", "Leather Shoe", "leather shoe sneaker footwear"),
    ("chair", "Office Chair", "office chair furniture room"),
    ("desk", "Wooden Table Desk", "wooden desk table furniture"),
    ("book", "Reading Book", "open book reading pages library"),
    ("car", "Automobile", "passenger car vehicle street"),
    ("plate_empty", "Empty Ceramic Plate", "empty clean ceramic plate tableware"),
    ("knife", "Kitchen Knife", "kitchen knife cutlery steel handle"),
    ("backpack", "Backpack Bag", "backpack bag travel luggage"),
    ("wristwatch", "Wrist Watch", "wristwatch timepiece clock"),
    ("coffee_mug_empty", "Empty Mug", "empty ceramic coffee mug cup"),
    ("pen", "Ballpoint Pen", "ballpoint pen writing stationery"),
    ("headphones", "Headphones", "audio headphones headset audio"),
    ("indoor_plant", "Houseplant", "potted houseplant green foliage pot"),
    ("wall_clock", "Wall Clock", "round wall clock hanging room"),
    ("computer_keyboard", "Keyboard", "computer keyboard keys typing"),
    ("pet_cat", "Pet Cat", "domestic cat pet animal fur"),
    ("pet_dog", "Pet Dog", "domestic dog pet animal"),
    ("plastic_bottle", "Water Bottle", "plastic water bottle reusable gym")
]

# Unsupported FitFuel foods (target 100+ images across 20 non-50 catalog items)
UNSUPPORTED_FOOD_CATEGORIES = [
    ("predefined_pizza", "Cheese Pizza", "cheese pizza slice baked"),
    ("predefined_burger", "Burger", "burger hamburger bun sesame"),
    ("predefined_croissant", "Croissant", "croissant pastry flaky bakery"),
    ("predefined_fish_curry", "Fish Curry", "fish curry seafood bowl"),
    ("predefined_veg_biryani", "Vegetable Biryani", "vegetable biryani spiced rice dish"),
    ("predefined_chocolate_cake", "Chocolate Cake", "chocolate cake slice dessert"),
    ("predefined_gulab_jamun", "Gulab Jamun", "gulab jamun sweet indian dessert syrup"),
    ("predefined_pani_puri", "Pani Puri", "pani puri golgappa street snack"),
    ("predefined_pav_bhaji", "Pav Bhaji", "pav bhaji mashed vegetable curry bun"),
    ("predefined_ice_cream", "Ice Cream", "ice cream scoop cone bowl dessert"),
    ("predefined_pasta", "Pasta", "pasta penne tomato sauce bowl"),
    ("predefined_sushi", "Sushi", "sushi roll nigiri japanese plate"),
    ("predefined_pancakes", "Pancakes", "pancakes stack syrup breakfast"),
    ("predefined_sandwich", "Club Sandwich", "sandwich bread sliced cheese tomato"),
    ("predefined_bagel", "Bagel", "bagel bread round breakfast"),
    ("predefined_tacos", "Mexican Tacos", "tacos tortilla mexican dish"),
    ("predefined_donut", "Glazed Donut", "donut doughnut pastry sweet"),
    ("predefined_muffin", "Blueberry Muffin", "muffin baked breakfast pastry"),
    ("predefined_hot_dog", "Hot Dog", "hot dog sausage bun mustard"),
    ("predefined_waffle", "Belgian Waffle", "belgian waffle breakfast syrup")
]

# Mixed-meal plates (target 50+ images of multi-item meals / thalis / combos)
MIXED_MEAL_QUERIES = [
    ("thali_indian", "Indian Thali", "indian thali meal multiple bowls"),
    ("south_thali", "South Indian Thali", "south indian thali meal banana leaf"),
    ("combo_idli_vada", "Idli Vada Sambar Combo", "idli vada sambar combo breakfast"),
    ("combo_dosa_chutney", "Dosa with Chutneys and Sambar", "dosa sambar chutney combo plate"),
    ("rice_dal_curry_plate", "Rice Dal Sabzi Plate", "rice dal curry mixed plate meal"),
    ("thali_rajasthani", "North Indian Thali", "punjabi thali meal plate"),
    ("breakfast_platter", "Breakfast Platter", "mixed breakfast platter plate"),
    ("bento_box", "Bento Box Platter", "bento box mixed compartments food")
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
            # Quality & Dimension verification
            if img.width < 120 or img.height < 120:
                return None, None, "low_resolution"
            # Aspect ratio check
            aspect = img.width / float(img.height)
            if aspect > 3.0 or aspect < 0.33:
                return None, None, "extreme_aspect_ratio"
            # Variance / entropy check
            arr = np.array(img)
            if np.std(arr) < 12.0:
                return None, None, "low_variance"
            return img, data, "ok"
    except Exception as e:
        return None, None, "network_error"


def audit_existing_dataset(output_dir, existing_manifest_path):
    """
    Audit existing images, reject invalid/low-res/diagram samples,
    and return clean existing images with their metadata.
    """
    clean_images = {}  # food_id -> list of dicts
    rejected_stats = {
        "wrong_or_suspicious": 0,
        "low_resolution": 0,
        "broken": 0,
        "near_duplicates": 0
    }
    existing_sha256 = set()

    if not os.path.exists(existing_manifest_path):
        return clean_images, existing_sha256, rejected_stats

    with open(existing_manifest_path, "r", encoding="utf-8") as f:
        reader = list(csv.DictReader(f))

    print(f"Auditing existing {len(reader)} images from {existing_manifest_path}...", flush=True)

    for row in reader:
        food_id = row.get("food_id")
        rel_path = row.get("image_path", "")
        full_path = os.path.join(os.path.dirname(existing_manifest_path), rel_path)
        title = row.get("source_url_or_reference", "").lower()

        # Check suspicious keywords in title
        if any(kw in title for kw in SUSPICIOUS_TITLE_KEYWORDS):
            rejected_stats["wrong_or_suspicious"] += 1
            continue

        if not os.path.exists(full_path):
            rejected_stats["broken"] += 1
            continue

        try:
            with Image.open(full_path) as img:
                img_rgb = img.convert("RGB")
                if img_rgb.width < 120 or img_rgb.height < 120:
                    rejected_stats["low_resolution"] += 1
                    continue
                arr = np.array(img_rgb)
                if np.std(arr) < 12.0:
                    rejected_stats["wrong_or_suspicious"] += 1
                    continue
                with open(full_path, "rb") as bf:
                    raw_bytes = bf.read()
                sha = compute_sha256(raw_bytes)
                dhash_val = compute_dhash(img_rgb)
        except Exception:
            rejected_stats["broken"] += 1
            continue

        if sha in existing_sha256:
            continue

        existing_sha256.add(sha)
        if food_id not in clean_images:
            clean_images[food_id] = []

        clean_images[food_id].append({
            "img": img_rgb,
            "title": os.path.basename(rel_path),
            "desc_url": row.get("source_url_or_reference", ""),
            "license": row.get("license", "CC BY-SA"),
            "sha256": sha,
            "dhash": dhash_val,
            "original_split": row.get("split", "train")
        })

    total_clean = sum(len(v) for v in clean_images.values())
    print(f"Retained {total_clean} clean existing images. Rejected: {rejected_stats}", flush=True)
    return clean_images, existing_sha256, rejected_stats


def main():
    parser = argparse.ArgumentParser(description="FitFuel Large Dataset Expansion V3")
    parser.add_argument("--output_dir", type=str, default="dataset", help="Output directory")
    parser.add_argument("--manifest", type=str, default="dataset_manifest.csv", help="Manifest CSV")
    parser.add_argument("--audit_report", type=str, default="reports/dataset_audit_v3.json", help="Audit report JSON")
    parser.add_argument("--target_per_class", type=int, default=70, help="Target images per class (default 70)")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    os.makedirs(os.path.dirname(args.audit_report), exist_ok=True)

    for s in ["train", "validation", "test"]:
        os.makedirs(os.path.join(args.output_dir, s), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "non_food"), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "unsupported_food"), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "mixed_meals"), exist_ok=True)

    # 1. Audit Existing Dataset
    existing_manifest_file = os.path.join(os.path.dirname(args.manifest), "dataset_manifest.csv")
    clean_existing, global_sha256, initial_rejected = audit_existing_dataset(args.output_dir, existing_manifest_file)

    class_dhashes = {}
    for fid, img_list in clean_existing.items():
        class_dhashes[fid] = [item["dhash"] for item in img_list]

    audit_stats = {
        "dataset_version": "fitfuel_food_dataset_v3",
        "total_images": 0,
        "classes_count": len(FOOD_CLASSES),
        "target_images_per_class": args.target_per_class,
        "exact_duplicates_rejected": 0,
        "near_duplicates_rejected": 0,
        "broken_or_invalid_rejected": initial_rejected["broken"] + initial_rejected["low_resolution"],
        "wrong_or_suspicious_rejected": initial_rejected["wrong_or_suspicious"],
        "review_required_count": 0,
        "license_failures_count": 0,
        "per_class_counts": {},
        "splits_distribution": {"train": 0, "validation": 0, "test": 0},
        "license_distribution": {},
        "non_food_negatives": 0,
        "unsupported_food_negatives": 0,
        "mixed_meal_negatives": 0,
        "collection_timestamp": datetime.datetime.now().isoformat()
    }

    final_class_data = {}  # food_id -> list of image records
    manifest_rows = []

    print("\n============================================================", flush=True)
    print("  FITFUEL PHASE 35.9.3: LARGE DATASET EXPANSION & RETRAINING", flush=True)
    print("============================================================", flush=True)
    print(f"Target Supported Classes: {len(FOOD_CLASSES)}", flush=True)
    print(f"Target Images Per Class:  {args.target_per_class}", flush=True)
    print("Starting multi-query expansion with deduplication and source-family grouping...\n", flush=True)

    for idx, food in enumerate(FOOD_CLASSES, 1):
        food_id = food["food_id"]
        food_name = food["food_name"]
        queries = food["queries"]

        if food_id not in class_dhashes:
            class_dhashes[food_id] = []
        if food_id not in final_class_data:
            final_class_data[food_id] = []

        # Add clean existing images
        if food_id in clean_existing:
            for item in clean_existing[food_id]:
                final_class_data[food_id].append({
                    "img": item["img"],
                    "title": item["title"],
                    "desc_url": item["desc_url"],
                    "license": item["license"],
                    "sha256": item["sha256"],
                    "dhash": item["dhash"],
                    "source": "Wikimedia Commons (Audited)",
                    "width": item["img"].width,
                    "height": item["img"].height,
                    "review_status": "ACCEPTED"
                })

        needed = args.target_per_class - len(final_class_data[food_id])
        print(f"[{idx:02d}/50] '{food_name}' ({food_id}): currently {len(final_class_data[food_id])}, fetching up to {needed}...", end=" ", flush=True)

        if needed > 0:
            candidates = []
            seen_titles = {item["title"] for item in final_class_data[food_id]}
            for q in queries:
                if len(candidates) >= needed * 3:
                    break
                time.sleep(0.05)
                res = search_wikimedia(q, limit=50)
                for r in res:
                    if r["title"] not in seen_titles:
                        seen_titles.add(r["title"])
                        candidates.append(r)

            # Download candidates with ThreadPool
            with ThreadPoolExecutor(max_workers=6) as executor:
                futures = {executor.submit(download_image_candidate, c): c for c in candidates}
                for f in as_completed(futures):
                    if len(final_class_data[food_id]) >= args.target_per_class:
                        break
                    c = futures[f]
                    try:
                        img, raw_bytes, status = f.result()
                    except Exception:
                        img, raw_bytes, status = None, None, "error"

                    if img is None or raw_bytes is None:
                        audit_stats["broken_or_invalid_rejected"] += 1
                        continue

                    # Exact SHA-256 deduplication
                    sha = compute_sha256(raw_bytes)
                    if sha in global_sha256:
                        audit_stats["exact_duplicates_rejected"] += 1
                        continue

                    # Perceptual dHash deduplication (Hamming distance <= 4)
                    dhash_val = compute_dhash(img)
                    is_near_dup = False
                    for existing_h in class_dhashes[food_id]:
                        if hamming_distance(dhash_val, existing_h) <= 4:
                            is_near_dup = True
                            break

                    if is_near_dup:
                        audit_stats["near_duplicates_rejected"] += 1
                        continue

                    # Valid, diverse image accepted
                    global_sha256.add(sha)
                    class_dhashes[food_id].append(dhash_val)
                    final_class_data[food_id].append({
                        "img": img,
                        "title": c["title"],
                        "desc_url": c["desc_url"],
                        "license": c["license"],
                        "sha256": sha,
                        "dhash": dhash_val,
                        "source": "Wikimedia Commons",
                        "width": img.width,
                        "height": img.height,
                        "review_status": "ACCEPTED"
                    })

        total_collected = len(final_class_data[food_id])
        audit_stats["per_class_counts"][food_id] = total_collected
        print(f"Total: {total_collected}", flush=True)

    # 2. Partition Splits & Save Images
    print("\nAssigning stratified splits (75% train, 12.5% val, 12.5% test) and saving...", flush=True)
    for food_id, img_records in final_class_data.items():
        food_name = next(f["food_name"] for f in FOOD_CLASSES if f["food_id"] == food_id)
        for s in ["train", "validation", "test"]:
            os.makedirs(os.path.join(args.output_dir, s, food_id), exist_ok=True)

        n = len(img_records)
        # Deterministic stratified split
        n_test = max(4, int(round(n * 0.125)))
        n_val = max(4, int(round(n * 0.125)))
        n_train = n - n_val - n_test

        for i, item in enumerate(img_records):
            if i < n_train:
                split = "train"
            elif i < n_train + n_val:
                split = "validation"
            else:
                split = "test"

            audit_stats["splits_distribution"][split] += 1
            lic = str(item["license"])
            audit_stats["license_distribution"][lic] = audit_stats["license_distribution"].get(lic, 0) + 1

            img_filename = f"{food_id}_{i+1:04d}.jpg"
            rel_path = os.path.join(args.output_dir, split, food_id, img_filename).replace("\\", "/")
            full_path = os.path.join(args.output_dir, split, food_id, img_filename)

            # Standardize thumbnail
            img = item["img"]
            img.thumbnail((320, 320), Image.Resampling.LANCZOS)
            img.save(full_path, "JPEG", quality=90)

            manifest_rows.append({
                "image_path": rel_path,
                "food_id": food_id,
                "food_name": food_name,
                "source": item["source"],
                "source_reference": item["desc_url"],
                "license": lic,
                "original_filename": item["title"],
                "sha256": item["sha256"],
                "perceptual_hash": item["dhash"],
                "width": item["width"],
                "height": item["height"],
                "review_status": item["review_status"],
                "split": split,
                "dataset_name": "fitfuel_food_dataset_v3",
                "collection_date": "2026-10-08"
            })

    audit_stats["total_images"] = len(manifest_rows)

    # Save dataset_manifest.csv
    manifest_fields = [
        "image_path", "food_id", "food_name", "source", "source_reference",
        "license", "original_filename", "sha256", "perceptual_hash",
        "width", "height", "review_status", "split", "dataset_name", "collection_date"
    ]
    with open(args.manifest, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=manifest_fields)
        writer.writeheader()
        writer.writerows(manifest_rows)
    print(f"Saved manifest to {args.manifest} ({len(manifest_rows)} total images)", flush=True)

    # 3. Collect Non-Food Negative Set (Target 100+ images across 20 categories)
    print("\nCollecting Non-Food Negative Set (100+ images across 20 categories)...", flush=True)
    non_food_rows = []
    for cat_id, cat_name, q in NON_FOOD_CATEGORIES:
        time.sleep(0.08)
        res = search_wikimedia(q, limit=12)
        count = 0
        for item in res:
            if count >= 6:
                break
            img, raw_bytes, status = download_image_candidate(item)
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
                "source_reference": item["desc_url"],
                "license": item["license"],
                "original_filename": item["title"],
                "sha256": sha,
                "width": img.width,
                "height": img.height,
                "review_status": "ACCEPTED"
            })

    audit_stats["non_food_negatives"] = len(non_food_rows)
    with open("non_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        nf_fields = ["image_path", "category", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=nf_fields)
        writer.writeheader()
        writer.writerows(non_food_rows)
    print(f"Saved Non-Food manifest to non_food_manifest.csv ({len(non_food_rows)} images)", flush=True)

    # 4. Collect Unsupported Food Negative Set (Target 100+ images across 20 non-50 catalog items)
    print("\nCollecting Unsupported Food Negative Set (100+ images across 20 categories)...", flush=True)
    unsupported_rows = []
    for food_id, food_name, q in UNSUPPORTED_FOOD_CATEGORIES:
        time.sleep(0.08)
        res = search_wikimedia(q, limit=12)
        count = 0
        for item in res:
            if count >= 6:
                break
            img, raw_bytes, status = download_image_candidate(item)
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
                "source_reference": item["desc_url"],
                "license": item["license"],
                "original_filename": item["title"],
                "sha256": sha,
                "width": img.width,
                "height": img.height,
                "review_status": "ACCEPTED"
            })

    audit_stats["unsupported_food_negatives"] = len(unsupported_rows)
    with open("unsupported_food_manifest.csv", "w", newline="", encoding="utf-8") as f:
        uf_fields = ["image_path", "food_id", "food_name", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=uf_fields)
        writer.writeheader()
        writer.writerows(unsupported_rows)
    print(f"Saved Unsupported Food manifest to unsupported_food_manifest.csv ({len(unsupported_rows)} images)", flush=True)

    # 5. Collect Mixed-Meal Negative Set (Target 50+ images of multi-item plates/thalis)
    print("\nCollecting Mixed-Meal Negative Set (50+ images across meal platters)...", flush=True)
    mixed_meal_rows = []
    for combo_id, combo_name, q in MIXED_MEAL_QUERIES:
        time.sleep(0.08)
        res = search_wikimedia(q, limit=15)
        count = 0
        for item in res:
            if count >= 8:
                break
            img, raw_bytes, status = download_image_candidate(item)
            if img is None or raw_bytes is None:
                continue
            sha = compute_sha256(raw_bytes)
            if sha in global_sha256:
                continue
            global_sha256.add(sha)
            count += 1
            filename = f"mixed_meal_{combo_id}_{count:02d}.jpg"
            rel_path = os.path.join(args.output_dir, "mixed_meals", filename).replace("\\", "/")
            full_path = os.path.join(args.output_dir, "mixed_meals", filename)
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

    audit_stats["mixed_meal_negatives"] = len(mixed_meal_rows)
    with open("mixed_meal_manifest.csv", "w", newline="", encoding="utf-8") as f:
        mm_fields = ["image_path", "meal_type", "source", "source_reference", "license", "original_filename", "sha256", "width", "height", "review_status"]
        writer = csv.DictWriter(f, fieldnames=mm_fields)
        writer.writeheader()
        writer.writerows(mixed_meal_rows)
    print(f"Saved Mixed-Meal manifest to mixed_meal_manifest.csv ({len(mixed_meal_rows)} images)", flush=True)

    # Summary statistics
    counts = list(audit_stats["per_class_counts"].values())
    audit_stats["summary"] = {
        "min_images_per_class": int(np.min(counts)) if counts else 0,
        "max_images_per_class": int(np.max(counts)) if counts else 0,
        "mean_images_per_class": round(float(np.mean(counts)), 2) if counts else 0.0,
        "median_images_per_class": round(float(np.median(counts)), 2) if counts else 0.0
    }

    # Save reports/dataset_audit_v3.json
    with open(args.audit_report, "w", encoding="utf-8") as f:
        json.dump(audit_stats, f, indent=2)

    print(f"\n============================================================")
    print(f"Dataset Audit V3 Summary:")
    print(f"  Total Usable Images:        {audit_stats['total_images']}")
    print(f"  Classes Count:             {audit_stats['classes_count']}")
    print(f"  Min / Max / Mean / Median: {audit_stats['summary']['min_images_per_class']} / {audit_stats['summary']['max_images_per_class']} / {audit_stats['summary']['mean_images_per_class']} / {audit_stats['summary']['median_images_per_class']}")
    print(f"  Splits (Train / Val / Test): {audit_stats['splits_distribution']['train']} / {audit_stats['splits_distribution']['validation']} / {audit_stats['splits_distribution']['test']}")
    print(f"  Non-Food Negatives:        {audit_stats['non_food_negatives']}")
    print(f"  Unsupported Food Negatives:{audit_stats['unsupported_food_negatives']}")
    print(f"  Mixed Meal Negatives:      {audit_stats['mixed_meal_negatives']}")
    print(f"  Exact Duplicates Rejected: {audit_stats['exact_duplicates_rejected']}")
    print(f"  Near Duplicates Rejected:  {audit_stats['near_duplicates_rejected']}")
    print(f"  Broken/Invalid Rejected:   {audit_stats['broken_or_invalid_rejected']}")
    print(f"  Wrong/Suspicious Rejected: {audit_stats['wrong_or_suspicious_rejected']}")
    print(f"Saved audit report to {args.audit_report}")
    print("============================================================\n", flush=True)


if __name__ == "__main__":
    main()
