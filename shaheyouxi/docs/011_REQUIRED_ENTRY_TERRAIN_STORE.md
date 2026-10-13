# Required-entry terrain record store

Source-only candidate for independent exact storage and restoration of the already
generated 147-cell artifact. Production: `game/scripts/terrain/required_entry_terrain_store.gd`.
Finite gate: **24** methods in `game/tests/terrain/RequiredEntryTerrainStoreTest.gd`.
No engine, GUI, native physics or formal release acceptance is claimed by this slice.

## Narrow contract and identity

The standalone byte format is `required_entry_terrain_record_store_v1`. This name
is a detached storage identity, **not a new actor save schema or Build**. The
contained artifact remains schema 1, kind `required_entry_static_generation_artifact`,
contract `011-required-entry-static-terrain-v1`.

- `Store.new(generation, prefab, bundle)` accepts the approved 011 source documents
- `encode(artifact, existing_world, world_id)` validates first and returns bytes
- `decode(bytes, existing_world, world_id)` verifies framing, codec and checksums,
  then independently validates and returns the stored records
- `restore(artifact, existing_world, world_id)` independently validates an already
  decoded typed artifact and returns a detached deep copy of that exact input

The store has no filesystem write/read policy, directory owner, save slots, backup
selection, promotion or migration. A future owner can write/read returned bytes;
the focused test explicitly writes them to a unique `user://` test file, flushes,
reads back identical bytes, restores and removes only its own file. Existing
SaveStore, actor/world loaders, scenes and schemas are untouched.

Framing is a five-element JSON **array**: format, scalar-codec identity, world ID,
payload JSON string, SHA256 of that exact payload string. All five members must be
strings. Array framing avoids JSON object duplicate-key collapse at that boundary.
The payload is the existing `scalar_bits_le_v1` tagged tree. It preserves dictionary
keys, array order, int64 values, exact finite float64 bits (including signed zero),
bools, nulls and strings; duplicate dictionary keys in the tagged payload are
rejected. No Object decoding or numerical coercion is used.

The complete byte input and encoded artifact/world have a 4 MiB operational cap;
the codec's 64-edge and 100,000-value limits also apply. UTF-8 is checked before
Godot string decoding to reject overlong, truncated, surrogate and out-of-range
sequences without decoder error logs. This is an engineering limit, not a gameplay
or source-table rule. Both the stored-payload checksum and original artifact hash
must match. A recomputed checksum never substitutes for semantic validation.

## Independent restoration, without terrain reconstruction

The store never preloads or constructs Stage, WorldComponent, LayoutGenerator or
PrefabInstantiator. It never calls materialize, a world-creation operation, terrain
generation, instantiation or a random source. It uses existing read-only source,
layout and prefab validators; the layout validator's existing pure geometry,
constant stage-status and fingerprint helpers do not generate a layout.

The checks bind approved source hashes and full biome input rows, explicit source
rules and algorithm identity, the current world and layout, bundle, permanent
changes, generation stages, generation/prefab documents, spawn and existing sites.
The world is independently checked with the read-only layout/prefab validators and
actual approved room-template binding. Stale world edits fail rather than producing
replacement terrain. The store derives no new sites or population candidates.

For each of three existing underground operation/region pairs it checks the exact
connection and endpoint, complete layer address, body/safety rectangle, operation
provenance and flags. Each 7×7 mask must contain exactly 49 existing row-major
coordinates. Holes, duplicates, extra or reordered cells/regions and same-layer
mask overlaps refuse. There is no missing-cell repair path.

For each existing row the validator checks its twelve categories independently:
nearest same-layer existing site and lexical tie-breaking; integer distance;
source resource IDs/cells; source H0 and initial H1 state; generated carve links;
opening height; protected natural exclusions and the extra depth2 liquid source;
surface-only initial-animal scope; and preserved prefab/saved-change references.
Full-address support and a nonempty same-map/depth site set are checked before any
assignment access. Same depth in another world/body/frame is insufficient.

These checks inspect existing values and compare category invariants. They do not
build an expected 147-cell artifact or return a reconstruction. Only after every
row, reference, scope claim and checksum passes does restore deep-copy the original
stored input. Strict comparison includes type and finite float bits; schema integer
fields do not accept floats, booleans or strings. Hashes require exact lowercase
64-character hexadecimal strings.

Outside cells, surface and inspection rings remain unknown, with neither implicit
air nor implicit walls. Dynamic occupancy is unresolved. Local initial-static
completion remains 147 cells only. Global completeness, native readiness, dynamic
clearance, formal-world permission, native-clear permission and transfer/F permission
all remain false.

## Review export versus exact stored records

The accepted ordinary JSON review export is
`evidence/011_required_entry_stage_seed42_20261006T075149440053Z.json`, 576,896 bytes,
SHA256 `666a67f96fb0850b9de40acba2aa1797b979869b6ab6f2822b31ced368f71553`.
Its original artifact fingerprint is
`d58ece4a5249132975d05486d7be9ab706c866289650e2af2943a9a513b17202`.
It was produced by the accepted 24-method stage gate, not by a Python generator.

Godot ordinary JSON parsing turns integer tokens into floats. That review file is
therefore **not** itself the new exact tagged store format. The store deliberately
refuses an unnormalized parsed review artifact rather than silently migrating it.
A test-only import helper restores only enumerated schema integer fields and arrays,
with a finite, integral, safe-bound check using `float(9007199254740991)` from an int
constant. It skips the entire `biome_inputs` and `source_rules` subtrees so approved
source floats and literal spreadsheet `cell` references remain unchanged.
It never updates the artifact fingerprint: the original fingerprint must verify,
and the result must exactly match the actual typed Stage-produced fixture.

