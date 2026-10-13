# 012 schema5 live inventory contract

2026-10-08. Staged source candidate only. No engine, ENet, GUI, ordinary new5, Windows5, or playable-package acceptance is claimed here. Existing Core/owner/Frame commit semantics are unchanged.

## Selection and wire

The terrain server and terrain GUI client are different leaves. Both inherit the same reliable RPC declarations from `actor_network_main.gd`: `inventory_request012(request: Variant)` (any authenticated remote peer) and `inventory_reply012(reply: Variant)` (authority/server peer 1 only). Default virtual hooks refuse. Only the frozen schema5 server and explicit owned schema5 client implement them. Old4 reports, save bytes and close contract receive no inventory fields.

`InventoryLive.CONTRACT` is `sandbox012-inventory-live-v1`; schema_version is exact integer 1. Every request/reply binds world_id, server_epoch, player_profile_id, player_instance_id, peer_id and input_generation. The client adds confirmed input_generation to the actor producer's five-field identity; it does not invent a generation. The server resolves actual sender through its fixed confirmed roster, current Authority active profile, actor instance/generation and retained ENet/API connection incarnation. Supplied identity only validates that binding and never selects a different player. Context is checked again before dequeue. Reconnect creates a new owner; a closed client cannot reconfigure or retry its pending request.

A request contains the version/identity fields plus kind, request_id and context_epoch. Kind is exactly view, close or left. Left adds sequence, expected_revision and address; address has exactly container, owner and slot. Bag/hotbar addresses must name the authenticated profile. Chest addresses only identify a requested existing scope; they do not grant access. There is no grant, item state, arbitrary component, command selector or file path payload. Numeric fields are strict TYPE_INT; bools/floats are refused. Addresses have fixed capacities, identities/string domains are bounded, and each request is at most 2,048 serialized bytes before admission. The fixed global queue is at most 64 events / 131,072 bytes; each connection has at most eight controls and one unresolved left action. The constants are technical transport bounds, not gameplay values.

request_id is contiguous across all requests and independent of left sequence. A connection's left sequence begins at persisted private Core last_sequence and must be contiguous. A valid queued but rejected left action advances processed_sequence, never accepted_sequence or Core mutation revision. A successful action advances Core's actual accepted cursor/revision. Initial, issued, processed and accepted cursors stay separate. Controls never consume a left sequence. View_sequence independently increases for each private response.

Replies have exact version/identity fields plus kind, request_id, context_epoch, sequence (zero for controls), initial_sequence, processed_sequence, accepted_sequence, revision, ok, code, authoritative, durable and view. All replies are authoritative=true and durable=false. They are sent only with rpc_id to the captured authenticated peer. There is no broadcast inventory_component or other-player projection. The real client validates the entire bounded View, known item IDs, capacities, opaque stack state, same-revision immutability and monotonic view sequence before binding a Close checkpoint. The transport helper intentionally checks only envelope/cursor/view-header shape and imports only Authority, avoiding a Scope → Live → Core → Scope dependency cycle.

## Confirmed Frame placement

The fixed roster binds its private transport cursors during supported input activation, after the actual initial/join save and before welcome. Ordinary new5 remains empty. No fixture grant is installed.

`_advance_live_input_phase` first confirms the previous Actor Frame, then synchronously drains inventory FIFO, then performs auto/stop save or submits a new Actor Frame. Left calls only the frozen `_inventory_apply_confirmed_left(authenticated_profile, address, expected_revision, sequence)` seam. Private close revokes temporary view access but does not return carry, mutate a stack, or save. Every schema5 active save refuses an undrained queue; normal stop additionally requires frozen inventory admission. SourceLease, Frame and Store remain the sole combined-save lineage and writer/receipt authority.

## UI and stop

The schema5 leaf installs the actual Panel in its own CanvasLayer. I/personal open, Escape/close and slot clicks emit authenticated RPC requests. There is no local item mutation. The isolated Panel's default cached-open behavior remains available for its existing finite tests; runtime explicitly requires authenticated asynchronous open. Each pending open captures a context epoch. Toggle, Escape, context loss and F10 invalidate it. A late view may update a valid cache but cannot reopen an obsolete context. Singleflight and control-flight gates disable slot requests without consuming an unsent Panel left sequence. Teardown disables callbacks before context invalidation and rechecks terminal state after synchronous view callbacks.

F10 freezes new client inventory issue before stopping Actor input. Close binds the initial private checkpoint and every issue/ack; left pending_count is exactly issued_sequence minus processed_sequence and remains 0 or 1. F10 waits for every control reply as well as left and Actor drains before publishing a request. `configure_owned_inventory`, `bind_inventory_checkpoint`, `begin_stop_inventory`, and `poll_release_inventory` are supplied by the separately reviewed Close module. No timer retries a pending action.

## Coordinator API

Server `inventory_live_statistics()` is included only for schema5 as `inventory_live_runtime`:

- contract: `InventoryLive.CONTRACT`
- queue_empty: bool, covering all left and control events across streams
- queued_count: integer
- close_proofs: Array of per-peer proofs, bounded by `InventoryLive.MAX_PROOFS` (64); ordinary local ownership may require exactly one

`inventory_close_proof(peer_id)` derives the current actual private Core cursor/revision and rechecks current profile, actor, epoch, generation and connection. Its exact fields are:

ok; world_id; server_epoch; player_profile_id; player_instance_id; peer_id; input_generation; initial_sequence; cutoff_sequence; processed_sequence; accepted_sequence; revision; queue_empty; stopping.

All counts are integers in-memory. Running proof has stopping=false and cutoff_sequence=-1. Stopped proof has stopping=true and cutoff_sequence frozen to the last received left sequence. Queue empty means both material/control queues and all per-stream receive/processed counts are drained, not merely an empty Actor queue.

