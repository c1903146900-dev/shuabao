# 011 startup-only confirmed presence and real save

Status: source implemented and independently reviewed; this slice has not run a native gate.
InitialBoundary8 and the affected FrozenSourceLease8/Frame10 regression passed in
the preceding parent-owned gates. The earlier idle benchmark also passed
`125332212210Z`; it measured idle/no-owner work only, not this startup path.

## Deliberately bounded vertical slice

The actual schema4 owner is being connected to the same Frame, starting from its
confirmed empty initial boundary. The supported join is an authenticated retained
inactive actor whose original underground layer and exact original XY are fully
clear in the existing finite native support. This is a technical subset, not the
full reconnect placement rule and not a replacement for Controller's general
placement logic. A blocked original placement is rejected here; no nearest-point,
spawn-center or surface-to-underground relocation is introduced.

New-profile surface spawn remains unsupported. The real natural surface spawn to
surface-entry route has not been implemented. Restored technical underground
profiles are test inputs, not evidence that the whole fresh-player route works.
Duplicate already-active joins and changing a retained display name on resume
are explicitly outside this slice. Existing authentication still validates the
resume proof; a local-host request also requires peer 1, host owner mode and the
retained HOST role. No client field can grant local-host trust.

The entry remains paused after bootstrap. It does not call old Controller.step,
admit actor input/F, rename, or apply ordinary disconnect mutations. Unsupported
input/command paths reject explicitly; disconnect of an authenticated or in-flight
presence fails closed without saving. This is not a fully playable network entry.
The later movement/F and ordered lifecycle work must extend this same Frame;
reconstructing it or clearing lineage is not an accepted integration mechanism.

## Presence proof

Frame.prepare_bootstrap_presence starts at an actually checked confirmed lineage.
It obtains the existing Authority prepared-join and Motion prepared-presence
tickets, binds their detached private write sets, and derives expected actor,
public, authority and input values before mutation. Motion's existing resource
resume logic is retained, including original absolute action deadlines and
fallback policy; this slice does not invent a resource/time reset.

The native preparation consumes a known generation without allocating bodies.
Cancellation is allowed only while prepared and only if the exact read set still
matches; it accounts for that known generation change and preserves all actor,
authority, input and public state. No unobserved snapshot becomes a new baseline.

commit_bootstrap_presence validates all three tickets and their expected read
sets, then allocates through the existing placement path. Its narrow Space wrapper
accounts for exactly two bodies and two shapes for the named actor and leaves
every old binding unchanged. The only newly observed identities admitted into the
proof are those controlled allocations and the named fresh InputState. Logical
records, resource changes, input generation and all other identities are checked
against pre-derived values.

Commit is explicitly pending and contains no welcome. A later physics frame must
prove the exact final boundary, including actual spaces, transforms and circle/
square shape bindings/dimensions, before confirm_bootstrap_presence establishes
the successor lineage. Ordinary submit, publication and saving remain pending
through prepared and committed presence. Wrong-kind/foreign/stale/replayed tickets
cannot switch phases. Unprovable commit/confirmation errors are fatal and release
owned runtime resources, with no delta retry.

## Real save and non-forgeable acknowledgment path

Frame.save_confirmed_owner accepts a reason and automatic-deadline intent, never
an externally supplied success dictionary. It resolves the bound real owner and
its actual SaveStore, requires the actual save script, schema4/exact format,
matching content/protocol, the owner's exact persistence directory/slot counts,
and the real TerrainSession validator attached to the same owner services. The
legacy ActorSession must also be the real script, ready, refer to the same World,
and retain the exact approved actor document and half extent. Automatic interval
is source-lease bound and must match the owner configuration. The first use
captures the Store and both Session identities plus Store configuration;
replacement later fails closed.

The method pre-derives the next sequence, automatic-backup slot, exact combined
schema4 state and permitted deadline difference. It calls that Store.save_main
itself synchronously, then checks its actual sequence/slot/configuration and the
unchanged runtime boundary. Only a genuine committed main write permits the
specified deadline assignment and exact successor-lineage check. The receipt
reports store identity, sequence, the hash of the exact-codec state tree, and
main_committed/complete flags; it is an output, not a credential accepted by a
second mutation API.

If main commits but backup fails, the allowed deadline still reflects the durable
main state and the operation then fails fatally. It does not claim that no bytes
were written, undo the main save, or send a success welcome. Failure before main
commit does not advance the deadline. Existing SaveStore atomic-write/backup
semantics remain the source of the actual I/O result.

The startup owner orders confirmation, successful real save, then welcome and
snapshot publication. This durable-before-welcome order is a conservative
engineering choice for this technical slice, not an additional cehua rule.
No resume proof, welcome, profile, full state or private writer token is logged.

