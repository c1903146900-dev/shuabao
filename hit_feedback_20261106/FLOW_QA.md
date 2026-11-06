# Combined flow verification

Frozen hit_feedback02 PCK744d7a6f5506d00249d78b9c8194c8529d1e9f4bf0833e24631540b017703994. All241 manifest entries independently rehashed correctly. Only presentation.gd and hit_reaction.gd plus generation/manifest seals differ from prior full-floor-passed projectile_cues02.

Key UI:hitui01 passed11 checks in13.183546140 seconds, exit0/full cleanup. Covers skill guidance, map, shop refusal and pause behavior using the existing player_ui fixture.

Full-floor normal-source combat is NOT complete for this candidate. hitnatural01 reached row8 before guard sample_gap_untrusted:126.719769611 seconds, gap0.241074829, exit-15/full cleanup. A serial unchanged-candidate retry hitnatural02 also reached row8 before the same protection:108.349495613 seconds,gap0.328088722,exit-15/full cleanup. No new script errors were logged. Neither run is counted as a full-floor pass. No guard thresholds, source combat, HP or economy were changed.

Previous diagnostics showed that an older baseline can also trigger sampling gaps, but this does not prove the cause of these two new row8 failures. Further attribution would require focused cost/scheduling evidence; do not dismiss them as definitely environment-only. Immediate repetition was stopped. Keep projectile_cues02 as the last complete-floor-passed baseline and preserve these failed runs. Windows, audio and human full-floor acceptance remain unverified.
