# 011 reconnect: bounded peer-occupancy candidate step (design, unimplemented)

Authority: `011_BOUNDARY_RECONNECT_GAPS.md` direct original references P421/P426 and sheet134 C2. No grid snapping, arbitrary search radius, respawn fallback, or original-mechanism change is authorized by this design.

## First supported subset

Preserve the retained full layer and exact original Vector2 when current complete-body placement succeeds. If it fails specifically with `PEER_OCCUPIED`, consider the complement of all active same-layer peer forbidden AABBs, using the production overlap predicate and full0.65side, not environmental circle substitution. Other failures remain explicit, including absent layer/unknown terrain/environment not ready. New-player anchor selection is unchanged.

Find the globally nearest peer-free representable position to the retained original position in this relaxed plane. For each axis, collect the original coordinate plus the actual representable transition points of every peer forbidden interval. Obtain those transitions by bounded binary search over ordered finite binary32 encodings using the exact scalar production predicate; do not infer them merely by rounding a mathematical edge. Enumerate Cartesian products, filter with the actual overlap predicate, and select the minimum squared scalar-double distance from the original. Check every tied minimum against the actual environmental circle, known-coverage and native environment predicate; stable x then y orders equal minima without depending on peer insertion order.

If at least one global relaxed minimum is fully legal, it is also a minimum of the full legal subset. If none is fully legal, return unresolved. Do not select a farther point from an incomplete candidate list and claim it is the nearest environmental placement. This subset does not solve reconnect inside newly built walls or the combined rectangle/circle obstacle arrangement.

## Completeness claim to review

For a point outside the finite union of open axis-aligned forbidden rectangles, the cell of the arrangement containing it has independent x/y intervals. Minimizing distance to the origin over the cell takes the origin coordinate if present, otherwise the nearest interval edge. Therefore a continuous minimum is on the Cartesian coordinate set of original projections and rectangle edges. On the binary32 coordinate lattice, obtain each actual predicate transition directly. Map finite float32 to ordered uint32 keys (negative bits inverted, nonnegative sign bit toggled), bracket from finite negative maximum to peer coordinate and from peer coordinate to finite positive maximum, and binary-search last outside/first outside, each within32 bisections. Signed zeros may duplicate coordinates but must not alter original-position identity. Validate endpoints and adjacent transition membership. Never discard alternative tied minima before native checks.

`Geometry.overlaps` uses scalar `a.x-b.x` / `a.y-b.y` comparisons, not a pre-rounded Vector2 difference. Its existing POSITION_EPSILON remains unchanged. Candidate arithmetic and distance must reject nonfinite/unrepresentable values and must not pretend arbitrary precision. Strict squared-double comparison has no new approximate tie tolerance. Source reviewer must verify the lattice argument and the exact predicate before implementation.

## Work and transaction boundary

Current formal max players is5 (`136_联机与存档!B2`); an offline reconnect normally faces at most4 online peers. Limit computational candidates/comparisons explicitly before enumeration; exceeding a technical work budget returns unresolved, never respawns or picks a first partial candidate. Work budget is not a game search radius or maximum allowed travel distance. Do not allocate all candidate dictionaries when a bounded scan suffices.

Use detached authoritative peer records with exact full Address.key. The chosen coordinate still enters existing identity/presence/native prepared tickets and immediate three-read-set validation. No read-only candidate step may allocate native actor RIDs, advance clocks, save, publish, rebind identity, alter fallback position, reset cooldown, or change retained resource values. A join can fail without modifying existing online players.

## Small required counterexample set

- Legal fractional original position returns exactly unchanged before any enumeration
- One centered peer: nearest continuous edge is closer than an arbitrary cell-center or spawn anchor; all tied directions considered
- Overlapping two peer rectangles: a closest edge projection may remain blocked; intersection/corner candidate must be included
- A closer candidate after a farther candidate in input order wins; reversing peer order gives identical result
- Other map layer/body/world peers do not block the retained layer
- Full AABB overlap, exact boundary contact, and float32-neighbor cases around16/32/400; no center-only legal test
- Nearest peer-free group all blocked by environment or unknown coverage: explicit unresolved even if some farther enumerated candidate is legal
- Several equal nearest points with one environment-legal: select that legal minimum; no callback-order-dependent tie
- Exhausted work budget, invalid peer geometry, callback failure, stale placement/identity/presence tickets: no partial join or save
- Real native peer occupying a disconnected player's coordinate: same identity resumes nearby and at original-layer minimum; empty original still restores exactly

The pure candidate source and10 tests have now been authored; none have run in Godot yet. Current accepted evidence is only the preceding limited circle-boundary integration; overall011 is incomplete.

### Source-review correction before implementation
Mathematical interval boundaries and their immediate float32 neighbors alone are insufficient for a general parameterized scalar-predicate guarantee: even scalar subtraction rounds. For E=1, peer.x=1, origin.x=2^-52, x=2^-54 can still compare non-overlapping because abs(x-1) rounds to1, yet is closer than mathematical edge0. Direct finite-key predicate-transition search closes this without a new epsilon or terrain assumption. Current formal extent is unchanged. With at most4 current peers, each axis has at most9 unique coordinates and the Cartesian product has at most81; explicit work limits still fail unresolved before a partial answer.

