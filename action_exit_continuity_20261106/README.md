# Isolated action-exit continuity candidate

Status: static-only candidate. No Godot compilation, runtime or visual acceptance is claimed. Built independently from the fully floor-checked e1_motion01, not stacked on the pending Q3 candidate. Existing passing builds and Q3 are unchanged.

## Specific source issue
presentation.gd uses the actual displacement-owned walk phase while there is no action. However, the expired-action branch and stale/cancelled-cast branch unconditionally return idle for their first frame even when _walking is true. The next frame returns walking. That creates an avoidable one-frame idle interruption at action exits, independent of the animation artwork. Earlier bounded captures also contained idle exit frames, but a new controlled visual comparison remains needed to attribute perceived improvement.

The isolated change extracts the exact existing locomotion selector into _locomotion_frame() and uses it for the empty-action, cancelled-action and expired-action paths. It does not advance walk distance, clear extra state, change clock domains or alter source cancellation rules. When stationary it still returns idle; when valid walking continues it returns the same authored four-phase leg selection immediately. Cast ID remains -1 and facing comes from the live hero.

## Static checks
check_static.py verifies that only presentation.gd and generated manifest/seal differ from e1_motion01, that all three exit paths use the common selector, and that all 243 manifest file hashes match. Reference selector checks cover stationary and 200 displacement samples. These are structural/hash/reference checks, NOT a Godot parser test or render check.

Build: reconstruct e1_motion01 through the established recovery chain, then use rebuild_20261106/build_action_exit.py with a fresh output directory. Original private inputs/artwork remain required.
Pack SHA256: bcaae29dafd0eebaad17536d24a58e54df9a95a19f147691c5125e77e9c161d6

## Next verification when scheduling permits
Use the unchanged guard. In a short buffered capture, maintain ordinary movement through Q1/Q3 recovery and compare the exit frame to the following frame. Verify no idle insertion only when _walking is true; stationary exits remain idle. Check cancellation/lifecycle boundaries still clear old cast identity, source clocks remain unchanged and no walk phase advances while paused. Do not promote or merge this candidate before runtime and visual validation.
