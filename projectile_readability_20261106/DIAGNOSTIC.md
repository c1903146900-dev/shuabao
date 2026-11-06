# Intermittent sampling-gap investigation

The first two full-floor attempts stopped after 42.959 and 38.580 seconds because safety-monitor sampling gaps exceeded the unchanged 200 ms limit. Both exited and were fully cleaned up. Neither was a completed test.

A later comparison reproduced a 419.534 ms sampling gap on the previous enemy_cues02 baseline, which does not contain the new projectile renderer. The unchanged projectile_cues02 then completed the same 45-second diagnostic scenario, with a 96.664 ms maximum gap and clean exit. These short, unequal diagnostic samples do not establish a controlled performance comparison or identify the root cause. An isolated long frame was also observed, so smooth performance is not claimed.

A subsequent serial full-floor run of unchanged projectile_cues02 completed all 12 nodes and the Boss: 190.014131 simulated seconds, 202.079606 wall seconds, exit 0, maximum safety-monitor gap 88.640071 ms, and full process cleanup. Final HP was 315.198393 and gold 395, with nine normal potion purchases and four uses.

The earlier failed runs remain part of the record. No safety thresholds, rendering code or game tuning were changed between these diagnostic and follow-up checks. One successful script-assisted full-floor run does not resolve the intermittent disturbance or establish human, Windows, audio, or subjective feel acceptance. No exact environment or product root cause is asserted. Raw telemetry, system details and process records are not included in this public summary.
