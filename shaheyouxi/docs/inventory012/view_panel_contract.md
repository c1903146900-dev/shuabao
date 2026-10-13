# Inventory 012 technical panel

Status: isolated source implementation. No runtime scene, main menu, ordinary F interaction, RPC, or schema4 integration. Engine/GUI acceptance is separate. No final art or item grants.

## Source checks

Read from the locked originals for this implementation:
- cehua.docx P129: independent 40 bag and 10 hotbar slots (the accessory expansion is outside the existing bounded core).
- P130–131: existing equipment roles; one 30-slot chest.
- P132: single authoritative carry; left-click lift/merge/swap remain server transactions.
- P133–134: centered personal composition; character preview and existing equipment positions are honest unavailable-interface placeholders. Chest sits beside bag with personal crafting hidden. Hotbar layer is above mask; resource-interface placeholder sits directly above hotbar. Whole context closes on close/Esc or explicit context loss without restoring carry.
- P136: padded tooltip shows current supplied instance data. Canonical item descriptions, firearm magazine field names, resource bars and final equipment/crafting interfaces have not been supplied to this component. It does not guess these. Thus this is not full P136/UI acceptance.
- sucai.xlsx / 全部素材技术清单 rows 1650 and 1671: wood `tubiao_mucai` / `mucai`, stone `tubiao_shitou` / `shitou`. Text names are technical placeholders, not final icon assets.

## View boundary

`inventory_view012.gd` is a read-only RefCounted cache. Construct with an independently established expected world and authenticated local profile. The untrusted view must contain exactly:

schema_version (integer 1), contract (`sandbox012-inventory-view-v1`), world_id, profile_id, view_sequence, revision, inventory, chests.

`server_view(core, authenticated_profile, view_sequence)` is a server-side envelope adapter around the existing `core.view`. It never creates an inventory or changes an item. The future authenticated bridge supplies a monotonically increasing view_sequence for each bound presentation session. This sequence differs from transaction revision because chest-access revocations do not increment the current core's inventory revision. The adapter must never be used to stamp client-provided inventory payloads.

`accept` validates all fields, exact integer types, world/profile, 40/10/30 capacities, pinned item rules, quantity bounds, instance uniqueness, origin, scalar tree and encoded size budget before replacing the whole cache. View sequence must increase; inventory revision and last_sequence may not regress. Equal revision allows access membership changes but rejects changed player or previously observed chest contents within that revision (bounded fingerprints survive revoke/regrant). Dictionary key order does not count as a state mutation. `snapshot()` is detached. Closed chest origins are legal carried-item history, not permission to address that chest.

The parser is not authentication, authorization, a transport decoder, or proof of range. The bridge must authenticate sender, verify current chest scope and supply new views. On disconnect/context invalidation, it should immediately call the presentation's context_lost for a derived chest context; carry disposition on disconnect remains unresolved and unimplemented.

## Control API

`inventory_panel012.gd` can be instantiated as a Control, then bind_identity(world_id, profile_id) once. A new identity needs a new component, preventing old cache reuse. `apply_server_view(view)` validates and atomically repaints; `cached_view()` returns a detached copy. `open_personal()`, `open_chest(id)`, `close_panel(reason)` and `context_lost()` change presentation only.

Signals:
- left_intent(address, expected_revision, sequence). Address has exactly container, owner, slot. Counts/items/results are never emitted. Sequence is a bounded local request counter, never a local item transaction. At most one request is pending. A valid view whose last_sequence acknowledges it clears the gate; an explicit authenticated server rejection can call reject_left_intent(sequence). Timers and unrelated views cannot release it. The server still owns acceptance and state.
- close_intent(reason, expected_revision), once per actual presentation close.
- open_intent(), when I/open is requested before a server view is available.
- view_rejected(code), with cache unchanged.

I toggles personal presentation; Esc closes the whole current presentation. No input-map edits, movement restrictions or pause semantics are introduced. Chest opening requires grant_chest_context(chest_id, requested_epoch) followed by open_chest. The bridge must echo the context_epoch captured when the grant request was sent. Close/context loss increments the epoch and clears the grant; delayed pre-close grants are rejected even when an in-flight view has a larger view_sequence. Switching chest to personal also closes and revokes the derived context. Switching to another chest requires closing the existing chest first; grants cannot silently replace an active different chest. A view revoking an unopened grant also invalidates its epoch. A newly authenticated post-close grant is required. Ordinary close preserves carry exactly; the technical carry label continues to follow the mouse while carry exists in server state. No right-click, Q, drop, outside-click action, or disconnect disposition is implemented.

`build_controls()` is idempotent and normally called from _ready. It is exposed for finite headless structural tests. The interface is a desktop technical layout, not visually accepted final UI. Native tooltip containers provide 24-pixel top/bottom margins and minimum height 132. Opaque instance JSON may be visibly truncated at 1800 characters, clearly labelled, without changing cached data.

## Finite verification source

`game/tests/inventory/InventoryPanel012Test.gd` contains 36 isolated tests: contracts, fields/types, bounds, whole-view atomicity, binding, instances, detachment, stale/state checks, access-only views, intent shape, preserved carry, scope closure/reopen prevention, structural layout, padded tooltips, key-order invariance, sequence ceiling, single pending intent acknowledgement/rejection, delayed pre-close grants, same-revision chest revoke/regrant, chest-to-personal scope invalidation, unopened-grant revocation, and visible pending-button gating. These use controlled fixtures only. Engine execution and visual interaction require the root resource window; no engine result is implied by test source.

## Actual finite gate, 2026-10-08 UTC

36/36 headless method-level UI tests passed, 0 errors/failures/skips/orphans. Guard: 2.085 seconds, 128344064 bytes peak, exit0 and complete cleanup. Initial two discovery failures from a test constant alias shadowing native Panel are retained; final alias InventoryPanel is tested. Core18 also passed separately in the same sequential resource window. This does not prove native key/mouse handling, visual layout or actual authenticated RPC; ordinary gameplay is still not wired. See evidence/012_inventory_ui_and_core_actual_result.json.
