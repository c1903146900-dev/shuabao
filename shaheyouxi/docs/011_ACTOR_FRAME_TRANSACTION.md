# 011 bounded actor frame transaction core

Status: **development_unreleased, source authored, engine tests unrun**. This is
an opt-in core, following the accepted standalone natural transfer and asymmetric
same-frame native rebind diagnostic. No Controller, schema3/schema4 network owner,
RPC, client, save schema, wire payload, source table or live F entrypoint is changed.
It is the intended core for the next owner FIFO/lifecycle/publication integration,
not an alternative disposable live contract.

## Source rules and engineering boundary

The source distinctions in `011_NATURAL_TRANSFER_CANDIDATE.md` remain binding:
cehua P56/P68–70 supplies shared XY and active bidirectional natural entries;
P86, 63_移动能量!A11:F11 and 137_快捷键!A9:C9 supplies same-layer pointing and 1.5-cell
range. The existing diameter is 0.65. None imposes a new moving, dodge or control
ban on F. Existing dead-actor admission semantics are retained.

Exact off-center actor XY preservation is the approved conservative engineering
choice, not a quoted original subcell landing algorithm. Blocked/unknown targets
reject without nearest/center landing, re-anchoring or reset. Each natural
transfer itself changes only layer and its monotonic revision; the subsequent
ordinary tick legitimately evolves movement, resources, dodge history and time.
The artificial nearest-landing rule is not reused. Future summons/beacons and
other dynamic categories remain outside this actor-only proof.

`ActorTransferRebindDiagnosticTest` established the concrete prerequisite: a
prewarmed destination-only wall is seen by raw body_test_motion immediately after
the same two RIDs are rebound, in that exact physics frame, and again later.
Its clear source/reverse observations prevent an empty-space false positive.
This core preserves the normal pending guard. Only its validated native frame
capability permits same-frame queries after its own proven same-XY rebind.

## Intended owner interface

- `capture_envelope(peer_id, request)` reads the actual authority peer-to-actor
  mapping and current actor input_generation. It returns a bounded internal
  envelope binding peer, actor, generation, epoch and world to the raw request
- `submit(delta, ordered_envelopes)` admits the bounded FIFO in order, immediately
  consumes each genuinely fresh F receipt, applies each permitted layer change,
  then resolves and commits exactly one existing normal all-actor joint tick
- Successful submission is deliberately **ok=false, pending=true, sealed=true,
  confirmed=false, delta_consumed=true, save_ready=false**. It includes the frame
  ticket, consumed FIFO count and separate admission/interaction diagnostics.
  Submitted interactions also carry ok=false, submitted=true,
  transfer_pending=true, transferred=false; only confirm returns their completed
  result list, so a nested result cannot imply final transfer success
- `confirm(ticket)` requires a later actual physics frame and exact planned
  model/input/authority/native postconditions. Only it opens publication/save
- `public_snapshot()` and `combined_save_state()` return explicit pending while
  sealed. The save accessor is explicitly labeled authority_world_actor_base
  with requires_terrain_wrapper=true: its seven-field dictionary must be combined
  with the stored typed terrain by the schema4 owner/TerrainSession and validated
  before any schema4 SaveStore write. It is not a complete schema4 save. `last_confirmed_snapshot()` supplies only the prior proven public state
  for read-only replies, never an empty fallback representing tentative state

The envelope is a server-side object, not a new client-selected identity field.
The future owner must supply the actual RPC sender/local-host binding. Every entry
is compared again against current authority and activation generation; a stale
connection/epoch, reused peer ID or foreign actor cannot admit input. Capturing an
envelope is not acknowledging input. accepted_sequence moves only when Motion
actually admits it. Malformed/foreign/stale entries produce rejected admissions
and do not suppress the normal frame tick.

There is no per-frame one-F rule or added cooldown. Multiple legitimate
pressed→released→pressed sequences can transfer in one bounded FIFO. Each fresh
edge consumes its own Motion-issued receipt and rechecks actual destination
occupancy using earlier committed layer changes. An ordinary rejected F is already
consumed, is never queued/replayed, and the frame still performs its one normal
source-layer tick. Current input/dodge admission costs remain independent actions
and are not rolled back because an interaction fails.

