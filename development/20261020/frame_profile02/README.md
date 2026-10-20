# Frame CPU profile02 diagnostic delta

Exact reconstruction chain: source06 -> source07 -> source08 -> source09 -> skin16 -> frame_profile01. This branch includes the skin16 original-3D test selection. It does not descend from visual11, visual13, visual15, motion14, skin18 or skin19.

Base PCK SHA-256: 2761e6997363ba41b1b8db841222be7b77d7632bd285a3a1ed3ce9f81143010d (301656868 bytes).
Result PCK SHA-256: b1320d0e2779c7063baf526a0be471a1691795f8cba4d552b3573801f4a4bb32 (301656868 bytes).

Run `python apply.py --base-pck BASE.pck --output NEW_DIRECTORY`. The output must not exist. All paths, preimage hashes, unique text replacements and complete final PCK bytes are checked. Restoration does not execute game code.

Use --test-original-skin-baseline and --trial-frame-cpu-profile for the B observation. After actual startup admission, arm_frame_cpu_profile starts bounded sampling; frame_cpu_profile_report reads it. Nested times overlap and cannot be added. This is instrumentation, not a game performance optimization or Windows FPS forecast.

This delta changes only six new entry.gd wrapper indentation lines to the existing tab style, plus exact seals. Native outcome: 28 bounded CPU frames were collected, with no engine ERROR. The full guard result remains FAIL because its inherited screenshot requirement expected three images while this run was approved for one. Valid timing data is not an overall guard PASS, visual acceptance or proof of a speed improvement. The original failed guard evidence is unchanged.
