# 011 explicit frozen source lease

Status: **first correctness gate: seven lease methods passed, final lifetime
method failed; diagnostic confirmed the fixture-stack lifetime boundary. The
test-only boundary correction awaits its rerun; Frame10 and benchmark have not
started for this candidate**. This
performance candidate retains the accepted Frame10 actor/transfer/tick proof.
There is no new owner/RPC wiring, source data, gameplay rule, persistence schema,
formal-world permission or live 60 Hz acceptance.

## Why this is a source ownership change

The previous core repeatedly ran full World/Store validation and copied static
world data at boundaries. Frame10 evidence included approximately 1.18 seconds
for eight validations in one fixture, far beyond a real-time frame budget. Merely
skipping these checks while their actual backing dictionaries stay mutable would
allow undetected changes. This candidate instead validates once and deeply freezes
the actual runtime roots before substituting constant-size identity guards.

Godot 4.6 Dictionary.make_read_only and Array.make_read_only are shallow. Therefore
a complete acyclic/type/depth/node preflight is followed by a child-first recursive
freeze. Old aliases see the same readonly containers. is_same compares reference
identity for Dictionary/Array, allowing a same-content replacement to invalidate
a lease without rehashing every cell.

Official references:
- https://docs.godotengine.org/en/4.6/classes/class_dictionary.html#class-dictionary-method-make-read-only
- https://docs.godotengine.org/en/4.6/classes/class_array.html#class-array-method-make-read-only
- https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#class-globalscope-method-is-same

## Actual roots, not copies of public views

ActorFrozenSourceLease binds and freezes these fields that really exist:

- World: component, _generation, _template
- ActorTerrainSpace: _terrain, _supported_regions, _spaces, including each actual
  layer identity and materialized_bounds array
- The actual TerrainStore instance: _generation, _prefab, _bundle
- The caller's ActorInputs and the model's own _settings: _data, _source_identity

World has no _bundle field and none is assumed. Dynamic authority profiles, actor
records, active/input dictionaries, body and shape registration arrays remain
mutable. The sources consist only of validated scalar/Array/Dictionary trees;
RID leaves are allowed only in the native _spaces root. No Object/Resource child
can smuggle mutable state into a supposedly frozen source tree.

Before the first freeze, every root passes the cold traversal limit (depth64,
500,000 aggregate nodes), approved-file/config comparison, the original complete
Transfer/ActorSession/World/Store/support validation, and actual native boundary
checks. A failure at the last terrain row or another root leaves all previously
mutable roots mutable. The aggregate traversal limits are technical work bounds,
not source gameplay values.

The lease retains container references but only WeakRefs to services. It binds
actual service/script identities, model-settings/store ownership, all actual root
identities and readonly flags, authority world/epoch/protocol/catalogue/capacity,
World bundle hash, model world, native geometry/support identity and the native
static lifecycle epoch. A changed guard permanently revokes that lease. Replacing
a root with an equal deep copy is still a replacement; restoring the old pointer
later does not revive a revoked lease. release is irreversible and prepare is
one-shot, including after a failed attempt. There is no automatic revalidation or
silent reminting in response to a changed source.

Readonly is not reversible. ActorTerrainSpace increments its static epoch before
freeing resources, and disposal replaces its readonly _spaces/_supported_regions
references with new empty containers rather than clearing through old aliases.
World.restore retains its original root-replacement behavior and thereby
invalidates old leases. Only already-frozen ActorInputs instances reject an
in-place load_document before attempting a readonly clear; reload needs a new
instance. Ordinary unopted inputs and the old schema3 owner remain unchanged.

## Frame hot path and proof preservation

Frame.prepare_frozen_sources explicitly establishes the lease. The first submit
may establish it lazily once so the existing standalone core interface remains
usable; a failed/released existing lease is never replaced. Guarding source roots
replaces static full-world validation only. The hot dynamic boundary still checks:

- Complete authority/profile validity and all retained actor records, including
  disconnected/inactive profile-to-actor correspondence
- Actor schema/source identity, resources, anchors, timers, world clocks and
  revisions through the existing model validator
- Current and fallback full layer membership and complete environment-circle
  containment, including inactive actors; a legal center alone is insufficient
- Active authority/model/native sets and input latch/generation validity
- Actual body spaces, transforms, original circle/square bindings, native shape
  type and exact trusted dimensions, plus peer and target CCD in the unchanged
  frame/native transaction operations

