#!/usr/bin/env python3
"""build_birmingham.py -- OSM extract -> low-poly chunked city geometry.

Headless Blender script for the "Mark in Brum" Godot 4.7 project.

Run:
    blender --background --python /home/debian/mark-in-brum/tools/blender/build_birmingham.py

Pipeline:
  1. Factory-reset the scene (idempotent).
  2. Parse the pinned OSM extract (nodes + ways; relations ignored).
  3. Project node lat/lon with tools/osm/projection.py (lat_lon_to_local_compressed).
  4. Buildings: extruded flat-shaded prisms (footprint simplified: collinear
     points < 0.3 m dropped, capped at 16 points). Roads: miter-joined ribbons.
  5. Chunk everything on an 80 m grid by way centroid (chunk-local coords).
  6. One 'geometry' mesh per chunk (material slots: asphalt/pavement/building,
     building variance via vertex colors) + one 'collision' mesh
     (building prisms incl. bottom cap; road ribbons as flat top plates).
  7. Save the working .blend, export one GLB per non-empty chunk, and write
     art_source/osm/landmarks.json.

Blender 3.4 (bmesh). No UVs/textures/lights/cameras exported.
"""

import bmesh
import bpy
import glob
import json
import math
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(os.path.dirname(HERE), "osm")  # tools/osm/projection.py
for _p in (HERE, PROJ_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)
from projection import lat_lon_to_local_compressed  # noqa: E402

# --------------------------------------------------------------------------
# Paths / constants
# --------------------------------------------------------------------------
OSM_PATH = "/home/debian/mark-in-brum/art_source/osm/birmingham_city_centre.json"
BLEND_OUT = "/home/debian/mark-in-brum/art_source/blender/birmingham_city_centre.blend"
CHUNK_DIR = "/home/debian/mark-in-brum/assets/models/world/chunks"
LANDMARKS_OUT = "/home/debian/mark-in-brum/art_source/osm/landmarks.json"

CHUNK = 80.0            # metres per chunk side
TRI_BUDGET = 120_000    # whole-district triangle budget (geometry)

ROAD_WIDTH = {
    "primary": 18.0,
    "secondary": 12.0,
    "tertiary": 9.0,
    "residential": 7.0,
    "pedestrian": 6.0,
    "footway": 3.0,
    "service": 4.0,
    "living_street": 6.0,
}
ROAD_MAT = {
    "primary": "asphalt",
    "secondary": "asphalt",
    "tertiary": "asphalt",
    "residential": "asphalt",
    "pedestrian": "pavement",
    "footway": "pavement",
    "service": "asphalt",
    "living_street": "asphalt",
}
ROAD_Y = {"asphalt": 0.02, "pavement": 0.04}

BUILD_MIN_AREA = 4.0      # m^2, drop footprints smaller than this
BUILD_ARENA_AREA = 4000.0  # m^2, arena-scale: extrude anyway, footprint capped
BUILD_MAX_POINTS = 16
BUILD_COLLINEAR_TOL = 0.3  # m
BUILD_FALLBACK_H = 8.0     # m
LEVELS_TO_M = 3.2          # building:levels -> metres
COLL_MAX_POINTS = 10
COLL_COLLINEAR_TOL = 1.0

MAT_COLORS = {
    "asphalt": (0.16, 0.16, 0.17),
    "pavement": (0.30, 0.29, 0.28),
    "building": (0.55, 0.55, 0.55),  # vertex colors add 0.45-0.65 variance
}

SKIP = {}  # reason -> count

T0 = time.time()


def log(msg):
    print("[build_birmingham]", msg, flush=True)


# --------------------------------------------------------------------------
# OSM parsing
# --------------------------------------------------------------------------
def load_osm():
    with open(OSM_PATH, "r") as f:
        data = json.load(f)
    nodes = {}
    ways = []
    for e in data["elements"]:
        if e["type"] == "node":
            nodes[e["id"]] = (e["lat"], e["lon"])
        elif e["type"] == "way":
            ways.append(e)
    return nodes, ways


def project(nodes, nid):
    lat, lon = nodes[nid]
    return lat_lon_to_local_compressed(lat, lon)