## Owner integration and bounded work

The base host bootstrap gains a default-compatible awaited composition seam;
ordinary legacy owners retain the original join behavior. Remote RPC sender is
captured before any await. The schema4 owner binds queued hello work to its
transport connection incarnation and rechecks it before post-await replies.
Queued work is bounded by 64 events, 4,096 bytes per event and 65,536 total bytes,
with at most one outstanding hello per connection. Typed fixed fields are checked
before copying. The private resume proof exists only in bounded in-memory work
and the existing identity/authentication mechanisms.

Normal stop waits for any already-committed presence confirmation and then saves
the confirmed state before cleanup. A fatal path never falls through to the old
normal-save or broadcast path. Pending snapshots use only the previous confirmed
cache; no empty-dictionary fallback asks Authority to construct a tentative live
snapshot. Owner tests exercise these actual seams in a scoped fixture; separate
real transport verification is still required before making ENet claims.

The finite target is ActorBootstrapPresenceSaveTest.gd with ten methods, including
the actual detached owner's successful async bootstrap path plus native and real
temporary SaveStore tests. Its Store-failure cases invoke Frame directly: they
prove exact I/O/deadline/fatal receipts at the core layer, not owner process exit
or absence of a network welcome. Assertions use booleans/scalar labels to avoid
dumping private state on failure. All native/IO execution remains resource-gated.

Production quit behavior is not replaced with a detached-test fallback. Real
owner main-write failure, post-main backup failure and stop-during-join therefore
belong to three separate short-process probes, with actual expected exit codes
1, 1 and 0. They instantiate the real owner in a SceneTree, restore a temporary
schema4 underground HOST fixture and use the actual bootstrap/termination path.
The seed already occupies one save sequence; expected subsequent sequence is
derived from that baseline, not hard-coded to 1. Faults use actual temporary-path
I/O failures, not fabricated success receipts. No successful new welcome/identity
publication is allowed on the terminal failure/stop paths. These probes are a
separate gate, never a claim inferred from the ten-method suite.

## Existing terrain-save twelve-method coverage map

The prior ActorTerrainSaveIntegrationTest method identities remain. Its FakeSpace
is removed from real-owner positive paths; those use actual runtime preparation,
native waits and initial Frame confirmation. Their technical service assembly
does not call detached _prepare_session, which requires scoped in-tree multiplayer.
It also does not add the owner to a tree and accidentally invoke its real _ready.

1. Generation/provenance and retry guard: preserve the original layer of testing
2. Real owner save/close/reopen/inactive exact state: migrate the positive owner
   fixture to the actual confirmed Frame contract
3. Schema3 denial: preserve denial
4. Missing/null terrain: preserve denial
5. Malformed types: preserve denial
6. Unknown fields/versions: preserve denial
7. Source mismatch: preserve denial
8. Rehashed semantic/checksum corruption: preserve denial
9. Stage failure/no save/listen/retry: preserve the failure-only probe
10. Runtime denial plus later terrain invalidation: migrate the positive runtime;
    check late invalidation through the actual Frame/Store refusal and unchanged
    bytes. This assertion is core-layer; real owner fatal exit/no-welcome handling
    is supplied by the separate terminal probes, not by a swallowed quit call
11. Actual Store 4 MiB read/write limit: retain Store-level coverage, not an owner
    integration claim
12. Schema3/schema4 constructor/report/wire separation: migrate the schema4
    positive fixture while preserving the legacy entry and wire assertions

No native pass is claimed for these migrated tests or the new probes until their
own authorized gates run. Pure Store coverage does not substitute for the owner
paths, and the pending terminal probes remain an explicit uncovered boundary.

## Native prepared-write-set refinement

The original first five bootstrap methods passed before the subsequent group was
refused at resource admission. That pass is historical evidence for the earlier
source only. A later source audit found that the native placement ticket's read
set and target legality were checked, but Frame had not captured its target write
set: changing the private candidate to another legal position could allocate at
that changed position. The later native/model confirmation would fail closed, but
the mismatch should have been rejected before allocation.

Space now exposes a validated, recursively detached prepared placement effect.
Frame captures it at prepare and compares it alongside the existing Authority and
Motion effects immediately before commit. It never recaptures the altered target
as new intent. The fourth existing method adds a second legal-position mutation,
checks that both top-level and nested changes to the returned effect cannot alter
the actual ticket, and then verifies pre-allocation refusal of the real private
candidate mutation. Its exact native-generation assertion permits only the one
fatal-cleanup dispose increment; an add_actor commit would consume another one.
Actor/authority state, publication and save assertions remain.

The suite still has ten methods, now 23 fixtures: ten in the first five methods
and thirteen in the last five. Both groups require a new authorized run after this
refinement. The former first-group pass is not carried forward to the changed
source, and no new native result is claimed here.