## Technical resource configuration

The core currently sets 64 envelopes per frame, 4,096 serialized bytes per valid
envelope and 65,536 bytes per valid batch. These are explicit implementation work
and memory limits, not source gameplay numbers, F rates or cooldowns. The later
owner FIFO must reuse these constants and bounded payload checks when slicing a
physics batch. It must retain only not-yet-admitted envelopes and must never turn a
failed admitted edge into a deferred retry. Oversized batches reject before a
frame starts; they must be split before submission or terminate the affected
input stream under the owner policy, not silently lose elapsed game time.

Payload structure and Command's primitive-field validation precede serialization
or copying; malformed nested/oversized input is not retained. Native preparation
reserves the worst-case bounded transfer, rollback and final movement generations.
Model preparation reserves input plus layer-change revisions and the one tick.
Duplicate/same-frame submissions cannot advance another tick; outstanding sealed
frames cannot accept input through this core.

## Pre-derived proof, not post-write snapshot adoption

Motion adds two read-only service seams: `frame_projection()` creates a detached
logical proof model, and `frame_input_state()` returns detached latch values and,
when requested, their identities. The projection contains only logical actor
records, active/input values, input generations and necessary monotonic serials.
It copies no terrain, authority profiles or credentials. It is never restored
into the live model, never owns a native body, and never rewinds live revisions.
The existing accept_input, commit_preview algorithm and return contracts remain.

Before each live admission, the projection derives that exact action result,
record, public cursor and input values. The real admission must match; input
identities may change only for the admitted actor as existing Motion requires.
Before each layer commit, a next projection derives only the destination layer
and revision. A rejected native submission leaves the current projection intact.
For the final tick, independent equal previews are resolved once by the existing
joint solver. The projection commits that exact resolution before the live model
commit, deriving the complete expected record/resources/dodge/clock/revision.
Tick input identity is retained. Authority time is independently predicted as the
same previous clock plus exactly this delta; other authority fields are unchanged.

ActorSpace owns a separate native frame capability. Its complete body/shape/space
bindings and generation chain are checked before every child operation. Legacy
prepare/commit/remove/dispose operations invalidate the capability. Only dedicated
synchronous wrappers may preserve it across the specific validated child ticket.
Each wrapper predicts the exact next generation and layer/position changes before
writing. Movement's ordinary invalidation still clears its ordinary tickets, but
cannot silently erase this separately verified transfer→movement chain.

The final native proof is derived from original RID/shape identities plus recorded
layer-only rebinds and the solver's final position targets. It is not a fresh
arbitrary native snapshot. Confirmation checks both actual body spaces/transforms
and original single-shape bindings, circle/rectangle types and trusted dimensions,
all model/input identities and values, actual
terrain/world bindings, and authority state against this pre-derived proof.
Circle radius accepts only the trusted configured scalar or its exact native
binary32 representation, as in existing join-native evidence; rectangle half
extents must equal the trusted native Vector2. No epsilon/tolerance is added.
Repeated confirmation cannot reuse the ticket. Outside sealed state, an unexpected
model/input/authority/native change, including removal of an actual native shape
or same-RID circle/rectangle dimension tampering while tracked RID arrays remain
unchanged, also fails the confirmed lineage rather than
being silently adopted by the next submit or publication accessor.

## Failure and elapsed-time boundaries

A native transfer refusal before its live model layer commit may restore both
actual source bindings/transforms through the dedicated monotonic rollback path.
Only verified restoration can become ordinary interaction failure followed by
that frame's normal tick. Once a planned live mutation or final tick cannot be
proved consistent, the core returns top-level fatal, releases model runtime and
native resources, and forbids publication/save. It does not restore a save or
rewind revisions. Prior accepted inputs/resources are not refunded. The caller
must stop and retain its last durable save; a nested interaction fatal is not
sufficient for the current NetworkOwner's error path.