# --------------------------------------------------------------------------
# Geometry helpers (all in the XZ plane, y = height axis)
# --------------------------------------------------------------------------
def poly_area(pts):
    """Signed shoelace area of an open ring of (x, z). CCW (from +y) => +."""
    a = 0.0
    n = len(pts)
    for i in range(n):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % n]
        a += x1 * z2 - x2 * z1
    return 0.5 * a


def poly_centroid(pts):
    """Shoelace centroid of an open ring of (x, z)."""
    n = len(pts)
    if n == 0:
        return 0.0, 0.0
    a2 = 0.0
    cx = cz = 0.0
    for i in range(n):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % n]
        cross = x1 * z2 - x2 * z1
        a2 += cross
        cx += (x1 + x2) * cross
        cz += (z1 + z2) * cross
    if abs(a2) < 1e-12:
        sx = sum(p[0] for p in pts) / n
        sz = sum(p[1] for p in pts) / n
        return sx, sz
    return cx / (3.0 * a2), cz / (3.0 * a2)


def dedupe_points(pts):
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > 1e-9 or abs(p[1] - out[-1][1]) > 1e-9):
            out.append(p)
    if len(out) > 1:
        # ring closure duplicate
        if abs(out[0][0] - out[-1][0]) < 1e-9 and abs(out[0][1] - out[-1][1]) < 1e-9:
            out.pop()
    return out


def drop_collinear(pts, tol):
    """Drop ring points within `tol` of the line through their neighbours."""
    if len(pts) < 4:
        return pts
    pts = list(pts)
    for _ in range(6):
        n = len(pts)
        if n < 4:
            break
        keep = [True] * n
        changed = False
        for i in range(n):
            ax, az = pts[(i - 1) % n]
            bx, bz = pts[i]
            cx, cz = pts[(i + 1) % n]
            dx, dz = cx - ax, cz - az
            length = math.hypot(dx, dz)
            if length < 1e-9:
                continue
            # perpendicular distance of b to line a-c
            dist = abs(dx * (bz - az) - dz * (bx - ax)) / length
            if dist < tol:
                keep[i] = False
                changed = True
        if not changed:
            break
        pts = [p for p, k in zip(pts, keep) if k]
        if len(pts) < 3:
            pts = pts[:3] if len(pts) == 2 else pts
    return pts


def cap_points(pts, maxn):
    if len(pts) <= maxn:
        return pts
    step = math.ceil(len(pts) / maxn)
    return [pts[i] for i in range(0, len(pts), step)][:maxn]


def simplify_ring(pts, tol, maxn):
    pts = dedupe_points(pts)
    pts = drop_collinear(pts, tol)
    pts = cap_points(pts, maxn)
    return pts


def decimate_road(pts, angle_deg):
    """Drop way points where the turn angle is below angle_deg (straight runs)."""
    if len(pts) < 3:
        return pts
    cos_thr = math.cos(math.radians(angle_deg))
    keep = [True] * len(pts)
    for i in range(1, len(pts) - 1):
        x1, z1 = pts[i - 1]
        x2, z2 = pts[i]
        x3, z3 = pts[i + 1]
        vx1, vz1 = x2 - x1, z2 - z1
        vx2, vz2 = x3 - x2, z3 - z2
        l1 = math.hypot(vx1, vz1)
        l2 = math.hypot(vx2, vz2)
        if l1 < 1e-9 or l2 < 1e-9:
            keep[i] = False
            continue
        dot = (vx1 * vx2 + vz1 * vz2) / (l1 * l2)
        if dot > cos_thr:  # nearly straight
            keep[i] = False
    return [p for p, k in zip(pts, keep) if k]


def build_height(tags):
    h = tags.get("height")
    if h is not None:
        try:
            return max(float(str(h).replace("m", "").replace("M", "").strip()), 0.5)
        except (TypeError, ValueError):
            pass
    lv = tags.get("building:levels")
    if lv is not None:
        try:
            return max(float(str(lv).split(";")[0].split("-")[0]), 0.5) * LEVELS_TO_M
        except (TypeError, ValueError):
            pass
    return BUILD_FALLBACK_H


