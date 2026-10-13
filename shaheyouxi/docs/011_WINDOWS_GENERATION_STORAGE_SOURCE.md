# Ordinary Windows generation storage (source candidate)

This is an explicit storage layout for new ordinary Windows slots only. It is not a migration of existing `main.json` archives, a formal Build, or evidence that a Windows executable has run. Linux/default SaveStore behavior remains on its existing file path. The actual `SandboxSaveStore` script and full schema4/terrain validator remain authoritative; an adapter cannot substitute an `ok` dictionary for a real save.

Each logical object has a bounded directory of generations. A generation uses a fresh `g_<sequence>_<nonce>` directory. Payload bytes are written once and reread, then checked for size, hash and the configured schema. A complete marker is first written to a unique temporary location, reread and validated, then moved to its previously nonexistent final name. No existing payload, committed marker or authoritative pointer is replaced. A hint is optional and never selects a generation.

Read rules are explicit:

- Missing complete marker, including partial payload or marker temporary files: uncommitted; ignore for selection, preserve and count toward the fixed directory bound
- Present complete marker with malformed/unknown metadata, missing data, wrong checksum, rejected schema or a duplicate committed sequence: refuse the read clearly; keep older valid files, but do not silently return them as success
- Otherwise, select the highest fully validated sequence. Keep the newest two distinct committed sequences once two exist; the first successful save necessarily has only one
- Older generation cleanup removes its complete marker before its payload. Cleanup or capacity failure reports disk pressure and cannot delete the newest two valid generations. A failure after publishing a new complete marker preserves the fact that that sequence committed

No recover-last-verified UI, old-layout conversion or automatic stale-lock reclamation is introduced. An interrupted slot remains explicitly incomplete and retains its files. This protocol targets testable process-interruption consistency. It does not claim `fsync`, power-loss durability or validated Windows filesystem behavior.

`SaveStore.configure_windows_generation_storage()` is explicit, before acquire, and constrained to the ordinary Windows user slot root. Refusal is sticky: no fallback to old layout. `_decode_text` is the existing decoder extracted without changing its validation body. Every operation verifies the exact configured adapter instance/script and its slot root/type/size/logical-name bindings. `inspect_main()` obtains actual selected bytes and full validation without acquiring a writer lock.

The same adapter has three precise record kinds: `save_schema4` (4 MiB), `slot_index_v1` (128 KiB) and `local_report_v1` (4 MiB). Report data is not save authority. Report and save callbacks must bind their payload sequence to the marker. Index generations use their own metadata sequence. GUI slot metadata still advances to ready only after the coordinator confirms actual server exit0, complete save evidence and actual disk/identity checks.

`ActorWindowsGenerationStoreTest.gd` has eight finite methods using real files with an explicitly mocked platform/scope and semantic validator. It covers generations, missing markers, committed corruption, duplicate sequence, non-authoritative hints, bounds, default-vs-opt-in Store routing, binding changes and a simulated post-commit failure. `ActorLocalSaveSlotsTest.gd` independently covers full World/Terrain validation on the unchanged legacy Linux path. Neither layer alone proves the full ordinary Windows generation/terrain chain; engine/export and Windows process-interruption tests remain required.

本机会话控制报告仅有 startup、close_cursor、terminal 三个一次性阶段。local_report_v1 固定最多3条，全部保留且会话内不退休，避免并发读取与删除旧报告竞争；第4条在写入前拒绝。save/index 仍保留最新两条有效代。
