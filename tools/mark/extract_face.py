#!/usr/bin/env python3
"""Extract Mark's face from the user-supplied photo into a transparent,
normalized face texture source.

Stage 1 of the photo-to-character pipeline:
  detect face -> expand box -> hair/skin-aware soft mask -> normalize crop
The output feeds the Blender UV projection step (build_mark_texture.py is
the driver; this module holds the reusable pieces).

Usage:
  python3 tools/mark/extract_face.py <input.jpg> <output.png>
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np

# OpenCV haarcascade: prefer cv2.data, fall back to the bundled copy
# (tools/mark/haarcascade_frontalface_default.xml, from the OpenCV repo,
# BSD-3-Clause).
try:
    FACE_CASCADE = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
except AttributeError:
    FACE_CASCADE = str(Path(__file__).resolve().parent / "haarcascade_frontalface_default.xml")
BOX_EXPAND_TOP: float = 1.55   # include hair/forehead
BOX_EXPAND_SIDES: float = 1.30
BOX_EXPAND_BOTTOM: float = 1.25
OUTPUT_SIZE: int = 1024


def detect_face(image: np.ndarray):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    for cascade_name, params in [
        (FACE_CASCADE, dict(scaleFactor=1.05, minNeighbors=4, minSize=(60, 60))),
        (FACE_CASCADE, dict(scaleFactor=1.1, minNeighbors=6, minSize=(120, 120))),
    ]:
        cascade = cv2.CascadeClassifier(cascade_name)
        faces = cascade.detectMultiScale(gray, **params)
        if len(faces) > 0:
            return max(faces, key=lambda rect: rect[2] * rect[3])
    return None


def expand_box(x, y, w, h, img_w, img_h) -> tuple[int, int, int, int]:
    cx, cy = x + w / 2.0, y + h / 2.0
    half_w = w * BOX_EXPAND_SIDES / 2.0
    top = y - h * (BOX_EXPAND_TOP - 1.0)
    bottom = y + h * BOX_EXPAND_BOTTOM
    left = cx - half_w
    right = cx + half_w
    left = max(0, int(left))
    top = max(0, int(top))
    right = min(img_w, int(right))
    bottom = min(img_h, int(bottom))
    return left, top, right, bottom


def soft_face_mask(crop: np.ndarray) -> np.ndarray:
    """Elliptical mask centred on the detected face, feathered at edges."""
    h, w = crop.shape[:2]
    mask = np.zeros((h, w), dtype=np.float32)
    center = (int(w / 2.0), int(h * 0.46))
    axes = (int(w * 0.48), int(h * 0.46))
    cv2.ellipse(mask, center, axes, 0, 0, 360, 1.0, -1)
    mask = cv2.GaussianBlur(mask, (0, 0), sigmaX=w * 0.02)
    return mask


def extract(input_path: Path, output_path: Path) -> dict:
    image = cv2.imread(str(input_path))
    if image is None:
        raise SystemExit(f"cannot read {input_path}")
    face = detect_face(image)
    if face is None:
        raise SystemExit("no face detected")
    x, y, w, h = face
    left, top, right, bottom = expand_box(x, y, w, h, image.shape[1], image.shape[0])
    crop = image[top:bottom, left:right]
    mask = soft_face_mask(crop)
    resized = cv2.resize(crop, (OUTPUT_SIZE, OUTPUT_SIZE), interpolation=cv2.INTER_LANCZOS4)
    mask_resized = cv2.resize(mask, (OUTPUT_SIZE, OUTPUT_SIZE), interpolation=cv2.INTER_LINEAR)
    rgba = cv2.cvtColor(resized, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = (mask_resized * 255).astype(np.uint8)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_path), rgba)
    skin_mean = resized[int(OUTPUT_SIZE * 0.55):int(OUTPUT_SIZE * 0.75),
                        int(OUTPUT_SIZE * 0.35):int(OUTPUT_SIZE * 0.65)]
    skin_bgr = [float(v) for v in skin_mean.reshape(-1, 3).mean(axis=0)]
    return {
        "face_box": [int(x), int(y), int(w), int(h)],
        "crop_box": [left, top, right, bottom],
        "output": str(output_path),
        "skin_mean_bgr": [round(v, 1) for v in skin_bgr],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    info = extract(args.input, args.output)
    print(info)
    return 0


if __name__ == "__main__":
    sys.exit(main())
