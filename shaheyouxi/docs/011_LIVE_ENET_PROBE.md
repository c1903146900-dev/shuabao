# 011 single remote client live-input probe

This is source for a bounded, test-only real ENet gate. It has not run merely
because source/mock checks pass. Product owner, Frame, protocol and default
activation behavior are unchanged. The runner owns admission, both recorded
Godot process groups, its own resource use, termination, reaping and evidence.

The two SceneTree scripts are `actor_live_enet_server_probe.gd` and
`actor_live_enet_client_probe.gd`. Each creates the exact production schema4
Owner, named `NetworkMain`, at the same RPC-relative path. Neither inherits an
owner, overrides RPC/disconnect/quit, or injects a positive server admission.

The server first writes an actual schema4 save containing one authenticated
underground inactive MEMBER, then starts the real server owner's restore path.
This seed is a technical fixture, not new-player surface spawning. It uses the
existing 147-cell support, with no new terrain or traversal certification. The
actual owner must report world generation/instantiation/random-seed and terrain
stage/materialization/generation counts of zero, and terrain restore count one.
The runner creates a fresh 0700 runtime root and applies umask077. Resume material
and full save files remain there and are not copied into logs or uploaded evidence.

The client resumes using that private identity and the exact retained display
name. Exercise/rename routes are disabled. After real remote join and its actual
save, the server explicitly activates the same Frame once and saves again. The
expected real sequence chain is seed 1, remote bootstrap 2, activation 3, normal
shutdown 4. A dedicated-server local producer call is rejected, and a direct
`actor_input` call outside RPC has sender zero and changes no queue or cursor.
Only the later remote client RPCs supply the positive queue evidence.

The client waits for the server's stage-1 activation rendezvous. This file does
not prove movement or F: those assertions use only its real validated network
snapshot cache and existing pending-input object. It sends exactly three intents
through the unchanged production producer: sequence 1 moves in positive X; after
confirmed displacement/cursor 1 with pending cleared, sequence 2 stops movement
and presses F, followed by sequence 3 releasing F. A newer actor revision,
destination layer, cursor 3 and empty pending queue must all arrive over ENet.
No failed F retry, client prediction or handcrafted server snapshot is permitted.
Both the client and saved-state checks compare the complete layer address,
including world, reference frame and body identity, rather than depth alone.

The server's physics/process signal observers read the actual bounded FIFO
before the child's physical callback. They record only sequence, movement/action,
numeric peer/generation/incarnation, actual-binding booleans and geometry bits.
The sequence-2 pre-transfer position must equal the client's final position and
the final actual save position. A missed queue observation is a failed probe,
not grounds to fabricate a receipt or call admission directly. Physics-frame
counters from different processes are not compared.
At activation the server also records its original two actor-body and two shape
RIDs without publishing their values. Once cursor 3 is public it passively checks
those exact bindings and both bodies' actual target spaces/transforms. The final
receipt exposes only the two resulting booleans.

Only after all client confirmation evidence is complete does the harness pause
that client's owner `_process`, write its existing stop file, and emit an armed
receipt while still connected. SceneTree multiplayer polling remains enabled.
The runner then requests server stop, waits for its actual exit 0, reaps its owned
group, and independently reads/validates the exact main save before writing
`client.finish`. The client must observe the real connection-lost flag and ENet
disconnected status as well as that release file before restoring `_process`.
The unchanged stop-file path then performs the client's normal exit. Until
arming, unexpected disconnect retains the original fatal handling. Arming does
not excuse server fatal/nonzero exit, corrupt disk state or missing cleanup.

Reports are restricted to the documented probe fields: stage/status, PID, counts,
public numeric binding/cursors/revisions, booleans, exact scalar geometry/time
bits and the main-file digest. Full owner reports, identity and saves remain
private runtime inputs. The server has a 35-second and client a 30-second internal
timeout; the runner supplies the separately approved outer bound and resource
profile. This single remote chain is not a multi-client, reconnect, late-join,
disconnect-lifecycle, long-running-server or moving/F performance benchmark.
