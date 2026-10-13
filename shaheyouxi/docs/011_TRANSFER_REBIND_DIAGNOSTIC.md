# 011 one-method same-frame native rebind diagnostic

Status: source authored, **unrun**. This diagnostic investigates a prerequisite
for a later transfer-plus-current-physics-tick transaction. It does not change
production readiness, pending confirmation, input admission, Controller, owner,
RPC, save, source rules or gameplay. The accepted standalone transfer candidate
remains separate; no live F claim follows from this diagnostic.

`ActorTransferRebindDiagnosticTest.gd` contains exactly one method. It creates the
real schema4 seed42 underground1/underground2 same-XY supported entry pair using
World, Stage, Store and ActorTerrainSpace. A clearly test-only native static wall
is added to underground2 at one cell ahead of the actor. Underground1 at the same
coordinates is clear. The actor starts at a non-center XY that is clear in both
layers, and a two-cell horizontal motion stays within actual known coverage but
intersects the target-layer wall. The actor itself is never moved by these queries.

The method checks these exact observations:

1. Source raw PhysicsServer2D.body_test_motion is clear
2. Dedicated native transfer rebinds the same two body RIDs; in that exact physics
   frame, raw body_test_motion must detect the target wall
3. At frame+1, native transfer confirmation succeeds and the raw query still hits
4. Reverse transfer in that frame restores a clear source raw query
5. At frame+2, reverse confirmation succeeds and source remains clear

Every transition verifies actual body_get_space, unchanged actual transforms,
shape count/RID identity and unchanged body/shape/space counts. The normal API
continues to report NATIVE_TARGET_PHYSICS_STEP_PENDING in the submission frame.
No pending guard is weakened, no epsilon is added, and no alternate query replaces
a failed direct raw motion result.

Each observation emits only a phase label, frame numbers and geometry/query facts.
Actor/profile/world identities, resume material and credentials are not logged.
Raw hit/fraction/normal and the existing adapter's separate endpoint-certification
result are recorded independently. An adapter rejection or refinement cannot be
reported as raw native success. If target same-frame raw motion misses, the method
must remain genuinely red; its source/next-frame results explain the boundary
rather than hiding it with an alternate route.

The target wall is only a diagnostic fixture, not formal generated terrain. The
method allocates no network owner or listener and frees all owned native resources.
No engine, GUI, CUA, commit or upload was run while authoring these two files.

Source preflight and74 Python runner/callback checks passed; evidence
`011_transfer_rebind_source_preflight_20261006T1012.json` and
`011_transfer_rebind_source_python_20261006T1012.log`. Single native diagnostic
remains unrun; parent source review confirmed raw/adapter separation, actual
layer-specific wall counterexample, unchanged production and five ordered
observations. Same192/900/raw192 MiB45s/110s budgets and same-namespace cleanup.

## Actual diagnostic passed

Candidate4217838 ran the single method successfully, zero errors/failures/skips/
orphans and no script warnings. Outer1.8968 seconds; peak109,780,992 bytes. Actual
raw observations for position(37.625,69.25), motion(2,0):
- frame20 source: clear, fraction1
- frame20 after target rebind: hit, fraction0.3359375, normal(-1,0)
- frame21 target: same hit/fraction/normal
- frame21 reverse source rebind: clear, fraction1
- frame22 source: clear, fraction1

Adapter observations were independently ok and equal to the corresponding raw
values; no endpoint fallback was substituted for raw native evidence. The test
asserted actual two-RID spaces/transforms/shape identity at each phase. This is one
bounded target-only-wall diagnostic, not general frame transaction or live F proof.

Evidence `011core_runs_20261006T101457143061Z.json`, matching actor_core log, and
`011core_completion_20261006T101447Z.json`. PID199746 exited0/reaped; its group was
empty in owning `pid:[4026532200]`; wrapper199721 exited0, CUA reset completed.
Production, standalone confirmation barrier and live RPC wiring stayed unchanged.
