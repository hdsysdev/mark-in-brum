#!/usr/bin/env python3
"""Projection regression tests for the OSM blockout pipeline.

Run: python3 tests/unit/test_osm_projection.py
"""
from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.osm import projection  # noqa: E402


class ProjectionTests(unittest.TestCase):
    def test_origin_maps_to_zero(self) -> None:
        x, z = projection.lat_lon_to_local(
            projection.ORIGIN_LAT, projection.ORIGIN_LON)
        self.assertAlmostEqual(x, 0.0, places=6)
        self.assertAlmostEqual(z, 0.0, places=6)

    def test_east_is_positive_x(self) -> None:
        x, _ = projection.lat_lon_to_local(
            projection.ORIGIN_LAT, projection.ORIGIN_LON + 0.001)
        self.assertGreater(x, 0.0)

    def test_south_is_positive_z(self) -> None:
        _, z = projection.lat_lon_to_local(
            projection.ORIGIN_LAT - 0.001, projection.ORIGIN_LON)
        self.assertGreater(z, 0.0)

    def test_known_landmark_offsets(self) -> None:
        # Bullring/St Martin's is ~450 m east-south-east of New Street.
        x, z = projection.lat_lon_to_local(52.4770, -1.8935)
        self.assertGreater(x, 300.0)
        self.assertLess(x, 600.0)
        self.assertGreater(z, 0.0)
        self.assertLess(z, 300.0)
        # Victoria Square/Town Hall is ~250 m west-north-west.
        x2, z2 = projection.lat_lon_to_local(52.4795, -1.9030)
        self.assertLess(x2, -150.0)
        self.assertGreater(x2, -350.0)
        self.assertLess(z2, -100.0)
        self.assertGreater(z2, -400.0)

    def test_compression_factor_applies(self) -> None:
        x, z = projection.lat_lon_to_local_compressed(52.4770, -1.8935)
        x_raw, z_raw = projection.lat_lon_to_local(52.4770, -1.8935)
        self.assertAlmostEqual(x / x_raw, projection.DISTANCE_COMPRESSION, places=6)
        self.assertAlmostEqual(z / z_raw, projection.DISTANCE_COMPRESSION, places=6)

    def test_round_trip_within_extent(self) -> None:
        lat, lon = 52.4740, -1.8930
        x, z = projection.lat_lon_to_local(lat, lon)
        lat2, lon2 = projection.local_to_lat_lon(x, z)
        self.assertLess(abs(lat - lat2), 1e-8)
        self.assertLess(abs(lon - lon2), 1e-8)


if __name__ == "__main__":
    unittest.main()
