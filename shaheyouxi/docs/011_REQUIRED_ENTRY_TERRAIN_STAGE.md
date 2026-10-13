# Required underground-entry static terrain stage

Source-only implementation candidate: `game/scripts/terrain/required_entry_terrain_stage.gd`, with 24 focused methods in `game/tests/terrain/RequiredEntryTerrainStageTest.gd`. Contract `011-required-entry-static-terrain-v1`; artifact kind `required_entry_static_generation_artifact`. The separate audit-only `bounded_terrain_contract.gd` is unchanged and still always incomplete.

This stage actually generates detached cell records for the three required underground entry masks. It does not change the existing WorldComponent, generation inputs, biome sites, native bodies, F handling, schema3 saves or lifecycle-v2 wire protocol. Local static-generation completion does not imply global terrain completion, native readiness, dynamic clearance or transfer eligibility.

## Directly reviewed originals

Original bytes were reopened read-only at `authorities/originals`, not inferred from an extraction or report. The reviewed SHA256 values match the approved generation sources:

- cehua.docx: `ea47bd7c60236a94a7a7d8fbc374fe0f10cb88af7a3c1815dea94009841effc9`
- shuzhi.xlsx: `736e69ab96ff099e1bec5148b85c82f91865eed0c0012153a8ab5a03079966bc`
- sucai.xlsx identity: `e0389a4b17f150e6d3335c8f18b7c21584bad9dd664c918e11f07ae1dcc97cd5`

Relevant cehua references use **top-level body paragraph** numbers: 52 fixes the starting body and Biome; 58 describes large contiguous Biomes; 65 requires ordinary H1 rock before H0 cave carving and permits disconnected caves; 68 requires same-XY paired entries; 69 excludes liquids, random rocks/minerals, trees and ordinary POIs around entries; 70 guarantees required entrances; 74 orders generation; 75 requires fail-closed generation. These are not all-paragraph extraction indices.

Original shuzhi ranges:

- `32_Biome总表!A9:D17`: nine mother-body Biome identities and layers
- `32_Biome总表!X9:Y17`: per-Biome H0 ground and underground ordinary-rock resource IDs
- `38_层间连接!O6:P7`: 3×3 entry bodies and 7×7 protected masks
- `145_普通岩石天体参数!F2`: 1×1×1 ordinary-rock occupancy
- `23_动物!F1:F9`: natural surface-Biome distribution; the stage binds the original header and all eight row texts
- `36_层级液体许可!C10:G10`: depth2 has no natural liquids

The existing GenerationInputs validator verifies approved original hashes and the exact approved generation projection before the stage can become ready. WorldComponent verifies the materialized world, Prefab and approved bundle. The small source23 animal projection is explicit in this version's source rules and bound by the original shuzhi hash; it is not represented as a field already present in GenerationInputs.

## Explicit engineering algorithm

`same-layer-existing-site-integer-voronoi-v1` is a declared engineering choice, not a claim that the original author prescribed Voronoi generation. For each cell, consider only existing sites with the same map kind and depth. Compare integer `(x−site_x)² + (y−site_y)²`; break exact ties by ascending lexical Biome ID. Do not generate sites, call random selection or sample density/area values. The validated 400-cell radius makes integer distance arithmetic bounded. The spawn's existing site is exactly at spawn, so it retains `x03_db_wendai_linyuan` at distance zero. Duplicate same-layer sites are already refused by WorldComponent.

All IDs and source-cell references come from the verified input Biome. The output preserves all nine input rows, including raw qualitative layout intent and the three null unimplemented projection placeholders. This finite algorithm does not claim to implement global area, cave fractions, liquid targets, mineral weights or population density.

Before selection, the complete layer address must match an existing validated spawn or connection endpoint address, and at least one same-map/depth site must exist. Materialization, query and the internal assignment seam all fail closed if that support is absent; downstream cell construction never indexes an empty selection.

Reordering otherwise valid input site/connection arrays, with a correctly rebound layout fingerprint, cannot change selected Biomes or the canonical regions/operations. The full-world and layout hashes still change, because they intentionally bind the actual input arrays. An artifact from the previous ordered world is rejected; no identity binding is discarded for order independence.

