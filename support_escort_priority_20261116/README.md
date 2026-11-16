# Preserve support escort priority: isolated source proposal

This is NOT an admitted runtime build. No engine, parser, whole-floor, Windows or visual validation occurred. No PCK was generated. The baseline remains byte-identical.

## Source-level regression

Original support movement chooses a nearby living armored guard when hero distance is strictly greater than five metres. The direct-fire sight patch computes that motion, then discards it whenever the hero is occluded: its firing-waypoint branch returns before ordinary escort/navigation is used. This is a demonstrable source control-flow change, not a recorded player-session reproduction. The range-query patch makes more guards discoverable but cannot repair this override.

## Conservative proposal

Set a local following_guard boolean only in the existing escort branch. Use firing-waypoint movement only when not following a guard. Keep the independent blocked-shot attack prohibition unchanged, so restoring escort does not restore shooting into walls. No new query, distance, attack number, role, timer or guard logic is added. Clear stale sight cache when ordinary escort movement resumes, through the existing cache-erasure line. Standard crowd separation and clipped normal navigation remain intact.

Input enemy_director SHA-256: bf6d7226cb3984b04cb2a452011886c1a3fe8f9aa5049a6184413893f5d8e27f. This is the temporary combination of the already-backed-up sight and support-query patches on the 4112 director, not an old packaged candidate.

Proposed enemy_director SHA-256: 324271748dc05975ea5a4e114bef79905bd33db48c8624c900e4dd05ec22da4b.

## Verification and limits

Eighty independent branch-model cases passed, covering support/ranged/pitcher/minion, guard presence/absence, 5m boundary and blocked/open sight. Two changed cases are exactly support + eligible guard + distance above 5m + occlusion. Reverse replacement reconstructs the input source byte-for-byte. Existing sight/route helper functions and guard search were verified unchanged. Published ten-case room-geometry model also passed unchanged. These models do not execute GDScript.

The first preparation attempt failed a source-needle assertion due to incorrect indentation. It did not write the proposed change or touch the baseline; its directory was retained. The second attempt corrected the needle and completed. This is not a runtime failure or pass.

Pending guarded fixtures: living guard behind an obstacle; guard dies or leaves eight-metre search range; hero crosses the 5m threshold; sight clears; guard moves around a corner; held sight route clears on escort activation; multiple support/ranged actors retain separation; ordinary room and whole-floor regression. Observe whether persistent escort can leave support unable to find a firing lane around a stationary guard. This proposal deliberately preserves the original escort priority rather than inventing a new timed fallback.

Keep this source proposal separate until actual-source testing is permitted and succeeds. Existing test/guard restrictions were not retried or bypassed. Files are only local pending any separately verified backup.
