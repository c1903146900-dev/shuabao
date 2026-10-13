# 011 schema-4 terrain save integration

This is an independent **development_unreleased technical entry**, not a formal
Build or a default old-save policy. New scene:
`game/scenes/actor_terrain_session011.tscn`. It uses
`game/scripts/actor/actor_terrain_network_main.gd`, extending the existing actor
owner. `ACTOR_SAVE_SCHEMA4 = 4` is explicit; the old
`game/scenes/actor_session011.tscn` and `ACTOR_SAVE_SCHEMA = 3` remain available.

The implementation is present, with exactly **12** source-authored methods in
`game/tests/actor/ActorTerrainSaveIntegrationTest.gd`. The bounded file gate passed on 2026-10-06. Native physics, GUI, ENet and
multiple-instance integration remain unverified.

## Actual assets and hooks

- `actor_terrain_session_state.gd` is a pure complete-contract wrapper around the
  unchanged `ActorSession` and the already accepted `RequiredEntryTerrainStore`
- `_prepare_session()` retains the original actor session and client setup, then
  constructs the terrain Store and wrapper from the approved source documents
- `_make_save_store()` selects schema 4 and the wrapper validator on the existing
  `SandboxSaveStore`, preserving exact-scalar mode and its **4,194,304-byte** cap
- `_create_new_world()` first creates the original world/actor model, then actually
  constructs one `RequiredEntryTerrainStage` and calls `materialize()` once. A
  complete combined-state validation must succeed before the new artifact is kept
- `_restore_authority_state()` validates the full new contract, independently
  restores existing records through Store, strips only the already-validated
  terrain component, and then calls the original actor owner's restore hook
- `_persistent_state_for_save()` uses the existing real actor Controller's state
  and adds the actual complete typed `terrain_component`, with validation before
  the SaveStore write
- `terrain_persistence_statistics()` and `_write_report()` report stage construction,
  materialization, successful generation and restore counts plus artifact hash and
  actual cell count. A successful fresh owner has counts **1/1/1/0**; a successful
  fresh restore owner has **0/0/0/1**

The persistence slice made one deliberately small original-owner change: its report
uses `_actor_save_schema_for_report()`. Its original implementation returns 3; only the
new owner overrides it to return 4. That report change left the old owner's save
constructor, restoration, creation, controller, public snapshots, hello and lifecycle
wire unchanged. The subsequent finite native slice adds one default-preserving
`_make_actor_space()` factory; see `011_SCHEMA4_TERRAIN_NATIVE.md`.

## Exact on-disk contract

Schema 4's state contains exactly these eight fields:

1. `world_id`
2. `world_seconds`
3. `revision`
4. `next_auto_due_world_seconds`
5. `profiles`
6. `world_component`
7. `actor_component`
8. `terrain_component`

The terrain value is the complete typed artifact Dictionary, including its original
hash, source/algorithm/world bindings, three regions, 147 cells and all 12 per-cell
categories. It is **not** a detached Store byte envelope, nested JSON string,
compressed string, regeneration hint or completion flag. The existing SaveStore
exact codec encodes the whole combined state once, within its unchanged version-2
`scalar_bits_le_v1` envelope. The terrain Store's standalone `encode/decode` format
is not used in this integration.

The accepted Stage asset used for independent seed42 comparison is
`evidence/011_required_entry_stage_seed42_20261006T075149440053Z.json`,
576,896 bytes, SHA256
`666a67f96fb0850b9de40acba2aa1797b979869b6ab6f2822b31ced368f71553`.
Its original artifact fingerprint remains
`d58ece4a5249132975d05486d7be9ab706c866289650e2af2943a9a513b17202`.
The test-only review-import helper restores enumerated integer slots, preserving
source floats and source-reference strings, and compares the original fingerprint
and complete typed record. Production never imports this ordinary-JSON review file.

SaveStore's existing build identity remains `kind = development_unreleased`, with
null `game_version`, `build_id` and `build_number`. No formal Build is allocated or
inferred by the schema number. The companion release-policy change is a separate
known-schema inventory mapping; schema3-to-schema4 remains incompatible.

## Restore and failure behavior

Session setup and restoration never construct Stage, call materialize, create a
world, instantiate a Prefab or choose a random seed. The existing world's validator
objects may be constructed; their generation/instantiation/random counters remain
zero. Store validates the actual saved rows without synthesizing replacements.
Only after the complete combined contract succeeds may world, actor or authority
state change. `terrain_component` is stripped before calling the original actor
restore because its `authority_state()` intentionally preserves unknown fields.

The wrapper makes all failed combined-state validation results
`recoverable_corruption = false`, including missing/null/wrong terrain, changed
source bindings, unsupported fields/versions and semantically corrupt terrain.
A current schema3 envelope is refused by SaveStore as `UNSUPPORTED_SCHEMA` before
state restoration. A terrain-missing state is refused as
`ACTOR_TERRAIN_COMPONENT_REQUIRED_NO_MIGRATION`. Neither failure selects an older
backup, grants write readiness, creates terrain, fills absent records or migrates
anything. The rejected current main and valid older backup remain byte-identical.
This change does not alter SaveStore's separate, existing recovery behavior for
outer-envelope JSON/checksum corruption; compatibility/state failures are never
reclassified as that recoverable outer corruption.

