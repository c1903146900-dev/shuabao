# 011 joint-preview solver contract

Status: reconstructed source, still WIP. The authorized native run recorded in
`evidence/011core_actor_core_20261005T161840425720Z.log` executed all 49 selected
methods: Geometry 10 passed; JointSolver 38 passed and its final one-ULP helper
test failed the strict magnitude-decrease assertion for a decimal input fixture.
The earlier chain expectation is now confirmed fixed without a solver change.
This last small-value fixture correction has not been rerun; no full actor-suite
or native ActorSpace integration acceptance is claimed.

## Integration

`ActorJointSolver.resolve(preview, environment_query, expected_half_extent, limits = {})` takes the
complete detached `ActorMotion.preview_tick` result. The caller supplies a positive
finite `expected_half_extent` from approved `ActorInputs`; every preview actor must
match it exactly. Never derive this value from RPC input. Current formal diameter
is 0.65, so the approved half extent is 0.325; future authorized table projection
changes remain possible without modifying the solver. Supply a callable matching
`ActorSpace.query_environment_motion(actor_id, start: Vector2, motion: Vector2)`.
It must be a read-only, deterministic query against a stable environment snapshot,
exclude all peer bodies, and bind each actor ID to the preview's full logical
layer. The caller owns that binding; this three-argument query cannot discover a
misregistered actor. An optional returned `layer_key` is checked if present.

The callback returns `{ok: bool, hit: bool, fraction: float, normal: Vector2}`.
A clear query has `fraction = 1`; a hit has a finite fraction in `[0,1]` and a unit
outward normal. Unknown/unmaterialized ground, missing registrations, or native
query failures return `ok = false`, never empty space. Initial zero-motion queries
must confirm placement; a zero-motion hit fails closed rather than depenetrating.
Callbacks are trusted adapter code: the solver cannot roll back side effects made
by a callback. Only pass the read-only adapter, never a mover.

Success returns `positions` for `ActorMotion.commit_preview`, plus a detached
`resolved_positions` alias for inspection. Each record contains only `layer`,
`position`, and `dodge_end_position` when the preview marks an interior dodge-end
boundary. ActorMotion remains responsible for the original preview's serial,
revision, state/input freshness, and atomic model commit. The solver never reads
or writes the model or any physics RID. Native body commit and atomic coordination
between model/body owners are separate integration work.

Failure returns no positions or partially usable trajectory. An adapter failure
is `ENVIRONMENT_QUERY_FAILED` with the adapter's error code in `cause`. Limits
(default 256 event/search iterations and 64 constraint passes) fail closed. Limits
must be positive integers up to 65536; input is also bounded to 256 actors and
4096 total preview segments. Limits are technical resource guards, not gameplay
values. Empty paused previews are accepted; no callback is invoked for them.

## Algorithm and evidence

All segment endpoints from every actor form one common time axis. Each actor's
current phase/velocity is sampled at the beginning of each common interval. Pair
CCD uses the simultaneous relative displacement over the same remaining time,
never a sequential sweep against the other actor's static start. Pair groups use
`Address.key` including world, reference frame, body instance, map kind and depth.
Peer geometry is the approved axis-aligned square (currently side 0.65), with no rotation,
enlargement, push-out, teleport, or recovery displacement.

The earliest peer or native environmental collision advances **every actor** by
the same elapsed time. Simultaneous contacts receive bounded iterative velocity
constraints: peer constraints remove closing normal speed without accelerating
the leader; environment constraints project away inward normal velocity. Tangents
are retained. After changing velocities, all actors and all pairs are queried
again, including zero-time chains. Three-body or peer/wall coupling cannot skip a
later constraint. A no-progress contact or nonconvergence rejects the whole tick.

`trajectory` contains consecutive positive-duration global spans. Each span has
`from`, `to`, and all actors' full `layer`, `from_position`, `to_position`,
`constrained_velocity`, `actual_velocity`, `query_motion`, and preview `phase`.
`constrained_velocity` is the requested velocity after contact constraints.
`actual_velocity` is a two-element array of scalar doubles, computed directly as
each stored endpoint difference divided by the positive span duration. It is not
the unmodified integration operand disguised as the realized velocity.
`query_motion` is the actual Vector2 sent to the final environment callback; its
addition to `from_position` must reconstruct `to_position` exactly.
Interpolation between those endpoints is the actual resolved linear path.
`events` records accepted contact times, participant IDs/normals, and velocities
before/after the constraints. They support checks over the entire motion, not
merely endpoint separation. A dodge boundary is captured at its actual common
boundary position before following walk movement.

