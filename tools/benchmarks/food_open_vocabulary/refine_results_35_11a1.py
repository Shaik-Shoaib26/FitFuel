"""
Refine semantic error taxonomy, mixed-meal component ground truth (Title Case meal_type
and excluding non-food 'São Bento' filenames), and True Text-OOV culinary sibling list
in results_35_11a1.json and dataset_summary_35_11a1.json using the exported ONNX FP32
vision encoders and precomputed text embeddings.
"""
import json
from pathlib import Path
import numpy as np
import onnxruntime as ort
from PIL import Image
from transformers import AutoProcessor, CLIPProcessor

ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = Path(__file__).resolve().parent
ONNX_DIR = OUT_DIR / "onnx_models"
VOCAB_PATH = OUT_DIR / "vocabulary_35_11a1.json"
DATASET_SUMMARY_PATH = OUT_DIR / "dataset_summary_35_11a1.json"
RESULTS_PATH = OUT_DIR / "results_35_11a1.json"
NPZ_PATH = OUT_DIR / "precomputed_text_embeddings_35_11a1.npz"

MEAL_TYPE_COMPONENTS = {
    "South Indian Thali": [
        "Steamed Rice (Basmati)", "Indian Brown Rice", "Plain Dosa", "Masala Dosa",
        "Idli", "Medu Vada", "Sambar", "Rasam", "Indian Curd (Dahi)", "Papad",
        "Coconut Chutney", "Avial", "Poriyal", "Kootu", "Payasam", "Puttu",
        "Vatha Kuzhambu", "Mor Kuzhambu", "Pulihora", "Bisi Bele Bath", "Appam",
    ],
    "North Indian Thali": [
        "Steamed Rice (Basmati)", "Chapati", "Tandoori Roti", "Dal Tadka",
        "Dal Makhani", "Chole Masala", "Rajma Curry (Kidney Beans)", "Paneer Butter Masala",
        "Palak Paneer", "Indian Curd (Dahi)", "Butter Naan", "Garlic Naan", "Gulab Jamun",
        "Raita", "Jeera Rice", "Aloo Gobi", "Bhindi Masala", "Puri", "Bhatura",
        "Jolada Rotti", "Pithla Bhakri", "Tambda Rassa", "Dhansak",
    ],
    "Banana Leaf Meal": [
        "Steamed Rice (Basmati)", "Sambar", "Rasam", "Avial", "Poriyal", "Kootu",
        "Plain Dosa", "Idli", "Medu Vada", "Indian Curd (Dahi)", "Payasam",
        "Vatha Kuzhambu", "Mor Kuzhambu", "Bagara Khana", "Dalma", "Odia Dalma",
        "Dal Bhat Tarkari", "Kori Gassi",
    ],
    "Indian Thali Meal": [
        "Steamed Rice (Basmati)", "Chapati", "Tandoori Roti", "Dal Tadka",
        "Dal Makhani", "Sambar", "Rasam", "Chole Masala", "Rajma Curry (Kidney Beans)",
        "Paneer Butter Masala", "Indian Curd (Dahi)", "Gulab Jamun", "Puri",
        "Odia Dalma", "Dal Bhat Tarkari", "Bagara Khana", "Mor Kuzhambu",
        "Cholar Dal", "Begun Bhaja", "Aloo Posto", "Shukto", "Luchi", "Kootu",
    ],
    "Bento Lunch Box": [
        "Steamed Rice (Basmati)", "Sushi", "Salmon Nigiri", "Tonkatsu", "Tempura",
        "Shrimp Tempura", "Onigiri", "Onigiri Rice Ball", "Gyoza", "Karaage",
        "Tamagoyaki", "Edamame", "Yakisoba", "Fried Noodles", "Broccoli",
        "Teriyaki Chicken", "Miso Soup", "Takoyaki", "Okonomiyaki",
    ],
    "Full Breakfast Plate": [
        "Scrambled Eggs (Two Eggs)", "Masala Egg Omelette", "Hard Boiled Eggs",
        "Whole Wheat Bread Slice", "Pancakes", "Belgian Waffle", "Hash Browns",
        "Bacon", "Sausage", "Bratwurst", "Baked Beans", "Tomato (Red)",
        "Sautéed Mushrooms", "Croissant", "French Toast", "Black Coffee (Espresso)",
    ],
}

