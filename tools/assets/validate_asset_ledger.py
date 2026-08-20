#!/usr/bin/env python3
"""Validate the asset ledger against policy and disk state.

Fails (exit 1) when:
  - an entry is missing required fields
  - an integrated asset's archive file is missing or its hash disagrees
  - a license string is not one of the allowed set
  - a status is neither 'pending' nor 'integrated'

Usage:
  python3 tools/assets/validate_asset_ledger.py [--report]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LEDGER_PATH = REPO_ROOT / "docs" / "asset_ledger.json"
ARCHIVE_DIR = REPO_ROOT / "art_source" / "third_party_archives"
ALLOWED_LICENSES = {"CC0-1.0", "CC-BY-4.0", "MIT", "ODbL-1.0", "Apache-2.0"}

REQUIRED_FIELDS = [
    "id", "role", "source_url", "author", "license", "archive",
    "archive_sha256", "downloaded_on", "modifications", "runtime_outputs",
    "status",
]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate() -> list[str]:
    errors: list[str] = []
    if not LEDGER_PATH.exists():
        return [f"ledger missing: {LEDGER_PATH}"]
    try:
        data = json.loads(LEDGER_PATH.read_text())
    except json.JSONDecodeError as exc:
        return [f"ledger is not valid JSON: {exc}"]
    if data.get("schema_version") != 1:
        errors.append("unsupported schema_version")
    assets = data.get("assets")
    if not isinstance(assets, list):
        return ["ledger 'assets' must be a list"]

    ids: set[str] = set()
    for entry in assets:
        if not isinstance(entry, dict):
            errors.append("asset entry is not an object")
            continue
        for field in REQUIRED_FIELDS:
            if field not in entry or entry[field] == "" or entry[field] is None:
                errors.append(f"asset entry missing '{field}'")
        entry_id = entry.get("id", "")
        if entry_id in ids:
            errors.append(f"duplicate asset id '{entry_id}'")
        ids.add(entry_id)
        if entry.get("license") not in ALLOWED_LICENSES:
            errors.append(f"{entry_id}: license '{entry.get('license')}' not in {sorted(ALLOWED_LICENSES)}")
        if entry.get("status") not in {"pending", "integrated"}:
            errors.append(f"{entry_id}: invalid status '{entry.get('status')}'")
        if entry.get("status") == "integrated":
            archive_path = ARCHIVE_DIR / entry["archive"]
            if not archive_path.exists():
                errors.append(f"{entry_id}: archive missing: {archive_path}")
                continue
            actual = sha256_file(archive_path)
            if actual != entry["archive_sha256"]:
                errors.append(
                    f"{entry_id}: hash mismatch: ledger {entry['archive_sha256'][:16]}... "
                    f"disk {actual[:16]}...")
            for output in entry.get("runtime_outputs", []):
                output_path = REPO_ROOT / output
                if not output_path.exists():
                    errors.append(f"{entry_id}: runtime output missing: {output}")
    return errors


def report(assets: list[dict]) -> None:
    print(f"{'ID':<34} {'license':<10} {'status':<11} source")
    for entry in assets:
        print(f"{entry['id']:<34} {entry['license']:<10} {entry['status']:<11} {entry['source_url']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()

    if args.report:
        if LEDGER_PATH.exists():
            data = json.loads(LEDGER_PATH.read_text())
            report(data.get("assets", []))
        else:
            print("no ledger present")
        return 0

    errors = validate()
    if errors:
        print("ASSET LEDGER INVALID:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("asset ledger valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
