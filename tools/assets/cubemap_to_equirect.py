#!/usr/bin/env python3
"""Convert krpano f/l/b/r/u/d cubefaces into an equirectangular JPEG."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def _sample_bilinear(face: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    height, width, _ = face.shape
    x = np.clip(u, 0.0, 1.0) * (width - 1)
    y = np.clip(v, 0.0, 1.0) * (height - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, width - 1)
    y1 = np.minimum(y0 + 1, height - 1)
    wx = (x - x0)[..., None]
    wy = (y - y0)[..., None]
    top = face[y0, x0] * (1.0 - wx) + face[y0, x1] * wx
    bottom = face[y1, x0] * (1.0 - wx) + face[y1, x1] * wx
    return top * (1.0 - wy) + bottom * wy


def convert(face_dir: Path, output: Path, width: int) -> None:
    height = width // 2
    faces = {
        name: np.asarray(Image.open(face_dir / f"{name}.jpg").convert("RGB"), dtype=np.float32)
        for name in "flbrud"
    }
    output_pixels = np.empty((height, width, 3), dtype=np.uint8)
    longitude = ((np.arange(width, dtype=np.float32) + 0.5) / width) * (2.0 * np.pi) - np.pi
    sin_longitude = np.sin(longitude)[None, :]
    cos_longitude = np.cos(longitude)[None, :]

    for start in range(0, height, 256):
        stop = min(start + 256, height)
        latitude = np.pi * 0.5 - ((np.arange(start, stop, dtype=np.float32) + 0.5) / height) * np.pi
        cos_latitude = np.cos(latitude)[:, None]
        direction_x = cos_latitude * sin_longitude
        direction_y = np.broadcast_to(np.sin(latitude)[:, None], direction_x.shape)
        direction_z = cos_latitude * cos_longitude
        absolute_x = np.abs(direction_x)
        absolute_y = np.abs(direction_y)
        absolute_z = np.abs(direction_z)
        major_axis = np.maximum(np.maximum(absolute_x, absolute_y), absolute_z)
        strip = np.empty((stop - start, width, 3), dtype=np.float32)

        masks_and_coordinates = [
            ("r", (absolute_x >= absolute_y) & (absolute_x >= absolute_z) & (direction_x >= 0.0), -direction_z, -direction_y),
            ("l", (absolute_x >= absolute_y) & (absolute_x >= absolute_z) & (direction_x < 0.0), direction_z, -direction_y),
            ("u", (absolute_y > absolute_x) & (absolute_y >= absolute_z) & (direction_y >= 0.0), direction_x, direction_z),
            ("d", (absolute_y > absolute_x) & (absolute_y >= absolute_z) & (direction_y < 0.0), direction_x, -direction_z),
            ("f", (absolute_z > absolute_x) & (absolute_z > absolute_y) & (direction_z >= 0.0), direction_x, -direction_y),
            ("b", (absolute_z > absolute_x) & (absolute_z > absolute_y) & (direction_z < 0.0), -direction_x, -direction_y),
        ]
        for face_name, mask, horizontal, vertical in masks_and_coordinates:
            u = (horizontal[mask] / major_axis[mask] + 1.0) * 0.5
            v = (vertical[mask] / major_axis[mask] + 1.0) * 0.5
            strip[mask] = _sample_bilinear(faces[face_name], u, v)
        output_pixels[start:stop] = np.clip(strip, 0.0, 255.0).astype(np.uint8)

    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(output_pixels, mode="RGB").save(
        output,
        format="JPEG",
        quality=92,
        optimize=True,
        progressive=True,
        subsampling=1,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("face_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, default=4096)
    args = parser.parse_args()
    if args.width < 1024 or args.width % 2:
        raise SystemExit("--width must be an even integer of at least 1024")
    convert(args.face_dir, args.output, args.width)


if __name__ == "__main__":
    main()
