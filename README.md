# Mark in Brum

A darkly comic third-person 3D sandbox for mobile web. You are Mark, an
antisocial man with a short fuse and a full bladder, loose in a condensed
Birmingham city centre. Explore, run errands, and cause escalating civic
chaos — while city-centre security slowly takes an interest.

**Working title.** Adults-only comedy. Non-explicit presentation, mature
content notice on first launch, and a reduced-grossness option included.

## Status

In active development. See `docs/GAME_DESIGN.md` for the vertical slice
definition and `docs/QA_MATRIX.md` for verification status.

## Tech

- Godot 4.7.2 (Standard), GDScript, Compatibility renderer
- Single-threaded WebAssembly / WebGL 2 export, portrait-first mobile
- Statically typed GDScript, signal-driven architecture
- GUT for headless unit/integration tests, Playwright for browser QA

## Development

```bash
# Parse/import check
godot --headless --path . --editor --quit

# Unit + integration tests
godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit

# Release Web export
godot --headless --path . --export-release "Web" build/web/index.html

# Local server for browser QA
python3 -m http.server 8080 --directory build/web
```

## Attribution

Third-party assets are tracked in `docs/ASSET_LEDGER.md`. Map data ©
OpenStreetMap contributors (ODbL) — see `ATTRIBUTION.md`.
