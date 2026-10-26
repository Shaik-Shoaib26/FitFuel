#!/usr/bin/env python3
"""
FitFuel Phase 35.9.3 - Model Training & Experiment Runner V3
Runs controlled training experiments across MobileNetV3Large and EfficientNetB0 backbones.
Tracks each experiment in ml/reports/training_experiments.csv.
Applies class weighting, label smoothing, and two-stage transfer learning fine-tuning.
"""

import argparse
import csv
import json
import os
import sys
import time
import numpy as np
import tensorflow as tf

EXPERIMENTS_CSV = "reports/training_experiments.csv"


def parse_args():
    parser = argparse.ArgumentParser(description="Train FitFuel Food Vision Classifier V3")
    parser.add_argument("--manifest", type=str, default="dataset_manifest.csv")
    parser.add_argument("--labels", type=str, default="labels.txt")
    parser.add_argument("--experiment_id", type=str, default="EXP_001")
    parser.add_argument("--backbone", type=str, default="MobileNetV3Large", choices=["MobileNetV3Large", "EfficientNetB0"])
    parser.add_argument("--img_size", type=int, default=224)
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--epochs_head", type=int, default=8)
    parser.add_argument("--epochs_fine", type=int, default=6)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--fine_tune_layers", type=int, default=35)
    parser.add_argument("--dropout", type=float, default=0.3)
    parser.add_argument("--label_smoothing", type=float, default=0.1)
    parser.add_argument("--output_dir", type=str, default="checkpoints")
    parser.add_argument("--model_name", type=str, default="best_model.keras")
    parser.add_argument("--notes", type=str, default="Standard baseline")
    return parser.parse_args()


def load_labels(labels_file):
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


def create_dataset(rows, base_dir, img_size, batch_size, num_classes, is_training=True):
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
        img = tf.cast(img, tf.float32)
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


def build_model(num_classes, img_size, backbone_name, dropout_rate):
    inputs = tf.keras.Input(shape=(img_size, img_size, 3), name="image_input")

    # Safe data augmentations: flip, rotation, zoom, brightness
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.06)(x)
    x = tf.keras.layers.RandomZoom(0.08)(x)
    x = tf.keras.layers.RandomBrightness(0.08)(x)

    if backbone_name == "MobileNetV3Large":
        x = tf.keras.applications.mobilenet_v3.preprocess_input(x)
        base = tf.keras.applications.MobileNetV3Large(
            input_shape=(img_size, img_size, 3),
            include_top=False,
            weights="imagenet"
        )
    else:
        x = tf.keras.applications.efficientnet.preprocess_input(x)
        base = tf.keras.applications.EfficientNetB0(
            input_shape=(img_size, img_size, 3),
            include_top=False,
            weights="imagenet"
        )

    base.trainable = False
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Dropout(dropout_rate)(x)
    x = tf.keras.layers.Dense(256, activation="relu")(x)
    x = tf.keras.layers.Dropout(dropout_rate * 0.7)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax", name="food_probabilities")(x)

    return tf.keras.Model(inputs, outputs, name=f"fitfuel_{backbone_name.lower()}"), base


def log_experiment(row):
    os.makedirs(os.path.dirname(EXPERIMENTS_CSV), exist_ok=True)
    file_exists = os.path.exists(EXPERIMENTS_CSV)
    fields = [
        "experiment_id", "dataset_version", "architecture", "learning_rate",
        "batch_size", "epochs", "fine_tuned_layers", "dropout",
        "label_smoothing", "augmentation_profile", "best_val_accuracy",
        "best_val_top3", "test_top1", "test_top3", "model_size", "notes"
    ]
    with open(EXPERIMENTS_CSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)


