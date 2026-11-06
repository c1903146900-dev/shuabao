# Four-enemy health and warning overlap review

The unchanged player_recoil01 candidate was observed through normal first-room entry, real enemy AI, actual incoming damage and script-assisted movement. No enemy positions, HP, damage, clocks or AI were injected or overridden. Existing gameplay, art, action response and HUD were retained.

Two eight-second post-hit observations each produced 75 chronological frames:

- Approach and stop: four enemies converge; 66 frames contain both the player's local HP cue and enemy body-warning annotations. Total guarded run 34.071 seconds, maximum monitoring gap 0.0581 seconds.
- Move through the group and stop: enemies pursue from below; 49 frames contain both cue types. Total guarded run 31.917 seconds, maximum monitoring gap 0.1165 seconds.

Both runs passed the unchanged guard, exited 0 and fully cleaned up owned processes. Inspected approach frames 20/40/68 and crossing frames 30/42/60 show the health bar and number remaining readable while one or two warning annotations are active. The second sequence covers the more constrained lower-side pursuit layout. Enemy artwork can appear behind the HP text, but the existing dark outline remains readable in the inspected frames. No new indicators were added and no HUD movement was justified by these observations.

A supplemental conservative screen-coordinate envelope check used the HP bar/text area and a 23.5-pixel radius bounding the warning ring and pointer. The minimum separation in the crossing sequence was 6.31 design-space pixels; this supports the observed non-overlap but is not an exhaustive pixel-occlusion proof. These are sampled normal-combat cases, not every relative position or viewport scale.

Coverage remains limited to four first-room melee enemies, not all mixed enemy types, dense multi-enemy Boss encounters or every Boss warning combination. The previous near-Boss observation and complete-floor tests remain separate evidence. Human play, Windows, hardware audio and final quality acceptance remain unverified. Raw captures, diagnostics, private references and assets are not published in this source-only evidence update.