The cached layer set and circle radius are derived from the validated frozen
World. Every accepted input, F receipt, same-XY transfer, projected expected tick,
monotonic native ticket chain, sealed state and publication gate remains. No
moving/dodge/control prohibition, nearest landing, delta merging or retry is added.

Motion.frame_projection accepts an optional valid source lease. In that explicit
path it uses an empty constructor and shares the already-frozen actual settings,
then copies the same logical records/input values/generations/serials as before.
It performs no input-file load or source reconstruction in the hot path. Calling
frame_projection without a lease retains the old validating construction path.
An invalid lease never falls back silently to a new source configuration.

The confirmed internal snapshot/state may share the readonly World root; external
public/save accessors still return their detached data. The save result remains
a labeled authority_world_actor_base requiring the existing schema4 terrain
wrapper and full save validation at the actual I/O boundary. This is not a claim
that every save component is already frozen or can bypass SaveStore validation.

## Remaining owner terrain and lifecycle dependency

The current native core reads ActorTerrainSpace._terrain, which is actually frozen.
ActorTerrainNetworkMain._terrain_component is a separate persistence copy and is
not passed to this core. This candidate does not claim that owner's copy is frozen.
When wiring the owner, it must either share the already-validated frozen artifact
or explicitly freeze/bind both actual roots before claiming a whole terrain lease.
Join/disconnect/rename/stop/save-deadline handoff and last-confirmed publication
remain the separate planned owner integration, with no arbitrary-state rebasing.

## Finite verification split

ActorFrozenSourceLeaseTest contains exactly eight methods: actual roots/old aliases
and immutable reload refusal; equal replacement/restore; terrain/config root
replacement; fake support/bounds and lifecycle epochs; all inactive actor/layer/
fallback-circle checks; actual shape/peer/clock/resource checks; failed preparation
atomicity; and unopted legacy behavior, release and weak service lifetime. Readonly
negative coverage uses readonly assertions and modified duplicate-root replacement,
never deliberate readonly writes that cause engine errors. Existing Frame10 is
retained as the transfer/movement/publication correctness regression gate.

ActorFrozenSourceBenchmarkTest is a separate one-method, opt-in gate after
correctness passes. It has three warmup frames followed by sixty measured frames
for one actor, then four actors, releasing the first fixture before the second.
The workload is explicitly idle_empty_input_batch. It performs normal model/native
frame submission and later confirmation, but no moving input, F, owner FIFO,
network socket, GUI or disk save. It cannot certify those workloads or complete
owner 60 Hz performance.

Only aggregate timing/count fields are printed: setup time, one cold complete
validation workflow, no subsequent hot complete-validation workflows, guard calls,
and submit/confirm/guard p50/p95/max microseconds. The source validator has an actual
counted cold entrypoint; guards/dynamic boundaries do not call it. Root's external
runner owns process time and peak RSS measurement. No source hash, actor/profile/
world identity, coordinates, authority data or credentials are printed in that
benchmark. No timing threshold or successful real-time claim is fabricated before
measurement; static/native resource limits remain unchanged.

## Source freeze and pending resource gates

Parent and independent source review checked actual-root freezing/weak ownership,
permanent invalidation, no-load shared settings projections, and retained dynamic
checks. Initial malformed input/world/actor/profile text and missing actor fields
now fail before older validators project them. Frame construction no longer reads
unverified numeric settings; half/range derive only after lease success. Missing
parameter/value fixtures reject normally without a partial freeze. Original
Frame10 assertions remain unchanged. The final constructor deferral and missing-key
negative additions were parent-reviewed after the independent full review.

122 Python checks (81 runner,3 callback,32 ReleaseSpec,6 package) and source/cache
preflight passed in `011_frozen_source_python_20261006T1206.log` and
`011_frozen_source_preflight_20261006T1206.json`. Runtime was unrun at that source
checkpoint. Correctness
profile serially selects Lease8 then originalFrame10, stopping after first failure;
each45 seconds, outer110 seconds, one192 MiB PID/effective reserve900/raw margin192.
Only after that gate passes may the separate one-method benchmark run, with the
same budget. Its1/4-actor×60 measured frames after3 warmups use idle empty input
batches, not moving/transfer/owner/network workload. Anticipated gate duration is
within110 seconds, but no measured cost or60Hz claim exists for this source.
The first source-protection attempt failed before process creation during a shared
exec transport outage; supported recovery confirmed the same host and unchanged
source hashes. No engine or desktop app was launched for this source checkpoint.

