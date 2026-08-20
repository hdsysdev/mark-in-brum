#!/usr/bin/env python3
"""Fetch and pin the Birmingham city-centre OSM extract.

One-shot tool: normal builds must never hit Overpass. The response is
pinned at art_source/osm/birmingham_city_centre.json and committed.

Usage:
  python3 tools/osm/fetch_birmingham.py [--query path/to/query.overpassql]

If --query is omitted the pinned query in art_source/osm/query.overpassql
is used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OSM_DIR = REPO_ROOT / "art_source" / "osm"
PINNED_OUTPUT = OSM_DIR / "birmingham_city_centre.json"
ENDPOINT = "https://overpass-api.de/api/interpreter"
USER_AGENT = "mark-in-brum-dev/0.1 (asset pipeline; one-shot fetch)"


def fetch(query: str) -> dict:
    request = urllib.request.Request(
        ENDPOINT,
        data=query.encode("utf-8"),
        headers={"User-Agent": USER_AGENT},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=200) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", type=Path)
    parser.add_argument("--endpoint", default=ENDPOINT)
    args = parser.parse_args()

    query_path = args.query or (OSM_DIR / "query.overpassql")
    query = query_path.read_text()
    print(f"fetching from {args.endpoint} ...", file=sys.stderr)
    data = fetch(query)

    elements = data.get("elements", [])
    print(f"received {len(elements)} elements", file=sys.stderr)

    pinned = {
        "schema_version": 1,
        "fetched_at_iso": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "endpoint": args.endpoint,
        "query_file": "art_source/osm/query.overpassql",
        "query_sha256": hashlib.sha256(query.encode("utf-8")).hexdigest(),
        "response_sha256": hashlib.sha256(
            json.dumps(data, sort_keys=True).encode("utf-8")).hexdigest(),
        "license": "ODbL-1.0",
        "attribution": "© OpenStreetMap contributors",
        "elements": elements,
    }
    PINNED_OUTPUT.write_text(json.dumps(pinned, indent=1))
    print(f"pinned {len(elements)} elements to {PINNED_OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
