import json
import csv
import sys

def main():
    with open('tools/benchmarks/food_open_vocabulary/device_results_RZCW8201QBV_35_11a2.json') as f:
        dev = json.load(f)

    preds = dev['models']['siglip_b16_int8']['suitePredictions']

    # Filter out non-food and mixed meals to evaluate single-food predictions
    by_group = {}
    for p in preds:
        g = p.get('testGroup', 'other')
        by_group.setdefault(g, []).append(p)

    for g, items in by_group.items():
        print(f"=== Group {g} (count={len(items)}) ===")
        for p in items:
            t1 = p['top5'][0]
            t2 = p['top5'][1] if len(p['top5']) > 1 else None
            m12 = t1['score'] - t2['score'] if t2 else t1['score']
            gt = p.get('groundTruthName', '')
            t1_name = t1['name']
            exact = gt.lower() in t1_name.lower() or t1_name.lower() in gt.lower()
            print(f"  {p['imageId']}: gt='{gt}' top1='{t1_name}' ({t1['score']:.4f}) top2='{t2['name'] if t2 else None}' margin12={m12:.4f} neg_margin={p['negMargin']:.4f} match={exact}")

if __name__ == '__main__':
    main()
