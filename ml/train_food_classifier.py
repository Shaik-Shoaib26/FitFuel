#!/usr/bin/env python3
"""
FitFuel Phase 35.9.2 - Transfer Learning Training Script
Supports MobileNetV3Large and EfficientNetB0 backbones.
Includes label smoothing (0.1), safe augmentations, class balancing,
and two-phase fine-tuning.
"""

import argparse
import csv
import json
import os
import sys
import numpy as np
import tensorflow as tf


def parse_args():
    parser = argparse.ArgumentParser(description="Train FitFuel Food Vision Classifier")
    parser.add_argument("--manifest", type=str, default="dataset_manifest.csv", help="Path to dataset_manifest.csv")
    parser.add_argument("--labels", type=str, default="labels.txt", help="Path to labels.txt")
    parser.add_argument("--backbone", type=str, default="MobileNetV3Large", choices=["MobileNetV3Large", "EfficientNetB0"])
    parser.add_argument("--img_size", type=int, default=224, help="Input image dimension (224)")
    parser.add_argument("--batch_size", type=int, default=16)
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--output_dir", type=str, default="checkpoints")
    parser.add_argument("--model_name", type=str, default="best_model.keras")
    parser.add_argument("--history_output", type=str, default=None)
    return parser.parse_args()


def load_labels(labels_file):
    with open(labels_file, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    label_to_index = {label: i for i, label in enumerate(labels)}
    return labels, label_to_index


def load_dataset_manifest(manifest_path, label_to_index):
    if not os.path.exists(manifest_path):
        raise ValueError(f"Manifest '{manifest_path}' does not exist.")

    rows = []
    with open(manifest_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            food_id = row.get("food_id", "")
            if food_id in label_to_index:
                row["label_idx"] = label_to_index[food_id]
                rows.append(row)

    if not rows:
        raise ValueError("No valid rows in manifest matching labels in labels.txt.")

    return rows


def create_tf_dataset(rows, base_dir, img_size, batch_size, num_classes, is_training=True):
    paths = []
    labels = []
    for r in rows:
        p = r["image_path"]
        if not os.path.isabs(p):
            p = os.path.join(base_dir, p)
        if os.path.exists(p):
            paths.append(p)
            labels.append(r["label_idx"])

    if not paths:
        raise ValueError("No valid image files found on disk matching manifest paths.")

    def _parse_fn(path, label):
        raw = tf.io.read_file(path)
        img = tf.io.decode_jpeg(raw, channels=3)
        img = tf.image.resize(img, [img_size, img_size])
        img = tf.cast(img, tf.float32)
        one_hot = tf.one_hot(label, num_classes)
        return img, one_hot

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if is_training:
        ds = ds.shuffle(buffer_size=len(paths), seed=42)
    ds = ds.map(_parse_fn, num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.batch(batch_size)
    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds, len(paths), labels


def compute_balanced_class_weights(labels_list):
    y = np.array(labels_list, dtype=np.int32)
    classes, counts = np.unique(y, return_counts=True)
    total_samples = len(y)
    n_classes = len(classes)
    weights = total_samples / (n_classes * counts.astype(np.float32))
    return {int(cls): float(w) for cls, w in zip(classes, weights)}


def build_model(num_classes, img_size=224, backbone_name="MobileNetV3Large"):
    inputs = tf.keras.Input(shape=(img_size, img_size, 3), name="image_input")

    # Safe data augmentations: horizontal flip, mild rotation, zoom, brightness, contrast
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.06)(x)
    x = tf.keras.layers.RandomZoom(0.08)(x)
    x = tf.keras.layers.RandomBrightness(0.08)(x)
    x = tf.keras.layers.RandomContrast(0.08)(x)

    if backbone_name == "MobileNetV3Large":
        x = tf.keras.applications.mobilenet_v3.preprocess_input(x)
        base_model = tf.keras.applications.MobileNetV3Large(
            input_shape=(img_size, img_size, 3),
            include_top=False,
            weights="imagenet"
        )
    else:
        x = tf.keras.applications.efficientnet.preprocess_input(x)
        base_model = tf.keras.applications.EfficientNetB0(
            input_shape=(img_size, img_size, 3),
            include_top=False,
            weights="imagenet"
        )

    base_model.trainable = False
    x = base_model(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(256, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax", name="food_probabilities")(x)

    model = tf.keras.Model(inputs, outputs, name=f"fitfuel_{backbone_name.lower()}")
    return model, base_model


def main():
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)
    base_dir = os.path.dirname(os.path.abspath(args.manifest))

    labels, label_to_index = load_labels(args.labels)
    num_classes = len(labels)
    print(f"Loaded {num_classes} classes from {args.labels}", flush=True)

    rows = load_dataset_manifest(args.manifest, label_to_index)
    distinct_classes = len(set(r["food_id"] for r in rows))
    print(f"Loaded manifest with {len(rows)} labeled images across {distinct_classes} classes.", flush=True)

    train_rows = [r for r in rows if r.get("split") == "train"]
    val_rows = [r for r in rows if r.get("split") == "validation"]

    if not train_rows or not val_rows:
        print("Error: Manifest must contain at least 'train' and 'validation' splits.", flush=True)
        sys.exit(1)

    train_ds, n_train, train_labels = create_tf_dataset(train_rows, base_dir, args.img_size, args.batch_size, num_classes, is_training=True)
    val_ds, n_val, _ = create_tf_dataset(val_rows, base_dir, args.img_size, args.batch_size, num_classes, is_training=False)
    print(f"Training samples: {n_train}, Validation samples: {n_val}", flush=True)

    class_weight_dict = compute_balanced_class_weights(train_labels)

    model, base_model = build_model(num_classes, args.img_size, args.backbone)

    loss_fn = tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.1)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr),
        loss=loss_fn,
        metrics=[
            "accuracy",
            tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")
        ]
    )

    checkpoint_path = os.path.join(args.output_dir, args.model_name)
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(checkpoint_path, save_best_only=True, monitor="val_accuracy", mode="max"),
        tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True, monitor="val_loss"),
        tf.keras.callbacks.ReduceLROnPlateau(patience=3, factor=0.5, monitor="val_loss")
    ]

    print(f"\nPhase 1: Training {args.backbone} classification head (frozen backbone)...", flush=True)
    history_phase1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=callbacks,
        class_weight=class_weight_dict,
        verbose=1
    )

    print(f"\nPhase 2: Fine-tuning top {args.backbone} backbone layers...", flush=True)
    base_model.trainable = True
    fine_tune_layers = 30 if args.backbone == "MobileNetV3Large" else 20
    for layer in base_model.layers[:-fine_tune_layers]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr * 0.1),
        loss=loss_fn,
        metrics=[
            "accuracy",
            tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")
        ]
    )

    fine_tune_epochs = max(5, args.epochs // 2)
    history_phase2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=fine_tune_epochs,
        callbacks=callbacks,
        class_weight=class_weight_dict,
        verbose=1
    )

    if not os.path.exists(checkpoint_path):
        model.save(checkpoint_path)

    # Evaluate best model on validation
    best_model = tf.keras.models.load_model(checkpoint_path)
    val_loss, val_acc, val_top3 = best_model.evaluate(val_ds, verbose=0)
    print(f"\n[{args.backbone}] Best Val Loss: {val_loss:.4f} | Val Accuracy: {val_acc*100:.2f}% | Val Top-3: {val_top3*100:.2f}%", flush=True)
    print(f"Model saved to: {checkpoint_path}", flush=True)

    if args.history_output:
        history_data = {
            "backbone": args.backbone,
            "val_loss": round(float(val_loss), 4),
            "val_accuracy": round(float(val_acc) * 100, 2),
            "val_top3": round(float(val_top3) * 100, 2),
            "epochs_phase1": len(history_phase1.history["loss"]),
            "epochs_phase2": len(history_phase2.history["loss"]),
        }
        with open(args.history_output, "w", encoding="utf-8") as f:
            json.dump(history_data, f, indent=2)


if __name__ == "__main__":
    main()