Numerically simultaneous fractions within actor_geometry's tolerance are
constrained at the earliest of them, never advanced beyond their earliest hit.
Before publishing any span, the solver checks the entire same-time relative path
between its actual representable endpoints, not just the final positions. Scalar
double endpoint components are used before subtraction; an intermediate Vector2
subtraction must not round away the evidence. The open overlap threshold is exactly
the existing `half_a + half_b - Geometry.POSITION_EPSILON` (currently 0.6499999),
without a larger tolerance or changed gameplay body size. Different full layers
remain isolated in this certification too.

If an event's proposed span fails that check, at most 64 common-time bisections
retain a certified earlier candidate. Safety can be non-monotone across rounding
cells; this search promises a safe retained candidate, not a globally latest one.
Every actor advances by that same accepted elapsed time, with no committed-position
push-out, added speed, or distance compensation. Original
contact normals are applied at the earlier time and the next query uses the true
remaining interval. If the only retained time is `now`, no zero-duration span is
emitted, but those original constraints still apply before querying again. This
also covers an event time that rounds directly to `now` on the double clock.

The event-only retreat is insufficient for ordinary map coordinates: equal-speed
following across 16/32/64/128/256 can round the next contact-free span closed.
Therefore every accepted time, including contact-free intervals, goes through a
second, complete candidate certification before any working position changes:

1. Compute each intended coordinate in scalar double, then round toward that
   actor's current start. This only removes unrepresentable progress; it cannot
   add speed or compensate distance elsewhere.
2. Bound the actual endpoint distance by both the constrained speed and the
   original phase's distance budget. Rebuild a Vector2 query motion. If its
   addition would produce a different endpoint, only a closer-to-start endpoint
   is permitted; at most 16 fitting corrections are attempted. Unreconstructable
   or unbounded candidates fail closed.
3. Check every same-layer pair over its entire actual relative line. A detected
   entry supplies an axis-aligned normal. Limit only candidate coordinate motion
   closing along that normal, choosing the nearest representable reduction that
   restores separation. Never advance a leader, move past an actor's own start,
   or alter the peer-normal's tangent coordinate as part of that peer limit.
4. Rebuild motion after those limits and query the environment for every actor.
   An additional hit may shorten an inward-contributing candidate coordinate
   using the returned safe fraction/normal. That plane is only a proposal: it is
   never a substitute for another native callback query. Unknown geometry or an
   unresolvable/inconsistent response rejects the whole result.
5. Repeat the whole set, including earlier pairs, after any candidate changes.
   Only an unchanged pass with all final queries clear (or safe fraction 1) and
   all continuous peer paths certified may commit the candidate. This uses the
   existing bounded constraint-pass limit; exhaustion is `JOINT_CANDIDATE_LIMIT`.

Candidate limiting consumes the entire accepted span duration. It neither drops
remaining tick time nor changes resource timers. All candidate construction
precedes mutation of detached working positions; no partial positions or trace
escape on failure. Final total displacement and both sides of an interior dodge
boundary are checked against the same preview budgets and existing 1e-5 tolerance
used by ActorMotion; that model and its tolerance are unchanged. No epsilon
forward time step is used to escape zero-time contacts.

For non-axis environment normals, a rounded
projection can retain an inward float32 ULP. Up to 16 representable velocity
components are reduced one ULP toward zero, requiring nonnegative dot products
in both scalar-double and Vector2 arithmetic and no increase in squared speed.
No negative normal tolerance, position push-out, or penetration permission is
introduced. Directed coordinate rounding and environment candidate reductions can
also cause a tiny tangent loss at an oblique wall. Exact arbitrary-normal tangent
preservation, a finite float32 coordinate grid, and strict nonpenetration/no-speed
gain cannot all be promised together. Peer-normal limits preserve that axis's
tangent coordinate, but the overall numerical/environment fitting has this
explicit small loss. Unresolved rounding still fails closed and requires fresh
engine regression execution.

