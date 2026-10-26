import os
import json
import csv
import time
import numpy as np
import tensorflow as tf

def main():
    print("=== Step 1: Label Verification ===")
    with open("ml/labels.txt", "r", encoding="utf-8") as f:
        ml_labels = [line.strip() for line in f if line.strip()]
    with open("assets/ml/fitfuel_food_labels.txt", "r", encoding="utf-8") as f:
        asset_labels = [line.strip() for line in f if line.strip()]

    print(f"ml/labels.txt count: {len(ml_labels)}")
    print(f"assets/ml/fitfuel_food_labels.txt count: {len(asset_labels)}")
    labels_identical = (ml_labels == asset_labels)
    print(f"Labels exactly identical: {labels_identical}")
    if not labels_identical:
        for i, (l1, l2) in enumerate(zip(ml_labels, asset_labels)):
            if l1 != l2:
                print(f"Mismatch at index {i}: ml='{l1}' vs asset='{l2}'")
                break

    label_to_index = {l: i for i, l in enumerate(ml_labels)}

    print("\n=== Step 2: Model Inspection ===")
    tflite_path = "assets/ml/fitfuel_food_classifier.tflite"
    keras_path = "ml/checkpoints/mobilenet_v3_exp2.keras"

    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("TFLite Input details:", input_details)
    print("TFLite Output details:", output_details)

    keras_model = tf.keras.models.load_model(keras_path)
    print("Keras Model summary:")
    keras_model.summary(line_length=100)

    print("\n=== Step 3: Test Split Evaluation ===")
    manifest_path = "ml/dataset_manifest.csv"
    test_rows = []
    with open(manifest_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            if r.get("split") == "test":
                fid = r.get("food_id")
                if fid in label_to_index:
                    r["label_idx"] = label_to_index[fid]
                    test_rows.append(r)

    print(f"Found {len(test_rows)} test samples.")

    # Load and evaluate all test images on both Keras and TFLite
    keras_correct_top1 = 0
    keras_correct_top3 = 0
    tflite_correct_top1 = 0
    tflite_correct_top3 = 0
    disagreements = 0
    max_prob_diff = 0.0

    tflite_confs = []
    keras_confs = []

    for idx, r in enumerate(test_rows):
        img_p = r["image_path"]
        if not os.path.isabs(img_p):
            img_p = os.path.join("ml", img_p)

        target_idx = r["label_idx"]

        img = tf.keras.utils.load_img(img_p, target_size=(224, 224))
        arr = tf.keras.utils.img_to_array(img)
        input_data = np.expand_dims(arr, axis=0).astype(np.float32)

        # Keras prediction (disable training)
        keras_preds = keras_model(input_data, training=False).numpy()[0]
        # TFLite prediction
        interpreter.set_tensor(input_details[0]["index"], input_data)
        interpreter.invoke()
        tflite_preds = interpreter.get_tensor(output_details[0]["index"])[0]

        prob_diff = np.max(np.abs(keras_preds - tflite_preds))
        if prob_diff > max_prob_diff:
            max_prob_diff = prob_diff

        k_top1 = int(np.argmax(keras_preds))
        k_top3 = list(np.argsort(keras_preds)[-3:][::-1])

        t_top1 = int(np.argmax(tflite_preds))
        t_top3 = list(np.argsort(tflite_preds)[-3:][::-1])

        if k_top1 != t_top1:
            disagreements += 1

        if k_top1 == target_idx:
            keras_correct_top1 += 1
        if target_idx in k_top3:
            keras_correct_top3 += 1

        if t_top1 == target_idx:
            tflite_correct_top1 += 1
        if target_idx in t_top3:
            tflite_correct_top3 += 1

        tflite_confs.append(float(tflite_preds[t_top1]))
        keras_confs.append(float(keras_preds[k_top1]))

    n = len(test_rows)
    print("\n=== Canonical Metric Results ===")
    print(f"Total Test Samples: {n}")
    print(f"Keras Top-1: {keras_correct_top1}/{n} ({keras_correct_top1/n*100:.2f}%)")
    print(f"Keras Top-3: {keras_correct_top3}/{n} ({keras_correct_top3/n*100:.2f}%)")
    print(f"TFLite Top-1: {tflite_correct_top1}/{n} ({tflite_correct_top1/n*100:.2f}%)")
    print(f"TFLite Top-3: {tflite_correct_top3}/{n} ({tflite_correct_top3/n*100:.2f}%)")
    print(f"Disagreements between Keras and TFLite: {disagreements}/{n}")
    print(f"Max absolute probability difference: {max_prob_diff:.6f}")
    print(f"Mean TFLite confidence: {np.mean(tflite_confs):.4f}")
    print(f"Mean Keras confidence: {np.mean(keras_confs):.4f}")

if __name__ == "__main__":
    main()