Use only these narrow static helper APIs:

1. `normalize_close_proof_json(value)` returns `{ok, proof}` after exact field, declared integer, finite/integral/range, identity and boolean checks. It is for JSON disk reports only. Never normalize RPC envelopes.
2. `validate_request_coverage(proof, request)` checks a running proof before writing server.stop. Identity/initial must match; processed and accepted may lag a recent client request, in which case return `{ok:false, pending:true, code:"INVENTORY_COVERAGE_PENDING"}` without extending the existing deadline. Any future processed/accepted cursor or malformed identity/type refuses. Success requires exact requested cutoff/processed/accepted, revision at least requested, zero requested pending and all controls/left drained.
3. `validate_close_proof(proof, request)` checks final stopping=true proof. Initial/cutoff/processed/accepted must exactly match the client request; processed must equal the frozen cutoff; revision must be at least requested; all queues must be empty. No future cursor is accepted as coverage.

The request's inventory fields are inventory_initial_sequence, inventory_cutoff_sequence, inventory_processed_sequence, inventory_accepted_sequence, inventory_revision and inventory_pending_count. Coordinator retains the existing Actor proof, actual child exit and lock-release checks. It separately reads the actual saved schema5 state's profile inventory last_sequence and global revision and places those in inventory_saved_accepted_sequence / inventory_saved_revision. A private RPC acknowledgement or these server transport proofs are not disk receipts. A failure after main commit retains the existing main-committed/backup-incomplete failure semantics and never replays inventory actions.

## Verification and remaining gates

`InventoryLive012Test.gd` contains 24 finite cases covering exact production helper queue/cursors plus real Core/View/Panel, old4/base refusal, stale rejection and accepted gaps, persisted initial cursor, replay/jump/bounds, sender epoch/incarnation/context change, private replies, control/global queue caps, no chest grant, close-cutoff/control races, stale-report coverage, strict JSON-vs-wire types, reconnect no replay, late-open cancellation, unknown-item/overflow refusal and teardown reentrancy. These method-level tests do not prove ENet routing, native Frame integration, real GUI event dispatch or actual save/reopen.

Read-only independent source review found a synchronous teardown callback defect; sticky teardown gating plus post-view terminal recheck fix it, with pending-open/chest regressions. Lightweight Python source checks found no duplicate functions, trailing whitespace, mismatched delimiters, missing dependencies or preload/extends cycles in the 69-script reachable overlay. These checks are not GDScript parsing or a test pass. Field-set constants are explicit typed Array literals to avoid the previously observed cross-script constant inference failure.

Await authorized finite import/test windows, old4 regression, real ENet peer-auth tests and actual native mouse fixture take/place/merge plus carry/slots save/reopen. Test items must come only from separately prepared isolated saved state. Q quantity, occupied-origin half-return, drop merge radius and disconnect carry disposition remain undecided and unimplemented. Windows5 remains explicitly refused until its separate generation-storage gate.

## Integrated source review, 2026-10-08 04:16 UTC

The Close/Live/coordinator overlay is now in the actual project, not merely external candidates. This is source integration only until new runtime evidence is recorded. Independent combined review found and corrected two blockers: the schema5 server summary now carries the actual Frame state_sha256 for independent saved-state inspection (old4 keeps exactly its three prior fields); all acquired-session fields reset before marker/profile rejection, so a rejected second attempt retires its own real Slots ticket.

A temporary development boundary keeps undecided carry-on-disconnect behavior out of normal new5 F10 acceptance: wait for any actual pending inventory reply, then require empty carry before beginning normal shutdown. Nonempty carry produces “请先放回手中物品再保存退出” and leaves authoritative items unchanged, with controls available to put the item back. Missing replies use the existing bounded close timeout, without retry or extending the deadline on repeated F10. This is not a final gameplay decision. Unexpected disconnect retains the existing last-complete-commit failure behavior; no automatic return/drop policy is installed.

Live now contains 27 finite cases; coordinator contains 9. New regressions cover actual schema5/old4 receipt summary shape, real Slots failure-ticket retirement without spawning, temporary carry gate and bounded pending wait. No engine pass is yet claimed.

Actual finite gates: Live27 passed2.534s/175136768B; Coordinator initial run kept red due solely to unindexed test-marker fixture colliding with real Slots missing-index check. After cleaning only its own test marker and guarding failed fixture setup, Coordinator9 passed2.086s/159584256B. All runs fully cleaned;98 current frozen source hashes unchanged. Native ENet/UI/save-reopen remains pending.

## Real ordinary empty-inventory gate, 2026-10-08 04:29 UTC

Inventory pair01 passed through native menu new5 creation, authenticated initial private view, native I open (40 empty bag plus10 empty hotbar), one native empty-slot click rejected authoritatively, Escape/F10, saved-menu return and native Exit. The real empty-slot request retired processed1 while accepted remained0/revision1, and normal F10 receipt independently proved actor cutoff4, inventory cutoff/processed1, saved accepted0/revision1, no pending/queues, main sequence3, observed server exit0 and released lock. Total121.859s/757346304B, guard green and complete cleanup. Empty-slot rejection is not successful item manipulation. There were no item grants or real resource acquisition.

Observer parse passed1.182s/135032832B. Current integrated owner case9 old4 exact save/reopen passed28.448s/399196160B. All receipts preserved. A full hash-verified15-file private ready3 checkpoint is retained locally outside the source archive; no owned locks remain. Ordinary Continue of this new5 slot and isolated real item take/place/merge/save/reopen are still pending. Windows5 still rejects pending generation registration.
