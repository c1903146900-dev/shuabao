# Schema5 inventory-aware local close contract

2026-10-08. Pure source candidate for the approved minimal real-entry integration. This file describes the contract and finite tests; it does not claim an engine run, actual F10, socket drain, disk receipt, or save/reopen acceptance. The initial candidate is staged outside the project until the parent releases the current source freeze.

## Scope and compatibility

`game/scripts/actor/actor_local_session_close.gd` remains a pure one-use state machine. It performs no filesystem, transport, queue processing, process termination, or save work. Scope, coordinator, client, owner, and Frame must integrate its explicit schema5 API separately.

Both existing schema4 contracts and their `configure` / `configure_owned` APIs remain unchanged. Their manifest, request, receipt, and `statistics()` shapes remain unchanged. The new fields are never appended to legacy output. Existing `begin_stop` and `poll_release` reject a configured schema5 instance rather than allowing actor-only shutdown proof.

The same actor identity binds inventory to the connection: world, server epoch, authenticated profile, actor instance, peer, and input generation. The profile marker hash binds the selected immutable slot profile. Its underlying canonical file bytes must be verified by the surrounding read-only scope; this pure class only validates and binds the exact lowercase SHA256.

## Exact schemas

Every listed schema is exact: omitted or additional keys reject. Counts are genuine `TYPE_INT`, bounded 0 through 9007199254740991. No float, boolean, string, negative, or unbounded counter is coerced. Identity-specific positive bounds still apply. Boolean flags are genuine `TYPE_BOOL`.

### Owned schema5 manifest

`configure_owned_inventory(manifest, directory_name, client_pid)` requires these 11 fields:

- `schema_version`: 1
- `contract`: `schema5_owned_local_session_v1`
- `session_id`: lowercase 32-digit hexadecimal; exactly `directory_name`
- `slot_id`: lowercase 32-digit hexadecimal
- `server_pid`: greater than 1 and different from client PID
- `owner_pid`: exactly client PID, greater than 1
- `owner_nonce`: lowercase 32-digit hexadecimal
- `server_epoch`: valid `session_` identifier
- `world_id`: valid `world_` identifier
- `save_schema`: 5
- `profile_marker_sha256`: lowercase 64-digit hexadecimal

This is `INVENTORY_OWNED_MANIFEST_FIELDS`. Neither process-birth ticks nor Linux group-reaping facts are invented for the owned-child contract. An instance may attempt configuration only once, including after malformed input.

### Actor checkpoint

The existing `ClientState.INPUT_CHECKPOINT_FIELDS` and identity validation are retained: `world_id`, `server_epoch`, `player_profile_id`, `player_instance_id`, `peer_id`, `input_generation`, `accepted_sequence`, `actor_revision`, `authority_revision`, `world_seconds`.

### Inventory checkpoint

`bind_inventory_checkpoint(cursor)` is a public, pure runtime method. Its exact `INVENTORY_CHECKPOINT_FIELDS` are:

- `world_id`, `server_epoch`, `player_profile_id`, `player_instance_id`, `peer_id`, `input_generation`: exact type and value of the bound actor identity
- `initial_sequence`: the saved Core accepted cursor at this connection's start; immutable
- `issued_sequence`: highest left-action transport sequence actually issued on this connection; the next issue must be this value plus one
- `processed_sequence`: highest contiguous left-action sequence acknowledged as processed by the authoritative server reply, including rejected actions
- `accepted_sequence`: Core's last accepted inventory action sequence
- `revision`: authoritative inventory component revision, independent of actor revision
- `pending_count`: exactly 0 or 1 for the single-flight panel

Always require `initial_sequence <= accepted_sequence <= processed_sequence <= issued_sequence` and `issued_sequence - processed_sequence == pending_count`.

The controller must first bind its actor checkpoint, then bind the inventory connection-start checkpoint with initial, issued, processed, and accepted all equal, and pending zero. It must call the inventory binder on every issue and every authoritative reply. Sampling only at F10 after several completed actions is invalid because it loses the per-issue proof.

An issue advances `issued_sequence` by exactly one from a previous pending-zero checkpoint. The new checkpoint has pending one, unchanged processed and accepted cursors. A reply advances processed to issued and retires pending to zero; accepted may remain behind processed if the action was rejected. A skipped combined issue/reply transition, second outstanding issue, jump, regression, changed initial cursor, or changed connection identity fails closed. An accepted-cursor change without a processed-cursor change also rejects. Repeated identical checkpoints are permitted.

Revision must be nondecreasing. If the accepted cursor advances, revision must strictly increase because a successful Core transaction increments revision. Other players' inventory/chest mutations can advance the global revision further, so it need not advance exactly one per local action. A rejected reply may retain both accepted cursor and revision. Issue, processed, and accepted counters cannot regress. Reconnection requires a new close-state instance, new binding, and clearing old pending/cache in the real controller; this contract never replays a command.

### Close request

`begin_stop_inventory(actor_cursor, actor_issued_cutoff, connected, inventory_cursor)` freezes two independent cutoffs: the explicit actor cutoff and the current inventory `issued_sequence`. Connected must be strictly true. The caller freezes further inventory issue before beginning close and stops actor sampling using the existing release mechanism.

