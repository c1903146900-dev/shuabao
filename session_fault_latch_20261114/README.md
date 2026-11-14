# Preserve pause after terminal session faults

Independent candidate based on the isolated 875 combination; not merged with the direct-fire sight candidate. QA.json pins both runtime packages. The original session._fault sets status=faulted and pauses the simulation. The host's next _sync_pause previously recomputed pause without that status, allowing the fault stop to be undone when other flags were false.

The patch adds four lines to the host pause synchronizer. It latches the session reason into the existing floor_error path without replacing an existing error and suspends input. Combat values, enemy rosters, progression, settlement, rewards and guard behavior remain unchanged. Session faults already terminate this run; the patch does not add recovery or silently clear faults.

Apply the patch to a fresh exact baseline runtime, checking SOURCE_HASHES.json before and after. Use the existing trusted sealing procedure to regenerate manifest, generation, runtime package and descriptor. This package includes no runtime binary, assets, private original archives or raw logs.

Static scope and both sets of 260 bindings were verified. test_pause_model.py passes 128 boolean combinations and distinguishes the old false-pause result in the all-flags-clear fault case. This is only an independent Python logic model, NOT GDScript execution. The engine was not launched. Parser acceptance, actual-host fault injection, visible guidance, normal-room regression and whole-floor validation remain untested. A naturally occurring fault was not reproduced.

Before admission, use the unchanged original guard and approved desktop workflow to test next-frame pause persistence, held-input clearing, prior-error preservation, menu return and clean new-run reset. Preserve the baseline. Do not treat this backup as gameplay acceptance.
