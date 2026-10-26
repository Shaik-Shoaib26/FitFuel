import json

with open('tools/benchmarks/food_open_vocabulary/device_results_RZCW8201QBV_35_11a2.json') as f:
    dev = json.load(f)

preds = dev['models']['siglip_b16_int8']['suitePredictions']
eligible_food_images = [p for p in preds if p.get('testGroup') not in ['non_food_safety', 'mixed_meal']]

for p in eligible_food_images:
    t1 = p['top5'][0]
    t2 = p['top5'][1] if len(p['top5']) > 1 else None
    top1_sim = t1['score']
    top2_sim = t2['score'] if t2 else 0.0
    m12 = top1_sim - top2_sim
    neg_margin = p['negMargin']
    gt = p.get('groundTruthName', '')
    t1_name = t1['name']
    print(f"{p['imageId']}: gt='{gt}' top1='{t1_name}' sim={top1_sim:.4f} m12={m12:.4f} neg={neg_margin:.4f}")
