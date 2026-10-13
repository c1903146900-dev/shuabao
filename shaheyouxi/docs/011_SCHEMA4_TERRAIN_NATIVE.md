# 011 schema-4 finite terrain native adapter

This is a **development_unreleased technical slice**, following the accepted
schema4 file gate in `011_SCHEMA4_TERRAIN_SAVE.md`. It adds no F interaction,
cross-layer movement, approach tunnel, surface generation or formal world.
Implementation and ten bounded tests are present. At this source checkpoint,
**no Godot parse or runtime result is claimed**.

## Production seam

- `game/scripts/actor/actor_terrain_space.gd` extends the existing ActorSpace
- The legacy owner now constructs through `_make_actor_space()`, whose default
  still returns ActorSpace. Its configure, two-physics-frame wait, direct-state
  checks, Controller creation, save-before-listen order and cleanup are unchanged
- Only `actor_terrain_network_main.gd` overrides the factory, passing the stored
  complete terrain component and its actual RequiredEntryTerrainStore
- `_write_report()` adds separate ephemeral `terrain_runtime` evidence. The
  existing `terrain_persistence` report and stored component retain false
  `native_clear_allowed`, `formal_world_allowed` and `transfer_allowed`

## Validation before native allocation

The adapter calls **Store.restore**, bound to the current world's complete public
component and world ID. It never calls Stage, Stage.validate, materialize, world
creation, random selection or prefab instantiation. Store validates all actual
147 records, their exact types and source/world/operation/reference bindings.

A second read-only pass translates the actual records into support:

1. Index the world's actual full layers and object IDs; reject unsupported liquid,
   plane or formal blocking occupancy rather than silently dropping it
2. Require three distinct region and endpoint identities, each with its actual
   underground full address, a 7×7 bound and 49 unique stored cells
3. Inspect all twelve category statuses and explicit occupancy: H0 ground, cleared
   H1 rock, applied carve, cave height, excluded initial liquids/minerals/trees/POI,
   initial-animal candidates, prefab object references and permanent-change keys
4. Recheck every integer cell coordinate in each rectangle. Completion booleans
   and declared completion counts never grant support
5. Refuse permanent edits inside the new support bounds: this slice has no native
   interpretation of their changed occupancy

Only after the full pass succeeds does the inherited configure allocate spaces
and existing technical-room blockers. All target native layers are checked before
publishing the three regions. A later failure disposes every inherited body,
shape and space RID and clears all support/evidence, including a failure injected
immediately after publication in the rollback test.

For seed42 there are two disjoint depth1 regions and one depth2 region sharing
XY with the second depth1 region. They remain three distinct regions. Full layer
keys prevent the coordinate alias from mixing support or peer occupancy.

## Query behavior and limits

The existing technical surface room remains inherited. No new generated surface
region is added. The native blocker set remains the room's existing fifteen
rectangles; an unknown support edge is **not** a new wall and has no fabricated
contact normal. No tunnels or connecting corridors are filled in.

The adapter inherits full environment-circle coverage, map-circle bounds,
PhysicsServer shape intersection, native motion testing and endpoint certification,
known-region swept-AABB checks, peer placement/target overlap rules and native
position tickets. Both endpoints being known does not certify a sweep between
disjoint regions. It remains forbidden to traverse the unstored gap.

The artifact's dynamic occupancy is unchanged and unknown. Runtime placement
checks cover only currently registered actor peers and represented world objects.
Enemies, summons, carried animals and user objects are not asserted clear or
prohibited. Runtime evidence does not certify these categories, grant transfer,
or alter the stored terrain artifact. Owner readiness is reported independently
and can become true only through the inherited two-frame preparation path.

## Finite ten-method native gate

`game/tests/actor/ActorTerrainSpaceTest.gd` contains exactly these tests:

1. All three real regions have clear native interiors and within-region motion;
   exactly 147 cells, three spaces and fifteen original blocker bodies/shapes
2. Full-circle edge overhang and unstored neighboring cells reject, with map-circle
   containment retained and actor pose unchanged
