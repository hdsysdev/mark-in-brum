#!/usr/bin/env python3
"""Regression tests for the asset ledger validator.

Run: python3 tests/unit/test_asset_ledger.py
(Plain unittest — the validator is a Python CLI, no Godot runtime needed.)
"""
from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.assets import validate_asset_ledger as mod  # noqa: E402


def make_entry(**overrides) -> dict:
    entry = {
        "id": "test_asset",
        "role": "test",
        "source_url": "https://example.com/test",
        "author": "Tester",
        "license": "CC0-1.0",
        "archive": "test.zip",
        "archive_sha256": "0" * 64,
        "downloaded_on": "2026-08-20",
        "modifications": [],
        "runtime_outputs": [],
        "status": "pending",
    }
    entry.update(overrides)
    return entry


class LedgerValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = Path(self._tmp.name)
        self.ledger_path = root / "docs" / "asset_ledger.json"
        self.archive_dir = root / "art_source" / "third_party_archives"
        self.ledger_path.parent.mkdir(parents=True)
        self.archive_dir.mkdir(parents=True)
        self.orig_ledger = mod.LEDGER_PATH
        self.orig_archive_dir = mod.ARCHIVE_DIR
        self.orig_root = mod.REPO_ROOT
        mod.LEDGER_PATH = self.ledger_path
        mod.ARCHIVE_DIR = self.archive_dir
        mod.REPO_ROOT = root

    def tearDown(self) -> None:
        mod.LEDGER_PATH = self.orig_ledger
        mod.ARCHIVE_DIR = self.orig_archive_dir
        mod.REPO_ROOT = self.orig_root

    def _write_ledger(self, assets: list[dict]) -> None:
        self.ledger_path.write_text(json.dumps(
            {"schema_version": 1, "policy": {}, "assets": assets}))

    def test_missing_ledger_is_an_error(self) -> None:
        self.assertTrue(mod.validate())

    def test_empty_ledger_is_valid(self) -> None:
        self._write_ledger([])
        self.assertEqual(mod.validate(), [])

    def test_missing_fields_are_rejected(self) -> None:
        entry = make_entry()
        entry.pop("license")
        self._write_ledger([entry])
        errors = mod.validate()
        self.assertTrue(any("missing 'license'" in e for e in errors))

    def test_unknown_license_is_rejected(self) -> None:
        self._write_ledger([make_entry(license="ALL-RIGHTS-RESERVED")])
        self.assertTrue(any("not in" in e for e in mod.validate()))

    def test_duplicate_ids_are_rejected(self) -> None:
        self._write_ledger([make_entry(), make_entry()])
        self.assertTrue(any("duplicate" in e for e in mod.validate()))

    def test_integrated_asset_without_archive_fails(self) -> None:
        self._write_ledger([make_entry(status="integrated")])
        self.assertTrue(any("archive missing" in e for e in mod.validate()))

    def test_integrated_asset_hash_mismatch_fails(self) -> None:
        payload = b"original bytes"
        archive = self.archive_dir / "test.zip"
        archive.write_bytes(payload)
        good_hash = hashlib.sha256(payload).hexdigest()
        self._write_ledger([make_entry(status="integrated",
                                       archive_sha256=good_hash)])
        self.assertEqual(mod.validate(), [])
        self._write_ledger([make_entry(status="integrated",
                                       archive_sha256="f" * 64)])
        self.assertTrue(any("hash mismatch" in e for e in mod.validate()))

    def test_missing_runtime_output_fails(self) -> None:
        payload = b"x"
        archive = self.archive_dir / "test.zip"
        archive.write_bytes(payload)
        self._write_ledger([make_entry(
            status="integrated",
            archive_sha256=hashlib.sha256(payload).hexdigest(),
            runtime_outputs=["assets/models/missing.glb"])])
        self.assertTrue(any("runtime output missing" in e for e in mod.validate()))


if __name__ == "__main__":
    unittest.main()
