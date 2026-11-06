# Body aiming integrated with mirrored enemy motion

motion_combo05 integrates the independently verified body_aim05 into motion_combo04 by differences. host.gd and puppet_motion.gd retain the isolated input and exact hero-geometry changes. The enemy renderer retains all combo04 pouncer warning/landing, impact events and shooter facing. One signed body_scale is used both by draw_set_transform and by the recorded Transform2D for opaque-pixel picking. Atlas and reaction-sprite records use that transform. It does not overwrite newer motion with an old whole-file implementation.

Package: f722486eef1571faf20c1352226eb20aef489f4cff5003ba13afc02bf5d4b5e9. Independent read-only review verified all243 manifest hashes, generation pin and exact final built-source matches. Only Fengli host/presentation/puppet-motion and manifest/seal differ from combo04. All combat, enemy AI, range, other heroes and progression remain byte-identical. There is no new target ID, nearest-enemy selection or attack-range expansion. The inherited0.12-second click buffer stores a world point, not a following target. Exact hero occlusion, reverse draw order and bilinear source-clamped alpha picking remain intact; effects are not body targets.

## Real OS mouse evidence

Two native sessions used actual desktop pointer motion, timed mouse holds, ordinary Space pause/resume and D movement. The observer only navigated into the room; the second also performed a normal leftward approach before handing over. No HP, enemy, position or combat-state injection. Native event.position and source attack events were recorded separately.

Session01: visible far right-facing pouncer, holding the same pointer after it moved away, left-facing shooter while moving right, a foreground minion overlapping a rear minion, then opposite empty ground. All5 actual attacks matched the current expected body/ground direction. The first hold changed from body target to ground once the actor left the pointer; it did not keep tracking it. The overlapping click selected enemy6 at(1.010019,0,9.24484), ahead of enemy5 at(1.035434,0,8.762131). Far target clicks did not expand the unchanged2.4 attack radius.

Session02: left-facing compressed pouncer at(-4.492341,0,9.49997), transparent space beside a mirrored shooter, the hero's visible hair, then clear ground. The pouncer click mapped to its actual source position. Transparent space initially returned no body; when a shooter later moved underneath the held pointer, the next ordinary attack correctly sampled that new body. The hair click returned no enemy and logged hero_occludes=1; no immediate attack was available for that click, so it is point-selection/occlusion evidence, not a claimed successful cast. All3 actual attacks matched current expected directions, and the final empty-ground attack used ground direction.

Both sessions passed the original guard and cleaned up owned processes. All11 UI checks passed. Screenshots of the real scenes were reviewed. This is bounded native input verification, not manual completion of a full floor or user aesthetic approval. It does not establish every possible pixel/overlap or another hero's runtime aiming.

## Recovery and integration status

Rebuild motion_combo04 through its documented chain, then run rebuild_20261106/build_motion_combo05.py with a fresh output name. Private original inputs/art are required. Old motion_combo04 is preserved. Full-floor outcome follows; do not promote before it passes. The separate Q3 animation candidate remains excluded.

## Final combined full-floor acceptance

FINAL NATURAL_PASS time=157.449999999997 rows=12 HP=315.998392857142 gold=395 purchased=9 used=9 route=["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10a", "r11a", "r12boss"]

The exact combined package passed all12 nodes through Boss under unchanged protection: wall169.388245 s, max gap0.134061 s, exit0 and complete cleanup. No SCRIPT ERROR. Together with the final native mouse, UI and independent code review evidence, motion_combo05 is now the latest functionally verified development baseline. Old motion_combo04 remains untouched for rollback. This does not claim a manual full-floor run, Windows execution, or user aesthetic sign-off.