def miter_offsets(pts, half_width, closed):
    """Per-point left/right offset positions with clamped miter joins."""
    n = len(pts)
    L = [None] * n
    R = [None] * n

    def perp(dx, dz):
        return (-dz, dx)

    for i in range(n):
        prev = pts[(i - 1) % n] if (closed or i > 0) else None
        nxt = pts[(i + 1) % n] if (closed or i < n - 1) else None
        cur = pts[i]
        if prev is None:
            d = (nxt[0] - cur[0], nxt[1] - cur[1])
            norm = perp(*d)
        elif nxt is None:
            d = (cur[0] - prev[0], cur[1] - prev[1])
            norm = perp(*d)
        else:
            d1 = (cur[0] - prev[0], cur[1] - prev[1])
            d2 = (nxt[0] - cur[0], nxt[1] - cur[1])
            l1 = math.hypot(*d1)
            l2 = math.hypot(*d2)
            if l1 < 1e-9 or l2 < 1e-9:
                norm = None
            else:
                p1 = perp(d1[0] / l1, d1[1] / l1)
                p2 = perp(d2[0] / l2, d2[1] / l2)
                sx, sz = p1[0] + p2[0], p1[1] + p2[1]
                sl = math.hypot(sx, sz)
                norm = (sx / sl, sz / sl) if sl > 1e-9 else p1
        if norm is None:
            L[i] = cur
            R[i] = cur
            continue
        # clamp the miter so sharp corners don't spike
        if prev is not None and nxt is not None:
            d1 = (cur[0] - prev[0], cur[1] - prev[1])
            l1 = math.hypot(*d1)
            if l1 > 1e-9:
                p1 = perp(d1[0] / l1, d1[1] / l1)
                cos_join = max(0.25, min(1.0, norm[0] * p1[0] + norm[1] * p1[1]))
            else:
                cos_join = 1.0
        else:
            cos_join = 1.0
        off = half_width / cos_join
        L[i] = (cur[0] + norm[0] * off, cur[1] + norm[1] * off)
        R[i] = (cur[0] - norm[0] * off, cur[1] - norm[1] * off)
    return L, R


# --------------------------------------------------------------------------
# Classification
# --------------------------------------------------------------------------
def classify(ways, nodes):
    roads = []    # dicts: pts, kind, mat, closed, way
    buildings = []  # dicts: ring (CCW), height, way
    for w in ways:
        tags = w.get("tags") or {}
        hw = tags.get("highway")
        bval = tags.get("building")
        is_building = bval is not None and bval not in ("no",)
        if is_building:
            ring = []
            bad = False
            for nid in w["nodes"]:
                if nid not in nodes:
                    bad = True
                    break
                ring.append(project(nodes, nid))
            if bad or len(ring) < 3:
                SKIP["building_missing_or_bad_nodes"] = SKIP.get("building_missing_or_bad_nodes", 0) + 1
                continue
            ring = dedupe_points(ring)
            if len(ring) < 3:
                SKIP["building_under_3_points"] = SKIP.get("building_under_3_points", 0) + 1
                continue
            area = abs(poly_area(ring))
            if area < BUILD_MIN_AREA:
                SKIP["building_area_lt_4m2"] = SKIP.get("building_area_lt_4m2", 0) + 1
                continue
            if area > BUILD_ARENA_AREA:
                SKIP["building_arena_scale_extruded"] = SKIP.get("building_arena_scale_extruded", 0) + 1
            if poly_area(ring) < 0:  # normalise to CCW viewed from +y
                ring = list(reversed(ring))
            buildings.append({
                "ring": ring,
                "area": area,
                "height": build_height(tags),
                "way": w,
            })
        elif hw in ROAD_WIDTH:
            pts = []
            bad = False
            for nid in w["nodes"]:
                if nid not in nodes:
                    bad = True
                    break
                pts.append(project(nodes, nid))
            if bad:
                SKIP["road_missing_nodes"] = SKIP.get("road_missing_nodes", 0) + 1
                continue
            pts = dedupe_points(pts)
            closed = bool(w["nodes"]) and w["nodes"][0] == w["nodes"][-1]
            if closed and len(pts) > 1 and pts[0] == pts[-1]:
                pts.pop()
            if len(pts) < 2:
                SKIP["road_under_2_points"] = SKIP.get("road_under_2_points", 0) + 1
                continue
            roads.append({
                "pts": pts,
                "kind": hw,
                "mat": ROAD_MAT[hw],
                "closed": closed and len(pts) >= 3,
                "way": w,
            })
        else:
            if hw:
                SKIP["road_unknown_highway_type"] = SKIP.get("road_unknown_highway_type", 0) + 1
            elif "barrier" in tags:
                SKIP["barrier_no_geometry_rule"] = SKIP.get("barrier_no_geometry_rule", 0) + 1
            elif "amenity" in tags:
                SKIP["amenity_only_no_geometry_rule"] = SKIP.get("amenity_only_no_geometry_rule", 0) + 1
            elif "landuse" in tags:
                SKIP["landuse_no_geometry_rule"] = SKIP.get("landuse_no_geometry_rule", 0) + 1
            elif "natural" in tags:
                SKIP["natural_no_geometry_rule"] = SKIP.get("natural_no_geometry_rule", 0) + 1
            else:
                SKIP["no_geometry_rule"] = SKIP.get("no_geometry_rule", 0) + 1
    return roads, buildings


