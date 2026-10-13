# 011 standalone natural-entry active-transfer candidate

Status: **development_unreleased, source authored, engine tests unrun**. This
candidate follows schema4's accepted twelve-method real-file gate and ten-method
finite native-support gate. It does not wire F into Controller or NetworkOwner,
change a save/wire schema, generate terrain, open a tunnel or authorize a formal
world. The existing live selector still reports transfer unsupported.

## Original source and explicit engineering choices

Source references use top-level body paragraph numbering in the locked cehua.docx.
P56 gives shared layer XY coordinates. P68 requires same-XY paired natural entries,
bidirectional active interaction; P69 protects initial surrounds, without asserting
future dynamic vacancy; P65 does not guarantee cave connectivity. P68–70 and
38_层间连接!O6:P7 supply the existing natural connection layout and 3×3 entry /
7×7 protected dimensions.

P86, 63_移动能量!A11:F11 and 137_快捷键!A9:C9 require pointing at the same-layer
object and being within the supplied 1.5-cell F range. Actor diameter comes from
63_移动能量!A10:F10 = 0.65. Neither those F rules nor 64_伤害控制!G8:G10/G23 impose a
stationary, ordinary-moving, dodging or controlled-player ban on F. This candidate
adds none. Existing actor admission still rejects dead-player interaction.

The exact off-center actor world XY is preserved in the paired destination layer.
This is an **approved conservative engineering choice**, not an original quotation
specifying subcell landing behavior. The existing selector's cell-center distance
anchor is likewise an explicit coordinate-mapping choice; its pointed hit target
is the actual 3×3 generated body, not its 7×7 protected surround. A blocked or
unknown full destination body rejects. There is no center snap, nearest search,
resource/cooldown/action reset or implicit fallback re-anchoring. Artificial
22_垂直交通!F5/D17 nearest-landing rules are not imported into natural entries.
The prior source-backed fallback/parent handling remains unchanged: the retained
fallback is not rewritten merely because the active actor changes layer.

P112 and 70_机械召唤!B12:E12/B18:E18 require ordinary summons to accompany the player
across layers and fixed beacons to disappear when their owner leaves. Summons and
beacons are not implemented here. They are a required later formal-migration
integration, not certified by an actor-only transaction or the static artifact.

## Standalone interface and proof boundaries

`ActorNaturalTransfer.prepare(actor_id, admission, cursor)` accepts only trusted
server-side values: the immediate Motion.accept_input result for a fresh requested
interaction and its exact input_generation/accepted_sequence cursor. It is not a
client RPC or a replacement for authenticated dispatch. Motion also retains a
one-use internal proof of the actual F admission, bound to actor revision, input
identity, generation, sequence and exact result. Later input or model mutation
invalidates it; an old F result paired with a newer same-aim cursor is rejected.
No wire field or accept_input return shape changes. Each admitted cursor can
be attempted once; duplicate/held/released inputs cannot create a candidate.
A failed or pending attempt never caches the edge for a later frame. The already
committed input cursor, held edge and normal input revision remain committed.
A return transfer requires release plus a fresh pressed edge.

The coordinator checks combined authority/world/model validity, equal authority
and model clocks, the complete active actor sets, every model/native layer and
position binding, current actual body spaces/transforms, and the actual Store
artifact against published native bounds. It runs the existing selector over the
validated current world. The selected connection, direction, source and destination
full identities, source XY, model/public/authority context, input cursor, terrain
fingerprint and model/native generation tickets are frozen. Validation repeats
those read sets, source selection and complete destination circle/environment/peer
checks immediately before any write. Model tickets additionally retain the same
InputState identity, sequence, aim, held state and input generation.

Motion's dedicated active-layer preparation reserves the single required revision.
Commit changes only the record layer and the normal monotonic actor revision; it
never deactivates/reactivates, replaces the InputState, settles resources or resets
cooldown/deadline/dodge/fallback fields. Movement preview, presence and transfer
plans invalidate on ordinary model mutation. A newer admitted input invalidates
an older transfer ticket and cannot be overwritten by it.