A normal transfer frame advances its model and authority clocks by delta before
sealing. The next frame first confirms those already-committed targets, then may
submit its own delta. Confirmation never advances clocks. Thus no ordinary
transfer frame is skipped, doubled, clamped, or replaced with a two-delta tick
using later input. Invalid whole-batch/time/capacity preflight has consumed no
frame delta; the owner must not interpret it as a completed frame. Fatal results
report whether the model tick had committed, with retry_allowed=false and
delta_disposition=failed_no_retry. Tick accounting is scoped to the current
attempt and is cleared after confirmation, so a later failed preflight never
claims it consumed a new delta. Cleanup permits only a new lifecycle from the
last durable save; the failed frame delta must never be replayed.

## Explicit future owner dependencies

The later owner must feed every physics-frame FIFO through this same object and
coordinate lifecycle changes at proved boundaries; it may not retain direct
side-door admissions while treating this lineage as authoritative. Join,
disconnect, rename, stop and autosave need explicit owner state-machine handling,
with terminal/final-save semantics and no generation reuse. The present core has
no permissive “adopt arbitrary state” rebasing API. Planned lifecycle and actual
save-deadline changes need their own checked handoff transaction when added.

Pending publication must cover periodic broadcasts, hello replies, command
snapshots, reports, automatic save, last-player save and normal stop. A stop flag
must not bypass the physics confirmation needed to finish a pending transaction.
An empty dictionary must not be passed to existing snapshot/save fallbacks as a
pending marker. Newly created body first-frame query readiness remains a separate
join integration gate; this core does not alter add_actor readiness semantics.

## Proposed finite core gate and cost disclosure

`ActorFrameTransactionTest.gd` contains ten focused actual native methods. It
covers transfer+one tick time/resource/movement accounting, consumed blocked F,
layer-specific wall CCD, serial peer occupancy and joint CCD, multiple fresh F,
active dodge/control, sealed and confirmed-lineage corruption, rejected stale/
foreign/bounded envelopes, exact publication/save accessors, recoverable native
refusal and unrecoverable post-model movement submission. Save accessors return
actual authority/world/actor base dictionaries with the explicit terrain-wrapper
requirement, but this suite performs no disk SaveStore write,
owner networking, live queue integration, GUI or real-input acceptance.

Source/Store/native binding checks are still performed; no source-validation cache
or relaxed mutation detection was introduced. status exposes only validation call
count and accumulated microseconds alongside phase flags. Repeated validation of
the full 147-cell artifact/world is likely expensive at live 60 Hz and must be
measured before owner rollout. No live performance claim is made by a finite gate.
Multi-fixture methods free previous native fixtures before preparing another.
All test assertions avoid dumping private authority data or resume material.

## Reviewed source gate

Parent and independent source review corrected current-attempt delta accounting,
confirmed-lineage actual shape removal, malformed kind before legacy comparison,
pre-confirm nested success flags, and status readiness. The shared finite shape
proof additionally checks circle/rectangle type and trusted dimensions, accepting
only configured scalar or exact native float32 circle representation, not epsilon.
Corresponding negative assertions remain within the ten authored methods.

115 Python checks (74 runner,3 reserved callbacks,32 ReleaseSpec,6 package) and
source/cache preflight passed. Evidence: `011_frame_source_python_20261006T1045.log`
and `011_frame_source_preflight_20261006T1045.json`. Exactly ten native methods are
pending; no cold import/GUI. Frozen single command remains192 MiB owned RSS,
900 MiB effective reserve,192 MiB raw margin,45 seconds command/110 seconds outer,
with normal same-namespace reap+empty group proof. Shared regressions and actual
owner integration remain pending; this source review is not engine acceptance.

## First runtime gate failed, without script errors

Candidate d34ea70 executed only the first method, which reported three failures:
the expected complete actor record and both expected native transforms. The other
nine methods did not start. No script error/warning or orphan was reported; the
sealed/confirmation assertions did not report failure, but this does not establish
the complete frame contract. Preserve evidence `011core_runs_20261006T105100335782Z.json`,
matching actor_core log and `011core_completion_20261006T105050Z.json` unchanged.
PID207727 exited100/reaped, same-namespace group-empty true; wrapper207715 exited1,
CUA reset completed. Outer2.928s, peak122,793,984 bytes.

