# 012 exact owner / confirmed save integration

2026-10-08. Source integration only. No engine, UI, ENet, ordinary slot, Windows, or playable-package acceptance is claimed by this document.

## Scope and selection

- The actual `actor_terrain_network_main.gd` script remains the owner. There is no replacement owner subclass or weakening of SourceLease's exact owner/script checks.
- `--save_profile=4` or an absent argument freezes old4. Exactly `--save_profile=5` freezes new5. Other strings and non-string selectors reject. Later argument changes cannot change the frozen profile; changing the active profile field violates its read-only binding.
- The profile5 factory creates the exact closed registry, actual-authority cold validator, and bounded schema5 Store. It never manufactures an Authority with a matching saved world ID. The ordinary scope independently checks its strict profile arguments and immutable slot marker; its heartbeat refuses a changed marker/profile.
- Windows5 explicitly rejects at selection and in the registry until its separately reviewed generation-storage registration/failure matrix exists. No unsafe rename fallback is selected.
- The agreed narrow base startup change checks a null factory result before `acquire()`. A rejected factory opens no lock, creates no target directory, and does not fabricate a Store or overload Windows generation errors.

## Initialization and restore ordering

1. For a genuine new5 world, create and validate the existing world/actor/terrain components. Only then create the private InventoryOwner, initialized from a completely empty Core. No starting items are granted.
2. On restore, validate the entire schema5 envelope through the cold validator before any world, actor, authority, or inventory restore. The validator derives its temporary Core world binding from the candidate while retaining the actual catalogue/protocol configuration.
3. Restore the ordinary validated terrain/world/actor/authority path, then initialize InventoryOwner from that full validated state. The restored authority adopts the saved world ID before private-owner construction.
4. A newly confirmed Authority join supplies the trusted `is_new` flag to Frame. Only a true new profile creates an empty bag, before the same join save. A resume uses complete combined validation and never creates a replacement inventory.

## Confirmed boundaries and persistence

- Frame binds the original profile, registry, cold-validator instance, registry descriptor, and private InventoryOwner instance when it prepares the original SourceLease. The owner's own read-only binding also retains the exact private service/registry references.
- Frame retains the exact `InventoryOwner.boundary_token()` alongside its actor lineage. Pending initial, actor, and presence boundaries cannot apply inventory commands. An unapproved service replacement or inventory mutation invalidates publication/save; the source lease is not reconstructed.
- `_inventory_apply_confirmed_left(authenticated_profile, address, expected_revision, sequence)` is the small server-only owner seam. It requires a ready exact owner and Frame, then applies against the confirmed Frame actor/authority base combined with the actual terrain. The profile must currently be active. The later queue remains responsible for authenticated peer/epoch/incarnation, receive cursor, ordering, and cutoffs.
- Valid actions update the private in-memory state and confirmed inventory token atomically after final combined-envelope budget validation. Their acknowledgement remains `authoritative=true, durable=false`; a click does not write a file. A rejected action cannot change the token. Actor/source postconditions must still match exactly.
- Frame remains the only actual owner Store writer and receipt authority. Initial, join, automatic, and normal-shutdown writes append inventory/carry/origin/revision/cursor to the same whole-state envelope. The old4 branch still requires its exact base Store, terrain validator, schema4, exact codec, byte limit, catalogue, protocol, target, counts, and interval.
- Profile5 admits only registry-verified exact Store/validator/configuration. Pre/post checks retain the original service references and exact inventory token together with actor lineage, Store configuration, instance, world binding, writer lock token/readiness, sequence, and slot expectations.
- `main_committed=false` failure leaves the previous durable file/sequence/deadline intact. `MAIN_SAVED_BACKUP_FAILED` preserves the genuinely committed main and its sequence/deadline, returns an incomplete receipt, and remains fatal. Neither case replays inventory actions or pretends a backup completed.
- Public actor/terrain snapshots, broadcast paths, and reports never include the private inventory component. Private per-player views and RPC/epoch envelopes belong to the subsequent module.

## Finite test sources

`game/tests/inventory/InventoryOwnerSaveIntegration012Test.gd` adds ten independently selectable cases:

1. Real new5 creation, initial save, confirmed new-profile join, and saved empty bag/carry/cursor.
2. Isolated item fixture, confirmed non-durable place/take actions, saved exact carry/opaque protected state/cursor, fresh random-authority schema5 cold load, and restoration without regeneration.
3. Missing resumed inventory fails before any restore or replacement bag.
4. Pending Frame refuses inventory application; confirmed action works; replay refuses without disk I/O.
5. Actual Store main-temp obstruction leaves previous inventory bytes/sequence/deadline and shuts Frame publication.
6. Actual automatic-backup-temp obstruction retains committed main, expected inventory/deadline, incomplete receipt, exact cold readback, and no replay.
7. Equivalent replacement InventoryOwner is rejected before first save.
8. Trusted-side out-of-boundary inventory mutation is rejected before save.
9. Default exact old4 restore/initial/join saves and fresh reopen remain inventory-free.
10. Invalid selectors return a null factory without target I/O; profile freezing and explicit Windows5 refusal remain closed.

Tests use the exact production owner outside the SceneTree and actual native Frame/Space setup; no positive owner/Store subclasses or fake receipts are used. The only fixture items are supplied by the existing isolated schema5 test fixture. Test cases should be selected into the approved bounded engine windows rather than assuming the full suite fits one 60-second process.

## Remaining gates

- Static independent review and approved bounded import/test runs, including old4 regression suites.
- Authenticated inventory receive queue, epoch/incarnation and reconnect behavior, private views, and inventory-aware close/drain cutoffs.
- Ordinary new5 slot/menu/client integration and real mouse fixture proof.
- Windows5 generation storage and failure matrix; final Windows playable packaging.
- No decision is supplied for Q quantity, occupied-origin half-return, world-drop merge radius, or disconnect carry disposition.

## Source review result

Independent read-only review of the scoped owner/Frame/factory change and ten new tests found no blocking defect. Lightweight source checks found no duplicate function names, trailing whitespace, unbalanced delimiters/strings, missing script dependencies, or preload/extends cycles (60-file graph). These checks are not GDScript parsing or runtime acceptance.

The pending-action test explicitly covers a pending bootstrap presence; a sealed actor-submit action rejection remains an additional regression case. Automatic-save success is source-reviewed; the current explicit automatic runtime cases intentionally exercise main and backup failures. Run/record the successful automatic path in the later finite regression gate as well.

## Actual first two single-case gates

2026-10-08: new5 initial+confirmed join empty-inventory save passed23.598s/382029824B. Fixture non-durable place/take then complete carry/unique-ID/cursor save and fresh random-Authority cold reopen passed52.260s/408576000B. Each1/1, zero errors/failures/skips/orphans, exit0/full cleanup. All60 frozen source hashes remained unchanged. The other8 authored methods remain unrun; no ENet, ordinary menu or native GUI proof is claimed. Evidence012_inventory_owner_save_initial_actual_result.json.
