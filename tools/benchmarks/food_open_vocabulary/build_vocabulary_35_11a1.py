#!/usr/bin/env python3
"""
FitFuel Phase 35.11A.1 — Large Open-Vocabulary Food Ontology Builder

Builds a structured, geographically diverse open-vocabulary food recognition index:
- Includes 100% of the 238 FitFuel predefined catalog foods
- Expands to 1,800+ distinct canonical food concepts across:
  Indian, South Asian, East Asian, Southeast Asian, Middle Eastern,
  Mediterranean, European, African, North American, Latin American,
  Desserts, Breakfast foods, Snacks, Fruits, Vegetables, Proteins, Grains, Drinks
- Strictly obeys Section 9:
  "Do not duplicate aliases as unrelated canonical foods."
  Sub-variants/synonyms of existing canonical foods are merged into `aliases[]`
  rather than competing as duplicate canonical foods.
- Defines explicit negative non-food concepts for safety gating
- Defines explicit True Text-OOV food concepts (intentionally excluded from the
  active text vocabulary to test OOV abstention / nearest-parent behavior)
"""

import json
import os
import re
from collections import Counter

DART_PREDEFINED_PATH = "lib/features/food/data/datasources/predefined_food_data.dart"
V5_LABELS_PATH = "assets/ml/fitfuel_food_labels.txt"
OUT_DIR = "tools/benchmarks/food_open_vocabulary"


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


# Explicit rich aliases for key FitFuel and global foods (Section 9)
EXPLICIT_ALIASES = {
    "Penne Pasta": ["penne", "penne rigate", "cooked penne", "pasta penne"],
    "Penne Alfredo": ["alfredo penne", "white sauce penne", "parmesan penne alfredo"],
    "Creamy Penne Pasta": ["creamy penne", "penne in cream sauce", "penne alla vodka"],
    "Creamy Pasta": ["white sauce pasta", "cream sauce pasta", "cheesy creamy pasta"],
    "Pasta Alfredo": ["fettuccine alfredo", "alfredo pasta", "parmesan alfredo noodles"],
    "Spaghetti": ["spaghetti pasta", "cooked spaghetti noodles", "italian spaghetti"],
    "Spaghetti Bolognese": ["bolognese pasta", "spaghetti meat sauce", "spaghetti ragu"],
    "Tomato Pasta": ["pasta pomodoro", "penne arrabbiata", "marinara pasta"],
    "Lasagna": ["baked lasagna", "meat lasagna", "lasagne al forno"],
    "Macaroni": ["elbow macaroni", "cooked macaroni pasta", "macaroni noodles"],
    "Ramen Noodles": ["ramen", "japanese ramen", "tonkotsu ramen", "shoyu ramen noodle soup"],
    "Udon": ["japanese udon noodles", "kake udon soup", "thick wheat udon"],
    "Sushi": ["japanese sushi", "nigiri sushi platter", "maki sushi rolls", "salmon sushi"],
    "Samosa": ["vegetable samosa", "punjabi samosa", "fried triangular samosa pastry", "singara"],
    "Medu Vada": ["urad dal vada", "south indian medu vada", "uddina vada", "ulundu vadai"],
    "Plain Dosa": ["dosa", "south indian dosa crepe", "crispy rice lentil dosa", "sada dosa"],
    "Masala Dosa": ["potato stuffed masala dosa", "mysore masala dosa", "crispy masala dosa"],
    "Idli": ["steamed rice idli", "south indian idli", "idly cakes", "soft white idli"],
    "Chicken Biryani": ["biryani", "hyderabadi chicken dum biryani", "spiced basmati chicken biryani", "murgh biryani"],
    "Vegetable Biryani": ["veg biryani", "subz dum biryani", "spiced vegetable basmati rice"],
    "Butter Chicken": ["murgh makhani", "delhi butter chicken curry", "creamy tomato butter chicken"],
    "Paneer Tikka": ["grilled paneer tikka", "tandoori cottage cheese skewers", "paneer tikka kebab"],
    "Mexican Tacos": ["tacos", "street tacos", "corn tortilla tacos", "carne asada tacos"],
    "Burrito": ["mexican burrito", "stuffed flour tortilla burrito", "bean and rice burrito wrap"],
    "Falafel": ["chickpea falafel balls", "middle eastern fried falafel", "crispy herb falafel"],
    "Hummus": ["chickpea tahini hummus", "levantine hummus dip", "creamy hummus with olive oil"],
    "Vietnamese Pho": ["pho", "beef pho noodle soup", "pho bo", "vietnamese rice noodle broth"],
    "Pad Thai": ["thai stir fried rice noodles", "shrimp pad thai", "peanuts tamarind pad thai"],
    "Bibimbap": ["korean mixed rice bowl", "dolsot bibimbap", "bibimbap with egg and vegetables"],
    "Kimchi Fried Rice": ["kimchi bokkeumbap", "spicy korean kimchi rice", "fried rice with kimchi"],
    "Spanish Paella": ["paella", "seafood saffron paella", "valencian paella rice"],
    "Croissant": ["butter croissant", "flaky french croissant", "viennoiserie crescent pastry"],
    "Cheesecake": ["new york cheesecake", "baked cream cheese cake slice", "strawberry cheesecake"],
    "Pani Puri": ["golgappa", "puchka", "gupchup", "pani ke batashe"],
    "Curd": ["plain yogurt", "dahi", "indian set curd", "natural yogurt bowl"],
    "Chapati": ["roti", "phulka", "whole wheat indian flatbread", "tawa chapati"],
    "Eggplant": ["brinjal", "aubergine", "baingan", "fresh purple eggplant"],
    "Capsicum": ["bell pepper", "green bell pepper", "shimla mirch", "sweet pepper"],
    "Cheese Pizza": ["pizza", "margherita pizza", "neapolitan pizza", "pepperoni pizza"],
    "Burger": ["cheeseburger", "hamburger", "beef burger", "veggie burger"],
    "Glazed Donut": ["donut", "doughnut", "ring donut with glaze", "frosted donut"],
    "Pancakes": ["buttermilk pancakes", "breakfast pancakes with syrup", "hotcakes"],
    "Belgian Waffle": ["waffle", "crispy breakfast waffle", "grid waffle"],
    "Sweet Crepes": ["crepes", "french crepe", "folded thin pancake crepe"],
    "Blueberry Muffin": ["muffin", "baked cupcake muffin", "breakfast muffin"],
    "Hot Dog": ["hotdog", "frankfurter in bun", "sausage hot dog"],
    "French Fries": ["fries", "potato fries", "finger chips"],
    "Chocolate Cake": ["chocolate sponge cake", "fudge cake slice", "layered chocolate cake"],
    "Ice Cream": ["vanilla ice cream scoop", "gelato", "ice cream sundae"],
    "Baklava": ["turkish baklava pastry", "pistachio phyllo baklava", "middle eastern baklava"],
    "Bhel Puri": ["bhelpuri chaat", "puffed rice sev chaat", "mumbai bhel"],
    "Pav Bhaji": ["mumbai pav bhaji", "buttered pav with vegetable bhaji"],
    "Paneer Butter Masala": ["paneer makhani", "shahi paneer", "butter paneer gravy"],
    "Chicken Curry": ["homestyle chicken curry", "indian chicken gravy", "masala chicken curry"],
    "Dal Makhani": ["black lentil dal makhani", "creamy urad dal makhani", "punjabi dal makhani"],
    "Fish Curry": ["malabar fish curry", "machher jhol", "spicy fish gravy"],
    "Gulab Jamun": ["gulab jamun in syrup", "kala jamun", "fried milk solid sweet"],
    "Fried Noodles": ["chow mein", "hakka noodles", "stir fried noodles", "lo mein"],
    "Nachos with Cheese": ["nachos", "loaded tortilla chips", "cheese nachos with salsa"],
    "Club Sandwich": ["sandwich", "toasted club sandwich", "vegetable sandwich"],
}

