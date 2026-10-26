#!/usr/bin/env python3
"""
FitFuel TFLite Model Exporter & Quantizer
Converts a trained Keras model into an optimized TensorFlow Lite model (.tflite)
supporting float32, float16, and int8 quantization.
"""

import argparse
import os
import sys
import numpy as np
import tensorflow as tf


def parse_args():
    parser = argparse.ArgumentParser(description="Export trained model to TensorFlow Lite (.tflite)")
    parser.add_argument("--checkpoint", type=str, required=True, help="Path to trained Keras model (.keras)")
    parser.add_argument("--quantization", type=str, default="float16", choices=["float32", "float16", "int8"])
    parser.add_argument("--calibration_data", type=str, default=None, help="Directory of sample images for int8 calibration")
    parser.add_argument("--output", type=str, default="../assets/ml/fitfuel_food_classifier.tflite")
    return parser.parse_args()


def export_tflite(checkpoint_path, output_path, quantization="float16", calibration_dir=None):
    if not os.path.exists(checkpoint_path):
        print(f"[EXPORT ERROR]: Checkpoint '{checkpoint_path}' does not exist.")
        print("A model must be trained on real data before exporting a production TFLite artifact.")
        sys.exit(1)

    print(f"Loading trained model from {checkpoint_path}...")
    model = tf.keras.models.load_model(checkpoint_path)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantization == "float16":
        print("Applying float16 post-training quantization...")
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    elif quantization == "int8":
        print("Applying full integer (int8) quantization...")
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

        if not calibration_dir or not os.path.isdir(calibration_dir):
            print("Error: int8 quantization requires a representative calibration dataset directory (--calibration_data).")
            sys.exit(1)

        def representative_data_gen():
            for filename in os.listdir(calibration_dir)[:150]:
                filepath = os.path.join(calibration_dir, filename)
                img = tf.keras.utils.load_img(filepath, target_size=(224, 224))
                arr = tf.keras.utils.img_to_array(img)
                arr = np.expand_dims(arr, axis=0).astype(np.float32)
                yield [arr]

        converter.representative_dataset = representative_data_gen
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    else:
        print("Exporting unquantized float32 model...")

    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / (1024 * 1024)
    print(f"Successfully exported TFLite model to {output_path} ({size_mb:.2f} MB)")


def main():
    args = parse_args()
    export_tflite(args.checkpoint, args.output, args.quantization, args.calibration_data)


if __name__ == "__main__":
    main()
