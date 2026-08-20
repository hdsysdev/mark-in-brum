#!/usr/bin/env python3
"""Local flat-earth projection for the Birmingham city-centre blockout.

Equirectangular approximation centred on New Street. Distances are
compressed ~15-25% where necessary for a fun mobile-scale loop; the raw
projection is exact at the origin and degrades negligibly over the ~1.5 km
extent (sub-metre error for gameplay purposes).

Origin: New Street / Corporation Street junction (approx).
"""

from __future__ import annotations

import math

ORIGIN_LAT: float = 52.4776
ORIGIN_LON: float = -1.8995
METERS_PER_DEG_LAT: float = 110_540.0
METERS_PER_DEG_LON: float = 111_320.0 * math.cos(math.radians(ORIGIN_LAT))

# Compress real distances by this factor so the district reads dense at a
# mobile-friendly walking scale. Kept explicit so tests can assert it.
DISTANCE_COMPRESSION: float = 0.85


def lat_lon_to_local(lat: float, lon: float) -> tuple[float, float]:
    """Return (x, z) in meters. +x = east, +z = south (Godot XZ plane)."""
    x = (lon - ORIGIN_LON) * METERS_PER_DEG_LON
    z = -(lat - ORIGIN_LAT) * METERS_PER_DEG_LAT
    return x, z


def compress(value: float) -> float:
    return value * DISTANCE_COMPRESSION


def lat_lon_to_local_compressed(lat: float, lon: float) -> tuple[float, float]:
    x, z = lat_lon_to_local(lat, lon)
    return compress(x), compress(z)


def local_to_lat_lon(x: float, z: float) -> tuple[float, float]:
    lat = ORIGIN_LAT - z / METERS_PER_DEG_LAT
    lon = ORIGIN_LON + x / METERS_PER_DEG_LON
    return lat, lon
