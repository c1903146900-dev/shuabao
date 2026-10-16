# Production map-projection cache overlay

Frozen 2026-10-16 16:40 UTC. Single-source delta: fengli_route_rest_20261016/room.gd, 13261 bytes. The frozen combined candidate was not modified in place. Applying this delta produces an independent 3280-file source tree with exactly one changed hash.

## Change and test boundary

Hidden maps skip presentation. Visible maps reuse an exact semantic projection signature; a fresh projection is flushed before re-showing hidden buttons. Route binding identity invalidates the cache. Original resize behavior and original present arguments are retained. The overlay changes no movement, attack, AI, reward, rest or route authority rules. The exact source diff is support/fix_source/room.patch; the production source contains no performance instrumentation.

Performance evidence comes from separate instrumented A/B projects. A is run02; B is run_B01. B_SEAL records that only its instrumented room.gd changed from A, with the same probe/observer. The pure production overlay has a different SHA from the instrumented measured B file; fix_source/manifest.json correctly retains engine_run:false. The measurements validate the isolated caching change under that test setup, not a direct engine run of this exact uninstrumented production snapshot.

The B tail window was 20.013 seconds in total: approximately 12.684 seconds of actual combat followed by 7.329 seconds after real defeat. It is not 20 seconds of continuous combat. Within actual combat, reported FPS median improved from A's 1 to B's 40, and map presentation calls were zero. Whole-tail or post-defeat statistics must not be substituted for actual-combat statistics. AB_PERFORMANCE_ANALYSIS.json retains the detailed phase/segment calculations and input-pin checks. This is not a 60-FPS guarantee, all-hardware claim, complete manual clear, whole-floor acceptance or final production performance certification.

AB_RUN_EVIDENCE.json preserves source pins, exit observations and hashes/sizes of the local raw logs and performance traces. Full raw logs, trace payloads and isolated A/B project copies are excluded. The production-overlay manifest and instrumented A/B patch/seal remain distinct so measured source identity is not conflated with the restore target.

## Dependency and exact restore

Repository c1903146900-dev/shuabao; required base commit f629ff8a7d139542e13e4a45aa2fc5c0307c4cad, development/shuabao/recovery-cross-room-20261016/ui02-modal-fix. Restore that checkpoint and its documented chain first. Required base TARGET_SOURCE_MAP.json SHA256: af6bc3ba223b74dcfa8c49f7fe81dff3a79010ab88037960f5df08a2eb045a5f. This delta is not standalone.

Join archive.part files in numeric order and verify every part/full archive using ARCHIVE_PARTS.json. Extract only unique regular safe-relative members, rejecting links, absolute paths and parent traversal. Then:

    python3 -B restore_sources.py --base-game /path/to/restored-ui02-game --base-map /path/to/ui02-package/TARGET_SOURCE_MAP.json --output /path/to/new-mapcache-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. The script validates the complete package, all 3280 base hashes, the exact before/after room hash, and all 3280 independent output hashes while preserving the base. Target map SHA256: 823e30fb59a7ea38495968ef17b6656e4ef873a6ec07d711d91cd8431a645415. A local independent restoration passed all 3280 source hashes. No engine is invoked during restoration.

Excluded: imported caches, .godot/.local, raw logs and profiling traces, isolated A/B copies, user data, credentials, private media and engine binaries. Prior backup packages and main are unchanged. Remote blob SHA/size verification is distinct from downloading and restoring a second remote copy; no such round trip is claimed.