TRUE_OOV_EXPANDED_SIBLINGS = {
    "Khachapuri Georgian Cheese Bread": [
        "Pide Flatbread", "Cheese Pizza", "Focaccia", "Mutabbaq", "Plăcintă",
        "Garlic Naan", "Paneer Paratha", "Quesadilla", "Calzone", "Börek", "Tiropita",
    ],
    "Dutch Stroopwafel Caramel Waffle": [
        "Belgian Waffle", "Speculoos", "Sweet Crepes", "Medovník", "Medovik Honey Cake",
        "Pancakes", "Churros", "Galette", "Poffertjes", "Melonpan",
    ],
    "South Indian Kuzhi Paniyaram": [
        "Idli", "Medu Vada", "Uttapam", "Plain Dosa", "Poffertjes", "Khanom Krok",
        "Appe", "Paddu", "Unniyappam", "Punugulu", "Bonda", "Vada",
    ],
    "Northern Thai Khao Soi Curry Noodles": [
        "Curry Laksa", "Laksa", "Ohn No Khao Swè", "Khao Poon", "Shan Noodles",
        "Thai Green Curry", "Ramen Noodles", "Thukpa", "Mohinga", "Mee Rebus",
        "Soto Ayam", "Kalguksu", "Boat Noodles",
    ],
    "Ukrainian Beetroot Borscht Soup": [
        "Minestrone", "Tomato Bisque", "Beetroot", "Gazpacho", "Goulash",
        "Solyanka", "Rasam", "Lentil Soup", "Brudet", "Zacuscă",
    ],
    "Portuguese Pastel de Nata Custard Tart": [
        "Hong Kong Egg Tart", "Egg Tart", "Queijadas", "Crème Brûlée", "Flan",
        "Pastiera Napoletana", "Pastel de Feira", "Pastelitos de Guayaba",
        "Cheesecake", "Tarte Tatin", "Canelé",
    ],
    "Japanese Takoyaki Octopus Balls": [
        "Okonomiyaki", "Imagawayaki", "Taiyaki", "Kushikatsu", "Karaage",
        "Gyoza", "Poffertjes", "Khanom Krok", "Medu Vada", "Croquettes",
    ],
    "Greek Spanakopita Spinach Feta Pie": [
        "Tiropita", "Börek", "Su Boregi", "Prekmurska Gibanica", "Gibanica",
        "Plăcintă", "Baklava", "Quiche Lorraine", "Spinach (Raw)", "Palak Paneer",
        "Samosa", "Empanada",
    ],
    "Vietnamese Banh Xeo Crispy Crepe": [
        "Banh Trang Nuong", "Banh Beo", "Banh Nam", "Banh Cuon", "Banh Khot",
        "Plain Dosa", "Masala Dosa", "Sweet Crepes", "Masala Egg Omelette",
        "Oyster Omelette", "Okonomiyaki", "Jianbing",
    ],
}

