# Boss B warning readability

Candidate boss_cues01 built on frozen dash_timing01. PCK SHA256 de11d5007da04d88af49b3a4707650ff0678c20dd2f5bcbf2df38504632caeea.

## Confirmed normal-combat issue

Following the normal first-floor route to Boss, a15-second positioning/dodge observation captured113 frames. The B wave's dashed locked path was visible,but its source warning-progress ring was centered25 pixels above the Boss feet and rendered behind the Boss sprite. In inspected frame16 the ring was effectively hidden. This removed the timing cue despite an existing1.35-second source warning.

The fix moves only that countdown/direction annotation above the Boss and draws it after actors. A dark backing separates it from environment decoration; viewport-edge clamping keeps the ring visible. It is a screen annotation,not damage geometry. The future-path rails,actual advancing damaging lip,source width/speed/warning time,attack selection and escape admission remain unchanged. No enemy/player numerical tuning changed.

Only boss_wave_effects.gd,presentation.gd,and manifest/generation seals differ from dash_timing01. The _valid snapshot checks,_draw_front and _plate functions are byte-identical to the baseline. No simulation files changed. Current warning badges are cleared each draw and come only from the same validated snapshot as the dashed rails.

## Evidence

Baseline normal-route observation:113 frames/15 seconds,Boss window finished at HP420,guard passed/exit0/full cleanup168.376363204s. Candidate:113 frames/15 seconds,HP420,guard passed/exit0/full cleanup179.558549787s. Both used normal source movement with lateral positioning against the committed warning;no HP/damage or AI overrides. This demonstrates one feasible scripted dodge scenario,not universal player dodgeability or human acceptance.

Candidate frame16 was manually inspected:the progress ring and direction arrow are visible above Boss while the original rails remain clear. Across all113 recorded frames,warning badge count equals validated warning count. All10 warning frames match cast identity and source progress exactly;seven released-front frames contain no stale warning badge. Runtime source validation reported no errors.

Complete-floor follow-up passed as recorded below. Preserve prior passed builds. Dummy audio,Windows execution,human full-floor play,and final user satisfaction remain outside this evidence. No new release is published.


## Full-floor result

Unchanged boss_cues01 passed all12 selected nodes through Boss:188.459401667 simulation seconds,200.299418411 wall seconds,HP420,gold595,eight potions purchased/eight used. Guard passed,exit0,max sample gap0.090124049 seconds,all owned processes reaped. No new script errors. This one scripted normal-combat route is not an exhaustive branch test or human/Windows acceptance.

Source-only overlay after the preserved dash_timing01 runtime. Apply the changed scripts and regenerate binding metadata; required assets remain in the original restoration chain. Public capture copies save to `user://boss_before_frame_*.png` and `user://boss_after_frame_*.png`. No images, logs or runtime packages are included.