The regression source includes head-on, following, and oblique cases translated
by 0, 10, and 100 cells, a retreat-to-now case near the upper allowed solver clock,
and a direct guard case with separated endpoints but an intersecting interior.
Its independent analytic oracle now uses scalar-double endpoints and the same
1e-7 separation allowance; the former 2e-6 test-only allowance is removed. Every
successful trace is checked over every span, with exact query-motion endpoint reconstruction,
common time coverage, layer isolation, and velocity-budget assertions. There are
39 JointSolver method definitions; their bounded execution status is stated above.
They additionally include
all five ordinary map exponent boundaries, a three-actor rounding chain, captured
final callback motions, reconstruction fitting, an analytic oblique wall,
unverified-corner failure, and actual ActorMotion commit regressions for the
large-coordinate walk and separate dodge/walk budgets.

The three chain endpoints and the large-coordinate walk endpoint are exact
binary32 fixtures, identified by bits `0x416e6a7e`, `0x4178d0e5`, `0x41819ba6`, and
`0x43807999`. Expectations decode those bits to scalar double and still require
strict equality, with no epsilon. This avoids making a binary32 endpoint depend
on decimal-to-double literal conversion. The first native failure printed both
sides of the B endpoint as `15.551000`; GdUnit formats that report with only six
decimals. The next native run confirmed the binary64 mismatch: the actual B bits
were `4624944052578549760`, while the old decimal literal bits were
`4624944052578549759`, exactly one scalar-double ULP lower. The solver and all
collision/distance tolerances are unchanged by these test-fixture corrections.

The remaining one-ULP test's failure was in the strict magnitude comparison, not
its sign assertion. It now decodes explicit binary32 inputs, including positive
and negative `0x1e3ce508` magnitudes near 1e-20, and strictly requires the returned
bits to equal the input bits minus one. The magnitude/sign checks remain. One
diagnostic retains the original long-zero decimal literal's binary64 bits and
both the literal/fixture return bits for the next native run; whether that old
literal parsed as zero remains to be established by that run. Godot 4.6.3
`signf` delegates to `SIGN`, which uses strict positive/negative comparisons,
without an epsilon ([utility implementation](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/variant/variant_utility.cpp#L308-L310),
[SIGN definition](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/typedefs.h#L114-L117)).

A lightweight Python IEEE754 calculation reproduces the old head-on error for
starts (10,0)/(11,0) and velocities +4.5/-4.5: nominal contact gives gap
0.6499996185302734. At starts (100,0)/(101,0), the nominal gap is
0.649993896484375. A separate ordinary-coordinate example starts at 14/15 with
speeds 4.5/2.25: the event-only implementation's later equal-speed span ends at
16.600000381469727/17.25, again giving gap 0.6499996185302734. Candidate limiting
addresses that later span rather than claiming the initial retreat solves it.
For one actor starting at 256.5, speed 4.5 and duration 0.1, nearest rounding moves
0.45001220703125, beyond the model's 0.45 + 1e-5 bound. Directed rounding instead
moves 0.449981689453125. This is mathematical evidence about float32 operations,
not a Godot parse, native test, or environmental validation result.

## Explicit limits

The callback exposes first collision only, not finite wall-end/contact-release
geometry. Reduced velocities are retained for the remainder of the common preview
interval, with fresh requested velocities sampled at its next true boundary.
There is no invented post-wall acceleration or distance compensation. This is
conservative remaining-motion sliding, not a complete persistent contact or rigid
body dynamics solver; it may stop a normal component longer than strictly needed
at a finite wall end. Continuous tangent motion remains available.

The current ActorSpace adapter rejects map-circle-crossing proposals with
`MAP_BOUNDARY_CLIP_REQUIRED`; this solver propagates that failure. Native circle
boundary clipping/tangent queries still require adapter work. Its environment
body remains the existing circle; only peer geometry is fixed to the mandated
square. Underground H0 rows are not evidence of carved/generated air, so the
adapter's unknown underground failure is deliberately retained. Native shape
margins, physics readiness, generated geometry, and formal tree-trunk accuracy
need their own approved engine verification.


## Authorized49-method completion,2026-10-05 16:26UTC
All Geometry10/Joint39 passed on9cc8587, with unchanged solver bytes. Raw evidence011core_runs_20261005T162656988320Z.json. The old B decimal literal was one binary64 ULP below the actual exact binary32 endpoint; the tiny leading-zero literal decoded to binary64zero. Strict bit-defined fixtures resolved these test-domain errors without relaxing solver bounds. This establishes the tested pure solver behavior, not native ActorSpace/world collision integration.