## Protected source gate and execution partition

149 Python checks and source/cache preflight passed in the1542 evidence files.
Independent review found no remaining source blocker for the10-method suite; no
runtime/native or real owner termination success is inferred. The suite has22
fixtures,23 actualSpace configurations and at least66 cold Store validations before
extra save/readback work. Therefore its original10 methods are prepartitioned into
first5 (9 fixtures) and last5 (13 fixtures), without deleting assertions.
Each serial process retains192MiB owned RSS,900MiB effective reserve,192MiB raw
floor and45s; total110s, first group failure prevents the next. No import/GUI.
The migrated old12, three real owner exit probes and affected schema3 gates are
separate pending gates. The exit probes enforce disk/stdout report agreement,
actual PID/exit, readback sequence, honest main_committed, zero welcome return,
unchanged identity/clock, zero restore generation and native cleanup.

First split attempt `011core_runs_20261006T154509607312Z.json`: first5 passed
with zero errors/failures/skips/orphans/script warnings,8.807s test. Engine246055
exit/wait0/reaped, desktop namespace group empty, peak139,997,184 bytes.
Before launching second5, original192+900MiB admission refused effective
1,137,987,640 <1,145,044,992 bytes. The second group ran zero methods/processes;
the overall gate remains failed. Wrapper246042 exit1, terminal closed/CUAreset.
This validates presence preparation/commit/next-frame confirmation and early
negative paths only; later save/actual-owner methods and all other gates remain
unrun. No threshold change or automatic retry followed.

The strengthened source passed the entire new5+5 split in
`011core_runs_20261006T160633199048Z.json`:10 methods, zero errors/failures/
skips/orphans/script warnings,11.652s+21.386s tests/36.310s outer. Both leaders
exited/waited0, reaped, desktop namespace groups empty; peaks140,148,736 and
164,274,176 bytes. Wrapper248740 exited0; terminal disappeared/CUAreset.
The real detached-owner success chain and native pre-allocation refusal passed.
The migrated old12, real_owner termination probes and affected legacy regressions
remain separate pending gates; moving/F/live network interaction is still absent.

The migrated terrain-save12 is prepartitioned6+6, preserving all methods and
assertions. Four real initial/native preparations were added compared with its
previous fake-positive fixture; the4MiB boundary remains. Each45s/total110s,
original192/900/192MiB, strict summary, explicit wait/reaped/empty-group, first
red stops the later group. Source preflight and188 combined Python checks passed;
this migrated12 gate remains unrun at source protection.

Migrated terrain-save12 passed both6-method groups in
`011core_runs_20261006T161703825214Z.json`: zero errors/failures/skips/orphans/
script warnings;12.147+11.879s tests/26.903s outer. Engines250238/250252 each
exit/wait0, reaped, desktop namespace groups empty; peaks165,326,848 and
187,879,424 bytes (second179.18MiB within original192). Wrapper250205 exit0,
terminal closed/CUAreset. Actual positive owner save/close/reopen and all existing
contract-denial/4MiB coverage remain; late invalidation is explicitly Frame-layer,
and real owner fatal/stop termination remains pending in the separate3 probes.

Before running the terminal probes, the outer runner independently checks the
case-specific owner terminal status/code/fatal, observed committed-pending phase,
not-startup-ready state, save completeness, stop injection, cleanup and explicit
no-RPC-delivery coverage, in addition to exit1/1/0, disk/stdout agreement and actual
sequence/main_committed/identity/clock proofs. The7 mock tests include21 corrupted
field alternatives; independent review passed. Each fault case gets a new private
runtime directory; injected.tmp directories never affect an earlier case or source.
The real terminal probes remain unrun until their own allocated gate executes.

Three actual Owner._ready/host terminal probes passed in
`011_bootstrap_fault_runs_20261006T162439172210Z.json`,14.022s total: main write
refusal exited1 with IO_ERROR/sequence1/unchanged main/main_committed=false;
post-main backup refusal exited1 with MAIN_SAVED_BACKUP_FAILED/sequence2/true;
stop during committed-pending exited0 with sequence2 and complete backup.
All disk/stdout proofs agreed, welcome return count0, private identity unchanged,
clock unchanged, all regeneration counters0/terrain restore1, native/writer-lock/
scoped API cleanup verified. Each PID251043/251057/251071 waited/reaped and its
desktop namespace group was empty; peaks143,486,976/164,806,656/164,917,248 bytes.
Wrapper251016 exit0, terminal disappeared/CUAreset. Independent private directories
retain their injected failures for inspection; none entered this archive.
This closes the terminal-owner coverage separated from the12-method file suite.
It does not test RPC delivery, movement/F, GUI or the full fresh-surface route.
