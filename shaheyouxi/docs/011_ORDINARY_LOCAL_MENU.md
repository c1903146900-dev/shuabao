# 011 ordinary local menu candidate

This is unfinished source preparation for a Windows ZIP. No ordinary-menu,
Windows executable, new process lifecycle or export pass is claimed. The earlier
technical GUI new/reopen gates use their own launcher and remain separate.
Ordinary Windows explicitly configures the real SaveStore's generation backend
before acquire; failure is sticky and does not fall back to the previous layout.
The same generation helper publishes its control reports. Both integrations are
source candidates requiring their method/runtime gates. Linux is a development
step, not Windows acceptance.

The ordinary main scene is `actor_local_menu011.tscn`: New World, a local world
selection/Continue, and Exit. There is no user-entered report path, shell command
or Python launcher. The original explicit technical scenes remain available.
New worlds currently use the same approved seed-42 technical surface room. They
receive real fresh world/profile identities; no prebuilt save or test identity
is distributed. This does not open the unknown entrance approach or add terrain.

The GUI process contains the menu, one coordinator and the existing thin client.
It owns one exact headless schema4 server child spawned from the same executable.
The client keeps its actual sampler, RPC and scoped multiplayer; Frame is not
recreated or bypassed. An exact local coordinator instance can supply startup
arguments before the client enters the tree and receive its final quit callback.
Other entry points retain OS arguments, actual application quit and their 90s
technical timeout. Ordinary sessions have startup, close and local-owner
deadlines, with no total play-time cutoff.

Slots and private identities belong under `user://local_play011/slots/<id>`;
fresh session controls use `sessions/<nonce>`. Each role's report, stop, world,
identity and manifest arguments must match their exact derived destination.
Allowed-path membership alone cannot authorize swapping a report with identity.
The slot library holds its own exclusive lock across the GUI lifetime. A session
is marked incomplete before launch; unknown or stale Windows locks are not
silently removed. Failed/crashed sessions retain the last valid data and show an
incomplete state. Automatic recovery of those locks is not implemented here.

The ordinary close contract is distinct from the technical Linux launcher:
`schema4_owned_local_session_v1` binds slot/session, parent PID and nonce, actual
child PID, world and server epoch. It contains no fabricated Linux birth ticks,
PID namespace or process-group cleanup facts. After real sampler releases are
confirmed, the coordinator checks the server's confirmed cursor and requests its
normal stop. Only the original child's observed exit 0, complete save receipt,
real schema4/identity readback and released writer lock permit the client receipt.
Save sequence must progress from the actual slot value; it is not fixed to 4/7.
An existing dodge may keep moving before the final confirmed save.

The client still requires both disconnect and save acknowledgment before normal
cleanup. Returning to the menu waits for the old node and deferred scoped API to
be released. New/Continue is locked during startup/closure. A force-stop attempt
is made at most once and leaves the application blocked; it cannot be relabeled
as a normal exit or followed by another signal to a possibly reused PID.

The local-owner watchdog checks session/slot/nonce and strictly advancing
counters using the server's own monotonic receive time. Ordinary Windows writes
each counter to a new unique filename, reads it back, and retains two completed
entries (temporarily three during publish/prune); incomplete temporaries do not
renew liveness. Missing new publication waits only to the existing local deadline.
Invalid, regressing or expired evidence closes input/publication/save gates.
Counter I/O is polled at the configured 0.5s interval, with a fresh check before
saving. The versioned `local_session_settings011.json` values are technical
engineering limits, not quotations or replacements for gameplay source tables.
These are process-interruption consistency claims to test, not fsync/power-loss
durability promises.

`ActorOrdinarySessionTest.gd` has eight method tests for role/path isolation,
ordinary close scope, actual-child proof fields, arbitrary legal save sequences,
typed report rejection, exact coordinator injection, legacy defaults, local
counter expiry/publication, pre-tick/pre-save failure and a single sticky forced
signal. They use explicit process/report/transport mocks and isolated test files;
they do not spawn a server or prove real Windows behavior. Slot storage has a
separate eight-method suite. Real Linux menu new/continue/close, repeated sessions,
interruption handling and Windows export/runtime gates remain to be performed.

Godot references: [child process API](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-get-process-exit-code),
[Windows child-handle implementation](https://github.com/godotengine/godot/blob/4.6-stable/platform/windows/os_windows.cpp),
and [Windows rename implementation](https://github.com/godotengine/godot/blob/4.6-stable/drivers/windows/dir_access_windows.cpp).

## Mutable-file audit for the ordinary entry

- World main/automatic/manual logical records and slot index: real server/slot
  services write on save or metadata changes. Windows uses complete immutable
  generations; Linux retains its existing storage behavior
- Library/session/writer lock owners, world identity and private resume identity:
  written once inside a newly owned directory/path; unknown records are never
  overwritten, and only the recorded owner releases a lock
- Session manifest, client close request, server stop and server close receipt:
  published once to fixed roles in a fresh session; they contain no user-selected
  destination or network stop permission
- Owner liveness: the GUI publishes a new counter every 0.5s; Windows keeps two
  completed unique counter files, Linux uses its prior replacement mechanism
- Windows server control reports: the same generation helper writes only startup,
  a close cursor after the real request is physically covered, and terminal state.
  The close stage is not published on an uncovered cursor. The coordinator waits
  for the matching complete stage and still performs its full cursor/disk checks.
  This exact report kind retains all three records, with a hard three-record
  bound and no retirement within a session; save/index records still retain two
- Ordinary client reports, close-status files and presentation traces have no
  file consumer, so they remain in their existing live client objects. Their
  technical-launcher file behavior is unchanged
- Local abort is published on the first failure only. Subsequent callbacks retain
  the first cause instead of repeatedly replacing the abort file
- Godot/server logs are diagnostic streams. They authorize no save/close result
  and are not included with a user's world or identity in a distribution

The Windows control reader accepts only complete valid generation records. It
waits through initial layout publication or an older startup stage within the
existing deadline. Reports never replace full SaveStore validation as save
proof. The three causally ordered report publications also avoid continuous
Windows report replacement while a coordinator reads the previous report.
