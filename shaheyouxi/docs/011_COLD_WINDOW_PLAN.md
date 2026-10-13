# 011 restored-environment cold bootstrap candidate

Purpose: rebuild the intentionally excluded Godot import/global-class caches after restoring010 v9. This is not a gameplay/model/physics acceptance run, and import completion alone does not prove every new script was compiled.

Only one engine command:
/usr/local/bin/godot --headless --path /workspace/shared/shaheyouxi_project/game --verbose --editor --import --quit

No game run, GdUnit suite, ENet server/client, GUI editor, Blender, packaging or additional test matrix. Existing Godot MCP plugin requires an explicit project environment flag; the guard removes those variables.

Entry: tools/desktop_actor011_cold.sh, fresh uniquely titled desktop terminal. Existing10-second delay, then CUA reset before actual cgroup admission. Shared tools/verify_batch004.py --actor011-cold uses own 1024MiB/effective reserve900MiB/raw emergency192MiB,45-second command/110-second total limits, process-group cleanup and OOM checks. No thresholds changed in older profiles. Root must freshly authorize the frozen candidate.

Mock-only runner checks: two new cold-profile cases and five010runner regression cases passed. They prove command selection/guard parameters and zero-exit parse-error rejection, not actual desktop capacity or engine behavior. A missing capacity budget, process timeout, parse error or nonzero exit fails this one run and releases the slot. No immediate retries without parent instruction.

After completion, report true exit/cleanup/cgroup evidence and class-cache presence. New actor GdUnit tests still require their own frozen bounded window.

Root approved1024MiB cold-editor-only ceiling after two prematurely truncated probes. Verbose diagnostics added before freeze to record actual backend/import stages. No additional command or test suite.

## Replacement-host guarded bootstrap (2026-10-06)

The actual launcher uses its relative project directory. It now requires the
explicit pair `--actor011-cold --observe-cold-import`. The sole standard import
command and1024MiB/900MiB/192MiB,45/110 limits are unchanged. The dedicated
observer applies0.1-second resource TERM grace and6-second post-KILL cleanup.
Default core/v3 still reject import. Source/project/plugin hashes are compared
before, directly before launch, and afterward including failures; generated
cache/sidecars are explicitly excluded. No plugin is disabled and no foreign
global class cache is copied. Independent45 mock checks and combined232 mocks
pass. This is source-ready only; replacement-host import has not yet run.
