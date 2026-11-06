# E1 first-throw follow-up observation

After the combined walking/minion baseline passed its complete floor and UI checks, a normal-input E1 first-throw probe was performed. The first probe aimed from outside a valid target range and received no_target, so its completed guard run is not casting evidence. The corrected observer walked toward the nearest existing enemy, then requested E within four units; the request was accepted with cast_id 1. No position or skill-state injection.

The actual 45-frame sequence was viewed: rear dagger preparation at source age 0, front release at 0.10, recovery at 0.18 and idle by 0.283 observer seconds. A source dagger visibly reaches its target during the recovery. This is a fast three-pose throw, not the long held R1 problem already fixed. It offers less obvious immediate improvement than that earlier issue, so no speculative stretch of its timing or replacement of the source projectile was made. A future arm-travel experiment should remain isolated and preserve this very short release window rather than slowing gameplay for animation.

Guard passed unchanged: wall 19.217848 seconds, max gap 0.054352 seconds, peak RSS+swap 532623360 bytes, exit 0, owned processes cleaned up, no SCRIPT ERROR or visual receipt errors. Existing NUL diagnostics remain. This is observation, not a new implemented skill change or human aesthetic acceptance.

The public observer writes to user://throw_motion/before02; create output directory first and use the documented guard. Screenshots and raw logs remain private. The checked baseline is motion_combo02; no new candidate is merged here.
