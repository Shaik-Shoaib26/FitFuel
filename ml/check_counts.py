import json
import urllib.request
import urllib.parse
from collect_dataset import FOOD_CLASSES, USER_AGENT

def check_available_counts():
    print(f"Checking available images on Wikimedia Commons for {len(FOOD_CLASSES)} classes...")
    total_avail = 0
    results = {}
    for idx, food in enumerate(FOOD_CLASSES, 1):
        food_id = food["food_id"]
        food_name = food["food_name"]
        queries = food["queries"]
        seen_titles = set()
        for q in queries:
            params = {
                "action": "query",
                "generator": "search",
                "gsrsearch": q,
                "gsrnamespace": "6",
                "gsrlimit": "50",
                "prop": "imageinfo",
                "iiprop": "url",
                "format": "json"
            }
            url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    pages = data.get("query", {}).get("pages", {})
                    for pid, p in pages.items():
                        title = p.get("title", "")
                        lower_title = title.lower()
                        if any(ext in lower_title for ext in [".svg", ".pdf", ".ogg", ".webm", ".mp4", ".gif", ".tif"]):
                            continue
                        seen_titles.add(title)
            except Exception as e:
                pass
        results[food_id] = len(seen_titles)
        total_avail += len(seen_titles)
        print(f"[{idx:02d}/50] {food_name}: ~{len(seen_titles)} images found")

    print(f"\nTotal potential images: {total_avail}")
    print(f"Min: {min(results.values())}, Max: {max(results.values())}")

if __name__ == "__main__":
    check_available_counts()
