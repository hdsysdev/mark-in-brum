# Birmingham art-pass provenance

**Prepared:** 2026-08-21T09:56:48Z
**Runtime scene:** `scenes/world/city_centre.tscn` via `scenes/main/game_root.tscn`
**Implementation:** `src/world/birmingham_art_pass.gd` and
`src/world/landmark_primitives.gd`

## Asset decision

The six recognizable Birmingham landmarks remain original procedural geometry,
but the surrounding playable streets now use the collected, locally shipped CC0
asset packs instead of stopping at a primitive showcase:

- Selected Kenney City Kit (Commercial) GLBs provide shops and background blocks.
- Selected Kenney City Kit (Roads) GLBs provide lights, signs, traffic lights,
  roadworks, and service props.
- Selected Kenney Car Kit GLBs provide parked vehicles.
- Selected Poly Haven 1K diffuse/roughness maps provide asphalt, paving, brick,
  concrete, and metal surface detail.

Every runtime file is under `assets/`, with the Kenney CC0 license texts copied
to `assets/licenses/`. Exact archive hashes, download dates, source URLs, and
runtime output directories are recorded in `docs/asset_ledger.json`. No runtime
CDN, copyrighted logo, Google imagery, or unlicensed texture is used.

## Reusable reference data

| Reference | Exact source URL | License / terms | Use and modifications |
|---|---|---|---|
| Birmingham city-centre OSM extract | `https://overpass-api.de/api/interpreter` | ODbL-1.0; © OpenStreetMap contributors | Existing pinned response at `art_source/osm/birmingham_city_centre.json`, fetched 2026-08-20. Used for semantic landmark names, road/public-realm context, and the chunk coordinate convention. No source geometry is imported into the new art meshes. |
| Kenney City Kit (Commercial) | `https://kenney.nl/assets/city-kit-commercial` | CC0-1.0 | Selected GLBs scaled and arranged as shops/background massing around the Birmingham-specific landmarks. |
| Kenney City Kit (Roads) | `https://kenney.nl/assets/city-kit-roads` | CC0-1.0 | Selected lights, signs, traffic lights, roadworks, and service props placed along the route. |
| Kenney Car Kit | `https://kenney.nl/assets/car-kit` | CC0-1.0 | Five selected vehicle GLBs used as static parked street dressing. |
| Poly Haven city surfaces | `https://polyhaven.com/textures` | CC0-1.0 | Selected 1K asphalt, paving, brick, concrete, and metal diffuse/roughness maps, locally imported and tinted for the overcast Birmingham palette. |
| OpenStreetMap attribution and license | `https://www.openstreetmap.org/copyright` | ODbL-1.0 | Attribution and redistribution policy reference. |
| Open Database License text | `https://opendatacommons.org/licenses/odbl/1-0/` | ODbL-1.0 | License interpretation reference. |
| Pinned OSM query | `art_source/osm/query.overpassql` | ODbL-1.0 data query context | Existing query bounding box covers Birmingham city centre. No modification to this source file. |

The pinned extract already records:

- `query_sha256`: `bf8adc6a511d3104dcae6d392237ebaed816d1b814f7657c6e0a67c8aa200c69`
- `response_sha256`: `54e76ea9c293fbeb939b0088aa04845a299a41d5b55693606e97a2985668ad50`
- `fetched_at_iso`: `2026-08-20T22:51:31Z`

## Landmark interpretation

The six landmark families are simplified, de-branded silhouettes rather than
reproductions of copyrighted images or logos:

- Grand Central / New Street: glass frontage, long canopy, mullions, and
  platform-wayfinding sign.
- Victoria Square / Town Hall: classical stone massing, front colonnade,
  pediment, clock tower, and square/fountain.
- Council House / Chamberlain Square: blue-grey civic massing, wings,
  pediment, dome, and square/fountain.
- Bullring: low dark podium plus a curved disc-clad façade, glass entry, and
  fictional shop signage (`BRUM MARKET`, `PAVEMENT & PASTIES`).
- St Martin in the Bull Ring: nave, gable, square tower, spire, and cross.
- Rotunda: tall tapered cylindrical silhouette, roof, and horizontal bands.

All anchor coordinates are explicitly documented in
`BirminghamArtPass` and are a condensed adaptation of the existing OSM/chunk
route. They are not a redistributed OSM polygon export.

## Runtime safety

`art_source/.gdignore` remains present, and the project export excludes
`art_source/*`, `tools/*`, `tests/*`, and `docs/*`. The art pass only loads
local, ledgered `res://assets/...` resources; it contains no file-system reads,
remote URLs, external texture references, or runtime CDN dependencies.