PARENT_CATEGORY_MAP = {
    "Pasta & Noodles": "Grains & Pasta",
    "Rice Dishes": "Grains & Rice",
    "Breads & Flatbreads": "Bakery & Breads",
    "Curries & Gravies": "Main Dishes",
    "Street Food & Chaat": "Snacks & Appetizers",
    "Snacks": "Snacks & Appetizers",
    "Breakfast": "Breakfast & Brunch",
    "Desserts & Sweets": "Desserts & Bakery",
    "Desserts": "Desserts & Bakery",
    "Fruits": "Produce",
    "Vegetables": "Produce",
    "Legumes & Lentils": "Plant Proteins",
    "Legumes": "Plant Proteins",
    "Meat & Poultry": "Proteins",
    "Seafood": "Proteins",
    "Protein": "Proteins",
    "Dairy & Eggs": "Dairy & Alternatives",
    "Dairy": "Dairy & Alternatives",
    "Nuts & Seeds": "Healthy Fats & Nuts",
    "Beverages": "Drinks & Beverages",
    "Drinks": "Drinks & Beverages",
    "Soups & Stews": "Soups & Salads",
    "Salads & Bowls": "Soups & Salads",
    "Sandwiches & Wraps": "Main Dishes",
    "Pizza & Flatbreads": "Main Dishes",
}

# Protected pasta regression & core global concepts that must always remain distinct canonical entries
PROTECTED_CANONICAL_NAMES = {
    "Penne Pasta", "Penne Alfredo", "Creamy Penne Pasta", "Creamy Pasta",
    "Pasta Alfredo", "Spaghetti", "Spaghetti Bolognese", "Tomato Pasta",
    "Lasagna", "Macaroni", "Macaroni and Cheese", "Spaghetti Carbonara",
    "Potato Gnocchi", "Cheese Ravioli", "Udon", "Falafel", "Hummus",
    "Chicken Shawarma", "Shakshuka", "Vietnamese Pho", "Pad Thai",
    "Bibimbap", "Kimchi Fried Rice", "Spanish Paella", "Croissant",
    "Cheesecake", "Fish and Chips", "Greek Salad", "Jollof Rice",
    "Injera with Wat", "Moroccan Tagine", "Moroccan Couscous",
    "Peruvian Ceviche", "Argentine Empanada", "Colombian Arepa",
    "Guacamole", "Churros", "Tiramisu", "French Macarons", "Crème Brûlée",
    "French Onion Soup", "Ratatouille", "Quiche Lorraine", "Mushroom Risotto",
    "Bruschetta", "Caprese Salad", "Gazpacho", "Tortilla Española",
    "Moussaka", "Chicken Souvlaki", "Wiener Schnitzel", "Bratwurst",
    "Bavarian Pretzel", "Apple Strudel", "Swiss Cheese Fondue", "Polish Pierogi",
    "Hungarian Goulash", "Beef Stroganoff", "Swedish Meatballs", "Peking Duck",
    "Kung Pao Chicken", "Mapo Tofu", "Xiao Long Bao", "Har Gow Dim Sum",
    "Char Siu BBQ Pork", "Dan Dan Noodles", "Tonkatsu Pork Cutlet",
    "Japanese Katsu Curry", "Shrimp Tempura", "Okonomiyaki", "Yakitori Skewers",
    "Onigiri Rice Ball", "Miso Soup", "Bulgogi Beef", "Tteokbokki",
    "Japchae Glass Noodles", "Kimbap Roll", "Tom Yum Goong", "Thai Green Curry",
    "Som Tum Papaya Salad", "Mango Sticky Rice", "Chicken Satay",
    "Banh Mi Baguette", "Goi Cuon Summer Rolls", "Nasi Goreng", "Beef Rendang",
    "Hainanese Chicken Rice", "Curry Laksa", "Nasi Lemak", "Chicken Adobo",
    "Halo-Halo", "Baba Ganoush", "Tabbouleh Salad", "Kunafa", "Lahmacun",
    "Canadian Poutine", "New England Clam Chowder", "Eggs Benedict",
    "Cinnamon Roll", "Fudge Brownie", "Apple Pie", "Brazilian Feijoada",
    "Pão de Queijo", "Vada Pav", "Chole Bhature", "Rasmalai", "Kaju Katli",
    "Kachori", "Butter Naan", "Sweet Lassi", "Steamed Momos", "Spring Rolls",
}

# True Text-OOV Concepts (Intentionally EXCLUDED from the active text vocabulary!)
TRUE_TEXT_OOV_EXCLUDED_CONCEPTS = {
    "Khachapuri",
    "Stroopwafel",
    "Koshari",
    "Paniyaram",
    "Khao Soi",
    "Borscht",
    "Pastel de Nata",
    "Takoyaki",
    "Spanakopita",
    "Banh Xeo",
}


def parse_fitfuel_238(dart_path: str):
    with open(dart_path, "r", encoding="utf-8") as f:
        text = f.read()
    blocks = text.split("const FoodModel(")[1:]
    foods = []
    for b in blocks:
        id_m = re.search(r"id:\s*'([^']+)'", b)
        name_m = re.search(r"name:\s*'([^']+)'", b)
        cat_m = re.search(r"category:\s*'([^']+)'", b)
        ind_m = re.search(r"isIndian:\s*(true|false)", b)
        if id_m and name_m:
            fid = id_m.group(1)
            name = name_m.group(1)
            cat = cat_m.group(1) if cat_m else "Other"
            is_ind = (ind_m.group(1) == "true") if ind_m else False
            cuisine = "Indian" if is_ind else "Global"
            foods.append({
                "canonicalFoodId": fid,
                "canonicalName": name,
                "category": cat,
                "cuisine": cuisine,
                "inFitFuel238": True,
            })
    return foods


def generate_clean_aliases(name: str, category: str, cuisine: str, used_strings: set) -> list:
    candidates = []
    if name in EXPLICIT_ALIASES:
        candidates.extend(EXPLICIT_ALIASES[name])

    lname = name.lower().strip()
    candidates.append(f"fresh {lname}")
    if cuisine.lower() not in lname and cuisine != "Global":
        candidates.append(f"{cuisine.lower()} {lname}")
    candidates.append(f"plate of {lname}")
    candidates.append(f"serving of {lname}")

    selected = []
    for c in candidates:
        norm_c = re.sub(r"\s+", " ", c.lower().strip())
        if norm_c and norm_c not in used_strings and len(selected) < 3:
            used_strings.add(norm_c)
            selected.append(c.strip())
    return selected