### Pure-source checkpoint
`actor_peer_reconnect.gd` directly searches canonical finite binary32 keys (both signed zeros collapsed for axis enumeration; legal original returns its original Vector2). Each result contains all exact minimum ties in the finite Cartesian candidate set. This does not enumerate every other binary32 lattice point whose squared double distance may round to the same value. If all returned minima fail environment checks, unresolved remains correct; do not claim no other equal-distance environment placement exists. Distances use strict scalar float64 arithmetic, not exact real Euclidean geometry.
Ten source tests cover fractional original, four-way ties, scalar-versus-Vector2 subtraction, synthetic cancellation, signed outward transitions at10, two-peer corner, ordering, work budget, finite extremes and invalid inputs. No environment/native/controller join change is made. The standalone profile runs only these10; 83 Python driver/mock tests pass, no runtime claim.

### Production subset wiring candidate, not yet run
ActorSpace.nearest_peer_reconnect uses complete original placement first, enters onlyPEER_OCCUPIED, filters all active peers by retained Address.key and validates sorted minimum candidates through production complete-body/native/known-region placement. No tickets, body allocation or runtime state mutation occurs during search. Controller only invokes this subset for that exact reason; it requires the same retained layer and a Vector2 return, then uses the unchanged three prepared identity/presence/native tickets and validation/commit order. Old fallback/resource/cooldown state is not reset.
New Placement6 seam methods substitute only full-placement checks and exercise production enumeration. NativeJoin now10 methods: occupied resume now tests successful same-profile/actor relocation, unchanged occupantinput/latch/resource/RIDs/profile/clock, and a new real small-static-blockers fixture rejects when all nearest candidates are blocked although a farther point exists. Unknown underground and unchanged original restore tests retained. Scope is33 pure composition then10 native, singleGodot/192MiB/effective900/raw192/45command110total; new window required.84 Python driver/mock tests pass, GDScript integration unrun.

### 01:28 limited source/native verification recorded
Pure10 passed with complete guard exit at124f295 (prior engine-pass/guard-red retained). Integration7849def passed33 composition plus10 actual native. Evidence and cleanup are in011_RECONSTRUCTION_RUNTIME_RESULTS. These results support only the documented peer-occupied subset and complete-minimum environmental refusal, not a general rectangle/circle environment nearest solver.
Next finite test uses existing production ENet scene: one dedicated server, A first joins and exits, B new profile occupies the old coordinate, A resumes existing private local identity under a new connection. Total4 distinct PIDs, peak3 engines; actual client cache consumption, identity/layer/nearest placement, final exactsave/pause and cleanup are required. No game input/GUI/restart replay is included; driver is unrun.

### Four-PID ENet driver source frozen, unrun
`probe_actor011_reconnect.py` now implements the bounded sequence. A/B one-client reports are legitimatelyclient_waiting_for_players because existinglaunch expects2; separate strict single-cache validation checks accepted actualcache/count/revisions/nativeclock bits and laterprogress. Dual-client stage uses existing strictvalidator unchanged. Resume secret is copied only between exclusive private files in this test runtime, never printed or included in evidence. All children inherit onePGID; at most3live,4distincttotal. Active deadline76seconds reserves shared6seconds TERM/KILL/reap within82; outer command90/total110.
Exact report-clock checks rely on current network_main._write_report full_precision=true; this is not the old default-precision SaveStore path. Both cached/reported nativebits and reportdecimal roundtrip must match; final exactsave authority/actor/pausedreportclock equality and last observed nativecache lower bound are strict. Synthetic1ULP report mismatch is a rejection test, not observed production corruption.
17new mock tests and combined169 relevant driver/guard tests passed. The unique delayed desktop entry is --actor011-reconnect-network, wholePGID384MiB/effective900/raw192. No native process has run this new driver yet.

### Guard-red diagnostic retry candidate, unrun
Prior4PID actualsame-identity/minimum/final-cache partial evidence is protected; whole run remains failed. MissingRSS failure now records PID and both statusState/Threads plusidentity/RSSlines, without changing failclosed behavior. Driver catches its ownSIGTERM, marks failed, retains a6second shared cleanup reserve, and suppresses repeated termination exceptions while cleanup runs. Child registration is protected until returnedPopen is recorded, and caught (notSIG_IGN) parent handlers preserve default execchild behavior. Even failed evidence writes cannot prevent mandatory cleanup_owned in innerfinally.
Atomic whitelisted checkpoints persist reconnect/cacheprogress before client normalstop, plus requested/completed stop stages.22driver mocks and175combined relevant mocks pass including leader/child lifecycles, repeatedTERM, registration, evidencewrite failure and childreap. Game/geometry/identity assertions and384/900/raw19290/110 remain unchanged. Same real scenario must be rerun only with a new root window, once.
