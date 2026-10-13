# 011 schema4 local technical GUI entry

Status: source/method-test candidate. The real GUI acceptance, F10 save and
separate reopen remain later resource-gated runs. Headless ENet passes and mock
close tests are not evidence of real keyboard, pointer, focus, resize or rendering.

The new scene is `res://scenes/actor_terrain_play_client011.tscn`. Its thin
`actor_terrain_play_client.gd` inherits the existing play client, preserving the
actual WASD/Shift/F sampler, pointer-at-F-edge behavior, production intent/RPC
producer, validated snapshot consumer, camera, geometry proxy and local hints.
No copy of the play implementation or predictive actor simulation is added.
The existing schema3 scene remains available and unchanged.

The shared network client is a wire-v2 reader/producer, not a schema3 save writer.
The new entry expects the exact schema4 server scene, selected and owned by its
local launcher. The local manifest binds that server's actual session/world and
recorded process identity before gameplay input is enabled. The GUI report's
schema4 label is that selected server contract; the client opens no SaveStore.
Window labeling explicitly identifies a new4 technical surface session. It uses
the existing source-bound room and does not enable the unknown approach to the
natural surface entrance or introduce final art or formal-world certification.

## Local session authority

The launcher creates a fresh private 0700 run directory named
`actor011_terrain_play_<32 lowercase hex digits>` under the project runtime and
uses umask077. It owns exactly the headless server and GUI processes it starts.
The GUI receives `--local_session=<run>/local_session.json`, with its report and
stop paths fixed to `<run>/client_owner.json` and `<run>/client.stop`. Other
control filenames are derived from that same directory; no manifest/request can
supply a server path, arbitrary target process or alternate receipt destination.

The manifest has exactly eight fields: schema_version 1, the
`schema4_local_gui_session_v1` contract, session_id, server_pid,
server_start_ticks, server_epoch, world_id and save_schema 4. The launcher obtains
the PID/start identity and live epoch/world from its actual server. The GUI checks
the manifest against its real validated input checkpoint, then retains the
profile/actor/peer/input-generation binding for this single connection. JSON
integer slots are canonicalized explicitly after finite/integral/range checks;
bools, fractional values and arbitrary fields are not silently normalized away.

The ordinary client report now retains `actor_schema4_initial_checkpoint` from
the first validated RPC snapshot whose real pending cursor passes that manifest
binding. It is captured before the shared view/sampler consumes the snapshot,
without waiting for another frame or changing input. Its exact 12 public fields
are world_id, server_epoch, player_profile_id, player_instance_id, peer_id,
input_generation, accepted_sequence, actor_revision, authority_revision, full
layer, position_bits_le (two binary64 little-endian hex strings), and
clock_bits_le. The stored copy and its nested containers are read-only; report
readers receive a deep copy, and subsequent snapshots never replace it. It has
no credentials or private actor resources. Until a successful binding it is an
empty dictionary. A separate same-save reopen verifier can compare this witness
with the previous exact save; this addition does not establish a real GUI pass,
and the first received clock may have advanced since the server restored it.

This local process/file capability grants no MEMBER network permission to stop
another server. No new RPC, client-selected authority flag or general disconnect
transaction is added. Private control requests/results remain in the private run
directory. Evidence can retain the small status and verified facts, never resume
secrets, the identity file, or an unrestricted copy of private request contents.

## F10 and window close

