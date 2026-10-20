# Frame CPU profile01 diagnostic delta

Exact reconstruction chain: source06 -> source07 -> source08 -> source09 -> skin16. This branch includes the skin16 original-3D test selection. It does not descend from visual11, visual13, visual15, motion14, skin18 or skin19.

Base PCK SHA-256: 761b094458f6025e876504f9ec677f20e0d98069598c9b3d4c7e1de13757710e (301579304 bytes).
Result PCK SHA-256: 2761e6997363ba41b1b8db841222be7b77d7632bd285a3a1ed3ce9f81143010d (301656868 bytes).

Run `python apply.py --base-pck BASE.pck --output NEW_DIRECTORY`. The output must not exist. All paths, preimage hashes, unique text replacements and complete final PCK bytes are checked. Restoration does not execute game code.

Use --test-original-skin-baseline and --trial-frame-cpu-profile for the B observation. After actual startup admission, arm_frame_cpu_profile starts bounded sampling; frame_cpu_profile_report reads it. Nested times overlap and cannot be added. This is instrumentation, not a game performance optimization or Windows FPS forecast.

Native outcome: entry.gd profiler wrapper indentation caused a parse failure. The strict engine-error guard failed correctly; no valid CPU sample was produced. This failed source and its evidence remain preserved. Profile02 is the separate indentation-only successor.
