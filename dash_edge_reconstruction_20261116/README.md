# Dash edge-hit reconstruction, 2026-11-16

This is a NEW isolated reconstruction, NOT recovery of the missing 11/14 patch. Public backup tree and recent commit checks found dash timing/trail/pitch work but no confirmed backup of that missing hit fix.

## Proven source discrepancy
Fengli ordinary basic already opts into finite-sector/circular-body intersection. Dash attacks explicitly do not; legacy cone query checks target center angle. Example: target center 1.5m away at 60 degrees, body radius .35m, attack 2m/100 degrees. Body overlaps the 50-degree side edge but old query rejects its center. The existing exact sector helper accepts the body overlap.

## Scope
One predicate assignment now opts both basic and dash into the existing helper; one explanatory comment changes. No new geometry implementation. Shape remains 2m/100 degrees; damage, timing, speed, cooldown, invulnerability and animations unchanged. Newly accepted enemy-body overlap is intended, not a larger nominal sector. Shared/default cone callers unchanged.

Existing dash sweep still performs obstacle visibility (_move_clipped), hit-list deduplication and claim_hit before damage. Those functions are byte-for-byte unchanged, not newly certified by this test. No claim that this fixes all dash misses: temporal gaps between moving cone samples and contact-time behavior are separate unresolved questions. No attempt to sweep over windup or extend range.

## Verification
520 independent Python geometry cases using sampled finite-sector boundary oracle (ambiguous .002m boundary comparisons excluded), mirror symmetry, radial rejection and legacy-hit preservation; 73 additional body-edge overlaps. One explicit nonboundary old-miss/new-hit example. Exact source transformation and source hashes verified. No GDScript execution/parser or engine test. No packaged candidate and no selected baseline change.

Run check_geometry.py --base BASE_RUNTIME --candidate SOURCE_FENGLI_SIM. To recover, apply dash_edge.patch to the pinned flow-trio source and retain the existing pinned sector helper; standard packaging remains a separate step.

Before adoption: real left/right boundary contacts, obstacle separation, repeated sweep frames yielding exactly one damage event, late dash attacks, ordinary attacks, and natural route play must be checked. Static preservation of occlusion/claim code is not gameplay verification.
