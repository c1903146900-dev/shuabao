# Runtime38 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part007 in numeric order as candidate38_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 858bcbe73ffd137dde23ab4a5020e3abcf7ebcc0cb5cb4d5bfd62bd4686e84f9 before extraction. Archive: 479075 bytes, 27 regular members. PACKAGE_FILES.json SHA256: e28d843dd4c33c6cf6885667614747aca1075f26cc9473631d632f30f9a60e6b.

# Runtime38 SOURCE_ONLY checkpoint delta

Dependency: c1903146900-dev/shuabao commit a4259d5e61734b32d93c89ec6b8b24a75d58d550, development/shuabao/cartoon-source-runtime36-20261016. Restore runtime36 and its documented dependency chain first. This archive is NOT standalone.

11 replacements and 8 additions reconstruct 3251 source/art files. The minimal delta is against publicly backed-up runtime36, so it includes the intervening runtime37 shop 50/72 display fixes and their historical preimage, as well as the reviewed runtime38 source changes. Exact paths and before/after pins are in DELTA.json.

All 90 .godot caches are excluded. Private reference media, profiling tools/libraries/traces, raw test logs, screenshots and credentials are excluded. The local builder and approval plan are not part of the public package. No engine is run for restore verification.

Verify archive/part hashes and unique regular safe relative members, then:

python3 -B restore_sources.py --base-game ../runtime36-restored/game_candidate36 --base-archive ../candidate36_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime38-restored

Replace MANIFEST_SHA256 with the published PACKAGE_FILES.json digest. Output must not exist and its parent must exist. Restore checks complete package/base maps and creates independent files in game_candidate38. Omit --output for read-only verification. Regenerating import caches, running the engine and runtime acceptance are separate steps.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Runtime38 is a source-only integration of runtime37 shop 50/72 display corrections, four reviewed missing-audio source changes and three visually reviewed VFX source changes, with necessary source/visual bindings and historical preimages. Preview74 supports merging the three VFX source changes only; it is not final-art or Q2/E2/R1 functional acceptance. The earlier preview73 run02 short business-flow recording passed 22/22 checks, but its runtime guard remained RED due to eight UID-fallback warnings with backtraces. Runtime38 includes updated UID cache data locally, but every .godot cache file is excluded from this source backup. At the package evidence cutoff, runtime38 had not had an engine run; later verification is recorded separately and is not asserted by this source archive. No claim is made that the UID warnings are fixed at runtime or that runtime38 has passed the guard. Earlier runtime32 original-input first-floor automation was a separate run and peaked at 934.18 MiB, above the original 896 MiB performance limit. No manual full-floor, cross-platform, final-art, whole-runtime or playable-release acceptance is claimed.