## Real cell records and exact supported scope

For seed42, the stage emits exactly 147 layer-addressed cells:

| Region | Layer | Half-open bounds | Cells |
|---|---|---|---:|
| First connection lower endpoint | underground1 | `[20,75,7,7]` | 49 |
| Second connection upper endpoint | underground1 | `[34,66,7,7]` | 49 |
| Second connection lower endpoint | underground2 | `[34,66,7,7]` | 49 |

Bounds and connection identities come from the actual validated component, never hardcoded seed42 coordinates in production. This contract supports exactly three underground 49-cell masks. Same-layer mask overlap is refused rather than merged or double-counted. The two actual entry bodies remain `[22,77,3,3]` and `[36,68,3,3]`.

Each cell has all 12 required categories:

1. Biome: selected existing site, integer distance, stable ID, algorithm version and source cells
2. Source ground: actual occupied H0 and the selected Biome's ground resource ID
3. Default rock: actual source H1 resource ID, explicitly occupied before carving with 1×1×1 size, then explicitly removed by its generated operation
4. Generated carve: applied generation operation, scoped only to default geological H1 rock
5. Caves: resolved required H0 opening only, without a global random-cave topology assertion
6–9. Liquids, minerals, trees and ordinary POI: explicit natural-generation exclusions linked to the exact protected operation and cehua69; depth2 liquid records additionally bind table36
10. Natural initial animals: empty eligible candidate set from the original surface-only distribution
11. Prefab: preserved existing per-cell object IDs; never cleared by this stage
12. Permanent changes: preserved saved change keys; never created or impersonated by this stage

Animal completion is narrowly about **initial natural distribution**. It is not a prohibition on carrying animals underground, and does not remove or resolve actors, enemies, summons, future animals or user objects. The artifact explicitly leaves dynamic occupancy unknown. Entry exclusions likewise do not erase arbitrary categories, existing Prefab content or player edits.

Every generated operation binds the full existing connection SHA256, stable connection ID, endpoint index, full layer, body rectangle, safety rectangle and all 49 mask cells. It is base-terrain generation after source ground/H1 fill and before random population. It is never an F-time carve or a player `permanent_changes` write.

The three openings have no generated connecting tunnel. All outside cells, including the 96 one-cell inspection-ring cells, remain unknown. They are never implicit walls, implicit air, or completed cave boundaries. The surface entry and surface Prefab are outside local completion; the artifact retains references to every existing Prefab object, including the 15 H1 walls and southern doorway's H0 floor. Knowing a Biome assignment at spawn does not certify surface terrain.

## API, completeness and strict validation

- Construct with the existing generation, Prefab and world-bundle documents and approved technical profile (`011` by default)
- `materialize(component, expected_world_id)` validates the existing world and produces the actual deterministic detached artifact
- `validate(artifact, component, expected_world_id)` reconstructs expected records from validated inputs and checks every required field and cell, rather than trusting caller completion claims or a rehashed artifact
- `biome_at(component, world_id, layer, cell)` returns a source-backed assignment only, without occupancy completion
- `inspect_cell(artifact, component, world_id, layer, cell)` validates first, then returns a resolved static record only inside an actual mask; outside returns explicit unknown with both implicit-air and implicit-wall false
- `require_native_ready(...)` validates local completion but always refuses with `ENTRY_TERRAIN_NATIVE_AND_DYNAMIC_READINESS_UNPROVEN`

The computed completion report counts actual rows and unresolved required categories against an exact per-category status map. Seed42 has `cell_count=147`, `unresolved_cell_count=0`, `local_static_generation_complete=true`. `global_terrain_complete`, `native_ready`, `dynamic_occupancy_resolved`, `formal_world_allowed`, `native_clear_allowed` and `transfer_allowed` remain false. There is no native certificate API. The unchanged world layout still declares its global stages incomplete.

Bindings include the original source map, exact generation/Prefab input-document hashes, full validated WorldComponent hash, approved bundle byte hash, full layout and core-layout fingerprints, separate permanent-change hash, stage hash/version, algorithm hash, full per-region layer hash and per-operation connection hash. The final canonical SHA256 covers every artifact field except its own hash field.

