import json
import os
import sys
from pathlib import Path
import numpy as np
import onnxruntime as ort
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

BASE_DIR = Path(r"c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary")
ONNX_DIR = BASE_DIR / "onnx_models"
ASSET_DIR = BASE_DIR / "device_assets"
IMG_DIR = ASSET_DIR / "images"
RESULTS_JSON = BASE_DIR / "device_results_RZCW8201QBV_35_11a2.json"
OFFLINE_JSON = BASE_DIR / "offline_verification_RZCW8201QBV_35_11a2.json"
INSPECT_TXT = BASE_DIR / "inspect_out.txt"

def preprocess_android_exact(img_path: Path, arch: str) -> np.ndarray:
    with Image.open(img_path) as im:
        im = im.convert("RGB")
        w, h = im.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        cropped = im.crop((left, top, left + side, top + side))
        if side != 224:
            scaled = cropped.resize((224, 224), Image.Resampling.BILINEAR)
        else:
            scaled = cropped
        arr = np.asarray(scaled, dtype=np.float32)
        if arch == "siglip":
            arr = arr / 127.5 - 1.0
        else:
            mean = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
            std = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)
            arr = (arr / 255.0 - mean) / std
        chw = np.transpose(arr, (2, 0, 1))[None, ...]
        return chw.astype(np.float32)

def main():
    with open(RESULTS_JSON, "r", encoding="utf-8") as f:
        res = json.load(f)
    with open(ASSET_DIR / "vocab_concepts_2050.json", "r", encoding="utf-8") as f:
        vocab = json.load(f)
    concepts = vocab["concepts"]

    npz = np.load(BASE_DIR / "precomputed_text_embeddings_35_11a1.npz")
    sig_canon = npz["siglip_b16_canonical_fp16"].astype(np.float32)
    tiny_canon = npz["tinyclip_40m_canonical_fp16"].astype(np.float32)

    sig_sess = ort.InferenceSession(str(ONNX_DIR / "siglip_b16_vision_int8.onnx"), providers=["CPUExecutionProvider"])
    tiny_sess = ort.InferenceSession(str(ONNX_DIR / "tinyclip_40m_vision_int8.onnx"), providers=["CPUExecutionProvider"])

    lines = []
    for mk, sess, arch, canon in [
        ("siglip_b16_int8", sig_sess, "siglip", sig_canon),
        ("tinyclip_40m_int8", tiny_sess, "clip", tiny_canon),
    ]:
        m = res["models"][mk]
        preds = m["suitePredictions"]
        top1_exact = 0
        top3_ov = 0.0
        top5_ov = 0.0
        for p in preds:
            iid = p["imageId"]
            img_path = IMG_DIR / f"{iid}.jpg"
            inp = preprocess_android_exact(img_path, arch)
            emb = sess.run(["image_embeds"], {"pixel_values": inp})[0][0]
            emb = emb / np.linalg.norm(emb)
            sims = canon @ emb
            top5_idx = np.argsort(sims)[::-1][:5]
            d_ids = [concepts[i]["id"] for i in top5_idx]
            d_names = [concepts[i]["name"] for i in top5_idx]
            a_ids = p["top5Ids"]
            if a_ids[0] == d_ids[0]:
                top1_exact += 1
            top3_ov += len(set(a_ids[:3]).intersection(set(d_ids[:3]))) / 3.0
            top5_ov += len(set(a_ids[:5]).intersection(set(d_ids[:5]))) / 5.0
            p["exactDesktopTop5Names"] = d_names
            p["exactDesktopTop1Match"] = (a_ids[0] == d_ids[0])
            p["exactDesktopTop3Overlap"] = len(set(a_ids[:3]).intersection(set(d_ids[:3])))
            p["exactDesktopTop5Overlap"] = len(set(a_ids[:5]).intersection(set(d_ids[:5])))
        n = len(preds)
        lines.append(f"=== {mk} EXACT ARTIFACT FIDELITY ({n} images) ===")
        lines.append(f"Top-1 Agreement vs Desktop ONNX INT8: {top1_exact}/{n} = {top1_exact*100.0/n:.2f}%")
        lines.append(f"Top-3 Overlap vs Desktop ONNX INT8:   {top3_ov*100.0/n:.2f}%")
        lines.append(f"Top-5 Overlap vs Desktop ONNX INT8:   {top5_ov*100.0/n:.2f}%")
        lines.append(f"(Vs pre-MatMul-only ConvInteger desktop ref: Top-1={m['predictionFidelity']['top1AgreementPct']}%, Top-3={m['predictionFidelity']['top3OverlapPct']}%, Top-5={m['predictionFidelity']['top5OverlapPct']}%)")
        lines.append("")

    sig_preds = {p["imageId"]: p for p in res["models"]["siglip_b16_int8"]["suitePredictions"]}
    tiny_preds = {p["imageId"]: p for p in res["models"]["tinyclip_40m_int8"]["suitePredictions"]}

    for p in res["models"]["siglip_b16_int8"]["suitePredictions"]:
        iid = p["imageId"]
        tp = tiny_preds[iid]
        lines.append(f"[{p['testGroup']}] {iid} | Label: {p['displayLabel']} | GT: {p['groundTruthName']}")
        lines.append(f"  SigLIP   Android: Top1={p['top5Names'][0]} ({p['maxFoodSim']:.4f}) | Top3={p['top5Names'][:3]} | Top5={p['top5Names']} | Acc={p['foodAccepted']} (negM={p['negMargin']:.4f}) | ExactDesktopMatch={p['exactDesktopTop1Match']} ({p['exactDesktopTop5Overlap']}/5)")
        lines.append(f"  TinyCLIP Android: Top1={tp['top5Names'][0]} ({tp['maxFoodSim']:.4f}) | Top3={tp['top5Names'][:3]} | Top5={tp['top5Names']} | Acc={tp['foodAccepted']} (negM={tp['negMargin']:.4f}) | ExactDesktopMatch={tp['exactDesktopTop1Match']} ({tp['exactDesktopTop5Overlap']}/5)")

    INSPECT_TXT.write_text("\n".join(lines), encoding="utf-8")
    print("Wrote inspect_out.txt")

if __name__ == "__main__":
    main()