F10 is consumed in `_unhandled_key_input`, which the engine dispatches before
`_unhandled_input`. The inherited world key callback therefore cannot set the
legacy stop flag first. Echo and release are consumed without starting another
close; other keys retain their inherited handling. Window close calls the shared
`_request_user_close` virtual hook, whose default keeps the original stop flag
behavior and whose new4 override enters the same local close state machine.
The Play notification handler no longer explicitly calls `super`: Godot already
dispatches `_notification` to every script in the inheritance chain. This avoids
duplicating the ancestor window close request while preserving focus handling.
See the official [input event order](https://docs.godotengine.org/en/4.6/tutorials/inputs/inputevent.html#how-does-it-work)
and [notification dispatch contract](https://docs.godotengine.org/en/4.6/classes/class_object.html#class-object-private-method-notification).

After either close request, the existing
sampler is disabled and emits its normal zero-movement plus held-action releases
through the real producer. Only after those synchronous sends does the client
capture its actual last-issued sequence as a fixed cutoff. New key, pointer and
focus-reentry intents are suppressed, while normal `_process`, snapshots and
SceneTree network polling continue. No probe-style process pause is used.

The pure `actor_local_session_close.gd` state machine requires the same complete
input binding, a received cursor covering that cutoff, an empty pending buffer
and a still-connected transport before producing the local close request. Merely
closing/clearing the pending object on disconnect cannot satisfy this condition.
Before an effective initial checkpoint, F10/close explicitly fails the technical
session; it does not claim a successful normal save or invent an empty receipt.

The request has the manifest fields plus client_pid, peer/profile/actor identity,
input_generation, accepted_sequence, actor_revision, cutoff_sequence,
pending_count 0 and intent_count. The launcher verifies it against its actual
owned GUI process, server session and public actor binding, then requests the
server's existing normal stop. The server retains its established queue cutoff,
physical confirmation and exact save behavior.

Only after actual server exit 0, reaping/group cleanup, schema4 normal-shutdown
main-file verification and writer-lock release does the launcher write the
24-field receipt. It binds the same session/process/input identity and cutoff,
reports the actual main sequence/hash and requires complete/main_committed plus
the actual cleanup facts. A partial main/backup outcome is not complete success.

The GUI may observe the expected server-disconnected signal before or after that
receipt. Both are required before it sets its original client stop flag and exits
normally. An unrequested disconnect keeps the inherited fatal behavior. A finite
15-second close deadline fails rather than fabricating successful persistence.
The final close-status file is only an auxiliary witness; the launcher must also
verify the GUI's actual exit and owned process cleanup.

Zero/release does not cancel an already-started dodge or rewind authoritative
time/resources. The server may legitimately move further while the local stop
request travels. Its last confirmed exact save is authoritative; no assertion
requires that final position to equal an earlier GUI close checkpoint.

## Source-only method gate

`ActorLocalSessionCloseTest.gd` contains eight methods for exact local scope and
JSON types, stream binding, cutoff/pending confirmation, disconnect invalidation,
receipt failure facts, both receipt/disconnect orders, shared sampler cleanup
and focus/pointer suppression, and early/unarmed failure behavior. Its explicitly
mocked transport/filesystem/quit seams do not claim real ENet or GUI evidence.
The existing binding method also checks initial-capture ordering, rejected
bindings, unchanged input/cursor/sampler state, exact binary64 fixtures, detached
report copies and preservation across later snapshots; the count remains eight.
The sampler, view and camera remain shared with PlayClient. Its notification
handler now omits the duplicate `super` call, and the base network owner routes
window close through the default-compatible virtual hook described above. The
native actor owner and save schema are unchanged by these close-dispatch fixes.
The separate launcher has its own approved GUI resource profile;
the prior headless-only RSS allowance must not be applied to a rendered client.

`ActorUserCloseDispatchTest.gd` adds three separate methods using real
`SubViewport.push_input` event propagation and `Object.notification` dispatch.
They cover F10 before the legacy key handler, press/release/echo and repeated
close requests, exactly one inherited window notification per request, unchanged
non-close keys/focus, legacy default stop behavior, and the new4 process waiting
for release confirmation plus both save receipt and disconnect before cleanup.
The tests mock transport, local control I/O and final quit; their receipts are
explicit test values, not real save or OS-window evidence. The original eight
state/adapter methods remain separate and unchanged.

The real GUI run `011_terrain_play_20261007T072819055181Z` remains a failed
record: movement was observed, but F10 reached the ancestor key handler first
and the client disconnected while its local close state still said `draining`.
The later server disconnect failure does not establish a successful shutdown
save. The separate window-notification defect was found by reading the engine
contract and source; that failed run did not exercise window close. These fixes
require new headless dispatch and real GUI gates before claiming either path.
