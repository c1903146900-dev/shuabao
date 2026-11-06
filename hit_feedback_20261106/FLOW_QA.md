# Combined flow verification

Frozen hit_feedback02 PCK744d7a6f5506d00249d78b9c8194c8529d1e9f4bf0833e24631540b017703994. All241 manifest entries independently rehashed correctly. Only presentation.gd and hit_reaction.gd plus generation/manifest seals differ from prior full-floor-passed projectile_cues02.

Key UI:hitui01 passed11 checks in13.183546140 seconds, exit0/full cleanup. Covers skill guidance, map, shop refusal and pause behavior using the existing player_ui fixture.

Initial full-floor attempts did not complete; the later production follow-up below did. hitnatural01 reached row8 before guard sample_gap_untrusted:126.719769611 seconds, gap0.241074829, exit-15/full cleanup. A serial unchanged-candidate retry hitnatural02 also reached row8 before the same protection:108.349495613 seconds,gap0.328088722,exit-15/full cleanup. No new script errors were logged. Neither run is counted as a full-floor pass. No guard thresholds, source combat, HP or economy were changed.

Previous diagnostics showed that an older baseline can also trigger sampling gaps, but this does not prove the cause of these two new row8 failures. Further attribution would require focused cost/scheduling evidence; do not dismiss them as definitely environment-only. Immediate repetition was stopped at that stage, with projectile_cues02 retained as the prior passing baseline. The later hit_feedback02 production pass is recorded below; the earlier failures remain preserved. Windows, audio and human full-floor acceptance remain unverified.


## Frozen production follow-up

After the separate cost diagnostic, unchanged production hit_feedback02 passed hitnatural03:all12 nodes through Boss,193.447893000 simulation seconds,205.170903428 wall seconds,HP324.418392857134,gold395,nine potions purchased/six used. Guard passed,exit0,max gap0.120035536 seconds,full cleanup. No instrumentation code was included in this production pack. All241 manifest entries and the frozen PCK hash remain unchanged. Previous failed runs remain valid historical failures,not erased by this pass. Intermittent sampling/long-frame root cause remains unresolved. This is script-assisted normal source combat,not human or Windows acceptance.
