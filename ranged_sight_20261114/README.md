# Direct-fire sight candidate: isolated, not engine-tested

This patch is based on the isolated 875 combination, not a newly accepted release. QA.json pins the source and candidate. It only changes direct-fire ranged/support line-of-fire readiness and movement around occluding walls. Pitcher lobs, combat numbers, commit budget, other enemy roles, hero skills and room rosters remain unchanged.

Apply direct_fire_sight.patch to a fresh copy of the exact baseline runtime after checking the pinned enemy_director.gd hash. Verify the resulting hash, then use the existing trusted sealing procedure to regenerate manifest, generation, PCK and descriptor. The patch is not itself a runnable game; privately held original inputs and the baseline are still required. No assets, binaries, raw logs, private design files or earlier denied payloads are included.

Static review led to reachable firing-corner goals instead of requiring the enemy to reach the smaller hero's center. The final revision preserves crowd separation, original hero-spacing speed cap and zero-direction fallback, and clears stale normal-navigation cache while occluded. Empty route still waits for recalculation: general freedom from deadlock is not established.

Run geometry_model.py with the actual room_layout.json path as its sole argument. Ten independent Python geometry cases pass: two enemy radii, mirrored corners, changed targets and close-wall hero endpoints. This is not GDScript execution or actor-dynamics testing. deterministic_fixture.gd prepares actual-source synthetic checks for blocked/open lanes, corner egress, moving target, safe steps, no attack threat while occluded and preserved pitcher behavior. It has NOT RUN. No parser, visual, performance, natural-room or whole-floor pass is claimed.

Run engine tests only through the project's unchanged established guard and approved desktop workflow after coordinating an engine slot. No shell display or headless workaround is authorized. Before admission, validate the fixture, multiple-shooter separation, scheduling fairness, pathfinding cost and natural first-floor flow. Preserve the accepted baseline and 875 candidate independently.
