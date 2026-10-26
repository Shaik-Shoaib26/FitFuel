import json

with open('tools/benchmarks/food_open_vocabulary/device_results_RZCW8201QBV_35_11a2.json') as f:
    dev = json.load(f)

preds = dev['models']['siglip_b16_int8']['suitePredictions']

def is_exact_or_verified_alias(ground_truth: str, pred_name: str) -> bool:
    gt = ground_truth.lower().strip()
    p = pred_name.lower().strip()
    if gt == p:
        return True
    aliases = {
        'butter chicken': ['butter chicken (murgh makhani)', 'murgh makhani'],
        'butter chicken (murgh makhani)': ['butter chicken', 'murgh makhani'],
        'plain dosa': ['dosa', 'plain dosa'],
        'dosa': ['plain dosa', 'dosa'],
        'burger': ['burger', 'hamburger'],
        'samosa': ['samosa'],
        'mexican tacos': ['tacos', 'mexican tacos'],
        'creamy penne pasta': ['creamy penne pasta'],
        'vegetable biryani': ['vegetable biryani', 'veg biryani'],
        'paneer tikka': ['paneer tikka'],
        'idli': ['idli'],
        'sushi': ['sushi'],
        'pasta alfredo': ['pasta alfredo'],
        'spaghetti carbonara': ['spaghetti carbonara', 'carbonara'],
    }
    for k, v in aliases.items():
        if (gt == k or gt in v) and (p == k or p in v):
            return True
    return False

def get_culinary_family(name: str) -> str:
    n = name.lower()
    if any(x in n for x in ['pasta', 'penne', 'spaghetti', 'alfredo', 'carbonara', 'fideuà', 'ravioli', 'noodle', 'noodles', 'ramen', 'tsukemen', 'pho', 'macaroni']):
        return 'pasta_noodles'
    if any(x in n for x in ['pizza', 'flammkuchen', 'ciabatta', 'focaccia', 'smørrebrød']):
        return 'pizza_flatbread'
    if any(x in n for x in ['burger', 'sandwich', 'jucy lucy', 'blt', 'bake and shark']):
        return 'burger_sandwich'
    if any(x in n for x in ['dosa', 'idli', 'vada', 'appam', 'uttapam']):
        return 'south_indian'
    if any(x in n for x in ['biryani', 'rice', 'pulao']):
        return 'rice_biryani'
    if any(x in n for x in ['curry', 'masala', 'paneer', 'tikka', 'samosa', 'sambusa', 'briouat', 'makhani']):
        return 'indian_curry_savory'
    if any(x in n for x in ['taco', 'tostada']):
        return 'mexican'
    if any(x in n for x in ['sushi', 'tempura']):
        return 'japanese_seafood'
    if any(x in n for x in ['chicken paprikash', 'poulet']):
        return 'poultry'
    return 'other'

def has_confusable_siblings(top_names, margin12):
    joined = " | ".join(top_names).lower()
    if ("pizza" in joined or "flammkuchen" in joined or "zanzibar" in joined) and ("flammkuchen" in joined or "zanzibar" in joined):
        if margin12 < 0.025:
            return True
    if ("ramen" in joined or "tsukemen" in joined or "mien ga" in joined) and ("tsukemen" in joined or "mien ga" in joined):
        if margin12 < 0.025:
            return True
    # All pasta siblings (e.g. Carbonara, Bolognese, Penne, Alfredo, Spaghetti, Fideua)
    pasta_words = ['spaghetti', 'bolognese', 'carbonara', 'alfredo', 'penne', 'chili', 'fideuà', 'macaroni', 'ravioli']
    pasta_matches = [w for w in pasta_words if w in joined]
    if len(set(pasta_matches)) >= 2 and margin12 < 0.030:
        return True
    return False

eligible = [p for p in preds if p.get('testGroup') not in ['non_food_safety', 'mixed_meal']]

for min_m12 in [0.015, 0.016, 0.018]:
    for min_sim in [0.080, 0.085, 0.090]:
        accepted = []
        for p in eligible:
            t1 = p['top5'][0]
            t2 = p['top5'][1] if len(p['top5']) > 1 else None
            top1_sim = t1['score']
            top2_sim = t2['score'] if t2 else 0.0
            m12 = top1_sim - top2_sim
            neg_margin = p['negMargin']
            top_names = [x['name'] for x in p['top5'][:3]]
            gt = p.get('groundTruthName', '')
            t1_name = t1['name']
            t2_name = t2['name'] if t2 else ''

            f1 = get_culinary_family(t1_name)
            f2 = get_culinary_family(t2_name)
            same_family = (f1 == f2 and f1 != 'other')
            confusable = has_confusable_siblings(top_names, m12)

            is_reliable = (
                top1_sim >= min_sim and
                m12 >= min_m12 and
                neg_margin >= 0.075 and
                same_family and
                not confusable
            )

            if is_reliable:
                is_correct = is_exact_or_verified_alias(gt, t1_name)
                accepted.append((p['imageId'], gt, t1_name, is_correct, top1_sim, m12))

        correct = sum(1 for a in accepted if a[3])
        prec = correct / len(accepted) if accepted else 0.0
        cov = len(accepted) / len(eligible)
        print(f"sim>={min_sim:.3f} m12>={min_m12:.3f}: Accepted={len(accepted)}, Correct={correct}, Prec={prec*100:.1f}%, Cov={cov*100:.1f}%")
        for a in accepted:
            print(f"   Acc: {a[0]} gt='{a[1]}' top1='{a[2]}' correct={a[3]} sim={a[4]:.4f} m12={a[5]:.4f}")