# Distinct global dishes bank (carefully avoiding near-synonyms of the 50 V5 or benchmark dishes)
DISTINCT_WORLD_DISHES = [
    # Indian Regional Specialties
    ("Indian", "Breakfast", [
        "Thalipeeth", "Methi Thepla", "Handvo", "Misal Pav", "Sabudana Vada",
        "Batata Vada", "Maddur Vada", "Puttu", "Idiyappam", "Akki Roti",
        "Ragi Mudde", "Jolada Rotti", "Puran Poli", "Amritsari Kulcha", "Sindhi Koki",
        "Dal Pakwan", "Luchi", "Radhaballabhi", "Pesarattu", "Adai",
        "Paniyaram", "Neer Dosa", "Pathiri", "Khaman", "Fafda",
    ]),
    ("Indian", "Curries & Gravies", [
        "Malai Kofta", "Navratan Korma", "Dum Aloo", "Baingan Bharta", "Gatte ki Sabzi",
        "Ker Sangri", "Undhiyu", "Sarson ka Saag", "Kadhi Pakora", "Panchmel Dal",
        "Cholar Dal", "Mor Kuzhambu", "Vatha Kuzhambu", "Ennai Kathirikai", "Avial",
        "Olan", "Kootu", "Guthi Vankaya", "Gongura Pachadi", "Mirchi ka Salan",
        "Mutton Rogan Josh", "Laal Maas", "Kosha Mangsho", "Keema Matar", "Nihari",
        "Haleem", "Dhansak", "Meen Moilee", "Shorshe Ilish", "Chingri Malai Curry",
        "Prawn Balchao", "Crab Masala", "Aloo Posto", "Potoler Dolma", "Dhokar Dalna",
        "Mochar Ghonto", "Shukto", "Begun Bhaja", "Doi Maach", "Bhetki Paturi",
        "Litti Chokha", "Masor Tenga", "Odia Dalma", "Santula", "Chepala Pulusu",
        "Royyala Iguru", "Beef Ularthiyathu", "Karimeen Pollichathu", "Kori Gassi", "Bharli Vangi",
        "Pithla Bhakri", "Matki Usal", "Tambda Rassa", "Sol Kadhi", "Dal Dhokli",
        "Sev Tameta", "Dal Baati Churma", "Gushtaba", "Rista", "Tabak Maaz",
        "Nadru Yakhni", "Soya Chaap Masala", "Methi Malai Matar", "Kaju Curry", "Kofta Curry",
    ]),
    ("Indian", "Rice Dishes", [
        "Kashmiri Pulao", "Yakhni Pulao", "Curd Rice", "Lemon Rice", "Tamarind Rice",
        "Coconut Rice", "Tomato Bath", "Bisi Bele Bath", "Vangi Bath", "Masala Khichdi",
        "Palak Khichdi", "Bajra Khichdi", "Bhoger Khichuri", "Bagara Khana", "Zarda Pulao",
        "Tahiri Rice", "Masale Bhaat", "Pakhala Bhata", "Kanika", "Kappa Biriyani",
    ]),
    ("Indian", "Street Food & Chaat", [
        "Dahi Puri", "Sev Puri", "Ragda Pattice", "Aloo Tikki Chaat", "Papdi Chaat",
        "Dahi Bhalla", "Palak Patta Chaat", "Ram Ladoo", "Daulat ki Chaat", "Kutchi Dabeli",
        "Vada Pav", "Kanda Bhaji", "Mirchi Bajji", "Bread Pakora", "Kathi Roll",
        "Jhalmuri", "Ghugni", "Chana Jor Garam", "Gobi Manchurian", "Chilli Paneer",
        "Honey Chilli Potato", "Chicken 65", "Chicken Lollipop", "Apollo Fish", "Kothimbir Vadi",
        "Alu Vadi", "Chakli", "Karanji", "Shankarpali", "Mirchi Vada",
        "Kalmi Vada", "Hara Bhara Kebab", "Dahi ke Kebab", "Punugulu", "Goli Baje",
    ]),
    ("Indian", "Desserts & Sweets", [
        "Rasmalai", "Rajbhog", "Chhena Poda", "Sandesh", "Mishti Doi",
        "Patishapta", "Malpua", "Rabri", "Basundi", "Shrikhand",
        "Aamras", "Moong Dal Halwa", "Sooji Halwa", "Badam Halwa", "Karachi Halwa",
        "Tirunelveli Halwa", "Kaju Katli", "Motichoor Ladoo", "Mysore Pak", "Kalakand",
        "Mathura Peda", "Dharwad Peda", "Kaju Barfi", "Anjeer Barfi", "Gujiya",
        "Ukadiche Modak", "Shahi Tukda", "Double ka Meetha", "Qubani ka Meetha", "Sheer Khurma",
        "Phirni", "Seviyan Kheer", "Ada Pradhaman", "Palada Payasam", "Ghevar",
        "Imarti", "Balushahi", "Chiroti", "Pootharekulu", "Ariselu",
        "Malai Kulfi", "Falooda", "Chhena Jhili", "Rasabali", "Unniyappam",
        "Neyyappam", "Kozhukattai", "Mohanthal", "Sukhdi", "Shufta",
    ]),
    ("South Asian", "Main Dishes", [
        "Kottu Roti", "String Hoppers", "Pol Sambol", "Fish Ambul Thiyal", "Dal Bhat Tarkari",
        "Newari Choila", "Thukpa", "Sel Roti", "Yomari", "Chapli Kebab",
        "Seekh Kebab", "Shami Kebab", "Galouti Kebab", "Kakori Kebab", "Bihari Kebab",
        "Mutton Karahi", "Sindhi Sai Bhaji", "Bhuna Khichuri", "Beef Tehari", "Mezbani Beef",
        "Chotpoti", "Mughlai Paratha", "Bakarkhani", "Sheermal", "Taftan",
        "Roghni Naan", "Peshawari Naan", "Keema Naan", "Lamprais", "Kiribath",
        "Watalappan", "Kukul Mas Curry", "Parippu", "Aluwa", "Kokis",
    ]),
    ("East Asian", "Main Dishes", [
        "Chirashi Bowl", "Tekkadon", "Unadon", "Gyudon", "Katsudon",
        "Oyakodon", "Tendon Bowl", "Tonkatsu Pork Cutlet", "Japanese Katsu Curry", "Shrimp Tempura",
        "Okonomiyaki", "Yakitori Skewers", "Yakisoba", "Zaru Soba", "Tsukemen",
        "Tantanmen", "Chawanmushi", "Agedashi Tofu", "Miso Soup", "Wakame Salad",
        "Onigiri Rice Ball", "Omurice", "Taiyaki", "Mochi", "Dorayaki",
        "Castella Cake", "Dango", "Peking Duck", "Kung Pao Chicken", "General Tso Chicken",
        "Mapo Tofu", "Yu Xiang Pork", "Twice Cooked Pork", "Dongpo Pork", "Char Siu BBQ Pork",
        "Siu Yuk Roast Pork", "Beef and Broccoli", "Mongolian Beef", "Sichuan Hot Pot", "Dan Dan Noodles",
        "Zha Jiang Mian", "Lanzhou Beef Noodles", "Beef Chow Fun", "Yangzhou Fried Rice", "Congee Porridge",
        "Hot and Sour Soup", "Wonton Soup", "Xiao Long Bao", "Har Gow Dim Sum", "Siu Mai",
        "Char Siu Bao", "Baozi Steamed Buns", "Sheng Jian Bao", "Potstickers", "Scallion Pancakes",
        "Turnip Cake", "Cheung Fun", "Hong Kong Egg Tart", "Mango Pomelo Sago", "Tangyuan",
        "Mooncake", "Jian Dui", "Gua Bao", "Taiwanese Beef Noodle Soup", "Lu Rou Fan",
        "San Bei Ji", "Oyster Omelette", "Pineapple Cake", "Baobing Shaved Ice", "Bulgogi Beef",
        "LA Galbi", "Samgyeopsal", "Bossam", "Dakgalbi", "Yangnyeom Chicken",
        "Jjimdak", "Tteokbokki", "Japchae Glass Noodles", "Jajangmyeon", "Jjamppong",
        "Naengmyeon", "Kalguksu", "Kimchi Jjigae", "Sundubu Jjigae", "Doenjang Jjigae",
        "Budae Jjigae", "Galbitang", "Samgyetang", "Seolleongtang", "Gamjatang",
        "Kimbap Roll", "Haemul Pajeon", "Mandu Dumplings", "Hotteok", "Bungeoppang",
        "Patbingsu", "Sukiyaki", "Shabu Shabu", "Kaiseki Platter", "Negitoro",
        "Tamagoyaki", "Karaage Chicken", "Korokke Croquette", "Nikujaga", "Oden Stew",
        "Ochazuke", "Monjayaki", "Kushikatsu", "Fugu Sashimi", "Anmitsu",
        "Warabimochi", "Yatsuhashi", "Imagawayaki", "Melonpan", "Anpan",
        "Curry Bread Kare Pan", "Yurinchi", "Ebi Chili", "Ma La Xiang Guo", "Kou Shui Ji",
        "La Zi Ji", "Suan Cai Yu", "Fu Qi Fei Pian", "Guobaorou", "Di San Xian",
        "Jing Jiang Rou Si", "Rou Jia Mo", "Yangrou Paomo", "Liangpi Cold Noodles", "Biangbiang Noodles",
        "Guilin Rice Noodles", "Crossing the Bridge Noodles", "Claypot Rice", "Salted Fish Chicken Rice", "Hakka Stuffed Tofu",
        "Poon Choi", "Lo Mai Gai", "Taro Dumpling Wu Gok", "Mango Pudding", "Tofu Fa",
        "Gui Ling Gao", "Sachima", "Wife Cake Lou Po Beng", "Dragon Beard Candy", "Tanghulu",
        "You Tiao Cruller", "Doujiang Soy Milk", "Zongzi Sticky Rice Dumpling", "Nian Gao", "Aiyu Jelly",
    ]),
    ("Southeast Asian", "Main Dishes", [
        "Pad See Ew", "Pad Kee Mao", "Boat Noodles", "Tom Yum Goong", "Tom Kha Gai",
        "Thai Green Curry", "Thai Red Curry", "Panang Curry", "Massaman Curry", "Pad Kra Pao",
        "Som Tum Papaya Salad", "Larb Salad", "Yam Woon Sen", "Khao Pad", "Chicken Satay",
        "Moo Ping", "Tod Mun Pla", "Mango Sticky Rice", "Tub Tim Krob", "Bun Bo Hue",
        "Bun Cha", "Cao Lau", "Mi Quang", "Hu Tieu", "Banh Mi Baguette",
        "Goi Cuon Summer Rolls", "Cha Gio", "Banh Cuon", "Com Tam", "Bo Luc Lac",
        "Ca Kho To", "Che Ba Mau", "Nasi Goreng", "Mie Goreng", "Beef Rendang",
        "Soto Ayam", "Bakso", "Gado Gado", "Pecel Lele", "Ayam Goreng",
        "Ayam Bakar", "Babi Guling", "Opor Ayam", "Gudeg", "Pempek",
        "Martabak Manis", "Es Cendol", "Klepon", "Nasi Lemak", "Hainanese Chicken Rice",
        "Char Kway Teow", "Curry Laksa", "Asam Laksa", "Hokkien Mee", "Mee Rebus",
        "Roti Canai", "Murtabak", "Nasi Kerabu", "Bak Kut Teh", "Chilli Crab",
        "Black Pepper Crab", "Kaya Toast", "Rojak", "Ice Kachang", "Kuih Lapis",
        "Onde Onde", "Chicken Adobo", "Sinigang", "Kare Kare", "Lechon Kawali",
        "Sisig", "Crispy Pata", "Pancit Canton", "Lumpia Shanghai", "Arroz Caldo",
        "Bulalo", "Tinola", "Bistek Tagalog", "Chicken Inasal", "Halo-Halo",
        "Leche Flan", "Bibingka", "Ube Halaya", "Turon", "Taho",
        "Palabok", "Laing Taro Leaves", "Pinakbet", "Bicol Express", "Dinuguan",
        "Kaldereta", "Mechado", "Menudo Filipino", "Pochero", "Longganisa",
        "Tapsilog", "Tocino", "Champorado", "Puto", "Kutsinta",
        "Suman", "Buko Pandan", "Sans Rival", "Silvanas", "Ensaymada",
        "Mohinga", "Tea Leaf Salad Lahpet Thoke", "Shan Noodles", "Ohn No Khao Swè", "Burmese Tofu",
        "Fish Amok", "Lok Lak", "Nom Banh Chok", "Bai Sach Chrouk", "Kuy Teav",
        "Laap Lao", "Tam Mak Hoong", "Khao Poon", "Sai Oua Sausage", "Khao Jee",
    ]),
    ("Middle Eastern", "Main Dishes", [
        "Doner Kebab", "Iskender Kebab", "Adana Kebab", "Shish Tawook", "Kofta Kebab",
        "Mansaf", "Maqluba", "Kabsa", "Mandi", "Machboos",
        "Mujadara", "Ful Medames", "Molokhia", "Hawawshi", "Fattoush Salad",
        "Tabbouleh Salad", "Baba Ganoush", "Muhammara", "Labneh", "Tzatziki",
        "Dolma", "Mahshi", "Kibbeh", "Sambousek", "Fatayer",
        "Manakish Zaatar", "Lahmacun", "Pide Flatbread", "Su Boregi", "Gozleme",
        "Manti Dumplings", "Menemen", "Cilbir", "Imam Bayildi", "Hunkar Begendi",
        "Shorbat Adas", "Sabich", "Zereshk Polo", "Ghormeh Sabzi", "Fesenjan",
        "Tahchin", "Tahdig", "Chelow Kebab", "Joojeh Kebab", "Ash Reshteh",
        "Mirza Ghasemi", "Kashke Bademjan", "Baghali Polo", "Kunafa", "Umm Ali",
        "Basbousa", "Maamoul", "Qatayef", "Lokma", "Turkish Delight",
        "Sesame Halva", "Muhallebi", "Sahlab", "Ayran", "Koofteh Tabrizi",
        "Abgoosht Dizi", "Bademjan Stew", "Gheymeh", "Kuku Sabzi", "Salad Shirazi",
        "Zeytoon Parvardeh", "Mast o Khiar", "Faloodeh", "Sohan", "Gaz Nougat",
        "Bamieh", "Sholezard", "Kleicha", "Masgouf Grilled Carp", "Quzi Lamb",
        "Tepsi Baytinijan", "Mutabbaq", "Saltah", "Fahsa", "Bint Al Sahn",
        "Aseed", "Harees", "Tharid", "Luqaimat", "Balaleet",
        "Khachapuri Adjaruli" if False else "Mtsvadi Skewers", "Khinkali Dumplings", "Badrijani Nigvzit", "Chakhokhbili", "Lobio Bean Stew",
        "Churchkhela", "Tolitma", "Khorovats", "Ghapama", "Harissa Wheat Stew",
    ]),
    ("European", "Main Dishes", [
        "Calzone", "Stromboli", "Focaccia", "Ciabatta", "Bruschetta",
        "Caprese Salad", "Burrata Plate", "Panzanella", "Beef Carpaccio", "Vitello Tonnato",
        "Arancini", "Suppli", "Mushroom Risotto", "Risotto Milanese", "Polenta",
        "Osso Buco", "Saltimbocca", "Chicken Piccata", "Chicken Marsala", "Chicken Parmigiana",
        "Veal Milanese", "Eggplant Parmigiana", "Bistecca Fiorentina", "Minestrone", "Ribollita",
        "Pasta e Fagioli", "Cioppino", "Tiramisu", "Panna Cotta", "Sicilian Cannoli",
        "Affogato", "Biscotti", "Panettone", "Maritozzo", "Sfogliatella",
        "Pain au Chocolat", "Baguette", "Brioche", "Croque Monsieur", "Croque Madame",
        "Quiche Lorraine", "French Onion Soup", "Vichyssoise", "Bouillabaisse", "Ratatouille",
        "Beef Bourguignon", "Coq au Vin", "Duck Confit", "Steak Frites", "Steak Tartare",
        "Moules Marinières", "Escargots", "Cassoulet", "Salade Niçoise", "Gratin Dauphinois",
        "Gougères", "Cheese Soufflé", "Crème Brûlée", "French Macarons", "Chocolate Éclair",
        "Profiteroles", "Mille-Feuille", "Tarte Tatin", "Lemon Meringue Tart", "Paris-Brest",
        "Madeleines", "Canelé", "Clafoutis", "Buckwheat Galette", "Fideuà",
        "Gazpacho", "Salmorejo", "Patatas Bravas", "Tortilla Española", "Gambas al Ajillo",
        "Pulpo a la Gallega", "Croquetas", "Pan con Tomate", "Pimientos de Padrón", "Fabada Asturiana",
        "Cochinillo Asado", "Crema Catalana", "Tarta de Santiago", "Basque Cheesecake", "Bacalhau à Brás",
        "Caldo Verde", "Francesinha", "Piri Piri Chicken", "Bifana", "Arroz de Pato",
        "Moussaka", "Pastitsio", "Chicken Souvlaki", "Pork Gyro", "Lamb Kleftiko",
        "Stifado", "Tiropita", "Saganaki", "Grilled Halloumi", "Avgolemono Soup",
        "Gigantes Plaki", "Loukoumades", "Galaktoboureko", "Bougatsa", "Full English Breakfast",
        "Shepherd's Pie", "Cottage Pie", "Bangers and Mash", "Beef Wellington", "Yorkshire Pudding",
        "Toad in the Hole", "Cornish Pasty", "Scotch Egg", "Sausage Roll", "Ploughman's Lunch",
        "Bubble and Squeak", "Cullen Skink", "Sticky Toffee Pudding", "Eton Mess", "English Trifle",
        "Banoffee Pie", "Victoria Sponge", "Scones with Clotted Cream", "Apple Crumble", "Wiener Schnitzel",
        "Schweinshaxe", "Bratwurst", "Currywurst", "Sauerbraten", "Spätzle",
        "Käsespätzle", "Kartoffelsalat", "Flammkuchen", "Bavarian Pretzel", "Apple Strudel",
        "Black Forest Cake", "Kaiserschmarrn", "Sachertorte", "Swiss Cheese Fondue", "Raclette",
        "Zürcher Geschnetzeltes", "Swiss Rösti", "Bircher Muesli", "Carbonnade Flamande", "Speculoos",
        "Bitterballen", "Poffertjes", "Polish Pierogi", "Bigos Stew", "Zurek Soup",
        "Gołąbki Cabbage Rolls", "Hungarian Goulash", "Chicken Paprikash", "Langos", "Chimney Cake",
        "Beef Stroganoff", "Chicken Kiev", "Pelmeni", "Vareniki", "Blini",
        "Olivier Salad", "Syrniki", "Swedish Meatballs", "Gravlax", "Smørrebrød",
        "Kanelbullar", "Cacio e Pepe", "Bucatini Amatriciana", "Pasta Puttanesca", "Pasta alla Norma",
        "Pasta Primavera", "Penne alla Vodka", "Rigatoni Bolognese", "Fusilli Pesto", "Farfalle Mushroom",
        "Tagliatelle al Ragu", "Linguine Clam Sauce", "Orecchiette Broccoli Rabe", "Cheese Ravioli", "Tortellini in Brodo",
        "Potato Gnocchi", "Baked Ziti", "Stuffed Shells", "Manicotti", "Cannelloni",
    ]),
    ("African", "Main Dishes", [
        "Jollof Rice", "Injera with Wat", "Moroccan Tagine", "Moroccan Couscous", "Egusi Soup",
        "Ogbono Soup", "Efo Riro", "Afang Soup", "Banga Soup", "Okro Soup",
        "Nigerian Pepper Soup", "Fufu", "Banku and Tilapia", "Waakye", "Red Red Bean Stew",
        "Kelewele", "Suya Skewers", "Kilishi", "Moi Moi", "Akara",
        "Puff Puff", "Chin Chin", "Nigerian Meat Pie", "Boli Plantain", "Asun Goat",
        "Nkwobi", "Abacha", "Ofada Rice", "Thieboudienne", "Chicken Yassa",
        "Mafe Peanut Stew", "Attiéké", "Alloco", "Kedjenou", "Ndole",
        "Poulet DG", "Doro Wat", "Misir Wat", "Kik Alicha", "Shiro Wat",
        "Gomen Greens", "Beef Tibs", "Kitfo", "Firfir", "Chechebsa",
        "Sambusa", "Dabo Kolo", "Kenyan Pilau", "Nyama Choma", "Ugali",
        "Sukuma Wiki", "Githeri", "Mukimo", "Kachumbari", "Mandazi",
        "Zanzibar Pizza", "Urojo Soup", "Matoke", "Rolex Egg Wrap", "Luwombo",
        "Harira Soup", "Bissara", "Pastilla", "Zaalouk", "Taktouka",
        "Briouat", "Msemen", "Baghrir", "Rfissa", "Tanjia",
        "Chebakia", "Brik Pastry", "Lablabi", "Mechouia Salad", "Chermoula Fish",
        "Bobotie", "Bunny Chow", "Boerewors", "Chakalaka", "Potjiekos",
        "Sosaties", "Biltong", "Vetkoek", "Koeksisters", "Malva Pudding",
        "Melktert", "Muamba de Galinha", "Cachupa", "Saka Saka", "Moambe Chicken",
        "Kapenta", "Sadza", "Chambo Fish", "Romazava", "Ravitoto",
    ]),
    ("North American", "Main Dishes", [
        "Philly Cheesesteak", "Reuben Sandwich", "Pastrami on Rye", "BLT Sandwich", "Tuna Melt",
        "Egg Salad Sandwich", "Lobster Roll", "Shrimp Po Boy", "Muffuletta", "Monte Cristo",
        "Sloppy Joe", "Corn Dog", "Buffalo Wings", "Chicken and Waffles", "Chicken Tenders",
        "Chicken Fried Steak", "BBQ Baby Back Ribs", "Smoked Beef Brisket", "Pulled Pork", "Ribeye Steak",
        "Filet Mignon", "Prime Rib", "Meatloaf", "Salisbury Steak", "Pot Roast",
        "Chicken Pot Pie", "Roast Turkey", "Glazed Ham", "Pork Chops", "Macaroni Salad",
        "Loaded Baked Potato", "Garlic Mashed Potatoes", "Au Gratin Potatoes", "Tater Tots", "Onion Rings",
        "Mozzarella Sticks", "Jalapeno Poppers", "Spinach Artichoke Dip", "Deviled Eggs", "Shrimp Cocktail",
        "Maryland Crab Cakes", "New England Clam Chowder", "Lobster Bisque", "Broccoli Cheddar Soup", "Chicken Noodle Soup",
        "Tomato Bisque", "Chili con Carne", "Louisiana Gumbo", "Creole Jambalaya", "Crawfish Etouffee",
        "Shrimp and Grits", "Biscuits and Gravy", "Cornbread", "Hushpuppies", "Fried Green Tomatoes",
        "Baked Beans", "Coleslaw", "Cobb Salad", "Waldorf Salad", "Wedge Salad",
        "Salmon Poke Bowl", "Ahi Tuna Poke Bowl", "Loco Moco", "Spam Musubi", "Kalua Pork",
        "Huli Huli Chicken", "Canadian Poutine", "Montreal Smoked Meat", "Nanaimo Bar", "Butter Tart",
        "French Toast", "Eggs Benedict", "Eggs Florentine", "Smoked Salmon Bagel", "Everything Bagel",
        "Breakfast Burrito", "Western Omelette", "Hash Browns", "Corned Beef Hash", "Granola Parfait",
        "Cinnamon Roll", "Banana Bread", "Zucchini Bread", "Coffee Cake", "Apple Pie",
        "Pecan Pie", "Pumpkin Pie", "Key Lime Pie", "Banana Cream Pie", "Cherry Pie",
        "Peach Cobbler", "Fudge Brownie", "Blondie", "Chocolate Chip Cookies", "Snickerdoodle",
        "Red Velvet Cake", "Carrot Cake", "Angel Food Cake", "Lemon Pound Cake", "Vanilla Cupcake",
        "Banana Split", "Chocolate Milkshake", "Funnel Cake", "S'mores", "Clam Cakes",
        "Brunswick Stew", "Burgoo", "Cincinnati Chili", "Frito Pie", "Garbage Plate",
        "Horseshoe Sandwich", "Italian Beef Sandwich", "Jucy Lucy", "Kentucky Hot Brown", "pepperoni Roll",
        "Pork Roll Taylor Ham", "Runza", "Scrapple", "Sonoran Hot Dog", "Spiedie",
        "Toasted Ravioli", "Gooey Butter Cake", "Buckeye Candy", "Whoopie Pie", "Boston Cream Pie",
        "Shoofly Pie", "Derby Pie", "Chess Pie", "Marionberry Pie", "Huckleberry Pie",
        "Bananas Foster", "Beignets", "King Cake", "Pralines", "Mud Pie",
    ]),
    ("Latin American", "Main Dishes", [
        "Quesadilla", "Enchiladas Verdes", "Enchiladas Mole", "Chicken Fajitas", "Chilaquiles",
        "Huevos Rancheros", "Tamales", "Chile Relleno", "Chiles en Nogada", "Mole Poblano",
        "Cochinita Pibil", "Torta Cubana", "Torta Ahogada", "Gorditas", "Sopes",
        "Tlacoyos", "Huaraches", "Tostadas", "Taquitos", "Chimichanga",
        "Elote Street Corn", "Esquites", "Guacamole", "Pico de Gallo", "Queso Fundido",
        "Refried Beans", "Charro Beans", "Arroz Rojo", "Pozole Rojo", "Menudo Soup",
        "Sopa de Tortilla", "Caldo de Res", "Aguachile", "Camarones a la Diabla", "Tres Leches Cake",
        "Churros", "Caramel Flan", "Chocoflan", "Sopapillas", "Conchas Sweet Bread",
        "Arroz con Leche", "Horchata", "Agua de Jamaica", "Peruvian Ceviche", "Tiradito",
        "Lomo Saltado", "Pollo a la Brasa", "Aji de Gallina", "Seco de Cordero", "Causa Rellena",
        "Papa a la Huancaina", "Anticuchos", "Arroz con Mariscos", "Arroz Chaufa", "Rocoto Relleno",
        "Suspiro a la Limeña", "Picarones", "Alfajores", "Chicha Morada", "Brazilian Feijoada",
        "Picanha", "Churrasco", "Moqueca", "Bobo de Camarão", "Vatapá",
        "Acarajé", "Pão de Queijo", "Coxinha", "Pastel de Feira", "Empadão",
        "Farofa", "Baião de Dois", "Brigadeiro", "Beijinho", "Quindim",
        "Argentine Empanada", "Humita", "Asado", "Bife de Chorizo", "Milanesa Napolitana",
        "Choripán", "Provoleta", "Locro Stew", "Matambre", "Medialunas",
        "Pastafrola", "Chocotorta", "Colombian Arepa", "Bandeja Paisa", "Sancocho",
        "Ajiaco", "Lechona", "Patacones", "Tostones", "Maduros Plantains",
        "Pandebono", "Buñuelos", "Cachapa", "Tequeños", "Pabellón Criollo",
        "Hallaca", "Ropa Vieja", "Picadillo", "Lechón Asado", "Cuban Sandwich",
        "Moros y Cristianos", "Yuca con Mojo", "Pastelitos de Guayaba", "Mofongo", "Arroz con Gandules",
        "Pernil", "Alcapurrias", "Tembleque", "Mangú", "Pupusas",
        "Gallo Pinto", "Nacatamal", "Jerk Chicken", "Curry Goat", "Oxtail Stew",
        "Ackee and Saltfish", "Jamaican Beef Patty", "Callaloo", "Trinidadian Doubles", "Bake and Shark",
        "Curanto", "Pastel de Choclo", "Cazuela Chilena", "Completo Hot Dog", "Chorrillana",
        "Salteñas", "Silpancho", "Pique Macho", "Sopa Paraguaya", "Chipa",
        "Vori Vori", "Chivito Sandwich", "Pamplona", "Encebollado", "Fanesca",
        "Llapingachos", "Seco de Chivo", "Bolón de Verde", "Guatita", "Ceviche de Camarón",
    ]),
    ("Global", "Produce & Staples", [
        "Pink Grapefruit", "Pomelo", "Tangerine", "Clementine", "Key Lime",
        "Cantaloupe", "Honeydew Melon", "Blueberries", "Cranberries", "Goji Berries",
        "Mulberries", "Amla Gooseberry", "Apricot", "Nectarine", "Medjool Dates",
        "Raisins", "Passion Fruit", "Lychee", "Rambutan", "Longan",
        "Mangosteen", "Durian", "Jackfruit", "Starfruit", "Persimmon",
        "Custard Apple", "Soursop", "Tamarind", "Bael Fruit", "Jamun",
        "Kumquat", "Quince", "Plantain", "Hass Avocado", "Arugula",
        "Swiss Chard", "Collard Greens", "Mustard Greens", "Watercress", "Bok Choy",
        "Napa Cabbage", "Brussels Sprouts", "Kohlrabi", "Celery", "Fennel",
        "Artichoke", "Leeks", "Scallions", "Shallots", "Turmeric Root",
        "Galangal", "Lemongrass", "Cassava Yuca", "Taro Root", "Lotus Root",
        "Daikon Radish", "Turnip", "Parsnip", "Rutabaga", "Celeriac",
        "Zucchini", "Butternut Squash", "Acorn Squash", "Spaghetti Squash", "Kabocha",
        "Ash Gourd", "Bitter Gourd", "Ridge Gourd", "Snake Gourd", "Pointed Gourd",
        "Ivy Gourd", "Chayote", "Drumstick Moringa", "Cluster Beans", "Broad Beans",
        "Snow Peas", "Sugar Snap Peas", "Tomatillo", "Jalapeno", "Habanero",
        "Poblano Pepper", "Shiitake Mushrooms", "Oyster Mushrooms", "Enoki Mushrooms", "Chanterelle",
        "Porcini", "Black Truffle", "Bamboo Shoots", "Water Chestnuts", "Bean Sprouts",
        "Heart of Palm", "Nopales", "Green Olives", "Kalamata Olives", "Capers",
        "Sun Dried Tomatoes", "Smoked Salmon", "Ahi Tuna", "Halibut", "Sea Bass",
        "Tilapia", "Rainbow Trout", "Mackerel", "Sardines", "Anchovies",
        "Swordfish", "Mahi Mahi", "Red Snapper", "Catfish", "Rohu",
        "Pomfret", "Surmai", "Hilsa", "Crawfish", "Lobster Tail",
        "King Crab", "Snow Crab", "Scallops", "Steamed Mussels", "Manila Clams",
        "Raw Oysters", "Calamari", "Grilled Octopus", "Rotisserie Chicken", "Roast Duck",
        "Quail", "Beef Sirloin", "Beef Tenderloin", "Short Ribs", "Lamb Leg",
        "Lamb Rack", "Pork Tenderloin", "Pork Belly", "Crispy Bacon", "Prosciutto",
        "Pepperoni", "Salami", "Chorizo", "Tempeh", "Seitan",
        "Cheddar Cheese", "Mozzarella", "Parmesan", "Feta Cheese", "Gouda",
        "Brie", "Camembert", "Emmental", "Provolone", "Monterey Jack",
        "Gorgonzola", "Goat Cheese", "Ricotta", "Mascarpone", "Cream Cheese",
        "Almond Milk", "Oat Milk", "Soy Milk", "Coconut Milk", "Kefir",
        "Sour Cream", "Whipping Cream", "Salted Butter", "Ghee", "Poached Egg",
        "Deviled Egg", "Quail Eggs", "Bulgur Wheat", "Farro", "Pearl Barley",
        "Buckwheat Kasha", "Pearl Millet Bajra", "Sorghum Jowar", "Finger Millet Ragi", "Foxtail Millet",
        "Amaranth Grain", "Teff", "Hemp Hearts", "Macadamia Nuts", "Pine Nuts",
        "Roasted Chestnuts", "Cashew Butter", "Sunflower Seed Butter", "Black Sesame Seeds", "Poppy Seeds",
        "Lotus Seeds Makhana", "Trail Mix", "Protein Bar", "Granola Bar", "Espresso",
        "Americano", "Cappuccino", "Caffe Latte", "Flat White", "Caffe Mocha",
        "Cold Brew Coffee", "Hot Chocolate", "Kashmiri Kahwa", "Earl Grey Tea", "Chamomile Tea",
        "Peppermint Tea", "Hibiscus Tea", "Jasmine Tea", "Oolong Tea", "Boba Milk Tea",
        "Thai Iced Tea", "Teh Tarik", "Fresh Orange Juice", "Apple Cider", "Pomegranate Juice",
        "Cranberry Juice", "Sugarcane Juice", "Aam Panna", "Nimbu Pani", "Jaljeera",
        "Kokum Sherbet", "Rooh Afza", "Badam Milk", "Haldi Doodh", "Thandai",
        "Kombucha", "Sparkling Water",
    ]),
]


