# Natural-entry terrain and active-transfer plan

Read-only source design after the first F-input/candidate slice. No materializer, native support extension, persistent schema change or layer-transfer implementation is claimed. F continues to return INTERACTION_TRANSFER_UNSUPPORTED after valid selection.

## Original authority and present gap

The original document references used here are top-level body paragraph numbers: cehua 65, 68–70 and 74–75. Existing extraction reports that also count table paragraphs call the corresponding paragraphs 171, 174–176 and 180–181. Keep the convention explicit when citing them. They require underground H1 before carving, paired same-XY natural entries, protected surroundings and ordered world generation.

Formal shuzhi cells 38!J6:P6 and O7:P7 supply the connection counts/distances and 3×3 body / 7×7 safety dimensions. Cells 63!C10:C11 supply actor diameter 0.65 and F range 1.5. Ground/rock IDs are in 32!X9:Y17; 32!S9:S12 and W9:W12 prohibit random geological H1 surface entities. 145!F2 specifies an ordinary rock's 1×1×1 occupancy. These source constraints do not imply that all unspecified surface terrain is empty.

Generation007 currently stores biome sites, natural connections and permanent-change metadata. It does not implement authoritative per-cell terrain, cave carving or an occupancy cache; its generation-stage declaration still marks base_terrain incomplete. Better Terrain and visual_decal_cache are presentation-only. WorldComponent.technical_clear_cell is an operator seam, not a generator and not a permitted F effect. ActorSpace currently certifies only the existing surface Prefab; underground is deliberately unknown.

## Smallest next code slice

Implement a detached, versioned bounded occupancy artifact and validator. Do not connect it to ActorSpace, saves or F yet. Link it to original source hashes, layout fingerprint, world/layer identities, generation-stage identity and the existing stable connection IDs.

Every declared region must account for every cell and its required occupancy categories: source ground ID, underground default rock, explicit generation-time carving, existing Prefab obstacles and applied permanent changes. Missing coverage or an unresolved required category remains unknown and cannot produce a native-clear certificate. Unknown must not be represented by an absent H1 row or a new empty bounds rectangle.

Use the actual seed42 connections:
- Surface ↔ underground1: cell [23,78], body [22,77,3,3], safety [20,75,7,7]
- Underground1 ↔ underground2: cell [37,69], body [36,68,3,3], safety [34,66,7,7]

Materialize both endpoints of each connection. A useful bounded surface work region is [1,75,26,20], the bounding union of the existing Prefab [1,82,17,13] and entry0 safety. This is a technical implementation scope, not a new gameplay boundary or a prescribed corridor. Retain the original room walls and southern doorway. The region is not certified until its required occupancy has been resolved.

Underground must explicitly start with source-backed H1 rock. Apply the original protected entry openings as world-generation operations, with connection provenance, before random population. Keep generated carve operations separate from player permanent changes. Resolve enough surrounding rock cells to define a real boundary around the protected area. Do not carve on F and do not invent a tunnel between the two underground1 openings; the original permits disconnected caves.

Per-cell biome assignment is also missing. Nearest-site assignment with stable ties is a possible technical algorithm, but it is not established by the original cells reviewed here and must not be silently labeled an original rule or allowed to violate source area/content rules. The first contract can require explicitly resolved, source-valid biome inputs and refuse incomplete terrain. Incomplete liquids/ecology/cave stages remain declared incomplete; formal_world_allowed stays false.

Pure tests should establish source/fingerprint binding, deterministic structured output, exact 49-cell safety masks, explicit rock outside generated cutouts where that stage is resolved, retained Prefab walls, complete cell/category accounting, unknown refusal, malformed data rejection and unchanged input documents. A source-only fixture is not a traversable world.

## Persistence and native materialization milestones

Persist actual resolved occupancy and operations, not merely a seed that is regenerated on load. Restoration must not call the generator/random source/carver. Permanent changes must survive and never be confused with generated cutouts.

WorldComponent.FIELDS, combined saves and ActorClientState currently reject unknown contracts/fields; the actor save schema is 3 and wire contract is lifecycle-v2. Runtime terrain requires an explicit coordinated version/content change in world, save, client validators and approved bundle identity. No silent old-save upgrade or inferred permission to generate missing old terrain is allowed. The detached first artifact changes none of these contracts.

Only validated, complete artifact regions may create native static rock/obstacle bodies and coverage certificates. Prewarm and verify their physics readiness before use. Preserve the conservative _covered_sweep rule: adjacent bounds do not prove complete-body traversal across a seam. A fully resolved covering region may certify the approach. Verify doorway-to-entry traversal, carved clear interiors, boundary rocks, circle containment, cleanup and existing fixture-wall regressions in a separate bounded native window.

## Dedicated active-actor transfer milestone

ActorMotion.commit_preview and ActorSpace.prepare_positions currently prohibit layer changes. Add separate owner/generation-bound prepare, validate, commit and cancel operations rather than weakening general movement or using inactive activation/deactivation.

A prepared transfer binds authenticated actor, consumed F edge/input generation, selected connection/direction, source and destination full layer identities, source position and revisions/clock, terrain fingerprint, native occupancy generation and destination readiness. Validate the complete destination environment circle and peer AABBs, excluding only the actor being transferred. Unknown, stale, blocked and unready destinations fail before mutation.

Preserving the actor's current XY is the existing conservative spatial-lab convention. Original endpoint XY equality does not independently prescribe off-center actor landing coordinates. Record this distinction before implementing the transaction.

Preserve actor/profile/body identities, resources and anchors, absolute cooldown/deadline values, dodge history, input latch/sequence/generation, fallback and active presence. Change only the intended layer and normal monotonic revisions. Do not restore a save into a live epoch or use deactivate/activate, which would reset input/resource semantics.

Commit the model layer and both existing native body-space bindings at one explicit physics-owner boundary, with no await, callback, save or broadcast inside the synchronous mutation. Extend applied-target verification to inspect actual native body spaces and both transforms. Bookkeeping alone is insufficient. Transfers cannot be committed arbitrarily from an RPC/process callback: existing movement already requires a next-physics-frame readiness check. The eventual staging/publication boundary must preserve elapsed authoritative time and input bookkeeping; no new global pause is approved as a workaround.

Ordinary preparation failure leaves source state intact apart from the already-consumed edge. Post-submission rollback must restore both source bindings/transforms and model state using a dedicated monotonic transaction, not revision rewind or save reload. Until backend application or restoration is proved, do not publish or save a mixed/pending state. If restoration cannot be proved, fail closed without saving and retain the durable save. These phase/rollback guarantees need real native tests before F is wired to transfer.

## Finite acceptance order

1. Detached occupancy materializer/validator and reviewable actual-location artifact
2. Explicit persistence contract, restore without regeneration, compatibility refusal
3. Native region materialization, approach coverage and physics readiness
4. Pure transfer ticket/state preservation and injected failure/rollback tests
5. Native transfer in both directions, both RIDs, peer changes, phase interleavings and disconnect/shutdown
6. Snapshot/save/reconnect and separately allocated real-input entry tests, with terrain/entry proxies from the same records

None of these later stages is complete merely because the first F selector identifies an entry.
