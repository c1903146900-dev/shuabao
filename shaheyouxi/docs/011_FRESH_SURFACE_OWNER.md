# 011 A: new surface presence through the existing Frame

Status: source implementation and finite native-test candidate. No native or real
ENet acceptance follows from source checks. This extends the technical schema4
entry; it does not certify a formal world, create surface approach terrain or
make the natural surface entrance reachable from the current room.

## Existing geometry and selection

The original Controller's read-only new-actor placement loop is extracted into
`actor_join_placement_selector.gd`. The Controller still validates its World and
uses the identical five `actor_spawn_0` through `actor_spawn_4` anchors in the
same order. Frame reads its already validated/frozen actual World component and
uses that selector directly. It never calls the legacy synchronous join.

Every candidate passes the existing actual native complete-circle, map-circle,
known-region and same-layer peer tests. No nearest-position search or center
substitution is added. The original technical surface room and its H1 walls stay
unchanged. The 147 underground cells, both actual terrain roots, their artifact
hash, World component, Prefab identities and permanent_changes are unchanged.
The five-anchor ordering remains the prior engineering subset; it is not a claim
that cehua prescribes those five universal spawn points.

## New and retained write sets

Authority still authenticates and prepares the actual join. For a new identity,
Frame seals the new profile, its HOST/MEMBER role from server trust, profile and
actor IDs, secret hash, welcome, and all three newly reserved IDs. The prepared
runtime keeps the original profiles/used IDs; only the prepared-join generation
is consumed. The expected committed runtime adds the three IDs and one peer/
welcome binding. No private welcome or secret appears in prepare/commit results.

Before live mutation, an independent Motion projection creates the actor with
the selected anchor as its initial fallback and then activates it. This derives
the whole initial resource/action record and model revision +2. The existing
Motion prepared presence commits exactly that record. Native preparation still
captures its detached placement effect, and commit compares identity, model and
native effects before allocating exactly the named two bodies and two shapes.

A retained surface actor instead uses its exact saved layer/XY and original
fallback, with the existing resource-resume behavior and revision +1. A blocked
or uncovered original location rejects; neither a nearby anchor nor underground
placement substitutes for it. Already-active joins, injected layer fields,
implicit renaming and occupied retained positions retain their rejection paths.

The same Frame must prove the complete expected model, authority, input and
actual native bindings on the next physics boundary. Its internal surface-route
result is derived from that confirmed actor record, not an independent mutable
routing flag. Only then may the real exact SaveStore path persist the join.

## Production-controlled input transition

For a confirmed new or retained surface join, the actual owner creates a one-use
internal activation proof after its successful real save, binding owner context,
Frame/presence generation, actor/peer and real save sequence/serial. The final
activation implementation itself consumes and validates this proof, including
exact field/type checks. A boolean helper call alone cannot grant the exception.
The ordinary public server-only activation method remains parameterless and
keeps its startup/hello-drain gates.

This narrow internal path permits the host's still-running initial `_ready` and
the remote join's own in-flight hello accounting. It verifies the confirmed Frame
boundary and actual complete native body coverage/environment for every active
actor, then performs a fresh exact save and enables the fixed roster before
returning welcome. Thus a normal client can send its first intent immediately;
the probe does not call activation or manufacture readiness. Retained underground
bootstrap continues to use the prior explicit activation route.

Hello work queued before the roster closed is drained into the same bounded
late-hello rejection path. The current in-flight event remains counted until the
original single cleanup tail; accounting is not reset and then subtracted twice.
Authenticated duplicates do not receive a false welcome that would disconnect
them. General late joins, renaming and disconnect transactions remain outside A.

The expected new-world sequence is initial_world 1, confirmed join 2, automatic
surface activation 3, normal shutdown 4. Reopening that actual save performs no
initial write: resumed join 5, surface activation 6, normal shutdown 7. These
extra activation saves are the existing engineering safety boundary, not a new
source reward, clock advance, resource reset or gameplay rule.

## Bounded evidence

`ActorFreshSurfaceOwnerTest.gd` contains eight methods and eleven sequential,
promptly released fixtures. It exercises real empty Store/owner world creation,
new-ID cancellation and expected writes, next-frame/native confirmation, original
five-anchor selection, independently owned native blockers, three prepared-effect
corruptions, automatic host activation/movement, actual same-directory save/reopen
with retained resources/actions, and an actual blocked-body activation refusal.
Detached exact-owner calls are not ENet or process-exit evidence.

Bootstrap10 keeps all method identities and other negative assertions. Its old
blanket new-profile rejection becomes successful preparation plus cancellation
with no live identity/native allocation. Its surface negative uses an inactive
point still inside the map circle but beyond the original room's native coverage;
legal retained-surface restoration has its positive test in the new suite.

The two separate surface ENet probes cover an actually empty save/identity and a
later reopen of that same real saved directory/private identity. They must use
the normal owner transition, real sender/producer/RPC/cache, complete surface
layer and bounded full-body sweep, then confirmed stop and independent disk
readback. Each gate requires its own parent-owned resource window and cleanup.
Neither gate authorizes missing surface terrain, nearest respawn, speed changes
or a formal playable route to the natural entrance.