def build_full_vocabulary():
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(V5_LABELS_PATH, "r", encoding="utf-8") as f:
        v5_set = set(l.strip() for l in f if l.strip())

    fitfuel_238 = parse_fitfuel_238(DART_PREDEFINED_PATH)
    vocab = []
    used_ids = set()
    used_names = set()
    used_all_strings = set()

    # Reserve all explicit aliases first so no canonical food collides with an alias
    for cname, alist in EXPLICIT_ALIASES.items():
        for a in alist:
            used_all_strings.add(a.lower().strip())

    # 1. Add all 238 FitFuel catalog foods first
    for item in fitfuel_238:
        fid = item["canonicalFoodId"]
        name = item["canonicalName"].strip()
        norm_name = name.lower()
        used_ids.add(fid)
        used_names.add(norm_name)
        used_all_strings.add(norm_name)
        vocab.append({
            "canonicalFoodId": fid,
            "canonicalName": name,
            "aliases": [],
            "category": item["category"],
            "optionalParentCategory": PARENT_CATEGORY_MAP.get(item["category"], "Food & Drink"),
            "cuisine": item["cuisine"],
            "inFitFuel238": True,
            "inV5Classes": fid in v5_set,
        })

    # 2. Add legacy benchmark IDs from unsupported_food_manifest
    legacy_mapped = [
        ("predefined_pizza", "Cheese Pizza", "Pizza & Flatbreads", "European"),
        ("predefined_burger", "Burger", "Sandwiches & Wraps", "North American"),
        ("predefined_pasta", "Pasta", "Pasta & Noodles", "European"),
        ("predefined_sushi", "Sushi", "Main Dishes", "East Asian"),
        ("predefined_ramen", "Ramen Noodles", "Pasta & Noodles", "East Asian"),
        ("predefined_noodles", "Fried Noodles", "Pasta & Noodles", "East Asian"),
        ("predefined_tacos", "Mexican Tacos", "Main Dishes", "Latin American"),
        ("predefined_burrito", "Burrito", "Sandwiches & Wraps", "Latin American"),
        ("predefined_nachos", "Nachos with Cheese", "Snacks", "Latin American"),
        ("predefined_sandwich", "Club Sandwich", "Sandwiches & Wraps", "North American"),
        ("predefined_pancakes", "Pancakes", "Breakfast", "North American"),
        ("predefined_waffle", "Belgian Waffle", "Breakfast", "European"),
        ("predefined_crepes", "Sweet Crepes", "Desserts", "European"),
        ("predefined_donut", "Glazed Donut", "Desserts", "North American"),
        ("predefined_muffin", "Blueberry Muffin", "Breakfast", "North American"),
        ("predefined_hot_dog", "Hot Dog", "Snacks", "North American"),
        ("predefined_french_fries", "French Fries", "Snacks", "North American"),
        ("predefined_chocolate_cake", "Chocolate Cake", "Desserts", "European"),
        ("predefined_ice_cream", "Ice Cream", "Desserts", "Global"),
        ("predefined_baklava", "Baklava", "Desserts", "Middle Eastern"),
        ("predefined_pani_puri", "Pani Puri", "Street Food & Chaat", "Indian"),
        ("predefined_bhel_puri", "Bhel Puri", "Street Food & Chaat", "Indian"),
        ("predefined_pav_bhaji", "Pav Bhaji", "Street Food & Chaat", "Indian"),
        ("predefined_biryani", "Chicken Biryani", "Rice Dishes", "Indian"),
        ("predefined_veg_biryani", "Vegetable Biryani", "Rice Dishes", "Indian"),
        ("predefined_butter_chicken", "Butter Chicken", "Curries & Gravies", "Indian"),
        ("predefined_paneer_butter_masala", "Paneer Butter Masala", "Curries & Gravies", "Indian"),
        ("predefined_chicken_curry", "Chicken Curry", "Curries & Gravies", "Indian"),
        ("predefined_dal_makhani", "Dal Makhani", "Curries & Gravies", "Indian"),
        ("predefined_fish_curry", "Fish Curry", "Curries & Gravies", "Indian"),
        ("predefined_gulab_jamun", "Gulab Jamun", "Desserts & Sweets", "Indian"),
    ]
    for fid, name, cat, cuis in legacy_mapped:
        norm_name = name.lower().strip()
        if fid not in used_ids and norm_name not in used_names:
            used_ids.add(fid)
            used_names.add(norm_name)
            used_all_strings.add(norm_name)
            vocab.append({
                "canonicalFoodId": fid,
                "canonicalName": name,
                "aliases": [],
                "category": cat,
                "optionalParentCategory": PARENT_CATEGORY_MAP.get(cat, "Food & Drink"),
                "cuisine": cuis,
                "inFitFuel238": False,
                "inV5Classes": fid in v5_set,
            })

    def add_concept(name: str, cat: str, cuis: str):
        clean_name = re.sub(r"\s+", " ", name.strip())
        if any(oov.lower() in clean_name.lower() for oov in TRUE_TEXT_OOV_EXCLUDED_CONCEPTS):
            return
        norm_name = clean_name.lower()
        if norm_name in used_names or norm_name in used_all_strings:
            return
        fid = f"openvocab_{slugify(clean_name)}"
        if fid in used_ids:
            return
        used_ids.add(fid)
        used_names.add(norm_name)
        used_all_strings.add(norm_name)
        vocab.append({
            "canonicalFoodId": fid,
            "canonicalName": clean_name,
            "aliases": [],
            "category": cat,
            "optionalParentCategory": PARENT_CATEGORY_MAP.get(cat, "Food & Drink"),
            "cuisine": cuis,
            "inFitFuel238": False,
            "inV5Classes": False,
        })

    # 3. Add Protected Canonical Names first
    for pname in sorted(PROTECTED_CANONICAL_NAMES):
        cat = "Pasta & Noodles" if any(k in pname for k in ["Pasta", "Penne", "Spaghetti", "Lasagna", "Macaroni", "Udon", "Noodles", "Pho", "Pad Thai", "Gnocchi", "Ravioli"]) else "Main Dishes"
        cuis = "European" if cat == "Pasta & Noodles" and "Udon" not in pname and "Pho" not in pname and "Pad Thai" not in pname else "Global"
        add_concept(pname, cat, cuis)

    # 4. Add Distinct World Dishes
    for cuis, cat, names in DISTINCT_WORLD_DISHES:
        for n in names:
            add_concept(n, cat, cuis)

    # 5. Add International Regional Specialty Dishes to reach ~1,650 canonical foods
    # while never colliding with existing benchmark food names
    extra_international_specialties = [
        # Regional cheeses, breads, pastries, soups, stews, curries, street foods
        ("European", "Desserts & Sweets", [
            "Zabaione", "Cassata Siciliana", "Struffoli", "Pastiera Napoletana", "Baba au Rhum",
            "Bommeboller", "Kransekake", "Semla Bun", "Prinsesstårta", "Runeberg Tart",
            "Mämmi", "Karjalanpiirakka", "Korvapuusti", "Pulla Bread", "Leipäjuusto",
            "Rugelach", "Hamantaschen", "Babka Chocolate", "Challah Loaf", "Matzo Brei",
            "Kugel Noodle", "Blintzes Cheese", "Latkes Potato", "Sufganiyot", "Charoset",
            "Medovik Honey Cake", "Napoleon Cake Russian", "Ptichye Moloko", "Vatrushka", "Pryaniki",
            "Pastel de Tres Leches", "Pionono", "Yemas de Santa Teresa", "Polvorón", "Turrón",
            "Roscon de Reyes", "Ensaimada", "Fartons", "Leche Frita", "Pestiños",
            "Bolo Rei", "Pão de Ló", "Queijadas", "Travesseiros", "Arroz Doce",
            "Baba Ganoush Libanais", "Loukoumi", "Melomakarona", "Kourabiedes", "Vasilopita",
            "Diples", "Halvas Semolina", "Portokalopita", "Ravani", "Karidopita",
            "Cozonac", "Papanași", "Mucenici", "Plăcintă", "Amandină",
            "Kremšnita", "Gibanica", "Štrukli", "Fritule", "Rožata",
            "Kroštule", "Međimurska Gibanica", "Prekmurska Gibanica", "Potica Roll", "Tufahija",
            "Hurmašice", "Urmašice", "Tulumba", "Kadaif", "Sutlijaš",
            "esterházy Torte", "Dobos Torte", "Somlói Galuska", "Rákóczi Túrós", "Zserbó",
            "Bejgli", "Flódni", "Mákos Guba", "Aranygaluska", "Palacsinta",
            "Kremówka", "Sernik", "Makowiec", "Pączki", "Faworki",
            "Sękacz", "Karpatka", "Wuzetka", "Piernik", "Mazurek",
            "Trdelník", "Kolache", "Buchty", "Vánočka", "Medovník",
            "Bublanina", "Větrník", "Laskonky", "Rakvičky", "Štramberk Ears",
        ]),
        ("European", "Main Dishes", [
            "Svíčková", "Vepřo Knedlo Zelo", "Smažený Sýr", "Bramboráky", "Kulajda",
            "Česnečka", "Zelňačka", "Bryndzové Halušky", "Kapustnica", "Lokše",
            "Žemľovka", "Töltött Káposzta", "Halászlé", "Pörkölt", "Lecsó",
            "Hortobágyi Palacsinta", "Főzelék", "Túrós Csusza", "Rakott Krumpli", "Sarmale",
            "Mămăligă", "Mici Mititei", "Ciorbă de Burtă", "Ciorbă de Perișoare", "Tochitură",
            "Zacuscă", "Salată de Boeuf", "Drob de Miel", "Ostropel", "Varză a la Cluj",
            "Ćevapi", "Pljeskavica", "Burek Meat", "Sarma Rolls", "Ajvar Relish",
            "Kajmak", "Karađorđeva Šnicla", "Mućkalica", "Prebranac", "Pasulj",
            "Riblja Čorba", "Pašticada", "Crni Rižoto", "gregada", "Brudet",
            "Fuži with Truffles", "Maneštra", "Soparnik", "Sinjski Arambašići", "Čobanac",
            "Fiš Paprikaš", "Kotlovina", "Purica s Mlincima", "Kranjska Klobasa", "Jota Stew",
            "Idrijski Žlikrofi", "Bograč", "Ričet", "Šavelski Štruklji", "Frika",
            "Shopska Salad", "Tarator Cold Soup", "Banitsa Pastry", "Kavarma", "Chushkiurek",
            "Bob Chorba", "Shkembe Chorba", "Kyopolou", "Lyutenitsa", "Meshana Skara",
            "Kapama", "Patatnik", "Kachamak", "Mekitsa", "Tavče Gravče",
            "Pastrmajlija", "elski Tava", "Širden", "Kukurek", "Fergese",
            "Tavë Kosi", "Flija", "Byrek", "Qofte", "Speca te Mbushura",
            "Tarhana Soup", "Hünkarbeğendi", "Karnıyarık", "Ali Nazik", "Çiğ Köfte",
            "Mercimek Köftesi", "Kısır Salad", "Yaprak Sarma", "Lahana Sarma", "Zeytinyağlı Enginar",
            "Fasulye Pilaki", "Barbunya Pilaki", "Mücver Zucchini Fritters", "Hamsi Tava", "Midye Dolma",
            "Kokoreç", "Kumpir Stuffed Potato", "Tantuni", "Beyti Kebab", "Testi Kebab",
            "Cağ Kebab", "Çökertme Kebab", "Alinazik Kebab", "Pideli Köfte", "İnegöl Köfte",
            "Akçaabat Köfte", "Sulu Köfte", "Kadınbudu Köfte", "İçli Köfte", "Tepsi Kebabı",
            "Kağıt Kebabı", "Orman Kebabı", "Tas Kebabı", "Hamsili Pilav", "İç Pilav",
            "Perde Pilavı", "Ali Paşa Pilavı", "Keşkek", "Yayla Çorbası", "Ezogelin Çorbası",
            "İşkembe Çorbası", "Beyran Soup", "Yuvalama", "Analı Kızlı", "Hینگel",
        ]),
        ("Asian", "Regional Specialties", [
            "Khao Kha Moo", "Khao Mok Gai", "Khao Kluk Kapi", "Kuay Tiew Kua Gai", "Yen Ta Fo",
            "Suki Haeng", "Rad Na", "Gai Tod Hat Yai", "Pla Pao Salt Crusted Fish", "Goong Ob Woonsen",
            "Poo Pad Pong Karee", "Hor Mok Pla", "Gaeng Som", "Gaeng Keow Wan", "Gaeng Hung Lay",
            "Nam Prik Ong", "Nam Prik Noom", "Sai Ua", "Miang Kham", "Khao Lam",
            "Khanom Krok", "Khanom Buang", "Sangkhaya Fak Thong", "Foi Thong", "Thong Yip",
            "Look Choup", "Lod Chong", "Bua Loi", "Kluay Buat Chi", "Ruam Mit",
            "Banh Beo", "Banh Bot Loc", "Banh Nam", "Banh It Ram", "Banh Khot",
            "Banh Cong", "Banh Trang Nuong", "Banh Trang Tron", "Banh Chung", "Banh Tet",
            "Banh Bao", "Banh Gio", "Banh Day", "Banh Pia", "Banh Da Lon",
            "Banh Bo", "Banh Flan", "Banh Cam", "Xoi Gac", "Xoi Xeo",
            "Xoi Man", "Com Chay", "Com Hen", "Bun Rieu", "Bun Mam",
            "Bun Dau Mam Tom", "Bun Moc", "Bun Mang Vit", "Bun Ca", "Bun Oc",
            "Pho Cuon", "Pho Xao", "Mien Ga", "Mien Luon", "Chao Long",
            "Chao Ga", "Chao Vit", "Bo Kho", "Bo Ne", "Bo La Lot",
            "Nem Nuong", "Nem Chua", "Cha Ca La Vong", "Canh Chua", "Thit Kho Tau",
            "Ga Nuong", "Goi Ga", "Goi Ngo Sen", "Che Chuoi", "Che Troi Nuoc",
            "Che Buoi", "Che Hat Sen", "Sua Chua Nep Cam", "Sinh To Bo", "Nuoc Mia",
            "Rawon Black Beef Soup", "Sop Buntut Oxtail", "Soto Betawi", "Soto Makassar", "Pallubasa",
            "Konro Ribs", "Tongseng", "Gulai Kambing", "Sate Padang", "Sate Lilit",
            "Sate Maranggi", "Ayam Penyet", "Ayam Geprek", "Ayam Taliwang", "Ayam Betutu",
            "Bebek Goreng", "Bebek Betutu", "Ikan Bakar", "Pepes Ikan", "Otak Otak",
            "Siomay Bandung", "Batagor", "Cilok", "Cireng", "Seblak",
            "Ketoprak", "Karedok", "Rujak Cingur", "Tahu Gejrot", "Tahu Tek",
            "Lontong Sayur", "Lontong Balap", "Ketupat Sayur", "Nasi Uduk", "Nasi Kuning",
            "Nasi Liwet", "Nasi Padang", "Nasi Campur", "Nasi Kucing", "Nasi Pecel",
            "Nasi Rawon", "Nasi Timbel", "Tinutuan", "Bubur Ayam", "Bubur Manado",
            "Bubur Sumsum", "bubur Ketan Hitam", "Kolak Pisang", "Es Teler", "Es Doger",
            "Es Pisang Ijo", "Es Campur", "Serabi", "Kue Putu", "Kue Cubit",
            "Kue Lumpur", "Kue Ape", "Kue Pancong", "Kue Pukis", "Lemper",
            "Risoles", "Pastel Goreng", "Bakwan Jagung", "Tempe Mendoan", "Tahu Isi",
            "Pisang Goreng", "Kerak Telor", "Bika Ambon", "Lapis Legit", "Nastar",
        ]),
    ]

    for cuis, cat, names in extra_international_specialties:
        for n in names:
            add_concept(n, cat, cuis)

    # Generate strictly deduplicated aliases for every canonical concept
    for entry in vocab:
        entry["aliases"] = generate_clean_aliases(
            entry["canonicalName"],
            entry["category"],
            entry["cuisine"],
            used_all_strings,
        )

    negative_concepts = [
        {"canonicalFoodId": "neg_not_food", "canonicalName": "not food", "aliases": ["non-food object", "inanimate background", "empty scene"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_empty_plate", "canonicalName": "empty plate", "aliases": ["clean empty dish", "empty ceramic plate", "empty bowl on table"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_human_hand", "canonicalName": "human hand", "aliases": ["person hand fingers", "human face portrait", "person body"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_phone", "canonicalName": "smartphone", "aliases": ["mobile phone", "cellphone screen", "telephone device"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_laptop", "canonicalName": "laptop computer", "aliases": ["computer keyboard", "notebook computer monitor", "electronic device"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_table_desk", "canonicalName": "wooden desk table", "aliases": ["office desk", "furniture chair sofa", "wooden table surface"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_utensils", "canonicalName": "metal utensils fork spoon knife", "aliases": ["cutlery fork and spoon", "kitchen knife", "empty kitchenware"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_packaging", "canonicalName": "closed packaging box", "aliases": ["cardboard package", "plastic bottle wrapper", "shopping bag backpack"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_shoe_clothing", "canonicalName": "footwear shoe sneakers", "aliases": ["running shoe", "leather boot", "clothing apparel"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_vehicle_car", "canonicalName": "automobile car", "aliases": ["motor vehicle", "street car", "outdoor street lamp bench"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_plant_decor", "canonicalName": "houseplant indoor decor", "aliases": ["potted plant leaves", "wall clock painting", "acoustic guitar"], "category": "Non-Food"},
        {"canonicalFoodId": "neg_pet_animal", "canonicalName": "domestic pet cat dog", "aliases": ["pet dog", "pet cat", "animal"], "category": "Non-Food"},
    ]

    alias_mapping = {}
    for entry in vocab:
        cid = entry["canonicalFoodId"]
        alias_mapping[entry["canonicalName"].lower()] = cid
        for a in entry["aliases"]:
            alias_mapping[a.lower()] = cid

    total_aliases = sum(len(e["aliases"]) for e in vocab)
    total_text_entries = len(vocab) + total_aliases
    cuisines_count = Counter(e["cuisine"] for e in vocab)
    categories_count = Counter(e["category"] for e in vocab)
    fitfuel_covered = sum(1 for e in vocab if e["inFitFuel238"])

    payload = {
        "phase": "35.11A.1",
        "canonicalFoodsCount": len(vocab),
        "aliasesCount": total_aliases,
        "totalFoodTextEntries": total_text_entries,
        "negativeConceptsCount": len(negative_concepts),
        "fitFuel238CoverageCount": fitfuel_covered,
        "fitFuel238CoveragePercent": round(fitfuel_covered / 238.0 * 100.0, 2),
        "v5OverlapCount": sum(1 for e in vocab if e["inV5Classes"]),
        "unseenToV5CanonicalCount": sum(1 for e in vocab if not e["inV5Classes"]),
        "cuisineDistribution": dict(cuisines_count),
        "categoryDistribution": dict(categories_count),
        "trueTextOovExcludedConcepts": sorted(TRUE_TEXT_OOV_EXCLUDED_CONCEPTS),
        "entries": vocab,
        "negativeConcepts": negative_concepts,
    }

    vocab_path = os.path.join(OUT_DIR, "vocabulary_35_11a1.json")
    with open(vocab_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    alias_path = os.path.join(OUT_DIR, "alias_mapping_35_11a1.json")
    with open(alias_path, "w", encoding="utf-8") as f:
        json.dump(alias_mapping, f, indent=2)

    print(f"Canonical foods: {len(vocab)}")
    print(f"Aliases: {total_aliases}")
    print(f"Total food text entries: {total_text_entries}")
    print(f"FitFuel 238 coverage: {fitfuel_covered}/238 ({fitfuel_covered/238*100:.1f}%)")
    print(f"Cuisines: {dict(cuisines_count)}")


if __name__ == "__main__":
    build_full_vocabulary()
