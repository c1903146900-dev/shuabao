# Independent base R2 ground peaks

This candidate implements source/API mechanics above the exact E1 reform-pause
leaf. It does not open the ordinary chooser, change the host, learn R early,
provide a short ultimate presentation, or claim visual/balance acceptance.

## Authorities actually read

- Original DOCX, all-body-descendant paragraph 87 (one-based), and original XLSX
  `晏归舟技能!E87:H98`, compared to `data/final_design/catalog.json`
- User decision `Sentinel_0a6789080ce48191abd8a74885876fd3`, retained verbatim in
  `docs/source_decisions/20261006-ink-five-resolutions.json`
- Explicit single-candidate authoring `data/combat/ink_r2_peak_authoring.json`,
  SHA256 `d11c59f5e7b680d61e8aacd7fa90a406820086c1cc74d59c97582cacb0862002`
- Existing `tests/ink_r2_explicit_structure_20261006/reference_notes.md`. Its
  official references were text-only; no reference pixels were inspected here
- No applicable ancestor or scoped AGENTS.md was present. No engine, CUA,
  Blender, alternate sandbox, or excluded session source was accessed

The newest user decision replaces angle-driven strokes and old count inference.
The explicit authoring table replaces the older overlay's still-proposed kD/N
schedule, 18x4 footprint, and old line damage. Nonconflicting originals remain:
12m center placement, radii 10/10.54/11.5/13m, duration 5/5.5/6.5/8s, 0.3s peak
body, original rollup 300/420/720/1150 +220/260/340/470% AP, and cooldown
145/136/121/101s. Source files and original H15/H16 definitions are untouched.

## Explicit production conventions and limits

Exactly N=7/9/13/20 warning ordinals use s_i=i*(D-.48)/(N-1). Warning .18s,
body .30s, one hit at .24s, fade .32s, disappear .48s. The last disappearance
uses the exact original deadline, before one rollup and one cast completion.
One visual cluster remains one ordinal. No angle, solid collider, pull, push,
slow, stun or other new control is implemented.

Each warning scores eligible enemy centers and pair midpoints. It chooses the
most bodies within this finite candidate set, ties by x/z then stable actor IDs,
without claiming a continuous-space global optimum or adding Boss weights.
Candidates remain inside the original fixed domain. The initial reference
proposal mentioned room legality; review found no original R2 basis to inherit
E3 actor-landing restrictions, so this implementation adds no room/wall rejection.
Original 12m area-placement eligibility and fixed-domain clipping remain.

Peak damage requires the actual intersection of enemy body, peak disk and fixed
domain disk. This avoids domain-edge damage caused by merely checking the two
pairwise overlaps separately. All geometry uses scalar float64 arithmetic over
original stored Vector3 components. Input-point containment and pairwise external
rejection are strict, without EPS expansion. Only reconstructed circle vertices
allow numerical residual bounded at 64 binary64 epsilon times squared operand
scale; this is a local operation-error guard, not a gameplay radius. Finite
fixtures include exact boundary, next representable float32 exterior point, and
pairwise-overlapping disks with no common intersection. This does not claim an
arbitrary-precision computational-geometry proof.

The chosen center locks at warning. Hit-time membership is read once from live
current actors. A callback pause preserves that admitted target snapshot/cursor;
it does not refresh targets on resume. Each original identity is still checked
before dispatch; an old body cannot transfer membership to a same-ID replacement.
A harmless empty selection consumes its ordinal, even if an enemy enters before
its hit time. Each subsequent warning re-evaluates density independently.

Nominal peak/rollup AP is snapshotted at accepted cast, matching the existing
cast-snapshot convention. Impact penetration and lifesteal are snapshotted when
that hit batch is admitted. All packets use inherited damage_enemy/common/HP,
kill and healing services. Receipts capture actual committed damage before any
callback or nested damage, not after-the-fact HP subtraction. R2 never enters
Q/E P1 or P2 entitlement and does not consume or count a P2 use.

World schedule uses clock.world_time exclusively, including future presentation
integration. There is one inherited fixed step; no new clock, Engine.time_scale,
private real-time world, or artificial replay step. Held pause consumes nothing.
Death, room retirement, and cancel discard active state/batch without compensation.
Entry spends original cooldown once; completion/cancellation never restarts it.
The lifetime prevents early victory from truncating an accepted normal full cast.
H15/H16 remain unavailable through the inherited Hex gate; source definitions
are preserved for separate complete implementation. Learning at level 6 remains
future ordinary-layer work and is not modified here.

Authored 2m radius and 40/55/80/120 +25/30/40/50% AP peaks are explicitly
unbalanced production values. This candidate provides no art/audio or ordinary
input acceptance. All engine runs belong to the coordinator.
