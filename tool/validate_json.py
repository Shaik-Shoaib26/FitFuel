import json
import sys

def check_json(file_path):
    print(f"Checking {file_path}...")
    duplicates = []
    
    def dict_raise_on_duplicates(ordered_pairs):
        d = {}
        for k, v in ordered_pairs:
            if k in d:
                duplicates.append(k)
            d[k] = v
        return d

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    try:
        data = json.loads(content, object_pairs_hook=dict_raise_on_duplicates)
    except Exception as e:
        print(f"JSON syntax error: {e}")
        sys.exit(1)

    if duplicates:
        print(f"ERROR: Duplicate keys found: {duplicates}")
        sys.exit(1)
    else:
        print("No duplicate keys found at top level.")

    # Check the three target foods
    targets = ['predefined_almond_butter', 'predefined_aloo_methi', 'predefined_grilled_fish_tikka']
    for t in targets:
        if t not in data:
            print(f"ERROR: {t} missing from json!")
            sys.exit(1)
        item = data[t]
        print(f"{t}: {item}")
        if item.get("source") != "FitFuel Branded Fallback" or item.get("license") != "FitFuel Open Design System":
            print(f"WARNING: {t} does not match expected fallback!")

    print(f"Total entries: {len(data)}")
    print("JSON validation PASSED!")

if __name__ == '__main__':
    check_json('assets/data/food_image_sources.json')