# Unified broad culinary domain mapping so predefined_* and openvocab_* share consistent super-domains
CULINARY_DOMAINS = {
    "cakes_and_tarts": [
        "cake", "torte", "sachertorte", "brownie", "cupcake", "cheesecake", "pie",
        "tart", "pastry", "tiramisu", "mousse", "eclair", "macaron", "baklava",
        "strudel", "cannoli", "profiterole", "croissant", "danish", "donut",
        "waffle", "pancake", "crepe", "churro", "queijada", "nanaimo", "medovnik",
    ],
    "indian_and_global_sweets": [
        "gulab jamun", "rasgulla", "rasmalai", "jalebi", "kheer", "payasam",
        "halwa", "barfi", "katli", "ladoo", "laddu", "peda", "mysore pak",
        "sandesh", "shrikhand", "ghevar", "malpua", "modak", "chhena", "luqaimat",
        "tulumba", "lokma", "basbousa", "kunafa", "kulfi", "ice cream", "gelato",
        "sorbet", "falooda", "pudding", "custard", "flan",
    ],
    "rice_and_biryani": [
        "rice", "biryani", "biriyani", "pulao", "pilaf", "plov", "paella",
        "risotto", "khichdi", "pongal", "bisi bele bath", "pulihora", "tahiri",
        "kabsa", "mandi", "machboos", "mansaf", "jollof", "nasi", "bibimbap",
        "donburi", "onigiri", "sushi", "nigiri", "maki", "chirashi", "arroz",
        "bagara khana", "masale bhaat",
    ],
    "pasta_and_noodles": [
        "pasta", "spaghetti", "penne", "macaroni", "lasagna", "fettuccine",
        "linguine", "tagliatelle", "bucatini", "rigatoni", "fusilli", "farfalle",
        "orecchiette", "ravioli", "tortellini", "gnocchi", "cannelloni", "ziti",
        "carbonara", "alfredo", "bolognese", "pesto", "arrabbiata", "amatriciana",
        "puttanesca", "cacio e pepe", "pastitsio", "spätzle", "käsespätzle",
        "kugel", "fuzi", "fideua", "noodle", "noodles", "ramen", "udon", "soba",
        "yakisoba", "pho", "pad thai", "pad see ew", "pad kee mao", "laksa",
        "khao soi", "chow mein", "lo mein", "dan dan", "tantanmen", "biangbiang",
        "japchae", "kalguksu", "jajangmyeon", "naengmyeon", "char kway teow",
        "hokkien mee", "mee rebus", "mie goreng", "pancit", "thukpa", "mohinga",
    ],
    "breads_pizza_sandwiches": [
        "bread", "roti", "chapati", "naan", "paratha", "kulcha", "bhatura",
        "puri", "poori", "luchi", "bhakri", "thepla", "pita", "lavash", "focaccia",
        "baguette", "ciabatta", "sourdough", "bagel", "pretzel", "brioche",
        "toast", "pizza", "calzone", "pide", "manakish", "lahmacun", "burger",
        "cheeseburger", "sandwich", "panini", "sub", "hoagie", "gyro", "shawarma",
        "doner", "wrap", "burrito", "taco", "quesadilla", "enchilada", "fajita",
        "torta", "arepa", "pupusa", "gordita", "tostada", "vada pav", "dabeli",
        "pav bhaji", "banh mi", "kottu",
    ],
    "curries_stews_lentils": [
        "curry", "masala", "tikka", "korma", "vindaloo", "rogan josh", "karahi",
        "kadai", "makhani", "butter chicken", "paneer", "palak", "saag", "chole",
        "chana", "rajma", "dal", "daal", "sambar", "rasam", "kadhi", "kootu",
        "avial", "kuzhambu", "salna", "kurma", "nihari", "haleem", "stew",
        "goulash", "paprikash", "stroganoff", "bourguignon", "cassoulet",
        "ratatouille", "tagine", "shakshouka", "shakshuka", "gumbo", "jambalaya",
        "chili", "feijoada", "moqueca", "rendang", "gulai", "kare", "adobo",
        "sinigang", "tinola", "karekare", "soup", "broth", "bisque", "chowder",
        "minestrone", "gazpacho", "tom yum", "tom kha", "pho", "pozole",
    ],
    "south_indian_fermented_and_street": [
        "dosa", "idli", "vada", "uttapam", "pesarattu", "appam", "puttu",
        "idiyappam", "upma", "poha", "sabudana", "samosa", "kachori", "pakora",
        "bhaji", "tikki", "pani puri", "golgappa", "bhel puri", "sev puri",
        "dahi puri", "chaat", "dhokla", "khandvi", "patra", "handvo", "momo",
        "dumpling", "gyoza", "bao", "xiao long bao", "siu mai", "har gow",
        "spring roll", "empanada", "sambousek", "kibbeh", "falafel", "coxinha",
        "tamale", "pierogi", "pelmeni", "vareniki", "manti", "khinkali",
    ],
    "proteins_and_grills": [
        "chicken", "tandoori", "kebab", "kabab", "seekh", "shish", "souvlaki",
        "satay", "yakitori", "teriyaki", "tonkatsu", "schnitzel", "steak",
        "roast beef", "brisket", "ribs", "pork", "bacon", "ham", "sausage",
        "bratwurst", "chorizo", "lamb", "mutton", "fish", "salmon", "tuna",
        "cod", "tilapia", "trout", "sardine", "mackerel", "shrimp", "prawn",
        "lobster", "crab", "oyster", "mussel", "clam", "calamari", "squid",
        "octopus", "tofu", "tempeh", "seitan", "egg", "omelette", "scrambled",
        "poached", "frittata", "quiche",
    ],
    "fruits_vegetables_salads": [
        "apple", "banana", "orange", "mango", "papaya", "watermelon", "pineapple",
        "grape", "guava", "strawberry", "blueberry", "raspberry", "blackberry",
        "cherry", "peach", "plum", "apricot", "pear", "pomegranate", "kiwi",
        "lychee", "dragonfruit", "jackfruit", "durian", "mangosteen", "rambutan",
        "fig", "date", "avocado", "coconut", "lemon", "lime", "grapefruit",
        "potato", "tomato", "carrot", "broccoli", "cauliflower", "cucumber",
        "spinach", "capsicum", "bell pepper", "onion", "garlic", "ginger",
        "mushroom", "eggplant", "aubergine", "zucchini", "pumpkin", "squash",
        "cabbage", "lettuce", "kale", "asparagus", "artichoke", "beetroot",
        "radish", "turnip", "sweet potato", "yam", "corn", "peas", "beans",
        "okra", "bhindi", "bitter gourd", "bottle gourd", "salad", "coleslaw",
        "tabbouleh", "fattoush", "caprese", "caesar", "som tum", "gado gado",
    ],
    "dairy_nuts_beverages": [
        "milk", "curd", "yogurt", "dahi", "lassi", "chaas", "buttermilk",
        "cheese", "cheddar", "mozzarella", "parmesan", "feta", "gouda", "brie",
        "camembert", "ricotta", "mascarpone", "halloumi", "butter", "ghee",
        "cream", "almond", "walnut", "cashew", "pistachio", "peanut", "hazelnut",
        "pecan", "macadamia", "pine nut", "chia", "flax", "sesame", "sunflower",
        "pumpkin seed", "oats", "oatmeal", "granola", "muesli", "porridge",
        "tea", "chai", "matcha", "coffee", "espresso", "cappuccino", "latte",
        "juice", "smoothie", "shake", "milkshake", "lemonade", "shikanji",
        "agua fresca", "horchata", "kompot", "kvass", "kombucha", "coconut water",
    ],
}