def estimate_tris(roads, buildings):
    road_tris = 0
    for r in roads:
        segs = len(r["pts"]) if r["closed"] else len(r["pts"]) - 1
        road_tris += 2 * max(segs, 0)
    bldg_tris = 0
    for b in buildings:
        n = len(simplify_ring(b["ring"], BUILD_COLLINEAR_TOL, BUILD_MAX_POINTS))
        if n >= 3:
            bldg_tris += 3 * n  # top fan + sides (bottom face dropped)
    return road_tris + bldg_tris


# --------------------------------------------------------------------------
# Chunking
# --------------------------------------------------------------------------
def chunk_of(x, z):
    return int(math.floor(x / CHUNK)), int(math.floor(z / CHUNK))


def chunk_name(cx, cz):
    return "{:02d}_{:02d}".format(cx, cz)


def way_centroid(way, nodes, closed_ring=None):
    """Area centroid for buildings, mean of points for roads."""
    if closed_ring is not None:
        return poly_centroid(closed_ring)
    pts = [project(nodes, nid) for nid in way["nodes"] if nid in nodes]
    if not pts:
        return 0.0, 0.0
    return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)


# --------------------------------------------------------------------------
# Mesh building (bmesh, chunk-local coordinates)
# --------------------------------------------------------------------------
def new_bm():
    bm = bmesh.new()
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


def add_road_to_bm(bm, pts, half_width, y, closed, mat_slot, col_layer, col, geom):
    """Ribbon along a polyline. Returns triangle count added."""
    if len(pts) < 2:
        return 0
    L, R = miter_offsets(pts, half_width, closed)
    n = len(pts)
    segs = n if closed else n - 1

    def V(x, z):
        return bm.verts.new((x - geom["ox"], y, z - geom["oz"]))

    for i in range(segs):
        j = (i + 1) % n
        if L[i] is None or R[i] is None or L[j] is None or R[j] is None:
            continue
        if L[i] == R[i] or L[j] == R[j]:
            continue  # degenerate (zero-width) segment
        v_li = V(*L[i])
        v_lj = V(*L[j])
        v_ri = V(*R[i])
        v_rj = V(*R[j])
        for tri in ((v_li, v_lj, v_ri), (v_lj, v_rj, v_ri)):
            f = bm.faces.new(tri)
            f.material_index = mat_slot
            if col_layer is not None:
                for lp in f.loops:
                    lp[col_layer] = col
    return 2 * segs