`poll_release_inventory(actor_cursor, actor_pending_count, connected, actor_intent_count, inventory_cursor)` returns pending until both streams drain. Inventory issue after cutoff rejects. Actor acceptance beyond its frozen cutoff rejects. Actor pending must be zero, accepted must reach its own cutoff, and intent count must cover that cutoff. Inventory pending must be zero and processed must exactly equal its own cutoff. Inventory accepted need not equal issued or processed.

The exact request contains every owned schema5 manifest field above, these unchanged actor request fields:

`client_pid`, `peer_id`, `player_profile_id`, `player_instance_id`, `input_generation`, `accepted_sequence`, `actor_revision`, `cutoff_sequence`, `pending_count`, `intent_count`

and exactly these `INVENTORY_REQUEST_EXTRA_FIELDS`:

- `inventory_initial_sequence`
- `inventory_cutoff_sequence`
- `inventory_processed_sequence`
- `inventory_accepted_sequence`
- `inventory_revision`
- `inventory_pending_count`: 0

All request values are detached copies. Neither cutoff substitutes for the other. After request creation, inventory binding is frozen; only `mark_request_written()` arms the expected server disconnect.

### Final close receipt

`accept_receipt(value)` retains its common entry point but, for schema5, requires the complete schema5 receipt. The exact fields are every owned schema5 manifest field, these existing owned receipt fields:

`client_pid`, `peer_id`, `player_profile_id`, `player_instance_id`, `input_generation`, `cutoff_sequence`, `accepted_sequence`, `server_exit_code`, `writer_lock_released`, `main_committed`, `complete`, `main_sequence`, `main_sha256`, `reason`, `child_exit_observed`

and exactly these `INVENTORY_RECEIPT_EXTRA_FIELDS`:

- `inventory_initial_sequence`: equals frozen request's initial cursor
- `inventory_cutoff_sequence`: equals frozen inventory cutoff
- `inventory_processed_sequence`: exactly equals the cutoff; a larger value is a control-flow mismatch
- `inventory_saved_accepted_sequence`: the saved player's Core cursor inspected from the actual main save; equals the fully drained request's `inventory_accepted_sequence`, lies between initial and processed
- `inventory_saved_revision`: inventory component revision inspected from the actual main save; at least request's `inventory_revision`
- `inventory_queue_empty`: strictly true from the matching server queue proof

The manifest and actor connection identity must match exactly; actor accepted must equal the final request's accepted cursor. Existing receipt requirements remain: zero exit code, observed owned-child exit, released writer lock, committed main, complete save, positive bounded main sequence, canonical main SHA256, and `normal_shutdown` reason. Every success flag must be a strict true boolean. The receipt cannot be reused.

The actual coordinator must assemble this only from read-only inspection of the saved schema5 main bytes, the correct queue's initial/cutoff/processed proof, and actual server exit. It must verify the saved component belongs to the requested world/profile and that the server admitted no post-cutoff inventory work. Client request fields alone cannot establish any saved cursor, saved revision, queue drain, or durable success. A normal action acknowledgement remains authoritative in-memory confirmation and is never labeled durable.

Receipt and expected disconnect may arrive in either order. Both are required before `can_close()` and one successful `mark_closed()`. An unexpected disconnect, repeated stop/release/write/receipt/close, malformed data, or mismatch fails closed.

## Example: last action rejected

At connection start, saved accepted=40, so initial=issued=processed=accepted=40 and pending=0. Issue41 gives issued41, processed40, accepted40, pending1. Successful reply41 gives processed41, accepted41, pending0. Issue42 gives issued42, processed41, accepted41, pending1. F10 freezes inventory cutoff42 while actor cutoff can independently be3. Rejected reply42 gives processed42, accepted41, pending0. The request records those different cursors. A valid saved receipt reports inventory saved accepted41, processed42, cutoff42 and a saved revision covering the request; it must not claim accepted42 merely to reach the cutoff.

## Finite test coverage and remaining gate

`game/tests/inventory/InventoryClose012Test.gd` has 22 pure cases covering exact/canonical manifests, bounded integers and strict flags, initial binding, all identity fields, immutable initial cursor, issue jumps/skipped steps, single-flight conservation, regressions, accepted advance without a newer revision, independent global revision, both pending barriers, cleared pending without reply, separate cutoffs, late issue, actor-only schema5 rejection, exact detached requests, rejected-last success in both receipt/disconnect orders, wrong saved cursor/revision/cutoff/epoch/marker, repeated close operations, no-new-action close, and exact old4 launcher/owned request/receipt/statistics regressions.

These fixtures do not replace the existing schema4 close tests or demonstrate real networking, marker-file verification, actual save writes, process exit, or reopening. No engine or GUI has been run for this candidate; a separately approved finite resource window is required before execution. The actual integration must preserve Frame as sole Store writer and receipt authority.

For the first real-item fixture, place carried items back before closing. This is a test precondition only. This contract adds no carry-disposition choice and does not resolve the pending disconnect carry policy.