Measured full-validation cost: eight calls accumulated1,177,650 microseconds.
This is a material live-runtime blocker, not a 60Hz acceptance. First diagnose
exact expected/actual field and position bits while preserving delta and assertions;
only after correctness is located should immutable world/terrain validation move
to a verified load/freeze boundary with necessary revision/identity/dynamic native
checks retained per frame. Do not optimize safety and numerical behavior together.

Single-first-method diagnostic source adds only two whitelist log observations,
without changing production, original assertions, delta or expectations. It records
first differing field/types/safe Variant bits, exact scalar64 and float32 coordinate
bits, actual native body positions, table speed4.5, dt0.1, strict0.45 budget and
existing query/circle endpoint-fit results. Identity fields and whole actor/world/
authority data are omitted. Full-precision JSON prevents ULP loss in display.
`--actor011-frame-diagnostic` excludes the other nine methods at discovery; it
expects exactly one method and preserves real assertion failures.79 Python runner/
callback checks and source preflight passed in the1056 evidence files. Runtime
source-diagnostic remains pending; no expected-red is called a successful gate.

## Exact-bit diagnostic located the failed expectation

Single diagnostic report `011core_runs_20261006T105800694931Z.json` retained the
same three assertion failures, exit100, no script error. The first differing field
was position. From x37.75 at4.5 cells/s and dt0.1, strict budget is0.45. Closed-form
Vector2 rounding expected x38.20000076293945 (binary32LE cdcc1842), displacement
0.4500007629394531, exceeding that budget. Actual x38.19999694824219 (cccc1842),
displacement0.4499969482421875, matches both existing strict endpoint fits exactly.
At submitted frame21 both native bodies retained source x37.75; at confirmed22 both
matched the actual model endpoint exactly. Eight full validations cost1,175,241us.
PID209137 exited100/reaped, group-empty true; wrapper208981 exited1, CUA reset.
This diagnostic remains red and is not relabelled a test pass.

Test-only repair scans all ten methods and changes four free positive-X fixtures
(methods1,2,5,10) to an independent IEEE754 binary32 bit-order binary search oracle.
It uses only start/table speed/dt, never the production solver/fit or actual result.
At most32 iterations find the greatest representable endpoint within the strict
double budget; the successor must exceed it. Exact y, direction, reconstruction,
complete record/clock and two-RID equality assertions remain. The original rounded
closed form is explicitly asserted to be the next ULP and over budget. Wall, peer,
dodge/control and corruption tests were not generalized into this oracle.

Production mechanics, delta and validation-cost implementation are unchanged.
79 Python checks and source preflight passed in1105 evidence; full ten-method
runtime retry remains pending. Immutable-validation performance remains blocked.

## Ten-method correctness gate passed, performance still blocked

Candidateac4694c passed all10 original methods after the test-only independent
budget oracle repair. Zero errors/failures/flaky/skipped/orphans, no script warnings.
Test20.926 seconds, outer22.191 seconds, peak124,047,360 bytes. Evidence:
`011core_runs_20261006T110651834953Z.json`, matching actor_core log and
`011core_completion_20261006T110641Z.json`. PID210525 exited0/reaped, same owning
`pid:[4026532200]` group-empty true; wrapper210481 exited0 and CUA reset completed.
Both earlier failed reports remain unchanged.

The result covers the bounded independent frame core: correctly admitted FIFO,
transfer and single normal delta, failed-F normal tick, original-body target CCD,
sealed confirmation and denied corruption/publication/save-ready access. It does
not establish actual owner/RPC/SaveStore integration, the absent surface approach,
full F gameplay or performance. Ten recorded fixtures each spent1.086–1.216 seconds
across eight full validations. The next work must move immutable full verification
to a verified load/freeze boundary and retain cheap ownership/epoch and necessary
dynamic actor/input/native checks per frame, with explicit mutation refusal tests.
Do not deploy this full-validation-per-access path at60Hz. Shared affected regression
for the new frame seams remains pending alongside that performance repair.