ActorSpace reserves generations for preparation, submission and a possible
pre-model rollback. It validates both actual source RIDs, their original single
circle/square shapes, complete destination map-circle/known-region/environment
clearance, and currently registered destination-layer peer AABBs. It rebinds exactly
the two existing body RIDs to the destination space, retaining all shape/body
identities and XY transforms. It allocates/removes no actor bodies. Layer-key
bookkeeping alone is insufficient: body_get_space and body_get_state are checked
for both RIDs. General applied-target validation now also inspects actual spaces.

## Explicit pending, confirmation and failures

`commit(ticket)` is a synchronous native-then-model submission, with no await,
save or broadcast. All staleness, capacity, geometry and support checks precede
native mutation. Successful submission returns **ok=false, pending=true,
committed=true, transferred=false, save_ready=false**. It is deliberately not
encoded as ordinary successful interaction.

`confirm(ticket)` must be called after a later physics frame. It verifies unchanged
expected model/input/world/authority context and actual two-RID destination space
and transform application. Only that call returns transferred=true and
save_ready=true. status() additionally consults actual native target readiness;
prepared, pending, rollback-awaiting-physics and fatal states are not save-ready.
The helper does not save, broadcast, advance authority time or own a controller.

Same-frame pending movement returns NATIVE_TARGET_PHYSICS_STEP_PENDING without
preparing/caching a transfer or resetting the accepted input. This is only an
independent API boundary. Wiring it directly into current process/RPC handling
could reject moving F on every frame. A separate physics-owner fresh-edge design
must preserve elapsed authoritative time, permit moving/dodging/controlled F,
and coordinate snapshot/save publication before any live wiring is approved.
There is no new global pause or gameplay moving ban in this slice.

If immediate native submission is incomplete, both original source space bindings
and transforms must be observed restored before returning ordinary rejection. If
the still-unmodified model refuses its commit, the native transaction similarly
restores and verifies both source RIDs with monotonic ticket advancement; no save
restore or revision rewind is used. The admission remains consumed. Failure to
prove restoration, unexpected model mutation, or a later confirmation mismatch
returns fatal=true and save_ready=false. Post-model failure is fail-closed; this
candidate does not claim a proved post-model rollback mechanism.

Mandatory future caller contract: on fatal, stop the controller/owner before any
save or broadcast and retain the last durable save. The current NetworkOwner only
checks top-level fatal; a nested interaction.fatal would be insufficient. An
integration must call Controller._fatal and propagate top-level fatal. Ordinary
blocked/unknown destinations remain nonfatal action rejection.

## Exactly ten proposed bounded tests

`game/tests/actor/ActorNaturalTransferTest.gd` uses actual PhysicsServer2D resources,
actual Store/Stage-generated finite test fixtures and real Motion/authority/world
services. It does not run an ENet socket, Controller interaction handler, full owner,
file save/load or GUI. Test fixture Stage use is fresh setup only; the transfer
runtime imports no generator and performs no carving.

1. Off-center underground1→2→1, exact two RID identities, backend pending/explicit
   confirmation, stale admission/new cursor and held rejection, fresh-edge return
2. Moving transfer and active dodge plus control transfer preserve all record
   fields except layer, input identity/cursor/generation, resources and fallback
3. Destination peer rejection preserves admitted input and cannot replay the edge
4. Wrong full layer and actual peer RID space mismatch fail before model/native writes
5. Real surface endpoint unknown and legacy/schema3 transfer refusal
6. Cancel/replay, newer-input staleness and model/native revision capacity refusal
7. Same-frame movement pending, no next-frame replay, later fresh moving edge succeeds
8. Full circle edge blocker, changed native topology, actual terrain-row corruption
   and fabricated published bounds reject
9. Injected partial native submission and model commit refusal restore both actual
   source RIDs and unchanged model, with readiness awaiting native observation
10. Post-submission native space or shape corruption is fatal and never
    final-success/save-ready

All fixtures use only transient existing-style technical identities. No resume
secret, authority credential state, personal identity or private payload is printed
or persisted. The suite frees its own RIDs. Exactly ten methods are authored;
preload-path checks and git diff --check are clean. No engine parse/runtime result,
rollback behavior, transfer performance, physics readiness or gameplay acceptance
is claimed until the separately owned bounded gate runs.

## Remaining limits

