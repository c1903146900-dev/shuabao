# 012 actual-slot profile routing: source gate

## Scope and status

This change adds the slot-storage portion of explicit schema5 selection. It does
not expose a new menu option, change the coordinator or CLI, install a schema5
runtime owner, grant user items, migrate a save, or alter the ordinary library.
The new tests are authored source, not an engine-pass claim. An approved resource
window is required to compile and run them. The existing Registry and cold
validator are reused without modification.

Owned implementation files:

- `game/scripts/actor/actor_local_save_slots.gd`
- `game/scripts/inventory/inventory_profile_marker012.gd` (shared leaf)
- `game/tests/inventory/InventorySlotProfiles012Test.gd`

## Stable legacy storage and API

The persistent slot index remains exact schema version 1. Its fields remain
`schema_version`, `slots`, and `last_slot_id`; each row remains exactly `slot_id`,
`label`, `status`, `last_sequence`, and `world_id`. No profile, marker hash, private
identity, or new path is added to the index. Existing index encoding and old save
bytes are not rewritten for a profile migration. Windows4 retains its existing
index/save generation-store route.

`create_slot(label)` and `create_slot(label, 4)` use the original marker-free
creation branch. They return the original `{ok: true, slot_id}` result. The new
explicit `create_slot(label, 5)` is the only production schema5 creation route.
Profiles must be exact integers 4 or 5. Windows5 fails before a new slot or index
write; there is no unsupported generation5 fallback.

The nested session ticket remains exactly `owner_id`, `generation`, `slot_id`,
and `session_id`. `begin_session` adds two top-level result fields:

- `profile`: exact integer 4 or 5
- `profile_marker_sha256`: empty string for marker-free 4, canonical marker hash
  for 5

`derive_paths` and its returned path fields are unchanged. `inspect_save` adds a
top-level `profile`; its existing state, sequence, identity, reason, hash and
zero-generation fields remain. `finish_session` and `fail_session` keep their
existing success/failure result shapes.

`slot_profile(slot_id)` is an owned-library read and returns either
`{ok: true, profile, marker_sha256}` or `{ok: false, code}`. Listing leaves valid
legacy rows unchanged, adds only `profile: 5` to valid schema5 rows, and adds
`profile_error` with no guessed profile to damaged rows. These annotations never
enter the persisted index.

## Marker contract and session immutability

The marker is `slots/<slot_id>/save_profile.json`, outside `world/`. It is a
canonical exact-scalar-codec document, at most 4096 bytes, with exactly:

- `slot_id`: the exact containing 32-character lowercase hexadecimal slot ID
- `profile`: integer 5
- `schema_version`: integer 5
- `contract`: `sandbox012-world-inventory-v1`

The leaf `inventory_profile_marker012.gd` depends only on the exact codec. It
provides `make_value(slot_id)`, `validate(value, slot_id)`, and
`decode_text(text, slot_id)` for later Scope integration without a dependency
cycle through Registry/Core. The pure test asserts its fixed contract and
profile constants match the actual combined session and Registry. The leaf does
not authorize a read, inspect a filesystem, follow links, or infer legacy4 from
an invalid document; those duties remain with the caller.

Slots reads only while it owns the library, rejects linked slot/marker paths,
rejects malformed, duplicate-field, wrong-slot, unsupported, noncanonical,
oversize or directory markers, and never guesses a profile from the save. Only
absence means profile4. A marker-free schema5 main therefore reaches the actual
schema4 validator and fails `UNSUPPORTED_SCHEMA` with its bytes unchanged.

Production writes a marker only into this call's fresh, empty, unindexed slot.
It never overwrites a marker or stamps an already-indexed legacy slot. An
independent canonical readback must succeed before the index can publish the
new slot. Session start checks the binding before locks and again after the
incomplete-index write, then freezes the selected profile and exact marker hash
privately. Inspection and finish recheck it; an observed change latches the
session failure even if the original marker is restored. Failure preserves the
incomplete state and original save files. The caller can still `fail_session`
to finish its failure bookkeeping without converting the slot to ready.

## Failed creation and evidence preservation

A failed schema5 marker or index write does not publish an unverified new slot.
If index commitment is absent and a fresh disk reread proves the index does not
name the new slot, the entire new directory is atomically moved to
`slot_creation_quarantine/<slot_id>/` outside `slots/`. All existing contents,
including a partial or invalid marker, are retained. A bounded exact-codec
`creation_failure.json` trace is added when possible.

