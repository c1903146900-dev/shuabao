# 011 remaining user path after real ENet verification

## Verified boundary

`011_live_enet_20261006T232826427669Z.json` proves actual localhost server/client
with a previously saved underground member: input sequences1–3, movement,
underground1→2 F transfer, client confirmed revision34/pending clear, exact
normal-shutdown save sequence4 and both process exits. It does not prove new
surface-player creation, a normal playable GUI route, or sustained performance.
Formal world remains disallowed; graphics are technical proxies, not final art.

## Next minimum visible goal (A)

A completely new identity joins new4 at one of the existing five validated
surface spawn anchors, receives welcome only after physics confirmation and
actual save, and moves using the actual client. Use the existing source-bound
room; do not pre-create a profile or move the player underground.

Existing reusable APIs: Authority.prepare_join/prepared_join_effect,
ActorSessionController._choose_join_placement (extract read-only selection,
not synchronous join), ActorMotion.prepare_presence, native prepared placement,
and the same Frame commit→next-physics confirm→SaveStore→welcome path.

Required changes are small but must be atomic: Frame currently refuses is_new
and predicts only retained actor activation/revision+1. New actor creation
requires profile/used_ids/added_ids/actor/fallback and revision+2 in the sealed
write set. Owner activation must validate actual complete native coverage,
not simply remove its underground-only check. A user-facing owner transition
must replace probe-only activation. The ordinary technical GUI still targets
schema3; new4 GUI wiring is a separate explicit acceptance step.

A does not require missing balance data. Test empty save directory and empty
client identity, real ENet creation/movement, rejected placement with no partial
identity/native allocation, and normal exact save/reopen without regeneration.

## Follow-on goal (B): actual surface approach and entry

The verified seed42 layout has spawn[9,88], surface room[1,82,17,13], natural
surface/u1 entry[23,78] and safety region[20,75,7,7]. The entry is outside the
current supported room. Three underground7×7 regions are genuine generated
opening artifacts, but their147 cells do not establish a playable world or
surface route. Do not enlarge bounds, generate during F, or clear a straight
corridor merely to make the test pass.

Materialize a versioned surface occupied-cell artifact from the same world and
layout; validate and persist it independently without restore-time generation.
Stage currently skips surface; Store and native consumer explicitly expect
three underground regions/147 cells. Their contract and version change must be
coordinated with TerrainSession, source lease and native complete-body/sweep
coverage. Render real layout connection3×3 bodies through the same pointer
transform; currently ViewProjection renders only prefab objects/actors. Do not
broadcast a whole large audit artifact every tick or silently extend snapshot
fields without a bounded public projection contract.

Original authority reviewed: cehua paragraphs143,171,174–175,192;
shuzhi sheets34 R11/J11/O11,38 J6:P6 and O7:P7,32 X9:Y17,
63 C10:C11,134 C2/E2. These define mother world/body/surface, spawn radius100,
entry distance10–30, next-depth distance30, body3×3/safety7×7, protected-category
exclusions, underground H1-before-carving-H0, complete body diameter0.65 and
pointed target range1.5. Safety rules do not authorize clearing arbitrary approach
terrain. Actor exactXY preservation is the documented conservative implementation
choice; original paired endpoints shareXY but do not separately specify an
off-center actor landing algorithm.

Real unresolved balancing/source details: biome area fractions, cave rates,
tree/animal densities, POI cell geometry, and traceable minimum material guarantees.
The three null projection fields are implementation additions, not proof that
all numeric source data is missing. Existing known categories and rules can be
implemented now; unexecuted stages cannot be relabeled empty air. New quantitative
balance choices require explicit table review, not hidden constants.

## Remaining 011 / 011.5 gates

- A and B: new surface player, visible real entry, GUI pointer/F to u1 and back
- new4 normal disconnect/empty-server pause/rejoin/late join/rename and general
  occupied-place reconnect; current fixed roster disconnect is fatal
- actual F save followed by a separate real server restart and continued input
- full successful movement in eight directions, held-key focus loss/recovery,
  and actual viewport resize (prior camera centering/limited inputs remain valid)
- positional prediction/reconciliation, dodge afterimages, final animations/audio
- sustained moving/F/owner load timing; idle benchmark is not that measurement
- ordinary server lifecycle beyond current technical90-second timeout
- 011.5 real unique Build and explicit old-save policy integration; the current
  Python planner is advisory, not a migration loader or formal release identity

This document is a plan, not authorization to generate additional terrain or run
an engine. No game source was changed during this review.

## Frozen-source boundary and future editing

Current lease freezes more than configuration: the whole World.component
(including permanent_changes and Prefab objects), generation/template roots,
Space terrain/support/space maps, Store input roots, both ActorInputs trees, and
the real owner terrain root. Identity-equivalent replacement still invalidates
it permanently; release does not thaw it. PhysicsServer RID contents are not
made immutable by freezing dictionaries, so actual native checks remain necessary.

A only creates mutable authority profile/ID entries, actor/input records and
actor bodies/shapes. It can preserve every static root/hash and the existing
schema4 format. Its tests must prove this, not renew the lease or call
technical_clear_cell. No terrain generation or migration is required for A.

B's surface artifact must be built before initial freeze, with an explicit new
terrain contract matching Store/native/save validation. Preserve existing Prefab
walls, door, objects and instance IDs. Each effective cell has one H0 occupancy:
base-generation provenance plus Prefab H0 provenance must not double-render or
create two base floors. Current permanent_changes means only a validated default
underground-rock clear action, not arbitrary mining/building edits. Old terrainv1
must not acquire surface through restore-time generation. Whether the outer save
schema increments depends on the chosen format; explicit compatibility/refusal
is mandatory, not an implicit migration.

Future mining/building needs lawful updates to depletion, removed objects, placed
floors/buildings and their native occupancy. Initial generation inputs/seed and
initial facts should remain immutable, while runtime edits need an explicit
successor revision transaction: bind previous version, prevalidate state/native
changes, commit, then permit save/publication. Today full world/edit hashes and
frozen roots block that operation. Rebuilding a Frame or silently renewing a lease
would erase the proof chain and is not acceptable. This is a declared later
interface requirement, not a mining system or generic editing framework in A.