def add_building_to_bm(bm, ring, height, mat_slot, col_layer, col, geom,
                       include_bottom=False):
    """Flat-shaded prism: top fan + side quads (+ optional bottom fan).

    Every triangle gets its own vertices so Blender exports flat face
    normals (no smoothing across roof/side edges).
    """
    n = len(ring)
    if n < 3:
        return 0
    ox, oz = geom["ox"], geom["oz"]

    def V(x, z, y):
        return bm.verts.new((x - ox, y, z - oz))

    def mk(a, b, c, slot):
        f = bm.faces.new((a, b, c))
        f.material_index = slot
        if col_layer is not None:
            for lp in f.loops:
                lp[col_layer] = col
        return f

    tris = 0
    # top fan (CCW ring => +y normal)
    for i in range(1, n - 1):
        mk(V(ring[0][0], ring[0][1], height),
           V(ring[i][0], ring[i][1], height),
           V(ring[i + 1][0], ring[i + 1][1], height), mat_slot)
        tris += 1
    # sides (outward-facing, 2 tris per edge)
    for i in range(n):
        j = (i + 1) % n
        xi, zi = ring[i]
        xj, zj = ring[j]
        mk(V(xi, zi, height), V(xj, zj, height), V(xj, zj, 0.0), mat_slot)
        mk(V(xi, zi, height), V(xj, zj, 0.0), V(xi, zi, 0.0), mat_slot)
        tris += 2
    # bottom fan (reversed => -y normal, watertight collision)
    if include_bottom:
        for i in range(1, n - 1):
            mk(V(ring[0][0], ring[0][1], 0.0),
               V(ring[i + 1][0], ring[i + 1][1], 0.0),
               V(ring[i][0], ring[i][1], 0.0), mat_slot)
            tris += 1
    return tris