Quarantine holds at most 16 entries and never deletes or overwrites older
failures. At capacity, on ownership loss, unreadable index, unsafe paths, or a
failed rename, the new unindexed directory remains intact and the result says
`quarantined: false`. A remaining unindexed directory blocks later creation;
it is never silently adopted. There is no generic orphan-repair operation.

A result marked `committed`, or a disk index that already names the slot even
when a writer omitted that flag, prevents quarantine. Such a directory stays
where the index names it. The old schema4 empty-directory cleanup branch is
unchanged.

The two controlled failure seams are `_write_profile_marker` and the existing
`_write_index_value`. Production does not accept an injected validator, profile
picker, or trusted save result. Tests override only writers inside new fixture
roots; marker publication still has independent readback and quarantine still
has independent index proof.

## Cold save inspection

Both profiles are made and binding-checked by the closed Registry. Profile4
uses the original SaveStore and full terrain validator; profile5 uses the
bounded store and real cold inventory/terrain validator. The fresh actual
server-authority service retains its own random world ID and is never restored
or adopted. Its persistent bytes and the world's zero generation/instantiation/
world-seed-random counters are checked after successful inspection.

Inspection calls only `inspect_main`, never `acquire`, `load_latest`, `save`, a
backup fallback, or a migration. Existing writer-lock, safe-path, canonical
payload readback, sequence, world-marker, private identity, and full static-state
checks remain in place. The Registry and complete validator chain remain alive
for the entire read. Finish still independently reads disk and requires
`normal_shutdown`, the exact world, and the confirmed sequence before updating
the existing v1 index.

## Test selection and limits

`InventorySlotProfiles012Test.gd` has 12 finite methods:

- 2 `test_pure_*`: marker exact fields/types/contract/identity, strict v1 index
- 8 `test_metadata_*`: legacy byte roundtrip and ticket; explicit5 and read-only
  listing; malformed/wrong-slot/duplicate/noncanonical/oversize/directory/link
  markers; immutable active profile in both directions; marker/index failure
  quarantine; flagged and unflagged committed writes; bounded-quarantine
  overflow; Windows5 and unknown-profile rejection before writes
- 2 `test_disk_*`: real schema5 inspect/finish/cold reopen; both cross-profile
  main-file directions without migration

Run the 10 pure/metadata methods separately from the two disk methods. Disk
cases generate one cached real 667-cell fixture only within the test's fresh
`user://inventory_slot_profiles012/` roots and add one empty inventory player.
They create no native space, network process, ordinary-library entry, user item,
or chest. Each disk method should receive its own measured resource window;
metadata success does not stand in for full-validator disk success. The existing
`ActorLocalSaveSlotsTest` remains the schema4 full-save regression gate. Symlink
creation and schema5 disk cases are skipped on actual Windows, whose schema5
route is intentionally unsupported.

No engine, GUI, Blender, native-space, or multi-instance execution was performed
by the slot implementation worker. Engine compilation, the 12 new cases, and
legacy slot regression remain pending the parent's resource gate.

## Actual lightweight gate, 2026-10-08 UTC

10/10 pure/metadata tests passed in 1.833 seconds, peak133234688 bytes, exit0 and full cleanup. The two real-disk methods were explicitly excluded and remain unrun. Scope's separate five methods passed in 1.532 seconds, peak121098240 bytes, exit0/full cleanup. All38 captured extends/preload source hashes were unchanged after both runs; the graph excluded the owner/Frame/network-main files being edited separately. This is not ordinary menu or Windows5 acceptance. Evidence: `012_inventory_slot_scope_actual_result.json`.

## Actual real-disk gate

Two real-disk cases passed on2026-10-08 in30.958 seconds, peak337911808 bytes, exit0, zero errors/failures/skips/orphans and full cleanup. Includes full667 schema5 inspection/finish/reopen and mismatched4/5 rejection with main/index bytes preserved. First attempt used the wrong underground-only fixture Stage and was correctly refused by the product validator; that failure and its cascading test errors remain recorded. Only fixture generation and fail-fast diagnostics changed. The39-file final static dependency closure remained byte-identical during the passing run. See012_inventory_slot_disk_actual_result.json.
