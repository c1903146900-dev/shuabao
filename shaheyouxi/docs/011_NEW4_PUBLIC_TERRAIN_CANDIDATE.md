# New4 public terrain candidate, 2026-10-07 23:14 UTC

Restored baseline010 v9 and cumulative011 v241 after environment replacement. All 4,900 baseline and 1,256 increment file hashes passed. The later previously described boundary/display implementation was not in the latest retained increment and is not claimed recovered.

## Added source-only slice
- ActorTerrainPublicProjection validates through actual CombinedStore, projects existing cells and actual H1, preserves effective prefab H0 and source liquid type, and binds world/contract/artifact plus public payload digest.
- ActorTerrainClientState is explicit composition around the unmodified old3 exact parser. It validates bounded new4 public rows before stripping the extension for legacy validation, rejects duplicate cells and immutable terrain changes, and publishes detached cache copies.
- Five GdUnit cases cover 667 cells, 221 surface prefab identities, source/hash/world tampering, detachment, layer/camera filtering and unknown-space emptiness. These are test SOURCE, not executed results.

No Godot, Blender, native runtime, GUI, export or heavy tests started. git diff --check and new-file whitespace checks passed; there is no GDScript parse or runtime pass yet.

## Remaining integration and verification
This adapter is deliberately NOT wired into the server/client owner or default menu yet. Public row hashes detect corruption and bind a received snapshot; they do not authenticate a malicious server or certify movement clearance. The public projection must be built once per initial static artifact, not revalidated and copied on each physics tick. The network must select new4 explicitly. Client PlayView must draw the effective ground then actual H1, preserving actor order; no duplicate prefab H0 drawing. Old3 must continue rejecting extra fields. Boundary rejection and authority-confirmed user feedback remain pending. Full new4 movement/F, save-return-menu/same-save Continue, cold import, resource gates and re-export are all open. Earlier technical Windows package predates these changes and has no Windows-native validation.


## 2026-10-07 23:25 UTC update
Two source-review gaps were corrected before integration: first-snapshot world-component hash/layer/full-H1/prefab-H0 cross-binding and complete-envelope cache-atomicity tests. Static subsequent packets lock both terrain and world-component identity, without repeating terrain hashes or retained deep copies. The old3 exact parser bytes remain unchanged.

Source integration now selects a distinct sandbox011-new4-public-terrain-v1 handshake, constructs the owner projection once on create/restore, and uses an explicit terrain client/view. Default old3 factories retain their prior behavior. New4 renders actual H0 then actual H1 then actors; actual cell bounds can establish display coordinates on natural layers without prefab regions but cannot manufacture rows or support clearance. Network world-view callbacks no longer call snapshot() to copy terrain just to retrieve the world component. The new4 launcher has 20 passing pure Python checks.

Cold import01 had a clean resource/cleanup result, 5.144 seconds and 795,656,192 bytes peak, but a real parse failure: Projection collided with the Godot builtin type. That original failure is preserved. Renaming the constants to TerrainProjection resolved the tested dependency parse.

The actual public terrain suite then passed 11/11 with zero errors, failures, flaky, skipped or orphan counts; no script errors in the log. Resource supervision passed in 43.726 seconds at 193,204,224 bytes peak; all owned children and original groups cleared. Source hashes, original logs, sampled resources and XML are included. This does not independently parse or run all owner integration scripts or validate ordinary GUI, movement/F, complete save-return-menu/Continue, Windows or full game.

Next reserved runtime goal is actual ordinary New/Continue and movement/F/save flow. Boundary coverage rejection still follows the earlier fatal solver path and needs a deliberate authority-confirmed nonfatal policy; no synthetic walls or false terrain clearance were added.
