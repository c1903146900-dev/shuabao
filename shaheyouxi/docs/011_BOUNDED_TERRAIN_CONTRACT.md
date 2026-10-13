# Detached bounded terrain contract candidate

Source slice only. `game/scripts/terrain/bounded_terrain_contract.gd` projects an already validated WorldComponent into an explicit finite terrain contract. Its 18 GdUnit methods are in `game/tests/terrain/BoundedTerrainContractTest.gd`. The latest focused runtime gate is recorded below; no full runtime artifact export is claimed.

This is deliberately incomplete terrain. The candidate records what the reviewed original requires, what the existing technical Prefab actually contains, what the existing world has permanently changed, and what is still unknown. Neither an empty object list nor a protected opening is a traversability certificate.

## API and exact support boundary

- Construct with the existing generation, Prefab and world-bundle documents plus approved technical profile (`011` by default). GenerationInputs and WorldComponent validate the authority/projection inputs. Invalid input leaves `ready=false`.
- `materialize(component, expected_world_id)` calls WorldComponent validation and projects only that existing component. It never invokes world generation, random selection, Prefab instantiation, cave carving, native physics, save I/O or interaction handling. Its result contains an artifact and explicit completeness report.
- `validate(artifact, component, expected_world_id)` verifies the source and full-world bindings, exact operation/region coverage, every cell and every required category against the current validated component. It accepts only the deterministic contract produced by this version. Source-valid biome IDs alone cannot authorize a caller-supplied per-cell assignment.
- `require_complete(artifact, component, expected_world_id)` first structurally validates, then refuses with `TERRAIN_REQUIRED_CATEGORIES_UNRESOLVED`. Every supported artifact has unresolved mandatory categories. There is no complete-fixture bypass, certificate method or native consumer in this version.

`ok=true` means structurally valid only. The successful report explicitly has `structure_valid=true`, `occupancy_complete=false`, `formal_world_allowed=false`, `native_clear_allowed=false` and `transfer_allowed=false`. The artifact repeats all three permission flags as typed booleans. Runtime services do not import this script. This version is not a persistence restore format.

This strict first version rejects altered/reordered/overlapping regions, additional categories and caller-resolved categories instead of silently accepting a future terrain schema. A future resolver requires an explicit contract revision and independent original-backed biome/ground/rock/population semantics. No nearest-site assignment is implemented.

## Identity and sources

Bindings include canonical validated full-world and full-layout SHA256 values, the existing layout core fingerprint, a separate permanent-changes SHA256, generation-stage SHA256/version, approved world-bundle byte identity and canonical generation/Prefab input-document hashes. The latter hashes are computed from the actual verified input documents, not inferred from filenames. Each region has a full layer address and its canonical hash; each endpoint operation includes the actual existing connection ID, full connection hash and endpoint index. The final artifact hash covers all content except its own hash field.

Full-world and permanent-change binding are important because the layout core fingerprint intentionally excludes world identity and player changes. An artifact created before a saved rock clearing is rejected against the changed component even when its core layout fingerprint is identical. Generated required-entry operations use connection provenance; they never write or impersonate `permanent_changes`.

The exact original source-hash map and all existing reviewed biome rows are copied, including ground/default-rock IDs, source cells, liquid interfaces and null area/cave/density values. Original mechanisms were rechecked read-only in cehua top-level body paragraphs 65, 68–70, 74–75 (all-paragraph extraction 171, 174–176, 180–181). The references include shuzhi 38!O6:P6/O7:P7, 32!X9:Y17, 32!S9:S12/W9:W12 and 145!F2. Source documents and formal projections are unchanged.

## Finite actual-location scope

Bounds are computed from the actual validated component, not a seed hardcoded into the production script. For seed 42:

| Region | Layer | Half-open cell bounds | Cells |
|---|---|---|---:|
| Existing Prefab plus first-entry inspection union | surface | `[1,75,26,20]` | 520 |
| First connection lower endpoint and inspection ring | underground1 | `[19,74,9,9]` | 81 |
| Second connection upper endpoint and inspection ring | underground1 | `[33,65,9,9]` | 81 |
| Second connection lower endpoint and inspection ring | underground2 | `[33,65,9,9]` | 81 |

There are 763 layer-addressed cells and 9156 mandatory category records. Each of four endpoint operations has 49 distinct safety-mask cells; both actual connection bodies remain 3×3. The first connection is at `[23,78]`, body `[22,77,3,3]`, safety `[20,75,7,7]`; the second is at `[37,69]`, body `[36,68,3,3]`, safety `[34,66,7,7]`.