Validation rejects missing, duplicated, shifted, reordered and extra cells/regions/categories; caller-changed source IDs, initial rock, carve provenance, animal semantics or permission flags; stale worlds/edits; and unknown schema fields. Recalculating the final hash cannot authorize altered semantics. The expected-schema comparator reuses verified exact-safe JSON semantics: expected integers alone accept finite exactly integral floats within ±(2^53−1); floats retain exact type/equality; hashes stay unchanged; recursion is capped at32. The integer bound is written as an integer and converted to float, avoiding the known decimal-literal issue. Validation does not mutate inputs.

## Tests and artifact-export gate

The 24 source-authored methods cover exact seed42 regions/147 cells; source H0/H1 and carving; actual operation provenance; local/global distinction; repeatability; no generation/random calls; input nonmutation; same-layer nearest-site assignment; stable ties; reordered inputs; spawn identity; region edges and ring/tunnel unknowns; animal/dynamic scope; protected exclusions; existing walls/doorway; saved-change binding; original/input/world rejection; bad addresses; coverage holes/duplicates; rehashed semantic forgeries; all identity bindings; permission forgery; safe JSON boundaries; and overlapping-mask refusal.

Runtime has **not been run by this implementation worker**. The approved parent resource window is required for Godot, even headless. Source-only checks are not runtime evidence.

For the separately approved focused test runner, the seed42 method supports `SHAHE_REQUIRED_ENTRY_EXPORT_PATH`. With no variable it performs no output-file I/O. When explicitly set to a new absolute path inside this project's `evidence/`, it refuses an existing destination, writes the actual GDScript-produced artifact only after successful `validate`, checks write/flush errors, reads the file back through JSON, validates it again and prints `REQUIRED_ENTRY_TERRAIN_EXPORTED` with path, fingerprint,147 cells and readback result. It does not touch runtime saves. The runner must still require the entire 24-method gate to pass before accepting that export as evidence; a file left by a later-failed suite is only a failed-run artifact. There is no Python duplicate generator or hand-authored occupancy artifact.

Persistence, native physics/approach coverage, dynamic-field checks, transfer tickets and rollback, source/destination readiness and F integration remain separately gated by `011_NATURAL_ENTRY_MATERIALIZATION_PLAN.md`. This source slice does not alter those contracts or establish their completion.

## First runtime gate retained as failed

2026-10-06 07:45UTC sourcebe62051 executed2methods: first generated/exported/readback-validated147cells; second failed only at GdUnit integer assertion applied to JSON source depth float (294assertion reports), leaving22methods unrun. Report `evidence/011core_runs_20261006T074429448232Z.json`. Productionstage unchanged. Both analogous source-depth test comparisons now first require Address.is_integer, then compareint values without tolerance; finite24-method revalidation remains pending. Export from this failed suite is evidence of that first method, not an accepted full gate.

Second gate2889895:14/15executedmethods passed; door reference fixture omitted full-layer filtering and counted the three preserved H0 floors as surface doors. Production artifact correctly retains depth0/1/2; updated test requires surface door1 and allthreeH0references separately, plus15surfacewalls. Remaining9methods were unrun; full24gate pending. The complete suite was reviewed for analogous JSON-type and same-XY cross-layer count assumptions before requesting rerun.

## Complete finite gate and produced asset

2026-10-06 07:52UTC sourceeb0193d:24/24methods passed,0errors/failures/skips/orphans,nowarnings,exit0/fullresourceguard. Report `evidence/011core_runs_20261006T075149440053Z.json`; actual asset `evidence/011_required_entry_stage_seed42_20261006T075149440053Z.json` is576896bytes, SHA256 `666a67f96fb0850b9de40acba2aa1797b979869b6ab6f2822b31ced368f71553`. The actualGDScript producer and validator performed export/readback; no Python substitute generated this asset. Asset bytes equal both prior partial-run exports, while those failed suites remain historically red.

Process175345 normallyreaped/groupempty,peak109707264bytes,12.586seconds,CUAreset. This passes local initial-static generation and validation, not persisted restoration, native space readiness, surface approach, active layer transfer, dynamic clearance or actual F operation. Existing schema3 remains untouched.