def main():
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)
    base_dir = os.path.dirname(os.path.abspath(args.manifest))

    labels, label_to_index = load_labels(args.labels)
    num_classes = len(labels)
    rows = load_manifest(args.manifest, label_to_index)

    train_rows = [r for r in rows if r.get("split") == "train"]
    val_rows = [r for r in rows if r.get("split") == "validation"]
    test_rows = [r for r in rows if r.get("split") == "test"]

    print("============================================================", flush=True)
    print(f"  FITFUEL TRAINING EXPERIMENT: {args.experiment_id} ({args.backbone})", flush=True)
    print("============================================================", flush=True)
    print(f"Train / Val / Test samples: {len(train_rows)} / {len(val_rows)} / {len(test_rows)}", flush=True)

    train_ds, n_train, train_labels = create_dataset(train_rows, base_dir, args.img_size, args.batch_size, num_classes, is_training=True)
    val_ds, n_val, _ = create_dataset(val_rows, base_dir, args.img_size, args.batch_size, num_classes, is_training=False)
    test_ds, n_test, _ = create_dataset(test_rows, base_dir, args.img_size, args.batch_size, num_classes, is_training=False)

    class_weights = compute_class_weights(train_labels)
    model, base_model = build_model(num_classes, args.img_size, args.backbone, args.dropout)

    loss_fn = tf.keras.losses.CategoricalCrossentropy(label_smoothing=args.label_smoothing)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr),
        loss=loss_fn,
        metrics=["accuracy", tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")]
    )

    checkpoint_path = os.path.join(args.output_dir, args.model_name)
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(checkpoint_path, save_best_only=True, monitor="val_accuracy", mode="max"),
        tf.keras.callbacks.EarlyStopping(patience=4, restore_best_weights=True, monitor="val_loss"),
        tf.keras.callbacks.ReduceLROnPlateau(patience=2, factor=0.5, monitor="val_loss")
    ]

    print(f"\nPhase 1: Classification Head Training ({args.epochs_head} epochs)...", flush=True)
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs_head,
        callbacks=callbacks,
        class_weight=class_weights,
        verbose=1
    )

    print(f"\nPhase 2: Backbone Fine-Tuning (top {args.fine_tune_layers} layers, {args.epochs_fine} epochs)...", flush=True)
    base_model.trainable = True
    for layer in base_model.layers[:-args.fine_tune_layers]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr * 0.1),
        loss=loss_fn,
        metrics=["accuracy", tf.keras.metrics.TopKCategoricalAccuracy(k=3, name="top_3_accuracy")]
    )

    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs_fine,
        callbacks=callbacks,
        class_weight=class_weights,
        verbose=1
    )

    # Evaluate best saved checkpoint
    best_model = tf.keras.models.load_model(checkpoint_path)
    val_loss, val_acc, val_top3 = best_model.evaluate(val_ds, verbose=0)
    test_loss, test_acc, test_top3 = best_model.evaluate(test_ds, verbose=0)
    model_size_mb = os.path.getsize(checkpoint_path) / (1024 * 1024)

    print(f"\n============================================================")
    print(f"Results for {args.experiment_id}:")
    print(f"  Best Val Accuracy:  {val_acc*100:.2f}% | Val Top-3:  {val_top3*100:.2f}%")
    print(f"  Test Top-1:         {test_acc*100:.2f}% | Test Top-3: {test_top3*100:.2f}%")
    print(f"  Model Size (.keras):{model_size_mb:.2f} MB")
    print(f"============================================================\n", flush=True)

    log_experiment({
        "experiment_id": args.experiment_id,
        "dataset_version": "fitfuel_food_dataset_v3",
        "architecture": args.backbone,
        "learning_rate": args.lr,
        "batch_size": args.batch_size,
        "epochs": args.epochs_head + args.epochs_fine,
        "fine_tuned_layers": args.fine_tune_layers,
        "dropout": args.dropout,
        "label_smoothing": args.label_smoothing,
        "augmentation_profile": "Safe-Food (flip, rot 0.06, zoom 0.08, bright 0.08)",
        "best_val_accuracy": round(float(val_acc * 100), 2),
        "best_val_top3": round(float(val_top3 * 100), 2),
        "test_top1": round(float(test_acc * 100), 2),
        "test_top3": round(float(test_top3 * 100), 2),
        "model_size": f"{model_size_mb:.2f} MB",
        "notes": args.notes
    })


if __name__ == "__main__":
    main()