def finalize_bm(bm, name, mats):
    """bmesh -> mesh datablock."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    for m in mats:
        me.materials.append(m)
    return me


def make_materials():
    mats = {}
    for mname, (r, g, b) in MAT_COLORS.items():
        mat = bpy.data.materials.new(mname)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 1.0
        mat.diffuse_color = (r, g, b, 1.0)
        mats[mname] = mat
    return mats


# --------------------------------------------------------------------------
# Landmarks
# --------------------------------------------------------------------------
def write_landmarks(ways, nodes, built_ids):
    entries = []
    for w in ways:
        tags = w.get("tags") or {}
        if "name" not in tags:
            continue
        if not any(k in tags for k in ("tourism", "amenity", "building", "historic")):
            continue
        bval = tags.get("building")
        hw = tags.get("highway")
        is_building = bval is not None and bval not in ("no",) and w["id"] in built_ids
        if is_building:
            ring = [project(nodes, nid) for nid in w["nodes"] if nid in nodes]
            ring = dedupe_points(ring)
            cx_, cz_ = poly_centroid(ring) if len(ring) >= 3 else (0.0, 0.0)
            height = build_height(tags)
            kind = "building"
            kindval = bval
        elif hw in ROAD_WIDTH:
            pts = [project(nodes, nid) for nid in w["nodes"] if nid in nodes]
            pts = dedupe_points(pts)
            cx_ = sum(p[0] for p in pts) / len(pts) if pts else 0.0
            cz_ = sum(p[1] for p in pts) / len(pts) if pts else 0.0
            height = ROAD_Y[ROAD_MAT[hw]]
            kind = "highway"
            kindval = hw
        else:
            pts = [project(nodes, nid) for nid in w["nodes"] if nid in nodes]
            pts = dedupe_points(pts)
            cx_, cz_ = poly_centroid(pts) if len(pts) >= 3 else (
                (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)) if pts else (0.0, 0.0))
            height = build_height(tags) if is_building else 0.0
            kind = "highway" if hw else "building"
            kindval = hw if hw else bval
        ccx, ccz = chunk_of(cx_, cz_)
        entries.append({
            "name": tags["name"],
            kind: kindval,
            "x": round(cx_ - ccx * CHUNK, 3),
            "z": round(cz_ - ccz * CHUNK, 3),
            "height": round(height, 3),
            "chunk": chunk_name(ccx, ccz),
            "built": w["id"] in built_ids,
        })
    entries.sort(key=lambda e: (e["chunk"], e["name"]))
    out = {
        "chunk_size_m": CHUNK,
        "local_origin_note": "x/z are chunk-local, origin at chunk min corner (world = chunk*80 + local)",
        "count": len(entries),
        "landmarks": entries,
    }
    with open(LANDMARKS_OUT, "w") as f:
        json.dump(out, f, indent=2)
    return entries


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def main():
    log("factory reset")
    bpy.ops.wm.read_factory_settings(use_empty=True)

    os.makedirs(os.path.dirname(BLEND_OUT), exist_ok=True)
    os.makedirs(CHUNK_DIR, exist_ok=True)
    stale = glob.glob(os.path.join(CHUNK_DIR, "chunk_*.glb"))
    for old in stale:
        os.remove(old)
    if stale:
        log("removed %d stale chunk GLBs" % len(stale))

    log("loading OSM: %s" % OSM_PATH)
    nodes, ways = load_osm()
    log("nodes: %d, ways: %d" % (len(nodes), len(ways)))

    roads, buildings = classify(ways, nodes)
    log("roads: %d, buildings: %d" % (len(roads), len(buildings)))

    # --- triangle budget: adaptive decimation if needed -------------------
    est = estimate_tris(roads, buildings)
    log("estimated geometry tris (pre-decimation): %d" % est)
    if est > TRI_BUDGET:
        log("over budget (%d > %d) -- decimating roads" % (est, TRI_BUDGET))
        for thresh in (2.0, 5.0, 10.0):
            for r in roads:
                r["pts"] = decimate_road(r["pts"], thresh)
            est = estimate_tris(roads, buildings)
            log("  after %g deg decimation: %d tris" % (thresh, est))
            if est <= TRI_BUDGET:
                break
        else:
            for r in roads:
                r["pts"] = r["pts"][::2]
            est = estimate_tris(roads, buildings)
            log("  after alternate-node drop: %d tris" % est)
        if est > TRI_BUDGET:
            global BUILD_MAX_POINTS
            BUILD_MAX_POINTS = 12
            est = estimate_tris(roads, buildings)
            log("  reduced building point cap to 12: %d tris" % est)
            if est > TRI_BUDGET:
                BUILD_MAX_POINTS = 8
                est = estimate_tris(roads, buildings)
                log("  reduced building point cap to 8: %d tris" % est)
    log("final estimated geometry tris: %d (budget %d)" % (est, TRI_BUDGET))

    # --- assign chunks by centroid -----------------------------------------
    built_ids = set()
    chunks = {}  # (cx, cz) -> {"geom": bm, "col": bm, "mats": {name: slot}}
    roads_assigned = []

    def chunk_slot(cx, cz, mname):
        ch = chunks.setdefault((cx, cz), {
            "geom": new_bm(), "col": new_bm(), "mats": {}, "geom_meta": {
                "ox": cx * CHUNK, "oz": cz * CHUNK,
                "col_layer": None,
            },
        })
        if mname is None:
            return ch, None
        if mname not in ch["mats"]:
            ch["mats"][mname] = len(ch["mats"])
        return ch, ch["mats"][mname]

    for b in buildings:
        ring = simplify_ring(b["ring"], BUILD_COLLINEAR_TOL, BUILD_MAX_POINTS)
        if len(ring) < 3:
            SKIP["building_simplified_under_3"] = SKIP.get("building_simplified_under_3", 0) + 1
            continue
        cx, cz = chunk_of(*poly_centroid(ring))
        ch, slot = chunk_slot(cx, cz, "building")
        rng = random.Random(b["way"]["id"])
        f = rng.uniform(0.45, 0.65) / MAT_COLORS["building"][0]  # 0.818..1.182
        col = (f, f, f, 1.0)
        bm = ch["geom"]
        if bm.loops.layers.color.get("Col") is None:
            bm.loops.layers.color.new("Col")
        cl = bm.loops.layers.color["Col"]
        add_building_to_bm(bm, ring, b["height"], slot, cl, col, ch["geom_meta"])
        # collision: simplified more aggressively, watertight prism
        cring = simplify_ring(b["ring"], COLL_COLLINEAR_TOL, COLL_MAX_POINTS)
        if len(cring) >= 3:
            add_building_to_bm(ch["col"], cring, b["height"], 0, None, (1.0, 1.0, 1.0, 1.0),
                               ch["geom_meta"], include_bottom=True)
        built_ids.add(b["way"]["id"])

    for r in roads:
        pts = r["pts"]
        if len(pts) < 2:
            continue
        if r["closed"]:
            cx, cz = chunk_of(*poly_centroid(pts))
        else:
            cx, cz = chunk_of(*(sum(p[0] for p in pts) / len(pts),
                                sum(p[1] for p in pts) / len(pts)))
        half = ROAD_WIDTH[r["kind"]] / 2.0
        y = ROAD_Y[r["mat"]]
        ch, slot = chunk_slot(cx, cz, r["mat"])
        bm = ch["geom"]
        if bm.loops.layers.color.get("Col") is None:
            bm.loops.layers.color.new("Col")
        cl = bm.loops.layers.color["Col"]
        add_road_to_bm(bm, pts, half, y, r["closed"], slot, cl,
                       (1.0, 1.0, 1.0, 1.0), ch["geom_meta"])
        # collision: flat top plate at road height (ground plane does the rest)
        add_road_to_bm(ch["col"], pts, half, y, r["closed"], 0, None,
                       (1.0, 1.0, 1.0, 1.0), ch["geom_meta"])
        built_ids.add(r["way"]["id"])
        roads_assigned.append(r)

    log("chunks with geometry: %d" % len(chunks))

    # --- materials + objects -----------------------------------------------
    mats = make_materials()
    objs = {}
    stats = {}
    for (cx, cz), ch in sorted(chunks.items()):
        bm = ch["geom"]
        if len(bm.verts) == 0:
            ch["geom"].free()
            ch["col"].free()
            continue
        # geometry object
        slot_names = [""] * len(ch["mats"])
        for mname, slot in ch["mats"].items():
            slot_names[slot] = mname
        me = finalize_bm(bm, "mesh_geom_%s" % chunk_name(cx, cz),
                         [mats[m] for m in slot_names])
        obj = bpy.data.objects.new("geometry_%s" % chunk_name(cx, cz), me)
        bpy.context.scene.collection.objects.link(obj)
        # collision object
        cb = ch["col"]
        cme = finalize_bm(cb, "mesh_col_%s" % chunk_name(cx, cz), [])
        cobj = bpy.data.objects.new("collision_%s" % chunk_name(cx, cz), cme)
        bpy.context.scene.collection.objects.link(cobj)
        objs[(cx, cz)] = (obj, cobj)
        stats[(cx, cz)] = {
            "geometry_tris": len(me.polygons),
            "collision_tris": len(cme.polygons),
        }

    log("saving working blend: %s" % BLEND_OUT)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

    # --- export chunk GLBs ---------------------------------------------------
    total_geo = 0
    total_col = 0
    largest = (0, None)
    exported = 0
    for (cx, cz), (gobj, cobj) in sorted(objs.items()):
        path = os.path.join(CHUNK_DIR, "chunk_%s.glb" % chunk_name(cx, cz))
        gname, cname = gobj.name, cobj.name
        gobj.name = "geometry"
        cobj.name = "collision"
        bpy.ops.object.select_all(action="DESELECT")
        gobj.select_set(True)
        cobj.select_set(True)
        bpy.context.view_layer.objects.active = gobj
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_materials="EXPORT",
            export_colors=True,
            export_apply=True,
            export_yup=True,
        )
        gobj.name, cobj.name = gname, cname
        exported += 1
        g = stats[(cx, cz)]["geometry_tris"]
        c = stats[(cx, cz)]["collision_tris"]
        total_geo += g
        total_col += c
        if g + c > largest[0]:
            largest = (g + c, chunk_name(cx, cz))

    # names restored; save again so the blend keeps unique names
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

    # --- landmarks ------------------------------------------------------------
    entries = write_landmarks(ways, nodes, built_ids)
    log("landmarks written: %d entries -> %s" % (len(entries), LANDMARKS_OUT))

    log("exported %d chunk GLBs" % exported)
    log("geometry tris total: %d   collision tris total: %d" % (total_geo, total_col))
    log("largest chunk: %s (%d tris)" % (largest[1], largest[0]))
    for reason, count in sorted(SKIP.items()):
        log("skipped -- %s: %d" % (reason, count))
    log("done in %.1f s" % (time.time() - T0))


if __name__ == "__main__":
    main()