The one-cell underground ring is a technical inspection scope, not an original gameplay radius or a rock-wall/cave topology assertion. It contributes 32 unresolved surrounding cells per underground endpoint, 96 total. No region or carve joins the two underground1 openings. The surface bounding union includes unknown intervening terrain; it does not declare a corridor. The original Prefab bounds remain `[1,82,17,13]`, all 15 actual H1 walls are referenced in their original cells, and the southern doorway at `[9,90]` retains only its existing technical H0 floor reference. The floor does not resolve the source-ground category.

The 4096-cell cap bounds the projection workload. It is an operational limit, not a gameplay rule. Same-layer region overlap is unsupported and rejected, rather than silently merging or double-counting cells.

## Every cell and category

Each cell must contain exactly these 12 categories:

- biome and source_ground: unknown everywhere. Biome sites are not per-cell assignments
- default_rock: surface explicitly has no default geological H1; underground records source-required occupied H1 before carving, with unknown biome-specific resource ID. Every underground default-rock category remains unknown
- generated_carve: exact connection-backed operation references for the three underground protected openings; no surface geological carve, no player-edit provenance
- prefab: exact existing object IDs covering that cell, including technical H0 and H1 objects. An empty list resolves only this Prefab contribution
- permanent_changes: exact saved per-cell change keys, separate from generated operations. A clearing describes only default-rock removal; it does not erase other category uncertainty
- caves: unknown final cave occupancy everywhere. Required-entry carving does not stand in for a completed cave generator
- liquids, resources, trees and ordinary_poi: explicit original-required exclusion contracts inside each 49-cell protected mask; unknown outside those masks
- animals: unknown everywhere; cehua 69's tree prohibition is not expanded into an invented animal prohibition

The protected exclusion and carve records are materialized generation requirements. They do not claim that the missing generation stages have run. Pre-carve H1 occupancy is known as a stage invariant; per-cell source rock IDs and final surrounding rock remain unresolved. The contract never asserts physical air or a completed final rock boundary.

For seed 42 the unknown counts are 763 each for biome/source_ground/caves/animals, 243 for default_rock, 567 each for liquids/resources/trees/ordinary_poi, and 0 for generated_carve/prefab/permanent_changes. All 763 cells are incomplete.

## Refusal codes

- `TERRAIN_INPUTS_NOT_READY`, `TERRAIN_WORLD_INVALID:<world-code>`: source or existing world validation failed
- `TERRAIN_BOUNDED_SCOPE_LIMIT`, `TERRAIN_REGION_OVERLAP_UNSUPPORTED`: technical projection scope cannot be represented safely
- `TERRAIN_SCHEMA_INVALID`, `TERRAIN_VERSION_UNSUPPORTED`: missing/unknown fields or unsupported identity
- `TERRAIN_CERTIFICATION_FORBIDDEN`: any native/formal/transfer permission claim, including non-boolean substitutes
- `TERRAIN_SOURCE_MISMATCH`, `TERRAIN_WORLD_BINDING_MISMATCH`, `TERRAIN_LAYER_BINDING_MISMATCH`: source, input/world/edit/stage, or full-layer identity mismatch
- `TERRAIN_CONNECTION_OPERATION_MISMATCH`: absent/altered connection, endpoint, safety mask, footprint, stage or carve provenance
- `TERRAIN_REGION_FIELDS_INVALID`, `TERRAIN_REGION_COVERAGE_INVALID`, `TERRAIN_CELL_COVERAGE_INVALID`, `TERRAIN_CATEGORY_COVERAGE_INVALID`: incomplete, duplicated, reordered or extraneous accounting
- `TERRAIN_CATEGORY_SEMANTICS_INVALID`: corrupt category or attempted unknown-to-empty/fixture resolution, even if the attacker recalculates the hash
- `TERRAIN_ARTIFACT_FINGERPRINT_MISMATCH`: final candidate identity differs
- `TERRAIN_REQUIRED_CATEGORIES_UNRESOLVED`: structurally valid candidate explicitly fails completeness

## Verification and later gates

The 18 source-authored GdUnit methods cover deterministic/nonmutating projection, source rejection, actual entry footprints, all endpoint layers, explicit cell/category unknown counts, initial underground H1, generation versus saved-edit provenance, disjoint rings, preserved walls/doorway, malformed/missing/rehashed data, stale permanent-change bindings, schema/flag refusal and incomplete-world rejection. NaN/nonmutation fixtures compare `var_to_bytes`; they do not stringify invalid floating-point values. The latest focused runtime result is recorded below.

