# 012 fixed save-profile foundation

## Status and scope

Source foundation only, pending independent review and a parent-approved Godot window. No runtime result is claimed here. The new registry and cold validator are not wired into the ordinary menu, owner, Frame, Slots, RPC, GUI or exports. Existing ordinary play still uses its original schema4 path. No data-source rule, gameplay grant or migration is introduced.

The new files are:

- `game/scripts/inventory/inventory_save_profiles012.gd`
- `game/scripts/inventory/inventory_cold_validator012.gd`
- `game/tests/inventory/InventorySaveProfiles012Test.gd`

The only existing-file change in this slice is the explicitly approved `inventory_world_session012.gd` constructor's optional validation-only world scope and a strict String guard before comparing its inventory contract. Core type-guard hardening is separately owned/reviewed by the parent.

## Closed profiles and API

`Registry.new(terrain_session, authority, directory, automatic_count, manual_count)` captures the exact actual TerrainSession and Authority, their catalogue/protocol configuration, path, and bounded integer slot counts (automatic 1–64; manual 1–63). Invalid inputs leave `ready` false. It does not create a directory, acquire a lock, read a save, apply a component or configure a storage adapter.

Only exact integer profile IDs 4 and 5 exist. Strings, floats, booleans, unknown versions, custom scripts and arbitrary callbacks cannot register a profile.

- Profile 4: the exact original `save_store.gd`, exact original TerrainSession object and `validate_combined_state` method, schema4, exact scalar codec, 4 MiB envelope ceiling. Its Store constructor configuration is identical to the existing owner's constructor. Existing Windows schema4 generation-storage opt-in remains the existing owner's responsibility; this foundation does not change it.
- Profile 5: exact `inventory_world_save_store012.gd`, exact registry-owned ColdValidator object and `validate_combined_state` method, schema5, exact scalar codec, 4 MiB envelope ceiling. BoundedStore keeps the existing bounded reason policy and real Store commit receipts.

`descriptor(profile)` returns the fixed script resources and scalar configuration. It is a description, never a validity or permission token. `make_store(profile)` returns `{ok, store, validator, descriptor}` or a closed failure. Every factory call uses only these fixed constructors and validator methods. A returned descriptor cannot change future factories.

`verify_binding(profile, store, expected_world_id = "")` checks the current actual service/configuration binding, exact Store script, exact validator instance and method, profile/schema, codec/budget, catalogue/protocol, path and slot counts. A supplied saved world ID must be legal and equal the Store's bound world ID. An empty expected ID is for pre-load configuration inspection, not proof that a world is loaded. A nonempty invalid Store world is always rejected. Schema5 also rejects any generation adapter or generation-configuration error.

This method intentionally does not attest that a Store was the owner's original instance, that the lock belongs to the owner, that load succeeded, that a live Frame is sealed, or that a save committed. Future owner/Frame integration must preserve those existing checks and compare the original Store instance itself; the registry must not become a substitute for them.

## Why a cold validator is required

The ordinary network bootstrap allocates a new actual Authority with a random world ID before loading a save. A live Combined created with the normal three arguments is bound to that fresh ID, so it must reject inventory snapshots from a different saved world. Mutating the live Authority early or constructing a fabricated Authority merely to pass validation would weaken the boundary.

ColdValidator instead retains the real TerrainSession and real Authority configuration. It first admits only the full schema5 field set, contract and legal saved world ID, then makes a temporary empty Core scoped to the candidate ID and a temporary Combined using that ID as an explicitly validation-only scope. The candidate's world, actor, terrain, profiles and inventory still pass the full existing validators and exact final-envelope budget. Configuration or captured terrain-service changes fail closed.

The approved Combined change is narrowly:

1. An optional fourth `validation_world_id: String = ""` parameter.
2. Empty/default resolves to the actual Authority's world ID, preserving existing three-argument behavior.
3. A nonempty scope must be a legal world ID and exactly match the supplied Core's ID.
4. Catalogue hash and protocol still come exclusively from the exact actual Authority object.
5. Top-level inventory contract must be a String before comparison.

No cold validation calls restore, creates a player/chest, grants an item, generates/materializes a world, activates an actor, adopts a saved Authority state, or writes a file. The temporary Core remains empty; it is used only to validate the supplied snapshot. The registry's existence does not authorize restoring the projection returned by `Combined.terrain_state` without first validating the full candidate.

## Windows phase requirement

Schema5 is explicitly unsupported on Windows in this registry. Both factory and verification check the actual OS and refuse it with `INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED`. The informational platform helper cannot override that check. There is no rename fallback, automatic schema downgrade, old-layout conversion or copying.

Before any Windows inventory entry or export is enabled, a separate approved phase must extend and validate the immutable generation-storage profile, bind full schema5 validation and inventory-aware owner/Frame/Slots paths, test crash/retention/commit failures on the actual Windows route, and preserve exact committed-main receipts. Until that phase passes, the UI/launcher must not offer a working Windows schema5 entry.

## Finite pending gate

The suite contains seven focused methods:

1. Fixed profile selection, exact original schema4 factory equivalence, invalid profile IDs and Windows policy.
2. Invalid constructor types/counts and malformed actual Authority configuration.
3. Wrong Store/profile/script/callback/configuration/world binding and changed source services.
4. Cold admission against a genuinely fresh random-ID Authority; original three-argument Combined mismatch refusal; no state/adoption/grant/generation/activation.
5. Bad contracts, internal world/profile mismatches and malformed metadata/field types, all closed without candidate or live-state mutation.
6. One actual schema5 save/reopen using a new random-ID Authority, exact saved state/bytes, no live restore or activation.
7. Full envelope acceptance within each profile and explicit schema4↔schema5 rejection without migration.

A single generated real technical fixture is cached as exact-codec bytes for the suite. Cold-reader owners are separately constructed and retain their actual random IDs. Only the fixture builder invokes the existing world creation path. The real-file test confines paths and cleanup to `user://inventory_profiles012/`. Windows runs assert the profile5 block instead of attempting profile5 file writes.

After independent review, run this focused gate together with the Core and 7 WorldSave methods affected by the approved Combined change, under the root resource-window rules. Inventory UI's separate pending gate is not claimed by this registry work.

## Actual Linux finite result

2026-10-08: 7/7 tests passed, 0 errors/failures/skips/orphans. Guard 33.363 seconds, 369647616 bytes peak, exit0 and complete cleanup. Includes real schema5 file save/cold reopen using a fresh random-ID Authority without adopting world/actor/inventory during validation. Windows5 still refused; no ordinary entry/RPC claim. Raw/guard/XML evidence under evidence/012_inventory_profile_tests01_*; source hashes captured before running.