3. Actual same-layer endpoints in the two disjoint regions reject an unknown-gap
   sweep without altering position
4. Same-XY depth1/depth2 regions remain distinct; wrong world/body aliases reject
5. Existing peer occupancy, peer-overlap target transactions and removal work
6. Seven rehashed bad-artifact variants reject before native allocation, including
   a corrupt final cell after the preceding regions have valid rows. A Store-valid
   permanent edit is independently rejected, and an actual owner failure leaves
   no initial main, backup or world-identity files
7. Injected post-allocation/post-publication failure leaves no RID or partial support
8. Legacy factory still selects ActorSpace/schema3, underground remains unknown,
   surface native wall motion and blocked virtual-start checks remain effective
9. Actual schema4 owner, scoped multiplayer branch, real two-frame native
   preparation, Controller and initial SaveStore write retain all stored flags
10. Actual schema4 SaveStore close/reopen, state restore and native preparation
    yield 147 supported cells with zero terrain/world/prefab/random generation,
    inactive actor runtime and byte-identical main file after restore

The suite uses actual PhysicsServer2D resources and the production Store/Stage,
world, actor, owner, Controller and SaveStore. Stage is used only to create fresh
test worlds. The owner probe intercepts `_ready()` and final quit; it does not
replace native configuration, readiness, scoped multiplayer, controller or file
restore. It opens no ENet socket, does not execute full network bootstrap, and
establishes no GUI, multi-instance, approach or F-transfer result. The deliberate
post-publication error proves cleanup, not a real engine allocation failure.

The restore case begins with an empty actor set; non-empty actor state persistence
is covered by the prior twelve-method file suite, and underground peer placement
is covered by this suite's direct native tests. No new migration or actor transfer
is implied by these fixtures.

## Source verification

The authored method inventory is ten. All explicit preload/scene paths exist;
`git diff --check` is clean. Store, Stage, ActorSpace and controller production
sources are unchanged. The only new legacy-owner runtime seam is its default
factory; no query or lifecycle logic is duplicated. Native execution remains
pending the root-owned bounded resource window and runner evidence.

Source freeze: 62 runner +32 ReleaseSpec +6 package Python checks passed, with
source/cache preflight in `evidence/011_terrain_native_source_preflight_20261006T0925.json`
and Python log `evidence/011_terrain_native_source_python_20261006T0925.log`.
Independent read-only review found no remaining source blocker. The test statistics
key was corrected before any engine run. Native ten-method gate is pending a
separate window: one PID 192 MiB / effective reserve900 MiB / raw margin192 MiB,
45-second command /110-second outer, no import or GUI. Same-namespace normal
reap and empty process-group evidence are required. These source checks are not
native acceptance.

## Actual finite native gate passed

Candidate cefd23b172788294713b13596f7f838fc01bb13d passed all 10 methods: zero
errors/failures/flaky/skipped/orphans, no script warnings. Test time10.789 seconds,
outer12.009 seconds. Peak owned RSS197,599,232 bytes (188.45 MiB), below the
unchanged192 MiB cap but with only3.55 MiB margin; later wider gates must not
assume this run has a generous memory reserve.

Evidence: `evidence/011core_runs_20261006T093135827100Z.json`, matching
`011core_actor_core_20261006T093135827100Z.log`, and completion
`011core_completion_20261006T093125Z.json`. Godot PID192603 exited0, was reaped,
and the owning desktop runner verified its process group empty in
`pid:[4026532200]`. Wrapper192573 exited0; CUA reset completed.

Validated scope is actual three-region native support, real shape and strict
known-region edge/gap checks, actual peer occupancy/transactions, failed publication
and invalid owner cleanup, retained legacy surface behavior, two-frame new-owner
readiness, and empty-actor real-file reopen with zero generation. The persisted
artifact certification flags remain false; runtime support is separate evidence.
Surface generation/approach, F cross-layer transactions, full bootstrap/ENet/GUI,
nonempty actor native restoration and other dynamic categories remain unverified.
