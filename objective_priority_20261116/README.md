# Current-state objective priority, isolated 875 child

The host currently displays an unexpired rejection notice ahead of the current guidance. Automatic death settlement and exit-map opening do not clear that notice. A dead hero can therefore still be told to clear enemies, or an open map can retain the old exit instruction.

The candidate adds FlowGuidance.objective_for and changes only the host objective-label call. Fault, pause, map, completed and defeated states delegate to the unchanged text_for function; ordinary active notices retain their previous behavior. Original text wording and precedence inside text_for are unchanged. No combat, navigation, input, settlement or other candidate changes are included.

BUILD.json pins the exact parent and candidate PCK. Both verify 260 bindings; only host, flow_guidance and the two required seals differ. MODEL_RESULT.json records 192 independent Python priority checks, not GDScript execution. No engine, visual, natural-flow or whole-floor test was run in this reconstruction. An earlier separate candidate had historical death/map integration results, but its acceptance is NOT inherited by this candidate.

Apply objective_priority.patch to a fresh exact 875 runtime and use the existing trusted sealing procedure to regenerate manifest, generation, PCK and descriptor. Preserve all existing baselines. Pending tests are actual-host death/map overlap, pause/fault precedence, normal notice expiry and return-to-menu/new-run behavior, only when an approved guarded engine workflow is available. No rejected operation was retried. This checkpoint excludes assets, binaries, raw logs and all other candidate batches.
