#!/usr/bin/env python3
"""
FitFuel Phase 35.9.5 - Model Retraining V5
Retrains MobileNetV3Large on the cleaned & supplemented fitfuel_food_dataset_v5:
- 2,715 train samples across 50 classes
- 457 validation samples across 50 classes
Evaluates validation metrics, exports the best model to Float16 TFLite,
and logs canonical metrics.
"""

import os
import sys
import csv
import json
import time
import numpy as np
import tensorflow as tf

def load_labels(labels_file="assets/ml/fitfuel_food_labels.txt"):
    with open(labels_file, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    return labels, {label: i for i, label in enumerate(labels)}

def load_manifest(manifest_path, label_to_index):
    rows = []
    with open(manifest_path, "r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            fid = r.get("food_id")
            if fid in label_to_index:
                r["label_idx"] = label_to_index[fid]
                rows.append(r)
    return rows

def create_dataset(rows, base_dir, img_size=224, batch_size=16, num_classes=50, is_training=True):
    paths = []
    labels = []
    for r in rows:
        p = r["image_path"]
        if not os.path.isabs(p):
            p = os.path.join(base_dir, p)
        if os.path.exists(p):
            paths.append(p)
            labels.append(r["label_idx"])

    def _parse(path, label):
        raw = tf.io.read_file(path)
        img = tf.io.decode_jpeg(raw, channels=3)
        img = tf.image.resize(img, [img_size, img_size])
        img = tf.cast(img, tf.float32) # [0, 255] float32
        one_hot = tf.one_hot(label, num_classes)
        return img, one_hot

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if is_training:
        ds = ds.shuffle(buffer_size=min(len(paths), 1500), seed=42)
    ds = ds.map(_parse, num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.batch(batch_size)
    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds, len(paths), labels

def compute_class_weights(labels_list):
    y = np.array(labels_list, dtype=np.int32)
    classes, counts = np.unique(y, return_counts=True)
    total = len(y)
    n_classes = len(classes)
    weights = total / (n_classes * counts.astype(np.float32))
    return {int(c): float(w) for c, w in zip(classes, weights)}

def build_model(num_classes=50, img_size=224, dropout_rate=0.25):
    inputs = tf.keras.Input(shape=(img_size, img_size, 3), name="image_input")

    # Safe data augmentations: horizontal flip, mild rotation, mild zoom, mild brightness
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.04)(x)
    x = tf.keras.layers.RandomZoom(0.05)(x)
    x = tf.keras.layers.RandomBrightness(0.05)(x)

    # MobileNetV3Large backbone (has built-in Rescaling layer)
    x = tf.keras.applications.mobilenet_v3.preprocess_input(x)
    base = tf.keras.applications.MobileNetV3Large(
        input_shape=(img_size, img_size, 3),
        include_top=False,
        weights="imagenet"
    )

    base.trainable = False
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout_rate)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax", name="food_probabilities")(x)

    model = tf.keras.Model(inputs, outputs, name="fitfuel_food_v5")
    return model, base

def export_float16_tflite(keras_model, output_tflite_path):
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(output_tflite_path), exist_ok=True)
    with open(output_tflite_path, "wb") as f:
        f.write(tflite_model)
    size_mb = len(tflite_model) / (1024 * 1024)
    print(f"Exported Float16 TFLite model to {output_tflite_path} ({size_mb:.2f} MB)")
    return size_mb

def main():
    print("============================================================", flush=True)
    print("  FITFUEL 35.9.5: CORRECTIVE RETRAINING (MOBILENETV3LARGE)  ", flush=True)
    print("============================================================", flush=True)

    manifest_path = "ml/dataset_manifest_v5.csv"
    labels_path = "assets/ml/fitfuel_food_labels.txt"
    labels, label_to_idx = load_labels(labels_path)
    num_classes = len(labels)

    rows = load_manifest(manifest_path, label_to_idx)
    train_rows = [r for r in rows if r.get("split") == "train"]
    val_rows = [r for r in rows if r.get("split") == "validation"]

    print(f"Loaded {len(train_rows)} train and {len(val_rows)} validation samples across {num_classes} classes.")

    base_dir = "ml"
    train_ds, n_train, train_labels = create_dataset(train_rows, base_dir, img_size=224, batch_size=16, num_classes=num_classes, is_training=True)
    val_ds, n_val, val_labels = create_dataset(val_rows, base_dir, img_size=224, batch_size=16, num_classes=num_classes, is_training=False)

    class_weights = compute_class_weights(train_labels)

    model, base_model = build_model(num_classes=num_classes, img_size=224, dropout_rate=0.25)
    loss_fn = tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.03)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss=loss_fn,
        metrics=["accuracy", tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")]
    )

    checkpoint_dir = "ml/checkpoints"
    os.makedirs(checkpoint_dir, exist_ok=True)
    best_checkpoint = os.path.join(checkpoint_dir, "fitfuel_food_v5.keras")

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            best_checkpoint,
            monitor="val_top_3_accuracy",
            mode="max",
            save_best_only=True,
            verbose=1
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_top_3_accuracy",
            mode="max",
            patience=5,
            restore_best_weights=True,
            verbose=1
        )
    ]

    print("\n--- Phase 1: Classification Head Training (8 epochs) ---", flush=True)
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=8,
        callbacks=callbacks,
        class_weight=class_weights,
        verbose=1
    )

    print("\n--- Phase 2: Backbone Fine-Tuning (top 60 layers, 8 epochs) ---", flush=True)
    base_model.trainable = True
    fine_tune_layers = 60
    for layer in base_model.layers[:-fine_tune_layers]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=4e-5),
        loss=loss_fn,
        metrics=["accuracy", tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")]
    )

    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=8,
        callbacks=callbacks,
        class_weight=class_weights,
        verbose=1
    )

    # Evaluate best saved checkpoint on validation data
    best_model = tf.keras.models.load_model(best_checkpoint)
    val_loss, val_acc, val_top3 = best_model.evaluate(val_ds, verbose=0)
    print(f"\n============================================================")
    print(f"Validation Results for fitfuel_food_v5:")
    print(f"  Val Top-1 Accuracy: {val_acc*100:.2f}%")
    print(f"  Val Top-3 Accuracy: {val_top3*100:.2f}%")
    print(f"============================================================\n", flush=True)

    # Export to Float16 TFLite
    deployed_tflite = "assets/ml/fitfuel_food_classifier.tflite"
    backup_tflite = "ml/checkpoints/fitfuel_food_v5.tflite"
    tflite_size_mb = export_float16_tflite(best_model, deployed_tflite)
    export_float16_tflite(best_model, backup_tflite)

    # Log training experiment
    exp_log = "ml/reports/training_experiments_v5.csv"
    with open(exp_log, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "model_version", "architecture", "dataset_version", "val_samples",
            "val_top1", "val_top3", "model_size_mb"
        ])
        writer.writeheader()
        writer.writerow({
            "model_version": "fitfuel_food_v5",
            "architecture": "MobileNetV3Large",
            "dataset_version": "fitfuel_food_dataset_v5",
            "val_samples": n_val,
            "val_top1": round(val_acc * 100, 2),
            "val_top3": round(val_top3 * 100, 2),
            "model_size_mb": round(tflite_size_mb, 2)
        })

    print("Retraining and TFLite export complete!")

if __name__ == "__main__":
    main()