Only the stored 147 underground cells and inherited technical surface room have
native query support. The real surface natural entry and approach remain unknown;
no loop from the room to a natural entry is demonstrated. Other dynamic categories
remain unresolved outside currently registered actor peers and represented world
objects. Stored native_clear_allowed, transfer_allowed and formal_world_allowed
flags remain false. No schema3 migration, live F dispatch, same-frame network
ordering, save/reconnect lifecycle, summons/beacons, GUI/input realization or
formal world permission is added or certified by this source candidate.

## Reviewed source freeze

Independent review caught and fixed two issues before engine execution: stale F
admission paired with a newer cursor, and premature readiness during native target
or rollback application. Model-owned one-use receipt and applied-native readiness
checks now have negative assertions inside the same ten methods. 65 runner +32
ReleaseSpec +6 package Python checks and source/cache preflight passed; evidence:
`011_natural_transfer_source_python_20261006T0951.log` and
`011_natural_transfer_source_preflight_20261006T0951.json` under evidence/. The
single ten-method native candidate gate is unrun; same192/900/192 MiB and45/110s
limits, no import or GUI. Shared Motion/ActorSpace affected regression is also
pending; standalone results cannot substitute live controller/RPC-phase testing.

## First native gate: discovery parse failure

Candidate8568aa3 exited105 before any of the10 methods started. The suite's
helper `_input(...)` conflicted with Node's reserved `_input(InputEvent)->void`
virtual at line105. Static source review did not detect this signature collision.
Production transfer behavior was not executed or accepted. Evidence is
`011core_runs_20261006T095237438728Z.json` and matching actor_core log; wrapper
completion `011core_completion_20261006T095227Z.json`. Godot195801 exited105,
was reaped, and same-desktop-namespace group-empty was true; wrapper195776 exited1.
CUA reset completed. Original failed report is retained unchanged.

Test-only repair: helper and all calls renamed `_admit_input`, with the same ten
methods and unchanged assertions/production source. A deterministic source guard
now rejects unapproved top-level Node callback names in this standalone suite;
it does not claim to replace Godot parsing. Three Python guard tests include the
original collision, all reserved callback names, and the correctly renamed helper.
Source preflight and these tests passed; evidence `011_transfer_callback_fix_*0954`
files retain that result. The original parse-red is not relabelled as passing.

## Independent candidate native gate passed

Candidate764b6d51280bdf7470e2822568e062ea8be46c17 passed all10 methods after the
test-only helper rename. Zero errors/failures/flaky/skips/orphans or script
warnings; test11.860 seconds, outer13.116 seconds; peak115,933,184 bytes below192
MiB. Evidence: `011core_runs_20261006T095601740815Z.json`, matching actor_core log,
and `011core_completion_20261006T095551Z.json`. PID196195 exited0/reaped; the
owning runner proved its group empty in `pid:[4026532200]`; wrapper196169 exited0,
CUA reset completed. The original discovery parse failure remains unchanged.

Verified limits are the ten standalone model/native methods above, including
nonfinal pending result before explicit confirmation, native rollback readiness,
fresh receipt no-replay, and real existing RID spaces/transforms/shapes. Shared
Motion/Space regressions remain pending. Controller/RPC-phase/live F dispatch,
automatic publication/save gating, actual surface approach and whole natural-entry
gameplay remain unimplemented; this is not full user-operation acceptance.

Affected regression frozen as two serial commands: Motion34+PresenceTransaction12
then Space13+NativeCircle3+JoinNative10, exactly46+26 prior methods, without rerunning
the new ten. Same192/900/192 MiB,45s each/110s outer. First failure or nonempty
owned group blocks the second command.71 Python runner/callback checks and source
preflight passed; actual regression execution pending, production unchanged.

## Shared regressions passed

Candidatef551e26 ran the frozen46+26 prior methods serially: each exact count passed
with zero errors/failures/skips/orphans and no script warnings. Outer8.167 seconds;
peak RSS95,502,336 and109,813,760 bytes. Both normal exits0 were reaped and both
process groups proved empty in the owning `pid:[4026532200]` namespace. PIDs197580
and197594; wrapper197549 exited0; CUA reset completed. Evidence:
`011core_runs_20261006T100049121117Z.json`, matching transfer_motion_presence and
transfer_wall_regression logs, and `011core_completion_20261006T100039Z.json`.
These72 are shared model/presence/native regressions, separate from the ten new
candidate methods. Live F/RPC/physics-phase integration remains unimplemented.