A reviewable full candidate must be exported by this actual GDScript implementation in a separately approved bounded headless window. No manually duplicated Python generator is shipped as execution evidence. The test setup uses the established seed 42 WorldComponent factory; the contract itself only reads validated materialized data.

Later work must first resolve original-backed per-cell terrain and all required categories. Persistence then needs explicit 011.5 compatibility policy and actual-occupancy restore without regeneration; no silent old-save fill. Native readiness, full-body approach coverage, dedicated active transfer, actual RID application/rollback, lifecycle and F integration remain separate gates in `011_NATURAL_ENTRY_MATERIALIZATION_PLAN.md`. Save schema3, lifecycle-v2, original authority files and existing native/F behavior remain unchanged.

## JSON integer representation repair candidate

The first18-method gate executed9 methods and failed the ninth JSON roundtrip; the other9 were unrun. The subsequent one-method diagnostic also failed, specifically TERRAIN_CONNECTION_OPERATION_MISMATCH at operations[0].layer, with scalar-equal elements but differing deep-container numeric representation. Both raw logs remain retained. Full-precision JSON did not cure the representation mismatch.

The repaired validator compares against its already validated expected schema tree. Only expected integer positions accept JSON float values, and only finite exact integers in the symmetric safe range ±(2^53−1). Boolean/string/fractional/nonfinite/unsafe values are refused. Expected floating-point fields retain exact same-type equality without tolerance or coercion; hash strings are compared unchanged. Input dictionaries are never rewritten. Recursion is bounded32 and collection size/key sets must match. Added assertions exercise these refusals inside the existing focused method; the suite remains18 methods. This repair has source-only checks until its separately allocated runtime gate.

The safe integer limit is now an integer constant converted to float explicitly, following ActorInputs.integer. The retained bit diagnostic proved the decimal float literal one lower than the intended bound. Tests keep both signed boundary positives, adjacent-overflow refusals, and bit-constructed one-ULP float-field refusal. This corrects representation of the specified range; no range or tolerance is expanded.

## Latest finite runtime result

2026-10-06 07:08UTC, source0dfe81d: all18 methods passed,0errors/failures/skips/orphans,nowarnings,exit0. Report `evidence/011core_runs_20261006T070824146793Z.json` and raw log prove the full focused gate. Process165215 was normally reaped; owned group empty,peak157548544bytes,10.827seconds,CUAreset. This includes the source/category/malformed-negative tests previously unreached by stop-on-failure. Actual JSON representation and integer-boundary repairs passed. It does not certify occupancy completeness, final biome/cave/population generation, native materialization, transfer or persistence.

## Source exclusion contract revision2

Direct reread of original shuzhi32!N9:N12/S9:S12/W9:W12 establishes no random natural geological mineral H1 on any mother-surface cell, not just entry protection. The resources category explicitly means natural geological mineral nodes; Prefab contents, trees, animals and player edits remain separate. Original36!C10:G10 and the approved liquid_permissions depth2 row establish no natural liquids at depth2, including the inspection ring. Provenance is carried on each such category. Contract identity increments to011-detached-required-entry-terrain-v2; no runtime save schema changes.

Seed42 unknown counts now: resources96,liquids535,trees/ordinary_poi567; biome/source_ground/caves/animals remain763 and default_rock243. All763cells still incomplete. These are explicit original prohibitions, not evidence that remaining generation ran. Tests retain uncertain surface animals/trees and depth1 ring liquids, and reject forged exclusion source cells.

The three null quantity fields were introduced as unimplemented projection placeholders at tools/data/generation_settings.py:45, not read from three blank source columns. Original table32 supplies qualitative contiguous-biome layout and ground/rock IDs, table33 mineral weights, table37 liquid targets; these known rules must be implemented rather than called globally unspecified. A future genuine terrain-stage artifact must compute local completeness from resolved cells; this detached audit contract intentionally cannot certify native occupancy. Required underground7×7 openings can become explicit H0/clearedH1 after source-valid deterministic per-cell biome assignment. Unrelated tunnels, surface animals and outside-protection random populations may not be cleared by inference.

Revision2 runtime: 2026-10-06 07:26UTC source5c27f9f passed18/18,0errors/failures/skips/orphans,nowarnings,normalexit0/fullguard; report `evidence/011core_runs_20261006T072543359612Z.json`. Unknown-category counts and exclusion provenance were verified; completeness remainsfalse.
