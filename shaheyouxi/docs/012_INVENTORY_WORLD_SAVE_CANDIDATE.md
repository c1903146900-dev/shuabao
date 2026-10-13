# Explicit inventory/world save candidate

2026-10-08. Source-only candidate. No Godot execution in this task. Seven finite GdUnit methods are proposed, not reported as passing. Current schema4 owner, movement, F interaction, normal save/Continue and restore policy are unchanged.

## Contract

`inventory_world_session012.gd` wraps the actual ActorTerrainSessionState and InventoryCore012 services. Selection is explicit through its `make_store`; there is no automatic owner wiring. Schema5 adds exactly `inventory_contract` and `inventory_component` to the eight schema4 fields. Full validation precedes admission, with exact world identity, exact inventory/profile key sets and the existing actual world/actor/667-cell terrain checks. Missing inventory, unknown fields, wrong worlds, unknown items, capacity errors and internal/reserved duplicate instance/protected IDs fail closed. All existing state, carry origins, quantities, scalar bits and replay cursors survive unchanged. The contract cannot create profiles or grant items.

The actual bound server authority supplies catalogue content revision and network protocol metadata. The fixture constructs this authority with the actual loaded catalogue and network settings; no synthetic catalogue hash is used. The contract trusts the host's supplied approved authority service, like the existing owner factory.

Final admission uses SandboxSaveStore._encode itself, including its exact scalar codec and final JSON escaping, under the full 4 MiB budget. Its private sizing store carries no validator or I/O, avoiding validation recursion. The bounded Store subclass restricts main reasons to 1–64 ASCII identifier characters. A 64-character reason, manual kind, maximum sequence and maximum admitted manual slot are used for sizing. Integers have fixed-width exact-codec representations. Actual Store writes retain their independent final-byte check. Existing Store main/backup behavior and receipts are returned unchanged.

## Finite proposed engine gate

Run only `res://tests/inventory/InventoryWorldSave012Test.gd`, after independent source review and a root-approved resource window. Seven tests; one actual deterministic world generation is cached as exact codec bytes for the suite; all later owners remain detached from scene tree, GUI, network and physics runtime. Fixture files are confined to randomly named `user://inventory_world012/` directories with suite cleanup. Use the existing bounded inventory launcher pattern and root-approved time/RSS limits; do not run alongside loot's engine window.

1. Save and reopen actual files containing one actor, 667 terrain cells, bag quantity731 and a protected gun fixture held in carry at sequence19. Assert full exact state, rejected replay, no generation/materialization/random seed calls on restore and unchanged files after readback.
2. Ten invalid contract mutations fail before save, leaving actual main bytes, sequence and authoritative inventory untouched.
3. An actual schema4 file is refused by schema5 with no grant, migration or fallback.
4. Actual main temporary-path filesystem obstruction prevents commit and preserves old main/sequence.
5. Actual automatic-backup temporary-path obstruction occurs after main commit. Assert `MAIN_SAVED_BACKUP_FAILED`, `main_committed=true`, incremented sequence and reopened new state. No retry or transaction replay is attempted.
6. A Core-valid inventory is padded beyond the combined final envelope budget; combined admission and file save reject it while keeping old bytes/sequence. Invalid unbounded reason also rejects.
7. A checksum-correct schema5 main with invalid profile coverage is refused despite an older valid automatic backup; loading changes no file and never enables writing.

These tests are real-file finite fault cases, not a proof of power-loss durability, OS/filesystem guarantees, distributed atomicity or ordinary-play acceptance. Store success currently returns `ok=true`; backup failure explicitly returns `main_committed=true`. The current Frame's richer `complete` receipt is not installed here.

## Remaining integration gate

This is a persistence validation boundary, not a durable inventory-transaction coordinator. Core click publication is still in memory; no live owner, acknowledgement, authenticated inventory RPC, F/range access, visible bag, or durable action receipt is connected. Future integration must prepare a detached combined candidate, hold the corresponding world/actor/inventory boundary stable, durably save it and distinguish main committed from full backup completion before publishing/acknowledging; replay must never duplicate a committed action. Equipment/world-drop/recovery external ownership reservations still require a complete authoritative ledger when those systems exist. Existing terrain protected areas are spatial areas, not item protected IDs; this candidate does not invent a mapping.

All nonempty items and chest records in tests are explicit technical fixtures, never acquisition/runtime grants. The four unresolved Q quantity, right-click refilled-source handling, world-drop merge radius and disconnect-carry disposition remain unimplemented.

## Actual bounded verification, 2026-10-08 UTC

Seven distinct tests passed across two bounded runs. Run01 passed the first five assertions, then reached its 60-second resource deadline during test6 (59.556 seconds measured, 369332224 bytes peak, child terminated and fully cleaned). Its negative resource receipt is retained. Run02 excluded those five completed tests and passed only the remaining two: 24.492 seconds, 346419200 bytes peak, exit0, 0 errors/failures/skips/orphans, complete cleanup. This is seven individually covered cases, not one all-green batch. Evidence: `evidence/012_inventory_world_save_actual_result.json` and both raw/guard traces. Ordinary schema4 factory/entry remains unchanged; no migration or default schema switch is installed.