The inherited startup order remains load/create, prepare runtime, initial save,
then listen. Failed Stage initialization/materialization or complete-state
validation returns through the actual owner's fatal cleanup before runtime/listen
or an initial save. A repeated creation attempt is refused. A late missing terrain
component also fails before any save bytes change. Existing health, food, energy,
position, fallback, clocks, timers and profiles are retained; restored actors and
peers remain inactive, with no input latches or activation generations restored.

## Finite 12-method gate

1. Actual fresh-owner generation once and complete match to the accepted 147-row asset
2. Real initial save, close, reopen and new-owner restore, whole-tree exact types/bits,
   nontrivial resource/clock values, inactive restore, zero generation, no restore write
3. A real schema3 current main and valid older schema3 backups refused without changes
4. Missing/null terrain refused before base-state mutation and without backup fallback
5. Wrong terrain types, nested legacy text types and world-ID types fail closed
6. Unknown combined/component fields and versions, including file-level fallback refusal
7. Changed terrain/world/actor sources, with valid old backup preserved
8. Rehashed semantic terrain corruption and terrain checksum corruption refused
9. Failed actual new Stage leaves no main/backup/identity files or listener and cannot retry
10. Runtime preparation failure and late missing terrain prevent initial/following saves
11. Unchanged 4 MiB write/read refusal, without old-backup fallback or silent cap increase
12. Original schema3 constructor/getter, new schema4 metadata/report, unchanged lifecycle-v2,
    separate scenes, public-snapshot exclusion and no-generation restore/setup source audit

The fixture uses real owner creation/save/restore hooks, real `ActorController`,
real actor/world/authority models and the production exact SaveStore with real file
bytes. It explicitly substitutes a tiny pose-only native-space object and bypasses
scoped multiplayer setup, process-argument bootstrap and final engine quit. It
calls the inherited runtime/save sequencing seam, but does not execute the full
network `_ready()` bootstrap or open a socket. Therefore it proves only its bounded
persistence contract; it cannot establish collision, render, scoped API, native
readiness or ENet integration. No test was skipped or represented as passing by
this source-only implementation.

## Limits preserved

Only the three required underground initial-static masks have stored local
completion. Surface terrain, rings, outside cells, global generation, dynamic
occupancy and approach geometry remain unresolved. `formal_world_allowed`,
`native_clear_allowed` and `transfer_allowed` stay false. In the accepted persistence
slice, the artifact was not fed to native queries.
The subsequent finite adapter in `011_SCHEMA4_TERRAIN_NATIVE.md` reads its actual
validated rows into three bounded underground query-support regions. This does not
change any persisted certification flag or put terrain into public snapshots.
Approach terrain, F, transfer, runtime carving and formal-world permission remain
unimplemented and require separate gates.

## Source-only verification

Completed: exactly 12 test methods; all new preload/scene targets exist; the
persistence-slice legacy-owner diff was the report getter; forbidden generation calls
are absent from
new setup/restore/wrapper paths; new terrain is a Dictionary in the state; existing
SaveStore and Stage/Store production files are unchanged by this worker; pinned
review bytes/hash match; `git diff --check` is clean. These are static checks, not a
GDScript parse result, runtime pass, full integration result or release approval.

Independent source review found no blocking wiring defect. Coverage limits: the
negative Stage case covers constructor rejection, not a later materialize failure;
the exact reopen fixture varies clock/resources but retains default position,
fallback and action timers. JSON report integers require finite integral values
before conversion. These limits do not alter the 12 pending runtime assertions.

## Frozen pending runtime gate

`--actor011-terrain-save` selects only the 12 methods above, with no cold import.
The desktop launcher delays 10 seconds for CUA reset. Budgets remain one headless
PID at 192 MiB, effective reserve 900 MiB, raw margin 192 MiB, 45 seconds per
command and 110 seconds outer. Normal completion requires the owning desktop
runner to reap the leader and prove its process group empty in that same PID
namespace. An unrelated shell's empty process listing is not cleanup evidence.

Source preflight and 59 runner + 32 ReleaseSpec + 6 package Python tests passed:
`evidence/011_schema4_source_preflight_20261006T0911.json` and
`evidence/011_schema4_source_python_20261006T0911.log`. The 12 Godot methods subsequently passed as recorded below. No native, GUI, F-transfer or formal-world acceptance is claimed.

## Actual bounded file gate passed

Candidate d48431df29738888937ef2d6b63cc94e989b405f ran all 12 methods in one
headless command: 12 passed, zero errors/failures/flaky/skipped/orphans and no
script warnings. Actual test time was 22.338 seconds; outer elapsed 23.671 seconds.
Peak owned RSS was 179,281,920 bytes, below the unchanged 192 MiB cap.

Evidence: `evidence/011core_runs_20261006T091347862729Z.json`, its matching
`011core_actor_core_20261006T091347862729Z.log`, and
`011core_completion_20261006T091337Z.json`. Godot PID 189095 exited 0, was reaped,
and the owning desktop runner proved its process group empty in
`pid:[4026532200]`; wrapper PID 189069 exited 0. CUA reset completed.
An initial CUA transport disconnect occurred before any launcher; one reset
restored access and exactly one engine command was launched.

The file tests establish fresh creation once, typed full-terrain save, exact
close/reopen restoration with zero terrain/world generation, schema3/missing
terrain refusal, and actual legacy/new report and SaveStore schema agreement.
The documented fake native-space/scoped-multiplayer seams and coverage caveats
remain; these results do not prove native loading, full network bootstrap, approach
terrain, F transfer or formal-world acceptance.
