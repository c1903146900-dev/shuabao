# 011 reconstruction requirements

Status: requirements reconstructed from the task's retained handoff, NOT original recovered code. Reconcile every numeric/formal rule against the original documents in the restored 010 archive before implementation. Restore 010 v9 first; do not recreate or downgrade its validated implementation from summaries.

## Phase and authority boundaries
- 001–010 have limited internal technical acceptance. 011 remains WIP; 011→011.5→012→013 require joint verification before advancing to014.
- formal_world_allowed remains false. Technical actor proxies do not complete formal artwork, combat015, death/respawn018, or all terrain/ecology.
- Server owns positions, resources, cooldowns, interactions, persistence. Client sends input phases and sequence, never damage, critical result, trusted snapshot, target outcome, or rooted/hit-feedback control state.
- Original player-player body is an axis-aligned square, side0.65. Environmental bodies cannot overlap; visible tree trunk cannot be replaced by its full logical cell.
- Movement and dodge keep full body inside generated circular map, including forced displacement; tangent movement remains possible. Exact auxiliary-box/circle interpretation must be documented rather than silently inferred.

## Original-source values to recheck
Formal workbook62: health100; defense0; food100; food decay0.03/s; low-food threshold30 strict-below; low-food movement multiplier0.7; starvation health loss1/s; energy100; bag40; hotbar10.
Workbook63: movement4.5 cells/s; energy regeneration15/s; delay0.5s after last active consumption; dodge energy25; distance2.4; duration0.28s; invulnerability0.28s; cooldown3s; player diameter0.65; F range1.5; pickup3; gathering5.
Workbook64 D18 is a true Excel boolean, not numeric1. Workbook132 C16 camera ground1; C19 0.35 is zoom transition, not follow damping. Unknown camera pixel scale/deadzone/damping must remain explicit technical display choices.

## Input and temporal models
- WASD8 directions; mouse continuous360 aim; Shift pressed edge performs one dodge, no sprint. Stationary dodge uses last valid movement direction; without movement history cannot dodge.
- Input envelope strict sequence integers, finite bounded aim, discrete movement components, action and phase pair validation. Changed duplicate sequence rejected; exact duplicate cannot repeat pressed action. Stale sequence rejected. Held/released transitions validated and cleared on disconnect.
- Controlled/disabled movement must not overwrite last valid movement direction; held walk resumed after control release updates direction even without a new packet.
- Dodge start consumes once and starts fixed cooldown. Rejection for resources/control/no direction costs nothing. Wall-limited dodge keeps its consumption and cooldown.
- Integrate food, energy and starvation by server elapsed time, independent of partitioning into ticks. Split movement when crossing strict low-food threshold or reaching death time. Dead actor cannot F-interact.
- Reject huge finite clocks before mutation when deadline precision cannot represent meaningful intervals. Validate all candidates before whole-tick commit. A later actor/resolver failure must not retain earlier partial mutations.
- Public state must be explicitly whitelisted, not private actor/profile dictionary copies.

## Spatial collision counterexample
Sequential per-actor sweeps against the other actor's static start are insufficient, even if endpoint AABBs do not overlap. Retained concrete pair:
A start (0,0)
B start (0.6951440689835078,-0.5854194024805233)
Requested A motion (0.14624474260205597,0.12058146466251604)
Requested B motion (-0.11903650933642133,-0.06631129320223333)
Naive resolved A endpoint (0.04514405435903349,0.12058145260436959)
Naive resolved B endpoint (0.5761075596470865,-0.6517306956827567)
Transient overlap occurs around normalized time0.3 despite endpoint separation. Reproduce independently before treating as regression evidence.

Use simultaneous same-time relative AABB continuous collision, native Godot environmental queries, tangent-preserving velocity constraints, and all-actor candidate commit. Test actual trajectories, not endpoint-only separation. Preview must bind to the input/state snapshot; stale preview cannot commit. Bound contact iterations and fail closed on unresolved/nonconvergent state, with no partial save.

## Space and lifecycle
- Space identity uses full world/layer address, not only depth. Actual loaded generated layout plus instantiated Prefab is the authority.
- Offline actors have no active collider. Save layer, parent-local position and fallback. Reconnect restores original static location or nearest legal location if occupied. Do not invent new-player peer-ID formations; bed respawn3-cell rule belongs018.
- New room fixture must preserve original009 fixture bytes. Derive independent fixture_actor011_open_room revision1: remove only wall at [0,2], preserve three H0 floor records; add five explicit spawn anchors at cells [0,0],[-1,0],[1,0],[-1,1],[1,1]. Actor center is cell+0.5. Validate complete0.65 bodies, pair separation and swept exit accessibility. Use existing natural layer connections for F entry; do not invent forbidden central new-layer anchors.
- Existing network bootstrap may require an awaited physics-ready hook before listen/save. Defaults must preserve003/004/010. Physics stepping must not reuse a report-writing interval as the authoritative simulation tick.
- F uses pointer-selected actual same-layer target within1.5; no nearest-target fallback, resources remain left-click. Invalid context/Esc closes contextual group.

## Save and policy
- Preserve actor values and timers exactly through JSON full-precision roundtrip, authority clock and world combined snapshot. Restore inactive then explicitly activate authenticated sessions. Unknown schema/content incompatibility is not corruption and cannot trigger old-backup fallback.
- 011.5 formal package policy is user-controlled. Each formal package has visible game_version and unique internal Build; visible version may stay unchanged. Do not infer allow_old_saves. Unknown schema/epoch/ID semantics or unverifiable compatibility chain fails closed.
- Migration needs immutable verified pre-backup, temporary conversion, full validation, atomic promotion; failure/cancel/interrupt preserves original and old Build. Ordinary balance/text/additive content hash differences cannot automatically imply semantic incompatibility, but removing validation is not a migration plan.

## Revalidation plan
1. After restored original authorities, reconstruct deterministic numeric/asset projection with exact boolean and source-cell provenance; independently audit ranges/trigger distinctions.
2. Reconstruct input/state pure models and original four regressions: food partition, death/F and remaining motion, huge clock, held direction after control release.
3. Pure fixture Python checks plus real PrefabValidator in an approved engine window.
4. Bounded native spatial tests: simultaneous crossing, head-on, parallel, corner/tangent, wall slide, dodge blocked/cost, full-body circle edge, different layers, offline occupancy, whole-batch failure rollback.
5. Combined save roundtrip and authority failure-before-listen/save; authenticated network input/reconciliation; GUI evidence only after separate resource permission.
All rebuilt code needs fresh checks. Historical59/59 cannot be attached to new source. No engine/CUA allowed until parent allocates a new window.