## Bounded lifetime diagnosis after the first correctness gate

The parent-run gate `011core_runs_20261006T121751253016Z.json` passed the first
seven lease methods. The final method produced seven failed immediate WeakRef-null
assertions after fixture disposal, with no script errors or orphan nodes. Frame10
was not started because that gate stopped on failure; benchmark was not started.
This is a retained red result, not a successful lease-lifetime claim.

The asynchronous fixture holds six service locals across its final physics-frame
await and returns directly to the awaiting test. The model additionally owns its
settings. A fixture-completion stack that has not yet unwound is therefore a
specific possible owner of all seven observed services. The subsequent diagnostic
measured exactly the predicted common retention and release in both cases.

The diagnostic changes only the final test method and two test helpers. It adds a
no-lease control and six bounded `FROZEN_SOURCE_SERVICE_LIFETIME` records: before
disposal, same-stack after disposal, and after exactly one process-frame await for
each case. Records contain only the phase, fixed service labels, alive booleans
and reference counts. The sampled count includes the diagnostic's temporary local
reference, explicitly cleared before return; no service object is stored in the
log payload. The RefCounted count accessor is read-only according to the
[Godot 4.6 API](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html#class-refcounted-method-get-reference-count).

The parent-run single-method diagnostic is retained in
`011core_actor_core_20261006T123123245791Z.log`. Lines 19–24 show identical values
for all seven services in both cases at every phase. Before disposal the ordinary
service counts were 3, store 4 and settings 2; immediately afterward they were 2,
store 3 and settings 2. After one process-frame await every WeakRef was null and
every reported count was 0, including while the active lease remained alive.
The diagnostic preserved the original seven immediate failures and remained red.
Those observations identify a fixture-completion-stack boundary, with no extra
service ownership introduced by the lease in this experiment.

The authorized test-only correction now checks the seven service-null assertions
once, after that single stack unwind. Both released and active lease instances and
immutable aliases remain in scope; the active lease is checked and released
afterward. The no-lease control and all six scalar-only diagnostic records remain.
There is no polling, manual reference decrement, forced collection, production
lifetime change or removal of weak-ownership coverage. Both original red logs are
preserved unchanged. The corrected Lease8 then original Frame10 correctness gate
is pending a parent-owned rerun; benchmark remains a separate later gate.

Diagnostic source gate: 124 Python checks passed with explicit tests import path;
source/cache preflight passed, no engine launched. The initial Python invocation
without that import path failed module import and is retained separately.

The corrected Lease8→Frame10 attempt at 12:34 UTC was refused before any engine
launch: effective 1,134,447,966 bytes below required 1,145,044,992 bytes.
`011core_runs_20261006T123454566666Z.json` retains this admission result; zero
methods ran, wrapper exited 2, terminal disappeared and CUA reset. Budgets and
production source are unchanged; corrected correctness and benchmark remain pending.

Correctness rerun `011core_runs_20261006T124821523845Z.json` passed Lease8 and
Frame10 with zero errors/failures/skips/orphans; 22.020s +12.295s test durations,
36.960s outer. Both leaders exited0, were reaped, and their desktop namespace
groups were empty; peaks120,348,672/127,004,672 bytes. Wrapper exited0 and
terminal disappeared/CUA reset. Earlier red and admission refusal are retained.
Idle benchmark is still unrun; no measured frame-performance claim yet.

## Measured idle workload (not moving/F/owner)

`011core_runs_20261006T125332212210Z.json` passed the single benchmark with
1 and4 actors,3 warmup then60 measured frames each. Full validation ran once
at preparation and zero times hot. Cold preparation was259.705/277.104ms.

| Actors | Submit p50/p95/max ms | Confirm p50/p95/max ms | Guard p50/p95/max ms |
|---|---|---|---|
|1|1.661 /3.991 /6.100|0.684 /1.164 /1.337|0.038 /0.064 /0.244|
|4|5.625 /7.660 /10.750|1.241 /1.651 /3.311|0.040 /0.050 /0.069|

These separate distributions are not a whole-frame percentile and do not establish
60Hz game performance. The workload uses empty input, without movement, transfer,
owner, network, save, or presentation. The prior repeated immutable validation
is removed from this measured hot path; live performance remains unverified.
One test, zero errors/failures/skips/orphans;3.453s test /4.9405s outer,
peak124,370,944 bytes. Engine227155 exited0/reaped with desktop namespace group
empty; wrapper227130 exited0, terminal disappeared and CUA reset.
