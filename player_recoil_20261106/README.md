# Player body damage response: provisional checkpoint

The health cue made HP loss readable, but the hero body did not react to that source event. This adds a short additive body compression and release using the already validated actual-damage pulse. Maximum additions are 0.035 radians of lean, 1.5 pixels sideways/1 pixel down, and 7 percent horizontal expansion/6 percent vertical compression. It lasts only the existing 0.16-second pulse and cannot accumulate across hits. Ground aim, actual position, facing, action choice, movement, damage, recovery and action clocks are unchanged. This is a small presentation response, not newly authored directional hurt artwork or gameplay hitstun.

Only presentation.gd and generated binding seals differ from player_hurt01. The source health helper remains unchanged. The candidate passed the inherited 243 production-load/helper checks. A normal-source enemy-attack capture produced 38 frames; every rendered response pulse and sequence matched the live health cue, including decay to zero. Impact and settled frames were visually inspected. Both guarded runs passed, exited 0 and fully cleaned up. This is script-assisted evidence, not human quality acceptance.

The new candidate's key-UI run was stopped after 10.291 seconds by the unchanged guard: a 0.2451-second monitoring sample gap exceeded its 0.2-second limit. All owned processes were reaped and the terminal returned idle. The chained near-Boss run therefore never launched. These checks remain unverified, not passed. Further engine runs were paused rather than relaxing safeguards. The preceding health-only Boss observation was stopped in room six by a guard sampling-gap failure; all owned processes were cleaned up. No guard threshold was relaxed. Earlier full-floor passes belong to player_hurt01, not this modified candidate. Windows, hardware audio and final acceptance remain unverified.

## Recovery

Follow ../player_hurt_20261106/README.md to reconstruct player_hurt01, then run from the repository root in a fresh output directory:

    python rebuild_20261106/build_player_recoil.py player_recoil01

Expected runtime pack SHA-256: abb08b97eabde4a969824555636217a3ff2c90ba1aded1dd25850d52fec14692.

The original private archives remain necessary. This source-only checkpoint is not a standalone playable release. No images, assets, recordings, private storage references, diagnostics or internal reports are published here.

## Follow-up: scheduling diagnosis and successful sequential validation

Failed attempts had ample available memory (at least 7.48 GiB), normal median sample gaps around 50 ms, and isolated 245/321 ms gaps. A 45-second no-engine scheduling probe saw low system load and no gap above 200 ms (maximum 164 ms). Host pressure and CPU quota counters were not exposed, so no definitive host-throttling cause is asserted. Safeguards, thresholds and game code were not changed.

A subsequent quiet sequential run, without concurrent builds/uploads, completed all three checks on the unchanged player_recoil01 pack:

- Key UI: 11 checks, 13.822 wall seconds, maximum monitor gap 0.0567 seconds.
- Near-Boss observation: normal route followed by 18 seconds of close positioning; 135 frames, 178.796 wall seconds total, maximum gap 0.1152 seconds. Actual source damage reduced HP to 66.71. The local health cue was present in 60 frames. Inspected impact/settled/low-HP frames show readable health below the overlapping hero and Boss, including recovery/shield effects.
- Complete floor: all 12 selected nodes through Boss, 194.083 simulated seconds / 206.975 wall seconds, HP 420, gold 595, eight potions purchased and eight used; maximum gap 0.1221 seconds.

All three runs passed the existing guard, exited 0, and fully cleaned up owned processes. No SCRIPT ERROR was reported; existing NUL diagnostics remain. Fresh reconstruction also reproduced the exact pack hash above.

Coverage limits: the observed Boss encounter had only one enemy, not a multi-enemy crowd. Its 11 B-wave warning frames did not coincide with the local HP cue, so simultaneous warning/health overlap is not claimed verified. This is script-assisted normal-source testing; Windows, hardware audio, human quality acceptance and new directional hurt artwork remain outside completion. Prior failed guard attempts are retained rather than rewritten as passes.