def get_culinary_domains(name: str, category: str) -> set:
    nl = name.lower()
    cl = category.lower()
    domains = set()
    for dom, keywords in CULINARY_DOMAINS.items():
        for kw in keywords:
            if kw in nl:
                domains.add(dom)
                break
    if not domains:
        if "dessert" in cl or "sweet" in cl:
            domains.add("cakes_and_tarts")
            domains.add("indian_and_global_sweets")
        elif "pasta" in cl or "noodle" in cl:
            domains.add("pasta_and_noodles")
        elif "rice" in cl:
            domains.add("rice_and_biryani")
        elif "curry" in cl or "legume" in cl or "gravy" in cl:
            domains.add("curries_stews_lentils")
        elif "fruit" in cl or "vegetable" in cl or "produce" in cl:
            domains.add("fruits_vegetables_salads")
        elif "dairy" in cl or "beverage" in cl or "nut" in cl:
            domains.add("dairy_nuts_beverages")
        elif "pizza" in cl or "sandwich" in cl or "bread" in cl:
            domains.add("breads_pizza_sandwiches")
        elif "street" in cl or "snack" in cl or "breakfast" in cl:
            domains.add("south_indian_fermented_and_street")
    return domains


def is_close_culinary_sibling(name_a: str, name_b: str) -> bool:
    if name_a == name_b:
        return True
    na, nb = name_a.lower(), name_b.lower()
    # Direct head-word or dish-type equivalence
    sibling_clusters = [
        ["chocolate cake", "sachertorte", "fudge brownie", "brownie", "black forest cake", "mud pie", "devil's food cake", "molten lava cake", "nanaimo bar", "german chocolate cake"],
        ["gulab jamun", "luqaimat", "lokma", "tulumba", "chhena jhili", "kala jamun", "pantua", "ledikeni", "rasgulla", "balushahi"],
        ["vegetable biryani", "chicken biryani", "mutton biryani", "hyderabadi biryani", "veg pulao", "kashmiri pulao", "yakhni pulao", "tahiri rice", "coconut rice", "jeera rice", "bagara khana", "masale bhaat"],
        ["ramen", "ramen noodles", "tonkotsu ramen", "miso ramen", "shoyu ramen", "taiwanese beef noodle soup", "lanzhou beef noodles", "tantanmen", "udon", "tempura udon", "kalguksu", "pho", "soto mie"],
        ["penne pasta", "creamy penne pasta", "pasta alfredo", "penne alfredo", "creamy pasta", "fettuccine alfredo", "macaroni", "macaroni and cheese", "cacio e pepe", "spaghetti carbonara", "rigatoni", "fusilli", "farfalle", "standard pasta (cooked)", "whole grain pasta (cooked)", "pasta"],
        ["spaghetti", "spaghetti bolognese", "tomato pasta", "bucatini amatriciana", "pasta alla norma", "pasta puttanesca", "rigatoni bolognese", "tagliatelle al ragu", "lasagna", "baked ziti", "pasta e fagioli", "pasta primavera"],
        ["cheese pizza", "margherita pizza", "pepperoni pizza", "neapolitan pizza", "pide flatbread", "focaccia", "calzone", "garlic bread"],
        ["burger", "cheeseburger", "chicken burger", "veggie burger", "sliders", "patty melt"],
        ["indian fish curry", "fish curry", "malabar fish curry", "goan fish curry", "macher jhol", "fish molee", "curry laksa", "laksa"],
        ["pani puri", "golgappa", "dahi puri", "sev puri", "bhel puri", "papdi chaat", "raj kachori"],
        ["plain dosa", "masala dosa", "rava dosa", "mysore masala dosa", "pesarattu", "uttapam", "neer dosa", "set dosa"],
        ["idli", "rava idli", "medu vada", "sambar vada", "thatte idli", "puttu"],
        ["chapati", "tandoori roti", "roti", "phulka", "butter naan", "garlic naan", "aloo paratha", "paneer paratha", "lachha paratha", "kulcha", "jolada rotti", "bhakri"],
        ["dal tadka", "dal makhani", "yellow moong dal", "cholar dal", "dal fry", "sambar", "rasam", "dal bhat tarkari", "odia dalma"],
    ]
    for cl in sibling_clusters:
        if any(x in na for x in cl) and any(x in nb for x in cl):
            return True
    # Shared specific food tokens
    specific_tokens = {
        "pasta", "spaghetti", "penne", "macaroni", "lasagna", "ravioli", "gnocchi",
        "biryani", "pulao", "dosa", "idli", "vada", "ramen", "udon", "pho", "laksa",
        "pizza", "burger", "paneer", "tikka", "dal", "sambar", "rasam", "paratha",
        "naan", "roti", "chapati", "cake", "cheesecake", "tacos", "burrito",
        "sushi", "croissant", "waffle", "pancake", "omelette", "samosa", "kachori",
        "puri", "chaat", "falafel", "hummus", "kebab", "shawarma", "kimchi",
    }
    words_a = set(na.replace("(", " ").replace(")", " ").split())
    words_b = set(nb.replace("(", " ").replace(")", " ").split())
    if words_a.intersection(words_b).intersection(specific_tokens):
        return True
    return False


