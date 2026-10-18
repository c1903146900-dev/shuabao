# Front motion inspection 01

This is a newly authored asset-inspection prototype, not recovered production code or a live Sim test.

## Original assets
- upper_q1_eight_original.png: c5230883ccce96db9ec74f36379fc6401e1093770980453fd3d447bbc2ad1494
- lower_idle_walk_nine_original.png: 485eea12c243aa71cd06e91b33a3878ae5315c18f99ab08fa46bd3d8944451a8
Original PNG bytes are unchanged. The lower nine-picture sheet FAILED as an eight-step walk: most pictures repeat the same leading foot. Only its first neutral cell is used by this prototype.

## Alpha inspection
The apparent gray/brown background in raw previews is RGB behind zero alpha. White and dark compositing inspections show no broad opaque background. No alpha thresholding, recoloring or background deletion has been applied. Detailed pixel counts are in ALPHA_INSPECTION.json. Soft antialiased edges still require actual final shader inspection.

## Playable inspection
Open preview.html with its adjacent preview.js and the two original PNGs. It has dark/white/ground backgrounds, pause, upper-frame stepping, phase/progress control, and simultaneous 240px stationary / 240px moving-lower / 60px views. No frame crossfade is used. Canvas upper animation currently switches the authored cells; it is intentionally NOT accepted as continuous motion.

Lower pants use one continuous UV mesh: fixed waist, smooth leg field, whole-shoe translation. Numerical 361-phase sampling checks 131404 triangles without inversion, with shoe translation residual 2.84e-14. This does not prove visible seam quality. Top of pants is covered by the robe, with manually provisional waist registrations.

Known defects to inspect and fix:
1. Upper frame 6 (seventh picture) raises the brush overhead during return. This is a known return-path defect, not an intentional attack.
2. Upper cell proportions and waist locations are provisional; torso/head silhouette may jump at switches.
3. Eight upper pictures alone do not prove smooth animation. Continuous playback must identify where additional in-betweens or a coherent warp are needed. Do not disguise differences with crossfade.
4. Canvas triangle clip edges and 60px filtering require visual inspection.

## Timing authority
The replay's drag (.8s) and hold (.5s) are illustrative player-input intervals, not changes to skill timing. Release duration .6000000238418579 is read from the recovered original recovery08/runtime_fix01/source_boundaries.json, clip q1_recovery08_release_upper. Actual integration must read the original accepted release event and actual source/actor phase; the preview never dispatches gameplay input, damage, cooldowns or world effects. Loop idle is merely inspection spacing.

## Actual validation and blockers
- node --check preview.js: passed.
- check_mesh.cjs executes the exact preview legVertex function: passed, MESH_CHECK.json.
- White/dark diagnostic composites visually inspected: no broad painted background.
- Continuous browser playback NOT yet observed. Isolated Chromium could not launch under current socket restrictions; standard elevated execution failed during environment setup. Official cloud browser rejected local file:// protocol. No security setting was changed.
- No Godot, live Sim, world-depth or production-shader test has run. No mother-source file was changed.
