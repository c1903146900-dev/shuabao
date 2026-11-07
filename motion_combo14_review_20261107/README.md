# motion_combo14: accepted development baseline

This adds the isolated Boss body windup/release/settle presentation to accepted combo13. It preserves the alternating ordinary basic returnstroke, ink material, all earlier action improvements, health cues, shared drawing/picking transforms and gameplay mechanisms. No assets, balance values, attack geometry, timing or input rules changed. Combo13 and all candidates remain available.

Build: python3 -I -B rebuild_20261106/build_boss_combo13.py motion_combo14
Pack SHA-256: e7832236116d2a85a724818c782c0bc14f5cdc41e3f2fd0e8b21ee43f88ba702

All 245 runtime files and the pack are byte-identical to the tested boss_motion_combo13_draft01. All 243 manifest entries verified. Relative to combo13, only presentation.gd and its two generated seals differ. Recovery uses the existing public source/build chain and locally authorized original inputs; this is not a standalone asset distribution.

Validated on that exact content:
- bossstrict01: ordinary route, actual H08/E1 dagger/stun cancels a matching Boss warning, fresh neutral pose without fake release; subsequent real sweep release and settle.
- bossfull13a: ordinary 12-node first floor, Boss defeated, HP 315.968393, nine potions purchased/four used. Guard maximum gap 0.116337676 seconds, exit 0, owned cleanup passed.
- bosswave13b: two genuine waves with opposite projected horizontal directions, matched source releases and front advances. First wave finishes and settles; second is paused during its active release, then actual Start/Confirm ends the old run and creates a fresh run. Old cache clears on encounter_finished, old owners retire, and fresh draw frames contain no old Boss pose/front. Guard maximum gap 0.082098357 seconds, wall 170.867511 seconds, exit 0 and cleanup passed.
- bossui13a: all 11 existing player UI checks pass, including learning, map reopen, combat-shop rejection explanation and pause priority. Guard maximum gap 0.054740685 seconds, wall 12.397265 seconds, exit 0 and cleanup passed.

Key live screenshots were visually inspected locally: warning compression, opposite release lean, normal settling and clean fresh initial UI. These are modest body-motion improvements using existing art, not a claim of final aesthetic or human gameplay acceptance. Script-assisted ordinary input/UI does not equal OS-input testing. Pixel picking during the Boss release and menu Resume are not newly tested here; drawing/picking retain the same shared transform.

The failed bosswave13a attempt is retained as a failed observer-navigation check. Its requested waypoint intersected a parapet; no direction evidence was credited. The revised observer uses actual clear geometry and source warning direction, with unchanged credited event/pose/lifecycle requirements. No production fix or relaxed protection was used to pass it.

Only public-safe source, builders, observers and aggregate summaries are backed up. Private assets, captures, raw runtime logs, credentials and personal data are excluded.