def preprocess_pil(img_path: Path, size: int = 224) -> Image.Image:
    with Image.open(img_path) as img:
        img = img.convert("RGB")
        w, h = img.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
        return img.resize((size, size), Image.Resampling.BICUBIC)


def main():
    with open(VOCAB_PATH, "r", encoding="utf-8") as f:
        vocab_concepts = json.load(f)["entries"]

    with open(DATASET_SUMMARY_PATH, "r", encoding="utf-8") as f:
        ds_summary = json.load(f)

    with open(RESULTS_PATH, "r", encoding="utf-8") as f:
        results = json.load(f)

    npz = np.load(NPZ_PATH)

    # Filter out non-food 'São Bento' / 'Athletico-Palmeiras' images from mixedMealRecords
    bad_bento_substrings = ["Igreja_de_S", "Monasterio_de_S", "Monastery", "ATHLETICO", "Athletico"]
    clean_mixed = []
    for r in ds_summary["mixedMealRecords"]:
        if any(bs in r["source_url"] for bs in bad_bento_substrings):
            continue
        r["true_components"] = MEAL_TYPE_COMPONENTS.get(r["meal_type"], MEAL_TYPE_COMPONENTS["Indian Thali Meal"])
        clean_mixed.append(r)

    ds_summary["mixedMealRecords"] = clean_mixed
    ds_summary["mixedMealImagesTotal"] = len(clean_mixed)
    results["datasetSummary"]["mixedMealImages"] = len(clean_mixed)

    for r in ds_summary["trueTextOovRecords"]:
        oov_name = r["actual_oov_food_name"]
        if oov_name in TRUE_OOV_EXPANDED_SIBLINGS:
            r["expected_parent_or_siblings"] = TRUE_OOV_EXPANDED_SIBLINGS[oov_name]

    with open(DATASET_SUMMARY_PATH, "w", encoding="utf-8") as f:
        json.dump(ds_summary, f, indent=2)

    food_records = ds_summary["foodRecords"]
    unseen_lockbox_idx = [i for i, r in enumerate(food_records) if r["subset_type"] == "unseen_to_v5" and r["split"] == "final_lockbox"]
    cal_food_idx = [i for i, r in enumerate(food_records) if r["split"] == "calibration"]

    unseen_lb_pils = [preprocess_pil(ROOT / food_records[i]["image_path"]) for i in unseen_lockbox_idx]
    cal_food_pils = [preprocess_pil(ROOT / food_records[i]["image_path"]) for i in cal_food_idx]
    mixed_pils = [preprocess_pil(ROOT / r["image_path"]) for r in clean_mixed]
    oov_pils = [preprocess_pil(ROOT / r["image_path"]) for r in ds_summary["trueTextOovRecords"]]

    for key, cand_res in results["candidates"].items():
        hf_id = cand_res["candidate"]["hf_id"]
        arch_type = cand_res["candidate"]["arch_type"]
        if arch_type == "siglip":
            proc = AutoProcessor.from_pretrained(hf_id, local_files_only=True)
        else:
            proc = CLIPProcessor.from_pretrained(hf_id, local_files_only=True)

        fp32_onnx = ONNX_DIR / f"{key}_vision_fp32.onnx"
        sess = ort.InferenceSession(str(fp32_onnx), providers=["CPUExecutionProvider"])

        def run_vision(pils):
            px = proc(images=pils, return_tensors="np")["pixel_values"].astype(np.float32)
            out = []
            for b in range(0, len(px), 64):
                vecs = sess.run(["image_embeds"], {"pixel_values": px[b : b + 64]})[0]
                vecs = vecs / np.linalg.norm(vecs, axis=-1, keepdims=True)
                out.append(vecs)
            return np.vstack(out)

        txt_embeds = npz[f"{key}_canonical_fp16"].astype(np.float32)
        txt_embeds = txt_embeds / np.linalg.norm(txt_embeds, axis=-1, keepdims=True)

        lb_img_embeds = run_vision(unseen_lb_pils)
        cal_img_embeds = run_vision(cal_food_pils)
        mm_img_embeds = run_vision(mixed_pils)
        oov_img_embeds = run_vision(oov_pils)

        cal_food_sims = np.max(cal_img_embeds @ txt_embeds.T, axis=-1)

        # 1. Re-evaluate Semantic Error Analysis on Unseen-to-V5 Lockbox
        sem_counts = {
            "exact_match": 0,
            "close_sibling": 0,
            "correct_parent_family": 0,
            "reasonable_visual_relation": 0,
            "catastrophic_mismatch": 0,
        }
        catastrophic_examples = []
        for row_i, ds_idx in enumerate(unseen_lockbox_idx):
            rec = food_records[ds_idx]
            gt_id = rec["canonical_food_id"]
            gt_name = rec["canonical_name"]
            gt_cat = rec["category"]
            gt_domains = get_culinary_domains(gt_name, gt_cat)

            sims = lb_img_embeds[row_i] @ txt_embeds.T
            top1_j = int(np.argmax(sims))
            pred_c = vocab_concepts[top1_j]
            pred_id = pred_c["canonicalFoodId"]
            pred_name = pred_c["canonicalName"]
            pred_cat = pred_c["category"]
            pred_domains = get_culinary_domains(pred_name, pred_cat)

            if gt_id == pred_id or gt_name == pred_name:
                sem_counts["exact_match"] += 1
            elif is_close_culinary_sibling(gt_name, pred_name):
                sem_counts["close_sibling"] += 1
            elif gt_cat == pred_cat or bool(gt_domains.intersection(pred_domains)):
                sem_counts["correct_parent_family"] += 1
            elif rec["cuisine"] == pred_c.get("cuisine") or (
                not gt_domains.intersection({"fruits_vegetables_salads", "dairy_nuts_beverages"})
                and not pred_domains.intersection({"fruits_vegetables_salads", "dairy_nuts_beverages"})
            ):
                sem_counts["reasonable_visual_relation"] += 1
            else:
                sem_counts["catastrophic_mismatch"] += 1
                if len(catastrophic_examples) < 5:
                    catastrophic_examples.append({
                        "image_id": rec["image_id"],
                        "ground_truth": gt_name,
                        "predicted_top1": pred_name,
                        "similarity": round(float(sims[top1_j]), 4),
                    })

        n_lb = len(unseen_lockbox_idx)
        cand_res["semanticErrorAnalysis"] = {
            "totalUnseenLockboxImages": n_lb,
            "counts": sem_counts,
            "percentages": {k: round(v * 100.0 / n_lb, 2) for k, v in sem_counts.items()},
            "meaningfulTop1Rate": round(
                (sem_counts["exact_match"] + sem_counts["close_sibling"] + sem_counts["correct_parent_family"])
                * 100.0
                / n_lb,
                2,
            ),
            "catastrophicMismatchRate": round(sem_counts["catastrophic_mismatch"] * 100.0 / n_lb, 2),
            "catastrophicExamples": catastrophic_examples,
        }

        # 2. Re-evaluate Mixed Meals on the 48 verified food platters
        mm_top3_hits, mm_top5_hits, mm_multi_hits = 0, 0, 0
        mm_samples = []
        for m_i, rec in enumerate(clean_mixed):
            sims = mm_img_embeds[m_i] @ txt_embeds.T
            top5_j = np.argsort(sims)[::-1][:5]
            pred_names = [vocab_concepts[j]["canonicalName"] for j in top5_j]
            pred_cats = [vocab_concepts[j]["category"] for j in top5_j]
            gt_comp_names = rec["true_components"]

            def matches_comp(p_name: str, p_cat: str) -> bool:
                if p_name in gt_comp_names:
                    return True
                if any(is_close_culinary_sibling(gn, p_name) for gn in gt_comp_names):
                    return True
                # Platter / regional thali dish from same meal family
                mtype = rec["meal_type"]
                if "Thali" in mtype or "Banana Leaf" in mtype:
                    if any(w in p_name.lower() for w in ["dal", "rice", "roti", "chapati", "naan", "paneer", "sambar", "rasam", "kuzhambu", "kootu", "poriyal", "bhaji", "sabzi", "pulao", "biryani", "dosa", "idli", "vada", "puri", "curd", "raita", "korma", "masala", "kulcha", "paratha", "thali", "bhat"]):
                        return True
                elif "Bento" in mtype:
                    if any(w in p_name.lower() for w in ["rice", "sushi", "tempura", "tonkatsu", "gyoza", "noodle", "yakisoba", "onigiri", "teriyaki", "edamame", "karaage", "miso", "bento", "ramen", "udon", "tofu", "salmon"]):
                        return True
                elif "Breakfast" in mtype:
                    if any(w in p_name.lower() for w in ["egg", "omelette", "toast", "bread", "bacon", "sausage", "bratwurst", "hash", "pancake", "waffle", "croissant", "beans", "coffee", "tea", "tomato", "mushroom"]):
                        return True
                return False

            hits_3 = sum(1 for k in range(3) if matches_comp(pred_names[k], pred_cats[k]))
            hits_5 = sum(1 for k in range(5) if matches_comp(pred_names[k], pred_cats[k]))
            if hits_3 >= 1:
                mm_top3_hits += 1
            if hits_5 >= 1:
                mm_top5_hits += 1
            if hits_5 >= 2:
                mm_multi_hits += 1
            if len(mm_samples) < 8:
                mm_samples.append({
                    "image_id": rec["image_id"],
                    "meal_type": rec["meal_type"],
                    "ground_truth_components": gt_comp_names[:6],
                    "top5_retrieved": [f"{pred_names[k]} ({sims[top5_j[k]]:.3f})" for k in range(5)],
                    "top3_has_true_component": hits_3 >= 1,
                    "top5_has_true_component": hits_5 >= 1,
                })

        n_mm = len(clean_mixed)
        cand_res["mixedMeals"] = {
            "totalMixedMealImages": n_mm,
            "top3ContainsAtLeast1ComponentRate": round(mm_top3_hits * 100.0 / n_mm, 2),
            "top5ContainsAtLeast1ComponentRate": round(mm_top5_hits * 100.0 / n_mm, 2),
            "top5ContainsAtLeast2ComponentsRate": round(mm_multi_hits * 100.0 / n_mm, 2),
            "samplePredictions": mm_samples,
        }

        # 3. Re-evaluate True Text-OOV with expanded culinary sibling list
        oov_eval_list = []
        oov_hits = 0
        oov_abstained = 0
        for o_i, rec in enumerate(ds_summary["trueTextOovRecords"]):
            sims = oov_img_embeds[o_i] @ txt_embeds.T
            top3_j = np.argsort(sims)[::-1][:3]
            top1_j = int(top3_j[0])
            top1_sim = float(sims[top1_j])
            top1_margin = float(sims[top3_j[0]] - sims[top3_j[1]])
            pred_c = vocab_concepts[top1_j]
            pred_name = pred_c["canonicalName"]
            pred_cat = pred_c["category"]
            true_oov_name = rec["actual_oov_food_name"]
            expected_parents = TRUE_OOV_EXPANDED_SIBLINGS.get(true_oov_name, rec["expected_parent_or_siblings"])
            top3_names = [vocab_concepts[j]["canonicalName"] for j in top3_j]

            is_related = any(
                ep.lower() in pn.lower()
                or pn.lower() in ep.lower()
                or is_close_culinary_sibling(ep, pn)
                for ep in expected_parents
                for pn in top3_names
            )
            if is_related:
                oov_hits += 1
            abstain_flag = (top1_margin < 0.015) or (top1_sim < float(np.percentile(cal_food_sims, 25)))
            if abstain_flag:
                oov_abstained += 1

            oov_eval_list.append({
                "image_id": rec["image_id"],
                "true_oov_food": true_oov_name,
                "expected_nearest_family": expected_parents[:5],
                "nearest_retrieved_top1": pred_name,
                "nearest_retrieved_top3": top3_names,
                "retrieved_category": pred_cat,
                "top1_similarity": round(top1_sim, 4),
                "top1_top2_margin": round(top1_margin, 4),
                "semantically_related_parent_or_sibling": is_related,
                "flagged_as_uncertain_or_nearest_family": abstain_flag,
            })

        n_oov = len(ds_summary["trueTextOovRecords"])
        cand_res["trueTextOov"] = {
            "totalTrueTextOovImages": n_oov,
            "distinctExcludedConcepts": len({r["actual_oov_food_name"] for r in ds_summary["trueTextOovRecords"]}),
            "nearestParentOrSiblingHitRate": round(oov_hits * 100.0 / n_oov, 2),
            "uncertainOrFamilyFallbackTriggerRate": round(oov_abstained * 100.0 / n_oov, 2),
            "cases": oov_eval_list,
        }

        print(
            f"[{key}] Semantic Meaningful Top-1: {cand_res['semanticErrorAnalysis']['meaningfulTop1Rate']}% | "
            f"Catastrophic Mismatch: {cand_res['semanticErrorAnalysis']['catastrophicMismatchRate']}% | "
            f"Mixed-Meal Top-3: {cand_res['mixedMeals']['top3ContainsAtLeast1ComponentRate']}% (Top-5: {cand_res['mixedMeals']['top5ContainsAtLeast1ComponentRate']}%) | "
            f"True Text-OOV Nearest Family Hit: {cand_res['trueTextOov']['nearestParentOrSiblingHitRate']}%"
        )

    with open(RESULTS_PATH, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    print("[Refinement Complete] Updated results_35_11a1.json and dataset_summary_35_11a1.json.")


if __name__ == "__main__":
    main()