The fixture setup alone creates the seed42 matching world and materializes terrain
once, before storage assertions. This is explicitly generation **for setup**, not
restoration. Generation/factory/random counters are captured after setup and checked
unchanged after every test, including rejected inputs. A production source-call
audit independently prohibits Stage/World/generator/factory dependencies and calls.
The tests exercise complete typed/bit equality after byte and real-file roundtrips,
plus known bit-pattern fixtures without fragile decimal float literals.

## Old saves, Build policy and unfinished integration

Null/missing terrain is explicitly refused with no regeneration. Known schema-3
payload declarations receive `ENTRY_STORE_LEGACY_ACTOR_SCHEMA3_TERRAIN_MISSING`.
A real current SaveStore-shaped envelope (including version 2 and an exact payload
containing schema 3) receives
`ENTRY_STORE_ACTOR_SAVE_ENVELOPE_REQUIRES_EXPLICIT_SCHEMA_WIRING`. The store does not
decode or accept that envelope as terrain, invent a component, load an old backup,
or interpret absence as an empty world. Test framing includes the schema **inside**
the tagged payload, rather than relying only on a naked top-level schema field.

This is consistent with `011_5_RELEASE_POLICY_SLICE.md`: actor schema 3 has no terrain
inventory and cannot satisfy a terrain-required target. An explicit user old-save
policy, actual schema/owner wiring, visible version and independent unique internal
Build identity, compatibility evidence and any verified migration remain separate
future work. No new actor schema number is allocated here. No migration route,
automatic fallback, formal release or native/F readiness is authorized.

## Validation status

The 24 source-authored methods cover accepted-export identity/import; complete exact
roundtrip; actual stored bytes; non-generation audit/counters; nonmutation; missing
artifact; actual legacy envelope framing; both checksums; malformed framing/UTF-8;
malformed/duplicate codec nodes; limits; strict integers/hashes/float bits; cell and
region coverage; connection operations; source/algorithm/world bindings; stale edits;
nearest/spawn assignment; all category shapes/semantics; false permissions and
population scope; full-layer/site support; references; and unknown outside scope.

Only static/Python checks are permitted to this implementation worker. No Godot
process has been started for this slice. Parsing, execution and all 24 runtime
results remain pending the parent's separately approved resource window. The prior
Stage 24/24 result does not imply this new store suite passes.

Static checks completed for this candidate: pinned review bytes/147 rows/1,764
categories; exactly 24 test methods; production forbidden-dependency/call audit;
all preload targets present; no duplicate method names or unbalanced lexical
brackets; whitespace checks; test import preserving the original mixed numeric
types, source-reference strings and artifact SHA256. A Python model of the UTF-8
byte predicate agreed with strict decoding on 65,808 deterministic vectors. These
are source/fixture checks, not a GDScript parser result or runtime test pass.

The malformed-input review also requires type-safe textual boundaries. Untrusted
artifact/envelope/world identity comparisons use strict typed equality, rather than
Godot's cross-type scalar String operators. A bounded world text-slot preflight
protects the older read-only layout/prefab validators without changing their loaders;
nullable biome rock IDs are checked against the approved source row before invoking
those validators. Complete layer text types are guarded before Address validation.
The same 24 methods include number, bool, null, array and dictionary replacements
for envelope fields, artifact/world identity, regions, operations, assignments,
references and nested world layer/site/prefab fields. No extra test methods or
runtime acceptance claim are added by this repair.

## First runtime window and bounded partition

The09ba9b6 full24 command reached the unchanged45second limit after21methods explicitly passed; method22 was in progress and methods23–24 had not started. No script error, failed assertion or warning preceded termination; no overall24summary exists. `evidence/011core_runs_20261006T082658818503Z.json` staysfailed. The owning desktop runner reportsSIGTERM/reaped−15 andcleanup_group_empty=true; its wrapperfinished andCUAwasreset. PeakownedRSS153440256bytes.

Per-method timing shows bounded validation work, not a stalled loop: first12about20seconds, malformedmetadata7.862seconds, changed-world matrix5.943seconds. The approved next profile `--actor011-entry-terrain-store-split` selects exactly the original first12 and last12, with two disjoint supportedGdUnit discoveryfilters. It does not delete assertions, skip discovered tests, change production, or increase45/110second limits. Both exact12 summaries must pass; first failure stops second. The single launcher delays10seconds forreset. Eachnormal exit records leader reaping and same-runner-PIDnamespace emptygroup proof before admitting another command. External shellPIDvisibility is not used as cleanup proof.

## Complete unchanged24-method finite result

2026-10-06 08:42UTC source832b8dc: original24methods passed as disjoint12+12; each summary has0errors/failures/skips/orphans andexit0, no warnings. `evidence/011core_runs_20261006T084045048674Z.json` reports18.215s and26.775s (outer47.343s), both within45/110limits. Firstpeak153333760bytes,second118923264bytes.

Desktop runnerPIDnamespace `pid:[4026532200]` provesPIDs183378/183407leader_reaped=true andnormal_group_empty=true;wrapper183353finished,CUAreset. Actual file-byte readback, exacttypes/bits,147-record independent semantics, malformedwrongtypes/UTF8/codec/legacy framing and no generation all passed. The earlier single-command timeout retains its failed classification. No loader/schema/native/F integration is implied.
