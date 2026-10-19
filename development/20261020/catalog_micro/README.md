# Catalog scalar allocation: reproducible GUI microbenchmark

This evidence tests one proposed allocation reduction against the recovered source06 Catalog. It is not integrated into the game and does not establish game FPS, loading-time, Windows performance, or overall speedup.

## What changed

The original hex_parameter() deep-copies an entire Hex definition and the complete effective-overrides document for each scalar lookup. The candidate takes internal read-only references, deep-copies only the selected parameter, and runs the same scalar extraction. Public getter return values remain independent deep copies. No model/G20 calculations, permissions, world state, or game clock are changed. PATCH.diff is the exact source delta.

For G24, the input JSON trees contain 141 nodes in the definition and 97 in the override document, versus 17 in each selected parameter. These node counts are not memory-byte measurements.

## Actual result

The included report.json is the unchanged native report and contains no local filesystem paths. 4,352 checks passed: 344 Hex cells, 1,032 token spellings, 2,888 hero-rank cells, 152 percent cells, return-value mutation isolation, synthetic overrides, and unchanged source/override data. Official Godot 4.6.3 stable, windowed Linux GUI; exit 0, no SCRIPT ERROR, owned-process cleanup completed. RESULT_SUMMARY.json is a path-free extract of the local postcheck, whose hash is provided.

Four paired warm-cache rounds use AB / BA / AB / BA. Each arm performs 3,000 G24 scalar lookups. Median original 181,253 microseconds; candidate 22,133.5 microseconds, ratio 8.189. This is only the ratio for this getter microbenchmark, not an overall game acceleration. Full round values, checksums and test-loop wall time are retained in report.json. Guard elapsed includes startup and cleanup and is a separate measure.

## Reproduce without duplicating game data in this evidence folder

Requirements: Python 3, official Godot 4.6.3 stable with a GUI display, and an already verified extracted source06 resource tree. INPUTS.json identifies the base PCK by SHA256 and pins the two exact data JSON inputs. No large catalog JSON or game pack is duplicated in this payload. The five small fixture files include exact original/candidate Catalog scripts; they match the tested copies.

1. Verify inputs without writing:

    python build_fixture.py --base-root /path/to/extracted/source06 --verify-only

2. Build a separate project into a NEW directory:

    python build_fixture.py --base-root /path/to/extracted/source06 --output /path/to/new/catalog_fixture

3. Create a fresh evidence output directory, then run using your owned-process timeout/RSS guard and a real GUI display:

    /path/to/official/godot --path /path/to/new/catalog_fixture --audio-driver Dummy -- --evidence=/path/to/fresh/evidence

Do not pass --headless. The runner gives the GUI two frames before checks and exits after writing/reading back report.json. The benchmark intentionally runs synchronously and is not a GUI responsiveness test. Proposed reproduction limits: 60 seconds and 1.5 GiB, with reliable owned-child cleanup. This payload does not install software or launch an engine by itself. The original local run's guard is not bundled, and build_fixture.py is not a process guard.

4. Check exit 0, no engine errors, PASS, identical coverage counts, source_unchanged and override_unchanged true, and verify each checksum. Compare timings only as a microbenchmark under comparable system load.

Synthetic override tests modify only the isolated fixture's Script caches and restore them before timing; no gameplay is instantiated. Invalid ID lookup parity is checked. Intentionally error-producing invalid scalar calls are excluded to keep the engine ERROR gate strict; their original _value implementation remains byte-identical.

## Integration boundary

No authority binding is changed here. Production adoption requires separately validated exact source migration, game-level regression tests and real frame measurements. The recovered raw source is not edited by either this payload or the build script.
